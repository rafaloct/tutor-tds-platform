import 'package:cartilhas_app/features/course_editor/data/course_editor_repository.dart';
import 'package:cartilhas_app/features/course_editor/models/course_editor_models.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_editor_screen.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_structure_editor.dart';
import 'package:cartilhas_app/features/course_editor/presentation/message_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'course_editor_repository_test.dart' show courseJson;

class _Gateway implements CourseEditorGateway {
  Map<String, dynamic> data = courseJson();
  List<EditorProgram> allowed = const [
    EditorProgram(id: 'p', name: 'Programa', canCreate: true),
  ];
  bool conflict = false;
  int saves = 0;
  int loads = 0;
  String? action;
  @override
  Future<List<EditorProgram>> programs() async => allowed;
  @override
  Future<List<EditableCourse>> courses(String programId) async => [
    EditableCourse.fromJson(data),
  ];
  @override
  Future<EditableCourse> course(String courseId, {String? versionId}) async {
    loads++;
    return EditableCourse.fromJson(data);
  }

  @override
  Future<EditableCourse> create({
    required String programId,
    required String courseId,
    required String title,
    required String author,
  }) async => EditableCourse.fromJson(data);
  @override
  Future<EditableCourse> save(EditableCourse course) async {
    saves++;
    if (conflict) {
      throw const CourseEditorException('Conflito de revisão.', conflict: true);
    }
    data = {...course.data, 'revision': course.revision + 1};
    return EditableCourse.fromJson(data);
  }

  @override
  Future<EditableCourse> transition(
    EditableCourse course,
    String action,
  ) async {
    this.action = action;
    data = {
      ...data,
      'status': 'in_review',
      'can_edit': false,
      'can_submit': false,
    };
    return EditableCourse.fromJson(data);
  }

  @override
  Future<EditableCourse> fork(EditableCourse course) async =>
      EditableCourse.fromJson({
        ...data,
        'version_id': 'new-version',
        'status': 'draft',
        'can_edit': true,
        'can_fork': false,
      });
}

Future<void> openEditor(
  WidgetTester tester,
  CourseEditorGateway gateway,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CourseStructureEditor(
        gateway: gateway,
        courseId: 'horta',
        versionId: 'version-1',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await revealEditorAction(tester, text);
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> revealEditorAction(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(
    tester.element(find.text(text)),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editor adds, saves, edits and removes a module material', (
    tester,
  ) async {
    final gateway = _Gateway();
    await openEditor(tester, gateway);
    await tapVisible(tester, 'Adicionar material');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título do material'),
      'PDF remoto',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'URL pública HTTPS'),
      'https://example.org/a.pdf',
    );
    await tester.tap(find.text('Aplicar material'));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Salvar rascunho');
    final material =
        ((gateway.data['sections'] as List).first['materials'] as List).single;
    expect(material['kind'], 'pdf');
    expect(material['url'], 'https://example.org/a.pdf');
    final id = material['id'];
    await tapVisible(tester, 'PDF remoto');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título do material'),
      'PDF revisado',
    );
    await tester.tap(find.text('Aplicar material'));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Salvar rascunho');
    expect(
      ((gateway.data['sections'] as List).first['materials'] as List)
          .single['id'],
      id,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Remover material')),
    );
    await tester.tap(find.byTooltip('Remover material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Salvar rascunho');
    expect((gateway.data['sections'] as List).first['materials'], isEmpty);
  });
  testWidgets('back navigation asks before discarding unsaved draft', (
    tester,
  ) async {
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CourseStructureEditor(
                    gateway: gateway,
                    courseId: 'horta',
                    versionId: 'version-1',
                  ),
                ),
              ),
              child: const Text('Abrir curso'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir curso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Não perder');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Não perder'), findsOneWidget);
    expect(gateway.saves, 0);
  });
  testWidgets('no scoped programs means no creation entrypoint', (
    tester,
  ) async {
    final gateway = _Gateway()..allowed = [];
    await tester.pumpWidget(
      MaterialApp(home: CourseEditorCatalogScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Criar curso'), findsNothing);
    expect(find.textContaining('não possui programas'), findsOneWidget);
  });
  testWidgets('published version is read only and supports a new draft', (
    tester,
  ) async {
    final gateway = _Gateway();
    gateway.data = {
      ...gateway.data,
      'status': 'published',
      'can_edit': false,
      'can_submit': false,
      'can_fork': true,
    };
    await openEditor(tester, gateway);
    expect(find.text('Salvar rascunho'), findsNothing);
    expect(find.text('Publicar'), findsNothing);
    await tapVisible(tester, 'Criar nova versão');
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Salvar rascunho'), findsOneWidget);
    expect(gateway.saves, 0);
  });
  testWidgets('409 preserves unsaved changes and requires explicit reload', (
    tester,
  ) async {
    final gateway = _Gateway()..conflict = true;
    await openEditor(tester, gateway);
    await tester.enterText(find.byType(TextField).first, 'Mudança local');
    await tapVisible(tester, 'Salvar rascunho');
    expect(gateway.saves, 1);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Salvar rascunho'),
    );
    expect(save.onPressed, isNull);
    await tapVisible(tester, 'Recarregar versão do servidor');
    expect(
      find.text('Suas alterações não salvas serão descartadas.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Mudança local'), findsOneWidget);
    expect(gateway.loads, 1);
    await tapVisible(tester, 'Recarregar versão do servidor');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(gateway.loads, 2);
    expect(find.text('Alterações não salvas'), findsNothing);
  });
  testWidgets('submit is gated until save and then locks the revision', (
    tester,
  ) async {
    final gateway = _Gateway();
    await openEditor(tester, gateway);
    await tester.enterText(find.byType(TextField).first, 'Novo título');
    await tester.pumpAndSettle();
    await revealEditorAction(tester, 'Enviar para revisão');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar para revisão'),
          )
          .onPressed,
      isNull,
    );
    await tapVisible(tester, 'Salvar rascunho');
    await tapVisible(tester, 'Enviar para revisão');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(gateway.action, 'submit');
    expect(find.text('Salvar rascunho'), findsNothing);
  });
  testWidgets(
    'editing structured message preserves all unknown fields and IDs',
    (tester) async {
      Map<String, dynamic>? result;
      final original = {
        'id': 'content-1',
        'version_id': 'v1',
        'type': 'bot',
        'content': 'Antes',
        'custom': {'preserve': true},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => MessageEditorDialog(message: original),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Conteúdo'),
        'Depois',
      );
      await tester.tap(find.text('Aplicar mensagem'));
      await tester.pumpAndSettle();
      expect(result, {...original, 'content': 'Depois'});
      expect(original['content'], 'Antes');
    },
  );
}
