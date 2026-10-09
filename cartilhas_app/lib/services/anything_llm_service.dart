import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cartilhas_app/models/tutor_learning_context.dart';

/// Resultado tipado do chat do Tutor: a UI precisa distinguir uma resposta
/// educacional real de uma indisponibilidade para não renderizar erro como
/// resposta normal com ações de quiz/cartões/feedback.
enum TutorChatStatus { answer, emptyAnswer, unavailable }

class TutorChatResult {
  const TutorChatResult(this.status, this.text);

  final TutorChatStatus status;
  final String text;

  bool get isAnswer => status == TutorChatStatus.answer;

  static const emptyAnswerText =
      'O Tutor não encontrou uma resposta. Tente reformular a pergunta.';
  static const unavailableText =
      'O Tutor de IA está temporariamente indisponível. Continue pelas cartilhas ou fale com a equipe TDS pelo suporte.';
}

/// Cliente do gateway do Tutor. Credenciais e seleção do modelo nunca fazem
/// parte deste aplicativo; elas permanecem no Cloudflare e no AnythingLLM.
class AnythingLLMService {
  final String gatewayUrl;
  final http.Client _client;

  AnythingLLMService({required this.gatewayUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<TutorChatResult> getChatResponse(
    String message, {
    String mode = 'tutor',
    String? context,
    TutorLearningContext? learningContext,
  }) async {
    if (gatewayUrl.isEmpty) {
      return const TutorChatResult(
        TutorChatStatus.unavailable,
        TutorChatResult.unavailableText,
      );
    }

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
        Object? data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
        final text = data is Map<String, dynamic>
            ? data['text'] ?? data['textResponse']
            : null;
        if (text is String && text.trim().isNotEmpty) {
          return TutorChatResult(TutorChatStatus.answer, text);
        }
        return const TutorChatResult(
          TutorChatStatus.emptyAnswer,
          TutorChatResult.emptyAnswerText,
        );
      }

      return const TutorChatResult(
        TutorChatStatus.unavailable,
        TutorChatResult.unavailableText,
      );
    } on ArgumentError {
      return const TutorChatResult(
        TutorChatStatus.unavailable,
        TutorChatResult.unavailableText,
      );
    } on Exception {
      return const TutorChatResult(
        TutorChatStatus.unavailable,
        TutorChatResult.unavailableText,
      );
    }
  }
}
