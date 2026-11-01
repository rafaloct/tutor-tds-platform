import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';

// Prova o build servido em :9090 (config/staging.qa.web.json): com
// TUTOR_QA_AUTOLOGIN ligado, abrir o app loga a conta QA sozinho e cai
// direto na tela de Vídeos — zero toque manual.
// Este arquivo exige o config web de QA; com staging.qa.json ele falha
// (autologin desligado cai no WelcomeScreen, como deve ser).
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('[Q1] autologin cai direto nos videos, sem formulario', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await tester.pumpWidget(const CartilhasApp());
    await tester.pump();

    expect(await _pumpUntil(tester, find.byType(Card)), isTrue);
    // AppBar da MediaCatalogScreen — destino TUTOR_QA_OPEN=videos.
    expect(find.text('Vídeos'), findsWidgets);
    // Nao pode ter sobrado tela de login/boas-vindas.
    expect(find.text('Continuar neste dispositivo'), findsNothing);
    expect(find.text('CPF ou senha inválidos.'), findsNothing);
    // Catalogo remoto real (Aula 01 publicada no staging).
    expect(find.textContaining('Aula 01'), findsAtLeastNWidgets(1));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
