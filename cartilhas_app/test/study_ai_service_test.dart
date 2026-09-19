import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('envia somente o contrato de estudo e interpreta flashcards', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://gateway.example/v1/study');
      expect(request.headers['content-type'], 'application/json');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'material': {
            'title': 'Deck',
            'items': [
              {'front': 'Frente', 'back': 'Verso', 'hint': 'Dica'},
            ],
          },
        }),
        200,
      );
    });
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example/',
      client: client,
    );

    final deck = await service.generateFlashcards(topic: 'Tema TDS');

    expect(
      requestBody.keys,
      containsAll(['kind', 'topic', 'difficulty', 'count']),
    );
    expect(requestBody, isNot(contains('apiKey')));
    expect(deck.items.single.back, 'Verso');
    service.dispose();
  });

  test('envia fonte, dificuldade e quantidade escolhidas', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'material': {
            'title': 'Revisão',
            'items': [
              {'front': 'Pergunta', 'back': 'Resposta', 'hint': 'Dica'},
            ],
          },
        }),
        200,
      );
    });
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: client,
    );

    final deck = await service.generateFlashcards(
      topic: 'Agricultura sustentável',
      difficulty: StudyDifficulty.advanced,
      count: 12,
    );

    expect(requestBody['kind'], 'flashcards');
    expect(requestBody['topic'], 'Agricultura sustentável');
    expect(requestBody['difficulty'], 'advanced');
    expect(requestBody['count'], 12);
    expect(deck.items, hasLength(1));
    service.dispose();
  });

  test('retorna erro seguro quando o gateway falha', () async {
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async => http.Response('internal details', 500)),
    );

    expect(
      () => service.generateSummary(topic: 'Tema'),
      throwsA(
        isA<StudyAiException>().having(
          (error) => error.message,
          'message',
          isNot(contains('internal details')),
        ),
      ),
    );
    service.dispose();
  });
}
