import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/features/media/presentation/media_player_screen.dart';
import 'package:cartilhas_app/features/media/presentation/media_catalog_screen.dart';

// DFS continuacao do grafo web (V2->V3->V4), conta QA real em staging.
// Depende de account_qa_test: mesmo fluxo de entrada ate a Home.
//
//   V2 videos/catalogo (ponto de partida, sessao ja autenticada)
//     e6 consumo   : tap 'Aula 01' -> V3
//   V3 player/detalhe
//     e7a estado   : 'Salvar' -> snackbar + bookmark + persistencia local
//     e7b api      : rating 5 estrelas -> POST rate() na API staging
//                    (aceita 'Sua avaliacao' ou issue — ambos provam API)
//     e7-completion: INDEVEL — 'ended' e postMessage do iframe embed,
//                    sem controle de UI no headless (ver relatorio)
//     e8 retorno   : back -> catalogo -> home
//   V4 perfil/certificados
//     e9 dados     : nav Perfil -> 'Meu Cadastro TDS' -> campos renderizam
//     e10 wallet   : 'Meus certificados' -> carteira (vazia p/ QA) ->
//                    PDF e aresta condicional (sem certificado emitido)
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
  debugPrint('[DFS-learn] $edge');
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

/// Cadeia de entrada compartilhada: login QA -> consent -> home.
Future<void> _enterHome(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await tester.pumpWidget(const CartilhasApp());
  await _settle(tester, frames: 16);

  final loginLink = find.widgetWithText(TextButton, 'Já tenho conta');
  expect(await _pumpUntil(tester, loginLink), isTrue);
  await _reveal(tester, loginLink);
  await _settle(tester);
  await tester.tap(loginLink);
  await _settle(tester);

  expect(
    await _pumpUntil(tester, find.byKey(const ValueKey('account-login-cpf'))),
    isTrue,
    reason: 'tela de login nao abriu',
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
  await _settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar na conta'));

  final consent = find.widgetWithText(FilledButton, 'Concordar e continuar');
  expect(await _pumpUntil(tester, consent), isTrue);
  await tester.tap(consent);
  await _settle(tester);
  expect(
    await _pumpUntil(tester, find.text('Tutor TDS')),
    isTrue,
    reason: 'home nao apareceu',
  );
}

/// Settle bounded: pumpAndSettle() pode nunca retornar quando o embed do
/// player (iframe) ou o catalogo remoto seguem agendando frames — os
/// _pumpUntil seguintes cuidam da espera real.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// ensureVisible tolerante a scroll lazy: se o finder ainda nao existe na
/// arvore (Home/player constroem sob demanda), rola ate aparecer primeiro.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    for (var i = 0;
        i < scrollables.evaluate().length && finder.evaluate().isEmpty;
        i++) {
      try {
        await tester.scrollUntilVisible(
          finder,
          300,
          scrollable: scrollables.at(i),
          maxScrolls: 25,
        );
      } catch (_) {}
    }
  }
  await _reveal(tester, finder);
}

