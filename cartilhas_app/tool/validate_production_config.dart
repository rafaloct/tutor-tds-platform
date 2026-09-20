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
  } on Object catch (error) {
    stderr.writeln('JSON de produção inválido: $error');
    exitCode = 2;
    return;
  }

  const forbidden = {
    'ANYTHING_LLM_API_KEY',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'GEMINI_API_KEY',
  };
  final leakedKeys = config.keys.where(forbidden.contains).toList();
  if (leakedKeys.isNotEmpty) {
    stderr.writeln(
      'Build bloqueado: remova segredos do AAB (${leakedKeys.join(', ')}).',
    );
    exitCode = 1;
    return;
  }

  final rawGateway = config['TUTOR_GATEWAY_URL'];
  final gateway = rawGateway is String ? Uri.tryParse(rawGateway) : null;
  if (gateway == null || gateway.scheme != 'https' || gateway.host.isEmpty) {
    stderr.writeln('TUTOR_GATEWAY_URL deve ser uma URL HTTPS válida.');
    exitCode = 1;
    return;
  }

  final rawApi = config['TUTOR_API_URL'];
  final api = rawApi is String ? Uri.tryParse(rawApi) : null;
  if (api == null || api.scheme != 'https' || api.host.isEmpty) {
    stderr.writeln(
      'TUTOR_API_URL deve ser uma URL HTTPS válida; conta e analytics não podem ficar desconectados em produção.',
    );
    exitCode = 1;
    return;
  }

  for (final key in const ['PRIVACY_POLICY_URL', 'ACCOUNT_DELETION_URL']) {
    final rawValue = config[key];
    final value = rawValue is String ? Uri.tryParse(rawValue) : null;
    if (value == null || value.scheme != 'https' || value.host.isEmpty) {
      stderr.writeln('$key deve ser uma URL HTTPS pública e válida.');
      exitCode = 1;
      return;
    }
  }

  stdout.writeln(
    'Configuração de produção validada: nenhum segredo de IA será compilado.',
  );
}
