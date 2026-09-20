import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/media/data/media_event_tracker.dart';
import 'package:cartilhas_app/features/media/models/media_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'gera início, checkpoints e conclusão uma única vez por sessão',
    () async {
      const queue = LearningEventQueue();
      final auth = AuthRepository(apiUrl: '');
      final sync = LearningEventSyncService(
        apiUrl: '',
        authRepository: auth,
        queue: queue,
        consentChecker: () async => true,
      );
      final tracker = MediaEventTracker(
        media: _media(),
        syncService: sync,
        queue: queue,
        sessionId: 'session-1',
      );

      await tracker.progress(positionSeconds: 95, durationSeconds: 100);
      await tracker.progress(positionSeconds: 100, durationSeconds: 100);

      final events = await queue.pending();
      expect(events.map((event) => event.type), [
        LearningEventType.videoStarted,
        LearningEventType.videoCheckpoint,
        LearningEventType.videoCheckpoint,
        LearningEventType.videoCheckpoint,
        LearningEventType.videoCompleted,
      ]);
      expect(
        events.where((event) => event.type == LearningEventType.videoCompleted),
        hasLength(1),
      );
    },
  );

  test('salvamento e atividade posterior usam payload fechado', () async {
    const queue = LearningEventQueue();
    final auth = AuthRepository(apiUrl: '');
    final sync = LearningEventSyncService(
      apiUrl: '',
      authRepository: auth,
      queue: queue,
      consentChecker: () async => true,
    );
    final tracker = MediaEventTracker(
      media: _media(),
      syncService: sync,
      queue: queue,
      sessionId: 'session-1',
    );

    await tracker.saved();
    await tracker.followupCompleted('quiz');

    final events = await queue.pending();
    expect(events.last.payload['followup_type'], 'quiz');
    expect(events.last.payload.containsKey('text'), isFalse);
  });
}

MediaItem _media() => MediaItem(
  id: 'media-1',
  institutionId: 'inst-1',
  programId: 'program-1',
  courseId: 'course-1',
  moduleId: 'module-1',
  creatorUserId: 'creator-1',
  creatorName: 'Creator TDS',
  title: 'Vídeo',
  description: '',
  competencyId: 'competency-1',
  provider: MediaProvider.youtube,
  providerAssetId: 'AbCdEf12345',
  playbackUrl: null,
  durationSeconds: 100,
  thumbnailUrl: null,
  captions: const [],
  visibility: 'enrolled',
  offlinePolicy: MediaOfflinePolicy.forbidden,
  status: 'published',
  followupActivityId: 'quiz-1',
  publishedAt: DateTime.utc(2026, 9, 20),
  sourceLabel: 'TDS',
);
