import 'package:shared_preferences/shared_preferences.dart';

import '../../certificates/data/certificate_repository.dart';
import '../../profile/data/profile_data_store.dart';

class AccountDataDeletionService {
  AccountDataDeletionService({
    CertificateRepository? certificateRepository,
    ProfileDataStore? profileDataStore,
  }) : _certificateRepository =
           certificateRepository ?? CertificateRepository(),
       _profileDataStore = profileDataStore ?? SecureProfileDataStore();

  final CertificateRepository _certificateRepository;
  final ProfileDataStore _profileDataStore;

  Future<void> deleteLocalData() async {
    await _profileDataStore.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await _certificateRepository.deleteAll();
  }
}
