import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment_sync_models.dart';
import '../models/study_models.dart';

class AssessmentSyncQueue {
  const AssessmentSyncQueue();

  static const _storageKey = 'study_assessment:sync:v1';
  static Future<void> _operationTail = Future<void>.value();

  Future<AssessmentSyncRecord?> read(String attemptId) async {
    await _operationTail;
    final records = await _readAll();
    return records[attemptId];
  }

  Future<void> clear() async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } finally {
      turn.complete();
    }
  }

  Future<AssessmentSyncRecord> enqueue(AssessmentAttempt attempt) =>
      _mutate(attempt.id, (current) {
        if (current?.status == AssessmentSyncStatus.conflict) return current!;
        final confirmedRevision = current?.confirmedRevision ?? 0;
        final pending = [...?current?.pending];
        final last = pending.isEmpty ? null : pending.last;
        final nextRevision = last?.payload.revision ?? confirmedRevision;
        final candidate = AssessmentSyncPayload.fromAttempt(
          attempt,
          revision: nextRevision + 1,
        );

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
    );
  });

  Future<AssessmentSyncRecord> acceptRemote(
    String attemptId,
    RemoteAssessmentAttempt remote,
  ) => _mutate(
    attemptId,
    (_) => AssessmentSyncRecord(
      attemptId: attemptId,
      status: AssessmentSyncStatus.synced,
      confirmedRevision: remote.payload.revision,
      confirmedPayload: remote.payload,
      pending: const [],
    ),
  );

  Future<AssessmentSyncRecord> replaceWithLocal(
    AssessmentAttempt attempt,
    RemoteAssessmentAttempt remote,
  ) => _mutate(attempt.id, (_) {
    final payload = AssessmentSyncPayload.fromAttempt(
      attempt.copyWith(updatedAt: DateTime.now().toUtc()),
      revision: remote.payload.revision + 1,
    );
    return AssessmentSyncRecord(
      attemptId: attempt.id,
      status: AssessmentSyncStatus.pending,
      confirmedRevision: remote.payload.revision,
      confirmedPayload: remote.payload,
      pending: [AssessmentPendingRevision(payload: payload)],
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(records.map((key, value) => MapEntry(key, value.toJson()))),
      );
      return next;
    } finally {
      turn.complete();
    }
  }

  Future<Map<String, AssessmentSyncRecord>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_storageKey);
    if (source == null || source.isEmpty) return {};
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map((key, value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Registro de sincronização inválido.');
        }
        return MapEntry(key, AssessmentSyncRecord.fromJson(value));
      });
    } on FormatException {
      return {};
    }
  }
}
