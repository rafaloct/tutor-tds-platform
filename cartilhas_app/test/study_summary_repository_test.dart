import 'package:cartilhas_app/features/study_ai/data/study_summary_repository.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva resumo por cartilha e recupera como último resumo', () async {
    const repository = StudySummaryRepository();
    final summary = StudySummary(
      title: 'Resumo de Horticultura',
      overview: 'Conceitos fundamentais sobre cultivo agroecológico.',
      keyPoints: [
        'Preparo do solo',
        'Adubação orgânica',
        'Irrigação por gotejamento',
      ],
      practicalExamples: ['Canteiro suspenso na horta comunitária'],
      reviewQuestions: ['Qual a vantagem do gotejamento?'],
    );
    final saved = SavedStudySummary(
      courseId: 'horta-comunitaria',
      topic: 'Horta Comunitária',
      length: SummaryLength.detailed,
      summary: summary,
      createdAt: DateTime.utc(2026, 9, 19, 15, 30),
    );

    await repository.save(saved);

    final byCourse = await repository.load('horta-comunitaria');
    final last = await repository.loadLast();

    expect(byCourse, isNotNull);
    expect(byCourse?.courseId, 'horta-comunitaria');
    expect(byCourse?.topic, 'Horta Comunitária');
    expect(byCourse?.length, SummaryLength.detailed);
    expect(byCourse?.summary.title, 'Resumo de Horticultura');
    expect(byCourse?.summary.keyPoints, hasLength(3));
    expect(
      byCourse?.summary.practicalExamples.single,
      'Canteiro suspenso na horta comunitária',
    );
    expect(
      byCourse?.summary.reviewQuestions.single,
      'Qual a vantagem do gotejamento?',
    );

    expect(last, isNotNull);
    expect(last?.courseId, 'horta-comunitaria');
    expect(last?.summary.title, 'Resumo de Horticultura');
  });

  test('ignora resumo corrompido com fallback seguro para null', () async {
    SharedPreferences.setMockInitialValues({
      'study_summary:course:invalido': '{isto nao e json valido}',
      'study_summary:last': '{"courseId": "1", "createdAt": "data-invalida"}',
    });

    const repository = StudySummaryRepository();
    final byCourse = await repository.load('invalido');
    final last = await repository.loadLast();

    expect(byCourse, isNull);
    expect(last, isNull);
  });

  test('serializa e deserializa SavedStudySummary com precisão', () {
    final original = SavedStudySummary(
      courseId: 'curso-apicultura',
      topic: 'Apicultura Básica',
      length: SummaryLength.quick,
      summary: StudySummary(
        title: 'Manejo de Colmeias',
        overview: 'Visão geral do apiário.',
        keyPoints: ['Uso do fumegador'],
        practicalExamples: ['Inspeção matinal'],
        reviewQuestions: ['Quando alimentar as abelhas?'],
      ),
      createdAt: DateTime.utc(2026, 9, 19, 10, 0),
    );

    final jsonMap = original.toJson();
    final parsed = SavedStudySummary.tryParse(
      '{"courseId": "${jsonMap['courseId']}", "topic": "${jsonMap['topic']}", "length": "${jsonMap['length']}", "summary": {"title": "Manejo de Colmeias", "overview": "Visão geral do apiário.", "keyPoints": ["Uso do fumegador"], "practicalExamples": ["Inspeção matinal"], "reviewQuestions": ["Quando alimentar as abelhas?"]}, "createdAt": "${jsonMap['createdAt']}"}',
    );

    expect(parsed, isNotNull);
    expect(parsed?.courseId, 'curso-apicultura');
    expect(parsed?.topic, 'Apicultura Básica');
    expect(parsed?.length, SummaryLength.quick);
    expect(parsed?.summary.title, 'Manejo de Colmeias');
    expect(parsed?.summary.keyPoints, ['Uso do fumegador']);
  });

  test('permite limpar resumo salvo por cartilha', () async {
    const repository = StudySummaryRepository();
    final saved = SavedStudySummary(
      courseId: 'curso-remover',
      topic: 'Remover',
      length: SummaryLength.quick,
      summary: StudySummary(
        title: 'T',
        overview: 'O',
        keyPoints: [],
        practicalExamples: [],
        reviewQuestions: [],
      ),
      createdAt: DateTime.utc(2026, 9, 19),
    );

    await repository.save(saved);
    expect(await repository.load('curso-remover'), isNotNull);

    await repository.clear('curso-remover');
    expect(await repository.load('curso-remover'), isNull);
  });
}
