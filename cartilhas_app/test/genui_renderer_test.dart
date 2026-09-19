import 'package:cartilhas_app/genui/atui_parser.dart';
import 'package:cartilhas_app/genui/genui_renderer.dart';
import 'package:cartilhas_app/models/genui_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GenUI renderiza dica e ação retornadas pelo Tutor', (
    tester,
  ) async {
    final response = GenUIResponse.fromJson({
      'text': 'Considere estas dicas:',
      'ui': [
        {
          'type': 'tip',
          'props': {'content': 'Comece com uma ação pequena.'},
        },
        {
          'type': 'button',
          'props': {'label': 'Abrir guia', 'action': 'open_guide'},
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenUIRenderer(
            components: (response.components ?? const [])
                .map(ATUIParser.parse)
                .toList(),
          ),
        ),
      ),
    );

    expect(find.text('Comece com uma ação pequena.'), findsOneWidget);
    expect(find.text('Abrir guia'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
