import 'package:cartilhas_app/screens/chatwoot_screen.dart';
import 'package:cartilhas_app/features/support/support_help_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatwoot_screen_config_test.dart' show ConfigSource, FakeHost, start;

void main() {
  testWidgets('FAQ abre em bottom sheet com logo container e itens estáticos', (
    tester,
  ) async {
    final source = ConfigSource();
    final hosts = <FakeHost>[];
    await start(tester, source, hosts);
    await tester.pump();

    expect(find.text('Perguntas frequentes'), findsNothing);

    await tester.tap(find.byTooltip('Perguntas frequentes'));
    await tester.pumpAndSettle();

    expect(find.byType(SupportBrandHeader), findsOneWidget);
    expect(find.text('Central de Ajuda'), findsOneWidget);
    expect(find.text('Perguntas frequentes'), findsOneWidget);
    expect(
      find.text(SupportHelpSections.faq.first.question),
      findsOneWidget,
    );
    expect(
      find.text(SupportHelpSections.faq.last.question),
      findsOneWidget,
    );

    // Conteúdo permanece funcional offline/sem rede: nenhuma chamada extra.
    expect(source.calls, 1);
    expect(hosts.length, 1);
  });

  testWidgets('Item do FAQ expande e revela a resposta', (tester) async {
    final source = ConfigSource();
    final hosts = <FakeHost>[];
    await start(tester, source, hosts);
    await tester.pump();

    await tester.tap(find.byTooltip('Perguntas frequentes'));
    await tester.pumpAndSettle();

    expect(
      find.text(SupportHelpSections.faq.first.answer),
      findsNothing,
    );

    await tester.tap(find.text(SupportHelpSections.faq.first.question));
    await tester.pumpAndSettle();

    expect(
      find.text(SupportHelpSections.faq.first.answer),
      findsOneWidget,
    );
  });

  testWidgets('FAQ abre independente do estado do chat', (tester) async {
    final source = ConfigSource();
    final hosts = <FakeHost>[];
    await start(tester, source, hosts);
    await tester.tap(find.byTooltip('Perguntas frequentes'));
    await tester.pumpAndSettle();
    expect(find.text('Perguntas frequentes'), findsOneWidget);
  });
}
