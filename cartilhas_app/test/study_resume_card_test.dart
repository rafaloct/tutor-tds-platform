import 'package:cartilhas_app/widgets/study_resume_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra a próxima ação e abre a cartilha', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyResumeCard(
            courseTitle: 'Agricultura sustentável',
            progress: 0.5,
            isCompleted: false,
            onPressed: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('Continuar estudando'), findsOneWidget);
    expect(find.text('Agricultura sustentável'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(StudyResumeCard));
    expect(opened, isTrue);
  });
}
