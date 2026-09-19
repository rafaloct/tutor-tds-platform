import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente do gateway do Tutor. Credenciais e seleção do modelo nunca fazem
/// parte deste aplicativo; elas permanecem no Cloudflare e no AnythingLLM.
class AnythingLLMService {
  final String gatewayUrl;

  AnythingLLMService({required this.gatewayUrl});

  Future<String> getChatResponse(
    String message, {
    String mode = 'tutor',
    String? context,
  }) async {
    if (gatewayUrl.isEmpty) return _friendlyUnavailableMessage;

    final normalizedGatewayUrl = gatewayUrl.endsWith('/')
        ? gatewayUrl.substring(0, gatewayUrl.length - 1)
        : gatewayUrl;
    final url = Uri.parse('$normalizedGatewayUrl/v1/chat');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'mode': mode,
              if (context != null && context.trim().isNotEmpty)
                'context': context.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] ?? data['textResponse'];
        if (text is String && text.trim().isNotEmpty) return text;
        return 'O Tutor não encontrou uma resposta. Tente reformular a pergunta.';
      }

      return _friendlyUnavailableMessage;
    } on Exception {
      return _friendlyUnavailableMessage;
    }
  }

  static const _friendlyUnavailableMessage =
      'O Tutor de IA está temporariamente indisponível. Continue pelas cartilhas ou fale com a equipe TDS pelo suporte.';
}
