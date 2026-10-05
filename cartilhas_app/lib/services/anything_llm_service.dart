import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cartilhas_app/models/tutor_learning_context.dart';

/// Cliente do gateway do Tutor. Credenciais e seleção do modelo nunca fazem
/// parte deste aplicativo; elas permanecem no Cloudflare e no AnythingLLM.
class AnythingLLMService {
  final String gatewayUrl;
  final http.Client _client;

  AnythingLLMService({required this.gatewayUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<String> getChatResponse(
    String message, {
    String mode = 'tutor',
    String? context,
    TutorLearningContext? learningContext,
  }) async {
    if (gatewayUrl.isEmpty) return _friendlyUnavailableMessage;

    try {
      final normalizedGatewayUrl = gatewayUrl.endsWith('/')
          ? gatewayUrl.substring(0, gatewayUrl.length - 1)
          : gatewayUrl;
      final url = Uri.parse('$normalizedGatewayUrl/v1/chat');
      final body = {
        'message': message,
        'mode': mode,
        if (learningContext == null &&
            context != null &&
            context.trim().isNotEmpty)
          'context': context.trim(),
        if (learningContext != null)
          'learning_context': learningContext.toJson(),
      };
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] ?? data['textResponse'];
        if (text is String && text.trim().isNotEmpty) return text;
        return 'O Tutor não encontrou uma resposta. Tente reformular a pergunta.';
      }

      return _friendlyUnavailableMessage;
    } on ArgumentError {
      return _friendlyUnavailableMessage;
    } on Exception {
      return _friendlyUnavailableMessage;
    }
  }

  static const _friendlyUnavailableMessage =
      'O Tutor de IA está temporariamente indisponível. Continue pelas cartilhas ou fale com a equipe TDS pelo suporte.';
}
