import 'dart:convert';

import 'offline_manifest_repository.dart';
import 'offline_package_binding.dart';
import 'offline_package_manifest.dart';

/// Verifies a candidate against a fresh response from the canonical editorial
/// server, not against the candidate's own approval flags or a cached release.
/// This authorizes public media installation only, never academic access.
/// Application wiring remains explicitly opt-in; the default store still denies.
class EditorialOfflineReleaseAuthority
    implements VerifiedOfflineReleaseAuthority {
  EditorialOfflineReleaseAuthority({OfflineManifestRepository? repository})
    : _repository = repository ?? OfflineManifestRepository();

  final OfflineManifestRepository _repository;

  @override
  Future<bool> verify(OfflinePackageManifest manifest) async {
    try {
      final current = await _repository.fetch(
        manifest.courseId,
        manifest.lessonId,
      );
      // toJson emits a fixed schema order independent of server key ordering.
      // Include identity, revision, URLs, lengths, hashes, captions and title.
      return jsonEncode(current.toJson()) == jsonEncode(manifest.toJson());
    } on Object {
      // Unavailable, revoked, malformed or mismatched data never grants release.
      return false;
    }
  }
}
