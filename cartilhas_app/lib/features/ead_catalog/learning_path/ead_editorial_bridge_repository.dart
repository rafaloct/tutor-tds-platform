import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/ead_catalog_repository.dart';
import '../qa/private_editorial_qa_bridge.dart';
import 'ead_curriculum_repository.dart';

typedef EadEditorialGet =
    Future<http.Response> Function(Uri url, Map<String, String> headers);

class EadEditorialLesson {
  const EadEditorialLesson({
    required this.courseId,
    required this.lessonId,
    required this.title,
    required this.contentHtml,
    required this.revision,
    this.youtubeId,
    this.ipexVideoUrl,
    this.ipexCaptionsUrl,
  });

  final int courseId;
  final int lessonId;
  final String title;
  final String contentHtml;
  final String revision;
  final String? youtubeId;
  final Uri? ipexVideoUrl;
  final Uri? ipexCaptionsUrl;
}

/// Dynamic, opt-in WordPress projection. All requests are anonymous GET.
/// Authenticated quizzes and student evidence stay in their owning systems.
class EadEditorialBridgeRepository {
  EadEditorialBridgeRepository({
    EadEditorialGet? get,
    EadCurriculumRepository? fallback,
  }) : _get = get ?? ((uri, headers) => http.get(uri, headers: headers)),
       _fallback = fallback ?? EadCurriculumRepository();

  static const _host = EadCatalogRepository.host;
  static final _revisionPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _videoPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final _idPattern = RegExp(r'^[a-z0-9-]+$');
  final EadEditorialGet _get;
  final EadCurriculumRepository _fallback;
  final Map<int, ({String etag, EadCurriculum curriculum})> _memory = {};

  static Uri curriculumUrl(int id) =>
      PrivateEditorialQaBridge.curriculumUri(id) ??
      Uri.https(_host, '/wp-json/tds-learning/v1/courses/$id/curriculum');

  static Uri lessonUrl(int courseId, int lessonId) =>
      PrivateEditorialQaBridge.lessonUri(courseId, lessonId) ??
      Uri.https(
        _host,
        '/wp-json/tds-learning/v1/courses/$courseId/lessons/$lessonId',
      );

  Future<http.Response> _read(Uri uri, Map<String, String> headers) async {
    try {
      return await _get(uri, headers).timeout(const Duration(seconds: 12));
    } on Object {
      throw const EadCurriculumException(
        'Não foi possível consultar o conteúdo autorizado do EAD.',
      );
    }
  }

