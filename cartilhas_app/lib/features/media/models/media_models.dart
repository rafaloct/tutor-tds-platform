enum MediaProvider { youtube, cloudflareStream, externalHls }

extension MediaProviderValue on MediaProvider {
  String get apiValue => switch (this) {
    MediaProvider.youtube => 'youtube',
    MediaProvider.cloudflareStream => 'cloudflare_stream',
    MediaProvider.externalHls => 'external_hls',
  };
}

enum MediaOfflinePolicy { forbidden, allowed }

class MediaCaption {
  const MediaCaption({
    required this.language,
    required this.label,
    required this.format,
    required this.url,
  });

  final String language;
  final String label;
  final String format;
  final Uri url;
  bool get isWebVtt => format == 'vtt' || format == 'webvtt';

  factory MediaCaption.fromJson(Map<String, dynamic> json) {
    final language = _requiredIdentifier(json, 'language');
    final label = _optionalString(json['label']) ?? language;
    final format = _requiredIdentifier(json, 'format');
    final reference = json['url'] ?? json['reference'];
    if (reference is! String) {
      throw const FormatException('Referência de legenda ausente.');
    }
    final url = _safeHttpsUri(reference);
    if (!const {'vtt', 'webvtt', 'srt'}.contains(format)) {
      throw const FormatException('Formato de legenda não suportado.');
    }
    return MediaCaption(
      language: language,
      label: label,
      format: format,
      url: url,
    );
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.institutionId,
    required this.programId,
    required this.courseId,
    required this.moduleId,
    required this.creatorUserId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.competencyId,
    required this.provider,
    required this.providerAssetId,
    required this.playbackUrl,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.captions,
    required this.visibility,
    required this.offlinePolicy,
    required this.status,
    required this.followupActivityId,
    required this.publishedAt,
    required this.sourceLabel,
  });

  final String id;
  final String institutionId;
  final String programId;
  final String courseId;
  final String moduleId;
  final String creatorUserId;
  final String creatorName;
  final String title;
  final String description;
  final String competencyId;
  final MediaProvider provider;
  final String providerAssetId;
  final Uri? playbackUrl;
  final int durationSeconds;
  final Uri? thumbnailUrl;
  final List<MediaCaption> captions;
  final String visibility;
  final MediaOfflinePolicy offlinePolicy;
  final String status;
  final String followupActivityId;
  final DateTime publishedAt;
  final String sourceLabel;

  bool get canPlay => switch (provider) {
    MediaProvider.youtube => RegExp(
      r'^[A-Za-z0-9_-]{6,20}$',
    ).hasMatch(providerAssetId),
    MediaProvider.cloudflareStream => playbackUrl != null,
    MediaProvider.externalHls => playbackUrl != null,
  };

  bool get requiresPlaybackAuthorization =>
      visibility == 'enrolled' || visibility == 'institution';

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final providerValue = _requiredIdentifier(json, 'provider');
    final provider = switch (providerValue) {
      'youtube' => MediaProvider.youtube,
      'cloudflare_stream' => MediaProvider.cloudflareStream,
      'external_hls' => MediaProvider.externalHls,
      _ => throw const FormatException('Provedor de vídeo não suportado.'),
    };
    final playbackValue =
        json['playback_url'] ??
        (json['playback'] is Map<String, dynamic>
            ? (json['playback'] as Map<String, dynamic>)['url']
            : null);
    final playbackUrl = playbackValue is String && playbackValue.isNotEmpty
        ? _safePlaybackUri(playbackValue, provider)
        : null;
    final providerAssetId =
        _optionalString(json['provider_asset_id']) ??
        (provider == MediaProvider.youtube
            ? _youtubeAssetId(playbackUrl)
            : '') ??
        '';
    if (provider == MediaProvider.youtube &&
        playbackUrl != null &&
        !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(providerAssetId)) {
      throw const FormatException('Fonte YouTube inválida.');
    }

    final rawCaptions = json['captions'];
    if (rawCaptions is! List<dynamic>) {
      throw const FormatException('Legendas inválidas.');
    }
    final thumbnailValue = json['thumbnail_url'];
    final offlineValue = _requiredIdentifier(json, 'offline_policy');
    final publishedAt = DateTime.tryParse(
      _requiredString(json, 'published_at'),
    );
    if (publishedAt == null) {
      throw const FormatException('Publicação inválida.');
    }

    return MediaItem(
      id: _requiredIdentifier(json, 'id'),
      institutionId: _requiredIdentifier(json, 'institution_id'),
      programId: _requiredIdentifier(json, 'program_id'),
      courseId: _requiredIdentifier(json, 'course_id'),
      moduleId: _requiredIdentifier(json, 'module_id'),
      creatorUserId: _requiredIdentifier(json, 'creator_user_id'),
      creatorName: _optionalString(json['creator_name']) ?? 'Creator TDS',
      title: _requiredString(json, 'title'),
      description: _optionalString(json['description']) ?? '',
      competencyId: _requiredIdentifier(json, 'competency_id'),
      provider: provider,
      providerAssetId: providerAssetId,
      playbackUrl: playbackUrl,
      durationSeconds: _positiveInt(json, 'duration_seconds'),
      thumbnailUrl: thumbnailValue is String && thumbnailValue.isNotEmpty
          ? _safeHttpsUri(thumbnailValue)
          : null,
      captions: rawCaptions
          .whereType<Map<String, dynamic>>()
          .map(MediaCaption.fromJson)
          .toList(growable: false),
      visibility: _requiredIdentifier(json, 'visibility'),
      offlinePolicy: switch (offlineValue) {
        'allowed' => MediaOfflinePolicy.allowed,
        'forbidden' => MediaOfflinePolicy.forbidden,
        _ => throw const FormatException('Política offline inválida.'),
      },
      status: _requiredIdentifier(json, 'status'),
      followupActivityId: _requiredIdentifier(json, 'followup_activity_id'),
      publishedAt: publishedAt,
      sourceLabel: _optionalString(json['source_label']) ?? 'Acervo Tutor TDS',
    );
  }

  Map<String, Object?> toCacheJson() => {
    'id': id,
    'institution_id': institutionId,
    'program_id': programId,
    'course_id': courseId,
    'module_id': moduleId,
    'creator_user_id': creatorUserId,
    'creator_name': creatorName,
    'title': title,
    'description': description,
    'competency_id': competencyId,
    'provider': provider.apiValue,
    'provider_asset_id': providerAssetId,
    // URLs assinadas/temporárias nunca entram no cache persistente.
    'duration_seconds': durationSeconds,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl.toString(),
    'captions': captions
        .map(
          (caption) => {
            'language': caption.language,
            'label': caption.label,
            'format': caption.format,
            'url': caption.url.toString(),
          },
        )
        .toList(),
    'visibility': visibility,
    'offline_policy': offlinePolicy.name,
    'status': status,
    'followup_activity_id': followupActivityId,
    'published_at': publishedAt.toIso8601String(),
    'source_label': sourceLabel,
  };

  MediaItem withPlaybackUrl(String source) {
    final url = _safePlaybackUri(source, provider);
    final assetId = provider == MediaProvider.youtube
        ? _youtubeAssetId(url) ?? ''
        : providerAssetId;
    if (provider == MediaProvider.youtube &&
        !RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(assetId)) {
      throw const FormatException('Fonte YouTube inválida.');
    }
    return MediaItem(
      id: id,
      institutionId: institutionId,
      programId: programId,
      courseId: courseId,
      moduleId: moduleId,
      creatorUserId: creatorUserId,
      creatorName: creatorName,
      title: title,
      description: description,
      competencyId: competencyId,
      provider: provider,
      providerAssetId: assetId,
      playbackUrl: url,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      captions: captions,
      visibility: visibility,
      offlinePolicy: offlinePolicy,
      status: status,
      followupActivityId: followupActivityId,
      publishedAt: publishedAt,
      sourceLabel: sourceLabel,
    );
  }
}

