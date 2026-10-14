import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/verify_release_readiness.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('release-verifier-');
    _writeFixture(root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('bloqueia estado superseded e evidência física pendente', () {
    _writeStatus(
      root,
      buildAllowed: false,
      physicalStatus: 'pending',
      artifactStatus: 'superseded',
      uploadAllowed: false,
    );

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.audit);

    expect(result.isReady, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll({
        'release_evidence_pending',
        'release_build_frozen',
        'artifact_superseded',
      }),
    );
  });

  test('libera build somente após gate físico e decisão explícita', () {
    _writeStatus(
      root,
      buildAllowed: true,
      physicalStatus: 'passed',
      artifactStatus: 'superseded',
      uploadAllowed: false,
    );

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.build);

    expect(result.issues, isEmpty);
  });

  test('upload exige candidato liberado e hash exato', () {
    final artifact = File('${root.path}/release/candidate.aab')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    _writeStatus(
      root,
      buildAllowed: true,
      physicalStatus: 'passed',
      artifactStatus: 'candidate',
      uploadAllowed: true,
      artifactPath: 'release/candidate.aab',
      artifactSha: sha256
          .convert(artifact.readAsBytesSync())
          .toString()
          .toUpperCase(),
    );

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.upload);

    expect(result.issues, isEmpty);
  });

  test(
    'upload permanece bloqueado enquanto o freeze de build estiver ativo',
    () {
      final artifact = File('${root.path}/release/candidate.aab')
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [1, 2, 3, 4]);
      _writeStatus(
        root,
        buildAllowed: false,
        physicalStatus: 'passed',
        artifactStatus: 'candidate',
        uploadAllowed: true,
        artifactPath: 'release/candidate.aab',
        artifactSha: sha256
            .convert(artifact.readAsBytesSync())
            .toString()
            .toUpperCase(),
      );

      final result = ReleaseReadinessVerifier(
        root: root,
        verifySigningIdentity: false,
      ).verify(ReleaseIntent.upload);

      expect(
        result.issues.map((issue) => issue.code),
        contains('release_build_frozen'),
      );
    },
  );

  test('detecta divergência de package, versão e hash', () {
    final pubspec = File('${root.path}/pubspec.yaml');
    pubspec.writeAsStringSync('name: cartilhas_app\nversion: 9.9.9+99\n');
    File('${root.path}/release/candidate.aab')
      ..createSync(recursive: true)
      ..writeAsStringSync('different');
    _writeStatus(
      root,
      buildAllowed: true,
      physicalStatus: 'passed',
      artifactStatus: 'candidate',
      uploadAllowed: true,
      artifactPath: 'release/candidate.aab',
      artifactSha: '00',
    );

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.upload);

    expect(
      result.issues.map((issue) => issue.code),
      containsAll({'version_mismatch', 'artifact_hash_mismatch'}),
    );
  });

  for (final unsafe in [
    {'TUTOR_API_URL': 'http://127.0.0.1:8000'},
    {'EXTRA_ENDPOINT': 'https://tutor-tds-staging.fastapicloud.dev'},
    {'EXTRA_ENDPOINT': 'https://tutor-tds.local'},
    {'REMOTE_CATALOG_ENABLED': true},
    {'JOURNEY_TRACEABILITY_ENABLED': true},
    {'DYNAMIC_ACTIVITY_ENABLED': true},
    {'PUSH_NOTIFICATIONS_ENABLED': true},
  ]) {
    test('bloqueia configuração produtiva insegura: ${unsafe.keys.first}', () {
      final file = File('${root.path}/config/production.json');
      final config =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      config.addAll(unsafe);
      file.writeAsStringSync(jsonEncode(config));
      _writeStatus(
        root,
        buildAllowed: true,
        physicalStatus: 'passed',
        artifactStatus: 'superseded',
        uploadAllowed: false,
      );
      final result = ReleaseReadinessVerifier(
        root: root,
        verifySigningIdentity: false,
      ).verify(ReleaseIntent.build);
      expect(
        result.issues.map((issue) => issue.code),
        contains('production_config_mismatch'),
      );
    });
  }

  test('bloqueia configuração sem a flag push obrigatória', () {
    final file = File('${root.path}/config/production.json');
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    config.remove('PUSH_NOTIFICATIONS_ENABLED');
    file.writeAsStringSync(jsonEncode(config));
    _writeStatus(
      root,
      buildAllowed: true,
      physicalStatus: 'passed',
      artifactStatus: 'superseded',
      uploadAllowed: false,
    );

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.build);

    expect(
      result.issues.map((issue) => issue.code),
      contains('production_config_mismatch'),
    );
  });

  test('falha fechado quando a lista de evidência física está ausente', () {
    _writeStatus(
      root,
      buildAllowed: true,
      physicalStatus: 'passed',
      artifactStatus: 'superseded',
      uploadAllowed: false,
    );
    final statusFile = File('${root.path}/release/release_status.json');
    final status =
        jsonDecode(statusFile.readAsStringSync()) as Map<String, dynamic>;
    status.remove('required_physical_evidence');
    statusFile.writeAsStringSync(jsonEncode(status));

    final result = ReleaseReadinessVerifier(
      root: root,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.build);

    expect(
      result.issues.map((issue) => issue.code),
      contains('invalid_release_evidence'),
    );
  });

  for (final mutation in <String, void Function(List<dynamic>)>{
    'lista vazia': (gates) => gates.clear(),
    'gate obrigatório removido': (gates) => gates.removeLast(),
    'gate obrigatório rebaixado': (gates) =>
        gates.last['required_for_release_build'] = false,
    'entrada malformada': (gates) => gates[0] = 'passed',
    'id duplicado': (gates) => gates[1]['id'] = gates[0]['id'],
  }.entries) {
    test('falha fechado com ${mutation.key}', () {
      _writeStatus(
        root,
        buildAllowed: true,
        physicalStatus: 'passed',
        artifactStatus: 'superseded',
        uploadAllowed: false,
      );
      final file = File('${root.path}/release/release_status.json');
      final status =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      mutation.value(status['required_physical_evidence'] as List<dynamic>);
      file.writeAsStringSync(jsonEncode(status));

      final result = ReleaseReadinessVerifier(
        root: root,
        verifySigningIdentity: false,
      ).verify(ReleaseIntent.build);
      expect(
        result.issues.map((issue) => issue.code),
        contains('invalid_release_evidence'),
      );
    });
  }

  group('status externo absoluto', () {
    late Directory evidenceDirectory;
    late File externalStatus;

    setUp(() {
      evidenceDirectory = Directory.systemTemp.createTempSync(
        'release-observed-status-',
      );
      final artifact = File('${root.path}/release/candidate.aab')
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [1, 2, 3, 4]);
      _writeStatus(
        root,
        buildAllowed: true,
        physicalStatus: 'passed',
        artifactStatus: 'candidate',
        uploadAllowed: true,
        artifactPath: 'release/candidate.aab',
        artifactSha: sha256.convert(artifact.readAsBytesSync()).toString(),
      );
      externalStatus = File(
        '${root.path}/release/release_status.json',
      ).copySync('${evidenceDirectory.path}/observed release.json');
      _writeStatus(
        root,
        buildAllowed: false,
        physicalStatus: 'pending',
        artifactStatus: 'superseded',
        uploadAllowed: false,
      );
    });

    tearDown(() => evidenceDirectory.deleteSync(recursive: true));

    ReleaseVerificationResult verify({File? input}) => ReleaseReadinessVerifier(
      root: root,
      statusFile: input ?? externalStatus,
      verifySigningIdentity: false,
    ).verify(ReleaseIntent.upload);

    void mutate(void Function(Map<String, dynamic>) change) {
      final status =
          jsonDecode(externalStatus.readAsStringSync()) as Map<String, dynamic>;
      change(status);
      externalStatus.writeAsStringSync(jsonEncode(status));
    }

    test('usa o overlay sem alterar o checkout ou o default', () {
      final checkoutStatus = File('${root.path}/release/release_status.json');
      final original = checkoutStatus.readAsStringSync();
      for (final intent in ReleaseIntent.values) {
        final result = ReleaseReadinessVerifier(
          root: root,
          statusFile: externalStatus,
          verifySigningIdentity: false,
        ).verify(intent);
        expect(result.issues, isEmpty, reason: intent.name);
      }
      expect(checkoutStatus.readAsStringSync(), original);
      final defaultResult = ReleaseReadinessVerifier(
        root: root,
        verifySigningIdentity: false,
      ).verify(ReleaseIntent.upload);
      expect(
        defaultResult.issues.map((issue) => issue.code),
        containsAll({
          'release_evidence_pending',
          'release_build_frozen',
          'artifact_superseded',
        }),
      );
    });

    test('rejeita caminho relativo em vez de resolvê-lo contra o root', () {
      final result = verify(input: File('release/release_status.json'));
      expect(
        result.issues.map((issue) => issue.code),
        contains('invalid_status_file'),
      );
    });

    test('arquivo ausente bloqueia sem fallback para o checkout', () {
      File(
        '${root.path}/release/release_status.json',
      ).writeAsStringSync(externalStatus.readAsStringSync());
      expect(
        ReleaseReadinessVerifier(
          root: root,
          verifySigningIdentity: false,
        ).verify(ReleaseIntent.upload).isReady,
        isTrue,
      );
      externalStatus.deleteSync();
      final result = verify();
      expect(
        result.issues.map((issue) => issue.code),
        contains('required_file_missing'),
      );
    });

    for (final invalid in ['{not-json', '[]']) {
      test('rejeita JSON inválido ou sem objeto: $invalid', () {
        externalStatus.writeAsStringSync(invalid);
        final result = verify();
        expect(
          result.issues.map((issue) => issue.code),
          contains('invalid_json'),
        );
      });
    }

    for (final invalid in [
      <String, dynamic>{},
      <String, dynamic>{'schema_version': 1, 'release': {}},
    ]) {
      test('rejeita status incompleto: ${invalid.keys.join(',')}', () {
        externalStatus.writeAsStringSync(jsonEncode(invalid));
        final result = verify();
        expect(
          result.issues.map((issue) => issue.code),
          contains('invalid_release_status'),
        );
      });
    }

    final mutations =
        <String, ({String code, void Function(Map<String, dynamic>) change})>{
          'schema incompatível': (
            code: 'invalid_release_status',
            change: (status) => status['schema_version'] = 2,
          ),
          'evidência física incompleta': (
            code: 'invalid_release_evidence',
            change: (status) =>
                (status['required_physical_evidence'] as List).removeLast(),
          ),
          'evidência física pendente': (
            code: 'release_evidence_pending',
            change: (status) =>
                status['required_physical_evidence'][0]['status'] = 'pending',
          ),
          'freeze ativo': (
            code: 'release_build_frozen',
            change: (status) => status['release_build_allowed'] = false,
          ),
          'artefato de outra fonte': (
            code: 'artifact_superseded',
            change: (status) =>
                status['artifact']['matches_current_source'] = false,
          ),
          'upload não autorizado': (
            code: 'artifact_superseded',
            change: (status) => status['artifact']['upload_allowed'] = false,
          ),
          'hash divergente': (
            code: 'artifact_hash_mismatch',
            change: (status) => status['artifact']['sha256'] = '00',
          ),
          'versão diferente da fonte': (
            code: 'version_mismatch',
            change: (status) => status['release']['version_name'] = '9.9.9',
          ),
        };
    for (final mutation in mutations.entries) {
      test('mantém o gate de ${mutation.key}', () {
        mutate(mutation.value.change);
        final result = verify();
        expect(result.isReady, isFalse);
        expect(
          result.issues.map((issue) => issue.code),
          contains(mutation.value.code),
        );
      });
    }

    test('mantém os arquivos de assinatura obrigatórios', () {
      File('${root.path}/android/key.properties').deleteSync();
      final result = verify();
      expect(result.isReady, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        contains('missing_signing_properties'),
      );
    });

    test('mantém a configuração de produção exata', () {
      final config = File('${root.path}/config/production.json');
      final value =
          jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
      value['TUTOR_API_URL'] = 'http://127.0.0.1:8000';
      config.writeAsStringSync(jsonEncode(value));
      final result = verify();
      expect(
        result.issues.map((issue) => issue.code),
        contains('production_config_mismatch'),
      );
    });
  });
}

