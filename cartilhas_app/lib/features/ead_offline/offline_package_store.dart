import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'offline_package_manifest.dart';

/// Caller must obtain this result from a trusted, revision/ETag-checked
/// editorial adapter, including an independently verified rights decision.
typedef OfflineReleaseCheck =
    Future<bool> Function(OfflinePackageManifest manifest);
typedef OfflineAssetDownload = Stream<List<int>> Function(Uri url);

class OfflinePackageException implements Exception {
  const OfflinePackageException(this.code);
  final String code;
  @override
  String toString() => 'Offline package: $code';
}

/// Store root must be an application-support private directory when integrated.
/// Operations on the same root are serialized, including across store instances.
class OfflinePackageStore {
  OfflinePackageStore({
    required this.root,
    required this.authorize,
    required this.download,
    this.quotaBytes = 2 * 1024 * 1024 * 1024,
  }) {
    if (quotaBytes <= 0) throw ArgumentError.value(quotaBytes, 'quotaBytes');
  }

  final Directory root;
  final OfflineReleaseCheck authorize;
  final OfflineAssetDownload download;
  final int quotaBytes;
  static final Map<String, Future<void>> _queues = {};

  Future<T> _serial<T>(Future<T> Function() work) async {
    final key = root.absolute.path;
    final previous = _queues[key];
    final done = Completer<void>();
    _queues[key] = done.future;
    if (previous != null) await previous;
    try {
      return await work();
    } finally {
      done.complete();
      if (identical(_queues[key], done.future)) _queues.remove(key);
    }
  }

  String _at(String parent, String child) =>
      '$parent${Platform.pathSeparator}$child';
  String _lesson(int courseId, int lessonId) =>
      _at(_at(root.path, 'v1'), '$courseId${Platform.pathSeparator}$lessonId');
  String _revision(OfflinePackageManifest m) =>
      _at(_lesson(m.courseId, m.lessonId), m.contentRevision);

