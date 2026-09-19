import 'package:cartilhas_app/features/study_ai/presentation/assessment_feedback_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feedback informa explicação, fonte e próxima ação', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssessmentFeedbackCard(
            isCorrect: false,
            explanation: 'A alternativa correta considera os custos fixos.',
            source: 'Educação financeira',
            isLastQuestion: false,
          ),
        ),
      ),
    );

    expect(find.text('Vamos revisar'), findsOneWidget);
    expect(
      find.text('A alternativa correta considera os custos fixos.'),
      findsOneWidget,
    );
    expect(find.text('Fonte: Educação financeira'), findsOneWidget);
    expect(find.textContaining('Próxima ação:'), findsOneWidget);
  });
}
