import 'dart:convert';

import 'package:cartilhas_app/features/media/data/media_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> item(String id, String course) => {
  'id': id,
  'institution_id': 'inst-1',
  'program_id': 'program-1',
  'course_id': course,
  'module_id': 'module-1',
  'creator_user_id': 'creator-1',
  'title': 'Vídeo $id',
  'description': '',
  'competency_id': 'competency-1',
  'provider': 'youtube',
  'playback_url': 'https://www.youtube-nocookie.com/embed/AbCdEf12345',
  'duration_seconds': 120,
  'captions': const [],
  'visibility': 'enrolled',
  'offline_policy': 'forbidden',
  'status': 'published',
  'followup_activity_id': 'quiz-1',
  'published_at': '2026-09-20T12:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('carrega catálogo remoto, filtra curso e grava cache seguro', () async {
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.example/media?course_id=course-1',
        );
        return http.Response(
          jsonEncode({
            'media': [item('media-1', 'course-1')],
          }),
          200,
        );
      }),
    );

    final media = await repository.fetch(courseId: 'course-1');
    expect(media.single.id, 'media-1');
    expect(
      (await SharedPreferences.getInstance()).getString(
        'media:catalog_cache:v1',
      ),
      isNotNull,
    );
  });

  test('falha de rede usa cache e catálogo ausente retorna vazio', () async {
    SharedPreferences.setMockInitialValues({
      'media:catalog_cache:v1': jsonEncode([item('media-1', 'course-1')]),
    });
    final offline = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    expect((await offline.fetch()).single.id, 'media-1');

    SharedPreferences.setMockInitialValues({});
    final empty = MediaRepository(apiUrl: '');
    expect(await empty.fetch(), isEmpty);
  });

  test('item inseguro é ignorado sem derrubar itens válidos', () async {
    final unsafe = item('media-unsafe', 'course-1')
      ..['provider'] = 'external_hls'
      ..['provider_asset_id'] = 'external'
      ..['playback_url'] = 'https://drive.google.com/file/master.m3u8';
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'items': [unsafe, item('media-safe', 'course-1')],
          }),
          200,
        ),
      ),
    );

    final media = await repository.fetch();
    expect(media.map((item) => item.id), ['media-safe']);
    expect(repository.rejectedItems, 1);
  });

  test('catálogo totalmente incompatível deixa falha observável', () async {
    final unsafe = item('media-unsafe', 'course-1')
      ..['provider'] = 'external_hls'
      ..['playback_url'] = 'https://drive.google.com/file/master.m3u8';
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'media': [unsafe],
          }),
          200,
        ),
      ),
    );

    expect(await repository.fetch(), isEmpty);
    expect(repository.lastIssue, contains('foram rejeitados'));
  });
}
