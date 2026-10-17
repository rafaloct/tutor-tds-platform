import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/ead_catalog_repository.dart';

typedef EadCurriculumGet = Future<http.Response> Function(Uri uri);

class EadLesson {
  const EadLesson({
    required this.id,
    required this.title,
    required this.type,
    required this.isVideoCandidate,
  });
  final int id;
  final String title;
  final String type;
  final bool isVideoCandidate;
}

class EadSection {
  const EadSection({
    required this.id,
    required this.title,
    required this.lessons,
  });
  final int id;
  final String title;
  final List<EadLesson> lessons;
}

class EadCurriculum {
  const EadCurriculum({required this.course, required this.sections});
  final EadCourse course;
  final List<EadSection> sections;
  int get lessonCount =>
      sections.fold(0, (sum, section) => sum + section.lessons.length);
  int get videoCount => sections.fold(
    0,
    (sum, section) =>
        sum + section.lessons.where((lesson) => lesson.isVideoCandidate).length,
  );
}

class EadCurriculumException implements Exception {
  const EadCurriculumException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// LearnPress lesson order is editorial, not academic proof or grading authority.
class EadCurriculumRepository {
  EadCurriculumRepository({EadCurriculumGet? httpGet})
    : _httpGet = httpGet ?? http.get;
  final EadCurriculumGet _httpGet;

  static Uri endpoint(int courseId) => Uri.https(
    EadCatalogRepository.host,
    '/wp-json/learnpress/v1/courses/$courseId',
  );

  Future<EadCurriculum> fetch(EadCourse course) async {
    if (course.id <= 0 || course.id > 100000000) {
      throw const EadCurriculumException(
        'Curso sem identificador público válido.',
      );
    }
    final http.Response response;
    try {
      response = await _httpGet(
        endpoint(course.id),
      ).timeout(const Duration(seconds: 10));
    } on Object {
      throw const EadCurriculumException(
        'Não foi possível consultar a sequência do EAD.',
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 512 * 1024) {
      throw const EadCurriculumException('Sequência do curso indisponível.');
    }
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(response.bodyBytes));
    } on Object {
      throw const EadCurriculumException('Resposta inválida do LearnPress.');
    }
    if (raw is! Map<String, dynamic> || raw['id'] != course.id) {
      throw const EadCurriculumException(
        'Curso da resposta difere do solicitado.',
      );
    }
    final sectionsRaw = raw['sections'];
    if (sectionsRaw is! List || sectionsRaw.length > 40) {
      throw const EadCurriculumException('Estrutura do curso inválida.');
    }
    final seenSections = <int>{};
    final seenLessons = <int>{};
    var count = 0;
    final sections = <EadSection>[];
    for (final source in sectionsRaw) {
      if (source is! Map<String, dynamic> ||
          source['id'] is! int ||
          (source['id'] as int) <= 0 ||
          !seenSections.add(source['id'] as int) ||
          source['title'] is! String ||
          (source['title'] as String).trim().isEmpty ||
          source['items'] is! List) {
        throw const EadCurriculumException('Seção inválida no curso.');
      }
      final lessons = <EadLesson>[];
      final name = source['title'] as String;
      // Read editorial metadata on each request, never a fixed video section
      // map for the nine courses. Existing IA sections retain a verified
      // legacy fallback until LearnPress exposes an explicit media marker.
      // Unknown lessons are displayed as lessons, not invented video assets.
      final normalizedName = name.toLowerCase().trim();
      final isVideoSection =
          source['tds_content_type'] == 'video' ||
          normalizedName.startsWith('assista em vídeo') ||
          normalizedName.startsWith('assista em video') ||
          normalizedName.startsWith('videoaulas') ||
          normalizedName.startsWith('videoaula') ||
          (course.id == 614 && {28, 76, 77, 78}.contains(source['id']));
      for (final item in source['items'] as List) {
        count++;
        if (count > 200 ||
            item is! Map<String, dynamic> ||
            item['id'] is! int ||
            (item['id'] as int) <= 0 ||
            !seenLessons.add(item['id'] as int) ||
            item['title'] is! String ||
            (item['title'] as String).trim().isEmpty ||
            item['type'] is! String) {
          throw const EadCurriculumException(
            'Item inválido ou duplicado no curso.',
          );
        }
        final type = item['type'] as String;
        if (!{'lp_lesson', 'lp_quiz'}.contains(type)) {
          throw const EadCurriculumException('Tipo de aula desconhecido.');
        }
        lessons.add(
          EadLesson(
            id: item['id'] as int,
            title: (item['title'] as String).trim(),
            type: type,
            isVideoCandidate: isVideoSection && type == 'lp_lesson',
          ),
        );
      }
      sections.add(
        EadSection(
          id: source['id'] as int,
          title: name.trim(),
          lessons: List.unmodifiable(lessons),
        ),
      );
    }
    return EadCurriculum(course: course, sections: List.unmodifiable(sections));
  }
}
