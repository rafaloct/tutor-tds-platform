import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/data/auth_repository.dart';
import 'learning_context.dart';

abstract interface class LearningContextRepository {
  Future<LearningContextSnapshot> resolve(String cohortId);
}

class LearningContextException implements Exception {
  const LearningContextException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class RemoteLearningContextRepository implements LearningContextRepository {
  RemoteLearningContextRepository({
    required this.apiUrl,
    required this.auth,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;
  final String apiUrl;
  final AuthRepository auth;
  final http.Client _client;
  final DateTime Function() _clock;
  String? _owner;
  static const maxAge = Duration(days: 7);

  String _key(String owner, String cohort) =>
      'learning_context:v1:${sha256.convert(utf8.encode(jsonEncode([apiUrl.replaceFirst(RegExp(r'/+$'), ''), owner, cohort])))}';

  Future<void> _checkOwner(String owner) async {
    if (await auth.localUserId() != owner) {
      throw const LearningContextException(
        'A conta mudou. Reabra suas turmas.',
        statusCode: 401,
      );
    }
  }

  LearningContextSnapshot _parse(
    String body,
    String owner,
    String cohort, {
    bool cached = false,
  }) {
    try {
      final snapshot = LearningContextSnapshot.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
        fromCache: cached,
      );
      if (snapshot.context.userId != owner ||
          snapshot.context.cohortId != cohort ||
          !snapshot.context.permissions.contains('content.read')) {
        throw const FormatException('Context does not match request');
      }
      return snapshot;
    } on FormatException {
      throw const LearningContextException(
        'O contexto da matrícula precisa ser atualizado.',
      );
    } on TypeError {
      throw const LearningContextException(
        'A resposta da matrícula está incompleta.',
      );
    }
  }

  @override
  Future<LearningContextSnapshot> resolve(String cohortId) async {
    final owner = await auth.localUserId();
    if (owner == null || (_owner != null && _owner != owner)) {
      throw const LearningContextException(
        'Entre novamente para consultar sua matrícula.',
        statusCode: 401,
      );
    }
    _owner = owner;
    final prefs = await SharedPreferences.getInstance();
    final key = _key(owner, cohortId);
    Future<LearningContextSnapshot> saved() async {
      await _checkOwner(owner);
      final body = prefs.getString(key);
      if (body == null) {
        throw const LearningContextException(
          'Abra esta turma com internet antes de estudar offline.',
        );
      }
      final snapshot = _parse(body, owner, cohortId, cached: true);
      final age = _clock().toUtc().difference(snapshot.resolvedAt.toUtc());
      if (age.isNegative || age >= maxAge) {
        throw const LearningContextException(
          'Reconecte para atualizar seu acesso à turma.',
        );
      }
      return snapshot;
    }

    try {
      final response = await auth.authorized((token) async {
        await _checkOwner(owner);
        return _client
            .get(
              Uri.parse(
                '${apiUrl.replaceFirst(RegExp(r'/+$'), '')}/classes/${Uri.encodeComponent(cohortId)}/learning-context',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
      });
      await _checkOwner(owner);
      if (response.statusCode >= 500) return saved();
      if (response.statusCode != 200) {
        await prefs.remove(key);
        throw LearningContextException(
          'Não foi possível validar sua matrícula. Atualize o acesso com a equipe.',
          statusCode: response.statusCode,
        );
      }
      late final LearningContextSnapshot snapshot;
      try {
        snapshot = _parse(response.body, owner, cohortId);
      } on LearningContextException {
        await prefs.remove(key);
        rethrow;
      }
      await _checkOwner(owner);
      final stored = await prefs.setString(
        key,
        jsonEncode(snapshot.toCacheJson()),
      );
      if (!stored) {
        throw const LearningContextException(
          'Não foi possível salvar o acesso offline neste aparelho.',
        );
      }
      return snapshot;
    } on AuthException catch (error) {
      if (error.allowOfflineFallback) return saved();
      await prefs.remove(key);
      rethrow;
    } on TimeoutException {
      return saved();
    } on http.ClientException {
      return saved();
    }
  }

  void dispose() => _client.close();
}

class FakeLearningContextRepository implements LearningContextRepository {
  FakeLearningContextRepository(this.snapshots);
  final Map<String, LearningContextSnapshot> snapshots;
  @override
  Future<LearningContextSnapshot> resolve(String cohortId) async {
    final value = snapshots[cohortId];
    if (value == null) {
      throw const LearningContextException(
        'Matrícula não encontrada.',
        statusCode: 403,
      );
    }
    return value;
  }
}
