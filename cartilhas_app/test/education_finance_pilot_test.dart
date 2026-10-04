import 'dart:convert';

import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('educação financeira mantém 5 avaliações e adiciona experiências', () async {
    final raw = await rootBundle.loadString(
      'assets/data/lessons/educacao-financeira.json',
    );
    final course = Cartilha.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final messages = course.sections.expand((section) => section.messages).toList();
    final assessment = messages.where((message) => message.isAssessmentQuestion);
    final exploratory = messages.where(
      (message) => const {
        'scenario',
        'reveal',
        'reflection',
        'action_challenge',
      }.contains(message.type),
    );

    expect(assessment.length, 5);
    expect(exploratory.length, greaterThanOrEqualTo(10));
    expect(messages.where((message) => message.type == 'scenario'), isNotEmpty);
    expect(messages.where((message) => message.type == 'reveal'), isNotEmpty);
    expect(messages.where((message) => message.type == 'reflection'), isNotEmpty);
    expect(
      messages.where((message) => message.type == 'action_challenge'),
      isNotEmpty,
    );

    for (final message in exploratory) {
      expect(message.isAssessmentQuestion, isFalse);
      expect(message.options, isNotEmpty);
    }
  });
}
