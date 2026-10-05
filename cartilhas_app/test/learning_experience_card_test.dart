import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/services/anything_llm_service.dart';
import 'package:cartilhas_app/widgets/learning_experience_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all generic experience kinds render with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final entry in <(ExperienceKind, String)>[
      (ExperienceKind.scenario, 'Situação para explorar'),
      (ExperienceKind.reveal, 'Descubra a ideia-chave'),
      (ExperienceKind.reflection, 'Reflexão'),
      (ExperienceKind.actionChallenge, 'Desafio de ação'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: LearningExperienceCard(
              experience: ExperienceBlock(
                kind: entry.$1,
                objective: 'Objetivo contextualizado e acessível.',
              ),
            ),
          ),
        ),
      );
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        find.text('Objetivo contextualizado e acessível.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('practice action is explicitly non-assessed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LearningExperienceCard(
            experience: ExperienceBlock(
              kind: ExperienceKind.actionChallenge,
              objective: 'Defina um próximo passo.',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Marcar pequeno passo'));
    await tester.pump();
    expect(
      find.textContaining(
        'não conta como avaliação, presença, frequência ou certificado',
      ),
      findsOneWidget,
    );
  });

  test('an unavailable Tutor IA has a non-blocking fallback', () async {
    final response = await AnythingLLMService(gatewayUrl: '').getChatResponse(
      'Pergunta sintética',
      context: 'Cartilha: conteúdo sintético',
    );
    expect(response, contains('temporariamente indisponível'));
  });
}
