import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_manifest.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';

const host =
    'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds';
final video = utf8.encode('synthetic public video');
final captions = utf8.encode('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nTest');
String hash(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> manifest({
  String? url,
  String? revision,
  bool mobile = true,
  bool rights = true,
  bool withVtt = true,
}) => {
  'schema_version': 1,
  'course_id': 1420,
  'lesson_id': 1298,
  'content_revision': revision ?? 'a' * 64,
  'mobile_content': mobile,
  'rights_approved': rights,
  'mp4': {
    'url': url ?? '$host/video.mp4',
    'length': video.length,
    'sha256': hash(video),
  },
  if (withVtt)
    'vtt': {
      'url': '$host/video.vtt',
      'length': captions.length,
      'sha256': hash(captions),
    },
  'title': 'Aula publica',
};

void main() {
  group('manifest v1', () {
    test('accepts exact public IPEX assets', () {
      final m = OfflinePackageManifest.parse(manifest());
      expect(m.totalBytes, video.length + captions.length);
      expect(
        OfflinePackageManifest.fromJson(jsonEncode(m.toJson())).toJson(),
        m.toJson(),
      );
    });
    test(
      'denies rights false',
      () => expect(
        () => OfflinePackageManifest.parse(manifest(rights: false)),
        throwsFormatException,
      ),
    );
    test(
      'denies mobile false',
      () => expect(
        () => OfflinePackageManifest.parse(manifest(mobile: false)),
        throwsFormatException,
      ),
    );
    test(
      'denies HTTP',
      () => expect(
        () => OfflinePackageManifest.parse(
          manifest(url: '$host/video.mp4'.replaceFirst('https:', 'http:')),
        ),
        throwsFormatException,
      ),
    );
    test(
      'denies userinfo',
      () => expect(
        () => OfflinePackageManifest.parse(
          manifest(
            url: "${host.replaceFirst('https://', 'https://user@')}/video.mp4",
          ),
        ),
        throwsFormatException,
      ),
    );
    test(
      'denies another host',
      () => expect(
        () => OfflinePackageManifest.parse(
          manifest(url: 'https://evil.example/video.mp4'),
        ),
        throwsFormatException,
      ),
    );
    test(
      'denies port',
      () => expect(
        () => OfflinePackageManifest.parse(
          manifest(
            url: "${host.replaceFirst('.cloud', '.cloud:443')}/video.mp4",
          ),
        ),
        throwsFormatException,
      ),
    );
    test('denies query and fragment', () {
      for (final suffix in ['?x=1', '#x']) {
        expect(
          () => OfflinePackageManifest.parse(
            manifest(url: '$host/video.mp4$suffix'),
          ),
          throwsFormatException,
        );
      }
    });
    test('denies traversal and encoded separators', () {
      for (final path in [
        '../video.mp4',
        '%2e%2e/video.mp4',
        'x%2fvideo.mp4',
        'x\\video.mp4',
      ]) {
        expect(
          () => OfflinePackageManifest.parse(manifest(url: '$host/$path')),
          throwsFormatException,
        );
      }
    });
    test(
      'denies YouTube ID',
      () => expect(
        () => OfflinePackageManifest.parse(manifest(url: 'dQw4w9WgXcQ')),
        throwsFormatException,
      ),
    );
    test('denies duplicate asset', () {
      final raw = manifest();
      (raw['vtt'] as Map<String, dynamic>)['sha256'] = hash(video);
      expect(() => OfflinePackageManifest.parse(raw), throwsFormatException);
    });
    test('denies oversized MP4 and package', () {
      final raw = manifest();
      (raw['mp4'] as Map<String, dynamic>)['length'] = 500 * 1024 * 1024;
      expect(() => OfflinePackageManifest.parse(raw), throwsFormatException);
      (raw['mp4'] as Map<String, dynamic>)['length'] = 400 * 1024 * 1024;
      (raw['vtt'] as Map<String, dynamic>)['length'] = 300 * 1024 * 1024;
      expect(() => OfflinePackageManifest.parse(raw), throwsFormatException);
    });
    test('denies unknown schema and extra user data', () {
      final raw = manifest()..['schema_version'] = 2;
      expect(() => OfflinePackageManifest.parse(raw), throwsFormatException);
      raw['schema_version'] = 1;
      raw['user_id'] = 42;
      expect(() => OfflinePackageManifest.parse(raw), throwsFormatException);
    });
  });

  group('store', () {
    late Directory temp;
    late OfflinePackageManifest m;
    late bool permitted;
    late int calls;
    late Map<String, List<int>> payload;
    late OfflinePackageStore store;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ead-offline-test-');
      m = OfflinePackageManifest.parse(manifest());
      permitted = true;
      calls = 0;
      payload = {'mp4': video, 'vtt': captions};
      store = OfflinePackageStore(
        root: Directory('${temp.path}${Platform.pathSeparator}support'),
        authorize: (_) async => permitted,
        download: (url) async* {
          calls++;
          final bytes = payload[url.path.endsWith('.mp4') ? 'mp4' : 'vtt']!;
          for (var i = 0; i < bytes.length; i += 3) {
            yield bytes.sublist(i, i + 3 > bytes.length ? bytes.length : i + 3);
          }
        },
      );
    });
    tearDown(() async => temp.delete(recursive: true));

    test('reads verified package after restart without download', () async {
      await store.install(m);
      final restarted = OfflinePackageStore(
        root: store.root,
        authorize: (_) async => false,
        download: (_) => throw StateError('no internet'),
      );
      expect(await (await restarted.read(m))!.readAsBytes(), video);
      expect(
        await (await restarted.read(m, captions: true))!.readAsBytes(),
        captions,
      );
      expect(calls, 2);
    });
    test('public URL alone cannot authorize release', () async {
      permitted = false;
      await expectLater(
        store.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(await store.read(m), isNull);
      expect(calls, 0);
    });
    test('wrong hash is rejected and cleaned', () async {
      payload['mp4'] = utf8.encode('synthetic public VIDEo');
      await expectLater(
        store.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(await store.read(m), isNull);
    });
    test('short stream is rejected', () async {
      payload['mp4'] = video.sublist(1);
      await expectLater(
        store.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(await store.read(m), isNull);
    });
    test('long stream is rejected', () async {
      payload['mp4'] = [...video, 0];
      await expectLater(
        store.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(await store.read(m), isNull);
    });
    test('partial failure preserves previous READY revision', () async {
      await store.install(m);
      final newer = OfflinePackageManifest.parse(manifest(revision: 'b' * 64));
      payload['vtt'] = captions.sublist(1);
      await expectLater(
        store.install(newer),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(await (await store.read(m))!.readAsBytes(), video);
      expect(await store.read(newer), isNull);
    });
    test('corruption refuses read', () async {
      await store.install(m);
      final file = await store.read(m);
      await file!.writeAsBytes(List.filled(video.length, 0));
      expect(await store.read(m), isNull);
    });
    test('idempotent install does not redownload', () async {
      await store.install(m);
      await store.install(m);
      expect(calls, 2);
    });
    test('new revision is independently READY', () async {
      await store.install(m);
      final newer = OfflinePackageManifest.parse(manifest(revision: 'b' * 64));
      await store.install(newer);
      expect(await store.read(m), isNotNull);
      expect(await store.read(newer), isNotNull);
    });
    test('revoke removes all revisions, reauthorization required', () async {
      await store.install(m);
      await store.install(
        OfflinePackageManifest.parse(manifest(revision: 'b' * 64)),
      );
      await store.revoke(1420, 1298);
      expect(await store.read(m), isNull);
      permitted = false;
      await expectLater(
        store.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
    });
    test('concurrent duplicate installs make one commit', () async {
      await Future.wait([store.install(m), store.install(m)]);
      expect(calls, 2);
    });
    test('quota rejects before download', () async {
      final limited = OfflinePackageStore(
        root: store.root,
        quotaBytes: 1,
        authorize: (_) async => true,
        download: store.download,
      );
      await expectLater(
        limited.install(m),
        throwsA(isA<OfflinePackageException>()),
      );
      expect(calls, 0);
    });
  });
}
