import 'package:cartilhas_app/features/media/models/media_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> mediaJson({
  String provider = 'youtube',
  String providerAssetId = 'AbCdEf12345',
  String? playbackUrl,
  String? thumbnailUrl = 'https://cdn.example/thumb.jpg',
}) => {
  'id': 'media-1',
  'institution_id': 'inst-1',
  'program_id': 'program-1',
  'course_id': 'course-1',
  'module_id': 'module-1',
  'creator_user_id': 'creator-1',
  'creator_name': 'Maria Creator',
  'title': 'Como organizar uma cooperativa',
  'description': 'Aula introdutória.',
  'competency_id': 'competency-1',
  'provider': provider,
  'playback_url':
      ?playbackUrl ??
      (provider == 'youtube'
          ? 'https://www.youtube-nocookie.com/embed/$providerAssetId'
          : null),
  'duration_seconds': 360,
  'thumbnail_url': ?thumbnailUrl,
  'captions': [
    {
      'language': 'pt-BR',
      'label': 'Português',
      'format': 'vtt',
      'url': 'https://cdn.example/legendas/media-1.vtt',
    },
  ],
  'visibility': 'enrolled',
  'offline_policy': 'forbidden',
  'status': 'published',
  'followup_activity_id': 'quiz-1',
  'published_at': '2026-09-20T12:00:00Z',
  'source_label': 'Programa TDS',
};

void main() {
  test('decodifica mídia sem acoplar o domínio ao provedor', () {
    final media = MediaItem.fromJson(mediaJson());

    expect(media.provider, MediaProvider.youtube);
    expect(media.canPlay, isTrue);
    expect(media.captions.single.language, 'pt-BR');
    expect(media.creatorName, 'Maria Creator');
  });

  test('aceita fixture canônica sem provider_asset_id', () {
    final fixture = mediaJson();
    final caption =
        (fixture['captions'] as List).single as Map<String, dynamic>;
    caption['reference'] = caption.remove('url');
    caption.remove('label');
    final media = MediaItem.fromJson(fixture);
    expect(media.providerAssetId, 'AbCdEf12345');
    expect(media.playbackUrl?.host, 'www.youtube-nocookie.com');
  });

  test('aceita Cloudflare Stream somente em host oficial', () {
    final valid = MediaItem.fromJson(
      mediaJson(
        provider: 'cloudflare_stream',
        providerAssetId: 'stream-asset',
        playbackUrl:
            'https://customer.example.videodelivery.net/stream-asset/iframe',
      ),
    );
    expect(valid.canPlay, isTrue);

    expect(
      () => MediaItem.fromJson(
        mediaJson(
          provider: 'cloudflare_stream',
          providerAssetId: 'stream-asset',
          playbackUrl: 'https://evil.example/video',
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejeita Drive, HTTP e arquivo externo que não seja HLS', () {
    expect(
      () => MediaItem.fromJson(
        mediaJson(thumbnailUrl: 'https://drive.google.com/file/d/master'),
      ),
      throwsFormatException,
    );
    expect(
      () => MediaItem.fromJson(
        mediaJson(
          provider: 'external_hls',
          providerAssetId: 'external-1',
          playbackUrl: 'http://cdn.example/video.m3u8',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => MediaItem.fromJson(
        mediaJson(
          provider: 'external_hls',
          providerAssetId: 'external-1',
          playbackUrl: 'https://cdn.example/video.mp4',
        ),
      ),
      throwsFormatException,
    );
  });

  test('cache remove playback temporário mas preserva metadados', () {
    final media = MediaItem.fromJson(
      mediaJson(
        provider: 'cloudflare_stream',
        providerAssetId: 'stream-asset',
        playbackUrl:
            'https://customer.example.videodelivery.net/stream-asset/iframe',
      ),
    );
    final cached = MediaItem.fromJson(media.toCacheJson());

    expect(cached.playbackUrl, isNull);
    expect(cached.canPlay, isFalse);
    expect(cached.title, media.title);
  });
}
