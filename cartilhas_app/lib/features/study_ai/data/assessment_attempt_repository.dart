import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_models.dart';

abstract interface class PublishedAssessmentAttemptStore {
  Future<AssessmentAttempt?> loadPublished(PublishedAssessmentContext context);
  Future<void> saveConfirmed(AssessmentAttempt attempt);
}

class AssessmentAttemptRepository implements PublishedAssessmentAttemptStore {
  static const _lastAttemptKey = 'study_assessment:last';

  const AssessmentAttemptRepository();

  String _courseModeKey(String courseId, AssessmentMode mode) =>
      'study_assessment:course:$courseId:${mode.name}';

  String _publishedKey(PublishedAssessmentContext context) =>
      'study_assessment:context:${context.storageDiscriminator}';

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

  @override
  Future<AssessmentAttempt?> loadPublished(
    PublishedAssessmentContext context,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attempt = AssessmentAttempt.tryParse(
        prefs.getString(_publishedKey(context)),
      );
      return attempt?.origin == AssessmentOrigin.publishedBlock &&
              attempt?.publishedContext?.sameAs(context) == true
          ? attempt
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> save(AssessmentAttempt attempt) async {
    try {
      await _save(attempt);
    } catch (_) {
      // Ignora falhas de escrita locais com segurança
    }
  }

  @override
  Future<void> saveConfirmed(AssessmentAttempt attempt) => _save(attempt);

  Future<void> _save(AssessmentAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(attempt.toJson());
    if (attempt.origin == AssessmentOrigin.publishedBlock) {
      final context = attempt.publishedContext;
      if (context == null) {
        throw StateError('Tentativa publicada sem contexto local.');
      }
      final stored = await prefs.setString(_publishedKey(context), encoded);
      if (!stored) throw StateError('Não foi possível salvar a tentativa.');
      return;
    }
    final stored = await Future.wait([
      prefs.setString(_courseModeKey(attempt.courseId, attempt.mode), encoded),
      prefs.setString(_lastAttemptKey, encoded),
    ]);
    if (stored.any((value) => !value)) {
      throw StateError('Não foi possível salvar a tentativa.');
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
