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
  });

  final String courseId;
  final int sectionIndex;
  final int messageIndex;
  final int questionsAnswered;
  final bool showOptions;
  final bool isCompleted;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'courseId': courseId,
    'sectionIndex': sectionIndex,
    'messageIndex': messageIndex,
    'questionsAnswered': questionsAnswered,
    'showOptions': showOptions,
    'isCompleted': isCompleted,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
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

  String _courseKey(String courseId) => 'study_progress:course:$courseId';

  Future<StudyProgress?> load(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    return StudyProgress.tryParse(prefs.getString(_courseKey(courseId)));
  }

  Future<StudyProgress?> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    return StudyProgress.tryParse(prefs.getString(_lastProgressKey));
  }

  Future<void> save(StudyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(progress.toJson());
    await Future.wait([
      prefs.setString(_courseKey(progress.courseId), encoded),
      prefs.setString(_lastProgressKey, encoded),
    ]);
  }
}
