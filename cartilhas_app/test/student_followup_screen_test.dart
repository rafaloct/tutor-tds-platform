import 'dart:convert';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/student_followup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'student_followup_repository_test.dart' show FollowupAuth;

void main() {
  Future<ClassroomRepository> showScreen(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) handler,
  }) async {
    final repo = ClassroomRepository(
      apiUrl: 'https://example.test',
      authRepository: FollowupAuth(),
      client: MockClient(handler),
    );
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFollowupScreen(
          repository: repo,
          staffId: 'teacher',
          classroom: ClassroomDetails(
            id: 'class-a',
            programId: 'p',
            courseId: 'c',
            teacherId: 'teacher',
            name: 'Turma A',
            startDate: DateTime(2026),
            endDate: DateTime(2027),
            status: 'active',
            studentIds: ['s'],
            monitorIds: [],
          ),
          students: [
            ClassroomStudent(
              userId: 's',
              name: 'Ana',
              enrollmentId: 'e',
              status: 'active',
              plannedHours: 10,
              validatedHours: 0,
              progressPercent: 0,
              lastActivityAt: null,
              inactiveDays: null,
              alerts: [],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'baseline requires explicit confirmation and cancel does not write',
    (tester) async {
      var writes = 0;
      await showScreen(
        tester,
        handler: (request) async {
          if (request.method != 'GET') writes++;
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/baseline')
                  ? {'baseline': null, 'history': []}
                  : {'items': [], 'total': 0},
            ),
            200,
          );
        },
      );
      expect(find.text('Baseline ainda não vinculado'), findsOneWidget);
      await tester.tap(find.text('Conferir vínculo do baseline'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar online'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('authorization failure shows no editable followup data', (
    tester,
  ) async {
    await showScreen(
      tester,
      handler: (_) async => http.Response('{"detail":"Acesso revogado"}', 403),
    );
    expect(find.text('Acesso revogado'), findsOneWidget);
    expect(find.text('Abrir mentoria'), findsNothing);
    expect(find.text('Conferir vínculo do baseline'), findsNothing);
  });

  testWidgets('existing mentorship displays responsible and next action', (
    tester,
  ) async {
    await showScreen(
      tester,
      handler: (request) async => http.Response(
        jsonEncode(
          request.url.path.endsWith('/baseline')
              ? {'baseline': null, 'history': []}
              : {
                  'items': [
                    {
                      'id': 'case',
                      'mentor_id': 'teacher',
                      'mentor_name': 'Professora',
                      'objective': 'Retomar estudo',
                      'next_action': 'Conversar na próxima aula',
                      'status': 'in_progress',
                      'revision': 1,
                    },
                  ],
                  'total': 1,
                },
        ),
        200,
      ),
    );
    expect(find.text('Retomar estudo'), findsOneWidget);
    expect(find.textContaining('Conversar na próxima aula'), findsOneWidget);
    expect(find.text('Em acompanhamento'), findsOneWidget);
  });
}
