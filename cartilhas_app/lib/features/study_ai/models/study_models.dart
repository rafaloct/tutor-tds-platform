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

enum AssessmentMode { quiz, exam }

extension AssessmentModeLabel on AssessmentMode {
  String get label => switch (this) {
    AssessmentMode.quiz => 'Quiz',
    AssessmentMode.exam => 'Simulado',
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

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'topic': topic,
  };
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

  Map<String, dynamic> toJson() => {
    'title': title,
    'durationMinutes': durationMinutes,
    'items': items.map((item) => item.toJson()).toList(),
  };
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

@immutable
class AssessmentAttempt {
  AssessmentAttempt({
    required this.id,
    required this.courseId,
    required this.topic,
    required this.mode,
    required this.difficulty,
    required this.totalQuestions,
    required this.deck,
    required Map<int, int> answers,
    required this.currentIndex,
    required this.remainingSeconds,
    required this.score,
    required List<String> weakTopics,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  }) : answers = Map.unmodifiable(answers),
       weakTopics = List.unmodifiable(weakTopics);

  final String id;
  final String courseId;
  final String topic;
  final AssessmentMode mode;
  final StudyDifficulty difficulty;
  final int totalQuestions;
  final AssessmentDeck deck;
  final Map<int, int> answers;
  final int currentIndex;
  final int remainingSeconds;
  final int score;
  final List<String> weakTopics;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssessmentAttempt copyWith({
    Map<int, int>? answers,
    int? currentIndex,
    int? remainingSeconds,
    int? score,
    List<String>? weakTopics,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return AssessmentAttempt(
      id: id,
      courseId: courseId,
      topic: topic,
      mode: mode,
      difficulty: difficulty,
      totalQuestions: totalQuestions,
      deck: deck,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      score: score ?? this.score,
      weakTopics: weakTopics ?? this.weakTopics,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'topic': topic,
    'mode': mode.name,
    'difficulty': difficulty.name,
    'totalQuestions': totalQuestions,
    'deck': deck.toJson(),
    'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
    'currentIndex': currentIndex,
    'remainingSeconds': remainingSeconds,
    'score': score,
    'weakTopics': weakTopics,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static AssessmentAttempt? tryParse(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final dynamic json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return null;
      final id = json['id'] as String? ?? '';
      final courseId = json['courseId'] as String? ?? '';
      final topic = json['topic'] as String? ?? courseId;
      final modeName = json['mode'] as String?;
      final mode = AssessmentMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => AssessmentMode.quiz,
      );
      final diffName = json['difficulty'] as String?;
      final difficulty = StudyDifficulty.values.firstWhere(
        (d) => d.name == diffName,
        orElse: () => StudyDifficulty.intermediate,
      );
      final totalQuestions = (json['totalQuestions'] as num?)?.toInt() ?? 0;
      final deckJson = json['deck'];
      if (deckJson is! Map<String, dynamic>) return null;
      final deck = AssessmentDeck.fromJson(deckJson);

      final rawAnswers = json['answers'];
      final answers = <int, int>{};
      if (rawAnswers is Map) {
        for (final entry in rawAnswers.entries) {
          final key = int.tryParse(entry.key.toString());
          final value = (entry.value as num?)?.toInt();
          if (key != null && value != null) {
            answers[key] = value;
          }
        }
      }

      final currentIndex = (json['currentIndex'] as num?)?.toInt() ?? 0;
      final remainingSeconds = (json['remainingSeconds'] as num?)?.toInt() ?? 0;
      final score = (json['score'] as num?)?.toInt() ?? 0;
      final weakTopics = (json['weakTopics'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      final isCompleted = json['isCompleted'] == true;
      final createdAtRaw = json['createdAt'] as String?;
      final updatedAtRaw = json['updatedAt'] as String?;
      final createdAt = createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw)
          : null;
      final updatedAt = updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw)
          : null;

      if ((courseId.isEmpty && topic.isEmpty) ||
          createdAt == null ||
          updatedAt == null) {
        return null;
      }

      return AssessmentAttempt(
        id: id.isNotEmpty
            ? id
            : '${courseId}_${mode.name}_${createdAt.millisecondsSinceEpoch}',
        courseId: courseId.isNotEmpty ? courseId : topic,
        topic: topic.isNotEmpty ? topic : courseId,
        mode: mode,
        difficulty: difficulty,
        totalQuestions: totalQuestions > 0 ? totalQuestions : deck.items.length,
        deck: deck,
        answers: answers,
        currentIndex: currentIndex,
        remainingSeconds: remainingSeconds,
        score: score,
        weakTopics: weakTopics,
        isCompleted: isCompleted,
        createdAt: createdAt.isUtc ? createdAt.toLocal() : createdAt,
        updatedAt: updatedAt.isUtc ? updatedAt.toLocal() : updatedAt,
      );
    } catch (_) {
      return null;
    }
  }
}
