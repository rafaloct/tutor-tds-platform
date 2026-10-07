import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

enum ReleaseIntent { audit, build, upload }

class ReleaseVerificationIssue {
  const ReleaseVerificationIssue(this.code, this.message);

  final String code;
  final String message;
}

class ReleaseVerificationResult {
  const ReleaseVerificationResult(this.issues);

  final List<ReleaseVerificationIssue> issues;
  bool get isReady => issues.isEmpty;
}

class ReleaseReadinessVerifier {
  ReleaseReadinessVerifier({
    required this.root,
    this.verifySigningIdentity = true,
  });

  final Directory root;
  final bool verifySigningIdentity;

  ReleaseVerificationResult verify(
    ReleaseIntent intent, {
    String? artifactPath,
  }) {
    final issues = <ReleaseVerificationIssue>[];
    final status = _readJson('release/release_status.json', issues);
    if (status == null) return ReleaseVerificationResult(issues);

    final release = _map(status['release']);
    final artifact = _map(status['artifact']);
    if (status['schema_version'] != 1 || release == null || artifact == null) {
      issues.add(
        const ReleaseVerificationIssue(
          'invalid_release_status',
          'release_status.json não segue o schema v1.',
        ),
      );
      return ReleaseVerificationResult(issues);
    }

    _verifySource(release, issues);
    _verifyProductionConfig(issues);
    _verifySigning(release, issues);

    const requiredPhysicalIds = {
      'certificate_human_approval_e2e',
      'classroom_cold_offline_android_e2e',
      'course_versioning_android_e2e',
      'evidence_offline_android_e2e',
      'pre_aab_xiaomi_smoke',
    };
    final physicalEvidence = status['required_physical_evidence'];
    final gates = <String, Map<String, dynamic>>{};
    var invalidPhysical = physicalEvidence is! List || physicalEvidence.isEmpty;
    if (physicalEvidence is List) {
      for (final item in physicalEvidence) {
        if (item is! Map<String, dynamic>) {
          invalidPhysical = true;
          continue;
        }
        final id = item['id'];
        if (id is! String ||
            id.isEmpty ||
            gates.containsKey(id) ||
            item['required_for_release_build'] is! bool ||
            item['status'] is! String ||
            (item['status'] as String).isEmpty) {
          invalidPhysical = true;
          continue;
        }
        gates[id] = item;
      }
    }
    if (requiredPhysicalIds.any(
      (id) => gates[id]?['required_for_release_build'] != true,
    )) {
      invalidPhysical = true;
    }
    if (invalidPhysical) {
      issues.add(
        const ReleaseVerificationIssue(
          'invalid_release_evidence',
          'Lista de gates Android de release incompleta ou inválida.',
        ),
      );
    }
    final pendingPhysical = gates.entries
        .where(
          (entry) =>
              entry.value['required_for_release_build'] == true &&
              entry.value['status'] != 'passed',
        )
        .map((entry) => entry.key)
        .toList();
    if (pendingPhysical.isNotEmpty) {
      final ids = pendingPhysical.join(', ');
      issues.add(
        ReleaseVerificationIssue(
          'release_evidence_pending',
          'Gate Android de release pendente: $ids.',
        ),
      );
    }

    if (status['release_build_allowed'] != true) {
      issues.add(
        const ReleaseVerificationIssue(
          'release_build_frozen',
          'Build release congelado em release_status.json.',
        ),
      );
    }

    if (intent == ReleaseIntent.upload || intent == ReleaseIntent.audit) {
      if (artifact['status'] != 'candidate' ||
          artifact['upload_allowed'] != true ||
          artifact['matches_current_source'] != true) {
        issues.add(
          ReleaseVerificationIssue(
            'artifact_superseded',
            'Artefato ${artifact['sha256'] ?? 'sem hash'} está '
                '${artifact['status'] ?? 'sem estado'} e não pode ser enviado.',
          ),
        );
      } else {
        _verifyArtifact(artifact, artifactPath: artifactPath, issues: issues);
      }
    }

    return ReleaseVerificationResult(issues);
  }

