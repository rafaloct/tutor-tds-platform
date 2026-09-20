import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'learning_event.dart';

class LearningEventQueue {
  const LearningEventQueue({this.maxPending = 500}) : assert(maxPending > 0);

  static const _storageKey = 'learning_events:pending:v1';
  static Future<void> _operationTail = Future<void>.value();

  final int maxPending;

  Future<bool> enqueue(LearningEvent event) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = _decode(prefs.getString(_storageKey));
      if (events.any((item) => item.eventId == event.eventId)) return false;
      if (events.length >= maxPending) {
        final oldestTelemetry = events.indexWhere((item) => item.isTelemetry);
        if (event.isTelemetry && oldestTelemetry < 0) return false;
        events.removeAt(oldestTelemetry >= 0 ? oldestTelemetry : 0);
      }
      events.add(event);
      await prefs.setString(
        _storageKey,
        jsonEncode(events.map((item) => item.toJson()).toList()),
      );
      return true;
    } finally {
      turn.complete();
    }
  }

  Future<List<LearningEvent>> pending() async {
    final previous = _operationTail;
    await previous;
    final prefs = await SharedPreferences.getInstance();
    return List.unmodifiable(_decode(prefs.getString(_storageKey)));
  }

  Future<bool> removeById(String eventId) async {
    final previous = _operationTail;
    final turn = Completer<void>();
    _operationTail = turn.future;
    await previous;
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = _decode(prefs.getString(_storageKey));
      final originalLength = events.length;
      events.removeWhere((event) => event.eventId == eventId);
      if (events.length == originalLength) return false;
      await prefs.setString(
        _storageKey,
        jsonEncode(events.map((event) => event.toJson()).toList()),
      );
      return true;
    } finally {
      turn.complete();
    }
  }

  List<LearningEvent> _decode(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List<dynamic>) return [];
      return decoded
          .map(LearningEvent.fromJson)
          .whereType<LearningEvent>()
          .toList();
    } on FormatException {
      return [];
    }
  }
}
