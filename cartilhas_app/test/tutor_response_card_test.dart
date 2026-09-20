import 'package:cartilhas_app/widgets/tutor_response_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra resposta em camadas, contexto, ações e feedback', (
    tester,
  ) async {
    TutorResponseFeedback? feedback;
    String? followUp;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TutorResponseCard(
              text:
                  'Resposta curta e objetiva.\n\nDetalhe que aprofunda a explicação.',
              contextLabel: 'Manejo da água',
              onListen: () {},
              onCreateCards: () {},
              onPracticeQuiz: () {},
              onContinue: () {},
              onFollowUp: (value) => followUp = value,
              onFeedback: (value) => feedback = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Resposta direta'), findsOneWidget);
    expect(find.text('Entenda melhor'), findsOneWidget);
    expect(find.textContaining('Contexto enviado ao Tutor'), findsOneWidget);
    expect(find.text('Criar cartões'), findsOneWidget);
    expect(find.text('Praticar quiz'), findsOneWidget);

    await tester.tap(find.text('Mostre um exemplo'));
    expect(followUp, contains('exemplo prático'));

    await tester.tap(find.byTooltip('Útil'));
    await tester.pump();
    expect(feedback, TutorResponseFeedback.useful);
    expect(find.text('Feedback registrado'), findsOneWidget);
  });

  testWidgets('declara ausência de fonte quando gateway não informa citação', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorResponseCard(
            text: 'Resposta.',
            onListen: () {},
            onCreateCards: () {},
            onPracticeQuiz: () {},
            onContinue: () {},
            onFollowUp: (_) {},
            onFeedback: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.textContaining('não informou uma fonte específica'),
      findsOneWidget,
    );
  });
}
