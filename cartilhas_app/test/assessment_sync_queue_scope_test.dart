import 'package:cartilhas_app/features/study_ai/data/assessment_sync_queue.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('write=false não confirma fila durável', () async {
    final storage = _MemoryStorage()..acceptWrites = false;
    final queue = AssessmentSyncQueue(storage: storage);

    await expectLater(
      queue.enqueue(_publishedAttempt()),
      throwsA(isA<StateError>()),
    );
    expect(await queue.read(_publishedAttempt().id), isNull);
  });

  test('reinício preserva revisão, ID e escopo para replay offline', () async {
    final storage = _MemoryStorage();
    final firstProcess = AssessmentSyncQueue(storage: storage);
    final attempt = _publishedAttempt();
    final queued = await firstProcess.enqueue(attempt);

    expect(queued.pending.single.payload.revision, 1);
    expect(queued.localContext?.ownerId, 'student-1');

    final restarted = AssessmentSyncQueue(storage: storage);
    final recovered = await restarted.read(attempt.id);

    expect(recovered?.attemptId, attempt.id);
    expect(recovered?.pending.single.payload.revision, 1);
    expect(recovered?.pending.single.wasAttempted, isFalse);
    expect(recovered?.localContext?.apiUrl, 'https://api.example');
    expect(
      recovered?.pending.single.payload.publishedLineage?.blockVersionId,
      'block-version-1',
    );
  });

  test('logout remove somente fila legada e preserva a contextual', () async {
    final storage = _MemoryStorage();
    final queue = AssessmentSyncQueue(storage: storage);
    final published = _publishedAttempt();
    final practice = _practiceAttempt();
    await queue.enqueue(published);
    await queue.enqueue(practice);

    await queue.clear(preserveOwned: true);

    expect(await queue.read(published.id), isNotNull);
    expect(await queue.read(practice.id), isNull);
  });

  test(
    'correção de relógio preserva revisão e todo o estado acadêmico',
    () async {
      final storage = _MemoryStorage();
      final queue = AssessmentSyncQueue(storage: storage);
      final attempt = _publishedAttempt();
      final queued = await queue.enqueue(attempt);
      final attempted = await queue.markAttempted(
        attempt.id,
        queued.pending.single.payload.revision,
      );
      final before = attempted.pending.single.payload.toJson();
      final serverTime = DateTime.utc(2026, 10, 7, 10, 30);

      final corrected = await queue.correctFutureUpdatedAt(
        attempt.id,
        attempted.pending.single.payload.revision,
        serverTime,
      );

      final after = corrected.pending.single.payload.toJson();
      final beforeTimestamp = before.remove('updated_at');
      final afterTimestamp = after.remove('updated_at');
      expect(after, before);
      expect(afterTimestamp, serverTime.toIso8601String());
      expect(afterTimestamp, isNot(beforeTimestamp));
      expect(corrected.pending.single.wasAttempted, isFalse);
      expect(corrected.localContext?.sameAs(attempt.publishedContext), isTrue);
    },
  );

  test('nova revisão nunca recua em relação ao horário confirmado', () async {
    final storage = _MemoryStorage();
    final queue = AssessmentSyncQueue(storage: storage);
    final acceptedTime = DateTime.utc(2026, 10, 7, 10, 34);
    final first = _publishedAttempt().copyWith(updatedAt: acceptedTime);
    final queued = await queue.enqueue(first);
    await queue.markAttempted(first.id, queued.pending.single.payload.revision);
    await queue.markSuccess(
      first.id,
      RemoteAssessmentAttempt(
        attemptId: first.id,
        payload: queued.pending.single.payload,
      ),
    );

    final second = await queue.enqueue(
      first.copyWith(
        reviewQuestionIndexes: const {0},
        updatedAt: DateTime.utc(2026, 10, 7, 10, 30),
      ),
    );

    expect(second.pending.single.payload.revision, 2);
    expect(second.pending.single.payload.updatedAt, acceptedTime);
    expect(second.pending.single.payload.marked, {0});
  });
}

class _MemoryStorage implements AssessmentSyncQueueStorage {
  String? value;
  bool acceptWrites = true;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> remove() async {
    value = null;
    return true;
  }

  @override
  Future<bool> write(String value) async {
    if (!acceptWrites) return false;
    this.value = value;
    return true;
  }
}

PublishedAssessmentContext _context() => PublishedAssessmentContext(
  ownerId: 'student-1',
  apiUrl: 'https://api.example/',
  lineage: const PublishedAssessmentLineage(
    organizationId: 'org-1',
    programId: 'program-1',
    classId: 'class-1',
    membershipId: 'membership-1',
    enrollmentId: 'context-enrollment-1',
    legacyEnrollmentId: 'legacy-enrollment-1',
    courseId: 'course-1',
    courseVersionId: 'version-1',
    sectionId: 'section-1',
    sectionVersionId: 'section-version-1',
    blockId: 'block-1',
    blockVersionId: 'block-version-1',
  ),
);

AssessmentAttempt _publishedAttempt() => _attempt(
  id: 'attempt:published:stable',
  origin: AssessmentOrigin.publishedBlock,
  context: _context(),
);

AssessmentAttempt _practiceAttempt() => _attempt(id: 'attempt-practice');

AssessmentAttempt _attempt({
  required String id,
  AssessmentOrigin origin = AssessmentOrigin.practice,
  PublishedAssessmentContext? context,
}) => AssessmentAttempt(
  id: id,
  origin: origin,
  publishedContext: context,
  courseId: 'course-1',
  topic: 'Módulo',
  mode: AssessmentMode.quiz,
  difficulty: StudyDifficulty.intermediate,
  totalQuestions: 1,
  deck: AssessmentDeck(
    title: 'Bloco',
    durationMinutes: 0,
    items: [
      StudyQuestion(
        question: 'Pergunta?',
        options: const ['A', 'B'],
        correctIndex: origin == AssessmentOrigin.practice ? 0 : -1,
        correctIndexes: origin == AssessmentOrigin.practice
            ? const {0}
            : const {},
        graded: origin == AssessmentOrigin.practice,
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
  isCompleted: false,
  createdAt: DateTime.utc(2026, 10, 7),
  updatedAt: DateTime.utc(2026, 10, 7),
);
