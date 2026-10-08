import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment_sync_models.dart';
import '../models/study_models.dart';

abstract interface class AssessmentSyncQueueStorage {
  Future<String?> read();
  Future<bool> write(String value);
  Future<bool> remove();
}

class SharedPreferencesAssessmentSyncQueueStorage
    implements AssessmentSyncQueueStorage {
  const SharedPreferencesAssessmentSyncQueueStorage();

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance())
      .getString(AssessmentSyncQueue.storageKey);

  @override
  Future<bool> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(
        AssessmentSyncQueue.storageKey,
        value,
      );

  @override
  Future<bool> remove() async => (await SharedPreferences.getInstance()).remove(
    AssessmentSyncQueue.storageKey,
  );
}

class AssessmentSyncQueue {
  const AssessmentSyncQueue({this.storage});

  static const storageKey = 'study_assessment:sync:v1';
  static Future<void> _operationTail = Future<void>.value();
  final AssessmentSyncQueueStorage? storage;

  AssessmentSyncQueueStorage get _resolvedStorage =>
      storage ?? const SharedPreferencesAssessmentSyncQueueStorage();

  Future<AssessmentSyncRecord?> read(String attemptId) async {
    await _operationTail;
    final records = await _readAll();
    return records[attemptId];
  }

  Future<void> clear({bool preserveOwned = false}) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      if (!preserveOwned) {
        await _resolvedStorage.remove();
      } else {
        final records = await _readAll();
        records.removeWhere((_, record) => record.localContext == null);
        if (records.isEmpty) {
          await _resolvedStorage.remove();
        } else {
          final stored = await _resolvedStorage.write(
            jsonEncode(
              records.map((key, value) => MapEntry(key, value.toJson())),
            ),
          );
          if (!stored) {
            throw StateError(
              'Não foi possível preservar a fila de avaliações.',
            );
          }
        }
      }
    } finally {
      turn.complete();
    }
  }

  Future<AssessmentSyncRecord> enqueue(AssessmentAttempt attempt) =>
      _mutate(attempt.id, (current) {
        final context = attempt.publishedContext;
        final currentContext = current?.localContext;
        if (current != null &&
            ((currentContext == null) != (context == null) ||
                (currentContext != null && !currentContext.sameAs(context)))) {
          throw StateError(
            'Tentativa reutilizada em um contexto local divergente.',
          );
        }
        if (current?.status == AssessmentSyncStatus.conflict) return current!;
        final confirmedRevision = current?.confirmedRevision ?? 0;
        final pending = [...?current?.pending];
        final last = pending.isEmpty ? null : pending.last;
        final nextRevision = last?.payload.revision ?? confirmedRevision;
        var candidate = AssessmentSyncPayload.fromAttempt(
          attempt,
          revision: nextRevision + 1,
        );
        final confirmedTimestamp = current?.confirmedPayload?.updatedAt;
        final pendingTimestamp = last?.payload.updatedAt;
        final timestampFloor = switch ((confirmedTimestamp, pendingTimestamp)) {
          (final confirmed?, final pending?) =>
            confirmed.isAfter(pending) ? confirmed : pending,
          (final confirmed?, null) => confirmed,
          (null, final pending?) => pending,
          _ => null,
        };
        if (timestampFloor != null &&
            candidate.updatedAt.isBefore(timestampFloor)) {
          candidate = candidate.withUpdatedAt(timestampFloor);
        }

        if (last != null && last.payload.hasSameState(candidate)) {
          return current!;
        }
        if (last == null &&
            current?.confirmedPayload?.hasSameState(candidate) == true) {
          return AssessmentSyncRecord(
            attemptId: attempt.id,
            status: AssessmentSyncStatus.synced,
            confirmedRevision: confirmedRevision,
            confirmedPayload: current?.confirmedPayload,
            pending: const [],
            localContext: context,
          );
        }
        if (last != null && !last.wasAttempted) {
          pending[pending.length - 1] = AssessmentPendingRevision(
            payload: candidate.withRevision(last.payload.revision),
          );
        } else {
          pending.add(AssessmentPendingRevision(payload: candidate));
        }
        return AssessmentSyncRecord(
          attemptId: attempt.id,
          status: AssessmentSyncStatus.pending,
          confirmedRevision: confirmedRevision,
          confirmedPayload: current?.confirmedPayload,
          pending: pending,
          lastError: current?.lastError,
          localContext: context,
        );
      });

  Future<AssessmentSyncRecord> markAttempted(String attemptId, int revision) =>
      _mutate(attemptId, (current) {
        if (current == null) {
          throw StateError('Tentativa sem revisão pendente.');
        }
        final pending = current.pending
            .map(
              (item) => item.payload.revision == revision
                  ? AssessmentPendingRevision(
                      payload: item.payload,
                      wasAttempted: true,
                    )
                  : item,
            )
            .toList();
        return AssessmentSyncRecord(
          attemptId: attemptId,
          status: AssessmentSyncStatus.pending,
          confirmedRevision: current.confirmedRevision,
          confirmedPayload: current.confirmedPayload,
          pending: pending,
          lastError: current.lastError,
          localContext: current.localContext,
        );
      });

  Future<AssessmentSyncRecord> markSuccess(
    String attemptId,
    RemoteAssessmentAttempt response,
  ) => _mutate(attemptId, (current) {
    if (current == null || current.pending.isEmpty) {
      throw StateError('Resposta sem revisão pendente.');
    }
    final first = current.pending.first;
    if (response.attemptId != attemptId ||
        !response.payload.isAcceptedResponseFor(first.payload)) {
      throw const FormatException('Resposta de sincronização divergente.');
    }
    final remaining = current.pending.skip(1).toList();
    return AssessmentSyncRecord(
      attemptId: attemptId,
      status: remaining.isEmpty
          ? AssessmentSyncStatus.synced
          : AssessmentSyncStatus.pending,
      confirmedRevision: response.payload.revision,
      confirmedPayload: response.payload,
      pending: remaining,
      localContext: current.localContext,
    );
  });

  Future<AssessmentSyncRecord> markPending(String attemptId, String error) =>
      _mutate(attemptId, (current) {
        if (current == null) throw StateError('Tentativa não enfileirada.');
        return AssessmentSyncRecord(
          attemptId: attemptId,
          status: AssessmentSyncStatus.pending,
          confirmedRevision: current.confirmedRevision,
          confirmedPayload: current.confirmedPayload,
          pending: current.pending,
          lastError: error,
          localContext: current.localContext,
        );
      });

  /// Re-times a server-rejected contextual revision without changing its
  /// identity or academic state. The same revision is safe to replay because
  /// `future_updated_at` is guaranteed to be rejected before persistence.
  Future<AssessmentSyncRecord> correctFutureUpdatedAt(
    String attemptId,
    int revision,
    DateTime serverTime,
  ) => _mutate(attemptId, (current) {
    if (current == null || current.pending.isEmpty) {
      throw StateError('Tentativa sem revisão pendente para corrigir.');
    }
    final rejected = current.pending.first;
    if (rejected.payload.revision != revision) {
      throw StateError(
        'A revisão pendente mudou durante a correção de horário.',
      );
    }
    var correctedTime = serverTime.toUtc();
    final confirmedTime = current.confirmedPayload?.updatedAt;
    if (confirmedTime != null && confirmedTime.isAfter(correctedTime)) {
      correctedTime = confirmedTime;
    }
    final pending = [...current.pending];
    pending[0] = AssessmentPendingRevision(
      payload: rejected.payload.withUpdatedAt(correctedTime),
    );
    return AssessmentSyncRecord(
      attemptId: current.attemptId,
      status: AssessmentSyncStatus.pending,
      confirmedRevision: current.confirmedRevision,
      confirmedPayload: current.confirmedPayload,
      pending: pending,
      localContext: current.localContext,
    );
  });

  Future<AssessmentSyncRecord> markConflict(
    String attemptId,
    RemoteAssessmentAttempt? remote,
    String error,
  ) => _mutate(attemptId, (current) {
    if (current == null) throw StateError('Tentativa não enfileirada.');
    return AssessmentSyncRecord(
      attemptId: attemptId,
      status: AssessmentSyncStatus.conflict,
      confirmedRevision: current.confirmedRevision,
      confirmedPayload: current.confirmedPayload,
      pending: current.pending,
      remoteConflict: remote,
      lastError: error,
      localContext: current.localContext,
    );
  });

  Future<AssessmentSyncRecord> acceptRemote(
    String attemptId,
    RemoteAssessmentAttempt remote, {
    PublishedAssessmentContext? localContext,
  }) => _mutate(
    attemptId,
    (current) => AssessmentSyncRecord(
      attemptId: attemptId,
      status: AssessmentSyncStatus.synced,
      confirmedRevision: remote.payload.revision,
      confirmedPayload: remote.payload,
      pending: const [],
      localContext: localContext ?? current?.localContext,
    ),
  );

  Future<AssessmentSyncRecord> replaceWithLocal(
    AssessmentAttempt attempt,
    RemoteAssessmentAttempt remote,
  ) => _mutate(attempt.id, (_) {
    final now = DateTime.now().toUtc();
    final updatedAt = remote.payload.updatedAt.isAfter(now)
        ? remote.payload.updatedAt
        : now;
    final payload = AssessmentSyncPayload.fromAttempt(
      attempt.copyWith(updatedAt: updatedAt),
      revision: remote.payload.revision + 1,
    );
    return AssessmentSyncRecord(
      attemptId: attempt.id,
      status: AssessmentSyncStatus.pending,
      confirmedRevision: remote.payload.revision,
      confirmedPayload: remote.payload,
      pending: [AssessmentPendingRevision(payload: payload)],
      localContext: attempt.publishedContext,
    );
  });

  Future<AssessmentSyncRecord> _mutate(
    String attemptId,
    AssessmentSyncRecord Function(AssessmentSyncRecord? current) update,
  ) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final records = await _readAll();
      final next = update(records[attemptId]);
      records[attemptId] = next;
      final stored = await _resolvedStorage.write(
        jsonEncode(records.map((key, value) => MapEntry(key, value.toJson()))),
      );
      if (!stored) {
        throw StateError('Não foi possível salvar a fila de avaliações.');
      }
      return next;
    } finally {
      turn.complete();
    }
  }

  Future<Map<String, AssessmentSyncRecord>> _readAll() async {
    final source = await _resolvedStorage.read();
    if (source == null || source.isEmpty) return {};
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return {};
      final records = <String, AssessmentSyncRecord>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        try {
          records[entry.key] = AssessmentSyncRecord.fromJson(value);
        } on Object {
          // One stale legacy record must not hide other owner-scoped records.
        }
      }
      return records;
    } on Object {
      return {};
    }
  }
}
