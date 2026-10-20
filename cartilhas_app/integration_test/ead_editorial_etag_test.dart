import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:cartilhas_app/features/ead_catalog/qa/private_editorial_qa_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Focal transport/UI gate. The HTTP server runs only on Android loopback.
/// No WordPress, account, media permission or academic record is changed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android default client accepts gzip weak ETag and revalidates', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(PrivateEditorialQaBridge.enabled, isTrue);
    const revisionA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const revisionB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    var compressed = true;
    final requests = <Map<String, Object?>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18731);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final revision = compressed ? revisionA : revisionB;
      final etag = '${compressed ? 'W/' : ''}"$revision"';
      final conditional = request.headers.value('if-none-match');
      final status = conditional == etag ? 304 : 200;
      requests.add({
        'route': request.uri.queryParameters['rest_route'],
        'accept_encoding': request.headers.value('accept-encoding'),
        'if_none_match': conditional,
        'etag': etag,
        'status': status,
        'authorization': request.headers.value('authorization'),
        'cookie': request.headers.value('cookie'),
      });
      request.response.statusCode = status;
      request.response.headers.set('etag', etag);
      if (status == 200) {
        request.response.headers.contentType = ContentType.json;
        final body = utf8.encode(
          jsonEncode({
            'schema_version': 1,
            'authority': 'learnpress',
            'course_id': PrivateEditorialQaBridge.syntheticCourseId,
            'revision': revision,
            'sections': [
              {
                'id': 1,
                'title': 'QA isolado',
                'items': [
                  {
                    'id': PrivateEditorialQaBridge.syntheticLessonId,
                    'type': 'lp_lesson',
                    'title': compressed
                        ? 'ETag fraco gzip'
                        : 'ETag forte atualizado',
                    'mobile_content': false,
                    'media': null,
                  },
                ],
              },
            ],
          }),
        );
        if (compressed) {
          request.response.headers.set('content-encoding', 'gzip');
          request.response.add(gzip.encode(body));
        } else {
          request.response.add(body);
        }
      }
      await request.response.close();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: EadLearningPathScreen(
          course: EadCourse(
            id: PrivateEditorialQaBridge.syntheticCourseId,
            slug: 'etag-qa',
            title: 'ETag QA isolado',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ETag fraco gzip'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('ETag fraco gzip'), findsOneWidget);
    compressed = false;
    await tester.tap(find.byTooltip('Atualizar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('ETag forte atualizado'), findsOneWidget);
    expect(find.text('ETag fraco gzip'), findsNothing);
    await tester.tap(find.byTooltip('Atualizar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('ETag forte atualizado'), findsOneWidget);
    expect(requests.map((r) => r['status']), [200, 304, 200, 304]);
    expect(requests.map((r) => r['if_none_match']), [
      null,
      'W/"$revisionA"',
      'W/"$revisionA"',
      '"$revisionB"',
    ]);
    expect(requests.map((r) => r['accept_encoding']), everyElement('gzip'));
    expect(requests.map((r) => r['authorization']), everyElement(isNull));
    expect(requests.map((r) => r['cookie']), everyElement(isNull));
    expect(
      requests.map((r) => r['route']),
      everyElement('/tds-learning/v1/courses/12/curriculum'),
    );
    binding.reportData = {'issue': 303, 'requests': requests};
  });
}
