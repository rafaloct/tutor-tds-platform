import 'dart:convert';

import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserva IDs e versões editoriais no round-trip e cache', () {
    final course = Cartilha.fromJson({
      'id': 'course-1',
      'title': 'Curso publicado',
      'author': 'TDS',
      'course_version_id': 'course-version-1',
      'class_id': 'class-1',
      'sections': [
        {
          'id': 'section-1',
          'version_id': 'section-version-1',
          'title': 'Módulo 1',
          'messages': [
            {
              'id': 'block-1',
              'version_id': 'block-version-1',
              'type': 'quiz',
              'content': 'Pergunta publicada?',
              'options': [
                {'label': 'A', 'isCorrect': true},
                {'label': 'B', 'isCorrect': true},
                {'label': 'C', 'isCorrect': false},
              ],
            },
          ],
        },
      ],
    });

    final cached = Cartilha.fromJson(
      jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
    );

    expect(cached.sections.single.versionId, 'section-version-1');
    expect(cached.sections.single.messages.single.id, 'block-1');
    expect(cached.sections.single.messages.single.versionId, 'block-version-1');
    expect(
      cached.sections.single.messages.single.options
          ?.where((option) => option.isCorrect == true)
          .length,
      2,
    );
  });

  test('conteúdo legado sem versões continua legível', () {
    final course = Cartilha.fromJson({
      'id': 'legacy',
      'title': 'Legado',
      'author': 'TDS',
      'sections': [
        {
          'id': 'section',
          'title': 'Módulo',
          'messages': [
            {'type': 'bot', 'content': 'Texto'},
          ],
        },
      ],
    });

    expect(course.sections.single.versionId, isNull);
    expect(course.sections.single.messages.single.id, isNull);
    expect(course.sections.single.messages.single.versionId, isNull);
  });
}
