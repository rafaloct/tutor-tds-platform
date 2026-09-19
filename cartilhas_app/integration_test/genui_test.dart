import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/genui/genui_renderer.dart';
import 'package:cartilhas_app/genui/atui_parser.dart';
import 'package:cartilhas_app/models/genui_response.dart';

void main() {
  testWidgets('GenUIRenderer renders text and buttons from GenUI response', (
    WidgetTester tester,
  ) async {
    // Definindo um payload de teste simulando a IA
    final Map<String, dynamic> genUiPayload = {
      "text": "Para economizar energia no campo, considere estas dicas:",
      "ui": [
        {
          "type": "tip",
          "props": {
            "content": "Instale painéis solares para reduzir custos fixos.",
          },
        },
        {
          "type": "button",
          "props": {
            "label": "Ver Guia de Energia Solar",
            "action": "open_solar_guide",
          },
        },
      ],
    };

    final genUiResponse = GenUIResponse.fromJson(genUiPayload);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text(genUiResponse.text ?? ''),
              GenUIRenderer(
                components: (genUiResponse.components ?? const [])
                    .map(ATUIParser.parse)
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );

    // Verificações
    expect(
      find.text("Para economizar energia no campo, considere estas dicas:"),
      findsOneWidget,
    );
    expect(
      find.text("Instale painéis solares para reduzir custos fixos."),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text("Ver Guia de Energia Solar"), findsOneWidget);
  });
}
