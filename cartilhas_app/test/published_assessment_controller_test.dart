import 'dart:async';

import 'package:cartilhas_app/features/study_ai/application/published_assessment_controller.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'usa identidade estável e salva localmente antes de enfileirar',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls);
      final controller = PublishedAssessmentController(store, sync);
      addTearDown(controller.dispose);
      await controller.open(_block());

      expect(await controller.selectOption(1), isTrue);
      final firstId = controller.attempt?.id;

      expect(calls.take(2), ['save', 'queue']);
      expect(firstId, _block().attemptId);
      expect(controller.attempt?.assessmentContentId, isNull);
      expect(controller.attempt?.origin, AssessmentOrigin.publishedBlock);
      expect(controller.selectedOptionIndex, 1);
      expect(controller.selectionReady, isTrue);

      final restarted = PublishedAssessmentController(store, sync);
      addTearDown(restarted.dispose);
      await restarted.open(_block());
      expect(restarted.attempt?.id, firstId);
      expect(restarted.selectedOptionIndex, 1);
    },
  );

  test('identidade canônica exclui API local e ordena owner + linhagem', () {
    final first = _block();
    final anotherApi = _block(
      context: _context(api: 'https://outro-endpoint.example/v2/'),
    );
    final anotherOwner = _block(context: _context(owner: 'student-2'));

    expect(
      first.attemptId,
      'attempt:published:'
      '8c1c7c3a91d2c8980695a9fd3ce1328b8182cbc8433d2693',
    );
    expect(anotherApi.attemptId, first.attemptId);
    expect(
      anotherApi.context.storageDiscriminator,
      isNot(first.context.storageDiscriminator),
    );
    expect(anotherOwner.attemptId, isNot(first.attemptId));
  });

  test(
    'falha local mantém o bloco parado e retry conserva o mesmo ID',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls)..failWrites = true;
      final sync = _FakeSync(calls);
      final controller = PublishedAssessmentController(store, sync);
      addTearDown(controller.dispose);
      final block = _block();
      await controller.open(block);

      expect(await controller.selectOption(0), isFalse);
      expect(sync.queuedIds, isEmpty);
      expect(controller.selectedOptionIndex, isNull);
      expect(controller.error, contains('Não foi possível salvar'));
      expect(await controller.complete(), isFalse);

      store.failWrites = false;
      expect(await controller.selectOption(0), isTrue);
      expect(controller.attempt?.id, block.attemptId);
      expect(sync.queuedIds.single, block.attemptId);
    },
  );

  test(
    'marca e desmarca revisão na mesma tentativa antes de concluir',
    () async {
      final calls = <String>[];
      final controller = PublishedAssessmentController(
        _MemoryStore(calls),
        _FakeSync(calls),
      );
      addTearDown(controller.dispose);
      await controller.open(_block());

      expect(await controller.toggleReview(), isTrue);
      final attemptId = controller.attempt?.id;
      expect(controller.markedForReview, isTrue);

      expect(await controller.toggleReview(), isTrue);
      expect(controller.markedForReview, isFalse);
      expect(controller.attempt?.id, attemptId);

      expect(await controller.selectOption(2), isTrue);
      expect(await controller.complete(), isTrue);
      expect(controller.isCompleted, isTrue);
      expect(controller.attempt?.remainingSeconds, 0);
    },
  );

  test(
    'reinício após falha da fila retoma o mesmo ID antes de liberar',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls)..failQueue = true;
      final first = PublishedAssessmentController(store, sync);
      addTearDown(first.dispose);
      final block = _block();
      await first.open(block);

      expect(await first.selectOption(1), isFalse);
      expect(first.selectedOptionIndex, 1);
      expect(first.selectionReady, isFalse);

      final restarted = PublishedAssessmentController(store, sync);
      addTearDown(restarted.dispose);
      await restarted.open(block);
      expect(restarted.attempt?.id, block.attemptId);
      expect(restarted.selectedOptionIndex, 1);
      expect(restarted.selectionReady, isFalse);

      sync.failQueue = false;
      expect(await restarted.retry(), isTrue);
      expect(restarted.selectionReady, isTrue);
      expect(sync.queuedIds.single, block.attemptId);
    },
  );

  test(
    'reinício reconstrói fila ausente de tentativa local concluída',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls);
      final first = PublishedAssessmentController(store, sync);
      addTearDown(first.dispose);
      final block = _block();
      await first.open(block);
      expect(await first.selectOption(1), isTrue);
      expect(await first.complete(), isTrue);
      expect(store.value?.isCompleted, isTrue);

      sync
        ..record = null
        ..queuedIds.clear();
      final restarted = PublishedAssessmentController(store, sync);
      addTearDown(restarted.dispose);
      await restarted.open(block);

      expect(restarted.attempt?.id, block.attemptId);
      expect(restarted.isCompleted, isTrue);
      expect(restarted.selectionReady, isTrue);
      expect(restarted.error, isNull);
      expect(sync.queuedIds, [block.attemptId]);
      expect(await restarted.complete(), isTrue);
    },
  );

  test('conclusão remota prevalece sobre rascunho local na retomada', () async {
    final calls = <String>[];
    final store = _MemoryStore(calls);
    final sync = _FakeSync(calls);
    final first = PublishedAssessmentController(store, sync);
    addTearDown(first.dispose);
    final block = _block();
    await first.open(block);
    expect(await first.selectOption(1), isTrue);

    final completed = store.value!.copyWith(
      isCompleted: true,
      score: 1,
      updatedAt: DateTime.utc(2026, 10, 7, 13),
    );
    sync.foundRemote = RemoteAssessmentAttempt(
      attemptId: completed.id,
      payload: AssessmentSyncPayload.fromAttempt(completed, revision: 2),
    );
    sync.hydratedAttempt = completed;

    final restarted = PublishedAssessmentController(store, sync);
    addTearDown(restarted.dispose);
    await restarted.open(block);

    expect(restarted.isCompleted, isTrue);
    expect(restarted.selectionReady, isTrue);
    expect(store.value?.isCompleted, isTrue);
    expect(await restarted.complete(), isTrue);
    expect(sync.queuedIds, hasLength(1));
  });

  test('conclusão remota sem cache local não é reenfileirada', () async {
    final calls = <String>[];
    final store = _MemoryStore(calls);
    final sync = _FakeSync(calls);
    final block = _block();
    final completed = _completedAttempt(block);
    sync.foundRemote = RemoteAssessmentAttempt(
      attemptId: completed.id,
      payload: AssessmentSyncPayload.fromAttempt(completed, revision: 3),
    );
    sync.hydratedAttempt = completed;
    final controller = PublishedAssessmentController(store, sync);
    addTearDown(controller.dispose);

    await controller.open(block);

    expect(controller.isCompleted, isTrue);
    expect(controller.selectionReady, isTrue);
    expect(sync.queuedIds, isEmpty);
  });

  test(
    '403 assíncrono bloqueia conclusão e continua bloqueado ao reabrir',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls)
        ..denyOnRetry = true
        ..retryObserved = Completer<void>();
      final controller = PublishedAssessmentController(store, sync);
      addTearDown(controller.dispose);
      final block = _block();
      await controller.open(block);

      expect(await controller.selectOption(1), isTrue);
      await sync.retryObserved!.future;
      await Future<void>.delayed(Duration.zero);

      expect(controller.accessDenied, isTrue);
      expect(controller.selectionReady, isFalse);
      expect(controller.error, contains('não está ativo'));
      expect(await controller.complete(), isFalse);

      final restarted = PublishedAssessmentController(store, sync);
      addTearDown(restarted.dispose);
      await restarted.open(block);
      expect(restarted.accessDenied, isTrue);
      expect(restarted.selectionReady, isFalse);
      expect(await restarted.complete(), isFalse);
    },
  );

  test(
    '404 explícito da API bloqueia avanço, mas permite novo retry',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls)
        ..retryError = 'dynamic_activity_unavailable'
        ..retryObserved = Completer<void>();
      final controller = PublishedAssessmentController(store, sync);
      addTearDown(controller.dispose);
      final block = _block();
      await controller.open(block);

      expect(await controller.selectOption(1), isTrue);
      await sync.retryObserved!.future;
      await Future<void>.delayed(Duration.zero);

      expect(controller.activityUnavailable, isTrue);
      expect(controller.selectionReady, isFalse);
      expect(controller.error, contains('não está disponível'));
      expect(await controller.complete(), isFalse);

      sync.retryError = null;
      expect(await controller.retry(), isTrue);
      expect(controller.activityUnavailable, isFalse);
      expect(controller.selectionReady, isTrue);
    },
  );

  test(
    '2xx inválido conhecido não é tratado como offline utilizável',
    () async {
      final calls = <String>[];
      final store = _MemoryStore(calls);
      final sync = _FakeSync(calls)
        ..retryError = 'invalid_server_response'
        ..retryObserved = Completer<void>();
      final controller = PublishedAssessmentController(store, sync);
      addTearDown(controller.dispose);
      await controller.open(_block());

      expect(await controller.selectOption(1), isTrue);
      await sync.retryObserved!.future;
      await Future<void>.delayed(Duration.zero);

      expect(controller.activityUnavailable, isTrue);
      expect(controller.selectionReady, isFalse);
      expect(controller.error, contains('não está disponível'));
      expect(await controller.complete(), isFalse);
    },
  );

  test('conflito durável não libera bloco concluído nem retry', () async {
    final calls = <String>[];
    final sync = _FakeSync(calls)..forceConflict = true;
    final controller = PublishedAssessmentController(_MemoryStore(calls), sync);
    addTearDown(controller.dispose);
    await controller.open(_block());

    expect(await controller.selectOption(0), isFalse);
    expect(controller.selectedOptionIndex, 0);
    expect(controller.error, contains('outra revisão'));
    expect(await controller.complete(), isFalse);
    expect(controller.isCompleted, isFalse);
    expect(await controller.complete(), isFalse);
    expect(await controller.retry(), isFalse);
  });
}

