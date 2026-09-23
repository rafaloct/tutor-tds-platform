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
  Future<void> fillField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
  }

  Future<ClassroomRepository> showScreen(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) handler,
  }) async {
    final repo = ClassroomRepository(
      apiUrl: 'https://example.test',
      authRepository: FollowupAuth(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/mentors')) {
          return http.Response(
            '{"mentors":[{"user_id":"teacher","name":"Professora"}]}',
            200,
          );
        }
        return handler(request);
      }),
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

  testWidgets('baseline save rereads server state with explicit consent', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    var writes = 0;
    await showScreen(
      tester,
      handler: (request) async {
        if (request.method == 'PUT') {
          writes++;
          saved = {
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'revision': 1,
          };
          return http.Response(jsonEncode(saved), 200);
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/baseline')
                ? {'baseline': saved, 'history': []}
                : {'items': [], 'total': 0},
          ),
          200,
        );
      },
    );
    await tester.tap(find.text('Conferir vínculo do baseline'));
    await tester.pumpAndSettle();
    Future<void> fill(String label, String value) async {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await fill('ID local do registro', 'tablet-123');
    await fill('Data da coleta (AAAA-MM-DD)', '2026-09-21');
    await fill('Justificativa da vinculação', 'Formulário conferido');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar online'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(saved!['expected_revision'], 0);
    expect(saved!['idempotency_key'], startsWith('followup-'));
    expect(find.text('Baseline vinculado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentorship creates, updates and rereads history', (
    tester,
  ) async {
    Map<String, dynamic>? item;
    final writes = <Map<String, dynamic>>[];
    await showScreen(
      tester,
      handler: (request) async {
        if (request.method == 'POST' || request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          writes.add(body);
          item = {
            ...body,
            'id': 'case-1',
            'mentor_name': 'Professora',
            'status': body['status'] ?? 'open',
            'revision': writes.length,
          };
          return http.Response(
            jsonEncode(item),
            request.method == 'POST' ? 201 : 200,
          );
        }
        if (request.url.path.endsWith('/case-1')) {
          return http.Response(
            jsonEncode({
              ...item!,
              'history': [
                {
                  'revision': 2,
                  'occurred_at': '2026-09-21T15:00:00Z',
                  'reason': 'Próximo passo combinado',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/baseline')
                ? {'baseline': null, 'history': []}
                : {
                    'items': [?item],
                    'total': item == null ? 0 : 1,
                  },
          ),
          200,
        );
      },
    );
    await tester.tap(find.text('Abrir mentoria'));
    await tester.pumpAndSettle();
    await fillField(tester, 'Objetivo', 'Retomar os estudos');
    await fillField(tester, 'Próxima ação', 'Conversar na aula');
    await fillField(tester, 'Justificativa', 'Pedido do aluno');
    await tester.tap(find.text('Salvar online'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(writes.single['mentor_id'], 'teacher');
    expect(find.text('Retomar os estudos'), findsOneWidget);
    await tester.ensureVisible(find.text('Atualizar mentoria'));
    await tester.tap(find.text('Atualizar mentoria'));
    await tester.pumpAndSettle();
    await fillField(tester, 'Próxima ação', 'Rever progresso na sexta');
    await fillField(tester, 'Justificativa', 'Próximo passo combinado');
    await tester.tap(find.text('Salvar online'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(writes.last['expected_revision'], 1);
    expect(writes.length, 2);
    expect(find.textContaining('Rever progresso na sexta'), findsOneWidget);
    await tester.ensureVisible(find.text('Histórico da mentoria'));
    await tester.tap(find.text('Histórico da mentoria'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Próximo passo combinado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
