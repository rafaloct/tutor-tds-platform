import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const course = EadCourse(
  id: 1356,
  slug: 'saf',
  title: 'Sistemas Agroflorestais',
);
const emptyCourse = EadCourse(
  id: 1709,
  slug: 'ia-processos-internos',
  title: 'IA interna',
);

EadCurriculum fixture(EadCourse forCourse) => EadCurriculum(
  course: forCourse,
  sections: const [
    EadSection(
      id: 72,
      title: 'O que é um SAF?',
      lessons: [
        EadLesson(
          id: 1357,
          title: 'O que é um SAF?',
          type: 'lp_lesson',
          isVideoCandidate: false,
        ),
      ],
    ),
    EadSection(
      id: 80,
      title: 'Assista em vídeo',
      lessons: [
        EadLesson(
          id: 1425,
          title: 'Aula 01 - SAF',
          type: 'lp_lesson',
          isVideoCandidate: true,
        ),
        EadLesson(
          id: 1426,
          title: 'Aula 02 - Prática',
          type: 'lp_lesson',
          isVideoCandidate: true,
        ),
      ],
    ),
  ],
);

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(480, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUpAll(() async {
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf')))
        .load();
  });

  const cases = [
    (
      sections: 0,
      items: 0,
      summary: '0 seções · 0 itens de aula · 0 aulas em seções de vídeo',
    ),
    (
      sections: 1,
      items: 0,
      summary: '1 seção · 0 itens de aula · 0 aulas em seções de vídeo',
    ),
    (
      sections: 1,
      items: 1,
      summary: '1 seção · 1 item de aula · 1 aula em seções de vídeo',
    ),
    (
      sections: 2,
      items: 2,
      summary: '2 seções · 2 itens de aula · 2 aulas em seções de vídeo',
    ),
  ];
  for (final width in [360.0, 390.0, 450.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        for (final sample in cases) {
          testWidgets('percurso ${sample.sections} seções/${sample.items} itens '
              '$width px escala $scale dark=$dark', (tester) async {
            tester.view.physicalSize = Size(width, 920);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final data = EadCurriculum(
              course: course,
              sections: List.generate(
                sample.sections,
                (section) => EadSection(
                  id: section + 1,
                  title: 'Seção de vídeo ${section + 1}',
                  lessons: List.generate(
                    section == 0 ? sample.items : 0,
                    (item) => EadLesson(
                      id: item + 1,
                      title: 'Aula de vídeo ${item + 1}',
                      type: 'lp_lesson',
                      isVideoCandidate: true,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EadLearningPathScreen(
                          course: course,
                          curriculumLoader: (_) async => data,
                        ),
                      ),
                    ),
                    child: const Text('Abrir percurso'),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Abrir percurso'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(BackButton), findsOneWidget);
            expect(find.byTooltip('Atualizar percurso'), findsOneWidget);
            final title = find.text('Percurso');
            final paragraph = tester.renderObject<RenderParagraph>(title);
            expect(paragraph.didExceedMaxLines, isFalse);
            final titleRect = tester.getRect(title);
            final toolbarRect = tester.getRect(find.byType(AppBar));
            expect(toolbarRect.contains(titleRect.topLeft), isTrue);
            expect(toolbarRect.contains(titleRect.bottomRight), isTrue);
            expect(find.text(sample.summary), findsOneWidget);
            if (sample.sections > 0) {
              final section = find.byKey(const ValueKey('section-1'));
              await tester.ensureVisible(section);
              await tester.pumpAndSettle();
              expect(
                find.descendant(
                  of: section,
                  matching: find.text(
                    sample.items == 1 ? '1 item' : '${sample.items} itens',
                  ),
                ),
                findsOneWidget,
              );
            }
            // Scroll through the complete curriculum to lay out lazy children.
            await tester.drag(find.byType(ListView), const Offset(0, -1600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('curso SAF mostra vídeo, cartilha e prática sem importar prova', (
    tester,
  ) async {
    viewport(tester);
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (c) async => fixture(c),
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Percurso'), findsOneWidget);
    expect(
      find.text('2 seções · 3 itens de aula · 2 aulas em seções de vídeo'),
      findsOneWidget,
    );
    expect(find.text('Aula 01 - SAF'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-native-cartilha')),
      findsOneWidget,
    );
    await tester.tap(find.text('Assistir videoaulas no EAD'));
    await tester.pump();
    expect(
      opened!.toString(),
      'https://ead.ipexdesenvolvimento.cloud/courses/saf/',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('curso sem cartilha não fabrica tutor contextual', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadLearningPathScreen(
          course: emptyCourse,
          curriculumLoader: (c) async =>
              EadCurriculum(course: c, sections: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ainda não possui cartilha'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-native-cartilha')),
      findsNothing,
    );
  });

  testWidgets('falha de rede deixa o erro visível sem inventar aulas', (
    tester,
  ) async {
    viewport(tester);
    var online = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (c) async {
            if (!online) throw const EadCurriculumException('indisponível');
            return fixture(c);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível consultar'), findsOneWidget);
    expect(find.text('Aula 01 - SAF'), findsNothing);
    online = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aula 01 - SAF'), findsOneWidget);
  });
}
