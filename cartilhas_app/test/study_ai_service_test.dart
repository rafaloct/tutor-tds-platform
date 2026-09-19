import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends only the study contract and parses flashcards', () async {
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

  test('returns a safe error when the gateway fails', () async {
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
