import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/cartilha.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/auth_session.dart';
import '../models/classroom_models.dart';
import 'classroom_repository.dart';

/// Only previously authorized learner content. Never staff rosters or public fallback.
class LearnerOfflineRepository implements LearnerClassroomGateway {
  LearnerOfflineRepository({
    required this.remote,
    required this.auth,
    required String apiUrl,
    DateTime Function()? clock,
  }) : _scope = sha256
           .convert(utf8.encode(apiUrl.replaceFirst(RegExp(r'/+$'), '')))
           .toString(),
       _clock = clock ?? DateTime.now;

  static const maxAge = Duration(days: 7);
  final LearnerClassroomGateway remote;
  final AuthRepository auth;
  final String _scope;
  final DateTime Function() _clock;
  String? _owner;
  bool usingSavedData = false;
  DateTime? savedAt;

  String _key(String owner) =>
      'classroom_private:v1:$_scope:${Uri.encodeComponent(owner)}';

  Future<String> _requireOwner() async {
    final current = await auth.localUserId();
    if (current == null || current != _owner) {
      throw const ClassroomException(
        'A conta mudou. Entre novamente para abrir suas turmas.',
      );
    }
    return current;
  }

  bool _fresh(String? timestamp) {
    final saved = DateTime.tryParse(timestamp ?? '');
    if (saved == null) return false;
    final age = _clock().toUtc().difference(saved.toUtc());
    return !age.isNegative && age < maxAge;
  }

