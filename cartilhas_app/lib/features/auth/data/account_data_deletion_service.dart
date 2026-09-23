import 'package:shared_preferences/shared_preferences.dart';

import '../../certificates/data/certificate_repository.dart';
import '../../profile/data/profile_data_store.dart';
import '../../learning_events/sqlite_learning_outbox.dart';

class AccountDataDeletionService {
  AccountDataDeletionService({
    CertificateRepository? certificateRepository,
    ProfileDataStore? profileDataStore,
    Future<void> Function()? deleteLearningOutbox,
  }) : _certificateRepository =
           certificateRepository ?? CertificateRepository(),
       _profileDataStore = profileDataStore ?? SecureProfileDataStore(),
       _deleteLearningOutbox =
           deleteLearningOutbox ?? SqliteLearningOutbox.eraseIfPresent;

  final CertificateRepository _certificateRepository;
  final ProfileDataStore _profileDataStore;
  final Future<void> Function() _deleteLearningOutbox;

  Future<void> deleteLocalData() async {
    await _deleteLearningOutbox();
    await _profileDataStore.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await _certificateRepository.deleteAll();
  }
}
