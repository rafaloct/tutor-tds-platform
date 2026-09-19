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

  stdout.writeln(
    'Configuração de produção validada: nenhum segredo de IA será compilado.',
  );
}
