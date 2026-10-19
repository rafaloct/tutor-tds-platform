import 'dart:convert';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_ipex_video_player_screen.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const course = EadCourse(
  id: 1298,
  slug: 'agricultura-sustentavel',
  title: 'Agricultura Sustentável',
);
const revision =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const source =
    'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/'
    'tutor-tds/v2-20261016/saf/01_saf_v2_acessivel_FHD.mp4';
const captions =
    'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/'
    'tutor-tds/v2-20261016/saf/01_saf.vtt';

http.Response syllabus(
  Object? media, {
  bool mobile = true,
  String currentRevision = revision,
}) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'schema_version': 1,
          'authority': 'learnpress',
          'course_id': 1298,
          'title': 'Agricultura Sustentável',
          'revision': currentRevision,
          'sections': [
            {
              'id': 80,
              'title': 'Assista em vídeo',
              'items': [
                {
                  'id': 1299,
                  'type': 'lp_lesson',
                  'title': 'Videoaula SAF',
                  'mobile_content': mobile,
                  'revision': '2026-10-19 10:00:00',
                  'media': media,
                },
              ],
            },
          ],
        }),
      ),
      200,
      headers: {'etag': '"$currentRevision"'},
    );

http.Response lesson(Object? media) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'schema_version': 1,
      'authority': 'learnpress',
      'course_id': 1298,
      'lesson_id': 1299,
      'title': 'Videoaula SAF',
      'content_html': '<p>Cartilha pública.</p>',
      'revision': revision,
      'media': media,
    }),
  ),
  200,
);

