import 'dart:convert';

import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/data/study_ai_service.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/features/study_ai/presentation/assessment_feedback_card.dart';
import 'package:cartilhas_app/features/study_ai/presentation/assessment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final sampleDeck = AssessmentDeck(
    title: 'Quiz de Manejo Agroecológico',
    durationMinutes: 10,
    items: [
      StudyQuestion(
        question: 'Qual é o melhor método de irrigação para economizar água?',
        options: [
          'Aspersão ampla',
          'Inundação',
          'Gotejamento',
          'Manual com balde',
        ],
        correctIndex: 2,
        explanation:
            'O gotejamento direciona água diretamente à raiz sem desperdício.',
        topic: 'Irrigação sustentável',
      ),
      StudyQuestion(
        question: 'O que é cobertura morta (mulching)?',
        options: [
          'Palha sobre o solo',
          'Pesticida químico',
          'Adubo mineral',
          'Esterco fresco',
        ],
        correctIndex: 0,
        explanation:
            'A cobertura morta protege a umidade do solo e evita erosão.',
        topic: 'Conservação do solo',
      ),
    ],
  );

  Widget createWidget({
    required StudyAiService service,
    AssessmentMode mode = AssessmentMode.quiz,
    String topic = 'Manejo Agroecológico',
    String courseId = 'manejo-agroecologico',
    AssessmentAttemptRepository repository =
        const AssessmentAttemptRepository(),
    AssessmentAttempt? initialAttempt,
    AssessmentSyncCoordinator? syncCoordinator,
  }) {
    return Provider<StudyAiService>.value(
      value: service,
      child: MaterialApp(
        home: AssessmentScreen(
          topic: topic,
          courseId: courseId,
          mode: mode,
          repository: repository,
          initialAttempt: initialAttempt,
          syncCoordinator: syncCoordinator,
        ),
      ),
    );
  }

  testWidgets(
    'sem tentativa salva, exibe configuração inicial sem chamada de IA',
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

      expect(find.text('Pratique com um quiz'), findsOneWidget);
      expect(find.text('Gerar quiz'), findsOneWidget);
      expect(find.text('Retomar quiz em andamento'), findsNothing);
      expect(aiCalled, isFalse);
    },
  );

  testWidgets(
    'com tentativa em andamento, permite retomar questão sem nova chamada de IA',
    (tester) async {
      const repository = AssessmentAttemptRepository();
      final attempt = AssessmentAttempt(
        id: 'attempt-agro-1',
        courseId: 'manejo-agroecologico',
        topic: 'Manejo Agroecológico',
        mode: AssessmentMode.quiz,
        difficulty: StudyDifficulty.intermediate,
        totalQuestions: 2,
        deck: sampleDeck,
        answers: {0: 2}, // Primeira respondida corretamente
        currentIndex: 1, // Parou na segunda
        remainingSeconds: 0,
        score: 1,
        weakTopics: const [],
        isCompleted: false,
        createdAt: DateTime.utc(2026, 9, 19, 14),
        updatedAt: DateTime.utc(2026, 9, 19, 14, 5),
      );
      await repository.save(attempt);

      var aiCalled = false;
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async {
          aiCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        createWidget(service: service, repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tentativa em andamento'), findsOneWidget);
      expect(find.text('Retomar quiz em andamento'), findsOneWidget);
      expect(aiCalled, isFalse);

      // Toca em retomar
      await tester.tap(find.text('Retomar quiz em andamento'));
      await tester.pumpAndSettle();

      expect(find.text('O que é cobertura morta (mulching)?'), findsOneWidget);
      expect(find.text('Palha sobre o solo'), findsOneWidget);
      expect(aiCalled, isFalse);

      // Responde à segunda questão (índice 0 = 'Palha sobre o solo', correta)
      await tester.tap(find.text('Palha sobre o solo'));
      await tester.pumpAndSettle();

      // Finaliza
      await tester.ensureVisible(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('2 de 2 respostas corretas'), findsOneWidget);

      // Verifica persistência final
      final updated = await repository.load(
        'manejo-agroecologico',
        AssessmentMode.quiz,
      );
      expect(updated, isNotNull);
      expect(updated?.isCompleted, isTrue);
      expect(updated?.score, 2);
    },
  );

  testWidgets('gera nova tentativa com IA e persiste no repositório', (
    tester,
  ) async {
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'material': {
              'title': sampleDeck.title,
              'durationMinutes': sampleDeck.durationMinutes,
              'items': sampleDeck.items.map((i) => i.toJson()).toList(),
            },
          }),
          200,
        );
      }),
    );

    const repository = AssessmentAttemptRepository();
    await tester.pumpWidget(
      createWidget(service: service, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gerar quiz'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Qual é o melhor método de irrigação para economizar água?'),
      findsOneWidget,
    );

    final saved = await repository.load(
      'manejo-agroecologico',
      AssessmentMode.quiz,
    );
    expect(saved, isNotNull);
    expect(saved?.isCompleted, isFalse);
    expect(saved?.totalQuestions, 2);
  });

  testWidgets('simulado persiste revisão e protege entrega incompleta', (
    tester,
  ) async {
    const repository = AssessmentAttemptRepository();
    final attempt = AssessmentAttempt(
      id: 'exam-review',
      courseId: 'manejo-agroecologico',
      topic: 'Manejo Agroecológico',
      mode: AssessmentMode.exam,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: 2,
      deck: sampleDeck,
      answers: const {},
      currentIndex: 1,
      remainingSeconds: 600,
      score: 0,
      weakTopics: const [],
      isCompleted: false,
      createdAt: DateTime.utc(2026, 9, 19, 14),
      updatedAt: DateTime.utc(2026, 9, 19, 14),
    );
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(
      createWidget(
        service: service,
        mode: AssessmentMode.exam,
        repository: repository,
        initialAttempt: attempt,
      ),
    );
    await tester.pump();

    expect(find.text('Salvo neste aparelho'), findsOneWidget);
    await tester.ensureVisible(find.text('Marcar para revisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar para revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Remover marca de revisão'), findsOneWidget);

    await tester.ensureVisible(find.text('Revisar e entregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar e entregar'));
    await tester.pumpAndSettle();
    expect(find.text('Entregar simulado?'), findsOneWidget);
    expect(find.textContaining('2 questão(ões) sem resposta'), findsOneWidget);
    expect(find.text('Voltar e revisar'), findsOneWidget);
    await tester.tap(find.text('Voltar e revisar'));
    await tester.pumpAndSettle();

    final saved = await repository.load(
      'manejo-agroecologico',
      AssessmentMode.exam,
    );
    expect(saved?.reviewQuestionIndexes, {1});
    expect(saved?.isCompleted, isFalse);
  });

  testWidgets(
    'exibe sincronizado somente conforme confirmação do coordenador',
    (tester) async {
      final attempt = _sampleAttempt(sampleDeck);
      final coordinator = _FakeSyncCoordinator(
        AssessmentSyncRecord(
          attemptId: attempt.id,
          status: AssessmentSyncStatus.synced,
          confirmedRevision: 1,
          pending: const [],
        ),
      );
      final service = StudyAiService(
        gatewayUrl: 'https://gateway.example',
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      await tester.pumpWidget(
        createWidget(
          service: service,
          initialAttempt: attempt,
          syncCoordinator: coordinator,
        ),
      );
      await tester.pump();

      expect(find.text('Sincronizado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assessment-sync-status')),
        findsOneWidget,
      );
    },
  );

  testWidgets('conflito oferece escolha sem substituir automaticamente', (
    tester,
  ) async {
    final attempt = _sampleAttempt(sampleDeck);
    final payload = AssessmentSyncPayload.fromAttempt(attempt, revision: 2);
    final coordinator = _FakeSyncCoordinator(
      AssessmentSyncRecord(
        attemptId: attempt.id,
        status: AssessmentSyncStatus.conflict,
        confirmedRevision: 0,
        pending: [AssessmentPendingRevision(payload: payload.withRevision(1))],
        remoteConflict: RemoteAssessmentAttempt(
          attemptId: attempt.id,
          payload: payload,
        ),
      ),
    );
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async => http.Response('{}', 500)),
    );

    await tester.pumpWidget(
      createWidget(
        service: service,
        initialAttempt: attempt,
        syncCoordinator: coordinator,
      ),
    );
    await tester.pump();
    expect(find.text('Conflito de sincronização'), findsOneWidget);

    await tester.tap(find.text('Resolver'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha como continuar'), findsOneWidget);
    expect(find.text('Usar versão online'), findsOneWidget);
    expect(find.text('Manter deste aparelho'), findsOneWidget);
    expect(coordinator.usedRemote, isFalse);
    expect(coordinator.keptLocal, isFalse);
  });

  testWidgets('403 informa matrícula e mantém retry sob ação do aluno', (
    tester,
  ) async {
    final attempt = _sampleAttempt(sampleDeck);
    final coordinator = _FakeSyncCoordinator(
      AssessmentSyncRecord(
        attemptId: attempt.id,
        status: AssessmentSyncStatus.pending,
        confirmedRevision: 0,
        pending: [
          AssessmentPendingRevision(
            payload: AssessmentSyncPayload.fromAttempt(attempt, revision: 1),
            wasAttempted: true,
          ),
        ],
        lastError: 'active_enrollment_required',
      ),
    );
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async => http.Response('{}', 500)),
    );

    await tester.pumpWidget(
      createWidget(
        service: service,
        initialAttempt: attempt,
        syncCoordinator: coordinator,
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Tentativa segura neste aparelho • matrícula ativa necessária para sincronizar',
      ),
      findsOneWidget,
    );
    expect(coordinator.retryCount, 0);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(coordinator.retryCount, 1);
  });

  testWidgets('tentativa remota legada explica limite sem retomada insegura', (
    tester,
  ) async {
    final remotePayload = AssessmentSyncPayload(
      courseId: 'manejo-agroecologico',
      topic: 'Manejo Agroecológico',
      mode: AssessmentMode.quiz,
      revision: 2,
      answers: const {0: 2},
      marked: const {},
      currentIndex: 1,
      remainingSeconds: 0,
      completed: false,
      score: 0,
      updatedAt: DateTime.utc(2026, 9, 20, 15),
    );
    final coordinator = _FakeSyncCoordinator(
      AssessmentSyncRecord(
        attemptId: 'unused',
        status: AssessmentSyncStatus.localOnly,
        confirmedRevision: 0,
        pending: const [],
      ),
      discovered: [
        RemoteAssessmentAttempt(
          attemptId: 'remote-without-deck',
          payload: remotePayload,
        ),
      ],
    );
    var aiCalled = false;
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async {
        aiCalled = true;
        return http.Response('{}', 500);
      }),
    );

    await tester.pumpWidget(
      createWidget(service: service, syncCoordinator: coordinator),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentativa online encontrada'), findsOneWidget);
    expect(
      find.textContaining('antes da retomada entre dispositivos'),
      findsOneWidget,
    );
    expect(find.text('Retomar quiz em andamento'), findsNothing);
    expect(find.text('Tentar recuperar novamente'), findsOneWidget);
    expect(aiCalled, isFalse);
  });

  testWidgets('hidrata tentativa online e oferece retomada em outro aparelho', (
    tester,
  ) async {
    final hydratedDeck = AssessmentDeck(
      title: sampleDeck.title,
      durationMinutes: 0,
      items: [
        for (final question in sampleDeck.items)
          StudyQuestion(
            question: question.question,
            options: question.options,
            correctIndex: -1,
            explanation: '',
            topic: question.topic,
          ),
      ],
    );
    final hydrated = AssessmentAttempt(
      id: 'remote-current',
      assessmentContentId: 'content:remote-current',
      courseId: 'manejo-agroecologico',
      topic: 'Manejo Agroecológico',
      mode: AssessmentMode.quiz,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: 2,
      deck: hydratedDeck,
      answers: const {0: 2},
      currentIndex: 1,
      remainingSeconds: 0,
      score: 0,
      weakTopics: const [],
      isCompleted: false,
      createdAt: DateTime.utc(2026, 9, 20, 14),
      updatedAt: DateTime.utc(2026, 9, 20, 15),
    );
    final remotePayload = AssessmentSyncPayload.fromAttempt(
      hydrated,
      revision: 2,
    );
    final coordinator = _FakeSyncCoordinator(
      AssessmentSyncRecord(
        attemptId: hydrated.id,
        status: AssessmentSyncStatus.synced,
        confirmedRevision: 2,
        confirmedPayload: remotePayload,
        pending: const [],
      ),
      discovered: [
        RemoteAssessmentAttempt(attemptId: hydrated.id, payload: remotePayload),
      ],
      hydratedAttempt: hydrated,
    );
    final service = StudyAiService(
      gatewayUrl: 'https://gateway.example',
      client: MockClient((_) async => http.Response('{}', 500)),
    );

    await tester.pumpWidget(
      createWidget(service: service, syncCoordinator: coordinator),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentativa em andamento'), findsOneWidget);
    expect(find.text('Retomar quiz em andamento'), findsOneWidget);
    expect(find.text('Tentativa online encontrada'), findsNothing);
    await tester.tap(find.text('Retomar quiz em andamento'));
    await tester.pumpAndSettle();
    expect(find.text('O que é cobertura morta (mulching)?'), findsOneWidget);
    expect(find.byType(AssessmentFeedbackCard), findsNothing);
  });
}

