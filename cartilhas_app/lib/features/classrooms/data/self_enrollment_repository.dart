import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../../learning_context/learning_context.dart';
import '../../learning_context/learning_context_repository.dart';
import '../models/classroom_models.dart';

/// Spontaneous enrollment into a course's open class.
///
/// Online-only by contract: enrollment is a server authorization grant and is
/// never queued locally. The returned learning context must still be resolved
/// again through [LearningContextRepository] so the offline snapshot is stored
/// by its single writer.
abstract interface class SelfEnrollmentGateway {
  Future<LearningContextSnapshot> selfEnroll(String courseId);
  Future<List<OpenClassItem>> openClasses();
}

class RemoteSelfEnrollmentRepository implements SelfEnrollmentGateway {
  RemoteSelfEnrollmentRepository({
    required this.apiUrl,
    required this.auth,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository auth;
  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${apiUrl.replaceFirst(RegExp(r'/+$'), '')}$path');

  Future<String> _owner() async {
    final owner = await auth.localUserId();
    if (owner == null) {
      throw const LearningContextException(
        'Entre na sua conta para criar a matrícula.',
        statusCode: 401,
      );
    }
    return owner;
  }

  Future<void> _checkOwner(String owner) async {
    if (await auth.localUserId() != owner) {
      throw const LearningContextException(
        'A conta mudou. Reabra suas turmas.',
        statusCode: 401,
      );
    }
  }

  Map<String, dynamic> _object(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Objeto JSON esperado.');
    }
    return decoded;
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on Object {
      // Mensagem segura abaixo quando a API não devolve JSON.
    }
    return switch (response.statusCode) {
      401 => 'Entre novamente para criar sua matrícula.',
      404 => 'Auto-matrícula indisponível para este curso.',
      409 => 'Sua matrícula precisa ser revisada pela equipe.',
      _ => 'Não foi possível criar sua matrícula agora.',
    };
  }

  @override
  Future<LearningContextSnapshot> selfEnroll(String courseId) async {
    final owner = await _owner();
    final http.Response response;
    try {
      response = await auth.authorized((token) async {
        await _checkOwner(owner);
        return _client
            .post(
              _uri('/courses/${Uri.encodeComponent(courseId)}/self-enroll'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
      });
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const LearningContextException('Sem resposta da conexão.');
    } on http.ClientException {
      throw const LearningContextException('Sem conexão com o servidor.');
    }
    await _checkOwner(owner);
    if (response.statusCode != 200) {
      throw LearningContextException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final LearningContextSnapshot snapshot;
    try {
      snapshot = LearningContextSnapshot.fromJson(_object(response.body));
    } on FormatException {
      throw const LearningContextException(
        'A resposta da matrícula está incompleta.',
      );
    } on TypeError {
      throw const LearningContextException(
        'A resposta da matrícula está incompleta.',
      );
    }
    if (snapshot.context.userId != owner ||
        snapshot.context.courseId != courseId ||
        !snapshot.context.permissions.contains('content.read')) {
      throw const LearningContextException(
        'O contexto da matrícula precisa ser atualizado.',
      );
    }
    await _checkOwner(owner);
    return snapshot;
  }

  @override
  Future<List<OpenClassItem>> openClasses() async {
    final owner = await _owner();
    final http.Response response;
    try {
      response = await auth.authorized((token) async {
        await _checkOwner(owner);
        return _client
            .get(
              _uri('/open-classes'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
      });
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const LearningContextException('Sem resposta da conexão.');
    } on http.ClientException {
      throw const LearningContextException('Sem conexão com o servidor.');
    }
    await _checkOwner(owner);
    if (response.statusCode == 404) {
      // Flag desligada no servidor: catálogo aberto fica simplesmente oculto.
      return const [];
    }
    if (response.statusCode != 200) {
      throw LearningContextException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final payload = _object(response.body);
    final rawClasses = payload['classes'];
    if (rawClasses is! List<dynamic>) {
      throw const LearningContextException(
        'A lista de turmas abertas retornada é inválida.',
      );
    }
    try {
      return rawClasses
          .whereType<Map<String, dynamic>>()
          .map(OpenClassItem.fromJson)
          .toList(growable: false);
    } on FormatException {
      throw const LearningContextException(
        'A lista de turmas abertas retornada é inválida.',
      );
    }
  }

  void dispose() => _client.close();
}
