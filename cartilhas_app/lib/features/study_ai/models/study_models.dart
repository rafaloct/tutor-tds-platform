import 'dart:convert';

import 'package:flutter/foundation.dart';

enum StudyDifficulty { basic, intermediate, advanced }

extension StudyDifficultyLabel on StudyDifficulty {
  String get apiValue => name;

  String get label => switch (this) {
    StudyDifficulty.basic => 'Essencial',
    StudyDifficulty.intermediate => 'Intermediário',
    StudyDifficulty.advanced => 'Desafio',
  };
}

enum SummaryLength { quick, detailed }

extension SummaryLengthLabel on SummaryLength {
  String get apiValue => name;

  String get label => switch (this) {
    SummaryLength.quick => 'Resumo rápido',
    SummaryLength.detailed => 'Guia detalhado',
  };
}

@immutable
class StudyFlashcard {
  const StudyFlashcard({
    required this.front,
    required this.back,
    this.hint = '',
  });

  final String front;
  final String back;
  final String hint;

  factory StudyFlashcard.fromJson(Map<String, dynamic> json) => StudyFlashcard(
    front: json['front'] as String? ?? '',
    back: json['back'] as String? ?? '',
    hint: json['hint'] as String? ?? '',
  );
}

@immutable
class FlashcardDeck {
  FlashcardDeck({required this.title, required List<StudyFlashcard> items})
    : items = List.unmodifiable(items);

  final String title;
  final List<StudyFlashcard> items;

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
    title: json['title'] as String? ?? 'Cartões de estudo',
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudyFlashcard.fromJson)
        .toList(),
  );
}

@immutable
class StudyQuestion {
  StudyQuestion({
    required this.question,
    required List<String> options,
    required this.correctIndex,
    required this.explanation,
    required this.topic,
  }) : options = List.unmodifiable(options);

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String topic;

  factory StudyQuestion.fromJson(Map<String, dynamic> json) => StudyQuestion(
    question: json['question'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    correctIndex: json['correctIndex'] as int? ?? 0,
    explanation: json['explanation'] as String? ?? '',
    topic: json['topic'] as String? ?? 'Conteúdo da cartilha',
  );
}

@immutable
class AssessmentDeck {
  AssessmentDeck({
    required this.title,
    required this.durationMinutes,
    required List<StudyQuestion> items,
  }) : items = List.unmodifiable(items);

  final String title;
  final int durationMinutes;
  final List<StudyQuestion> items;

  factory AssessmentDeck.fromJson(Map<String, dynamic> json) => AssessmentDeck(
    title: json['title'] as String? ?? 'Atividade',
    durationMinutes: json['durationMinutes'] as int? ?? 30,
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudyQuestion.fromJson)
        .toList(),
  );
}

@immutable
class StudySummary {
  StudySummary({
    required this.title,
    required this.overview,
    required List<String> keyPoints,
    required List<String> practicalExamples,
    required List<String> reviewQuestions,
  }) : keyPoints = List.unmodifiable(keyPoints),
       practicalExamples = List.unmodifiable(practicalExamples),
       reviewQuestions = List.unmodifiable(reviewQuestions);

  final String title;
  final String overview;
  final List<String> keyPoints;
  final List<String> practicalExamples;
  final List<String> reviewQuestions;

  factory StudySummary.fromJson(Map<String, dynamic> json) => StudySummary(
    title: json['title'] as String? ?? 'Resumo',
    overview: json['overview'] as String? ?? '',
    keyPoints: _stringList(json['keyPoints']),
    practicalExamples: _stringList(json['practicalExamples']),
    reviewQuestions: _stringList(json['reviewQuestions']),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'overview': overview,
    'keyPoints': keyPoints,
    'practicalExamples': practicalExamples,
    'reviewQuestions': reviewQuestions,
  };

  static List<String> _stringList(Object? value) =>
      (value as List<dynamic>? ?? const []).whereType<String>().toList();
}

@immutable
class SavedStudySummary {
  const SavedStudySummary({
    required this.courseId,
    required this.topic,
    required this.length,
    required this.summary,
    required this.createdAt,
  });

  final String courseId;
  final String topic;
  final SummaryLength length;
  final StudySummary summary;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'topic': topic,
    'length': length.name,
    'summary': summary.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static SavedStudySummary? tryParse(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final dynamic json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return null;
      final courseId = json['courseId'] as String? ?? '';
      final topic = json['topic'] as String? ?? courseId;
      final lengthName = json['length'] as String?;
      final length = SummaryLength.values.firstWhere(
        (v) => v.name == lengthName,
        orElse: () => SummaryLength.quick,
      );
      final summaryJson = json['summary'];
      if (summaryJson is! Map<String, dynamic>) return null;
      final summary = StudySummary.fromJson(summaryJson);
      final createdAtRaw = json['createdAt'] as String?;
      final createdAt = createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw)
          : null;
      if (createdAt == null || (courseId.isEmpty && topic.isEmpty)) {
        return null;
      }
      return SavedStudySummary(
        courseId: courseId.isNotEmpty ? courseId : topic,
        topic: topic.isNotEmpty ? topic : courseId,
        length: length,
        summary: summary,
        createdAt: createdAt.isUtc ? createdAt.toLocal() : createdAt,
      );
    } catch (_) {
      return null;
    }
  }
}
