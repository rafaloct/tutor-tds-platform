import 'dart:async';
import 'dart:convert';
import 'package:cartilhas_app/features/remote_materials/course_material.dart';
import 'package:cartilhas_app/features/remote_materials/module_materials_screen.dart';
import 'package:cartilhas_app/features/course_editor/presentation/material_editor_dialog.dart';
import 'package:cartilhas_app/features/courses/application/course_pdf_controller.dart';
import 'package:cartilhas_app/features/courses/data/course_repository.dart';
import 'package:cartilhas_app/features/media/data/media_repository.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media_repository_test.dart' show item;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final manifest = [
    {
      'id': 'pdf',
      'kind': 'pdf',
      'title': 'Leitura',
      'url': 'https://example.org/a.pdf',
    },
    {
      'id': 'link',
      'kind': 'link',
      'title': 'Referência',
      'url': 'https://example.org/site',
    },
    {'id': 'video', 'kind': 'video', 'title': 'Vídeo', 'media_id': 'media-1'},
  ];
  test(
    'catalog refresh changes three materials without recreating repository; cache preserves them',
    () async {
      var revision = 1;
      var offline = false;
      final repository = CourseRepository.forCatalog(
        apiUrl: 'https://api.example',
        remoteCatalogEnabled: true,
        localLoader: () async => [],
        httpGet: (_) async => offline
            ? http.Response('', 503)
            : http.Response(
                jsonEncode([
                  {
                    'id': 'course-1',
                    'title': 'Curso',
                    'author': 'TDS',
                    'course_version_id': 'edition-$revision',
                    'sections': [
                      {
                        'id': 'module-1',
                        'title': 'Módulo',
                        'messages': [],
                        'materials': manifest
                            .map(
                              (m) => {...m, 'title': '${m['title']} $revision'},
                            )
                            .toList(),
                      },
                    ],
                  },
                ]),
                200,
              ),
      );
      final old = (await repository.fetchAll()).single;
      revision = 2;
      final updated = (await repository.fetchAll()).single;
      expect(old.sections.single.materials.map((m) => m.title), [
        'Leitura 1',
        'Referência 1',
        'Vídeo 1',
      ]);
      expect(updated.sections.single.materials.map((m) => m.title), [
        'Leitura 2',
        'Referência 2',
        'Vídeo 2',
      ]);
      offline = true;
      expect(
        (await repository.fetchAll())
            .single
            .sections
            .single
            .materials
            .last
            .mediaId,
        'media-1',
      );
      expect(
        Section.fromJson({
          'id': 'legacy',
          'title': 'Legado',
          'messages': [],
        }).materials,
        isEmpty,
      );
    },
  );
  test('unsafe links and mixed video destinations rejected', () {
    for (final url in [
      'http://example.org/a',
      'https://user:pass@example.org/a',
      'https://example.org/a?token=x',
      'javascript:alert(1)',
      'https://127.0.0.1/a',
      'https://10.0.0.1/a',
      'https://[::1]/a',
      'https://localhost/a',
      'https://files.internal/a',
      'https://192.168.1.1/a',
      'https://example.org:65536/a',
      'https://example.org:abc/a',
      'https://example.org:8443/a',
    ]) {
      expect(
        () => CourseMaterial.fromJson({...manifest.first, 'url': url}),
        throwsFormatException,
      );
    }
    expect(
      () => CourseMaterial.fromJson({
        ...manifest.last,
        'url': 'https://example.org/a',
      }),
      throwsFormatException,
    );
  });
  test(
    'video detail preserves API prefix and rejects mismatches, block and offline despite cache',
    () async {
      SharedPreferences.setMockInitialValues({
        'media:catalog_cache:v1': jsonEncode([item('media-1', 'course-1')]),
      });
      var status = 200;
      var payload = item('media-1', 'course-1');
      final repository = MediaRepository(
        apiUrl: 'https://api.example/tutor-api',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.example/tutor-api/media/media-1',
          );
          return http.Response(jsonEncode(payload), status);
        }),
      );
      Future<Object> fetch() => repository.fetchPublishedById(
        'media-1',
        courseId: 'course-1',
        moduleId: 'module-1',
      );
      expect(await fetch(), isNotNull);
      for (final field in ['id', 'course_id', 'module_id', 'status']) {
        payload = {...item('media-1', 'course-1'), field: 'other'};
        await expectLater(fetch(), throwsA(isA<FormatException>()));
      }
      for (final code in [403, 404, 503]) {
        status = code;
        await expectLater(fetch(), throwsA(isA<MediaRepositoryException>()));
      }
      repository.dispose();
    },
  );
  testWidgets(
    'materials show external failure, loading and recoverable unavailable video',
    (tester) async {
      final pending = Completer<http.Response>();
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleMaterialsScreen(
            courseId: 'course-1',
            moduleId: 'module-1',
            materials: manifest.map(CourseMaterial.fromJson).toList(),
            externalController: CoursePdfController(launch: (_) async => false),
            repository: MediaRepository(
              apiUrl: 'https://api.example',
              client: MockClient((_) => pending.future),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Leitura'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Material indisponível.'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is ListTile &&
              widget.title is Text &&
              (widget.title as Text).data == 'Vídeo',
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(http.Response('', 404));
      await tester.pumpAndSettle();
      expect(find.textContaining('Material indisponível.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
  for (final material in manifest) {
    testWidgets(
      'editor preserves identity and destination for ${material['kind']}',
      (tester) async {
        Map<String, dynamic>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Editar'),
                  onPressed: () async {
                    result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => MaterialEditorDialog(material: material),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aplicar material'));
        await tester.pumpAndSettle();
        expect(result, material);
      },
    );
  }
}
