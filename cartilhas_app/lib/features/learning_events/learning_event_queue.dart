import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import 'learning_event.dart';
import 'learning_outbox.dart';
import 'sqlite_learning_outbox.dart';

class _LearningQueueChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}

class LearningEventQueue {
  const LearningEventQueue({this.maxPending = 500, this.outbox})
    : assert(maxPending > 0);

  final LearningOutbox? outbox;
  static final _LearningQueueChanges _changes = _LearningQueueChanges();
  Listenable get changes => _changes;
  bool get isDurable =>
      outbox != null || AppConfig.durableLearningOutboxEnabled;

  Future<LearningOutbox?> _store() async {
    final store =
        outbox ??
        (AppConfig.durableLearningOutboxEnabled
            ? SqliteLearningOutbox.instance
            : null);
    if (store == null) return null;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on PlatformException {
      throw const OutboxStorageException('legacy_read');
    } on MissingPluginException {
      throw const OutboxStorageException('legacy_read');
    }
    final legacy = prefs.get(_storageKey);
    if (legacy != null) {
      if (legacy is! String) throw const OutboxDataException('legacy');
      await store.importLegacy(legacy);
      // Do not remove a source changed by another importer/producer while waiting.
      final remaining = prefs.get(_storageKey);
      if (remaining == null) return store;
      if (remaining != legacy) {
        throw const OutboxMigrationException(committed: true);
      }
      try {
        if (!await prefs.remove(_storageKey)) {
          throw const OutboxMigrationException(committed: true);
        }
      } on PlatformException {
        throw const OutboxMigrationException(committed: true);
      } on MissingPluginException {
        throw const OutboxMigrationException(committed: true);
      }
      _changes.changed();
    }
    return store;
  }

  Future<List<LearningEvent>> ready(DateTime now) async {
    final store = await _store();
    return store == null ? pending() : store.pending(readyAt: now);
  }

  Future<void> recordFailure(
    String eventId, {
    required DateTime now,
    int? statusCode,
  }) async {
    try {
      await (await _store())?.fail(eventId, now: now, statusCode: statusCode);
    } finally {
      _changes.changed();
    }
  }

  Future<LearningDeliverySnapshot> deliveryStatus(
    LearningDeliveryScope scope,
  ) async {
    await _operationTail;
    final store = await _store();
    if (store == null) {
      throw StateError('Delivery status requires the durable outbox');
    }
    return store.deliveryStatus(scope);
  }

  Future<bool> retryBlocked(
    String eventId, {
    required LearningDeliveryScope scope,
  }) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final store = await _store();
      if (store == null) {
        throw StateError('Scoped retry requires the durable outbox');
      }
      return await store.retryBlocked(eventId, scope: scope);
    } finally {
      turn.complete();
      _changes.changed();
    }
  }

  static const _storageKey = 'learning_events:pending:v1';
  static Future<void> _operationTail = Future<void>.value();

  /// Soft retention target: telemetry can be discarded, learning evidence cannot.
  /// A durable database outbox remains a separate migration gate.
  final int maxPending;

  Future<bool> enqueue(LearningEvent event) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final store = await _store();
      if (store != null) return await store.enqueue(event);
      final prefs = await SharedPreferences.getInstance();
      final events = _decode(prefs.getString(_storageKey));
      if (events.any((item) => item.eventId == event.eventId)) return false;
      if (events.length >= maxPending) {
        final oldestTelemetry = events.indexWhere((item) => item.isTelemetry);
        if (event.isTelemetry && oldestTelemetry < 0) return false;
        if (oldestTelemetry >= 0) events.removeAt(oldestTelemetry);
      }
      events.add(event);
      await prefs.setString(
        _storageKey,
        jsonEncode(events.map((item) => item.toStorageJson()).toList()),
      );
      return true;
    } finally {
      turn.complete();
      _changes.changed();
    }
  }

  Future<List<LearningEvent>> pending() async {
    final previous = _operationTail;
    await previous;
    final store = await _store();
    if (store != null) return List.unmodifiable(await store.pending());
    final prefs = await SharedPreferences.getInstance();
    return List.unmodifiable(_decode(prefs.getString(_storageKey)));
  }

  Future<bool> removeById(String eventId) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final store = await _store();
      if (store != null) return await store.acknowledge(eventId);
      final prefs = await SharedPreferences.getInstance();
      final events = _decode(prefs.getString(_storageKey));
      final originalLength = events.length;
      events.removeWhere((event) => event.eventId == eventId);
      if (events.length == originalLength) return false;
      await prefs.setString(
        _storageKey,
        jsonEncode(events.map((event) => event.toStorageJson()).toList()),
      );
      return true;
    } finally {
      turn.complete();
      _changes.changed();
    }
  }

  Future<void> clear({bool preserveOwned = false}) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final store = await _store();
      if (store != null) {
        await store.clear(preserveOwned: preserveOwned);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (preserveOwned) {
        final owned = _decode(
          prefs.getString(_storageKey),
        ).where((event) => event.localOwnerId != null).toList();
        if (owned.isEmpty) {
          await prefs.remove(_storageKey);
          return;
        }
        await prefs.setString(
          _storageKey,
          jsonEncode(owned.map((event) => event.toStorageJson()).toList()),
        );
      } else {
        await prefs.remove(_storageKey);
      }
    } finally {
      turn.complete();
      _changes.changed();
    }
  }

  List<LearningEvent> _decode(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List<dynamic>) return [];
      return decoded
          .map(LearningEvent.fromJson)
          .whereType<LearningEvent>()
          .toList();
    } on FormatException {
      return [];
    }
  }
}
