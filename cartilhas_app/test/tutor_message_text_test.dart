import 'package:cartilhas_app/widgets/tutor_message_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tutorPlainText (saída para TTS)', () {
    test('remove ênfase Markdown mantendo o texto', () {
      expect(
        tutorPlainText('**negrito** e *itálico* e ***os dois***'),
        'negrito e itálico e os dois',
      );
    });

    test('remove marcadores de título e lista', () {
      expect(tutorPlainText('## Solo\n- água\n- solo'), 'Solo\nágua\nsolo');
    });

    test('link Markdown vira só o texto', () {
      expect(
        tutorPlainText('Veja [a cartilha](https://exemplo.br/x)'),
        'Veja a cartilha',
      );
    });

    test('código inline perde crases', () {
      expect(tutorPlainText('Use `solo argiloso` aqui'), 'Use solo argiloso aqui');
    });

    test('chaves comuns passam intactas', () {
      expect(tutorPlainText('valor {x} preservado'), 'valor {x} preservado');
    });

    test('não contém sintaxe de link ou ênfase', () {
      final out = tutorPlainText(
        '**A** ***B*** [t](https://x.dev) `c`\n## h\n- i',
      );
      expect(out, isNot(contains('**')));
      expect(out, isNot(contains('](')));
      expect(out, isNot(contains('`')));
      expect(out, isNot(contains('#')));
    });
  });

  group('TutorMessageText (render)', () {
    testWidgets('renderiza ênfase sem delimitadores literais', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TutorMessageText('**negrito** e *itálico*'),
          ),
        ),
      );
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('negrito'), findsOneWidget);
      expect(find.textContaining('itálico'), findsOneWidget);
    });

    testWidgets('link chama confirmação em vez de abrir direto', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorMessageText(
              'Veja [a cartilha](https://exemplo.br/doc)',
              onLinkTap: (url) => tapped = url,
            ),
          ),
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('a cartilha'));
      expect(tapped, 'https://exemplo.br/doc');
    });

    testWidgets('URL nua preserva prefixo e pontuação uma única vez', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorMessageText(
              'Veja https://example.com, agora.',
              onLinkTap: (url) => tapped = url,
            ),
          ),
        ),
      );
      final rendered = tester.widget<Text>(
        find.descendant(
          of: find.byType(TutorMessageText),
          matching: find.byType(Text),
        ),
      );
      expect(rendered.textSpan!.toPlainText(), 'Veja https://example.com, agora.');
      await tester.tapOnText(find.textRange.ofSubstring('https://example.com'));
      expect(tapped, 'https://example.com');
    });

    testWidgets('lista vira marcador legível', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TutorMessageText('- primeiro\n- segundo')),
        ),
      );
      expect(find.textContaining('primeiro'), findsOneWidget);
      expect(find.textContaining('segundo'), findsOneWidget);
    });
  });
}
