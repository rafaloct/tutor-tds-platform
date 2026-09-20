import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mostra tentativa recente como próxima ação na Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'user_name': 'Maria da Silva',
      'user_cpf': '12345678901',
      'onboarding_seen_v1': true,
    });

    const repository = AssessmentAttemptRepository();
    await repository.save(
      AssessmentAttempt(
        id: 'quiz-agro-1',
        courseId: 'agricultura-sustentavel',
        topic: 'Agricultura Sustentável',
        mode: AssessmentMode.quiz,
        difficulty: StudyDifficulty.intermediate,
        totalQuestions: 5,
        deck: AssessmentDeck(
          title: 'Quiz de Agricultura',
          durationMinutes: 10,
          items: [
            StudyQuestion(
              question: 'Questão?',
              options: ['A', 'B'],
              correctIndex: 0,
              explanation: 'Ex',
              topic: 'T',
            ),
          ],
        ),
        answers: {0: 0},
        currentIndex: 0,
        remainingSeconds: 0,
        score: 1,
        weakTopics: const [],
        isCompleted: false,
        createdAt: DateTime.utc(2026, 9, 19, 10),
        updatedAt: DateTime.utc(2026, 9, 19, 10, 5),
      ),
    );

    await tester.pumpWidget(
      Provider<StudyAiService>.value(
        value: StudyAiService(gatewayUrl: 'https://gateway.example'),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect(find.text('Continuar quiz'), findsOneWidget);
    expect(find.text('Agricultura Sustentável'), findsWidgets);
    expect(find.byKey(const ValueKey('supporter_logo_ipex')), findsOneWidget);
    expect(find.byKey(const ValueKey('supporter_logo_uft')), findsOneWidget);
    expect(find.byKey(const ValueKey('supporter_logo_fapto')), findsOneWidget);
    expect(find.byKey(const ValueKey('supporter_logo_cdr')), findsOneWidget);
  });
}
