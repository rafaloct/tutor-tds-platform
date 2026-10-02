import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'config/production.json' : arguments.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Configuração não encontrada: $path');
    exitCode = 2;
    return;
  }

  late final Map<String, dynamic> config;
  try {
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on Object {
    stderr.writeln('JSON de produção inválido.');
    exitCode = 2;
    return;
  }

  const expected = <String, Object>{
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
  };
  if (config.length != expected.length ||
      expected.entries.any((entry) => config[entry.key] != entry.value)) {
    stderr.writeln(
      'Build bloqueado: configuração de produção contém endpoint, flag ou campo não aprovado.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Configuração de produção validada para preflight; gates de release ainda são obrigatórios.',
  );
}
