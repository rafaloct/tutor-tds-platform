import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const course = EadCourse(id: 1356, slug: 'saf', title: 'SAF');
const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test(
    'formatação limitada vira blocos nativos acessíveis, sem executar HTML',
    () {
      final blocks = EadSafeHtmlBlocks.parse(
        '<h2>Agroecologia</h2><p>Uso &amp; prática.</p>'
        '<ul><li>Plantio</li><li>Água &#225;</li></ul>',
      );
      expect(blocks.map((x) => x.kind), ['h2', 'p', 'li', 'li']);
      expect(blocks.map((x) => x.text), [
        'Agroecologia',
        'Uso & prática.',
        'Plantio',
        'Água á',
      ]);
    },
  );

  testWidgets('exibe texto público, vídeo autorizado e mantém tema TDS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadMobileLessonScreen(
          course: course,
          lessonId: 1425,
          loader: (_, _) async => const EadEditorialLesson(
            courseId: 1356,
            lessonId: 1425,
            title: 'Aula agroecológica',
            contentHtml: '<h2>Como plantar</h2><p>Material homologado.</p>',
            revision: sha,
            youtubeId: 'FG14ksTaMCE',
          ),
          videoViewFactory: (_, onReady, onError) => const SizedBox.expand(),
          openExternal: (url) async {
            opened = url;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aula agroecológica'), findsOneWidget);
    expect(find.text('Como plantar'), findsOneWidget);
    expect(find.text('Material homologado.'), findsOneWidget);
    await tester.tap(find.text('Assistir vídeo aprovado'));
    await tester.pump();
    expect(opened, isNull);
    expect(find.text('Vídeo da aula'), findsOneWidget);
    expect(find.text('SAF'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Abrir no YouTube'));
    await tester.pump();
    expect(opened?.host, 'www.youtube.com');
    expect(opened?.queryParameters['v'], 'FG14ksTaMCE');
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Como plantar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final youtubeId in <String?>[null, 'invalid', 'FG14ksTaMCE\n']) {
    testWidgets('aula sem ID autorizado não oferece player: $youtubeId', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: EadMobileLessonScreen(
          course: course,
          lessonId: 1425,
          loader: (_, _) async => EadEditorialLesson(
            courseId: 1356,
            lessonId: 1425,
            title: 'Somente leitura',
            contentHtml: '<p>Texto autorizado.</p>',
            revision: sha,
            youtubeId: youtubeId,
          ),
          videoViewFactory: (_, onReady, onError) =>
              throw StateError('Vídeo não autorizado'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Texto autorizado.'), findsOneWidget);
      expect(find.text('Assistir vídeo aprovado'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('aula sem autorização exibe bloqueio, não fabrica texto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadMobileLessonScreen(
          course: course,
          lessonId: 1425,
          loader: (_, _) async => throw Exception('403'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('não está disponível'), findsOneWidget);
    expect(find.text('Material homologado.'), findsNothing);
  });
}
