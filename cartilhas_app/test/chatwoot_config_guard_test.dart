import 'package:cartilhas_app/screens/chatwoot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support fails closed when Chatwoot widget config is absent', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatwootScreen()));

    expect(find.text('Não foi possível conectar ao suporte.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
