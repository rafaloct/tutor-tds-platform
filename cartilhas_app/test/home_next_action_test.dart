import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('retornar do menu atualiza acesso sem Future no setState', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(courseLoader: () async => [])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Como usar'));
    await tester.pumpAndSettle();
    expect(find.text('Como usar o App TDS'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Tutor TDS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsOneWidget);
  });

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

  testWidgets('Home permanece legível em telefone estreito com fonte 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      'user_name': 'Maria da Silva',
      'user_cpf': '12345678901',
      'onboarding_seen_v1': true,
    });

    await tester.pumpWidget(
      Provider<StudyAiService>.value(
        value: StudyAiService(gatewayUrl: 'https://gateway.example'),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: HomeScreen(courseLoader: () async => [_sampleCartilha()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tutor TDS'), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Glossário')).tooltip,
      'Glossário',
    );
    await tester.scrollUntilVisible(
      find.text('Estudar com IA'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Estudar com IA'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

Cartilha _sampleCartilha() => Cartilha(
  id: 'agricultura-sustentavel',
  title: 'Agricultura Sustentável',
  author: 'TDS 2026',
  sections: [
    Section(
      id: 'introducao',
      title: 'Introdução',
      messages: [Message(type: 'bot', content: 'Conteúdo local de teste.')],
    ),
  ],
);
