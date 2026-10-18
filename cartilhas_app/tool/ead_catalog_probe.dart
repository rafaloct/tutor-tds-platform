// Live, read-only smoke. Not part of unit tests or production runtime.
// Run: dart run tool/ead_catalog_probe.dart
import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';

Future<void> main() async {
  final courses = await EadCatalogRepository().fetchPublished();
  if (courses.isEmpty) {
    throw StateError('EAD returned an empty published catalog.');
  }
  stdout.writeln('EAD_PUBLISHED_COURSES=${courses.length}');
  for (final course in courses) {
    stdout.writeln('${course.id} | ${course.slug} | ${course.title}');
    if (course.url.host != EadCatalogRepository.host) {
      throw StateError('Untrusted EAD navigation host.');
    }
  }
  stdout.writeln('EAD_DISCOVERY_SMOKE=PASS');
}