  void _verifySource(
    Map<String, dynamic> release,
    List<ReleaseVerificationIssue> issues,
  ) {
    final pubspec = _read('pubspec.yaml', issues);
    final gradle = _read('android/app/build.gradle.kts', issues);
    final manifest = _read('android/app/src/main/AndroidManifest.xml', issues);
    if (pubspec == null || gradle == null || manifest == null) return;

    final expectedVersion =
        '${release['version_name']}+${release['version_code']}';
    _expectPattern(
      pubspec,
      RegExp(
        '^version:\\s*${RegExp.escape(expectedVersion)}\\s*\$',
        multiLine: true,
      ),
      'version_mismatch',
      'pubspec.yaml deve declarar version $expectedVersion.',
      issues,
    );
    for (final entry in <String, Object?>{
      'applicationId': release['application_id'],
      'namespace': release['application_id'],
      'compileSdk': release['compile_sdk'],
      'minSdk': release['min_sdk'],
      'targetSdk': release['target_sdk'],
    }.entries) {
      final separator = entry.key == 'applicationId' || entry.key == 'namespace'
          ? '=\\s*"${RegExp.escape(entry.value.toString())}"'
          : '=\\s*${entry.value}';
      _expectPattern(
        gradle,
        RegExp('${entry.key}\\s*$separator'),
        '${entry.key.toLowerCase()}_mismatch',
        '${entry.key} diverge de release_status.json.',
        issues,
      );
    }
    for (final required in const [
      'signingConfig = signingConfigs.getByName("release")',
      'tasks.matching { it.name == "preReleaseBuild" }',
      'validateReleaseProductionDefines(',
      'validateReleaseFreezeState(rootProject.file(',
    ]) {
      if (!gradle.contains(required)) {
        issues.add(
          ReleaseVerificationIssue(
            'missing_release_gate',
            'Gate Android ausente: $required',
          ),
        );
      }
    }
    for (final required in const [
      'android:allowBackup="false"',
      'android:fullBackupContent="false"',
      'android:usesCleartextTraffic="false"',
    ]) {
      if (!manifest.contains(required)) {
        issues.add(
          ReleaseVerificationIssue(
            'unsafe_manifest_flag',
            'Manifest deve conter $required.',
          ),
        );
      }
    }
  }

  void _verifyProductionConfig(List<ReleaseVerificationIssue> issues) {
    final config = _readJson('config/production.json', issues);
    if (config == null) return;
    const expected = {
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
    };
    if (config.keys.any((key) => !expected.containsKey(key))) {
      issues.add(
        const ReleaseVerificationIssue(
          'production_config_mismatch',
          'Configuração de produção contém define não aprovado.',
        ),
      );
    }
    for (final entry in expected.entries) {
      if (config[entry.key] != entry.value) {
        issues.add(
          ReleaseVerificationIssue(
            'production_config_mismatch',
            '${entry.key} não corresponde ao destino produtivo aprovado.',
          ),
        );
      }
    }
    const forbidden = {
      'ANYTHING_LLM_API_KEY',
      'OPENAI_API_KEY',
      'ANTHROPIC_API_KEY',
      'GEMINI_API_KEY',
    };
    if (config.keys.any(forbidden.contains)) {
      issues.add(
        const ReleaseVerificationIssue(
          'secret_in_production_config',
          'Configuração de produção contém chave de provedor proibida.',
        ),
      );
    }
  }

  void _verifySigning(
    Map<String, dynamic> release,
    List<ReleaseVerificationIssue> issues,
  ) {
    final propertiesFile = _file('android/key.properties');
    final certificateFile = _file('android/upload_certificate.pem');
    if (!propertiesFile.existsSync()) {
      issues.add(
        const ReleaseVerificationIssue(
          'missing_signing_properties',
          'android/key.properties ausente; release seria não assinada localmente.',
        ),
      );
      return;
    }
    if (!certificateFile.existsSync()) {
      issues.add(
        const ReleaseVerificationIssue(
          'missing_upload_certificate',
          'android/upload_certificate.pem ausente.',
        ),
      );
      return;
    }
    final properties = _properties(propertiesFile.readAsLinesSync());
    const required = {'storeFile', 'storePassword', 'keyPassword', 'keyAlias'};
    if (required.any((key) => properties[key]?.trim().isEmpty ?? true)) {
      issues.add(
        const ReleaseVerificationIssue(
          'incomplete_signing_properties',
          'key.properties não possui todos os campos obrigatórios.',
        ),
      );
      return;
    }
    final store = File.fromUri(
      _file('android/app/.placeholder').uri.resolve(properties['storeFile']!),
    );
    if (!store.existsSync()) {
      issues.add(
        const ReleaseVerificationIssue(
          'missing_keystore',
          'Keystore indicado em key.properties não existe.',
        ),
      );
      return;
    }
    if (!verifySigningIdentity) return;

    final keytool = _findKeytool();
    if (keytool == null) {
      issues.add(
        const ReleaseVerificationIssue(
          'keytool_unavailable',
          'keytool indisponível; identidade da assinatura não pôde ser confirmada.',
        ),
      );
      return;
    }
    final certificateFingerprint = _keytoolFingerprint(keytool, [
      '-printcert',
      '-file',
      certificateFile.path,
    ]);
    final keystoreFingerprint = _keytoolFingerprint(
      keytool,
      [
        '-list',
        '-v',
        '-keystore',
        store.path,
        '-alias',
        properties['keyAlias']!,
        '-storepass:env',
        'TUTOR_VERIFY_STORE_PASSWORD',
        '-keypass:env',
        'TUTOR_VERIFY_KEY_PASSWORD',
      ],
      environment: {
        'TUTOR_VERIFY_STORE_PASSWORD': properties['storePassword']!,
        'TUTOR_VERIFY_KEY_PASSWORD': properties['keyPassword']!,
      },
    );
    final expected = _normalizeFingerprint(
      release['upload_certificate_sha256']?.toString() ?? '',
    );
    if (certificateFingerprint == null ||
        keystoreFingerprint == null ||
        certificateFingerprint != expected ||
        keystoreFingerprint != expected) {
      issues.add(
        const ReleaseVerificationIssue(
          'signing_identity_mismatch',
          'Certificado PEM, keystore e fingerprint aprovado não coincidem.',
        ),
      );
    }
  }

