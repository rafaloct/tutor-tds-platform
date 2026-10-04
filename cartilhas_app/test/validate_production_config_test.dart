import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('production-config-validator-');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('aceita contrato canônico com push explicitamente desativado', () {
    final result = _run(root, _canonicalConfig());

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      result.stdout.toString(),
      contains('Configuração de produção validada para preflight'),
    );
  });

  test('rejeita push habilitado em produção', () {
    final config = _canonicalConfig()..['PUSH_NOTIFICATIONS_ENABLED'] = true;

    final result = _run(root, config);

    expect(result.exitCode, 1);
  });

  test('rejeita ausência da flag push obrigatória', () {
    final config = _canonicalConfig()..remove('PUSH_NOTIFICATIONS_ENABLED');

    final result = _run(root, config);

    expect(result.exitCode, 1);
  });

  test('rejeita campo extra não aprovado', () {
    final config = _canonicalConfig()..['EXTRA_FIELD'] = 'not-approved';

    final result = _run(root, config);

    expect(result.exitCode, 1);
  });
}

ProcessResult _run(Directory root, Map<String, Object> config) {
  final file = File('${root.path}/production.json')
    ..writeAsStringSync(jsonEncode(config));
  return Process.runSync('dart', [
    'tool/validate_production_config.dart',
    file.path,
  ], workingDirectory: Directory.current.path);
}

Map<String, Object> _canonicalConfig() => {
  'TUTOR_ENVIRONMENT': 'production',
  'TUTOR_API_URL': 'https://ead.ipexdesenvolvimento.cloud/tutor-api',
  'TUTOR_GATEWAY_URL': 'https://tutor-tds-gateway.tdsipex.workers.dev',
  'PRIVACY_POLICY_URL':
      'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html',
  'ACCOUNT_DELETION_URL':
      'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html',
  'REMOTE_CATALOG_ENABLED': false,
  'LEARNING_CONTEXT_ENABLED': false,
  'DURABLE_LEARNING_OUTBOX_ENABLED': false,
  'JOURNEY_TRACEABILITY_ENABLED': false,
  'SIGNED_SUPPORT_IDENTITY': false,
  'PUSH_NOTIFICATIONS_ENABLED': false,
};
