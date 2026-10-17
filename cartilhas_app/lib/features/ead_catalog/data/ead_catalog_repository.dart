import 'dart:convert';

import 'package:http/http.dart' as http;

typedef EadCatalogGet = Future<http.Response> Function(Uri uri);

/// A published LearnPress course, not an academic enrollment or CourseVersion.
class EadCourse {
  const EadCourse({required this.id, required this.slug, required this.title});

  final int id;
  final String slug;
  final String title;

  /// Only our canonical EAD host is allowed as a course destination.
  Uri get url => Uri.https(EadCatalogRepository.host, '/courses/$slug/');
}

class EadCatalogException implements Exception {
  const EadCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Read-only public discovery. Registration, identity and progress stay on EAD.
class EadCatalogRepository {
  EadCatalogRepository({EadCatalogGet? httpGet})
    : _httpGet = httpGet ?? http.get;

  static const host = 'ead.ipexdesenvolvimento.cloud';
  static const _maxResponseBytes = 512 * 1024;
  static const _pageSize = 100;
  static const _maxPages = 5;
  static final _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
  final EadCatalogGet _httpGet;

  static Uri endpoint({int page = 1}) =>
      Uri.https(host, '/wp-json/wp/v2/lp_course', {
        'per_page': '100',
        'page': page.toString(),
        '_fields': 'id,slug,title,status',
      });

  Future<List<EadCourse>> fetchPublished() async {
    final found = <EadCourse>[];
    final ids = <int>{};
    final slugs = <String>{};
    for (var page = 1; page <= _maxPages; page++) {
      final http.Response response;
      try {
        response = await _httpGet(
          endpoint(page: page),
        ).timeout(const Duration(seconds: 10));
      } on Object {
        throw const EadCatalogException(
          'Não foi possível consultar o EAD. Verifique a internet e tente novamente.',
        );
      }
      if (response.statusCode != 200 ||
          response.bodyBytes.length > _maxResponseBytes) {
        throw const EadCatalogException('Catálogo do EAD indisponível.');
      }
      final Object? payload;
      try {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } on Object {
        throw const EadCatalogException('O EAD respondeu com dados inválidos.');
      }
      if (payload is! List<dynamic> || payload.length > _pageSize) {
        throw const EadCatalogException('Lista de cursos do EAD inválida.');
      }
      for (final raw in payload) {
        if (raw is! Map<String, dynamic>) {
          throw const EadCatalogException('Curso retornado pelo EAD inválido.');
        }
        if (raw['status'] != 'publish') continue;
        final id = raw['id'];
        final slug = raw['slug'];
        final titleObject = raw['title'];
        final title = titleObject is Map<String, dynamic>
            ? titleObject['rendered']
            : null;
        if (id is! int ||
            id <= 0 ||
            slug is! String ||
            !_slugPattern.hasMatch(slug) ||
            title is! String ||
            _cleanTitle(title).isEmpty ||
            !ids.add(id) ||
            !slugs.add(slug)) {
          throw const EadCatalogException(
            'Identidade de curso inconsistente no EAD.',
          );
        }
        found.add(EadCourse(id: id, slug: slug, title: _cleanTitle(title)));
      }

      // WP REST provides X-WP-TotalPages. Without it, a short page ends the
      // sequence; a full page requires checking the next page.
      final totalHeader = response.headers['x-wp-totalpages'];
      if (totalHeader != null) {
        final total = int.tryParse(totalHeader);
        if (total == null || total < 1 || total > _maxPages) {
          throw const EadCatalogException('Paginação do EAD inesperada.');
        }
        if (page >= total) break;
      } else if (payload.length < _pageSize) {
        break;
      } else if (page == _maxPages) {
        throw const EadCatalogException('Catálogo do EAD excedeu o limite.');
      }
    }
    return List<EadCourse>.unmodifiable(
      found..sort((a, b) => a.title.compareTo(b.title)),
    );
  }

  static String _cleanTitle(String value) {
    final noTags = value.replaceAll(RegExp(r'<[^>]*>'), '');
    return noTags
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