class MediaPlaybackAuthorization {
  const MediaPlaybackAuthorization({
    required this.mediaId,
    required this.playbackUrl,
    required this.expiresAt,
  });

  final String mediaId;
  final Uri playbackUrl;
  final DateTime expiresAt;

  factory MediaPlaybackAuthorization.fromJson(
    Map<String, dynamic> json, {
    required String expectedMediaId,
    required Uri apiBase,
  }) {
    final mediaId = _requiredIdentifier(json, 'media_id');
    if (mediaId != expectedMediaId || json['token_type'] != 'media_playback') {
      throw const FormatException('Autorização de reprodução inválida.');
    }
    final rawUrl = json['playback_url'];
    final expiresAt = DateTime.tryParse(json['expires_at'] as String? ?? '');
    if (rawUrl is! String || expiresAt == null) {
      throw const FormatException('Autorização de reprodução incompleta.');
    }
    final playbackUrl = Uri.tryParse(rawUrl);
    final basePath = apiBase.path.replaceFirst(RegExp(r'/+$'), '');
    final expectedPath = '$basePath/media/$expectedMediaId/playback/';
    if (playbackUrl == null ||
        playbackUrl.scheme != 'https' ||
        playbackUrl.userInfo.isNotEmpty ||
        playbackUrl.host != apiBase.host ||
        playbackUrl.port != apiBase.port ||
        !playbackUrl.path.startsWith(expectedPath)) {
      throw const FormatException('URL de autorização de reprodução inválida.');
    }
    return MediaPlaybackAuthorization(
      mediaId: mediaId,
      playbackUrl: playbackUrl,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

class MediaPlaybackAccess {
  const MediaPlaybackAccess({required this.media, this.expiresAt});

  final MediaItem media;
  final DateTime? expiresAt;
}

class MediaRating {
  const MediaRating({
    required this.mediaId,
    required this.rating,
    required this.submittedAt,
    required this.updatedAt,
  });

  final String mediaId;
  final int rating;
  final DateTime submittedAt;
  final DateTime updatedAt;

  factory MediaRating.fromJson(
    Map<String, dynamic> json, {
    required String expectedMediaId,
  }) {
    final mediaId = _requiredIdentifier(json, 'media_id');
    final rating = (json['rating'] as num?)?.toInt();
    final submittedAt = DateTime.tryParse(
      json['submitted_at'] as String? ?? '',
    );
    final updatedAt = DateTime.tryParse(json['updated_at'] as String? ?? '');
    if (mediaId != expectedMediaId ||
        rating == null ||
        rating < 1 ||
        rating > 5 ||
        submittedAt == null ||
        updatedAt == null) {
      throw const FormatException('Avaliação de mídia inválida.');
    }
    return MediaRating(
      mediaId: mediaId,
      rating: rating,
      submittedAt: submittedAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 500) {
    throw FormatException('Campo inválido: $key.');
  }
  return value.trim();
}

String _requiredIdentifier(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}$').hasMatch(value)) {
    throw FormatException('Identificador inválido: $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 500) {
    throw const FormatException('Texto opcional inválido.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value <= 0 || value > 86400) {
    throw FormatException('Duração inválida: $key.');
  }
  return value.toInt();
}

Uri _safeHttpsUri(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      _isDriveHost(uri.host)) {
    throw const FormatException('URL de mídia insegura.');
  }
  return uri;
}

Uri _safePlaybackUri(String source, MediaProvider provider) {
  final uri = _safeHttpsUri(source);
  if (provider == MediaProvider.youtube &&
      !_hostEndsWith(uri.host, 'youtube-nocookie.com') &&
      !_hostEndsWith(uri.host, 'youtube.com')) {
    throw const FormatException('Host YouTube inválido.');
  }
  if (provider == MediaProvider.cloudflareStream &&
      !_hostEndsWith(uri.host, 'videodelivery.net') &&
      !_hostEndsWith(uri.host, 'cloudflarestream.com')) {
    throw const FormatException('Host Cloudflare Stream inválido.');
  }
  if (provider == MediaProvider.externalHls &&
      !uri.path.toLowerCase().endsWith('.m3u8')) {
    throw const FormatException('A fonte externa deve ser HLS.');
  }
  return uri;
}

bool _hostEndsWith(String host, String suffix) =>
    host == suffix || host.endsWith('.$suffix');

bool _isDriveHost(String host) =>
    _hostEndsWith(host.toLowerCase(), 'drive.google.com') ||
    _hostEndsWith(host.toLowerCase(), 'docs.google.com') ||
    _hostEndsWith(host.toLowerCase(), 'googleusercontent.com');

String? _youtubeAssetId(Uri? playbackUrl) {
  if (playbackUrl == null || playbackUrl.pathSegments.isEmpty) return null;
  return playbackUrl.pathSegments.last;
}
