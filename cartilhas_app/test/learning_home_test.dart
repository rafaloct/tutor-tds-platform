import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/learning_context/home_selection_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_home_controller.dart';
import 'package:cartilhas_app/features/learning_context/learning_home_card.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_context_test.dart' show contextPayload;

class HomeClasses implements LearnerClassroomGateway {
  List<String> ids = ['class-1'];
  String owner = 'student';
  bool wrongEdition = false;
  bool switchDuringList = false;
  @override
  Future<AuthUser> currentUser() async =>
      AuthUser(id: owner, name: 'Aluno', role: 'teacher');
  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async {
    if (switchDuringList) owner = 'other';
    return [
      for (final id in ids)
        ClassroomDetails(
          id: id,
          programId: 'program',
          courseId: 'course',
          teacherId: 'teacher',
          name: 'Turma $id',
          startDate: DateTime(2026),
          endDate: DateTime(2027),
          status: 'active',
          studentIds: const [],
          monitorIds: const [],
          courseVersionId: 'version-1',
        ),
    ];
  }

  @override
  Future<Cartilha> course(String classId) async => Cartilha(
    id: 'course',
    title: 'Curso da matrícula',
    author: 'TDS',
    sections: const [],
    classId: classId,
    versionNumber: 1,
    courseVersionId: wrongEdition ? 'wrong' : 'version-1',
  );
}

LearningHomeController controller(
  HomeClasses gateway,
  HomeSelectionRepository selection,
) {
  return LearningHomeController(
    gateway: gateway,
    selection: selection,
    contexts: FakeLearningContextRepository({
      for (final id in ['class-1', 'class-2'])
        id: LearningContextSnapshot.fromJson(contextPayload(cohort: id)),
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'one contextual membership resolves even with global teacher role',
    () async {
      final home = controller(HomeClasses(), FakeHomeSelectionRepository());
      addTearDown(home.dispose);
      await home.load();
      expect(home.state, LearningHomeState.ready);
      expect(home.contextController.snapshot!.context.role, 'student');
      expect(home.course!.classId, 'class-1');
      expect(home.contextController.snapshot!.progressPercent, 12.5);
    },
  );

  test(
    'parallel cohorts require choice; restart preserves only a still-valid choice',
    () async {
      final gateway = HomeClasses()..ids = ['class-1', 'class-2'];
      final selection = FakeHomeSelectionRepository();
      final first = controller(gateway, selection);
      await first.load();
      expect(first.state, LearningHomeState.choose);
      expect(first.course, isNull);
      await first.load(selectedCohort: 'class-2');
      expect(first.course!.classId, 'class-2');
      first.dispose();
      final restarted = controller(gateway, selection);
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.course!.classId, 'class-2');
      gateway.ids = ['class-1'];
      await restarted.load(selectedCohort: 'class-2');
      expect(restarted.state, LearningHomeState.error);
      expect(restarted.course, isNull);
    },
  );

  test(
    'empty, edition mismatch and account switch never yield a study target',
    () async {
      for (final gateway in [
        HomeClasses()..ids = [],
        HomeClasses()..wrongEdition = true,
        HomeClasses()..switchDuringList = true,
      ]) {
        final home = controller(gateway, FakeHomeSelectionRepository());
        await home.load();
        expect(home.course, isNull);
        expect(
          home.state,
          gateway.ids.isEmpty
              ? LearningHomeState.empty
              : LearningHomeState.error,
        );
        home.dispose();
      }
    },
  );

  test('saved choice is isolated by account and API environment', () async {
    final stage = LocalHomeSelectionRepository('https://stage.example/');
    await stage.write('student', 'class-2');
    expect(
      await LocalHomeSelectionRepository(
        'https://stage.example',
      ).read('student'),
      'class-2',
    );
    expect(await stage.read('other'), isNull);
    expect(
      await LocalHomeSelectionRepository(
        'https://production.example',
      ).read('student'),
      isNull,
    );
  });

  testWidgets('contextual home stays usable when public catalog fails', (
    tester,
  ) async {
    final home = controller(HomeClasses(), FakeHomeSelectionRepository());
    addTearDown(home.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          learningHomeController: home,
          courseLoader: () async =>
              throw const ClassroomException('Catalog unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sua aprendizagem'), findsOneWidget);
    expect(find.text('Continuar estudo'), findsOneWidget);
    expect(find.textContaining('Turma class-1'), findsOneWidget);
    expect(find.text('Progresso confirmado: 13%'), findsOneWidget);
    await tester.tap(find.text('Trocar turma'));
    await tester.pumpAndSettle();
    expect(
      find.text('Escolha a turma em que você quer estudar.'),
      findsOneWidget,
    );
    expect(find.text('Continuar estudo'), findsNothing);
  });

  testWidgets('context card remains legible at 320px and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final home = controller(HomeClasses(), FakeHomeSelectionRepository());
    addTearDown(home.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(children: [LearningHomeCard(controller: home)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continuar estudo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
