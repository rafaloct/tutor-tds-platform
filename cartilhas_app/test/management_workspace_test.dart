import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/application/team_capability.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/course_editor/data/course_editor_repository.dart';
import 'package:cartilhas_app/features/course_editor/models/course_editor_models.dart';
import 'package:cartilhas_app/features/management/presentation/management_workspace_screen.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EditorGateway implements CourseEditorGateway {
  @override
  Future<List<EditorProgram>> programs() async => const [
    EditorProgram(id: 'program', name: 'Programa TDS', canCreate: true),
  ];

  @override
  Future<List<EditableCourse>> courses(String programId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Cartilha _course() => Cartilha(
  id: 'course',
  title: 'Curso de teste',
  author: 'TDS',
  courseVersionId: 'version-1',
  versionNumber: 1,
  legacyProgressCompatible: false,
  sections: [
    Section(
      id: 'module',
      title: 'Módulo',
      messages: [Message(type: 'bot', content: 'Conteúdo')],
    ),
  ],
);

TeamCapabilitySnapshot _teamCapability() {
  final classroom = ClassroomDetails(
    id: 'class-1',
    programId: 'program',
    courseId: 'course',
    teacherId: 'staff-1',
    name: 'Turma piloto',
    startDate: DateTime.utc(2026, 10, 1),
    endDate: DateTime.utc(2026, 10, 2),
    status: 'active',
    studentIds: const [],
    monitorIds: const [],
  );
  return TeamCapabilitySnapshot(
    user: const AuthUser(id: 'staff-1', name: 'Equipe', role: 'teacher'),
    classrooms: [classroom],
    capabilities: const {'class-1': ClassroomStaffCapability.teacher},
  );
}

void _largeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('workspace mostra somente ferramentas autorizadas', (
    tester,
  ) async {
    _largeViewport(tester);
    var participants = 0;
    var contents = 0;
    var team = 0;
    var attendance = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ManagementWorkspaceScreen(
          operationScopeCount: 2,
          editorProgramCount: 1,
          teamCapability: _teamCapability(),
          onParticipantsTap: () => participants++,
          onContentTap: () => contents++,
          onTeamTap: () => team++,
          onAttendanceTap: () => attendance++,
        ),
      ),
    );

    expect(find.text('Gestão do programa'), findsOneWidget);
    expect(find.text('Participantes'), findsOneWidget);
    expect(find.text('Turmas e equipe'), findsOneWidget);
    expect(find.text('Registrar presença'), findsOneWidget);
    expect(find.text('Conteúdos'), findsOneWidget);

    await tester.tap(find.text('Participantes'));
    await tester.tap(find.text('Turmas e equipe'));
    await tester.tap(find.text('Registrar presença'));
    await tester.tap(find.text('Conteúdos'));

    expect(participants, 1);
    expect(contents, 1);
    expect(team, 1);
    expect(attendance, 1);
  });

  testWidgets('creator sem operação vê somente conteúdo', (tester) async {
    _largeViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ManagementWorkspaceScreen(
          operationScopeCount: 0,
          editorProgramCount: 1,
          teamCapability: null,
        ),
      ),
    );

    expect(find.text('Conteúdos'), findsOneWidget);
    expect(find.text('Participantes'), findsNothing);
    expect(find.text('Turmas e equipe'), findsNothing);
    expect(find.text('Registrar presença'), findsNothing);
  });

  testWidgets('home expõe Gestão por capacidade, não por login separado', (
    tester,
  ) async {
    _largeViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () async => [_course()],
          editorGatewayFactory: _EditorGateway.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gestão'), findsOneWidget);

    await tester.tap(find.text('Gestão'));
    await tester.pumpAndSettle();

    expect(find.text('Gestão do programa'), findsOneWidget);
    expect(find.text('Conteúdos'), findsOneWidget);
    expect(find.text('Participantes'), findsNothing);
  });

  testWidgets('menu agrupa atalhos administrativos em Gestão', (tester) async {
    _largeViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () async => [_course()],
          editorGatewayFactory: _EditorGateway.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();

    expect(find.text('Gestão'), findsWidgets);
    expect(find.text('Meus conteúdos'), findsNothing);
    expect(find.text('Operação de participantes'), findsNothing);
    expect(find.text('Área da equipe'), findsNothing);
    expect(find.text('Registrar presença'), findsNothing);
  });
}