  Future<EadCurriculum> fetch(EadCourse course) async {
    if (course.id <= 0) {
      throw const EadCurriculumException('ID do curso inválido.');
    }
    final previous = _memory[course.id];
    final response = await _read(curriculumUrl(course.id), {
      'Accept': 'application/json',
      if (PrivateEditorialQaBridge.enabled &&
          course.id == PrivateEditorialQaBridge.syntheticCourseId)
        ...PrivateEditorialQaBridge.headers,
      if (previous != null) 'If-None-Match': previous.etag,
    });
    if (response.statusCode == 404) {
      // Plugin is not installed yet: only the ordinary public LearnPress
      // syllabus is used; no content/YouTube authorization is inferred.
      _memory.remove(course.id);
      return _fallback.fetch(course);
    }
    if (response.statusCode == 304) {
      if (previous == null) {
        throw const EadCurriculumException('Cache sem revisão correspondente.');
      }
      return previous.curriculum;
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 512 * 1024) {
      throw const EadCurriculumException('Conteúdo editorial indisponível.');
    }
    final map = _decode(response, 512 * 1024);
    if (map['schema_version'] != 1 ||
        map['authority'] != 'learnpress' ||
        map['course_id'] != course.id ||
        map['sections'] is! List ||
        map['revision'] is! String ||
        !_revisionPattern.hasMatch(map['revision'] as String)) {
      throw const EadCurriculumException('Contrato editorial incompatível.');
    }
    final revision = map['revision'] as String;
    final etag = response.headers['etag'];
    if (etag == null || etag != '"$revision"') {
      throw const EadCurriculumException('Revisão editorial não comprovada.');
    }
    final rows = map['sections'] as List;
    if (rows.length > 50) {
      throw const EadCurriculumException('Seções demais na grade EAD.');
    }
    final sectionIds = <int>{};
    final itemIds = <int>{};
    var totalItems = 0;
    final sections = <EadSection>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! int ||
          (row['id'] as int) <= 0 ||
          !sectionIds.add(row['id'] as int) ||
          row['title'] is! String ||
          (row['title'] as String).trim().isEmpty ||
          row['items'] is! List) {
        throw const EadCurriculumException('Seção editorial inválida.');
      }
      final lessons = <EadLesson>[];
      for (final item in row['items'] as List) {
        totalItems++;
        if (totalItems > 250 ||
            item is! Map<String, dynamic> ||
            item['id'] is! int ||
            (item['id'] as int) <= 0 ||
            !itemIds.add(item['id'] as int) ||
            item['title'] is! String ||
            (item['title'] as String).trim().isEmpty ||
            !{'lp_lesson', 'lp_quiz'}.contains(item['type'])) {
          throw const EadCurriculumException('Lição editorial inválida.');
        }
        final mobile = item['mobile_content'] == true;
        final youtube = _videoId(item['media']);
        final hosted = _hosted(item['media']);
        if ((youtube != null || hosted != null) && !mobile) {
          throw const EadCurriculumException('Vídeo sem autorização de aula.');
        }
        lessons.add(
          EadLesson(
            id: item['id'] as int,
            title: (item['title'] as String).trim(),
            type: item['type'] as String,
            isVideoCandidate: youtube != null || hosted != null,
            mobileContent: mobile,
            youtubeId: youtube,
            ipexVideoUrl: hosted?.source,
            ipexCaptionsUrl: hosted?.captions,
          ),
        );
      }
      sections.add(
        EadSection(
          id: row['id'] as int,
          title: (row['title'] as String).trim(),
          lessons: List.unmodifiable(lessons),
        ),
      );
    }
    final result = EadCurriculum(
      course: course,
      sections: List.unmodifiable(sections),
    );
    _memory[course.id] = (etag: etag, curriculum: result);
    return result;
  }

  Future<EadEditorialLesson> lesson(EadCourse course, int lessonId) async {
    if (course.id <= 0 || lessonId <= 0) {
      throw const EadCurriculumException('Identificador de aula inválido.');
    }
    final response = await _read(lessonUrl(course.id, lessonId), {
      'Accept': 'application/json',
      if (PrivateEditorialQaBridge.enabled &&
          course.id == PrivateEditorialQaBridge.syntheticCourseId)
        ...PrivateEditorialQaBridge.headers,
    });
    if (response.statusCode != 200 || response.bodyBytes.length > 512 * 1024) {
      throw const EadCurriculumException(
        'Aula não foi liberada para o aplicativo.',
      );
    }
    final map = _decode(response, 512 * 1024);
    if (map['authority'] != 'learnpress' ||
        map['schema_version'] != 1 ||
        map['course_id'] != course.id ||
        map['lesson_id'] != lessonId ||
        map['title'] is! String ||
        map['content_html'] is! String ||
        map['revision'] is! String ||
        !_revisionPattern.hasMatch(map['revision'] as String)) {
      throw const EadCurriculumException('Resposta de aula não confiável.');
    }
    final content = map['content_html'] as String;
    if (content.length > 250000 ||
        RegExp(
          r'<\s*(script|iframe|object|embed|form)\b',
          caseSensitive: false,
        ).hasMatch(content) ||
        RegExp(r'\bon[a-z]+\s*=', caseSensitive: false).hasMatch(content) ||
        content.toLowerCase().contains('javascript:')) {
      throw const EadCurriculumException('Conteúdo HTML incompatível.');
    }
    final youtube = _videoId(map['media']);
    final hosted = _hosted(map['media']);
    return EadEditorialLesson(
      courseId: course.id,
      lessonId: lessonId,
      title: map['title'] as String,
      contentHtml: content,
      revision: map['revision'] as String,
      youtubeId: youtube,
      ipexVideoUrl: hosted?.source,
      ipexCaptionsUrl: hosted?.captions,
    );
  }

  static Map<String, dynamic> _decode(http.Response response, int max) {
    if (response.bodyBytes.length > max) {
      throw const EadCurriculumException('Resposta muito grande.');
    }
    try {
      final content = jsonDecode(utf8.decode(response.bodyBytes));
      if (content is Map<String, dynamic>) return content;
    } on Object {
      // Preserve a generic error instead of leaking server error payloads.
    }
    throw const EadCurriculumException('Dados editoriais inválidos.');
  }

  static ({Uri source, Uri? captions})? _hosted(Object? raw) {
    if (raw == null ||
        (raw is Map<String, dynamic> && raw['provider'] == 'youtube')) {
      return null;
    }
    if (raw is! Map<String, dynamic> || raw['provider'] != 'ipex_mp4') {
      throw const EadCurriculumException('Provedor de mídia não autorizado.');
    }
    final source = _ipexUrl(raw['source_url'], '.mp4');
    if (source == null) {
      throw const EadCurriculumException('MP4 do IPEX inválido.');
    }
    final captionField = raw['captions_url'];
    final captions = captionField == null
        ? null
        : _ipexUrl(captionField, '.vtt');
    if (captionField != null && captions == null) {
      throw const EadCurriculumException('Legenda do IPEX inválida.');
    }
    return (source: source, captions: captions);
  }

  static Uri? _ipexUrl(Object? raw, String extension) {
    if (raw is! String ||
        raw.length > 2000 ||
        raw.contains(RegExp(r'%(2e|2f|5c)', caseSensitive: false))) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != _host ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith('/wp-content/uploads/tutor-tds/') ||
        !uri.path.toLowerCase().endsWith(extension) ||
        uri.path.contains('..') ||
        uri.path.contains('\\')) {
      return null;
    }
    return uri;
  }

  static String? _videoId(Object? raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic> && raw['provider'] == 'ipex_mp4') {
      return null;
    }
    if (raw is! Map<String, dynamic> ||
        raw['provider'] != 'youtube' ||
        raw['video_id'] is! String ||
        !_videoPattern.hasMatch(raw['video_id'] as String)) {
      throw const EadCurriculumException('Mídia não autorizada.');
    }
    for (final field in ['poster_url', 'captions_url']) {
      final url = raw[field];
      if (url == null) continue;
      if (url is! String) {
        throw const EadCurriculumException('Link de mídia inválido.');
      }
      final parsed = Uri.tryParse(url);
      if (parsed == null ||
          parsed.scheme != 'https' ||
          parsed.host != _host ||
          parsed.hasQuery ||
          parsed.hasFragment ||
          parsed.userInfo.isNotEmpty ||
          parsed.hasPort ||
          !parsed.path.startsWith('/wp-content/uploads/') ||
          !_idPattern.hasMatch(parsed.host.split('.').last)) {
        throw const EadCurriculumException('Endereço de mídia não confiável.');
      }
    }
    return raw['video_id'] as String;
  }
}
