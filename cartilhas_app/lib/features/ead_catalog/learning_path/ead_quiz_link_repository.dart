import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/ead_catalog_repository.dart';
import 'ead_curriculum_repository.dart';

/// Public metadata only. Never requests answers, attempts, grades or student data.
class EadQuizLinkRepository {
  EadQuizLinkRepository({EadCurriculumGet? httpGet})
    : _httpGet = httpGet ?? http.get;

  final EadCurriculumGet _httpGet;

  static Uri endpoint(int quizId) => Uri.https(
    EadCatalogRepository.host,
    '/wp-json/wp/v2/lp_quiz/$quizId',
    {'_fields': 'id,status,link'},
  );

  Future<Uri> publishedQuizUri(int quizId) async {
    if (quizId <= 0 || quizId > 100000000) {
      throw const EadCurriculumException('Quiz inválido.');
    }
    final http.Response response;
    try {
      response = await _httpGet(
        endpoint(quizId),
      ).timeout(const Duration(seconds: 10));
    } on Object {
      throw const EadCurriculumException(
        'Não foi possível consultar o quiz no EAD.',
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 16384) {
      throw const EadCurriculumException(
        'Quiz ainda não disponível para acesso.',
      );
    }
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(response.bodyBytes));
    } on Object {
      throw const EadCurriculumException('Metadados do quiz inválidos.');
    }
    if (raw is! Map<String, dynamic> ||
        raw['id'] != quizId ||
        raw['status'] != 'publish' ||
        raw['link'] is! String) {
      throw const EadCurriculumException(
        'Quiz não está publicado no LearnPress.',
      );
    }
    final uri = Uri.tryParse(raw['link'] as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != EadCatalogRepository.host ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.hasPort ||
        !(uri.path.startsWith('/quizzes/') ||
            (uri.path.startsWith('/courses/') &&
                uri.path.contains('/quizzes/'))) ||
        uri.pathSegments
            .take(uri.pathSegments.length - 1)
            .any((part) => part == '.' || part == '..' || part.isEmpty)) {
      throw const EadCurriculumException('Endereço do quiz não é confiável.');
    }
    return uri;
  }
}
