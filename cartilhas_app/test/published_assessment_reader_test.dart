import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_controller.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('falha local mantém pergunta visível e impede avanço', (
    tester,
  ) async {
    final store = _Store()..failWrites = true;
    final sync = _Sync();
    await _open(tester, store: store, sync: sync);

    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();

    expect(find.text('Alternativa A').hitTestable(), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.textContaining('Não foi possível salvar'), findsWidgets);
    expect(sync.queued, isEmpty);
  });

  testWidgets('feature ligada bloqueia bloco versionado sem contexto', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync();
    await _open(tester, store: store, sync: sync, withLearningContext: false);

    expect(
      find.byKey(const Key('published-assessment-blocked')),
      findsOneWidget,
    );
    expect(find.textContaining('Atividade indisponível'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Alternativa A'), findsNothing);
    expect(find.text('Continuar'), findsNothing);
    expect(store.value, isNull);
    expect(sync.queued, isEmpty);
  });

  testWidgets(
    'curso contextual bloqueia bloco com linhagem editorial incompleta',
    (tester) async {
      final store = _Store();
      final sync = _Sync();
      await _open(
        tester,
        store: store,
        sync: sync,
        course: _course(completeLineage: false),
      );

      expect(
        find.byKey(const Key('published-assessment-blocked')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Alternativa A'),
        findsNothing,
      );
      expect(find.text('Continuar'), findsNothing);
      expect(store.value, isNull);
      expect(sync.queued, isEmpty);
    },
  );

  testWidgets('cartilha local sem linhagem mantém o caminho legado', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync();
    await _open(
      tester,
      store: store,
      sync: sync,
      withLearningContext: false,
      course: _legacyCourse(),
    );

    expect(
      find.widgetWithText(ElevatedButton, 'Alternativa A'),
      findsOneWidget,
    );
    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(store.value, isNull);
    expect(sync.queued, isEmpty);
  });

  testWidgets('falha da fila durável mantém pergunta visível para retry', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync()..failQueue = true;
    await _open(tester, store: store, sync: sync);

    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();

    expect(store.value?.answers, {0: 0});
    expect(find.text('Alternativa A').hitTestable(), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.textContaining('envio precisa ser tentado'), findsWidgets);
    expect(sync.queued, isEmpty);

    sync.failQueue = false;
    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    expect(sync.queued.single.id, store.value?.id);
  });

  testWidgets(
    'retomada reconstrói fila de conclusão local perdida antes do envio',
    (tester) async {
      final store = _Store();
      final sync = _Sync();
      await _open(tester, store: store, sync: sync);

      await tester.tap(find.text('Alternativa A'));
      await tester.pumpAndSettle();
      expect(store.value?.answers, {0: 0});

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      store.value = store.value!.copyWith(isCompleted: true);
      sync
        ..record = null
        ..queued.clear();

      await _open(tester, store: store, sync: sync);

      expect(find.text('Continuar'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Alternativa A'),
        findsNothing,
      );
      expect(sync.queued, hasLength(1));
      expect(sync.queued.single.isCompleted, isTrue);
      expect(sync.queued.single.id, store.value?.id);
    },
  );

  testWidgets('403 conhecido bloqueia ações e permanece bloqueado ao reabrir', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync()..denyOnRetry = true;
    await _open(tester, store: store, sync: sync);

    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('published-assessment-access-denied')),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Alternativa A'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _open(tester, store: store, sync: sync);

    expect(
      find.byKey(const Key('published-assessment-access-denied')),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Alternativa A'), findsNothing);
  });

  testWidgets('404 conhecido bloqueia opções até retry aceito pelo serviço', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync()..retryError = 'dynamic_activity_unavailable';
    await _open(tester, store: store, sync: sync);

    await tester.tap(find.text('Alternativa A'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('published-assessment-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Alternativa A'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('published-assessment-review-toggle')),
          )
          .onPressed,
      isNull,
    );

    sync.retryError = null;
    await tester.tap(find.text('Tentar envio novamente'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('published-assessment-unavailable')),
      findsNothing,
    );
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('marca revisão e só avança depois de tentativa + fila duráveis', (
    tester,
  ) async {
    final store = _Store();
    final sync = _Sync();
    await _open(tester, store: store, sync: sync);

    await tester.tap(find.text('Marcar para revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Remover marca de revisão'), findsOneWidget);
    expect(store.value?.reviewQuestionIndexes, {0});

    await tester.tap(find.text('Alternativa B'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(store.value?.answers, {0: 1});
    final attemptId = store.value?.id;

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Próximo conteúdo'), findsOneWidget);
    expect(store.value?.isCompleted, isTrue);
    expect(store.value?.id, attemptId);
    expect(sync.queued.last.isCompleted, isTrue);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required _Store store,
  required _Sync sync,
  bool withLearningContext = true,
  Cartilha? course,
}) async {
  LearningContextController? learning;
  if (withLearningContext) {
    learning = LearningContextController(_Contexts(_snapshot()));
    addTearDown(learning.dispose);
    await learning.load('class-1');
  }
  await tester.pumpWidget(
    Provider<LearningEventSyncService>.value(
      value: _OfflineLearningSync(),
      child: MaterialApp(
        home: ChatExperienceScreen(
          cartilha: course ?? _course(),
          progressOwnerId: 'student-1',
          learningContextController: learning,
          dynamicActivityEnabled: true,
          assessmentApiUrl: 'https://api.example',
          assessmentAttemptStore: store,
          assessmentSyncCoordinator: sync,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Cartilha _course({bool completeLineage = true}) => Cartilha(
  id: 'course-1',
  title: 'Curso publicado',
  author: 'TDS',
  classId: 'class-1',
  courseVersionId: 'version-1',
  legacyProgressCompatible: false,
  sections: [
    Section(
      id: 'section-1',
      versionId: completeLineage ? 'section-version-1' : null,
      title: 'Módulo',
      messages: [
        Message(
          id: completeLineage ? 'block-1' : null,
          versionId: completeLineage ? 'block-version-1' : null,
          type: 'quiz',
          content: 'Pergunta publicada?',
          options: [
            Option(label: 'Alternativa A', isCorrect: true),
            Option(label: 'Alternativa B', isCorrect: true),
          ],
        ),
        Message(type: 'bot', content: 'Próximo conteúdo'),
      ],
    ),
  ],
);

Cartilha _legacyCourse() => Cartilha(
  id: 'course-1',
  title: 'Curso local',
  author: 'TDS',
  sections: [
    Section(
      id: 'section-1',
      title: 'Módulo',
      messages: [
        Message(
          type: 'quiz',
          content: 'Pergunta local?',
          options: [
            Option(label: 'Alternativa A', isCorrect: true),
            Option(label: 'Alternativa B', isCorrect: false),
          ],
        ),
        Message(type: 'bot', content: 'Próximo conteúdo'),
      ],
    ),
  ],
);

LearningContextSnapshot _snapshot() => LearningContextSnapshot.fromJson({
  'context': {
    'user_id': 'student-1',
    'organization_id': 'org-1',
    'program_id': 'program-1',
    'cohort_id': 'class-1',
    'membership_id': 'membership-1',
    'role': 'student',
    'course_id': 'course-1',
    'course_version_id': 'version-1',
    'enrollment_id': 'context-enrollment-1',
    'legacy_enrollment_id': 'legacy-enrollment-1',
    'permissions': ['content.read', 'progress.read', 'activity.record'],
  },
  'progress': {
    'user_id': 'student-1',
    'enrollment_id': 'legacy-enrollment-1',
    'context_enrollment_id': 'context-enrollment-1',
    'progress_percent': 0.0,
    'validated_hours': 0.0,
  },
  'resolved_at': '2026-10-07T12:00:00Z',
  'contract_version': 'cohort-enrollment-v2',
});

class _Contexts implements LearningContextRepository {
  _Contexts(this.snapshot);
  final LearningContextSnapshot snapshot;

  @override
  Future<LearningContextSnapshot> resolve(String cohortId) async => snapshot;
}

class _OfflineLearningSync implements LearningEventSyncService {
  @override
  String get apiUrl => 'https://api.example';

  @override
  Future<int> flush() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements PublishedAssessmentAttemptStore {
  AssessmentAttempt? value;
  bool failWrites = false;

  @override
  Future<AssessmentAttempt?> loadPublished(
    PublishedAssessmentContext context,
  ) async => value?.publishedContext?.sameAs(context) == true ? value : null;

  @override
  Future<void> saveConfirmed(AssessmentAttempt attempt) async {
    if (failWrites) throw StateError('disk full');
    value = attempt;
  }
}

class _Sync
    implements AssessmentSyncCoordinator, PublishedAssessmentSyncCoordinator {
  final List<AssessmentAttempt> queued = [];
  AssessmentSyncRecord? record;
  bool failQueue = false;
  bool denyOnRetry = false;
  String? retryError;

  @override
  Future<AssessmentSyncRecord> queueAttempt(AssessmentAttempt attempt) async {
    if (failQueue) throw StateError('queue unavailable');
    queued.add(attempt);
    return record = AssessmentSyncRecord(
      attemptId: attempt.id,
      status: AssessmentSyncStatus.pending,
      confirmedRevision: 0,
      pending: [
        AssessmentPendingRevision(
          payload: AssessmentSyncPayload.fromAttempt(
            attempt,
            revision: queued.length,
          ),
        ),
      ],
      localContext: attempt.publishedContext,
    );
  }

  @override
  Future<AssessmentSyncRecord> retry(String attemptId) async {
    final error = denyOnRetry ? 'active_enrollment_required' : retryError;
    if (error == null) {
      final current = record!;
      if (current.lastError == null) return current;
      return record = AssessmentSyncRecord(
        attemptId: current.attemptId,
        status: current.status,
        confirmedRevision: current.confirmedRevision,
        confirmedPayload: current.confirmedPayload,
        pending: current.pending,
        localContext: current.localContext,
      );
    }
    final current = record!;
    return record = AssessmentSyncRecord(
      attemptId: current.attemptId,
      status: AssessmentSyncStatus.pending,
      confirmedRevision: current.confirmedRevision,
      confirmedPayload: current.confirmedPayload,
      pending: current.pending,
      localContext: current.localContext,
      lastError: error,
    );
  }

  @override
  Future<AssessmentSyncRecord?> status(String attemptId) async => record;

  @override
  Future<RemoteAssessmentAttempt?> findPublishedAttempt(
    PublishedAssessmentContext context,
    String attemptId,
  ) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
