import 'dart:async';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_delivery_controller.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/learning_events/learning_outbox.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final deliveryScope = LearningDeliveryScope(
  ownerId: 'student',
  apiUrl: 'https://staging.example/',
  cohortId: 'cohort',
  courseVersionId: 'edition',
  courseId: 'course',
);

LearningEvent deliveryEvent([String session = 'study']) =>
    LearningEvent.activity(
          courseId: 'course',
          sessionId: session,
          sequence: 1,
          activeSeconds: 3,
          occurredAt: DateTime.utc(2026, 9, 23),
        )
        .withCourseContext(classId: 'cohort', courseVersionId: 'edition')
        .forLocalOwner(userId: 'student', apiUrl: 'https://staging.example');

class DeliveryFakeAuth extends AuthRepository {
  DeliveryFakeAuth() : super(apiUrl: 'https://staging.example');
  String owner = 'student';
  @override
  Future<String?> localUserId() async => owner;
}

class DeliverySignal extends ChangeNotifier {
  void emit() => notifyListeners();
}

class DeliveryFakeQueue extends LearningEventQueue {
  final changed = DeliverySignal();
  @override
  Listenable get changes => changed;
  LearningDeliverySnapshot status = const LearningDeliverySnapshot();
  Object? enqueueFailure;
  Object? readFailure;
  Completer<void>? writeBarrier;
  Completer<LearningDeliverySnapshot>? readBarrier;
  final writes = <LearningEvent>[];
  final retries = <(String, LearningDeliveryScope)>[];
  final saved = <String>{};
  @override
  Future<bool> enqueue(LearningEvent event) async {
    writes.add(event);
    if (enqueueFailure != null) throw enqueueFailure!;
    await writeBarrier?.future;
    final added = saved.add(event.eventId);
    status = LearningDeliverySnapshot(pendingCount: saved.length);
    changed.emit();
    return added;
  }

  @override
  Future<LearningDeliverySnapshot> deliveryStatus(
    LearningDeliveryScope scope,
  ) async {
    expectSync(scope, deliveryScope);
    if (readFailure != null) throw readFailure!;
    return readBarrier?.future ?? Future.value(status);
  }

  @override
  Future<bool> retryBlocked(
    String eventId, {
    required LearningDeliveryScope scope,
  }) async {
    retries.add((eventId, scope));
    status = const LearningDeliverySnapshot(pendingCount: 1);
    changed.emit();
    return true;
  }
}

