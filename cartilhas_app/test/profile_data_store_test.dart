import 'package:cartilhas_app/features/profile/data/profile_data_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores CPF only in protected storage', () async {
    final store = SecureProfileDataStore();

    await store.write(
      const ProfileData(
        name: 'Pessoa Teste',
        phone: '(63) 99999-0000',
        cpf: '529.982.247-25',
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('user_name'), 'Pessoa Teste');
    expect(preferences.getString('user_phone'), '(63) 99999-0000');
    expect(preferences.getString(SecureProfileDataStore.legacyCpfKey), isNull);
    expect((await store.read()).cpf, '529.982.247-25');
  });

  test('migrates and removes a legacy plaintext CPF', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Pessoa Legada',
      SecureProfileDataStore.legacyCpfKey: '529.982.247-25',
    });
    final store = SecureProfileDataStore();

    final profile = await store.read();

    expect(profile.cpf, '529.982.247-25');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(SecureProfileDataStore.legacyCpfKey), isNull);
    expect(
      await const FlutterSecureStorage().read(
        key: SecureProfileDataStore.secureCpfKey,
      ),
      '529.982.247-25',
    );
  });
}