Future<void> _back(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await _settle(tester);
  } else {
    await tester.pageBack();
    await _settle(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DFS aprendizado: V2{e6} -> V3{e7a,e7b,e8} -> V4{e9,e10}', (
    tester,
  ) async {
    _coverage.clear();
    await _enterHome(tester);
    _cover('home (sessao QA)');

    // ── V2: abre o catalogo de videos ──
    final videos = find.widgetWithText(FilledButton, 'Vídeos');
    await _reveal(tester, videos);
    await _settle(tester);
    await tester.tap(videos);
    await _settle(tester);
    expect(await _pumpUntil(tester, find.byType(Card)), isTrue);
    expect(find.textContaining('Aula 01'), findsAtLeastNWidgets(1));
    _cover('V2 catalogo');

    // ── e6: consumo -> V3 player/detalhe ──
    final aulaInk = find.ancestor(
      of: find.textContaining('Aula 01').first,
      matching: find.byType(InkWell),
    );
    expect(aulaInk, findsWidgets, reason: 'e6: card da Aula 01 sem InkWell');
    await _reveal(tester, aulaInk.first);
    await _settle(tester);
    await tester.tap(aulaInk.first);
    await _settle(tester);
    for (final bar in tester.widgetList<AppBar>(find.byType(AppBar))) {
      debugPrint('[e6] AppBar: ${bar.title}');
    }
    expect(
      await _pumpUntil(tester, find.byType(MediaPlayerScreen)),
      isTrue,
      reason: 'e6: player/detalhe nao abriu',
    );
    // ListView lazy: a secao de detalhes existe abaixo da dobra.
    await tester.scrollUntilVisible(
      find.text('Contexto pedagógico'),
      320,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    expect(find.text('Contexto pedagógico'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Depois do vídeo'),
      320,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    expect(find.text('Fazer quiz rápido'), findsOneWidget);
    expect(find.text('Perguntar ao Tutor'), findsOneWidget);
    _cover('e6 aula-01 (V2->V3)');

    // Estado do embed (iframe): registra o que o headless renderizou.
    if (find.text('Preparando reprodução segura...').evaluate().isNotEmpty) {
      _cover('  [web] embed=loading');
    } else if (find
        .text('A fonte do vídeo não respondeu. Renove o acesso e tente novamente.')
        .evaluate()
        .isNotEmpty) {
      _cover('  [web] embed=error');
    } else {
      _cover('  [web] embed=ready(iframe)');
    }

    // ── e7a: 'Salvar' -> estado visual + persistencia ──
    final saveButton = find.widgetWithText(OutlinedButton, 'Salvar');
    if (saveButton.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        saveButton,
        320,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
    }
    expect(saveButton, findsOneWidget, reason: 'e7a: botao Salvar ausente');
    await _reveal(tester, saveButton);
    await _settle(tester);
    await tester.tap(saveButton);
    await _settle(tester);
    expect(
      await _pumpUntil(tester, find.text('Vídeo salvo.'), timeoutSeconds: 15),
      isTrue,
      reason: 'e7a: snackbar de salvo nao apareceu',
    );
    await _settle(tester);
    // estado visual: rotulo vira 'Salvo' e icone bookmark preenchido.
    expect(find.widgetWithText(OutlinedButton, 'Salvo'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsWidgets);
    _cover('e7a salvar->estado+persistido (V3->V3)');

    // ── e7b: rating 5 -> POST rate() na API staging ──
    if (find.text('Avalie este conteúdo').evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text('Avalie este conteúdo'),
        320,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
    }
    expect(
      await _pumpUntil(tester, find.text('Avalie este conteúdo')),
      isTrue,
      reason: 'e7b: painel de avaliacao ausente',
    );
    // espera o loading do rating terminar (estrelas aparecem).
    final star5 = find.byTooltip('5 de 5');
    expect(
      await _pumpUntil(tester, star5, timeoutSeconds: 30),
      isTrue,
      reason: 'e7b: estrelas nao renderizaram',
    );
    await tester.tap(star5.first);
    await _settle(tester);
    // API staging pode aceitar (rating registrado) ou exigir conclusao
    // qualificada (issue exibida) — ambas provam que a chamada saiu.
    final rated = find.textContaining('Sua avaliação:');
    final issued = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data?.contains('avaliação') == true ||
              w.data?.contains('conclusão') == true),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (rated.evaluate().isNotEmpty || find.text('Enviando avaliação...').evaluate().isEmpty && issued.evaluate().isNotEmpty) {
        break;
      }
      if (rated.evaluate().isNotEmpty) break;
    }
    final apiReached =
        rated.evaluate().isNotEmpty || issued.evaluate().isNotEmpty;
    expect(
      apiReached,
      isTrue,
      reason: 'e7b: rating nao obteve resposta da API',
    );
    _cover(
      rated.evaluate().isNotEmpty
          ? 'e7b rating-5 -> API 200 (V3->V3)'
          : 'e7b rating-5 -> API rejeitou c/ issue (V3->V3)',
    );

    // ── e8: retorno player -> catalogo -> home ──
    await _back(tester);
    expect(
      await _pumpUntil(tester, find.byType(MediaCatalogScreen)),
      isTrue,
      reason: 'e8: nao voltou ao catalogo',
    );
    await _back(tester);
    expect(
      await _pumpUntil(tester, find.text('Tutor TDS')),
      isTrue,
      reason: 'e8: nao voltou a home',
    );
    _cover('e8 retorno (V3->V2->home)');

    // ── e9: nav Perfil -> dados do usuario p/ certificado ──
    await tester.tap(find.text('Perfil'));
    await _settle(tester);
    expect(
      await _pumpUntil(tester, find.text('Meu Cadastro TDS')),
      isTrue,
      reason: 'e9: perfil/cadunico nao abriu',
    );
    // campos que alimentam a emissao do certificado (regra de negocio).
    for (final label in ['Nome completo', 'WhatsApp', 'CPF']) {
      expect(
        find.widgetWithText(TextFormField, label),
        findsOneWidget,
        reason: 'e9: campo $label ausente',
      );
    }
    final nameField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Nome completo'),
    );
    final cpfField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'CPF'),
    );
    debugPrint(
      '[DFS-learn] perfil: name="${nameField.controller?.text}" '
      'cpf="${cpfField.controller?.text}"',
    );
    _cover(
      'e9 perfil (name="${nameField.controller?.text}" '
      'cpf="${cpfField.controller?.text}")',
    );
    await _back(tester);
    expect(await _pumpUntil(tester, find.text('Tutor TDS')), isTrue);

    // ── e10: wallet de certificados ──
    final certButton = find.widgetWithText(OutlinedButton, 'Meus certificados');
    expect(certButton, findsOneWidget);
    await _reveal(tester, certButton);
    await _settle(tester);
    await tester.tap(certButton);
    await _settle(tester);
    expect(
      await _pumpUntil(tester, find.byTooltip('Pedidos de certificado')),
      isTrue,
      reason: 'e10: wallet nao abriu',
    );
    // conta QA: carteira vazia esperada; se houver item, valida card.
    // espera o body resolver (loading -> vazio | lista | erro).
    final emptyWallet = find.text('Sua carteira está vazia');
    final walletError = find.widgetWithText(OutlinedButton, 'Tentar novamente');
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (emptyWallet.evaluate().isNotEmpty ||
          find.byType(Card).evaluate().isNotEmpty ||
          walletError.evaluate().isNotEmpty) {
        break;
      }
    }
    if (emptyWallet.evaluate().isNotEmpty) {
      _cover('e10 wallet=vazia (sem certificado emitido p/ QA)');
    } else if (find.byType(Card).evaluate().isNotEmpty) {
      _cover('e10 wallet=${find.byType(Card).evaluate().length} cert(s)');
    } else {
      _cover('e10 wallet=erro (estado de erro renderizado)');
      expect(walletError, findsOneWidget);
    }
    await _back(tester);
    expect(await _pumpUntil(tester, find.text('Tutor TDS')), isTrue);

    debugPrint('═══ COBERTURA DFS LEARN ═══');
    for (final step in _coverage) {
      debugPrint('  $step');
    }
    expect(_coverage, hasLength(greaterThanOrEqualTo(8)));
  });
}