PublishedAssessmentContext _context({
  String owner = 'student-1',
  String api = 'https://api.example/',
  String classId = 'class-1',
  String courseVersion = 'version-1',
  String block = 'block-1',
}) => PublishedAssessmentContext(
  ownerId: owner,
  apiUrl: api,
  lineage: PublishedAssessmentLineage(
    organizationId: 'org-1',
    programId: 'program-1',
    classId: classId,
    membershipId: 'membership-$classId',
    enrollmentId: 'context-enrollment-$classId',
    legacyEnrollmentId: 'legacy-enrollment-1',
    courseId: 'course-1',
    courseVersionId: courseVersion,
    sectionId: 'section-1',
    sectionVersionId: 'section-version-1',
    blockId: block,
    blockVersionId: 'block-version-1',
  ),
);

PublishedAssessmentBlock _block({PublishedAssessmentContext? context}) =>
    PublishedAssessmentBlock(
      courseId: 'course-1',
      courseTitle: 'Curso',
      section: Section(
        id: 'section-1',
        versionId: 'section-version-1',
        title: 'Módulo',
        messages: const [],
      ),
      message: Message(
        id: 'block-1',
        versionId: 'block-version-1',
        type: 'quiz',
        content: 'Qual alternativa?',
        options: [
          Option(label: 'A', isCorrect: true),
          Option(label: 'B', isCorrect: true),
          Option(label: 'C', isCorrect: false),
        ],
      ),
      context: context ?? _context(),
    );

