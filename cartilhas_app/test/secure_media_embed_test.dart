import 'package:cartilhas_app/features/media/models/media_models.dart';
import 'package:cartilhas_app/features/media/presentation/secure_media_embed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('embed YouTube usa API, privacidade e controles de velocidade', () {
    final html = buildSecureMediaHtml(_media(MediaProvider.youtube));

    expect(html, contains('youtube.com/iframe_api'));
    expect(html, contains("host:'https://www.youtube-nocookie.com'"));
    expect(html, contains('AbCdEf12345'));
    expect(html, contains('setPlaybackRate'));
    expect(html, contains('TutorVideo.postMessage'));
    expect(html, contains("notify('error'"));
  });

  test('embed HLS inclui legenda WebVTT e retomada', () {
    final html = buildSecureMediaHtml(
      _media(MediaProvider.externalHls),
      initialPositionSeconds: 42,
    );

    expect(html, contains('https://cdn.example/video.m3u8'));
    expect(html, contains('https://cdn.example/video.vtt'));
    expect(html, contains('player.currentTime=Math.min(42'));
    expect(html, contains("notify('error'"));
  });
}

MediaItem _media(MediaProvider provider) => MediaItem(
  id: 'media-1',
  institutionId: 'inst-1',
  programId: 'program-1',
  courseId: 'course-1',
  moduleId: 'module-1',
  creatorUserId: 'creator-1',
  creatorName: 'Creator TDS',
  title: 'Vídeo',
  description: '',
  competencyId: 'competency-1',
  provider: provider,
  providerAssetId: 'AbCdEf12345',
  playbackUrl: provider == MediaProvider.externalHls
      ? Uri.parse('https://cdn.example/video.m3u8')
      : null,
  durationSeconds: 100,
  thumbnailUrl: null,
  captions: [
    MediaCaption(
      language: 'pt-BR',
      label: 'Português',
      format: 'vtt',
      url: Uri.parse('https://cdn.example/video.vtt'),
    ),
  ],
  visibility: 'enrolled',
  offlinePolicy: MediaOfflinePolicy.forbidden,
  status: 'published',
  followupActivityId: 'quiz-1',
  publishedAt: DateTime.utc(2026, 9, 20),
  sourceLabel: 'TDS',
);