  Future<void> _safeDirectory(String path, {bool create = false}) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await Directory(path).create();
    } else if (type != FileSystemEntityType.directory) {
      throw const OfflinePackageException('unsafe_path');
    }
  }

  Future<void> _parents(int courseId, int lessonId) async {
    await _safeDirectory(root.path, create: true);
    await _safeDirectory(_at(root.path, 'v1'), create: true);
    await _safeDirectory(_at(_at(root.path, 'v1'), '$courseId'), create: true);
    await _safeDirectory(_lesson(courseId, lessonId), create: true);
  }

  /// A rejected revision never replaces another READY revision.
  Future<void> install(OfflinePackageManifest manifest) => _serial(() async {
    if (!await authorize(manifest)) {
      throw const OfflinePackageException('release_denied');
    }
    await _parents(manifest.courseId, manifest.lessonId);
    final target = _revision(manifest);
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final existing = await _verify(manifest);
      if (existing != null) return;
      throw const OfflinePackageException('revision_conflict');
    }
    final used = await _usedBytes();
    if (manifest.totalBytes > quotaBytes ||
        used > quotaBytes - manifest.totalBytes) {
      throw const OfflinePackageException('quota_exceeded');
    }
    final random = Random.secure();
    final suffix = List<int>.generate(12, (_) => random.nextInt(256));
    final staging = Directory(
      '$target.part-${base64Url.encode(suffix).replaceAll('=', '')}',
    );
    await staging.create();
    try {
      await _writeAsset(manifest.mp4, File(_at(staging.path, 'video.mp4')));
      if (manifest.vtt case final vtt?) {
        await _writeAsset(vtt, File(_at(staging.path, 'captions.vtt')));
      }
      final bytes = utf8.encode(jsonEncode(manifest.toJson()));
      await File(
        _at(staging.path, 'manifest.json'),
      ).writeAsBytes(bytes, flush: true);
      await File(
        _at(staging.path, 'manifest.sha256'),
      ).writeAsString(sha256.convert(bytes).toString(), flush: true);
      await staging.rename(target);
    } on OfflinePackageException {
      rethrow;
    } on Object {
      throw const OfflinePackageException('install_failed');
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  });

  Future<int> _usedBytes() async {
    final v1 = Directory(_at(root.path, 'v1'));
    var size = 0;
    await for (final entry in v1.list(recursive: true, followLinks: false)) {
      if (entry is Link) throw const OfflinePackageException('unsafe_path');
      if (entry is File) size += await entry.length();
    }
    return size;
  }

  Future<void> _writeAsset(OfflineAsset asset, File file) async {
    final sink = file.openWrite();
    final digests = _DigestSink();
    final hashing = sha256.startChunkedConversion(digests);
    var size = 0;
    try {
      await for (final bytes in download(asset.url)) {
        size += bytes.length;
        if (size > asset.length) {
          throw const OfflinePackageException('size_mismatch');
        }
        hashing.add(bytes);
        sink.add(bytes);
      }
      hashing.close();
      await sink.flush();
      await sink.close();
      if (size != asset.length) {
        throw const OfflinePackageException('size_mismatch');
      }
      if (digests.digest?.toString() != asset.sha256) {
        throw const OfflinePackageException('hash_mismatch');
      }
    } finally {
      if (digests.digest == null) hashing.close();
      await sink.close();
    }
  }

  /// Returns only a fully verified local file. No academic state is recorded.
  Future<File?> read(
    OfflinePackageManifest manifest, {
    bool captions = false,
  }) => _serial(() async {
    final ready = await _verify(manifest);
    if (ready == null || (captions && manifest.vtt == null)) return null;
    return File(_at(ready.path, captions ? 'captions.vtt' : 'video.mp4'));
  });

  Future<Directory?> _verify(OfflinePackageManifest expected) async {
    final path = _revision(expected);
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return null;
    }
    final v1 = _at(root.path, 'v1');
    final course = _at(v1, '${expected.courseId}');
    final lesson = _lesson(expected.courseId, expected.lessonId);
    for (final parent in [v1, course, lesson, path]) {
      if (await FileSystemEntity.type(parent, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
    }
    try {
      for (final name in [
        'manifest.json',
        'manifest.sha256',
        'video.mp4',
        if (expected.vtt != null) 'captions.vtt',
      ]) {
        if (await FileSystemEntity.type(_at(path, name), followLinks: false) !=
            FileSystemEntityType.file) {
          return null;
        }
      }
      final bytes = await File(_at(path, 'manifest.json')).readAsBytes();
      if (bytes.length > 4096 ||
          sha256.convert(bytes).toString() !=
              await File(_at(path, 'manifest.sha256')).readAsString()) {
        return null;
      }
      final stored = OfflinePackageManifest.fromJson(utf8.decode(bytes));
      if (jsonEncode(stored.toJson()) != jsonEncode(expected.toJson())) {
        return null;
      }
      if (!await _matches(File(_at(path, 'video.mp4')), stored.mp4)) {
        return null;
      }
      if (stored.vtt case final vtt?) {
        if (!await _matches(File(_at(path, 'captions.vtt')), vtt)) return null;
      }
      return Directory(path);
    } on Object {
      return null;
    }
  }

  Future<bool> _matches(File file, OfflineAsset asset) async {
    if (await file.length() != asset.length) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == asset.sha256;
  }

  /// Revokes all revisions for this exact lesson. New installation needs a fresh
  /// trusted authorization check; stale files are not returned.
  Future<void> revoke(int courseId, int lessonId) => _serial(() async {
    if (courseId <= 0 ||
        lessonId <= 0 ||
        courseId > 100000000 ||
        lessonId > 100000000) {
      throw const OfflinePackageException('invalid_id');
    }
    final path = _lesson(courseId, lessonId);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw const OfflinePackageException('unsafe_path');
    }
    await Directory(path).delete(recursive: true);
  });
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}
