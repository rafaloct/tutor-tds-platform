import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/features/study_ai/presentation/assessment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final sampleDeck = AssessmentDeck(
    title: 'Quiz de Manejo Agroecológico',
    durationMinutes: 10,
    items: [
      StudyQuestion(
        question: 'Qual é o melhor método de irrigação para economizar água?',
        options: [
          'Aspersão ampla',
          'Inundação',
          'Gotejamento',
          'Manual com balde',
        ],
        correctIndex: 2,
        explanation:
            'O gotejamento direciona água diretamente à raiz sem desperdício.',
        topic: 'Irrigação sustentável',
      ),
      StudyQuestion(
        question: 'O que é cobertura morta (mulching)?',
        options: [
          'Palha sobre o solo',
          'Pesticida químico',
          'Adubo mineral',
          'Esterco fresco',
        ],
        correctIndex: 0,
        explanation:
            'A cobertura morta protege a umidade do solo e evita erosão.',
        topic: 'Conservação do solo',
      ),
    ],
  );

  Widget createWidget({
    required StudyAiService service,
    AssessmentMode mode = AssessmentMode.quiz,
    String topic = 'Manejo Agroecológico',
    String courseId = 'manejo-agroecologico',
    AssessmentAttemptRepository repository =
        const AssessmentAttemptRepository(),
    AssessmentAttempt? initialAttempt,
  }) {
    return Provider<StudyAiService>.value(
      value: service,
      child: MaterialApp(
        home: AssessmentScreen(
          topic: topic,
          courseId: courseId,
          mode: mode,
          repository: repository,
          initialAttempt: initialAttempt,
        ),
      ),
    );
  }

  testWidgets(
    'sem tentativa salva, exibe configuração inicial sem chamada de IA',
    (tester) async {
      var aiCalled = false;
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          aiCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(createWidget(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Pratique com um quiz'), findsOneWidget);
      expect(find.text('Gerar quiz'), findsOneWidget);
      expect(find.text('Retomar quiz em andamento'), findsNothing);
      expect(aiCalled, isFalse);
    },
  );

  testWidgets(
    'com tentativa em andamento, permite retomar questão sem nova chamada de IA',
    (tester) async {
      const repository = AssessmentAttemptRepository();
      final attempt = AssessmentAttempt(
        id: 'attempt-agro-1',
        courseId: 'manejo-agroecologico',
        topic: 'Manejo Agroecológico',
        mode: AssessmentMode.quiz,
        difficulty: StudyDifficulty.intermediate,
        totalQuestions: 2,
        deck: sampleDeck,
        answers: {0: 2}, // Primeira respondida corretamente
        currentIndex: 1, // Parou na segunda
        remainingSeconds: 0,
        score: 1,
        weakTopics: const [],
        isCompleted: false,
        createdAt: DateTime.utc(2026, 9, 19, 14),
        updatedAt: DateTime.utc(2026, 9, 19, 14, 5),
      );
      await repository.save(attempt);

      var aiCalled = false;
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          aiCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        createWidget(service: service, repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tentativa em andamento'), findsOneWidget);
      expect(find.text('Retomar quiz em andamento'), findsOneWidget);
      expect(aiCalled, isFalse);

      // Toca em retomar
      await tester.tap(find.text('Retomar quiz em andamento'));
      await tester.pumpAndSettle();

      expect(find.text('O que é cobertura morta (mulching)?'), findsOneWidget);
      expect(find.text('Palha sobre o solo'), findsOneWidget);
      expect(aiCalled, isFalse);

      // Responde à segunda questão (índice 0 = 'Palha sobre o solo', correta)
      await tester.tap(find.text('Palha sobre o solo'));
      await tester.pumpAndSettle();

      // Finaliza
      await tester.ensureVisible(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('2 de 2 respostas corretas'), findsOneWidget);

      // Verifica persistência final
      final updated = await repository.load(
        'manejo-agroecologico',
        AssessmentMode.quiz,
      );
      expect(updated, isNotNull);
      expect(updated?.isCompleted, isTrue);
      expect(updated?.score, 2);
    },
  );

  testWidgets('gera nova tentativa com IA e persiste no repositório', (
    tester,
  ) async {
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'material': {
              'title': sampleDeck.title,
              'durationMinutes': sampleDeck.durationMinutes,
              'items': sampleDeck.items.map((i) => i.toJson()).toList(),
            },
          }),
          200,
        );
      }),
    );

    const repository = AssessmentAttemptRepository();
    await tester.pumpWidget(
      createWidget(service: service, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gerar quiz'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Qual é o melhor método de irrigação para economizar água?'),
      findsOneWidget,
    );

    final saved = await repository.load(
      'manejo-agroecologico',
      AssessmentMode.quiz,
    );
    expect(saved, isNotNull);
    expect(saved?.isCompleted, isFalse);
    expect(saved?.totalQuestions, 2);
  });
}
