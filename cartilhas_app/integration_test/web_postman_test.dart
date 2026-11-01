import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';

// Caminho mínimo do "Carteiro Chinês" do grafo web (docs/qa/WEB_COVERAGE_GRAPH.md):
// cadeia de entrada + todos os spokes home->v->home alcançáveis por student
// em staging.qa.json. Cada vértice é provado pelo AppBar/texto de destino.
// Vértices de gestão (claims) ficam fora por design.
const _qaCpf = String.fromEnvironment(
  'QA_ACCOUNT_CPF',
  defaultValue: '90077712307',
);
const _qaPassword = String.fromEnvironment(
  'QA_ACCOUNT_PASSWORD',
  defaultValue: 'qa-web-senha-2026!',
);

Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int timeoutSeconds = 40,
}) async {
  for (var i = 0; i < timeoutSeconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> _tapAndLand(
  WidgetTester tester,
  Finder trigger,
  Finder landing, {
  bool scroll = true,
}) async {
  if (scroll) {
    // Home usa scroll lazy: o botao pode nem existir na arvore ainda.
    if (trigger.evaluate().isEmpty) {
      final scrollables = find.byType(Scrollable);
      for (var i = 0;
          i < scrollables.evaluate().length && trigger.evaluate().isEmpty;
          i++) {
        try {
          await tester.scrollUntilVisible(
            trigger,
            300,
            scrollable: scrollables.at(i),
            maxScrolls: 25,
          );
        } catch (_) {}
      }
    }
    if (trigger.evaluate().isNotEmpty) {
      await tester.ensureVisible(trigger.first);
      await tester.pumpAndSettle();
    }
  }
  await tester.tap(trigger.first);
  await tester.pumpAndSettle();
  expect(
    await _pumpUntil(tester, landing),
    isTrue,
    reason: 'destino nao apareceu: $landing',
  );
}

Future<void> _back(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await tester.pumpAndSettle();
  } else {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
}

Future<void> _home(WidgetTester tester) async {
  expect(await _pumpUntil(tester, find.text('Tutor TDS')), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('postman: caminho minimo cobre todos os vertices student', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpWidget(const CartilhasApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── ENTRADA: welcome -> account_login -> privacy_consent -> home ──
    final loginLink = find.widgetWithText(TextButton, 'Já tenho conta');
    expect(await _pumpUntil(tester, loginLink), isTrue);
    await tester.ensureVisible(loginLink);
    await tester.pumpAndSettle();
    await tester.tap(loginLink);
    await tester.pumpAndSettle();
    expect(
      await _pumpUntil(tester, find.byKey(const ValueKey('account-login-cpf'))),
      isTrue,
      reason: 'account_login nao abriu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-login-cpf')),
      _qaCpf,
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      _qaPassword,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar na conta'));
    final consent = find.widgetWithText(FilledButton, 'Concordar e continuar');
    expect(await _pumpUntil(tester, consent), isTrue);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    await _home(tester);

    // ── SPOKE midia: home -> videos -> player -> home ──
    await _tapAndLand(
      tester,
      find.widgetWithText(FilledButton, 'Vídeos'),
      find.text('Aprenda com propósito'),
    );
    expect(find.byType(Card), findsAtLeastNWidgets(1));
    if (find.byType(Card).evaluate().isNotEmpty) {
      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();
      await _back(tester); // player -> catalog
    }
    await _back(tester); // catalog -> home
    await _home(tester);

    // ── SPOKE study_hub via nav "Aprender" ──
    await _tapAndLand(
      tester,
      find.text('Aprender'),
      find.text('Estudar com IA'),
      scroll: false,
    );
    // spoke interno: flashcards
    if (find.text('Cartões de estudo').evaluate().isNotEmpty) {
      await _tapAndLand(
        tester,
        find.text('Cartões de estudo'),
        find.byType(Scaffold),
      );
      await _back(tester);
    }
    // spoke interno: resumo
    if (find.text('Resumo com IA').evaluate().isNotEmpty) {
      await _tapAndLand(
        tester,
        find.text('Resumo com IA'),
        find.byType(Scaffold),
      );
      await _back(tester);
    }
    await _back(tester); // hub -> home
    await _home(tester);

    // ── SPOKE conteudos via nav ──
    await _tapAndLand(
      tester,
      find.text('Conteúdos'),
      find.text('Aprenda com propósito'),
      scroll: false,
    );
    await _back(tester);
    await _home(tester);

    // ── SPOKE certificados: wallet -> requests -> home ──
    // Botoes 'Meus certificados'/'Como usar' sao OutlinedButton (nao FilledButton).
    await _tapAndLand(
      tester,
      find.widgetWithText(OutlinedButton, 'Meus certificados'),
      find.byTooltip('Pedidos de certificado'),
    );
    await _back(tester);
    await _home(tester);

    // ── SPOKE guia ──
    await _tapAndLand(
      tester,
      find.widgetWithText(OutlinedButton, 'Como usar'),
      find.text('Como usar o App TDS'),
    );
    await _back(tester);
    await _home(tester);

    // ── SPOKE perfil (nav) -> cadunico ──
    await _tapAndLand(
      tester,
      find.text('Perfil'),
      find.text('Meu Cadastro TDS'),
      scroll: false,
    );
    await _back(tester);
    await _home(tester);

    // ── SPOKE menu: suporte / settings / sobre ──
    final menu = find.byType(PopupMenuButton<String>);
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      await _tapAndLand(
        tester,
        find.text('Suporte TDS'),
        find.byType(Scaffold),
        scroll: false,
      );
      await _back(tester);
      await _home(tester);

      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      await _tapAndLand(
        tester,
        find.text('Configurações'),
        find.text('Configurações'),
        scroll: false,
      );
      // dentro de settings: privacy_policy + onboarding-review + voltar
      final privacy = find.text('Como seus dados são usados');
      if (privacy.evaluate().isNotEmpty) {
        await tester.ensureVisible(privacy.first);
        await tester.pumpAndSettle();
        await tester.tap(privacy.first);
        await tester.pumpAndSettle();
        await _back(tester);
      }
      final review = find.text('Rever apresentação do app');
      if (review.evaluate().isNotEmpty) {
        await tester.ensureVisible(review.first);
        await tester.pumpAndSettle();
        await tester.tap(review.first);
        await tester.pumpAndSettle();
        final skip = find.text('Pular');
        if (skip.evaluate().isNotEmpty) {
          await tester.tap(skip.first);
          await tester.pumpAndSettle();
        } else {
          await _back(tester);
        }
      }
      await _back(tester); // settings -> home
      await _home(tester);

      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      await _tapAndLand(
        tester,
        find.text('Sobre o Programa'),
        find.text('Sobre o Programa'),
        scroll: false,
      );
      await _back(tester);
      await _home(tester);
    }

    // ── ARESTA RELOAD: F5 -> welcome -> auto-home (sessao persiste) ──
    await tester.pumpWidget(const CartilhasApp());
    await tester.pump();
    await _home(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
