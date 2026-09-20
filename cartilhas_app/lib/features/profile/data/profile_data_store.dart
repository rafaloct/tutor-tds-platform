import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileData {
  const ProfileData({
    required this.name,
    required this.phone,
    required this.cpf,
  });

  final String name;
  final String phone;
  final String cpf;
}

abstract interface class ProfileDataStore {
  Future<ProfileData> read();
  Future<void> write(ProfileData data);
  Future<void> clear();
}

/// Keeps ordinary profile preferences separate from the CPF, which is stored
/// in the platform-protected keystore/keychain through FlutterSecureStorage.
///
/// Reading performs a one-time migration from the former SharedPreferences
/// key. The legacy value is removed only after the secure write succeeds; a
/// secure-storage failure never falls back to persisting CPF as plaintext.
class SecureProfileDataStore implements ProfileDataStore {
  SecureProfileDataStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const secureCpfKey = 'tutor_tds:profile_cpf:v1';
  static const legacyCpfKey = 'user_cpf';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<ProfileData> read() async {
    final preferences = await SharedPreferences.getInstance();
    var cpf = await _secureStorage.read(key: secureCpfKey) ?? '';
    final legacyCpf = preferences.getString(legacyCpfKey) ?? '';
    if (cpf.isEmpty && legacyCpf.isNotEmpty) {
      await _secureStorage.write(key: secureCpfKey, value: legacyCpf);
      await preferences.remove(legacyCpfKey);
      cpf = legacyCpf;
    } else if (legacyCpf.isNotEmpty) {
      await preferences.remove(legacyCpfKey);
    }
    return ProfileData(
      name: preferences.getString('user_name') ?? '',
      phone: preferences.getString('user_phone') ?? '',
      cpf: cpf,
    );
  }

  @override
  Future<void> write(ProfileData data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('user_name', data.name.trim());
    await preferences.setString('user_phone', data.phone.trim());
    final cpf = data.cpf.trim();
    if (cpf.isEmpty) {
      await _secureStorage.delete(key: secureCpfKey);
    } else {
      await _secureStorage.write(key: secureCpfKey, value: cpf);
    }
    await preferences.remove(legacyCpfKey);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(legacyCpfKey);
    await _secureStorage.delete(key: secureCpfKey);
  }
}
