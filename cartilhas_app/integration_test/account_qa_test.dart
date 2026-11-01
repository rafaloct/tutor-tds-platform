import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';

// E2E com conta QA real contra a API configurada (staging por padrao).
// Modelado como DFS sobre o grafo de auth (docs/qa/WEB_COVERAGE_GRAPH.md):
//
//   V0 auth (welcome + dialogs login/registro)
//     e1 falha     : senha errada -> erro inline -> Cancelar (back-edge V0)
//     e2 registro  : CPF QA -> 201 ou 'Ja existe' (idempotente) -> V0
//     e3 sucesso   : senha certa -> V1
//   V1 privacy_consent
//     e4 aceite    : 'Concordar e continuar' -> home -> V2
//   V2 videos/catalogo
//     e5 midia     : titulo + cards + thumbnail/player renderizando
//
// A conta e idempotente: primeiro run registra, seguintes reutilizam.
const _qaName = String.fromEnvironment(
  'QA_ACCOUNT_NAME',
  defaultValue: 'Aluno QA Web',
);
const _qaPhone = String.fromEnvironment(
  'QA_ACCOUNT_PHONE',
  defaultValue: '63999991234',
);
const _qaCpf = String.fromEnvironment(
  'QA_ACCOUNT_CPF',
  defaultValue: '90077712307',
);
const _qaPassword = String.fromEnvironment(
  'QA_ACCOUNT_PASSWORD',
  defaultValue: 'qa-web-senha-2026!',
);

final _coverage = <String>[];

void _cover(String edge) {
  _coverage.add(edge);
  debugPrint('[DFS] $edge');
}

/// Bombeia frames ate o finder existir ou estourar o timeout (rede real).
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

/// V0: abre o dialog de login ("Ja tenho conta") e submete credenciais.
Future<void> _openLoginAndSubmit(
  WidgetTester tester,
  String password,
) async {
  final loginLink = find.widgetWithText(TextButton, 'Já tenho conta');
  expect(await _pumpUntil(tester, loginLink), isTrue);
  await tester.ensureVisible(loginLink);
  await tester.pumpAndSettle();
  await tester.tap(loginLink);
  await tester.pumpAndSettle();

  expect(
    await _pumpUntil(tester, find.byKey(const ValueKey('account-login-cpf'))),
    isTrue,
    reason: 'dialog de login nao abriu',
  );
  await tester.enterText(
    find.byKey(const ValueKey('account-login-cpf')),
    _qaCpf,
  );
  await tester.enterText(
    find.byKey(const ValueKey('account-password')),
    password,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar na conta'));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DFS auth->videos cobre V0{e1,e2,e3} V1{e4} V2{e5}', (
    tester,
  ) async {
    _coverage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpWidget(const CartilhasApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    _cover('V0 welcome/auth');

    // ── e1 (back-edge): login com senha errada -> estado de erro -> V0 ──
    await _openLoginAndSubmit(tester, 'senha-totalmente-errada!');
    final errorText = find.byKey(const ValueKey('account-error'));
    expect(
      await _pumpUntil(tester, errorText, timeoutSeconds: 30),
      isTrue,
      reason: 'e1: estado de erro de credenciais nao apareceu',
    );
    expect(
      find.text('CPF ou senha inválidos.'),
      findsOneWidget,
      reason: 'e1: mensagem de erro inesperada',
    );
    _cover('e1 login-falha -> erro (V0->account_login->V0)');
    // back-edge: account_login e rota empurrada -> BackButton do AppBar.
    final loginBack = find.byType(BackButton);
    expect(loginBack, findsWidgets, reason: 'e1: sem back-edge em login');
    await tester.tap(loginBack.first);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextButton, 'Já tenho conta'),
      findsOneWidget,
      reason: 'e1: nao retornou a V0 (welcome)',
    );

    // ── e2 (back-edge): registro do CPF QA -> 201 ou duplicata -> V0 ──
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      _qaName,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp'),
      _qaPhone,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF'),
      _qaCpf,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Criar conta');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      _qaPassword,
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password-confirmation')),
      _qaPassword,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta segura'));
    await tester.pumpAndSettle();

    // Aceita 201 (fluxo segue para consent/onboarding) ou 409 (duplicata).
    final duplicate = find.text('Já existe uma conta para este CPF.');
    final consent = find.widgetWithText(FilledButton, 'Concordar e continuar');
    var registeredFresh = false;
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (duplicate.evaluate().isNotEmpty || consent.evaluate().isNotEmpty) {
        break;
      }
    }
    if (duplicate.evaluate().isNotEmpty) {
      _cover('e2 registro -> 409 duplicata (V0->dialog->V0)');
      // back-edge: dialog de registro fecha via 'Cancelar'.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    } else {
      expect(consent, findsWidgets, reason: 'e2: registro nao chegou a API');
      registeredFresh = true;
      _cover('e2 registro -> 201 (V0->V1 direto)');
    }

    // ── e3: login com senha correta -> V1 ──
    if (!registeredFresh) {
      await _openLoginAndSubmit(tester, _qaPassword);
    }
    expect(
      await _pumpUntil(tester, consent),
      isTrue,
      reason: 'e3: login nao abriu o consentimento (V1)',
    );
    _cover('e3 login-sucesso (V0->V1)');

    // ── e4: aceite do consentimento -> home ──
    await tester.tap(consent.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      await _pumpUntil(tester, find.text('Tutor TDS')),
      isTrue,
      reason: 'e4: consentimento nao chegou na home',
    );
    _cover('e4 consent-aceite (V1->home)');

    // ── e5: videos -> catalogo renderiza midia da API ──
    final videos = find.widgetWithText(FilledButton, 'Vídeos');
    await tester.ensureVisible(videos);
    await tester.pumpAndSettle();
    await tester.tap(videos);
    await tester.pumpAndSettle();

    await _pumpUntil(tester, find.byType(Card));
    expect(find.text('Vídeos'), findsWidgets);
    expect(find.text('Vídeos indisponíveis agora'), findsNothing);
    expect(find.text('Nenhum vídeo publicado ainda'), findsNothing);
    expect(find.byType(Card), findsAtLeastNWidgets(1));
    expect(find.textContaining('Aula 01'), findsAtLeastNWidgets(1));
    // affordance de midia: thumbnail (Image.network) ou fallback play_circle.
    final mediaRendered =
        find.byType(Image).evaluate().isNotEmpty ||
        find.byIcon(Icons.play_circle_outline).evaluate().isNotEmpty;
    expect(
      mediaRendered,
      isTrue,
      reason: 'e5: nem thumbnail nem icone de player renderizou',
    );
    _cover('e5 videos-catalogo (home->V2, midia OK)');

    debugPrint('═══ COBERTURA DFS ═══');
    for (final step in _coverage) {
      debugPrint('  $step');
    }
    expect(_coverage, hasLength(greaterThanOrEqualTo(5)));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
