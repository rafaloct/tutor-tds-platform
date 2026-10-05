enum TutorExperienceType {
  scenario('scenario'),
  reveal('reveal'),
  reflection('reflection'),
  actionChallenge('action_challenge');

  const TutorExperienceType(this.wireValue);

  final String wireValue;
}

class TutorLearningContext {
  const TutorLearningContext({
    required this.courseId,
    required this.courseVersionId,
    this.moduleId,
    this.experienceId,
    this.experienceType,
  });

  final String courseId;
  final String courseVersionId;
  final String? moduleId;
  final String? experienceId;
  final TutorExperienceType? experienceType;

  Map<String, String> toJson() {
    if (!_isStableId(courseId) || !_isStableId(courseVersionId)) {
      throw ArgumentError('Course and version IDs must be stable identifiers.');
    }
    if (moduleId != null && !_isStableId(moduleId!)) {
      throw ArgumentError.value(moduleId, 'moduleId');
    }
    if ((experienceId == null) != (experienceType == null)) {
      throw ArgumentError('Experience ID and type must be provided together.');
    }
    if (experienceId != null &&
        (moduleId == null || !_isStableId(experienceId!))) {
      throw ArgumentError(
        'An experience requires stable experience and module IDs.',
      );
    }

    return {
      'course_id': courseId,
      'course_version_id': courseVersionId,
      'module_id': ?moduleId,
      'experience_id': ?experienceId,
      'experience_type': ?experienceType?.wireValue,
    };
  }

  static bool _isStableId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);
}
