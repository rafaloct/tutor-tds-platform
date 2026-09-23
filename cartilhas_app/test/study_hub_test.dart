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

  for (final width in [320.0, 1000.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'resources remain reachable at width $width and scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final cartilha = Cartilha(
            id: 'remote-course',
            title: 'Curso remoto edição 2',
            author: 'TDS',
            sections: const [],
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: StudyHubScreen(cartilhas: [cartilha]),
            ),
          );
          await tester.pumpAndSettle();
          for (final title in [
            'Chat com IA',
            'Cartões de estudo',
            'Quiz com IA',
            'Resumo com IA',
            'Simulado com IA',
          ]) {
            await tester.scrollUntilVisible(
              find.text(title),
              300,
              scrollable: find.descendant(
                of: find.byType(StudyHubScreen),
                matching: find.byType(Scrollable),
              ),
              maxScrolls: 30,
            );
            await tester.pumpAndSettle();
            expect(find.text(title).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
