import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive state needed to safely resume an interrupted check-in.
///
/// The rotating check-in token is deliberately absent. It must remain in
/// memory only and be scanned/pasted again after the app is restarted.
class CheckinDraft {
  const CheckinDraft({
    required this.classId,
    required this.sessionId,
    required this.kind,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String classId;
  final String sessionId;
  final String kind;
  final String idempotencyKey;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'session_id': sessionId,
    'kind': kind,
    'idempotency_key': idempotencyKey,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static CheckinDraft? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final classId = value['class_id'];
    final sessionId = value['session_id'];
    final kind = value['kind'];
    final idempotencyKey = value['idempotency_key'];
    final createdAt = DateTime.tryParse(value['created_at'] as String? ?? '');
    if (classId is! String ||
        classId.trim().isEmpty ||
        sessionId is! String ||
        sessionId.trim().isEmpty ||
        (kind != 'checkin' && kind != 'checkout') ||
        idempotencyKey is! String ||
        !idempotencyKey.startsWith('mobile:') ||
        createdAt == null) {
      return null;
    }
    return CheckinDraft(
      classId: classId,
      sessionId: sessionId,
      kind: kind as String,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt.toUtc(),
    );
  }
}

abstract interface class CheckinDraftStore {
  Future<CheckinDraft?> read();
  Future<void> write(CheckinDraft draft);
  Future<void> clear();
}

class SharedPreferencesCheckinDraftStore implements CheckinDraftStore {
  SharedPreferencesCheckinDraftStore({
    DateTime Function()? now,
    this.maxAge = const Duration(hours: 24),
  }) : _now = now ?? DateTime.now;

  static const storageKey = 'evidence:pending_checkin:v1';

  final DateTime Function() _now;
  final Duration maxAge;

  @override
  Future<CheckinDraft?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null) return null;
    try {
      final draft = CheckinDraft.fromJson(jsonDecode(raw));
      if (draft == null ||
          _now().toUtc().difference(draft.createdAt) > maxAge ||
          draft.createdAt.isAfter(
            _now().toUtc().add(const Duration(minutes: 5)),
          )) {
        await preferences.remove(storageKey);
        return null;
      }
      return draft;
    } on Object {
      await preferences.remove(storageKey);
      return null;
    }
  }

  @override
  Future<void> write(CheckinDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}
