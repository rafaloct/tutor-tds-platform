import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StudyProgress {
  const StudyProgress({
    required this.courseId,
    required this.sectionIndex,
    required this.messageIndex,
    required this.questionsAnswered,
    required this.showOptions,
    required this.isCompleted,
    required this.updatedAt,
    this.courseVersionId,
    this.ownerId,
  });

  final String courseId;
  final int sectionIndex;
  final int messageIndex;
  final int questionsAnswered;
  final bool showOptions;
  final bool isCompleted;
  final DateTime updatedAt;
  final String? courseVersionId;
  final String? ownerId;

  Map<String, Object> toJson() => {
    'courseId': courseId,
    'sectionIndex': sectionIndex,
    'messageIndex': messageIndex,
    'questionsAnswered': questionsAnswered,
    'showOptions': showOptions,
    'isCompleted': isCompleted,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'courseVersionId': ?courseVersionId,
    'ownerId': ?ownerId,
  };

  static StudyProgress? tryParse(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return null;
      final courseId = json['courseId'];
      final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
      if (courseId is! String || courseId.isEmpty || updatedAt == null) {
        return null;
      }
      return StudyProgress(
        courseId: courseId,
        sectionIndex: (json['sectionIndex'] as num?)?.toInt() ?? 0,
        messageIndex: (json['messageIndex'] as num?)?.toInt() ?? 0,
        questionsAnswered: (json['questionsAnswered'] as num?)?.toInt() ?? 0,
        showOptions: json['showOptions'] == true,
        isCompleted: json['isCompleted'] == true,
        updatedAt: updatedAt,
        courseVersionId: json['courseVersionId'] as String?,
        ownerId: json['ownerId'] as String?,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class StudyProgressRepository {
  static const _lastProgressKey = 'study_progress:last';

  const StudyProgressRepository();

  String _courseKey(String courseId, String? versionId, String? ownerId) =>
      versionId == null && ownerId == null
      ? 'study_progress:course:$courseId'
      : 'study_progress:version:${jsonEncode([courseId, versionId, ownerId])}';

  Future<StudyProgress?> load(
    String courseId, {
    String? courseVersionId,
    String? ownerId,
    bool allowLegacy = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = StudyProgress.tryParse(
      prefs.getString(_courseKey(courseId, courseVersionId, ownerId)),
    );
    if (current != null || !allowLegacy || ownerId != null) return current;
    return StudyProgress.tryParse(
      prefs.getString(_courseKey(courseId, null, null)),
    );
  }

  Future<StudyProgress?> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    return StudyProgress.tryParse(prefs.getString(_lastProgressKey));
  }

  Future<void> save(StudyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(progress.toJson());
    await Future.wait([
      prefs.setString(
        _courseKey(
          progress.courseId,
          progress.courseVersionId,
          progress.ownerId,
        ),
        encoded,
      ),
      if (progress.ownerId == null) prefs.setString(_lastProgressKey, encoded),
    ]);
  }
}
