import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_models.dart';

class StudySummaryRepository {
  static const _lastSummaryKey = 'study_summary:last';

  const StudySummaryRepository();

  String _courseKey(String courseId) => 'study_summary:course:$courseId';

  Future<SavedStudySummary?> load(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SavedStudySummary.tryParse(prefs.getString(_courseKey(courseId)));
    } catch (_) {
      return null;
    }
  }

  Future<SavedStudySummary?> loadLast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SavedStudySummary.tryParse(prefs.getString(_lastSummaryKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedStudySummary item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(item.toJson());
      await Future.wait([
        prefs.setString(_courseKey(item.courseId), encoded),
        prefs.setString(_lastSummaryKey, encoded),
      ]);
    } catch (_) {
      // Ignora falhas de escrita locais com segurança
    }
  }

  Future<void> clear(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_courseKey(courseId));
    } catch (_) {
      // Ignora falhas locais
    }
  }
}
