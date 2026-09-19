import 'package:cartilhas_app/features/study_ai/presentation/flashcard_review_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra origem e autoavaliação dos cartões', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlashcardReviewStatus(
            source: 'Economia do lar',
            remembered: 3,
            toReview: 2,
          ),
        ),
      ),
    );

    expect(find.text('Fonte: Economia do lar'), findsOneWidget);
    expect(find.text('3 lembrei'), findsOneWidget);
    expect(find.text('2 para revisar'), findsOneWidget);
  });
}
