import 'dart:convert';

import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _assessmentCounts = <String, int>{
  'agricultura-sustentavel': 6,
  'atendimento-cliente': 4,
  'audiovisual': 4,
  'cooperativismo': 4,
  'economia-lar': 4,
  'educacao-financeira': 5,
  'ia-cartilha': 4,
  'saf': 3,
  'sim-sima': 4,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'nine lessons load, preserve assessments, and have a contextual experience',
    () async {
      final kinds = <ExperienceKind>{};
      for (final entry in _assessmentCounts.entries) {
        final json = await rootBundle.loadString(
          'assets/data/lessons/${entry.key}.json',
        );
        final lesson = Cartilha.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        final messages = lesson.sections.expand((section) => section.messages);
        expect(
          messages.where((message) => message.isAssessmentQuestion),
          hasLength(entry.value),
        );
        final experiences = messages
            .where((message) => message.experience != null)
            .toList();
        expect(experiences, isNotEmpty, reason: entry.key);
        kinds.addAll(experiences.map((message) => message.experience!.kind));
        expect(
          experiences.every((message) => message.experience!.ai != null),
          isTrue,
        );
      }
      expect(kinds, containsAll(ExperienceKind.values));
    },
  );

  test('Tutor context is content-only and does not leak between lessons', () {
    final first = _lesson('curso-a', 'Cartilha A', 'Módulo A', 'Desafio A');
    final second = _lesson('curso-b', 'Cartilha B', 'Módulo B', 'Desafio B');
    final firstContext = ExperienceTutorContext.fromContent(
      cartilha: first,
      section: first.sections.single,
      message: first.sections.single.messages.single,
    );
    final secondContext = ExperienceTutorContext.fromContent(
      cartilha: second,
      section: second.sections.single,
      message: second.sections.single.messages.single,
    );
    for (final forbidden in [
      'cpf',
      'telefone',
      'nome',
      'baseline',
      'frequência',
      'matrícula',
    ]) {
      expect(firstContext.toLowerCase(), isNot(contains(forbidden)));
      expect(secondContext.toLowerCase(), isNot(contains(forbidden)));
    }
    expect(firstContext, contains('Cartilha A'));
    expect(secondContext, contains('Cartilha B'));
    expect(secondContext, isNot(contains('Cartilha A')));
  });
}

Cartilha _lesson(String id, String title, String module, String challenge) =>
    Cartilha(
      id: id,
      title: title,
      author: 'TDS',
      sections: [
        Section(
          id: 'm',
          title: module,
          messages: [
            Message(
              type: 'bot',
              content: challenge,
              experience: const ExperienceBlock(
                kind: ExperienceKind.scenario,
                objective: 'Objetivo pedagógico',
                ai: ExperienceAiConfig(starterPrompt: 'Ajude-me a refletir.'),
              ),
            ),
          ],
        ),
      ],
    );