void _writeFixture(Directory root) {
  void write(String path, String value) {
    final file = File('${root.path}/$path')..createSync(recursive: true);
    file.writeAsStringSync(value);
  }

  write('pubspec.yaml', 'name: cartilhas_app\nversion: 1.4.0+13\n');
  write('android/app/build.gradle.kts', '''
namespace = "com.tutortds_cartilhas"
applicationId = "com.tutortds_cartilhas"
compileSdk = 36
minSdk = 24
targetSdk = 36
signingConfig = signingConfigs.getByName("release")
tasks.matching { it.name == "preReleaseBuild" }
validateReleaseProductionDefines(
validateReleaseFreezeState(rootProject.file(
''');
  write(
    'android/app/src/main/AndroidManifest.xml',
    '<application android:allowBackup="false" '
        'android:fullBackupContent="false" '
        'android:usesCleartextTraffic="false"/>',
  );
  write(
    'config/production.json',
    jsonEncode({
      'TUTOR_ENVIRONMENT': 'production',
      'TUTOR_GATEWAY_URL': 'https://tutor-tds-gateway.tdsipex.workers.dev',
      'TUTOR_API_URL': 'https://ead.ipexdesenvolvimento.cloud/tutor-api',
      'PRIVACY_POLICY_URL':
          'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html',
      'ACCOUNT_DELETION_URL':
          'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html',
      'REMOTE_CATALOG_ENABLED': false,
      'LEARNING_CONTEXT_ENABLED': false,
      'DURABLE_LEARNING_OUTBOX_ENABLED': false,
      'JOURNEY_TRACEABILITY_ENABLED': false,
      'DYNAMIC_ACTIVITY_ENABLED': false,
      'SIGNED_SUPPORT_IDENTITY': false,
      'PUSH_NOTIFICATIONS_ENABLED': false,
    }),
  );
  write(
    'android/key.properties',
    'storeFile=../upload-keystore.jks\n'
        'storePassword=test\nkeyPassword=test\nkeyAlias=upload\n',
  );
  write('android/upload-keystore.jks', 'fixture');
  write('android/upload_certificate.pem', 'fixture');
}

