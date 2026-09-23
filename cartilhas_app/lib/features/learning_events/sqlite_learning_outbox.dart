import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'learning_event.dart';
import 'learning_outbox.dart';

class SqliteLearningOutbox implements LearningOutbox {
  SqliteLearningOutbox({required this.open});

  final Future<Database> Function() open;
  Future<Database>? _database;
  Future<Database> get database async {
    final pending = _database ??= Future<Database>.sync(open);
    try {
      return await _guard('open', () => pending);
    } on OutboxStorageException {
      if (identical(_database, pending)) _database = null;
      rethrow;
    } on OutboxDataException {
      if (identical(_database, pending)) _database = null;
      rethrow;
    }
  }

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (error) {
      final code = error.getResultCode();
      final primary = code == null ? null : code & 0xff;
      if ({11, 26}.contains(primary) || error.isNoSuchTableError()) {
        throw const OutboxDataException('database');
      }
      if ({5, 6, 8, 10, 13, 14}.contains(primary) ||
          error.isOpenFailedError() ||
          error.isDatabaseClosedError() ||
          error.isReadOnlyError()) {
        throw OutboxStorageException(operation, sqliteCode: code);
      }
      // SQL syntax/constraint/programming errors remain visible, not retriable I/O.
      rethrow;
    } on PlatformException {
      throw OutboxStorageException(operation);
    } on MissingPluginException {
      throw OutboxStorageException(operation);
    }
  }

  LearningEvent _decodePersisted(Map<String, Object?> row) {
    final body = row['body'];
    if (body is! String) throw const OutboxDataException('persisted');
    final LearningEvent? event;
    try {
      event = LearningEvent.fromJson(jsonDecode(body));
    } on FormatException {
      throw const OutboxDataException('persisted');
    }
    if (event == null ||
        event.eventId != row['event_id'] ||
        event.localOwnerId != row['owner_id'] ||
        event.localApiUrl != row['api_url']) {
      throw const OutboxDataException('persisted');
    }
    return event;
  }

  static final instance = SqliteLearningOutbox(
    open: () async => databaseFactory.openDatabase(
      '${await getDatabasesPath()}/tds_learning_outbox.db',
      options: options,
    ),
  );

  /// Account deletion also removes a database left by a previous enabled build.
  static Future<void> eraseIfPresent() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    final path = '${await getDatabasesPath()}/tds_learning_outbox.db';
    await instance.close();
    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }
  }

  static OpenDatabaseOptions get options => OpenDatabaseOptions(
    version: 1,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
      await db.execute('PRAGMA synchronous = FULL');
    },
    onCreate: (db, version) async {
      await db.execute('''CREATE TABLE learning_outbox (
        event_id TEXT PRIMARY KEY NOT NULL,
        body TEXT NOT NULL,
        owner_id TEXT,
        api_url TEXT,
        occurred_at TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending'
          CHECK(state IN ('pending','retry','blocked','synced')),
        attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts >= 0),
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_status INTEGER,
        CHECK ((owner_id IS NULL AND api_url IS NULL) OR
               (owner_id IS NOT NULL AND api_url IS NOT NULL))
      )''');
      await db.execute(
        'CREATE INDEX outbox_due ON learning_outbox(state, next_attempt_at, created_at)',
      );
      await db.execute(
        'CREATE INDEX outbox_owner ON learning_outbox(owner_id, api_url)',
      );
      await db.execute(
        'CREATE TABLE outbox_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at INTEGER NOT NULL)',
      );
    },
  );

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  Future<bool> _insert(DatabaseExecutor db, LearningEvent event) async {
    final body = jsonEncode(_canonical(event.toStorageJson()));
    final prior = await db.query(
      'learning_outbox',
      columns: ['body'],
      where: 'event_id = ?',
      whereArgs: [event.eventId],
    );
    if (prior.isNotEmpty) {
      if (prior.single['body'] != body) throw OutboxConflict(event.eventId);
      return false;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert('learning_outbox', {
      'event_id': event.eventId,
      'body': body,
      'owner_id': event.localOwnerId,
      'api_url': event.localApiUrl,
      'occurred_at': event.occurredAt.toUtc().toIso8601String(),
      'created_at': now,
      'updated_at': now,
    });
    return true;
  }

  @override
  Future<void> importLegacy(String source) => _guard('import', () async {
    final digest = sha256.convert(utf8.encode(source)).toString();
    final db = await database;
    await db.transaction((tx) async {
      if ((await tx.query(
        'outbox_imports',
        where: 'digest = ?',
        whereArgs: [digest],
      )).isNotEmpty) {
        return;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(source);
      } on FormatException {
        throw const OutboxDataException('legacy');
      }
      if (decoded is! List) {
        throw const OutboxDataException('legacy');
      }
      for (final row in decoded) {
        final event = LearningEvent.fromJson(row);
        if (event == null) {
          throw const OutboxDataException('legacy');
        }
        await _insert(tx, event);
      }
      await tx.insert('outbox_imports', {
        'digest': digest,
        'imported_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    });
  });

  @override
  Future<bool> enqueue(LearningEvent event) => _guard(
    'write',
    () async => (await database).transaction((tx) => _insert(tx, event)),
  );

  @override
  Future<List<LearningEvent>> pending({DateTime? readyAt}) =>
      _guard('read', () async {
        final rows = await (await database).query(
          'learning_outbox',
          columns: ['event_id', 'body', 'owner_id', 'api_url'],
          where: readyAt == null
              ? "state != 'synced'"
              : "state IN ('pending','retry') AND next_attempt_at <= ?",
          whereArgs: readyAt == null
              ? null
              : [readyAt.toUtc().millisecondsSinceEpoch],
          orderBy: 'created_at, rowid',
        );
        return rows.map(_decodePersisted).toList(growable: false);
      });

  @override
  Future<LearningDeliverySnapshot> deliveryStatus(
    LearningDeliveryScope scope,
  ) => _guard('read_status', () async {
    // Exclude foreign owners/environments before decoding any body.
    final rows = await (await database).query(
      'learning_outbox',
      where: "owner_id = ? AND api_url = ? AND state != 'synced'",
      whereArgs: [scope.ownerId, scope.apiUrl],
      orderBy: 'created_at, rowid',
    );
    var pending = 0;
    var retry = 0;
    var accessRefresh = false;
    DateTime? nextAttempt;
    final blocked = <BlockedLearningEvent>[];
    for (final row in rows) {
      final event = _decodePersisted(row);
      if (!scope.matches(event)) continue;
      final state = row['state'];
      final next = row['next_attempt_at'];
      final status = row['last_status'];
      if (next is! int ||
          next < 0 ||
          next > 8640000000000000 ||
          (status != null && status is! int)) {
        throw const OutboxDataException('persisted');
      }
      final retryAt = next == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(next, isUtc: true);
      switch (state) {
        case 'pending':
          pending++;
          break;
        case 'retry':
          retry++;
          accessRefresh = accessRefresh || status == 401 || status == 403;
          if (retryAt != null &&
              (nextAttempt == null || retryAt.isBefore(nextAttempt))) {
            nextAttempt = retryAt;
          }
          break;
        case 'blocked':
          blocked.add(
            BlockedLearningEvent(
              eventId: event.eventId,
              lastStatus: status as int?,
              nextAttemptAt: retryAt,
            ),
          );
          break;
        default:
          throw const OutboxDataException('persisted');
      }
    }
    return LearningDeliverySnapshot(
      pendingCount: pending,
      retryCount: retry,
      blockedCount: blocked.length,
      nextAttemptAt: nextAttempt,
      blockedEvents: List.unmodifiable(blocked),
      requiresAccessRefresh: accessRefresh,
    );
  });

  @override
  Future<bool> acknowledge(String eventId) => _guard(
    'acknowledge',
    () async =>
        (await (await database).update(
          'learning_outbox',
          {
            'state': 'synced',
            'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
            'last_status': null,
          },
          where: "event_id = ? AND state != 'synced'",
          whereArgs: [eventId],
        )) >
        0,
  );

  @override
  Future<void> fail(String eventId, {required DateTime now, int? statusCode}) =>
      _guard('record_failure', () async {
        await (await database).transaction((tx) async {
          final rows = await tx.query(
            'learning_outbox',
            columns: ['attempts'],
            where: "event_id = ? AND state != 'synced'",
            whereArgs: [eventId],
          );
          if (rows.isEmpty) return;
          final attempts = (rows.single['attempts'] as int) + 1;
          final blocked =
              statusCode != null &&
              statusCode >= 400 &&
              statusCode < 500 &&
              !{401, 403, 408, 429}.contains(statusCode);
          final delay = {401, 403, 429}.contains(statusCode)
              ? 300
              : min(300, 5 * pow(2, min(attempts - 1, 6)).toInt());
          await tx.update(
            'learning_outbox',
            {
              'state': blocked ? 'blocked' : 'retry',
              'attempts': attempts,
              'next_attempt_at':
                  now.toUtc().millisecondsSinceEpoch + delay * 1000,
              'last_status': statusCode,
              'updated_at': now.toUtc().millisecondsSinceEpoch,
            },
            where: 'event_id = ?',
            whereArgs: [eventId],
          );
        });
      });

  @override
  Future<bool> retryBlocked(
    String eventId, {
    required LearningDeliveryScope scope,
  }) => _guard(
    'retry_blocked',
    () async => (await database).transaction((tx) async {
      const predicate =
          "event_id = ? AND owner_id = ? AND api_url = ? AND state = 'blocked'";
      final arguments = [eventId, scope.ownerId, scope.apiUrl];
      final rows = await tx.query(
        'learning_outbox',
        where: predicate,
        whereArgs: arguments,
      );
      if (rows.isEmpty) return false;
      if (!scope.matches(_decodePersisted(rows.single))) return false;
      return await tx.update(
            'learning_outbox',
            {
              'state': 'pending',
              'next_attempt_at': 0,
              'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
            },
            where: predicate,
            whereArgs: arguments,
          ) ==
          1;
    }),
  );

  @override
  Future<void> clear({required bool preserveOwned}) =>
      _guard('clear', () async {
        await (await database).transaction((tx) async {
          await tx.delete(
            'learning_outbox',
            where: preserveOwned ? 'owner_id IS NULL' : null,
          );
          if (!preserveOwned) await tx.delete('outbox_imports');
        });
      });

  Future<void> close() => _guard('close', () async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  });
}
