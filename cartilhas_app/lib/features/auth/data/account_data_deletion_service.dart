import 'package:shared_preferences/shared_preferences.dart';

import '../../certificates/data/certificate_repository.dart';

class AccountDataDeletionService {
  AccountDataDeletionService({CertificateRepository? certificateRepository})
    : _certificateRepository = certificateRepository ?? CertificateRepository();

  final CertificateRepository _certificateRepository;

  Future<void> deleteLocalData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await _certificateRepository.deleteAll();
  }
}