void _writeStatus(
  Directory root, {
  required bool buildAllowed,
  required String physicalStatus,
  required String artifactStatus,
  required bool uploadAllowed,
  String artifactPath = 'release/old.aab',
  String artifactSha = 'OLD',
}) {
  final file = File('${root.path}/release/release_status.json')
    ..createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode({
      'schema_version': 1,
      'release': {
        'application_id': 'com.tutortds_cartilhas',
        'version_name': '1.4.0',
        'version_code': 13,
        'min_sdk': 24,
        'target_sdk': 36,
        'compile_sdk': 36,
        'upload_certificate_sha256': 'AA',
      },
      'release_build_allowed': buildAllowed,
      'artifact': {
        'path': artifactPath,
        'sha256': artifactSha,
        'status': artifactStatus,
        'upload_allowed': uploadAllowed,
        'matches_current_source': artifactStatus == 'candidate',
      },
      'required_physical_evidence': [
        for (final id in [
          'certificate_human_approval_e2e',
          'classroom_cold_offline_android_e2e',
          'course_versioning_android_e2e',
          'evidence_offline_android_e2e',
          'pre_aab_xiaomi_smoke',
        ])
          {
            'id': id,
            'status': physicalStatus,
            'required_for_release_build': true,
          },
      ],
    }),
  );
}
