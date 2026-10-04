import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/widgets/learning_experience_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scenario card renders adult prompt and accessible choices', (
    tester,
  ) async {
    final message = Message(
      type: 'scenario',
      content: 'Você recebeu R$ 450 e ainda tem contas pela frente.',
      options: [
        Option(label: 'Separar primeiro o necessário', value: 'a'),
        Option(label: 'Gastar e decidir depois', value: 'b'),
      ],
    );

    Option? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LearningExperienceCard(message: message),
              LearningExperienceChoices(
                message: message,
                enabled: true,
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Situação real'), findsOneWidget);
    expect(find.text('O que você faria?'), findsOneWidget);
    expect(find.text('Separar primeiro o necessário'), findsOneWidget);

    await tester.tap(find.text('Separar primeiro o necessário'));
    expect(selected?.value, 'a');
  });

  testWidgets('learning experience remains usable at 2x text scale', (
    tester,
  ) async {
    final message = Message(
      type: 'reflection',
      content: 'Qual situação mais se parece com a sua rotina financeira?',
      options: [
        Option(label: 'Eu acompanho os gastos', value: 'a'),
        Option(label: 'Nem sempre sei para onde foi', value: 'b'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LearningExperienceCard(message: message),
                  LearningExperienceChoices(
                    message: message,
                    enabled: true,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('E na sua realidade?'), findsOneWidget);
    expect(find.text('Eu acompanho os gastos'), findsOneWidget);
  });

  test('new learning types are exploratory, not assessment questions', () {
    for (final type in [
      'scenario',
      'reveal',
      'reflection',
      'action_challenge',
    ]) {
      final message = Message(type: type, content: 'Teste');
      expect(message.isAssessmentQuestion, isFalse);
      expect(isLearningExperienceType(type), isTrue);
    }

    expect(Message(type: 'question', content: 'Q').isAssessmentQuestion, isTrue);
    expect(Message(type: 'quiz', content: 'Q').isAssessmentQuestion, isTrue);
  });
}
