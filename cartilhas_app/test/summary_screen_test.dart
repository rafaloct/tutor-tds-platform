import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/data/study_summary_repository.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/features/study_ai/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget createWidget({
    required StudyAiService service,
    String topic = 'Agricultura Familiar',
    String courseId = 'agricultura-familiar',
    StudySummaryRepository repository = const StudySummaryRepository(),
  }) {
    return Provider<StudyAiService>.value(
      value: service,
      child: MaterialApp(
        home: SummaryScreen(
          topic: topic,
          courseId: courseId,
          repository: repository,
        ),
      ),
    );
  }

  testWidgets(
    'sem resumo salvo, exibe estado inicial sem chamar IA automaticamente',
    (tester) async {
      var aiCalled = false;
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          aiCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(createWidget(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Resuma a cartilha'), findsOneWidget);
      expect(find.text('Gerar com IA'), findsOneWidget);
      expect(find.text('Abrir último resumo'), findsNothing);
      expect(aiCalled, isFalse);
    },
  );

  testWidgets(
    'com resumo salvo, oferece "Abrir último resumo" e "Gerar novo resumo" sem chamar IA',
    (tester) async {
      const repository = StudySummaryRepository();
      await repository.save(
        SavedStudySummary(
          courseId: 'agricultura-familiar',
          topic: 'Agricultura Familiar',
          length: SummaryLength.quick,
          summary: StudySummary(
            title: 'Resumo Salvo de Agricultura',
            overview: 'Visão geral previamente gerada e armazenada.',
            keyPoints: ['Ponto A salvo localmente', 'Ponto B salvo localmente'],
            practicalExamples: ['Exemplo local de compostagem'],
            reviewQuestions: ['Como aplicar o adubo?'],
          ),
          createdAt: DateTime.utc(2026, 9, 19, 14, 0),
        ),
      );

      var aiCalled = false;
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          aiCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(createWidget(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Último resumo salvo'), findsOneWidget);
      expect(find.text('Abrir último resumo'), findsOneWidget);
      expect(find.text('Gerar novo resumo'), findsOneWidget);
      expect(aiCalled, isFalse);

      // Toca em "Abrir último resumo"
      await tester.tap(find.text('Abrir último resumo'));
      await tester.pumpAndSettle();

      expect(find.text('Resumo Salvo de Agricultura'), findsOneWidget);
      expect(
        find.text('Visão geral previamente gerada e armazenada.'),
        findsOneWidget,
      );
      expect(find.text('Ponto A salvo localmente'), findsOneWidget);
      expect(find.textContaining('Resumo offline'), findsOneWidget);
      expect(aiCalled, isFalse);
    },
  );

  testWidgets(
    'ao tocar em gerar novo resumo, consulta IA e persiste o material',
    (tester) async {
      final summaryPayload = {
        'material': {
          'title': 'Novo Resumo Gerado',
          'overview': 'Nova visão geral gerada pela IA.',
          'keyPoints': ['Ponto novo 1'],
          'practicalExamples': ['Exemplo novo'],
          'reviewQuestions': ['Questão nova?'],
        },
      };

      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          return http.Response(jsonEncode(summaryPayload), 200);
        }),
      );

      const repository = StudySummaryRepository();
      await tester.pumpWidget(
        createWidget(service: service, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gerar com IA'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Novo Resumo Gerado'), findsOneWidget);
      expect(find.text('Nova visão geral gerada pela IA.'), findsOneWidget);
      expect(find.text('Ponto novo 1'), findsOneWidget);

      // Confirma que foi persistido no repositório
      final saved = await repository.load('agricultura-familiar');
      expect(saved, isNotNull);
      expect(saved?.summary.title, 'Novo Resumo Gerado');
    },
  );
}
