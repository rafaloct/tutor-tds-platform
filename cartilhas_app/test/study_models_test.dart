import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an immutable flashcard deck', () {
    final deck = FlashcardDeck.fromJson({
      'title': 'Cooperativismo',
      'items': [
        {'front': 'O que é cooperação?', 'back': 'Trabalho em conjunto.'},
      ],
    });

    expect(deck.title, 'Cooperativismo');
    expect(deck.items.single.front, 'O que é cooperação?');
    expect(() => deck.items.add(deck.items.single), throwsUnsupportedError);
  });

  test('parses assessment and summary structures', () {
    final assessment = AssessmentDeck.fromJson({
      'title': 'Quiz',
      'durationMinutes': 10,
      'items': [
        {
          'question': 'Pergunta?',
          'options': ['A', 'B', 'C', 'D'],
          'correctIndex': 2,
          'explanation': 'Explicação',
          'topic': 'Tema',
        },
      ],
    });
    final summary = StudySummary.fromJson({
      'title': 'Resumo',
      'overview': 'Visão geral',
      'keyPoints': ['Ponto'],
      'practicalExamples': ['Exemplo'],
      'reviewQuestions': ['Pergunta'],
    });

    expect(assessment.items.single.correctIndex, 2);
    expect(assessment.items.single.options, hasLength(4));
    expect(summary.keyPoints, ['Ponto']);
  });
}
