import 'package:cartilhas_app/features/media/presentation/media_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avaliação explícita confirma somente após callback', (
    tester,
  ) async {
    int? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaRatingPanel(
            rating: null,
            loading: false,
            submitting: false,
            issue: null,
            onRate: (value) async => submitted = value,
          ),
        ),
      ),
    );

    expect(find.text('Avalie este conteúdo'), findsOneWidget);
    expect(
      find.text('Disponível após a conclusão qualificada do vídeo.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('4 de 5'));
    await tester.pump();
    expect(submitted, 4);
    expect(find.text('Sua avaliação: 4 de 5.'), findsNothing);
  });

  testWidgets('mostra confirmação, envio e causa de bloqueio acessíveis', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaRatingPanel(
            rating: 5,
            loading: false,
            submitting: true,
            issue:
                'Conclua o vídeo antes de avaliar. A conclusão pode levar alguns instantes para sincronizar.',
            onRate: _ignoreRating,
          ),
        ),
      ),
    );

    expect(find.text('Sua avaliação: 5 de 5.'), findsOneWidget);
    expect(find.text('Enviando avaliação...'), findsOneWidget);
    expect(find.textContaining('Conclua o vídeo antes'), findsOneWidget);
  });
}

Future<void> _ignoreRating(int _) async {}
