import 'dart:io';

import 'package:cartilhas_app/features/auth/data/account_data_deletion_service.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('apaga preferências e a carteira privada de certificados', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'tutor_tds:profile_cpf:v1': '529.982.247-25',
    });
    SharedPreferences.setMockInitialValues({
      'user_name': 'Pessoa de Teste',
      'learning_events:pending:v1': '[]',
      'classroom_private:v1:environment:owner': '{"classes":[]}',
    });
    final documents = await Directory.systemTemp.createTemp(
      'tutor-tds-account-delete-',
    );
    addTearDown(() async {
      if (await documents.exists()) await documents.delete(recursive: true);
    });
    final repository = CertificateRepository(
      documentsDirectoryProvider: () async => documents,
    );
    final certificates = await repository.certificatesDirectory();
    await File(
      '${certificates.path}${Platform.pathSeparator}private.pdf',
    ).writeAsString('private certificate');

    var outboxDeleted = false;
    await AccountDataDeletionService(
      certificateRepository: repository,
      deleteLearningOutbox: () async {
        outboxDeleted = true;
      },
    ).deleteLocalData();

    final preferences = await SharedPreferences.getInstance();
    expect(outboxDeleted, isTrue);
    expect(preferences.getKeys(), isEmpty);
    expect(
      await const FlutterSecureStorage().read(key: 'tutor_tds:profile_cpf:v1'),
      isNull,
    );
    expect(await certificates.exists(), isFalse);
  });
}
