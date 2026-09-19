import 'package:cartilhas_app/features/study_ai/presentation/study_hub_screen.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the AI study overview and all resources', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartilha = Cartilha(
      id: 'teste',
      title: 'Cartilha de teste',
      author: 'TDS',
      sections: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: StudyHubScreen(cartilhas: [cartilha])),
    );

    expect(find.text('Visão geral da IA'), findsOneWidget);
    expect(find.text('Chat com IA'), findsOneWidget);
    expect(find.text('Cartões de estudo'), findsOneWidget);
    expect(find.text('Quiz com IA'), findsOneWidget);
    expect(find.text('Resumo com IA'), findsOneWidget);
    expect(find.text('Simulado com IA'), findsOneWidget);
    expect(find.text('Cartilha de teste'), findsOneWidget);
  });
}
