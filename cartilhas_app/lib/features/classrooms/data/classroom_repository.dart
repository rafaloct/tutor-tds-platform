import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../../auth/models/auth_session.dart';
import '../models/classroom_models.dart';

abstract interface class ClassroomGateway {
  Future<AuthUser> currentUser();
  Future<List<ClassroomDetails>> classrooms();
  Future<ClassroomDetails> classroom(String classId);
  Future<ClassroomDashboard> dashboard(String classId);
  Future<UsageSummary> usage(String classId, {int days = 30});
  Future<StudentHours> studentHours({
    required ClassroomDetails classroom,
    required String userId,
  });
}

class ClassroomException implements Exception {
  const ClassroomException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ClassroomRepository implements ClassroomGateway {
  ClassroomRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;

  @override
  Future<AuthUser> currentUser() => authRepository.currentUser();

  @override
  Future<List<ClassroomDetails>> classrooms() async {
    final response = await _authorizedGet('/classes');
    final payload = _object(response.body);
    final rawClasses = payload['classes'];
    if (rawClasses is! List<dynamic>) {
      throw const ClassroomException('A lista de turmas retornada é inválida.');
    }
    return rawClasses
        .whereType<Map<String, dynamic>>()
        .map(ClassroomDetails.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ClassroomDetails> classroom(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) {
      throw const ClassroomException('Informe o código da turma.');
    }
    final response = await _authorizedGet(
      '/classes/${Uri.encodeComponent(id)}',
    );
    return ClassroomDetails.fromJson(_object(response.body));
  }

  @override
  Future<ClassroomDashboard> dashboard(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) throw const ClassroomException('Selecione uma turma.');
    final response = await _authorizedGet(
      '/classes/${Uri.encodeComponent(id)}/dashboard',
    );
    return ClassroomDashboard.fromJson(_object(response.body));
  }

  @override
  Future<UsageSummary> usage(String classId, {int days = 30}) async {
    final query = Uri(
      queryParameters: {
        'class_id': classId,
        'days': days.clamp(1, 90).toString(),
      },
    ).query;
    final response = await _authorizedGet('/analytics/usage?$query');
    return UsageSummary.fromJson(_object(response.body));
  }

  @override
  Future<StudentHours> studentHours({
    required ClassroomDetails classroom,
    required String userId,
  }) async {
    final query = Uri(
      queryParameters: {
        'course_id': classroom.courseId,
        'program_id': classroom.programId,
      },
    ).query;
    final response = await _authorizedGet(
      '/users/${Uri.encodeComponent(userId)}/hours?$query',
    );
    return StudentHours.fromJson(_object(response.body));
  }

  Future<http.Response> _authorizedGet(String path) async {
    try {
      final response = await authRepository.authorized(
        (token) => _client
            .get(_uri(path), headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClassroomException(_errorMessage(response));
      }
      return response;
    } on ClassroomException {
      rethrow;
    } on AuthException catch (error) {
      throw ClassroomException(error.message);
    } on FormatException {
      throw const ClassroomException('A API retornou dados inválidos.');
    } on Object {
      throw const ClassroomException(
        'Não foi possível consultar a turma agora. Tente novamente.',
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
      // Usa a mensagem segura abaixo quando a API não devolve JSON.
    }
    return switch (response.statusCode) {
      403 => 'Você não possui acesso a esta turma.',
      404 => 'Turma não encontrada.',
      _ => 'Não foi possível consultar a turma agora.',
    };
  }

  Uri _uri(String path) {
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return Uri.parse('$base$path');
  }

  void dispose() => _client.close();
}
