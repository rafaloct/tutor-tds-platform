// Pass the native HTTP manifest JSON exported from acceptance.json['manifest'].
import 'dart:convert';
import 'dart:io';

import '../../../cartilhas_app/lib/features/ead_offline/offline_package_manifest.dart';

void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('Expected native HTTP JSON path');
  final raw = File(args.single).readAsStringSync();
  final source = jsonDecode(raw) as Map<String, dynamic>;
  final manifest = OfflinePackageManifest.fromJson(raw);
  if (manifest.courseId != source['course_id'] ||
      manifest.lessonId != source['lesson_id'] ||
      manifest.totalBytes != 81) {
    throw StateError('Native WordPress manifest mismatch');
  }
  final roundtrip = OfflinePackageManifest.parse(manifest.toJson());
  if (roundtrip.contentRevision != manifest.contentRevision ||
      roundtrip.mp4.sha256 != manifest.mp4.sha256) {
    throw StateError('Roundtrip mismatch');
  }
  source['revision'] = manifest.contentRevision;
  try {
    OfflinePackageManifest.parse(source);
    throw StateError('Extra field accepted');
  } on FormatException {
    // Expected: a second JSON revision key is outside the strict contract.
  }
  stdout.writeln('PASS native WP JSON -> unchanged Dart: 3 checks; not Android');
}
