import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/classroom_roster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Roster implements ClassroomRosterGateway {
  bool fail = false;
  final queries = <String>[];
  final offsets = <int>[];

  @override
  Future<EligibleStudentPage> eligibleStudents(
    String classId, {
    String query = '',
    int offset = 0,
  }) async {
    queries.add(query);
    offsets.add(offset);
    return EligibleStudentPage(
      students: [
        EligibleStudent(
          userId: '$offset',
          name: offset == 0 ? 'Ana Silva' : 'Beatriz Santos',
        ),
      ],
      nextOffset: offset == 0 ? 20 : null,
    );
  }

  @override
  Future<void> includeStudent(String classId, String userId) async {
    if (fail) {
      throw const ClassroomException(
        'Esta turma está encerrada e não pode receber estudantes.',
      );
    }
  }
}

void main() {
  final classroom = ClassroomDetails(
    id: 'a',
    programId: 'p',
    courseId: 'c',
    teacherId: 't',
    name: 'Turma Cerrado',
    startDate: DateTime(2026),
    endDate: DateTime(2026, 12),
    status: 'active',
    studentIds: const [],
    monitorIds: const [],
  );

  testWidgets(
    'busca por nome, carrega próxima página e mantém erro de inclusão',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _Roster()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ClassroomRosterScreen(classroom: classroom, gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Silva');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(gateway.queries.last, 'Silva');
      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(gateway.offsets.last, 20);
      expect(find.text('Beatriz Santos'), findsOneWidget);
      await tester.tap(find.text('Beatriz Santos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incluir na turma'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Esta turma está encerrada'), findsOneWidget);
      expect(find.textContaining('foi incluído'), findsNothing);
    },
  );

  testWidgets('inclusão suporta fonte ampliada em tela estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ClassroomRosterScreen(classroom: classroom, gateway: _Roster()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Incluir na turma'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
