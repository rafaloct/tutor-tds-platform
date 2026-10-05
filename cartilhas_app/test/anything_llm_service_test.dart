import 'dart:convert';

import 'package:cartilhas_app/services/anything_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends the focused chat contract and accepts text response', () async {
    late http.Request captured;
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example/',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'text': 'Resposta TDS'}), 200);
      }),
    );

    final response = await service.getChatResponse(
      'Como funciona?',
      mode: 'adaptive',
      context: 'Cooperativismo',
    );

    expect(response, 'Resposta TDS');
    expect(captured.url.toString(), 'https://gateway.example/v1/chat');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'message': 'Como funciona?',
      'mode': 'adaptive',
      'context': 'Cooperativismo',
    });
  });

  test(
    'keeps the app usable with fallback on observable gateway failures',
    () async {
      final service = AnythingLLMService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient(
          (_) async => http.Response('{"error":"rate_limited"}', 429),
        ),
      );

      final response = await service.getChatResponse('Pergunta');

      expect(response, contains('temporariamente indisponível'));
    },
  );

  test(
    'does not send empty context and handles an empty successful response',
    () async {
      late http.Request captured;
      final service = AnythingLLMService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"text":""}', 200);
        }),
      );

      final response = await service.getChatResponse('Pergunta', context: '  ');

      expect(jsonDecode(captured.body), {
        'message': 'Pergunta',
        'mode': 'tutor',
      });
      expect(
        response,
        'O Tutor não encontrou uma resposta. Tente reformular a pergunta.',
      );
    },
  );
}
