import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';

void main() {
  testWidgets('Novo usuário vê cadastro e aviso de privacidade', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CartilhasApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao TDS'), findsOneWidget);
    expect(
      find.text('Autorizo o envio dos meus dados e do progresso à equipe TDS.'),
      findsOneWidget,
    );
  });

  testWidgets('Cadastro pode continuar sem autorizar compartilhamento', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CartilhasApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      'Aluno Teste',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp'),
      '63999990000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF'),
      '52998224725',
    );
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Aprenda no seu ritmo'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('privacy_consent_v1'), isFalse);
  });
}