AssessmentAttempt _sampleAttempt(AssessmentDeck deck) => AssessmentAttempt(
  id: 'attempt-sync-ui',
  courseId: 'manejo-agroecologico',
  topic: 'Manejo Agroecológico',
  mode: AssessmentMode.quiz,
  difficulty: StudyDifficulty.intermediate,
  totalQuestions: deck.items.length,
  deck: deck,
  answers: const {},
  currentIndex: 0,
  remainingSeconds: 0,
  score: 0,
  weakTopics: const [],
  isCompleted: false,
  createdAt: DateTime.utc(2026, 9, 20, 14),
  updatedAt: DateTime.utc(2026, 9, 20, 14),
);

class _FakeSyncCoordinator implements AssessmentSyncCoordinator {
  _FakeSyncCoordinator(
    this.record, {
    this.discovered = const [],
    this.hydratedAttempt,
  });

  AssessmentSyncRecord record;
  final List<RemoteAssessmentAttempt> discovered;
  final AssessmentAttempt? hydratedAttempt;
  bool usedRemote = false;
  bool keptLocal = false;
  int retryCount = 0;

  @override
  Future<AssessmentSyncRecord> queueAndSync(AssessmentAttempt attempt) async =>
      record;

  @override
  Future<AssessmentSyncRecord> queueAttempt(AssessmentAttempt attempt) async =>
      record;

  @override
  Future<AssessmentSyncRecord> refreshConflict(String attemptId) async =>
      record;

  @override
  Future<AssessmentSyncRecord> retry(String attemptId) async {
    retryCount++;
    return record;
  }

  @override
  Future<List<RemoteAssessmentAttempt>> discoverIncomplete({
    required String courseId,
    required AssessmentMode mode,
  }) async => discovered;

  @override
  Future<AssessmentAttempt> hydrateRemoteAttempt(
    RemoteAssessmentAttempt remote,
  ) async {
    final hydrated = hydratedAttempt;
    if (hydrated == null) throw const AssessmentLegacyContentException();
    return hydrated;
  }

  @override
  Future<AssessmentSyncRecord> registerDiscovered(
    AssessmentAttempt local,
    RemoteAssessmentAttempt remote,
  ) async => record;

  @override
  Future<AssessmentAttempt> resolveUsingRemote(AssessmentAttempt local) async {
    usedRemote = true;
    return local;
  }

  @override
  Future<AssessmentSyncRecord> resolveKeepingLocal(
    AssessmentAttempt local,
  ) async {
    keptLocal = true;
    return record;
  }

  @override
  Future<AssessmentSyncRecord?> status(String attemptId) async => record;
}
