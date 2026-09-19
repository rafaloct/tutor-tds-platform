import 'package:cartilhas_app/widgets/tutor_conversation_starter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('oferece ações locais e envia somente a ação escolhida', (
    tester,
  ) async {
    String? selectedPrompt;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorConversationStarter(
            contextLabel: 'Agricultura familiar',
            onSelected: (prompt) => selectedPrompt = prompt,
          ),
        ),
      ),
    );

    expect(
      find.text('Como você quer estudar Agricultura familiar?'),
      findsOneWidget,
    );
    expect(find.text('Explique de forma simples'), findsOneWidget);
    expect(find.text('Mostre um exemplo prático'), findsOneWidget);
    expect(find.text('Quero praticar'), findsOneWidget);
    expect(selectedPrompt, isNull);

    await tester.tap(find.text('Quero praticar'));

    expect(selectedPrompt, contains('Faça uma pergunta curta'));
    expect(selectedPrompt, contains('este conteúdo'));
  });
}
