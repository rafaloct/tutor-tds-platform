// Run with Dart 3.12.2 from Flutter 3.44.9; no packages or network needed.
import 'dart:convert';
import 'dart:io';

import '../../../cartilhas_app/lib/features/ead_offline/offline_package_manifest.dart';

void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('Expected server JSON fixture path');
  final raw = File(args.single).readAsStringSync();
  final manifest = OfflinePackageManifest.fromJson(raw);
  if (manifest.courseId != 1356 ||
      manifest.lessonId != 1425 ||
      manifest.totalBytes != 81 ||
      manifest.mp4.length != 44 ||
      manifest.vtt?.length != 37) {
    throw StateError('Server contract mismatch');
  }
  final roundtrip = OfflinePackageManifest.parse(manifest.toJson());
  if (roundtrip.contentRevision != manifest.contentRevision) {
    throw StateError('Revision lost');
  }
  final invalid = jsonDecode(raw) as Map<String, dynamic>;
  invalid['revision'] = manifest.contentRevision;
  try {
    OfflinePackageManifest.parse(invalid);
    throw StateError('Extra field accepted');
  } on FormatException {
    // Expected: ETag belongs in headers, not an extra revision JSON key.
  }
  stdout.writeln('PASS PHP JSON -> Dart manifest: 3 contract checks; not Android');
}