class DeliveryFakeSync implements LearningEventSyncService {
  int calls = 0;
  Completer<int>? barrier;
  Future<int> Function()? effect;
  @override
  Future<int> flush() async {
    calls++;
    return barrier?.future ?? effect?.call() ?? Future.value(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DeliveryFixture {
  final queue = DeliveryFakeQueue();
  final auth = DeliveryFakeAuth();
  final sync = DeliveryFakeSync();
  bool consent = true;
  bool access = true;
  int progressReads = 0;
  late final controller = LearningDeliveryController(
    scope: deliveryScope,
    queue: queue,
    auth: auth,
    sync: sync,
    consentChecker: () async => consent,
    revalidateAccess: () async => access,
    onDelivered: () async {
      progressReads++;
    },
  );
  void dispose() {
    controller.dispose();
    queue.changed.dispose();
    auth.dispose();
  }
}

void main() {
  test(
    'local commit serializes actions but an offline HTTP wait does not',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.writeBarrier = Completer<void>();
      f.sync.barrier = Completer<int>();
      final writing = f.controller.record(deliveryEvent());
      expect(f.controller.canRecord, isFalse);
      expect(await f.controller.record(deliveryEvent('second')), isFalse);
      f.queue.writeBarrier!.complete();
      expect(await writing, isTrue);
      expect(f.controller.canRecord, isTrue);
      expect(f.queue.writes, hasLength(1));
      expect(f.controller.lastStoredEventId, deliveryEvent().eventId);
      expect(f.progressReads, 0);
      f.sync.barrier!.complete(0);
      await Future<void>.delayed(Duration.zero);
    },
  );

  for (final failure in <Object>[
    const OutboxStorageException('enqueue'),
    const OutboxDataException('legacy'),
    const OutboxMigrationException(committed: true),
    const OutboxConflict('study:study_activity:1'),
  ]) {
    test(
      'failed write retains exact event on retry: ${failure.runtimeType}',
      () async {
        final f = DeliveryFixture();
        addTearDown(f.dispose);
        final event = deliveryEvent();
        f.queue.enqueueFailure = failure;
        expect(await f.controller.record(event), isFalse);
        expect(f.controller.hasUnsavedEvent, isTrue);
        expect(f.controller.canRecord, isFalse);
        expect(f.controller.lastStoredEventId, isNull);
        await f.controller.refresh();
        expect(f.controller.hasUnsavedEvent, isTrue);
        expect(f.controller.issue, isNotNull);
        expect(f.progressReads, 0);
        f.queue.enqueueFailure = null;
        expect(await f.controller.retrySave(), isTrue);
        expect(f.queue.writes, hasLength(2));
        expect(identical(f.queue.writes.first, f.queue.writes.last), isTrue);
        expect(f.queue.writes.last.toStorageJson(), event.toStorageJson());
        expect(f.queue.saved, {event.eventId});
        expect(f.controller.hasUnsavedEvent, isFalse);
        expect(f.controller.canRecord, isTrue);
        await Future<void>.delayed(Duration.zero);
      },
    );
  }

  test(
    'failed projection is unknown, never a successful empty queue',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.readFailure = const OutboxDataException('persisted');
      await f.controller.refresh();
      expect(f.controller.snapshot, isNull);
      expect(f.controller.issue, LearningDeliveryIssue.data);
      expect(f.controller.canRecord, isFalse);
      f.queue.readFailure = null;
      await f.controller.refresh();
      expect(f.controller.snapshot!.isEmpty, isTrue);
      expect(f.controller.issue, isNull);
    },
  );

  test(
    'late projection after account change exposes no previous owner count',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.readBarrier = Completer<LearningDeliverySnapshot>();
      final pending = f.controller.refresh();
      await Future<void>.delayed(Duration.zero);
      f.auth.owner = 'other';
      f.queue.readBarrier!.complete(
        const LearningDeliverySnapshot(pendingCount: 7),
      );
      await pending;
      expect(f.controller.snapshot, isNull);
      expect(f.controller.issue, LearningDeliveryIssue.access);
      expect(await f.controller.record(deliveryEvent()), isFalse);
      expect(f.queue.writes, isEmpty);
    },
  );

  test('blocked retry requires access and preserves exact scoped ID', () async {
    final f = DeliveryFixture();
    addTearDown(f.dispose);
    f.queue.status = const LearningDeliverySnapshot(
      blockedCount: 1,
      blockedEvents: [
        BlockedLearningEvent(eventId: 'same-id', lastStatus: 409),
      ],
    );
    await f.controller.refresh();
    f.access = false;
    await f.controller.synchronize(retryBlocked: true);
    expect(f.queue.retries, isEmpty);
    expect(f.sync.calls, 0);
    f.access = true;
    await f.controller.synchronize(retryBlocked: true);
    expect(f.queue.retries, [('same-id', deliveryScope)]);
    expect(f.sync.calls, 1);
    expect(f.progressReads, 0);
  });

  test(
    'consent pauses sending and access-required projection grants nothing',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.status = const LearningDeliverySnapshot(
        retryCount: 1,
        requiresAccessRefresh: true,
      );
      f.consent = false;
      await f.controller.refresh();
      await f.controller.synchronize();
      expect(f.sync.calls, 0);
      f.consent = true;
      f.access = false;
      await f.controller.synchronize();
      expect(f.sync.calls, 0);
      expect(f.progressReads, 0);
    },
  );

  test(
    'external lifecycle acknowledge refreshes count without projecting progress',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.status = const LearningDeliverySnapshot(pendingCount: 2);
      await f.controller.refresh();
      f.queue.status = const LearningDeliverySnapshot();
      f.queue.changed.emit();
      await f.controller.refresh();
      expect(f.controller.snapshot!.isEmpty, isTrue);
      expect(f.progressReads, 0);
    },
  );

  test(
    'delivery storage failure after commit never labels the event unsaved',
    () async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.sync.effect = () async {
        throw const OutboxStorageException('acknowledge');
      };
      final event = deliveryEvent();
      expect(await f.controller.record(event), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(f.controller.hasUnsavedEvent, isFalse);
      expect(f.controller.lastStoredEventId, event.eventId);
      expect(f.queue.saved, {event.eventId});
      expect(f.controller.issue, LearningDeliveryIssue.storage);
      expect(f.progressReads, 0);
    },
  );
}
