import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_models.dart';

class StudyAiException implements Exception {
  const StudyAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudyAiService {
  StudyAiService({required this.gatewayUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String gatewayUrl;
  final http.Client _client;

  Future<FlashcardDeck> generateFlashcards({
    required String topic,
    StudyDifficulty difficulty = StudyDifficulty.intermediate,
    int count = 8,
  }) async {
    final material = await _generate(
      kind: 'flashcards',
      topic: topic,
      difficulty: difficulty,
      count: count,
    );
    return FlashcardDeck.fromJson(material);
  }

  Future<AssessmentDeck> generateQuiz({
    required String topic,
    StudyDifficulty difficulty = StudyDifficulty.intermediate,
    int count = 5,
  }) async {
    final material = await _generate(
      kind: 'quiz',
      topic: topic,
      difficulty: difficulty,
      count: count,
    );
    return AssessmentDeck.fromJson(material);
  }

  Future<AssessmentDeck> generateExam({
    required String topic,
    StudyDifficulty difficulty = StudyDifficulty.intermediate,
    int count = 10,
  }) async {
    final material = await _generate(
      kind: 'exam',
      topic: topic,
      difficulty: difficulty,
      count: count,
    );
    return AssessmentDeck.fromJson(material);
  }

  Future<StudySummary> generateSummary({
    required String topic,
    SummaryLength length = SummaryLength.quick,
  }) async {
    final material = await _generate(
      kind: 'summary',
      topic: topic,
      summaryLength: length,
    );
    return StudySummary.fromJson(material);
  }

  Future<Map<String, dynamic>> _generate({
    required String kind,
    required String topic,
    StudyDifficulty? difficulty,
    SummaryLength? summaryLength,
    int? count,
  }) async {
    if (gatewayUrl.isEmpty) {
      throw const StudyAiException(
        'Os recursos de IA estão temporariamente indisponíveis.',
      );
    }
    final base = gatewayUrl.endsWith('/')
        ? gatewayUrl.substring(0, gatewayUrl.length - 1)
        : gatewayUrl;

    try {
      final response = await _client
          .post(
            Uri.parse('$base/v1/study'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'kind': kind,
              'topic': topic,
              'difficulty': ?difficulty?.apiValue,
              'summaryLength': ?summaryLength?.apiValue,
              'count': ?count,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode != 200) {
        throw const StudyAiException(
          'Não foi possível criar o material agora. Tente novamente em instantes.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final material = data['material'];
      if (material is! Map<String, dynamic>) {
        throw const StudyAiException(
          'A IA retornou um material incompleto. Tente novamente.',
        );
      }
      return material;
    } on StudyAiException {
      rethrow;
    } on Exception {
      throw const StudyAiException(
        'Não foi possível conectar ao Tutor. Verifique sua internet e tente novamente.',
      );
    }
  }

  void dispose() => _client.close();
}
