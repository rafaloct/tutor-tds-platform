import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../certificates/data/certificate_repository.dart';
import '../../evidence/data/checkin_draft_store.dart';
import '../../learning_events/learning_event_queue.dart';
import '../../profile/data/profile_data_store.dart';
import '../../study_ai/data/assessment_sync_queue.dart';

/// Ends the local academic context at logout without touching owned evidence.
///
/// Owned learning events stay in the outbox (delivery is isolated by owner and
/// API URL). Only data that is not scoped to an identity is removed. This is
/// deliberately not AccountDataDeletionService: no outbox erase, no
/// SharedPreferences.clear(); theme and consents are preserved.
class UnscopedAccountDataCleaner {
  const UnscopedAccountDataCleaner({
    this._learningEventQueue,
    this._assessmentSyncQueue,
    this._checkinDraftStore,
    this._profileDataStore,
    this._certificateRepository,
  });

  final LearningEventQueue? _learningEventQueue;
  final AssessmentSyncQueue? _assessmentSyncQueue;
  final CheckinDraftStore? _checkinDraftStore;
  final ProfileDataStore? _profileDataStore;
  final CertificateRepository? _certificateRepository;

  static const _exactKeys = {
    'user_name',
    'user_phone',
    'user_cpf',
    'support_contact_id_v1',
    'study_progress:last',
    'study_assessment:last',
    'study_summary:last',
    'media:catalog_cache:v1',
  };
  static const _prefixes = [
    'study_progress:course:',
    'study_assessment:course:',
    'study_summary:course:',
    'media:progress:',
  ];
  static const _ownerScopedPrefixes = [
    'study_progress:version:',
    'study_progress:context:',
  ];

  Future<void> clear() async {
    await (_learningEventQueue ?? const LearningEventQueue()).clear(
      preserveOwned: true,
    );
    await (_assessmentSyncQueue ?? const AssessmentSyncQueue()).clear();
    await (_checkinDraftStore ?? SharedPreferencesCheckinDraftStore()).clear();
    await (_profileDataStore ?? SecureProfileDataStore()).clear();
    await _clearPreferences();
    await (_certificateRepository ?? CertificateRepository()).deleteAll();
  }

  Future<void> _clearPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().toList()) {
      if (_exactKeys.contains(key) ||
          _prefixes.any(key.startsWith) ||
          (_ownerScopedPrefixes.any(key.startsWith) && _isUnowned(key))) {
        await preferences.remove(key);
      }
    }
  }

  /// Version/context progress keys end with `ownerId` inside a JSON list.
  bool _isUnowned(String key) {
    try {
      final payload = jsonDecode(key.substring(key.indexOf(':', 15) + 1));
      return payload is List && payload.isNotEmpty && payload.last == null;
    } on Object {
      return true;
    }
  }
}
