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
        'physical_evidence_pending',
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
      contains('invalid_physical_evidence'),
    );
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
      'SIGNED_SUPPORT_IDENTITY': false,
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
        {
          'id': 'evidence_offline_xiaomi',
          'status': physicalStatus,
          'required_for_release_build': true,
        },
      ],
    }),
  );
}
