import 'package:cartilhas_app/features/support/support_help_sections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chatwoot_screen_config_test.dart' show ConfigSource, FakeHost, start;

Future<void> openFaq(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Perguntas frequentes'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'support_contact_id_v1': 'anonymous-id',
      'user_name': 'Private Name',
      'user_phone': 'Private Phone',
      'privacy_consent_v1': false,
    }),
  );

  testWidgets('FAQ abre em bottom sheet com logo container e itens estáticos', (
    tester,
  ) async {
    final source = ConfigSource();
    final hosts = <FakeHost>[];
    await start(tester, source, hosts);

    expect(find.text('Perguntas frequentes'), findsNothing);

    await openFaq(tester);

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
    await openFaq(tester);

    expect(
      find.text(SupportHelpSections.faq.first.answer),
      findsNothing,
    );

    await tester.tap(find.text(SupportHelpSections.faq.first.question));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(SupportHelpSections.faq.first.answer),
      findsOneWidget,
    );
  });

  testWidgets('FAQ abre independente do estado do chat', (tester) async {
    final source = ConfigSource();
    final hosts = <FakeHost>[];
    await start(tester, source, hosts);
    await openFaq(tester);
    expect(find.text('Perguntas frequentes'), findsOneWidget);
  });
}