  Future<Map<String, dynamic>?> _read() async {
    final owner = await _requireOwner();
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_key(owner));
      if (source == null) return null;
      final data = jsonDecode(source) as Map<String, dynamic>;
      if (data['owner'] != owner ||
          data['scope'] != _scope ||
          !_fresh(data['verified_at'] as String?) ||
          data['classes'] is! List ||
          data['courses'] is! Map) {
        return null;
      }
      await _requireOwner();
      return data;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final owner = await _requireOwner();
    final prefs = await SharedPreferences.getInstance();
    await _requireOwner();
    await prefs.setString(_key(owner), jsonEncode(data));
  }

  Future<void> _forget() async {
    // Invalidating a prior grant must still work after auth clears expired tokens.
    final owner = _owner;
    if (owner != null) {
      await (await SharedPreferences.getInstance()).remove(_key(owner));
    }
  }

  @override
  Future<AuthUser> currentUser() async {
    usingSavedData = false;
    final localOwner = await auth.localUserId();
    if (localOwner == null) {
      throw const ClassroomException(
        'Entre na sua conta para abrir suas turmas.',
      );
    }
    // An instance belongs to one account even while requests are in flight.
    _owner ??= localOwner;
    if (_owner != localOwner) {
      throw const ClassroomException('A conta mudou. Reabra a tela de turmas.');
    }
    try {
      final user = await remote.currentUser();
      await _requireOwner();
      if (user.id != _owner) {
        throw const ClassroomException(
          'A conta mudou. Consulte suas turmas novamente.',
        );
      }
      return user;
    } on AuthException catch (error) {
      if (!error.allowOfflineFallback) {
        // Tokens may already have been cleared by an expired/revoked session.
        final owner = _owner;
        if (owner != null) {
          await (await SharedPreferences.getInstance()).remove(_key(owner));
        }
        rethrow;
      }
      final data = await _read();
      if (data == null) rethrow;
      usingSavedData = true;
      savedAt = DateTime.parse(data['verified_at'] as String);
      // No cached name/role; this identity is only used for learner progress.
      return AuthUser(id: _owner!, name: 'Aluno', role: 'student');
    }
  }

  Map<String, dynamic> _classJson(ClassroomDetails row) => {
    'id': row.id, 'program_id': row.programId, 'course_id': row.courseId,
    'course_version_id': row.courseVersionId, 'name': row.name,
    'start_date': row.startDate.toIso8601String(),
    'end_date': row.endDate.toIso8601String(),
    'status': row.status,
    // Required DTO field; no teacher or other learner identity is cached.
    'teacher_id': 'not-cached',
  };

  List<ClassroomDetails> _classes(Map<String, dynamic> data) =>
      (data['classes'] as List)
          .map(
            (row) => ClassroomDetails.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

  bool _savedMatches(Object? value, ClassroomDetails row) {
    try {
      if (value is! Map || !_fresh(value['verified_at'] as String?)) {
        return false;
      }
      return _matches(
        Cartilha.fromJson(Map<String, dynamic>.from(value['content'] as Map)),
        row,
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async {
    await _requireOwner();
    try {
      // currentUser already established transport outage, so do not wait twice.
      if (usingSavedData) return _classes((await _read())!);
      final classes = await remote.learnerClassrooms();
      await _requireOwner();
      final previous = await _read();
      final courses = Map<String, dynamic>.from(
        previous?['courses'] as Map? ?? {},
      );
      courses.removeWhere(
        (id, value) =>
            !classes.any((row) => row.id == id && _savedMatches(value, row)),
      );
      final timestamp = _clock().toUtc().toIso8601String();
      await _write({
        'owner': _owner,
        'scope': _scope,
        'verified_at': timestamp,
        'classes': classes.map(_classJson).toList(),
        'courses': courses,
      });
      savedAt = DateTime.parse(timestamp);
      return classes;
    } on ClassroomException catch (error) {
      if (!error.allowOfflineFallback) {
        await _forget();
        rethrow;
      }
      final data = await _read();
      if (data == null) rethrow;
      usingSavedData = true;
      savedAt = DateTime.parse(data['verified_at'] as String);
      return _classes(data);
    }
  }

  bool _matches(Cartilha course, ClassroomDetails row) =>
      course.id == row.courseId &&
      course.classId == row.id &&
      course.courseVersionId != null &&
      course.courseVersionId == row.courseVersionId &&
      !course.legacyProgressCompatible &&
      course.sections.isNotEmpty &&
      course.sections.every((section) => section.messages.isNotEmpty);

  @override
  Future<Cartilha> course(String classId) async {
    final data = await _read();
    final rows = data == null
        ? <ClassroomDetails>[]
        : _classes(data).where((row) => row.id == classId).toList();
    if (data == null || rows.length != 1) {
      throw const ClassroomException(
        'Atualize suas turmas com internet antes de abrir este conteúdo.',
      );
    }
    final row = rows.single;
    try {
      // Always try online: membership may have been revoked since list download.
      final course = await remote.course(classId);
      await _requireOwner();
      if (!_matches(course, row)) {
        throw const ClassroomException(
          'A edição da turma mudou. Atualize suas turmas antes de continuar.',
        );
      }
      (data['courses'] as Map)[classId] = {
        'verified_at': _clock().toUtc().toIso8601String(),
        'content': course.toJson(),
      };
      await _write(data);
      usingSavedData = false;
      return course;
    } on ClassroomException catch (error) {
      if (!error.allowOfflineFallback) {
        // Auth refresh may have cleared the session without an HTTP response
        // reaching this layer. Never leave that old grant usable on next login.
        await _forget();
        rethrow;
      }
      await _requireOwner();
      try {
        final saved = (data['courses'] as Map)[classId] as Map?;
        if (saved == null || !_fresh(saved['verified_at'] as String?)) {
          throw const FormatException();
        }
        final course = Cartilha.fromJson(
          Map<String, dynamic>.from(saved['content'] as Map),
        );
        if (!_matches(course, row)) throw const FormatException();
        usingSavedData = true;
        savedAt = DateTime.parse(saved['verified_at'] as String);
        return course;
      } on Object {
        throw const ClassroomException(
          'Abra este conteúdo com internet uma vez para salvá-lo. Cópias vencidas precisam ser atualizadas.',
        );
      }
    }
  }
}
