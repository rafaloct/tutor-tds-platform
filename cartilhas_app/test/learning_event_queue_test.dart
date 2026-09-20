import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  LearningEvent event(String session, LearningEventType type) =>
      LearningEvent.forSession(
        type: type,
        courseId: 'agricultura-sustentavel',
        sessionId: session,
        occurredAt: DateTime.utc(2026, 9, 20, 10),
      );

  test('deduplica retries pelo event_id', () async {
    const queue = LearningEventQueue();
    final started = event('sessao-1', LearningEventType.lessonStarted);

    expect(await queue.enqueue(started), isTrue);
    expect(await queue.enqueue(started), isFalse);

    final pending = await queue.pending();
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'sessao-1:lesson_started');
    expect(pending.single.toJson(), isNot(contains('cpf')));
    expect(pending.single.toJson(), isNot(contains('name')));
  });

  test('limita crescimento preservando os eventos mais recentes', () async {
    const queue = LearningEventQueue(maxPending: 2);
    await queue.enqueue(event('sessao-1', LearningEventType.lessonStarted));
    await queue.enqueue(event('sessao-2', LearningEventType.lessonStarted));
    await queue.enqueue(event('sessao-3', LearningEventType.lessonCompleted));

    final pending = await queue.pending();
    expect(pending.map((item) => item.sessionId), ['sessao-2', 'sessao-3']);
  });

  test('ignora armazenamento corrompido e volta a enfileirar', () async {
    SharedPreferences.setMockInitialValues({
      'learning_events:pending:v1': '{invalido}',
    });
    const queue = LearningEventQueue();

    expect(
      await queue.enqueue(event('sessao-4', LearningEventType.lessonStarted)),
      isTrue,
    );
    expect(await queue.pending(), hasLength(1));
  });

  test('remove somente o event_id confirmado', () async {
    const queue = LearningEventQueue();
    final first = event('sessao-5', LearningEventType.lessonStarted);
    final second = event('sessao-5', LearningEventType.lessonCompleted);
    await queue.enqueue(first);
    await queue.enqueue(second);

    expect(await queue.removeById(first.eventId), isTrue);
    expect(await queue.removeById('inexistente'), isFalse);

    final pending = await queue.pending();
    expect(pending.map((item) => item.eventId), [second.eventId]);
  });

  test('preserva atividade e segundos ativos no armazenamento local', () async {
    const queue = LearningEventQueue();
    final activity = LearningEvent.activity(
      courseId: 'agricultura-sustentavel',
      sessionId: 'sessao-6',
      sequence: 1,
      activeSeconds: 27,
      occurredAt: DateTime.utc(2026, 9, 20, 10, 1),
    );

    await queue.enqueue(activity);

    final restored = (await queue.pending()).single;
    expect(restored.type, LearningEventType.studyActivity);
    expect(restored.activeSeconds, 27);
    expect(restored.toJson()['active_seconds'], 27);
  });
}