AssessmentAttempt _completedAttempt(PublishedAssessmentBlock block) {
  final now = DateTime.utc(2026, 10, 7, 12);
  return AssessmentAttempt(
    id: block.attemptId,
    origin: AssessmentOrigin.publishedBlock,
    publishedContext: block.context,
    courseId: block.courseId,
    topic: block.section.title,
    mode: AssessmentMode.quiz,
    difficulty: StudyDifficulty.intermediate,
    totalQuestions: 1,
    deck: AssessmentDeck(
      title: 'Curso • Módulo',
      durationMinutes: 0,
      items: [
        StudyQuestion(
          question: 'Qual alternativa?',
          options: ['A', 'B', 'C'],
          correctIndex: -1,
          correctIndexes: {},
          graded: false,
          explanation: '',
          topic: 'Módulo',
        ),
      ],
    ),
    answers: const {0: 1},
    currentIndex: 0,
    remainingSeconds: 0,
    score: 0,
    weakTopics: const [],
    isCompleted: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryStore implements PublishedAssessmentAttemptStore {
  _MemoryStore(this.calls);

  final List<String> calls;
  AssessmentAttempt? value;
  bool failWrites = false;

  @override
  Future<AssessmentAttempt?> loadPublished(
    PublishedAssessmentContext context,
  ) async => value?.publishedContext?.sameAs(context) == true ? value : null;

  @override
  Future<void> saveConfirmed(AssessmentAttempt attempt) async {
    calls.add('save');
    if (failWrites) throw StateError('disk full');
    value = attempt;
  }
}

class _FakeSync
    implements AssessmentSyncCoordinator, PublishedAssessmentSyncCoordinator {
  _FakeSync(this.calls);

  final List<String> calls;
  final List<String> queuedIds = [];
  AssessmentSyncRecord? record;
  bool forceConflict = false;
  bool failQueue = false;
  bool denyOnRetry = false;
  String? retryError;
  Completer<void>? retryObserved;
  RemoteAssessmentAttempt? foundRemote;
  AssessmentAttempt? hydratedAttempt;

  AssessmentSyncRecord _record(AssessmentAttempt attempt) =>
      AssessmentSyncRecord(
        attemptId: attempt.id,
        status: AssessmentSyncStatus.pending,
        confirmedRevision: 0,
        pending: [
          AssessmentPendingRevision(
            payload: AssessmentSyncPayload.fromAttempt(attempt, revision: 1),
          ),
        ],
        localContext: attempt.publishedContext,
      );

  @override
  Future<AssessmentSyncRecord> queueAttempt(AssessmentAttempt attempt) async {
    if (failQueue) throw StateError('queue unavailable');
    calls.add('queue');
    queuedIds.add(attempt.id);
    final queued = _record(attempt);
    if (!forceConflict) return record = queued;
    return record = AssessmentSyncRecord(
      attemptId: queued.attemptId,
      status: AssessmentSyncStatus.conflict,
      confirmedRevision: queued.confirmedRevision,
      pending: queued.pending,
      localContext: queued.localContext,
      lastError: 'revision_conflict',
    );
  }

  @override
  Future<AssessmentSyncRecord> retry(String attemptId) async {
    final error = denyOnRetry ? 'active_enrollment_required' : retryError;
    if (error != null) {
      final current = record!;
      record = AssessmentSyncRecord(
        attemptId: current.attemptId,
        status: AssessmentSyncStatus.pending,
        confirmedRevision: current.confirmedRevision,
        confirmedPayload: current.confirmedPayload,
        pending: current.pending,
        localContext: current.localContext,
        lastError: error,
      );
      final observed = retryObserved;
      if (observed != null && !observed.isCompleted) observed.complete();
      return record!;
    }
    final current = record!;
    if (current.lastError != null) {
      record = AssessmentSyncRecord(
        attemptId: current.attemptId,
        status: current.status,
        confirmedRevision: current.confirmedRevision,
        confirmedPayload: current.confirmedPayload,
        pending: current.pending,
        localContext: current.localContext,
      );
    }
    return record!;
  }

  @override
  Future<AssessmentSyncRecord?> status(String attemptId) async => record;

  @override
  Future<RemoteAssessmentAttempt?> findPublishedAttempt(
    PublishedAssessmentContext context,
    String attemptId,
  ) async => foundRemote;

  @override
  Future<AssessmentAttempt> hydrateRemoteAttempt(
    RemoteAssessmentAttempt remote,
  ) async => hydratedAttempt!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
