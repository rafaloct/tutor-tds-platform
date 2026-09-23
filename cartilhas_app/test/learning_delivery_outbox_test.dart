import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_outbox.dart';
import 'package:cartilhas_app/features/learning_events/sqlite_learning_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _OpenUnavailable extends DatabaseException {
  _OpenUnavailable() : super('open_failed');
  @override
  int? getResultCode() => 14;
  @override
  Object? get result => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime.utc(2026, 9, 23);
  late Directory temp;
  late SqliteLearningOutbox outbox;
  late LearningEventQueue queue;

  LearningDeliveryScope scope({
    String owner = 'student',
    String api = 'https://staging.example',
    String cohort = 'cohort',
    String edition = 'edition',
    String course = 'course',
  }) => LearningDeliveryScope(
    ownerId: owner,
    apiUrl: api,
    cohortId: cohort,
    courseVersionId: edition,
    courseId: course,
  );

  LearningEvent event(
    String id, {
    String owner = 'student',
    String api = 'https://staging.example',
    String cohort = 'cohort',
    String edition = 'edition',
    String course = 'course',
    int seconds = 20,
  }) =>
      LearningEvent.activity(
            courseId: course,
            sessionId: id,
            sequence: 1,
            activeSeconds: seconds,
            occurredAt: now,
          )
          .withCourseContext(classId: cohort, courseVersionId: edition)
          .forLocalOwner(userId: owner, apiUrl: api);

  Future<Database> open() => databaseFactoryFfi.openDatabase(
    '${temp.path}/outbox.db',
    options: SqliteLearningOutbox.options,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tds-delivery-status-');
    outbox = SqliteLearningOutbox(open: open);
    queue = LearningEventQueue(outbox: outbox);
  });
  tearDown(() async {
    await outbox.close();
    await temp.delete(recursive: true);
  });

  test(
    'projection counts only pedagogical evidence in the exact context',
    () async {
      for (final item in [
        event('pending'),
        event('retry'),
        event('blocked'),
        event('synced'),
        event('other-owner', owner: 'other'),
        event('other-api', api: 'https://production.example'),
        event('other-cohort', cohort: 'another'),
        event('other-edition', edition: 'another'),
        event('other-course', course: 'another'),
        LearningEvent.activity(
          courseId: 'course',
          sessionId: 'unowned',
          sequence: 1,
          activeSeconds: 10,
          occurredAt: now,
        ).withCourseContext(classId: 'cohort', courseVersionId: 'edition'),
        LearningEvent.telemetry(
          type: LearningEventType.pageViewed,
          targetId: 'home',
          courseId: 'course',
          sessionId: 'analytics',
          sequence: 1,
          occurredAt: now,
        ).forLocalOwner(userId: 'student', apiUrl: 'https://staging.example'),
      ]) {
        await queue.enqueue(item);
      }
      await queue.recordFailure(
        event('retry').eventId,
        now: now,
        statusCode: 503,
      );
      await queue.recordFailure(
        event('blocked').eventId,
        now: now,
        statusCode: 409,
      );
      await queue.removeById(event('synced').eventId);
      final status = await queue.deliveryStatus(
        scope(api: 'https://staging.example/'),
      );
      expect(status.pendingCount, 1);
      expect(status.retryCount, 1);
      expect(status.blockedCount, 1);
      expect(status.nextAttemptAt, now.add(const Duration(seconds: 5)));
      expect(status.blockedEvents.single.eventId, event('blocked').eventId);
      expect(status.blockedEvents.single.lastStatus, 409);
      expect(status.requiresAccessRefresh, isFalse);
      expect(status.isEmpty, isFalse);
      expect(scope(), scope(api: 'https://staging.example/'));
    },
  );

  test(
    'auth attention derives only from retry status in the selected context',
    () async {
      await queue.enqueue(event('own'));
      await queue.enqueue(event('other', cohort: 'other'));
      await queue.recordFailure(
        event('other', cohort: 'other').eventId,
        now: now,
        statusCode: 401,
      );
      expect(
        (await queue.deliveryStatus(scope())).requiresAccessRefresh,
        isFalse,
      );
      await queue.recordFailure(
        event('own').eventId,
        now: now,
        statusCode: 403,
      );
      final status = await queue.deliveryStatus(scope());
      expect(status.requiresAccessRefresh, isTrue);
      expect(status.nextAttemptAt, now.add(const Duration(minutes: 5)));
    },
  );

  test(
    'blocked retry checks all scope fields atomically and preserves evidence',
    () async {
      final item = event('blocked');
      await queue.enqueue(item);
      await queue.recordFailure(item.eventId, now: now, statusCode: 422);
      final database = await outbox.database;
      final before = (await database.query('learning_outbox')).single;
      for (final wrong in [
        scope(owner: 'other'),
        scope(api: 'https://production.example'),
        scope(cohort: 'other'),
        scope(edition: 'other'),
        scope(course: 'other'),
      ]) {
        expect(await queue.retryBlocked(item.eventId, scope: wrong), isFalse);
      }
      expect((await queue.deliveryStatus(scope())).blockedCount, 1);
      final results = await Future.wait(
        List.generate(
          3,
          (_) => queue.retryBlocked(item.eventId, scope: scope()),
        ),
      );
      expect(results.where((changed) => changed), hasLength(1));
      final after = (await database.query('learning_outbox')).single;
      for (final column in [
        'event_id',
        'body',
        'owner_id',
        'api_url',
        'occurred_at',
        'created_at',
        'attempts',
        'last_status',
      ]) {
        expect(after[column], before[column]);
      }
      expect(after['state'], 'pending');
      expect(after['next_attempt_at'], 0);
      await outbox.close();
      outbox = SqliteLearningOutbox(open: open);
      queue = LearningEventQueue(outbox: outbox);
      expect((await queue.deliveryStatus(scope())).pendingCount, 1);
      await queue.removeById(item.eventId);
      expect(await queue.retryBlocked(item.eventId, scope: scope()), isFalse);
    },
  );

  test(
    'corruption outside owner/API is excluded before decode; owned corruption fails closed',
    () async {
      await queue.enqueue(event('own'));
      await queue.enqueue(event('foreign', owner: 'other'));
      final database = await outbox.database;
      await database.update(
        'learning_outbox',
        {'body': '{invalid'},
        where: 'event_id = ?',
        whereArgs: [event('foreign', owner: 'other').eventId],
      );
      expect((await queue.deliveryStatus(scope())).pendingCount, 1);
      await database.update(
        'learning_outbox',
        {'body': '{invalid'},
        where: 'event_id = ?',
        whereArgs: [event('own').eventId],
      );
      await expectLater(
        queue.deliveryStatus(scope()),
        throwsA(isA<OutboxDataException>()),
      );
      expect(await database.query('learning_outbox'), hasLength(2));
    },
  );

  test(
    'invalid occurred_at in legacy data rolls back with typed FormatException',
    () async {
      final malformed = {...event('broken').toStorageJson(), 'occurred_at': 42};
      final source = jsonEncode([event('valid').toStorageJson(), malformed]);
      SharedPreferences.setMockInitialValues({
        'learning_events:pending:v1': source,
      });
      await expectLater(
        queue.deliveryStatus(scope()),
        throwsA(isA<OutboxDataException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'learning_events:pending:v1',
        ),
        source,
      );
      expect(await (await outbox.database).query('learning_outbox'), isEmpty);
      expect(await (await outbox.database).query('outbox_imports'), isEmpty);
      expect(const OutboxDataException('legacy'), isA<FormatException>());
    },
  );

  test(
    'known open failure can retry without a permanently failed cached Future',
    () async {
      var attempts = 0;
      outbox = SqliteLearningOutbox(
        open: () async {
          attempts++;
          if (attempts == 1) throw _OpenUnavailable();
          return open();
        },
      );
      queue = LearningEventQueue(outbox: outbox);
      await expectLater(
        queue.enqueue(event('held')),
        throwsA(isA<OutboxStorageException>()),
      );
      expect(await queue.enqueue(event('held')), isTrue);
      expect(attempts, 2);
      expect((await queue.deliveryStatus(scope())).pendingCount, 1);
    },
  );

  test(
    'conflict remains explicit and status reads never notify recursively',
    () async {
      var changes = 0;
      void listener() => changes++;
      queue.changes.addListener(listener);
      addTearDown(() => queue.changes.removeListener(listener));
      await queue.deliveryStatus(scope());
      expect(changes, 0);
      await queue.enqueue(event('immutable'));
      final afterWrite = changes;
      expect(afterWrite, greaterThan(0));
      await queue.deliveryStatus(scope());
      await queue.deliveryStatus(scope());
      expect(changes, afterWrite);
      await expectLater(
        queue.enqueue(event('immutable', seconds: 21)),
        throwsA(isA<OutboxConflict>()),
      );
      expect((await queue.pending()).single.activeSeconds, 20);
      expect((await queue.deliveryStatus(scope())).pendingCount, 1);
    },
  );

  test(
    'synchronous known open failure reaches the same typed recoverable boundary',
    () async {
      var attempts = 0;
      outbox = SqliteLearningOutbox(
        open: () {
          attempts++;
          if (attempts == 1) throw _OpenUnavailable();
          return open();
        },
      );
      queue = LearningEventQueue(outbox: outbox);
      await expectLater(
        queue.enqueue(event('held-sync')),
        throwsA(isA<OutboxStorageException>()),
      );
      expect(await queue.enqueue(event('held-sync')), isTrue);
      expect(attempts, 2);
    },
  );
}