void main() {
  final media = <String, String>{
    'provider': 'ipex_mp4',
    'source_url': source,
    'captions_url': captions,
  };

  test('48 videoaulas podem usar MP4 do IPEX em vez do YouTube', () async {
    final repo = EadEditorialBridgeRepository(
      get: (_, _) async => syllabus(media),
    );
    final courseView = await repo.fetch(course);
    final item = courseView.sections.first.lessons.first;
    expect(item.mobileContent, true);
    expect(item.isVideoCandidate, true);
    expect(item.youtubeId, isNull);
    expect(item.ipexVideoUrl.toString(), source);
    expect(item.ipexCaptionsUrl.toString(), captions);
    final detail = EadEditorialBridgeRepository(
      get: (_, _) async => lesson(media),
    );
    expect((await detail.lesson(course, 1299)).ipexVideoUrl.toString(), source);
  });

  test('nenhum MP4 libera a aula se mobile_content=false', () async {
    final repo = EadEditorialBridgeRepository(
      get: (_, _) async => syllabus(media, mobile: false),
    );
    await expectLater(repo.fetch(course), throwsException);
  });

  test('revogação editorial remove MP4/VTT após revisão da grade', () async {
    var approved = true;
    final repo = EadEditorialBridgeRepository(
      get: (_, _) async => syllabus(
        approved ? media : null,
        mobile: approved,
        currentRevision: approved
            ? revision
            : 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
    );
    final first = (await repo.fetch(course)).sections.single.lessons.single;
    expect(first.ipexVideoUrl.toString(), source);
    approved = false;
    final revoked = (await repo.fetch(course)).sections.single.lessons.single;
    expect(revoked.mobileContent, false);
    expect(revoked.isVideoCandidate, false);
    expect(revoked.ipexVideoUrl, isNull);
    expect(revoked.ipexCaptionsUrl, isNull);
  });

  test('navegação URL maliciosa não entra no player', () async {
    final bad = [
      source.replaceFirst('ead.ipexdesenvolvimento.cloud', 'evil.example'),
      source.replaceFirst('https:', 'http:'),
      source.replaceFirst('/tutor-tds/', '/uploads/'),
      '$source?token=unknown',
      source.replaceFirst('/saf/', '/%2e%2e/saf/'),
      source.replaceFirst('.mp4', '.m3u8'),
    ];
    for (final url in bad) {
      // Uri.parse canonicalizes %2e%2e before it becomes a Uri.
      // The repository validates the ORIGINAL response string first.
      if (!url.contains('%2e')) {
        expect(
          EadIpexVideoPolicy.allows(Uri.parse(url), '.mp4'),
          false,
          reason: url,
        );
      }
      final malicious = <String, String>{...media, 'source_url': url};
      final repo = EadEditorialBridgeRepository(
        get: (_, _) async => lesson(malicious),
      );
      await expectLater(repo.lesson(course, 1299), throwsException);
    }
  });

  test('HTML5 mantém MP4 e renderiza legenda fora do vídeo', () {
    final document = EadIpexVideoPolicy.document(
      Uri.parse(source),
      Uri.parse(captions),
    );
    expect(document, contains('type="video/mp4"'));
    expect(document, contains('kind="captions"'));
    expect(document, contains('srclang="pt-BR"'));
    expect(document, contains('preload="metadata"'));
    expect(document, contains('controls playsinline'));
    expect(document, isNot(contains('autoplay')));
    expect(document, isNot(contains(' default>')));
    expect(document, contains("item.mode = 'hidden'"));
    expect(document, contains("track.addEventListener('cuechange', render)"));
    expect(document, contains('output.textContent = cues'));
    expect(document, contains('</video><div id="caption-panel">'));
    expect(document, contains('aria-controls="caption-text"'));
    expect(document, contains('aria-pressed="true"'));
    expect(document, contains('Ocultar legendas'));
    expect(document, contains('Mostrar legendas'));
    expect(document, contains('aria-live="polite"'));
    final nonce = RegExp(r'<script nonce="([^"]+)">')
        .firstMatch(document)
        ?.group(1);
    expect(nonce, isNotNull);
    expect(document, contains('script-src &#39;nonce-$nonce&#39;'));
    expect(document, isNot(contains('script-src &#39;unsafe-inline&#39;')));
    expect(
      document,
      contains('media-src https://ead.ipexdesenvolvimento.cloud'),
    );
    expect(document, contains('connect-src &#39;none&#39;'));
    expect(document, isNot(contains('http://')));
    expect(
      () => EadIpexVideoPolicy.document(
        Uri.parse('https://evil.example/a.mp4'),
        null,
      ),
      throwsFormatException,
    );
  });

  test('sem VTT não injeta controle nem habilita script no documento', () {
    final document = EadIpexVideoPolicy.document(Uri.parse(source), null);
    expect(document, isNot(contains('<track')));
    expect(document, isNot(contains('<button id="caption-toggle"')));
    expect(document, isNot(contains('<script')));
    expect(document, contains('script-src &#39;none&#39;'));
    expect(document, contains('controls playsinline'));
  });

  test('URLs permitidas são escapadas como atributo, sem HTML remoto', () {
    final video = Uri.parse(source.replaceFirst('.mp4', '&extra.mp4'));
    final document = EadIpexVideoPolicy.document(video, Uri.parse(captions));
    expect(document, contains('FHD&amp;extra.mp4'));
    expect(document, isNot(contains('FHD&extra.mp4')));
    final encoded = Uri.parse(
      source.replaceFirst('.mp4', '%3Cscript%3Ealert(1)%3Cscript%3E.mp4'),
    );
    expect(EadIpexVideoPolicy.allows(encoded, '.mp4'), true);
    expect(
      EadIpexVideoPolicy.document(encoded, null),
      isNot(contains('<script>alert(1)')),
    );
  });

  testWidgets('área de legenda só amplia o player quando há VTT', (
    tester,
  ) async {
    Future<void> show(Uri? vtt) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EadIpexVideoPlayerScreen(
            video: Uri.parse(source),
            captions: vtt,
            lessonTitle: 'Aula SAF',
            playerFactory: (_, _, _, _) => const Text('PLAYER'),
          ),
        ),
      );
      await tester.pump();
    }

    await show(Uri.parse(captions));
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1);
    await show(null);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      16 / 9,
    );
  });

  testWidgets('aula autorizada mostra CTA MP4 e player dentro do app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: EadMobileLessonScreen(
          course: course,
          lessonId: 1299,
          loader: (_, _) async => EadEditorialLesson(
            courseId: 1298,
            lessonId: 1299,
            title: 'Aula SAF',
            contentHtml: '<p>Conteúdo publicado.</p>',
            revision: revision,
            ipexVideoUrl: Uri.parse(source),
            ipexCaptionsUrl: Uri.parse(captions),
          ),
          ipexVideoViewFactory: (_, _, onReady, _) {
            onReady();
            return const Text('PLAYER_HTTPS_IPEX');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assistir vídeo no IPEX'), findsOneWidget);
    await tester.tap(find.text('Assistir vídeo no IPEX'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Videoaula do IPEX'), findsOneWidget);
    expect(find.text('PLAYER_HTTPS_IPEX'), findsOneWidget);
    expect(find.textContaining('não registra'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Videoaula do IPEX'), findsNothing);
    expect(find.text('Assistir vídeo no IPEX'), findsOneWidget);
  });
}