  void _verifyArtifact(
    Map<String, dynamic> artifact, {
    required String? artifactPath,
    required List<ReleaseVerificationIssue> issues,
  }) {
    final path = artifactPath ?? artifact['path']?.toString();
    if (path == null || path.isEmpty) {
      issues.add(
        const ReleaseVerificationIssue(
          'artifact_path_missing',
          'Caminho do AAB não informado.',
        ),
      );
      return;
    }
    final file = _file(path);
    if (!file.existsSync()) {
      issues.add(
        ReleaseVerificationIssue(
          'artifact_missing',
          'AAB não encontrado: $path',
        ),
      );
      return;
    }
    final actual = sha256
        .convert(file.readAsBytesSync())
        .toString()
        .toUpperCase();
    final expected = artifact['sha256']?.toString().toUpperCase();
    if (actual != expected) {
      issues.add(
        const ReleaseVerificationIssue(
          'artifact_hash_mismatch',
          'SHA-256 do AAB diverge de release_status.json.',
        ),
      );
    }
  }

  Map<String, dynamic>? _readJson(
    String path,
    List<ReleaseVerificationIssue> issues,
  ) {
    final raw = _read(path, issues);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Object {
      // Reporta abaixo sem vazar conteúdo local.
    }
    issues.add(
      ReleaseVerificationIssue('invalid_json', 'JSON inválido: $path'),
    );
    return null;
  }

  String? _read(String path, List<ReleaseVerificationIssue> issues) {
    final file = _file(path);
    if (!file.existsSync()) {
      issues.add(
        ReleaseVerificationIssue(
          'required_file_missing',
          'Arquivo ausente: $path',
        ),
      );
      return null;
    }
    return file.readAsStringSync();
  }

  File _file(String path) => File.fromUri(root.uri.resolve(path));

  void _expectPattern(
    String source,
    RegExp pattern,
    String code,
    String message,
    List<ReleaseVerificationIssue> issues,
  ) {
    if (!pattern.hasMatch(source)) {
      issues.add(ReleaseVerificationIssue(code, message));
    }
  }

  Map<String, String> _properties(List<String> lines) => {
    for (final line in lines)
      if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        if (line.indexOf('=') > 0)
          line.substring(0, line.indexOf('=')).trim(): line
              .substring(line.indexOf('=') + 1)
              .trim(),
  };

  String? _findKeytool() {
    final executable = Platform.isWindows ? 'keytool.exe' : 'keytool';
    final candidates = <String>[
      if (Platform.environment['JAVA_HOME'] case final home?)
        '$home${Platform.pathSeparator}bin${Platform.pathSeparator}$executable',
      if (Platform.isWindows)
        'C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\keytool.exe',
      executable,
    ];
    for (final candidate in candidates) {
      if (candidate == executable) {
        try {
          final result = Process.runSync(candidate, const ['-help']);
          if (result.exitCode == 0) return candidate;
        } on ProcessException {
          // Tenta o próximo local conhecido.
        }
      } else if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  String? _keytoolFingerprint(
    String keytool,
    List<String> arguments, {
    Map<String, String>? environment,
  }) {
    final result = Process.runSync(
      keytool,
      arguments,
      environment: environment,
      includeParentEnvironment: true,
    );
    if (result.exitCode != 0) return null;
    final match = RegExp(
      r'SHA256:\s*([0-9A-Fa-f:]{64,})',
    ).firstMatch('${result.stdout}\n${result.stderr}');
    return match == null ? null : _normalizeFingerprint(match.group(1)!);
  }

  String _normalizeFingerprint(String value) =>
      value.replaceAll(':', '').trim().toUpperCase();
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

void main(List<String> arguments) {
  var intent = ReleaseIntent.audit;
  var rootPath = Directory.current.path;
  String? artifactPath;
  for (final argument in arguments) {
    if (argument.startsWith('--intent=')) {
      intent = ReleaseIntent.values.byName(argument.substring(9));
    } else if (argument.startsWith('--root=')) {
      rootPath = argument.substring(7);
    } else if (argument.startsWith('--artifact=')) {
      artifactPath = argument.substring(11);
    }
  }
  final result = ReleaseReadinessVerifier(
    root: Directory(rootPath),
  ).verify(intent, artifactPath: artifactPath);
  if (result.isReady) {
    stdout.writeln('Release ${intent.name}: READY.');
    return;
  }
  stderr.writeln('Release ${intent.name}: BLOCKED.');
  for (final issue in result.issues) {
    stderr.writeln('- [${issue.code}] ${issue.message}');
  }
  exitCode = 1;
}
