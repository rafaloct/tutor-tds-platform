import 'dart:async';

import 'package:cartilhas_app/features/course_editor/data/course_editor_repository.dart';
import 'package:cartilhas_app/features/course_editor/models/course_editor_models.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_editor_screen.dart';
import 'package:cartilhas_app/features/learning_context/home_selection_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_home_card.dart';
import 'package:cartilhas_app/features/study_ai/presentation/study_hub_screen.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_home_test.dart' show HomeClasses, controller;

Cartilha _edition(int version) => Cartilha(
  id: 'remote-course',
  title: 'Curso remoto edição $version',
  author: 'Equipe TDS',
  courseVersionId: 'version-$version',
  versionNumber: version,
  legacyProgressCompatible: false,
  sections: [
    Section(
      id: 'module',
      title: 'Introdução',
      messages: [Message(type: 'bot', content: 'Conteúdo remoto $version')],
    ),
  ],
);

class _EditorGateway implements CourseEditorGateway {
  @override
  Future<List<EditorProgram>> programs() async => const [
    EditorProgram(id: 'program', name: 'Programa editorial', canCreate: true),
  ];

  @override
  Future<List<EditableCourse>> courses(String programId) async => [];

  // This fixture only exercises the catalog entry and return, not publication.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mais opções'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _refresh(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text('Atualizar catálogo'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Finder get _refreshItem => find.byWidgetPredicate(
  (widget) =>
      widget is PopupMenuItem<String> && widget.value == 'refresh_catalog',
);

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('refresh is disabled during initial load and another refresh', (
    tester,
  ) async {
    _tallViewport(tester);
    final requests = <Completer<List<Cartilha>>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () {
            final next = Completer<List<Cartilha>>();
            requests.add(next);
            return next.future;
          },
        ),
      ),
    );
    await _openMenu(tester);
    expect(tester.widget<PopupMenuItem<String>>(_refreshItem).enabled, isFalse);
    await tester.tap(find.text('Atualizar catálogo'));
    await tester.pump();
    expect(requests, hasLength(1));
    await tester.tapAt(const Offset(20, 500));
    requests.single.complete([_edition(1)]);
    await tester.pumpAndSettle();

    await _refresh(tester);
    expect(requests, hasLength(2));
    await _openMenu(tester);
    expect(tester.widget<PopupMenuItem<String>>(_refreshItem).enabled, isFalse);
    await tester.tap(find.text('Atualizar catálogo'));
    await tester.pump();
    expect(requests, hasLength(2));
    await tester.tapAt(const Offset(20, 500));
    requests.last.complete([_edition(2)]);
    await tester.pumpAndSettle();
    expect(find.text('Curso remoto edição 2'), findsWidgets);
    expect(find.text('Curso remoto edição 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom learning destination waits for the refreshed edition', (
    tester,
  ) async {
    _tallViewport(tester);
    final next = Completer<List<Cartilha>>();
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () =>
              ++loads == 1 ? Future.value([_edition(1)]) : next.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _refresh(tester);
    await tester.tap(find.text('Aprender'));
    await tester.pump();
    expect(find.byType(StudyHubScreen), findsNothing);
    next.complete([_edition(2)]);
    await tester.pumpAndSettle();
    final study = tester.widget<StudyHubScreen>(find.byType(StudyHubScreen));
    expect(study.cartilhas.single.courseVersionId, 'version-2');
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty publication removes stale courses and keeps navigation safe',
    (tester) async {
      _tallViewport(tester);
      var courses = [_edition(1)];
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(courseLoader: () async => courses)),
      );
      await tester.pumpAndSettle();
      courses = [];
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma cartilha encontrada.'), findsOneWidget);
      expect(find.text('Curso remoto edição 1'), findsNothing);
      await tester.tap(find.text('Aprender'));
      await tester.pumpAndSettle();
      expect(find.byType(StudyHubScreen), findsNothing);
      expect(
        find.textContaining('Nenhum curso disponível para estudar.'),
        findsOneWidget,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog refresh preserves the enrolled edition and progress', (
    tester,
  ) async {
    _tallViewport(tester);
    final home = controller(HomeClasses(), FakeHomeSelectionRepository());
    addTearDown(home.dispose);
    var courses = [_edition(1)];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () async => courses,
          learningHomeController: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.state(find.byType(LearningHomeCard));
    final snapshot = home.contextController.snapshot!;
    final enrolledCourse = home.course;
    courses = [_edition(2)];
    await _refresh(tester);
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(LearningHomeCard)), card),
      isTrue,
    );
    expect(identical(home.course, enrolledCourse), isTrue);
    expect(identical(home.contextController.snapshot, snapshot), isTrue);
    expect(
      home.contextController.snapshot!.context.courseVersionId,
      'version-1',
    );
    expect(home.contextController.snapshot!.progressPercent, 12.5);
    expect(find.text('Curso remoto edição 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from the editor reloads once after the active request',
    (tester) async {
      _tallViewport(tester);
      final requests = <Completer<List<Cartilha>>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            editorGatewayFactory: _EditorGateway.new,
            courseLoader: () {
              final next = Completer<List<Cartilha>>();
              requests.add(next);
              return next.future;
            },
          ),
        ),
      );
      await _openMenu(tester);
      await tester.tap(find.text('Meus conteúdos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CourseEditorCatalogScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(requests, hasLength(1));
      requests.first.complete([_edition(1)]);
      await tester.pump();
      expect(requests, hasLength(2));
      requests.last.complete([_edition(2)]);
      await tester.pumpAndSettle();
      expect(find.text('Curso remoto edição 2'), findsWidgets);
      expect(find.text('Curso remoto edição 1'), findsNothing);
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
