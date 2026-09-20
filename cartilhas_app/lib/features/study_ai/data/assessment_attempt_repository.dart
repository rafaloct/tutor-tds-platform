import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_models.dart';

class AssessmentAttemptRepository {
  static const _lastAttemptKey = 'study_assessment:last';

  const AssessmentAttemptRepository();

  String _courseModeKey(String courseId, AssessmentMode mode) =>
      'study_assessment:course:$courseId:${mode.name}';

  Future<AssessmentAttempt?> load(String courseId, AssessmentMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AssessmentAttempt.tryParse(
        prefs.getString(_courseModeKey(courseId, mode)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<AssessmentAttempt?> loadLast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AssessmentAttempt.tryParse(prefs.getString(_lastAttemptKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AssessmentAttempt attempt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(attempt.toJson());
      await Future.wait([
        prefs.setString(
          _courseModeKey(attempt.courseId, attempt.mode),
          encoded,
        ),
        prefs.setString(_lastAttemptKey, encoded),
      ]);
    } catch (_) {
      // Ignora falhas de escrita locais com segurança
    }
  }

  Future<void> clear(String courseId, AssessmentMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_courseModeKey(courseId, mode));
    } catch (_) {
      // Ignora falhas locais
    }
  }
}
