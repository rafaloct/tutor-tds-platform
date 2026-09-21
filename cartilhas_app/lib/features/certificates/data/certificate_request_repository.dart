import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../models/certificate_request.dart';

abstract interface class CertificateRequestGateway {
  Future<List<CertificateRequestContext>> contexts(
    String courseId,
    String versionId,
  );
  Future<CertificateRequest> create(CertificateRequestContext context);
  Future<List<CertificateRequest>> ownRequests();
  Future<List<CertificateRequest>> reviewQueue();
  Future<CertificateRequest> detail(String id);
  Future<CertificateRequest> review(
    String id,
    String decision,
    int revision,
    String reason,
  );
  Future<CertificateRequest> resubmit(String id, int revision);
}

class CertificateRequestException implements Exception {
  const CertificateRequestException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  bool get conflict => statusCode == 409;
  @override
  String toString() => message;
}

class CertificateRequestRepository implements CertificateRequestGateway {
  CertificateRequestRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;
  String? _boundOwner;
  static const _root = '/certificate-requests';

  @override
  Future<List<CertificateRequestContext>> contexts(
    String courseId,
    String versionId,
  ) {
    _requireId(courseId);
    _requireId(versionId);
    final query = Uri(
      queryParameters: {'course_id': courseId, 'course_version_id': versionId},
    ).query;
    return _request(
      'GET',
      '$_root/contexts?$query',
      (json) => _list(json, 'contexts', CertificateRequestContext.fromJson),
    );
  }

  @override
  Future<CertificateRequest> create(CertificateRequestContext context) {
    _requireId(context.enrollmentId);
    _requireId(context.courseVersionId);
    if (context.classId != null) _requireId(context.classId!);
    return _request(
      'POST',
      _root,
      CertificateRequest.fromJson,
      body: {
        'enrollment_id': context.enrollmentId,
        'course_version_id': context.courseVersionId,
        'class_id': context.classId,
      },
    );
  }

  @override
  Future<List<CertificateRequest>> ownRequests() => _request(
    'GET',
    _root,
    (json) => _list(json, 'requests', CertificateRequest.fromJson),
  );

  @override
  Future<List<CertificateRequest>> reviewQueue() => _request(
    'GET',
    '$_root/review-queue',
    (json) => _list(json, 'requests', CertificateRequest.fromJson),
  );

  @override
  Future<CertificateRequest> detail(String id) =>
      _request('GET', _path(id), CertificateRequest.fromJson);

  @override
  Future<CertificateRequest> review(
    String id,
    String decision,
    int revision,
    String reason,
  ) {
    _requireRevision(revision);
    if (!{'approve', 'reject'}.contains(decision)) {
      throw const CertificateRequestException(
        'Escolha aprovar ou rejeitar a solicitação.',
        statusCode: 422,
      );
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 3 || normalizedReason.length > 500) {
      throw const CertificateRequestException(
        'Informe uma justificativa com 3 a 500 caracteres.',
        statusCode: 422,
      );
    }
    return _request(
      'POST',
      '${_path(id)}/review',
      CertificateRequest.fromJson,
      body: {
        'decision': decision,
        'expected_revision': revision,
        'reason': normalizedReason,
      },
    );
  }

  @override
  Future<CertificateRequest> resubmit(String id, int revision) {
    _requireRevision(revision);
    return _request(
      'POST',
      '${_path(id)}/resubmit',
      CertificateRequest.fromJson,
      body: {'expected_revision': revision},
    );
  }

  Future<T> _request<T>(
    String method,
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final owner = await authRepository.localUserId();
      if (owner == null) {
        throw const CertificateRequestException(
          'Entre na conta para consultar as solicitações.',
          statusCode: 401,
        );
      }
      _boundOwner ??= owner;
      if (_boundOwner != owner) {
        throw const CertificateRequestException(
          'Sua sessão mudou. Abra novamente as solicitações na conta atual.',
          statusCode: 401,
        );
      }
      // Appending preserves installations hosted below /api or another prefix.
      final base = apiUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base$path');
      final response = await authRepository.authorized((token) async {
        await _requireSameOwner(owner);
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        return (method == 'POST'
                ? _client.post(uri, headers: headers, body: jsonEncode(body))
                : _client.get(uri, headers: headers))
            .timeout(const Duration(seconds: 15));
      });
      await _requireSameOwner(owner);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CertificateRequestException(
          _statusMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) throw const FormatException();
      return parse(json);
    } on CertificateRequestException {
      rethrow;
    } on AuthException {
      throw const CertificateRequestException(
        'Não foi possível validar sua sessão. Entre na conta e tente novamente.',
        statusCode: 401,
      );
    } on FormatException {
      throw const CertificateRequestException(
        'A resposta das solicitações é inválida. Atualize e tente novamente.',
      );
    } on TimeoutException {
      throw const CertificateRequestException(
        'A conexão demorou demais. Atualize a lista para conferir o resultado antes de tentar novamente.',
      );
    } on Object {
      throw const CertificateRequestException(
        'Não foi possível consultar ou confirmar a solicitação. Atualize a lista e tente novamente.',
      );
    }
  }

  Future<void> _requireSameOwner(String owner) async {
    if (await authRepository.localUserId() != owner) {
      throw const CertificateRequestException(
        'Sua sessão mudou. Abra novamente as solicitações na conta atual.',
        statusCode: 401,
      );
    }
  }

  List<T> _list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final values = json[key];
    if (values is! List) throw const FormatException();
    return List<T>.unmodifiable(
      values.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        return parse(item);
      }),
    );
  }

  String _path(String id) {
    _requireId(id);
    return '$_root/${Uri.encodeComponent(id)}';
  }

  void _requireId(String id) {
    if (id.trim().isEmpty || id == '.' || id == '..') {
      throw const CertificateRequestException(
        'Selecione uma matrícula ou solicitação válida.',
        statusCode: 422,
      );
    }
  }

  void _requireRevision(int revision) {
    if (revision < 1) {
      throw const CertificateRequestException(
        'Atualize a solicitação antes de continuar.',
        statusCode: 422,
      );
    }
  }

  String _statusMessage(int status) => switch (status) {
    401 => 'Sua sessão expirou. Entre novamente.',
    403 => 'Você não tem permissão para acessar ou revisar esta solicitação.',
    404 => 'Solicitação não encontrada. Atualize a lista.',
    409 =>
      'Esta solicitação mudou ou a ação não está disponível. Recarregue antes de continuar.',
    422 => 'Confira a matrícula, a versão do curso e os dados da solicitação.',
    503 =>
      'O serviço de solicitações está temporariamente indisponível. Tente novamente mais tarde.',
    _ =>
      'Não foi possível confirmar a operação. Atualize a lista para conferir o resultado.',
  };

  void dispose() => _client.close();
}
