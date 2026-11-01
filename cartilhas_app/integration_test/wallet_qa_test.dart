import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';

// DFS V4 (certificados) com estado semeado — cobre a aresta condicional
// "carteira COM certificado" que learning_qa_test nao alcanca (QA vazia).
//
//   e11 render : seed CertificateRecord -> wallet lista card ->
//                details (CERTIFICADO + holderName + hash)
//   e12a share : 'Compartilhar PDF' -> kIsWeb -> Printing.sharePdf
//                (download blob, sem dart:io) -> sem excecao
//   e12b print : 'Imprimir' -> Printing.layoutPdf (iframe browser)
//                -> sem crash (bounded pump, headless pode suprimir dialog)
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
  debugPrint('[DFS-wallet] $edge');
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

/// Certificado de teste com hash local valido (sha256 do canonicalData).
CertificateRecord _qaCertificate() {
  const fields = (
    schemaVersion: 1,
    id: 'qa-wallet-cert-1',
    issuer: 'Tutor TDS QA',
    holderName: 'Aluno QA Web',
    courseId: 'saf',
    courseTitle: 'SAF - Seguranca e Administracao Farmaceutica',
    answeredQuestions: 9,
    totalQuestions: 10,
    signature: 'qa-seed-signature',
  );
  final draft = CertificateRecord(
    schemaVersion: fields.schemaVersion,
    id: fields.id,
    issuer: fields.issuer,
    holderName: fields.holderName,
    courseId: fields.courseId,
    courseTitle: fields.courseTitle,
    issuedAt: DateTime.utc(2026, 10, 31, 12),
    answeredQuestions: fields.answeredQuestions,
    totalQuestions: fields.totalQuestions,
    verificationUrl: Uri.parse('https://cert.tds.local/verify/${fields.id}'),
    hash: '0' * 64,
    signature: fields.signature,
  );
  return CertificateRecord(
    schemaVersion: fields.schemaVersion,
    id: fields.id,
    issuer: fields.issuer,
    holderName: fields.holderName,
    courseId: fields.courseId,
    courseTitle: fields.courseTitle,
    issuedAt: DateTime.utc(2026, 10, 31, 12),
    answeredQuestions: fields.answeredQuestions,
    totalQuestions: fields.totalQuestions,
    verificationUrl: Uri.parse('https://cert.tds.local/verify/${fields.id}'),
    hash: draft.computedHash,
    signature: fields.signature,
  );
}

/// Login QA -> consent -> home (mesma cadeia dos outros DFS).
Future<void> _enterHome(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // seed: indice da carteira no storage web (SharedPreferences).
  await CertificateRepository().upsert(_qaCertificate());
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

  testWidgets('DFS wallet: e11 render + e12 fallbacks web PDF', (
    tester,
  ) async {
    _coverage.clear();
    await _enterHome(tester);
    _cover('home + seed cert');

    // ── abre a wallet ──
    final certButton = find.widgetWithText(OutlinedButton, 'Meus certificados');
    expect(certButton, findsOneWidget);
    await tester.ensureVisible(certButton);
    await tester.pumpAndSettle();
    await tester.tap(certButton);
    await tester.pumpAndSettle();

    // espera o body resolver: card do certificado semeado.
    expect(
      await _pumpUntil(tester, find.text('SAF - Seguranca e Administracao Farmaceutica')),
      isTrue,
      reason: 'e11: certificado semeado nao apareceu na wallet',
    );
    expect(find.text('Sua carteira está vazia'), findsNothing);
    expect(find.byType(Card), findsAtLeastNWidgets(1));
    _cover('e11 wallet render (storage web OK)');

    // ── e11b: detalhes do certificado ──
    await tester.tap(
      find.text('SAF - Seguranca e Administracao Farmaceutica').first,
    );
    await tester.pumpAndSettle();
    expect(
      await _pumpUntil(tester, find.text('CERTIFICADO')),
      isTrue,
      reason: 'e11: details nao abriu',
    );
    expect(find.text('Aluno QA Web'), findsOneWidget);
    expect(find.text('Hash SHA-256'), findsOneWidget);
    _cover('e11 details (holder+hash+qr)');

    // ── e12a: 'Compartilhar PDF' -> Printing.sharePdf (web blob download) ──
    final shareButton = find.widgetWithText(FilledButton, 'Compartilhar PDF');
    expect(shareButton, findsOneWidget, reason: 'e12a: botao share ausente');
    await tester.ensureVisible(shareButton);
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    // sharePdf no web: gera bytes + dispara download via anchor — nao pode
    // lancar excecao (antes quebrava em dart:io File).
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text('CERTIFICADO'),
      findsOneWidget,
      reason: 'e12a: tela caiu apos sharePdf',
    );
    expect(find.byType(ErrorWidget), findsNothing);
    _cover('e12a sharePdf web (sem dart:io, sem crash)');

    // ── e12b: 'Imprimir' -> Printing.layoutPdf (iframe do browser) ──
    final printButton = find.widgetWithText(OutlinedButton, 'Imprimir');
    expect(printButton, findsOneWidget, reason: 'e12b: botao imprimir ausente');
    await tester.tap(printButton);
    // dialog de impressao do browser pode ser suprimido no headless:
    // bounded pump — o que interessa e a ausencia de excecao.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.text('CERTIFICADO'),
      findsOneWidget,
      reason: 'e12b: tela caiu apos layoutPdf',
    );
    expect(find.byType(ErrorWidget), findsNothing);
    _cover('e12b print fallback (layoutPdf sem crash)');

    // ── retorno: details -> wallet -> home ──
    final back = find.byType(BackButton);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
      await tester.pumpAndSettle();
    } else {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(
      await _pumpUntil(tester, find.byTooltip('Pedidos de certificado')),
      isTrue,
      reason: 'retorno a wallet falhou',
    );
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
    }
    expect(await _pumpUntil(tester, find.text('Tutor TDS')), isTrue);
    _cover('retorno (details->wallet->home)');

    debugPrint('═══ COBERTURA DFS WALLET ═══');
    for (final step in _coverage) {
      debugPrint('  $step');
    }
    expect(_coverage, hasLength(greaterThanOrEqualTo(5)));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
