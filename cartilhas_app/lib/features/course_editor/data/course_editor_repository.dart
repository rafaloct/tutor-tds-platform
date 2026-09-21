import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_repository.dart';
import '../models/course_editor_models.dart';

abstract interface class CourseEditorGateway {
  Future<List<EditorProgram>> programs();
  Future<List<EditableCourse>> courses(String programId);
  Future<EditableCourse> course(String courseId, {String? versionId});
  Future<EditableCourse> create({
    required String programId,
    required String courseId,
    required String title,
    required String author,
  });
  Future<EditableCourse> save(EditableCourse course);
  Future<EditableCourse> transition(EditableCourse course, String action);
  Future<EditableCourse> fork(EditableCourse course);
}

class CourseEditorException implements Exception {
  const CourseEditorException(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
  @override
  String toString() => message;
}

class CourseEditorRepository implements CourseEditorGateway {
  CourseEditorRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;

  @override
  Future<List<EditorProgram>> programs() async {
    final json = await _request('GET', '/editor/context');
    return (json['programs'] as List)
        .map((item) => EditorProgram.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<EditableCourse>> courses(String programId) async {
    final json = await _request(
      'GET',
      '/editor/courses?${Uri(queryParameters: {'program_id': programId}).query}',
    );
    return (json['courses'] as List)
        .map((item) => EditableCourse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EditableCourse> course(
    String courseId, {
    String? versionId,
  }) async => EditableCourse.fromJson(
    await _request(
      'GET',
      '/editor/courses/${Uri.encodeComponent(courseId)}${versionId == null ? '' : '?${Uri(queryParameters: {'version_id': versionId}).query}'}',
    ),
  );
  @override
  Future<EditableCourse> create({
    required String programId,
    required String courseId,
    required String title,
    required String author,
  }) async => EditableCourse.fromJson(
    await _request('POST', '/courses', {
      'program_id': programId,
      'course_id': courseId,
      'title': title,
      'author': author,
    }),
  );
  @override
  Future<EditableCourse> save(EditableCourse course) async =>
      EditableCourse.fromJson(
        await _request(
          'PATCH',
          '/courses/${Uri.encodeComponent(course.courseId)}',
          course.saveBody,
        ),
      );
  @override
  Future<EditableCourse> transition(
    EditableCourse course,
    String action,
  ) async {
    if (!{'submit', 'publish', 'archive'}.contains(action)) {
      throw ArgumentError.value(action);
    }
    final validation = course.releaseValidationError;
    if (action != 'archive' && validation != null) {
      throw CourseEditorException(validation);
    }
    return EditableCourse.fromJson(
      await _request(
        'POST',
        '/courses/${Uri.encodeComponent(course.courseId)}/$action',
        course.revisionBody,
      ),
    );
  }

  @override
  Future<EditableCourse> fork(EditableCourse course) async =>
      EditableCourse.fromJson(
        await _request(
          'POST',
          '/courses/${Uri.encodeComponent(course.courseId)}/versions',
          {'source_version_id': course.versionId},
        ),
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final base = apiUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base$path');
      final response = await authRepository.authorized((token) {
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        return switch (method) {
          'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
          'PATCH' => _client.patch(
            uri,
            headers: headers,
            body: jsonEncode(body),
          ),
          _ => _client.get(uri, headers: headers),
        }.timeout(const Duration(seconds: 15));
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CourseEditorException(switch (response.statusCode) {
          403 => 'Você não tem permissão para esta ação neste programa.',
          404 => 'Conteúdo indisponível. Atualize a lista.',
          409 =>
            'Este conteúdo mudou ou a ação não é mais permitida. Recarregue a versão antes de continuar.',
          422 =>
            'Confira o título, os módulos e as alternativas antes de continuar.',
          _ =>
            'Não foi possível confirmar a operação. Recarregue para conferir o estado atual.',
        }, conflict: response.statusCode == 409);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on CourseEditorException {
      rethrow;
    } on AuthException catch (e) {
      throw CourseEditorException(e.message);
    } on Object {
      throw const CourseEditorException(
        'Não foi possível conectar ao editor. Suas alterações continuam nesta tela.',
      );
    }
  }

  void dispose() => _client.close();
}
