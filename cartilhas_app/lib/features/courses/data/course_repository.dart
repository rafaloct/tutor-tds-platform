import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../../../models/cartilha.dart';

typedef CourseHttpGet = Future<http.Response> Function(Uri uri);
typedef LocalCourseLoader = Future<List<Cartilha>> Function();

class CourseRepository {
  CourseRepository({
    required this.apiUrl,
    CourseHttpGet? httpGet,
    LocalCourseLoader? localLoader,
  }) : _httpGet = httpGet ?? http.get,
       _localLoader = localLoader ?? _loadBundledCourses;

  factory CourseRepository.forCatalog({
    required String apiUrl,
    bool remoteCatalogEnabled = AppConfig.remoteCatalogEnabled,
    CourseHttpGet? httpGet,
    LocalCourseLoader? localLoader,
  }) => CourseRepository(
    apiUrl: remoteCatalogEnabled ? apiUrl : '',
    httpGet: httpGet,
    localLoader: localLoader,
  );

  static const _assetPaths = [
    'assets/data/lessons/agricultura-sustentavel.json',
    'assets/data/lessons/atendimento-cliente.json',
    'assets/data/lessons/audiovisual.json',
    'assets/data/lessons/cooperativismo.json',
    'assets/data/lessons/economia-lar.json',
    'assets/data/lessons/educacao-financeira.json',
    'assets/data/lessons/ia-cartilha.json',
    'assets/data/lessons/saf.json',
    'assets/data/lessons/sim-sima.json',
  ];

  final String apiUrl;
  final CourseHttpGet _httpGet;
  final LocalCourseLoader _localLoader;
  List<Cartilha>? _latestRemoteSnapshot;

  String get _apiBase => apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  String get _cacheKey =>
      'courses:remote_cache:v2:${Uri.encodeComponent(_apiBase)}';

  Future<List<Cartilha>> fetchAll() async {
    if (_apiBase.isEmpty) return _sorted(await _localLoader());
    final List<Cartilha> remote;
    try {
      remote = await _fetchRemote();
    } on Object {
      final cached = _latestRemoteSnapshot ?? await _loadCache();
      if (cached != null) return _sorted(cached);
      return _sorted(await _localLoader());
    }
    // Empty is a valid editorial snapshot, not an invitation to restore assets.
    _latestRemoteSnapshot = List<Cartilha>.unmodifiable(remote);
    try {
      await _saveCache(remote);
    } on Object {
      // A storage failure must not replace a valid response with stale content.
      // This snapshot remains authoritative in memory; persistence is best effort.
    }
    return _sorted(remote);
  }

  Future<List<Cartilha>> _fetchRemote() async {
    final response = await _httpGet(
      Uri.parse('$_apiBase/courses'),
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Catálogo remoto indisponível.');
    }
    // Um catálogo vazio é uma publicação válida, não uma falha de rede.
    // Não ressuscitar conteúdo retirado pela equipe usando assets/cache.
    return _parsePayload(jsonDecode(response.body));
  }

  Future<void> _saveCache(List<Cartilha> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
  }

  Future<List<Cartilha>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_cacheKey);
      if (source == null) return null;
      return _parsePayload(jsonDecode(source));
    } on Object {
      return null;
    }
  }

  static List<Cartilha> _parsePayload(Object? payload) {
    final raw = payload is List<dynamic>
        ? payload
        : payload is Map<String, dynamic>
        ? payload['courses']
        : null;
    if (raw is! List<dynamic>) {
      throw const FormatException('Contrato de catálogo inválido.');
    }
    final courses = <Cartilha>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Item de catálogo inválido.');
      }
      final course = Cartilha.fromJson(item);
      if (course.id.trim().isEmpty || course.title.trim().isEmpty) {
        throw const FormatException('Identidade de curso inválida.');
      }
      courses.add(course);
    }
    return courses;
  }

  static List<Cartilha> _sorted(List<Cartilha> courses) {
    return [...courses]..sort((a, b) => a.title.compareTo(b.title));
  }

  static Future<List<Cartilha>> _loadBundledCourses() async {
    final courses = <Cartilha>[];
    for (final path in _assetPaths) {
      try {
        final source = await rootBundle.loadString(path);
        courses.add(
          Cartilha.fromJson(jsonDecode(source) as Map<String, dynamic>),
        );
      } on Object {
        // Um asset inválido não impede o carregamento das demais cartilhas.
      }
    }
    return courses;
  }
}
