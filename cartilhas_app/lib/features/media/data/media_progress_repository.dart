import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MediaProgress {
  const MediaProgress({
    required this.mediaId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.saved,
    required this.updatedAt,
  });

  final String mediaId;
  final int positionSeconds;
  final int durationSeconds;
  final bool saved;
  final DateTime updatedAt;

  double get fraction => durationSeconds <= 0
      ? 0
      : (positionSeconds / durationSeconds).clamp(0, 1);

  Map<String, Object> toJson() => {
    'mediaId': mediaId,
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'saved': saved,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static MediaProgress? fromJson(Object? source) {
    if (source is! Map<String, dynamic>) return null;
    final mediaId = source['mediaId'];
    final position = source['positionSeconds'];
    final duration = source['durationSeconds'];
    final saved = source['saved'];
    final updatedAt = DateTime.tryParse(source['updatedAt'] as String? ?? '');
    if (mediaId is! String ||
        mediaId.isEmpty ||
        position is! int ||
        position < 0 ||
        duration is! int ||
        duration < 1 ||
        position > duration ||
        saved is! bool ||
        updatedAt == null) {
      return null;
    }
    return MediaProgress(
      mediaId: mediaId,
      positionSeconds: position,
      durationSeconds: duration,
      saved: saved,
      updatedAt: updatedAt,
    );
  }
}

class MediaProgressRepository {
  const MediaProgressRepository();

  String _key(String mediaId) => 'media:progress:$mediaId';

  Future<MediaProgress?> load(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_key(mediaId));
      return source == null ? null : MediaProgress.fromJson(jsonDecode(source));
    } on Object {
      return null;
    }
  }

  Future<void> save(MediaProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(progress.mediaId),
      jsonEncode(progress.toJson()),
    );
  }
}
