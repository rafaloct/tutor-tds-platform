import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/learning_events/learning_outbox.dart';
import 'package:cartilhas_app/features/learning_events/sqlite_learning_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Auth extends AuthRepository {
  _Auth() : super(apiUrl: 'https://staging.example');
  String owner = 'student';
  @override
  Future<String?> localUserId() async => owner;
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) action,
  ) => action('synthetic-token');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temp;
  late SqliteLearningOutbox outbox;
  late LearningEventQueue queue;
  final now = DateTime.utc(2026, 9, 23);
  SqliteLearningOutbox openStore() => SqliteLearningOutbox(
    open: () => databaseFactoryFfi.openDatabase(
      '${temp.path}/outbox.db',
      options: SqliteLearningOutbox.options,
    ),
  );
  LearningEvent event(String id, {int seconds = 20, bool owned = true}) {
    final e = LearningEvent.activity(
      courseId: 'course',
      sessionId: id,
      sequence: 1,
      activeSeconds: seconds,
      occurredAt: now,
    ).withCourseContext(classId: 'cohort', courseVersionId: 'edition');
    return owned
        ? e.forLocalOwner(userId: 'student', apiUrl: 'https://staging.example')
        : e;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tds-outbox-test-');
    outbox = openStore();
    queue = LearningEventQueue(outbox: outbox, maxPending: 1);
  });
  tearDown(() async {
    await outbox.close();
    await temp.delete(recursive: true);
  });

  test(
    'imports atomically, reopens and never reimports acknowledged evidence',
    () async {
      final source = jsonEncode([
        event('a').toStorageJson(),
        event('b').toStorageJson(),
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('learning_events:pending:v1', source);
      expect(await queue.pending(), hasLength(2));
      expect(prefs.containsKey('learning_events:pending:v1'), isFalse);
      await queue.removeById(event('a').eventId);
      await outbox.close();
      outbox = openStore();
      queue = LearningEventQueue(outbox: outbox);
      // Simulate interruption after commit but before removing old preferences.
      await prefs.setString('learning_events:pending:v1', source);
      expect((await queue.pending()).single.eventId, event('b').eventId);
      expect(await queue.enqueue(event('a')), isFalse);
      await expectLater(
        queue.enqueue(event('a', seconds: 30)),
        throwsA(isA<OutboxConflict>()),
      );
    },
  );

  test(
    'invalid legacy record rolls back all inserts and preserves original source',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final source = jsonEncode([
        event('valid').toStorageJson(),
        {'broken': true},
      ]);
      await prefs.setString('learning_events:pending:v1', source);
      await expectLater(queue.pending(), throwsFormatException);
      expect(prefs.getString('learning_events:pending:v1'), source);
      expect(await (await outbox.database).query('learning_outbox'), isEmpty);
      expect(await (await outbox.database).query('outbox_imports'), isEmpty);
    },
  );

  test(
    'concurrent writers deduplicate and logout retains owned evidence',
    () async {
      final accepted = await Future.wait(
        List.generate(10, (_) => queue.enqueue(event('same'))),
      );
      expect(accepted.where((value) => value), hasLength(1));
      await queue.enqueue(event('second'));
      await queue.enqueue(event('legacy', owned: false));
      await queue.clear(preserveOwned: true);
      await outbox.close();
      outbox = openStore();
      expect(await outbox.pending(), hasLength(2));
    },
  );

  test(
    'backoff and conflict state persist across reopen without altering event IDs',
    () async {
      await queue.enqueue(event('retry'));
      await queue.enqueue(event('conflict'));
      await outbox.fail(event('retry').eventId, now: now, statusCode: 503);
      await outbox.fail(event('conflict').eventId, now: now, statusCode: 409);
      await outbox.close();
      outbox = openStore();
      expect(await outbox.pending(readyAt: now), isEmpty);
      expect(
        (await outbox.pending(
          readyAt: now.add(const Duration(seconds: 5)),
        )).single.eventId,
        event('retry').eventId,
      );
      expect(await outbox.pending(), hasLength(2));
      await outbox.retryBlocked(
        event('conflict').eventId,
        scope: LearningDeliveryScope(
          ownerId: 'student',
          apiUrl: 'https://staging.example',
          cohortId: 'cohort',
          courseVersionId: 'edition',
          courseId: 'course',
        ),
      );
      expect(
        (await outbox.pending(readyAt: now)).single.eventId,
        event('conflict').eventId,
      );
    },
  );

  test(
    'one rejected event does not block valid delivery; retries honor owner and delay',
    () async {
      await queue.enqueue(event('conflict'));
      await queue.enqueue(event('retry'));
      await queue.enqueue(event('valid'));
      await queue.enqueue(event('unknown-owner', owned: false));
      final auth = _Auth();
      var instant = now;
      var retryFails = true;
      final sent = <String>[];
      final service = LearningEventSyncService(
        apiUrl: auth.apiUrl,
        authRepository: auth,
        queue: queue,
        clock: () => instant,
        consentChecker: () async => true,
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map;
          expect(payload.containsKey('local_owner_id'), isFalse);
          final id = payload['event_id'] as String;
          sent.add(id);
          return http.Response(
            '{}',
            id.startsWith('conflict:')
                ? 409
                : id.startsWith('retry:') && retryFails
                ? 503
                : 200,
          );
        }),
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      expect(await service.flush(), 1);
      expect(sent, hasLength(3));
      expect(await service.flush(), 0);
      expect(sent, hasLength(3));
      instant = now.add(const Duration(seconds: 5));
      retryFails = false;
      auth.owner = 'other';
      expect(await service.flush(), 0);
      auth.owner = 'student';
      expect(await service.flush(), 1);
      expect(sent.last, event('retry').eventId);
      expect((await queue.pending()).map((e) => e.eventId), [
        event('conflict').eventId,
        event('unknown-owner', owned: false).eventId,
      ]);
    },
  );
}
