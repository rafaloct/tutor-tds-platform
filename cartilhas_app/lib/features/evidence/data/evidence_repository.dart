import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../models/evidence_models.dart';

abstract interface class EvidenceGateway {
  Future<EvidenceSession> createSession({
    required String classId,
    required DateTime startsAt,
    required DateTime endsAt,
  });
  Future<EvidenceSessionPage> listSessions(
    String classId, {
    String? status,
    int limit = 50,
    int offset = 0,
  });
  Future<EvidenceSession?> openSession(String classId);
  Future<EvidenceSession?> session(String classId, String sessionId);
  Future<EvidenceSession> rotateToken(String classId, String sessionId);
  Future<EvidenceCheckin> checkin({
    required String classId,
    required String sessionId,
    required String kind,
    required String idempotencyKey,
    required String token,
  });
  Future<EvidenceImportRecord> createImport({
    required String classId,
    required String sourceType,
    required String sourceDigest,
    required String idempotencyKey,
    required DateTime retentionUntil,
    required List<EvidenceImportItemDraft> items,
  });
  Future<EvidenceImportRecord> getImport(String classId, String importId);
  Future<List<EvidenceExceptionItem>> exceptions(String classId);
  Future<EvidenceReviewResult> review({
    required String classId,
    required String evidenceId,
    required String decision,
    required String reasonCode,
  });
  Future<EvidenceReport> closeSession({
    required String classId,
    required String sessionId,
    bool confirmPending = false,
  });
  Future<EvidenceReport> report(String classId, String reportId);
}

class EvidenceApiException implements Exception {
  const EvidenceApiException(
    this.message, {
    this.statusCode,
    this.isNetworkFailure = false,
  });
  final String message;
  final int? statusCode;
  final bool isNetworkFailure;

  @override
  String toString() => message;
}

class EvidenceRepository implements EvidenceGateway {
  EvidenceRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;

  @override
  Future<EvidenceSession> createSession({
    required String classId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => EvidenceSession.fromJson(
    await _request(
      'POST',
      '/admin/classes/${_segment(classId)}/sessions',
      body: {
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
      },
    ),
  );

  @override
  Future<EvidenceSessionPage> listSessions(
    String classId, {
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (status != null && status != 'open' && status != 'closed') {
      throw const EvidenceApiException('Status de sessão inválido.');
    }
    final query = Uri(
      queryParameters: {
        'status': ?status,
        'limit': limit.clamp(1, 100).toString(),
        'offset': offset.clamp(0, 1 << 31).toString(),
      },
    ).query;
    return EvidenceSessionPage.fromJson(
      await _request('GET', '/classes/${_segment(classId)}/sessions?$query'),
    );
  }

  @override
  Future<EvidenceSession?> openSession(String classId) async {
    try {
      return EvidenceSession.fromJson(
        await _request('GET', '/classes/${_segment(classId)}/sessions/open'),
      );
    } on EvidenceApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<EvidenceSession?> session(String classId, String sessionId) async {
    try {
      return EvidenceSession.fromJson(
        await _request(
          'GET',
          '/classes/${_segment(classId)}/sessions/${_segment(sessionId)}',
        ),
      );
    } on EvidenceApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<EvidenceSession> rotateToken(String classId, String sessionId) async =>
      EvidenceSession.fromJson(
        await _request(
          'POST',
          '/classes/${_segment(classId)}/sessions/${_segment(sessionId)}/token',
        ),
      );

  @override
  Future<EvidenceCheckin> checkin({
    required String classId,
    required String sessionId,
    required String kind,
    required String idempotencyKey,
    required String token,
  }) async => EvidenceCheckin.fromJson(
    await _request(
      'POST',
      '/classes/${_segment(classId)}/sessions/${_segment(sessionId)}/checkins',
      body: {'kind': kind, 'idempotency_key': idempotencyKey, 'token': token},
    ),
  );

  @override
  Future<EvidenceImportRecord> createImport({
    required String classId,
    required String sourceType,
    required String sourceDigest,
    required String idempotencyKey,
    required DateTime retentionUntil,
    required List<EvidenceImportItemDraft> items,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64,128}$').hasMatch(sourceDigest)) {
      throw const EvidenceApiException('Digest da origem inválido.');
    }
    return EvidenceImportRecord.fromJson(
      await _request(
        'POST',
        '/classes/${_segment(classId)}/evidence-imports',
        body: {
          'source_type': sourceType,
          'source_digest': sourceDigest,
          'idempotency_key': idempotencyKey,
          'retention_until': retentionUntil.toUtc().toIso8601String(),
          'items': items.map((item) => item.toJson()).toList(growable: false),
        },
      ),
    );
  }

  @override
  Future<EvidenceImportRecord> getImport(
    String classId,
    String importId,
  ) async => EvidenceImportRecord.fromJson(
    await _request(
      'GET',
      '/classes/${_segment(classId)}/evidence-imports/${_segment(importId)}',
    ),
  );

  @override
  Future<List<EvidenceExceptionItem>> exceptions(String classId) async {
    final json = await _request(
      'GET',
      '/classes/${_segment(classId)}/exceptions',
    );
    return (json['exceptions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EvidenceExceptionItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EvidenceReviewResult> review({
    required String classId,
    required String evidenceId,
    required String decision,
    required String reasonCode,
  }) async => EvidenceReviewResult.fromJson(
    await _request(
      'POST',
      '/classes/${_segment(classId)}/evidence/${_segment(evidenceId)}/review',
      body: {'decision': decision, 'reason_code': reasonCode},
    ),
  );

  @override
  Future<EvidenceReport> closeSession({
    required String classId,
    required String sessionId,
    bool confirmPending = false,
  }) async => EvidenceReport.fromJson(
    await _request(
      'POST',
      '/classes/${_segment(classId)}/sessions/${_segment(sessionId)}/close?confirm_pending=$confirmPending',
    ),
  );

  @override
  Future<EvidenceReport> report(String classId, String reportId) async =>
      EvidenceReport.fromJson(
        await _request(
          'GET',
          '/classes/${_segment(classId)}/reports/${_segment(reportId)}',
        ),
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await authRepository.authorized((token) {
        final headers = {
          'Authorization': 'Bearer $token',
          if (body != null) 'Content-Type': 'application/json',
        };
        final uri = _uri(path);
        return switch (method) {
          'GET' => _client.get(uri, headers: headers),
          _ => _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ),
        }.timeout(const Duration(seconds: 15));
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EvidenceApiException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Objeto JSON esperado.');
      }
      return decoded;
    } on EvidenceApiException {
      rethrow;
    } on AuthException catch (error) {
      throw EvidenceApiException(error.message);
    } on FormatException catch (error) {
      throw EvidenceApiException(error.message);
    } on Object {
      throw const EvidenceApiException(
        'Sem conexão com o registro de evidências. Nenhum dado foi enviado.',
        isNetworkFailure: true,
      );
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on Object {
      // Mantém mensagem segura.
    }
    return switch (response.statusCode) {
      401 => 'Código inválido ou expirado.',
      403 => 'Sua conta não tem acesso a esta turma.',
      404 => 'Registro não encontrado.',
      409 => 'O registro possui pendências ou conflito de estado.',
      422 => 'Confira os metadados informados.',
      _ => 'Não foi possível concluir o registro.',
    };
  }

  String _segment(String value) => Uri.encodeComponent(value.trim());

  Uri _uri(String path) {
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return Uri.parse('$base$path');
  }

  void dispose() => _client.close();
}
