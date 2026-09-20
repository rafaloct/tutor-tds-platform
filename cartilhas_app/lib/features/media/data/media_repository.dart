import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../models/media_models.dart';

enum MediaRepositoryIssue {
  sessionRequired,
  activeEnrollmentRequired,
  accessDenied,
  qualifiedCompletionRequired,
  authorizationExpired,
  unavailable,
  invalidResponse,
}

class MediaRepositoryException implements Exception {
  const MediaRepositoryException(this.issue, this.message);

  final MediaRepositoryIssue issue;
  final String message;

  @override
  String toString() => message;
}

class MediaRepository {
  MediaRepository({
    required this.apiUrl,
    this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _cacheKey = 'media:catalog_cache:v1';
  final String apiUrl;
  final AuthRepository? authRepository;
  final http.Client _client;
  int rejectedItems = 0;
  bool usedCachedData = false;
  String? lastIssue;

  Future<List<MediaItem>> fetch({String? courseId, String? moduleId}) async {
    rejectedItems = 0;
    usedCachedData = false;
    lastIssue = null;
    if (apiUrl.trim().isNotEmpty) {
      try {
        final remote = await _fetchRemote(
          courseId: courseId,
          moduleId: moduleId,
        );
        await _saveCache(remote);
        return remote;
      } on Object catch (error) {
        // Baixa conectividade usa apenas metadados previamente validados.
        lastIssue = error is FormatException
            ? error.message.toString()
            : 'Não foi possível atualizar os vídeos.';
      }
    }
    final cached = await _loadCache();
    usedCachedData = cached.isNotEmpty;
    return _filter(cached, courseId: courseId, moduleId: moduleId);
  }

  Future<MediaPlaybackAccess> authorizePlayback(MediaItem media) async {
    if (!media.requiresPlaybackAuthorization && media.canPlay) {
      return MediaPlaybackAccess(media: media);
    }
    final auth = await _requiredAuth();
    final base = _apiBase();
    try {
      final response = await auth.authorized(
        (token) => _client
            .post(
              base.resolve('/media/${media.id}/playback-authorizations'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode == 401) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.sessionRequired,
          'Entre na sua conta para reproduzir este vídeo.',
        );
      }
      if (response.statusCode == 403) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.activeEnrollmentRequired,
          'Uma matrícula ou vínculo ativo é necessário para reproduzir este vídeo.',
        );
      }
      if (response.statusCode == 404) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.accessDenied,
          'Este vídeo não está disponível para sua conta ou deixou de ser publicado.',
        );
      }
      if (response.statusCode == 503) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.unavailable,
          'A entrega deste vídeo ainda não está configurada.',
        );
      }
      if (response.statusCode != 201) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.unavailable,
          'Não foi possível autorizar a reprodução agora.',
        );
      }
      final authorization = MediaPlaybackAuthorization.fromJson(
        _jsonMap(response.body),
        expectedMediaId: media.id,
        apiBase: base,
      );
      final now = DateTime.now().toUtc();
      if (!authorization.expiresAt.isAfter(now) ||
          authorization.expiresAt.isAfter(
            now.add(const Duration(minutes: 10)),
          )) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.invalidResponse,
          'A autorização de reprodução possui validade inválida.',
        );
      }
      final request = http.Request('GET', authorization.playbackUrl)
        ..followRedirects = false;
      final resolution = await _client
          .send(request)
          .timeout(const Duration(seconds: 12));
      if (resolution.statusCode == 401) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.authorizationExpired,
          'O acesso ao vídeo expirou. Tente renovar a reprodução.',
        );
      }
      if (resolution.statusCode == 403) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.activeEnrollmentRequired,
          'Seu vínculo não permite mais reproduzir este vídeo.',
        );
      }
      if (resolution.statusCode == 404) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.accessDenied,
          'Este vídeo não está mais disponível para sua conta.',
        );
      }
      if (resolution.statusCode != 307) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.unavailable,
          'A fonte do vídeo não pôde ser resolvida.',
        );
      }
      final target = resolution.headers['location'];
      if (target == null) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.invalidResponse,
          'A fonte do vídeo não foi informada.',
        );
      }
      return MediaPlaybackAccess(
        media: media.withPlaybackUrl(target),
        expiresAt: authorization.expiresAt,
      );
    } on MediaRepositoryException {
      rethrow;
    } on FormatException {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.invalidResponse,
        'A autorização de reprodução recebida é inválida.',
      );
    } on Object {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.unavailable,
        'Sem conexão para renovar o acesso ao vídeo.',
      );
    }
  }

  Future<MediaRating?> fetchRating(String mediaId) async {
    final auth = await _requiredAuth();
    try {
      final response = await auth.authorized(
        (token) => _client
            .get(
              _apiBase().resolve('/media/$mediaId/rating'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.unavailable,
          'Não foi possível consultar sua avaliação.',
        );
      }
      return MediaRating.fromJson(
        _jsonMap(response.body),
        expectedMediaId: mediaId,
      );
    } on MediaRepositoryException {
      rethrow;
    } on Object {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.unavailable,
        'Não foi possível consultar sua avaliação agora.',
      );
    }
  }

  Future<MediaRating> rate(String mediaId, int rating) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Deve estar entre 1 e 5.');
    }
    final auth = await _requiredAuth();
    try {
      final response = await auth.authorized(
        (token) => _client
            .put(
              _apiBase().resolve('/media/$mediaId/rating'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'rating': rating}),
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode == 403) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.activeEnrollmentRequired,
          'Matrícula ativa necessária para avaliar este vídeo.',
        );
      }
      if (response.statusCode == 409) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.qualifiedCompletionRequired,
          'Conclua o vídeo antes de avaliar. A conclusão pode levar alguns instantes para sincronizar.',
        );
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const MediaRepositoryException(
          MediaRepositoryIssue.unavailable,
          'Não foi possível enviar sua avaliação.',
        );
      }
      return MediaRating.fromJson(
        _jsonMap(response.body),
        expectedMediaId: mediaId,
      );
    } on MediaRepositoryException {
      rethrow;
    } on FormatException {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.invalidResponse,
        'A confirmação da avaliação é inválida.',
      );
    } on Object {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.unavailable,
        'Sem conexão para enviar sua avaliação agora.',
      );
    }
  }

  Future<List<MediaItem>> _fetchRemote({
    String? courseId,
    String? moduleId,
  }) async {
    final query = <String, String>{
      if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
      if (moduleId != null && moduleId.isNotEmpty) 'module_id': moduleId,
    };
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    final uri = Uri.parse('$base/media').replace(queryParameters: query);
    final auth = authRepository;
    late http.Response response;
    if (auth != null && auth.isConfigured && await auth.hasSession()) {
      response = await auth.authorized(
        (token) => _client
            .get(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 12)),
      );
    } else {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Catálogo de vídeos indisponível.');
    }
    return _parse(jsonDecode(response.body));
  }

  Future<AuthRepository> _requiredAuth() async {
    final auth = authRepository;
    if (apiUrl.trim().isEmpty || auth == null || !auth.isConfigured) {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.unavailable,
        'O acesso online a vídeos ainda não está disponível.',
      );
    }
    if (!await auth.hasSession()) {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.sessionRequired,
        'Entre na sua conta para continuar.',
      );
    }
    return auth;
  }

  Uri _apiBase() {
    final uri = Uri.parse(apiUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const MediaRepositoryException(
        MediaRepositoryIssue.unavailable,
        'A API de vídeos não está configurada com segurança.',
      );
    }
    return uri;
  }

  Map<String, dynamic> _jsonMap(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta de mídia inválida.');
    }
    return decoded;
  }

  Future<void> _saveCache(List<MediaItem> media) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(media.map((item) => item.toCacheJson()).toList()),
    );
  }

  Future<List<MediaItem>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_cacheKey);
      return source == null
          ? const []
          : _parse(jsonDecode(source), updateMetrics: false);
    } on Object {
      return const [];
    }
  }

  List<MediaItem> _parse(Object? payload, {bool updateMetrics = true}) {
    final raw = payload is List<dynamic>
        ? payload
        : payload is Map<String, dynamic>
        ? payload['media'] ?? payload['items']
        : null;
    if (raw is! List<dynamic>) {
      throw const FormatException('Catálogo de vídeos inválido.');
    }
    final parsed = <MediaItem>[];
    var rejected = raw.length - raw.whereType<Map<String, dynamic>>().length;
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      try {
        final media = MediaItem.fromJson(item);
        if (media.status == 'published') parsed.add(media);
      } on FormatException {
        rejected++;
      }
    }
    if (updateMetrics) rejectedItems = rejected;
    if (raw.isNotEmpty && parsed.isEmpty && rejected > 0) {
      throw FormatException(
        'Todos os $rejected item(ns) de mídia foram rejeitados pelo contrato seguro.',
      );
    }
    parsed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return parsed;
  }

  static List<MediaItem> _filter(
    List<MediaItem> media, {
    String? courseId,
    String? moduleId,
  }) => media
      .where(
        (item) =>
            (courseId == null || item.courseId == courseId) &&
            (moduleId == null || item.moduleId == moduleId),
      )
      .toList(growable: false);

  void dispose() => _client.close();
}
