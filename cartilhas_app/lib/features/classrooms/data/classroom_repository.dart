import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../../auth/models/auth_session.dart';
import '../models/classroom_models.dart';
import '../../../models/cartilha.dart';

abstract interface class LearnerClassroomGateway {
  Future<AuthUser> currentUser();
  Future<List<ClassroomDetails>> learnerClassrooms();
  Future<Cartilha> course(String classId);
}

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

abstract interface class ClassroomRosterGateway {
  Future<EligibleStudentPage> eligibleStudents(
    String classId, {
    String query = '',
    int offset = 0,
  });
  Future<void> includeStudent(String classId, String userId);
}

class ClassroomException implements Exception {
  const ClassroomException(
    this.message, {
    this.statusCode,
    this.allowOfflineFallback = false,
  });
  final String message;
  final int? statusCode;
  final bool allowOfflineFallback;

  @override
  String toString() => message;
}

class ClassroomRepository
    implements
        ClassroomGateway,
        ClassroomRosterGateway,
        LearnerClassroomGateway {
  ClassroomRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;
  String? _followupOwner;

  Future<List<Map<String, dynamic>>> studentMentors(
    String classId,
    String userId,
  ) async {
    final result = await _followup(
      '/classes/${Uri.encodeComponent(classId)}/students/${Uri.encodeComponent(userId)}/mentors',
    );
    return (result['mentors'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> studentBaseline(
    String classId,
    String userId,
  ) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/students/${Uri.encodeComponent(userId)}/baseline',
  );

  Future<Map<String, dynamic>> saveStudentBaseline({
    required String classId,
    required String userId,
    required String source,
    required String recordId,
    required String baselineDate,
    String? territoryId,
    required int expectedRevision,
    required String reason,
    required String idempotencyKey,
  }) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/students/${Uri.encodeComponent(userId)}/baseline',
    method: 'PUT',
    body: {
      'source': source.trim(),
      'record_id': recordId.trim(),
      'baseline_date': baselineDate,
      'territory_id': territoryId,
      'expected_revision': expectedRevision,
      'reason': reason.trim(),
      'idempotency_key': idempotencyKey,
    },
  );

  Future<Map<String, dynamic>> mentorshipCases(
    String classId,
    String userId, {
    int offset = 0,
  }) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/mentorship-cases?${Uri(queryParameters: {'user_id': userId, 'limit': '50', 'offset': '$offset'}).query}',
  );

  Future<Map<String, dynamic>> openMentorship({
    required String classId,
    required String userId,
    required String mentorId,
    required String objective,
    required String nextAction,
    required String reason,
    required String idempotencyKey,
  }) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/mentorship-cases',
    method: 'POST',
    body: {
      'user_id': userId,
      'mentor_id': mentorId,
      'objective': objective.trim(),
      'next_action': nextAction.trim(),
      'reason': reason.trim(),
      'idempotency_key': idempotencyKey,
    },
  );

  Future<Map<String, dynamic>> mentorshipCase(
    String classId,
    String caseId,
  ) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/mentorship-cases/${Uri.encodeComponent(caseId)}',
  );

  Future<Map<String, dynamic>> updateMentorship({
    required String classId,
    required String caseId,
    required int expectedRevision,
    required String mentorId,
    required String objective,
    required String nextAction,
    required String status,
    required String reason,
    required String idempotencyKey,
  }) => _followup(
    '/classes/${Uri.encodeComponent(classId)}/mentorship-cases/${Uri.encodeComponent(caseId)}',
    method: 'PATCH',
    body: {
      'expected_revision': expectedRevision,
      'mentor_id': mentorId,
      'objective': objective.trim(),
      'next_action': nextAction.trim(),
      'status': status,
      'reason': reason.trim(),
      'idempotency_key': idempotencyKey,
    },
  );

  // Sensitive follow-up data stays online and bound to the opening account.
  Future<Map<String, dynamic>> _followup(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final owner = await authRepository.localUserId();
    if (owner == null || (_followupOwner != null && _followupOwner != owner)) {
      throw const ClassroomException(
        'A conta mudou. Reabra o acompanhamento.',
        statusCode: 401,
      );
    }
    _followupOwner ??= owner;
    final response = await _authorizedRequest(
      path,
      method: method,
      body: body,
      expectedOwner: owner,
    );
    return _object(response.body);
  }

  @override
  Future<AuthUser> currentUser() => authRepository.currentUser();

  @override
  Future<Cartilha> course(String classId) async {
    final response = await _authorizedGet(
      '/classes/${Uri.encodeComponent(classId)}/course',
    );
    final course = Cartilha.fromJson(_object(response.body));
    if (course.classId != classId ||
        course.courseVersionId == null ||
        course.sections.isEmpty ||
        course.sections.any((section) => section.messages.isEmpty)) {
      throw const ClassroomException(
        'O conteúdo desta turma precisa ser conferido pela equipe.',
      );
    }
    return course;
  }

  @override
  Future<List<ClassroomDetails>> classrooms() => _classList('/classes');

  @override
  Future<List<ClassroomDetails>> learnerClassrooms() =>
      _classList('/classes?enrolled_only=true');

  Future<List<ClassroomDetails>> _classList(String path) async {
    final response = await _authorizedGet(path);
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

  @override
  Future<EligibleStudentPage> eligibleStudents(
    String classId, {
    String query = '',
    int offset = 0,
  }) async {
    final parameters = Uri(
      queryParameters: {'q': query.trim(), 'offset': '$offset', 'limit': '20'},
    ).query;
    final response = await _authorizedGet(
      '/classes/${Uri.encodeComponent(classId)}/eligible-students?$parameters',
    );
    try {
      return EligibleStudentPage.fromJson(_object(response.body));
    } on FormatException {
      throw const ClassroomException(
        'Não foi possível carregar os estudantes. Tente novamente.',
      );
    }
  }

  @override
  Future<void> includeStudent(String classId, String userId) async {
    await _authorizedRequest(
      '/classes/${Uri.encodeComponent(classId)}/students/${Uri.encodeComponent(userId)}',
      put: true,
    );
  }

  Future<http.Response> _authorizedGet(String path) => _authorizedRequest(path);

  Future<http.Response> _authorizedRequest(
    String path, {
    bool put = false,
    String? method,
    Map<String, dynamic>? body,
    String? expectedOwner,
  }) async {
    try {
      final response = await authRepository.authorized((token) async {
        if (expectedOwner != null &&
            await authRepository.localUserId() != expectedOwner) {
          throw const ClassroomException(
            'A conta mudou. Reabra o acompanhamento.',
            statusCode: 401,
          );
        }
        if (method != null) {
          final request = http.Request(method, _uri(path));
          request.headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          });
          if (body != null) request.body = jsonEncode(body);
          return _client
              .send(request)
              .then(http.Response.fromStream)
              .timeout(const Duration(seconds: 12));
        }
        return (put
                ? _client.put(
                    _uri(path),
                    headers: {'Authorization': 'Bearer $token'},
                  )
                : _client.get(
                    _uri(path),
                    headers: {'Authorization': 'Bearer $token'},
                  ))
            .timeout(const Duration(seconds: 12));
      });
      if (expectedOwner != null &&
          await authRepository.localUserId() != expectedOwner) {
        throw const ClassroomException(
          'A conta mudou. Reabra o acompanhamento.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClassroomException(
          _errorMessage(response),
          statusCode: response.statusCode,
        );
      }
      return response;
    } on ClassroomException {
      rethrow;
    } on AuthException catch (error) {
      throw ClassroomException(
        error.message,
        allowOfflineFallback: error.allowOfflineFallback,
      );
    } on TimeoutException {
      throw const ClassroomException(
        'Sem resposta da conexão.',
        allowOfflineFallback: true,
      );
    } on http.ClientException {
      throw const ClassroomException(
        'Sem conexão com a turma.',
        allowOfflineFallback: true,
      );
    } on FormatException {
      throw const ClassroomException('A API retornou dados inválidos.');
    } on Object {
      throw ClassroomException(
        put
            ? 'Não foi possível confirmar a inclusão. Tente novamente; o estudante não será duplicado.'
            : 'Não foi possível consultar a turma agora. Tente novamente.',
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
