import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/presentation/flashcards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('oferece frente, verso, origem e escala de quatro níveis', (
    tester,
  ) async {
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'material': {
              'title': 'Revisão',
              'items': [
                {
                  'front': 'O que é gotejamento?',
                  'back': 'Irrigação localizada.',
                  'hint': 'Economiza água',
                },
              ],
            },
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      Provider<StudyAiService>.value(
        value: service,
        child: const MaterialApp(
          home: FlashcardsScreen(topic: 'Irrigação sustentável'),
        ),
      ),
    );

    await tester.tap(find.text('Gerar com IA'));
    await tester.pumpAndSettle();
    expect(find.text('O que é gotejamento?'), findsOneWidget);
    expect(find.text('Cartão 1 de 1'), findsOneWidget);

    await tester.tap(find.text('O que é gotejamento?'));
    await tester.pumpAndSettle();
    expect(find.text('Irrigação localizada.'), findsOneWidget);
    expect(find.text('Origem: Irrigação sustentável'), findsOneWidget);
    expect(find.text('Não lembrei'), findsOneWidget);
    expect(find.text('Difícil'), findsOneWidget);
    expect(find.text('Bom'), findsOneWidget);
    expect(find.text('Fácil'), findsOneWidget);

    await tester.ensureVisible(find.text('Bom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bom'));
    await tester.pumpAndSettle();
    expect(find.text('Sessão concluída'), findsOneWidget);
    service.dispose();
  });
}
