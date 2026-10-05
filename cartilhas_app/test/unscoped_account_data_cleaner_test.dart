import 'package:cartilhas_app/features/auth/data/unscoped_account_data_cleaner.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/evidence/data/checkin_draft_store.dart';
import 'package:cartilhas_app/features/profile/data/profile_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileStore implements ProfileDataStore {
  var cleared = false;

  @override
  Future<void> clear() async => cleared = true;

  @override
  Future<ProfileData> read() async =>
      const ProfileData(name: '', phone: '', cpf: '');

  @override
  Future<void> write(ProfileData data) async {}
}

class _FakeCertificates extends CertificateRepository {
  var deleted = false;

  @override
  Future<void> deleteAll() async => deleted = true;
}

void main() {
  test('remove dados não escopados e preserva preferências e dados owned', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'A',
      'user_phone': '1',
      'support_contact_id_v1': 'x',
      'study_progress:last': '{}',
      'study_progress:course:c1': '{}',
      'study_progress:version:["c1","v1",null]': '{}',
      'study_progress:version:["c1","v1","owner-a"]': '{}',
      'study_assessment:last': '{}',
      'study_assessment:sync:v1': '{}',
      'study_summary:course:c1': '{}',
      'media:catalog_cache:v1': '[]',
      'media:progress:m1': '{}',
      'classroom_private:v1:learner:owner-a': '{}',
      'learning_home:selection:abc123': '{}',
      SharedPreferencesCheckinDraftStore.storageKey: '{}',
      'theme_preference_v1': 'dark',
      'privacy_consent_v1': true,
      'certificate_consent_v1': true,
      'onboarding_seen_v1': true,
    });
    final profile = _FakeProfileStore();
    final certificates = _FakeCertificates();

    await UnscopedAccountDataCleaner(
      profileDataStore: profile,
      certificateRepository: certificates,
    ).clear();

    final keys = (await SharedPreferences.getInstance()).getKeys();
    expect(profile.cleared, isTrue);
    expect(certificates.deleted, isTrue);
    expect(keys, {
      'study_progress:version:["c1","v1","owner-a"]',
      'classroom_private:v1:learner:owner-a',
      'learning_home:selection:abc123',
      'theme_preference_v1',
      'privacy_consent_v1',
      'certificate_consent_v1',
      'onboarding_seen_v1',
    });
  });
}
