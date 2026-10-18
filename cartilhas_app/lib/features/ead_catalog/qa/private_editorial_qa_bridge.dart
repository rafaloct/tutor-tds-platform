import 'package:flutter/foundation.dart';

/// Local QA-only transport through:
///   Android ADB reverse -> desktop localhost:18731
///   desktop SSH tunnel -> synthetic isolated WordPress on the VPS.
///
/// No public DNS, database or WordPress configuration is changed.
/// Never included as an available feature in profile/release builds.
class PrivateEditorialQaBridge {
  const PrivateEditorialQaBridge._();

  static const _isolated = bool.fromEnvironment(
    'DYNAMIC_QA_ISOLATED_PACKAGE',
    defaultValue: false,
  );
  static const _runId = String.fromEnvironment('DYNAMIC_QA_RUN_ID');
  static const _base = String.fromEnvironment('TDS_EDITORIAL_QA_HTTP_BASE');

  static const syntheticCourseId = 12;
  static const syntheticLessonId = 13;

  static bool get enabled =>
      kDebugMode &&
      _isolated &&
      RegExp(r'^[a-f0-9]{32}$').hasMatch(_runId) &&
      _base == 'http://127.0.0.1:18731';

  static Uri? curriculumUri(int courseId) {
    if (!enabled || courseId != syntheticCourseId) return null;
    return Uri.http('127.0.0.1:18731', '/', {
      'rest_route': '/tds-learning/v1/courses/$syntheticCourseId/curriculum',
    });
  }

  static Uri? lessonUri(int courseId, int lessonId) {
    if (!enabled ||
        courseId != syntheticCourseId ||
        lessonId != syntheticLessonId) {
      return null;
    }
    return Uri.http('127.0.0.1:18731', '/', {
      'rest_route':
          '/tds-learning/v1/courses/$syntheticCourseId/lessons/$syntheticLessonId',
    });
  }

  static Map<String, String> get headers =>
      enabled ? const {'Host': 'tds-learning-qa-wp-20261017'} : const {};

  static const marker = 'LABORATÓRIO INTERNO · DADOS FICTÍCIOS';
}
