import 'package:cartilhas_app/features/learning_events/learning_activity_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tela aberta sem segunda interação não gera tempo', () {
    final tracker = LearningActivityTracker(
      courseId: 'course-1',
      sessionId: 'session-1',
    );

    final event = tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10));

    expect(event, isNull);
  });

  test('gera somente o intervalo entre interações reais', () {
    final tracker = LearningActivityTracker(
      courseId: 'course-1',
      sessionId: 'session-1',
    );
    tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10));

    final event = tracker.recordInteraction(
      now: DateTime.utc(2026, 9, 20, 10, 0, 18),
    );

    expect(event?.activeSeconds, 18);
    expect(event?.eventId, 'session-1:study_activity:1');
    expect(event?.toJson()['active_seconds'], 18);
  });

  test('ignora intervalo longo sem interação', () {
    final tracker = LearningActivityTracker(
      courseId: 'course-1',
      sessionId: 'session-1',
    );
    tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10));

    final idleEvent = tracker.recordInteraction(
      now: DateTime.utc(2026, 9, 20, 10, 10),
    );
    final resumedEvent = tracker.recordInteraction(
      now: DateTime.utc(2026, 9, 20, 10, 10, 20),
    );

    expect(idleEvent, isNull);
    expect(resumedEvent?.activeSeconds, 20);
  });

  test('reset de ciclo de vida descarta intervalo em segundo plano', () {
    final tracker = LearningActivityTracker(
      courseId: 'course-1',
      sessionId: 'session-1',
    );
    tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10));
    tracker.reset();

    final firstAfterResume = tracker.recordInteraction(
      now: DateTime.utc(2026, 9, 20, 10, 1),
    );

    expect(firstAfterResume, isNull);
  });

  test('interações subsegundo acumulam até um segundo completo', () {
    final tracker = LearningActivityTracker(
      courseId: 'course-1',
      sessionId: 'session-1',
    );
    tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10));
    expect(
      tracker.recordInteraction(now: DateTime.utc(2026, 9, 20, 10, 0, 0, 500)),
      isNull,
    );

    final event = tracker.recordInteraction(
      now: DateTime.utc(2026, 9, 20, 10, 0, 1),
    );

    expect(event?.activeSeconds, 1);
    expect(event?.eventId, 'session-1:study_activity:1');
  });
}
