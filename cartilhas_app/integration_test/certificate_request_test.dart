import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/features/certificates/presentation/certificate_requests_screen.dart';

// DFS V4b (pedido de certificado) — cobre a aresta de SOLICITACAO que
// wallet_qa_test nao alcanca: a wallet recebe por seed; aqui o pedido real
// bate na API de staging e persiste server-side.
//
//   e13   open   : CertificateRequestsScreen(courseId:'saf') injetada via
//                  Navigator — o FAB 'Solicitar certificado' exige
//                  _isCompleted (aresta condicional: modulo concluido)
//   e13a  context: GET /certificate-requests/contexts -> matricula
//                  'qa-cert-enroll-1' + evidencia renderizada
//   e13b  create : 'Solicitar análise' -> confirm -> POST 201 ->
//                  'Aguardando análise da equipe' (pendente, revisao humana)
//   e13c  wallet : 'Pedidos de certificado' (IconButton) -> mesma
//                  solicitacao persistida visivel fora do contexto do curso
//
// Limite do contrato: emissao/approved depende de REVISAO HUMANA —
// o teste prova a aresta ate 'pending'; approved->issue e edge de gestor.
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
  debugPrint('[DFS-certreq] $edge');
}

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

/// Login QA -> consent -> home (mesma cadeia dos outros DFS).
Future<void> _enterHome(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await tester.pumpWidget(const CartilhasApp());
  await tester.pumpAndSettle(const Duration(seconds: 2));

  final loginLink = find.widgetWithText(TextButton, 'Já tenho conta');
  expect(await _pumpUntil(tester, loginLink), isTrue);
  await tester.ensureVisible(loginLink);
  await tester.pumpAndSettle();
  await tester.tap(loginLink);
  await tester.pumpAndSettle();
  expect(
    await _pumpUntil(tester, find.byKey(const ValueKey('account-login-cpf'))),
    isTrue,
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
  expect(await _pumpUntil(tester, find.text('Tutor TDS')), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DFS cert-request: e13 solicitar analise via API real', (
    tester,
  ) async {
    _coverage.clear();
    await _enterHome(tester);
    _cover('home');

    // ── e13: abre a tela de pedidos no contexto da matricula SAF ──
    // (rota equivalente ao FAB do chat_experience; o FAB so aparece
    // com _isCompleted — aresta condicional de modulo concluido).
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const CertificateRequestsScreen(courseId: 'saf'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      await _pumpUntil(tester, find.text('Pedidos de certificado')),
      isTrue,
      reason: 'e13: tela de pedidos nao abriu',
    );
    _cover('e13 requests screen (courseId=saf)');

    // ── e13a: contexts carregam da API → dropdown + evidência ──
    expect(
      await _pumpUntil(tester, find.text('Matrícula para o pedido')),
      isTrue,
      reason: 'e13a: dropdown de matricula ausente (contexts falhou?)',
    );
    expect(find.text('Nenhuma matrícula disponível para esta edição. Atualize o curso com internet ou peça ajuda à equipe para conferir seu vínculo.'), findsNothing);
    // contexto unico e auto-selecionado -> evidencia renderiza.
    expect(
      find.textContaining('Há critérios pendentes').evaluate().isNotEmpty ||
          find.textContaining('Critérios disponíveis').evaluate().isNotEmpty,
      isTrue,
      reason: 'e13a: evidencia de elegibilidade nao renderizou',
    );
    _cover('e13a contexts + evidencia');

    // ── e13b: Solicitar análise → confirm → POST → pending ──
    final ask = find.widgetWithText(FilledButton, 'Solicitar análise');
    expect(ask, findsOneWidget, reason: 'e13b: botao solicitar ausente');
    await tester.ensureVisible(ask);
    await tester.pumpAndSettle();
    await tester.tap(ask);
    await tester.pumpAndSettle();

    // dialogo de confirmacao explicita LGPD/contrato.
    expect(
      await _pumpUntil(tester, find.text('Solicitar análise do certificado?')),
      isTrue,
      reason: 'e13b: dialog de confirmacao ausente',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    // POST /certificate-requests -> 201 -> _load() -> request pendente listado.
    expect(
      await _pumpUntil(
        tester,
        find.text('Aguardando análise da equipe'),
        timeoutSeconds: 30,
      ),
      isTrue,
      reason: 'e13b: pedido pendente nao listado apos POST',
    );
    expect(find.text('Sistemas Agroflorestais (SAF)'), findsWidgets);
    expect(
      find.byKey(const Key('certificate-request-error')),
      findsNothing,
      reason: 'e13b: erro visivel apos criacao do pedido',
    );
    _cover('e13b POST 201 + pending listado');

    // ── e13c: wallet -> 'Pedidos de certificado' -> mesmo pedido ──
    final back = find.byType(BackButton);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
      await tester.pumpAndSettle();
    }
    final certButton = find.widgetWithText(OutlinedButton, 'Meus certificados');
    expect(certButton, findsOneWidget);
    await tester.ensureVisible(certButton);
    await tester.tap(certButton);
    await tester.pumpAndSettle();
    expect(
      await _pumpUntil(tester, find.byTooltip('Pedidos de certificado')),
      isTrue,
      reason: 'e13c: wallet nao abriu',
    );
    await tester.tap(find.byTooltip('Pedidos de certificado'));
    await tester.pumpAndSettle();
    expect(
      await _pumpUntil(tester, find.text('Aguardando análise da equipe')),
      isTrue,
      reason: 'e13c: pedido nao visivel via wallet (persistencia API)',
    );
    expect(find.text('Sistemas Agroflorestais (SAF)'), findsWidgets);
    _cover('e13c pedido visivel fora do contexto (wallet)');

    debugPrint('═══ COBERTURA DFS CERT-REQUEST ═══');
    for (final step in _coverage) {
      debugPrint('  $step');
    }
    expect(_coverage, hasLength(greaterThanOrEqualTo(4)));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
