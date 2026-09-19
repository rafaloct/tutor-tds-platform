import 'package:cartilhas_app/features/study_ai/presentation/study_generation_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explicita fonte e permite escolher quantidade', (tester) async {
    var count = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyConfigurationPanel(
            source: 'Educação financeira',
            controls: [
              StudyCountSelector(
                value: count,
                options: const [5, 10],
                onChanged: (value) => count = value,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Fonte: Educação financeira'), findsOneWidget);
    expect(find.text('Quantidade'), findsOneWidget);

    await tester.tap(find.text('5 itens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 itens').last);
    await tester.pumpAndSettle();

    expect(count, 10);
  });
}
