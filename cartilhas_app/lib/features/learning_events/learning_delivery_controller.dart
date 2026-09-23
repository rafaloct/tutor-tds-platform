import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/privacy_preferences.dart';
import '../auth/data/auth_repository.dart';
import 'learning_event.dart';
import 'learning_event_queue.dart';
import 'learning_event_sync_service.dart';
import 'learning_outbox.dart';

enum LearningDeliveryIssue { storage, data, migration, conflict, access }

/// Presentation state for one server-resolved cohort enrollment, never an
/// authorization source. An unsaved event remains in memory, not in a second DB.
class LearningDeliveryController extends ChangeNotifier {
  LearningDeliveryController({
    required this.scope,
    required this.queue,
    required this.sync,
    required this.auth,
    required this.revalidateAccess,
    required this.onDelivered,
    this.consentChecker = PrivacyPreferences.hasConsent,
  }) {
    queue.changes.addListener(_changed);
  }

  final LearningDeliveryScope scope;
  final LearningEventQueue queue;
  final LearningEventSyncService sync;
  final AuthRepository auth;
  final Future<bool> Function() revalidateAccess;
  final Future<void> Function() onDelivered;
  final Future<bool> Function() consentChecker;
  LearningDeliverySnapshot? snapshot;
  LearningDeliveryIssue? issue;
  String? lastStoredEventId;
  bool consent = true;
  bool saving = false;
  bool synchronizing = false;
  bool loading = true;
  bool _disposed = false;
  bool _refreshAgain = false;
  Future<void>? _refreshInFlight;
  LearningEvent? _unsaved;

  bool get hasUnsavedEvent => _unsaved != null;
  bool get canRecord => !saving && !hasUnsavedEvent && issue == null;
  bool get busy => saving || synchronizing;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!_disposed) unawaited(refresh());
  }

  Future<bool> _sameOwner() async {
    final current = await auth.localUserId();
    if (_disposed) return false;
    if (current != scope.ownerId ||
        auth.apiUrl.replaceFirst(RegExp(r'/+$'), '') != scope.apiUrl) {
      snapshot = null;
      issue = LearningDeliveryIssue.access;
      _notify();
      return false;
    }
    return true;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    final current = _refreshInFlight;
    if (current != null) {
      _refreshAgain = true;
      return current;
    }
    final operation = _refresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<void> _refresh() async {
    do {
      _refreshAgain = false;
      try {
        if (!await _sameOwner()) return;
        final next = await queue.deliveryStatus(scope);
        final allowed = await consentChecker();
        if (!await _sameOwner()) return;
        snapshot = next;
        consent = allowed;
        // Reading an empty queue cannot erase an event that failed to commit.
        if (!hasUnsavedEvent && issue != LearningDeliveryIssue.access) {
          issue = null;
        }
      } on OutboxStorageException {
        issue = LearningDeliveryIssue.storage;
        snapshot = null;
      } on OutboxDataException {
        issue = LearningDeliveryIssue.data;
        snapshot = null;
      } on OutboxMigrationException {
        issue = LearningDeliveryIssue.migration;
        snapshot = null;
      } on OutboxConflict {
        issue = LearningDeliveryIssue.conflict;
        snapshot = null;
      } on AuthException {
        issue = LearningDeliveryIssue.access;
        snapshot = null;
      } finally {
        loading = false;
        _notify();
      }
    } while (_refreshAgain && !_disposed);
  }

  Future<bool> record(LearningEvent event) {
    if (_disposed || !canRecord) return Future.value(false);
    if (!scope.matches(event)) {
      throw ArgumentError('Learning event does not match delivery scope.');
    }
    return _save(event);
  }

  Future<bool> retrySave() {
    final event = _unsaved;
    if (_disposed || saving || event == null) return Future.value(false);
    return _save(event);
  }

  Future<bool> _save(LearningEvent event) async {
    saving = true;
    _notify();
    try {
      if (!await _sameOwner()) return false;
      _unsaved = event;
      // A false result means this exact immutable ID already exists, including
      // an acknowledged receipt. It is not a reason to manufacture another ID.
      await queue.enqueue(event);
      _unsaved = null;
      lastStoredEventId = event.eventId;
      issue = null;
      if (!await _sameOwner()) return true;
      await refresh();
      unawaited(synchronize());
      return true;
    } on OutboxStorageException {
      issue = LearningDeliveryIssue.storage;
    } on OutboxDataException {
      issue = LearningDeliveryIssue.data;
    } on OutboxMigrationException {
      issue = LearningDeliveryIssue.migration;
    } on OutboxConflict {
      issue = LearningDeliveryIssue.conflict;
    } on AuthException {
      issue = LearningDeliveryIssue.access;
    } finally {
      saving = false;
      _notify();
    }
    return false;
  }

  Future<void> synchronize({bool retryBlocked = false}) async {
    if (_disposed || synchronizing || hasUnsavedEvent) return;
    synchronizing = true;
    _notify();
    try {
      if (!await _sameOwner()) return;
      consent = await consentChecker();
      if (!consent || !await _sameOwner()) return;
      if (retryBlocked ||
          snapshot?.requiresAccessRefresh == true ||
          issue == LearningDeliveryIssue.access) {
        if (!await revalidateAccess() || !await _sameOwner()) {
          issue = LearningDeliveryIssue.access;
          return;
        }
        issue = null;
      }
      if (retryBlocked) {
        final current = await queue.deliveryStatus(scope);
        for (final record in current.blockedEvents) {
          if (!await _sameOwner()) return;
          await queue.retryBlocked(record.eventId, scope: scope);
        }
      }
      final sent = await sync.flush();
      if (!await _sameOwner()) return;
      if (sent > 0) await onDelivered();
      await refresh();
    } on OutboxStorageException {
      issue = LearningDeliveryIssue.storage;
    } on OutboxDataException {
      issue = LearningDeliveryIssue.data;
    } on OutboxMigrationException {
      issue = LearningDeliveryIssue.migration;
    } on OutboxConflict {
      issue = LearningDeliveryIssue.conflict;
    } on AuthException {
      issue = LearningDeliveryIssue.access;
    } finally {
      synchronizing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    queue.changes.removeListener(_changed);
    super.dispose();
  }
}
