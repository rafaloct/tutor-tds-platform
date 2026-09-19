import 'package:cartilhas_app/widgets/tds_wait_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra status e conteúdo local sem spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TdsWaitExperience(
            title: 'Preparando seu quiz',
            status: 'Selecionando o conteúdo...',
            localTip: 'Revise o conceito principal enquanto espera.',
          ),
        ),
      ),
    );

    expect(find.text('Preparando seu quiz'), findsOneWidget);
    expect(find.text('Selecionando o conteúdo...'), findsOneWidget);
    expect(
      find.text('Revise o conceito principal enquanto espera.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
