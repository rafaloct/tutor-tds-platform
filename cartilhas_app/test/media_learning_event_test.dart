import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evento de vídeo usa envelope existente e ID idempotente', () {
    final first = LearningEvent.video(
      type: LearningEventType.videoCheckpoint,
      mediaId: 'media-1',
      moduleId: 'module-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      checkpoint: 50,
      positionSeconds: 61,
      occurredAt: DateTime.utc(2026, 9, 20),
    );
    final retry = LearningEvent.video(
      type: LearningEventType.videoCheckpoint,
      mediaId: 'media-1',
      moduleId: 'module-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      checkpoint: 50,
      positionSeconds: 61,
      occurredAt: DateTime.utc(2026, 9, 20, 0, 1),
    );

    expect(first.eventId, retry.eventId);
    expect(first.toJson()['event_type'], 'video_checkpoint');
    expect(first.payload, {
      'media_id': 'media-1',
      'module_id': 'module-1',
      'checkpoint': '50',
      'position_seconds': '61',
    });
    expect(first.activeSeconds, isNull);
    expect(LearningEvent.fromJson(first.toJson())?.eventId, first.eventId);
  });

  test('rejeita checkpoint e followup fora das enums fechadas', () {
    expect(
      () => LearningEvent.video(
        type: LearningEventType.videoCheckpoint,
        mediaId: 'media-1',
        moduleId: 'module-1',
        courseId: 'course-1',
        sessionId: 'session-1',
        checkpoint: 40,
        positionSeconds: 40,
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningEvent.video(
        type: LearningEventType.videoFollowupCompleted,
        mediaId: 'media-1',
        moduleId: 'module-1',
        courseId: 'course-1',
        sessionId: 'session-1',
        followupType: 'texto_livre',
      ),
      throwsArgumentError,
    );
  });

  test('conclusão exige posição estável sem declarar tempo pedagógico', () {
    final event = LearningEvent.video(
      type: LearningEventType.videoCompleted,
      mediaId: 'media-1',
      moduleId: 'module-1',
      courseId: 'course-1',
      sessionId: 'session-1',
      positionSeconds: 92,
    );
    expect(event.payload['position_seconds'], '92');
    expect(event.activeSeconds, isNull);
  });
}
