import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_repository.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements AuthTokenStore {
  AuthTokens? value = const AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _snapshot({
  String status = 'active',
  int revision = 4,
  bool canActivate = false,
  bool canClose = true,
  int openSessions = 0,
}) => {
  'classroom': {
    'id': 'class-1',
    'institution_id': 'institution-1',
    'program_id': 'program-1',
    'course_id': 'course-1',
    'course_version_id': 'version-7',
    'teacher_id': 'teacher-1',
    'monitor_ids': ['monitor-1'],
    'name': 'Turma Palmas — IA',
    'offer_municipality': 'Palmas',
    'offer_location': 'Laboratório',
    'start_date': '2026-10-11',
    'end_date': '2026-10-30',
    'status': status,
    'revision': revision,
  },
  'capacity': {
    'limit': 30,
    'occupancy': 26,
    'remaining': 4,
    'over_capacity': false,
    'exception': null,
  },
  'readiness': {
    'activation_blockers': <String>[],
    'can_activate': canActivate,
    'can_close': canClose,
    'closure_blockers': openSessions > 0 ? ['open_sessions'] : <String>[],
    'closure_warnings': {
      'open_sessions': openSessions,
      'pending_evidence': 1,
      'pending_makeup': 2,
      'pending_certificate_requests': 3,
    },
    'closure_warnings_block_close': false,
    'close_open_session_policy': 'HUMAN_GATE_CLOSE_WITH_OPEN_SESSION',
  },
  'capabilities': {
    'role': 'coordinator',
    'can_prepare': false,
    'can_change_team': true,
    'can_activate': canActivate,
    'can_close': canClose,
    'can_override_capacity': false,
  },
};

void main() {
  test('preparo após resposta perdida repete corpo e recibo sem outra turma', () async {
    final requests = <http.Request>[];
    final createdByReceipt = <String, Map<String, dynamic>>{};
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(),
      ),
      client: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['version_id'], 'version-7');
        final receiptId = body['id'] as String;
        final previous = createdByReceipt[receiptId];
        if (previous != null) return _jsonResponse(previous, 201);
        final committed = _snapshot(status: 'planned', revision: 1, canClose: false);
        createdByReceipt[receiptId] = committed;
        throw const SocketException('Resposta perdida após commit');
      }),
    );
    final command = PrepareClassroomCommand(
      className: 'Turma Palmas',
      offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório',
      institutionId: 'institution-1',
      programId: 'program-1',
      courseId: 'course-1',
      courseVersionId: 'version-7',
      startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30),
      teacherId: 'teacher-1',
      monitorIds: const ['monitor-1'],
    );

    await expectLater(repository.prepare(command), throwsA(isA<ClassLifecycleException>()));
    await expectLater(
      repository.prepare(PrepareClassroomCommand(
        className: 'Turma alterada',
        offerMunicipality: command.offerMunicipality,
        offerLocation: command.offerLocation,
        institutionId: command.institutionId,
        programId: command.programId,
        courseId: command.courseId,
        courseVersionId: command.courseVersionId,
        startDate: command.startDate,
        endDate: command.endDate,
        teacherId: command.teacherId,
        monitorIds: command.monitorIds,
      )),
      throwsA(isA<ClassLifecycleException>()),
    );
    expect(requests, hasLength(1));
    final result = await repository.prepare(command);
    expect(result.opaqueId, 'class-1');
    expect(createdByReceipt, hasLength(1));
    expect(requests, hasLength(2));
    expect(requests.first.body, requests.last.body);
  });

  test('version conflict releases pending receipt for confirmed new edition', () async {
    final receiptIds = <String>[];
    var optionsReads = 0;
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(),
      ),
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/operations/classes/options') {
          optionsReads++;
          return _jsonResponse({'options': [{
            'institution_id': 'institution-1',
            'program_id': 'program-1',
            'program_name': 'Programa TDS',
            'course_id': 'course-1',
            'course_title': 'IA',
            'course_version_id': optionsReads == 1 ? 'version-7' : 'version-8',
            'role': 'program_operator',
            'can_prepare': true,
            'can_activate': true,
            'can_close': true,
            'can_override_capacity': false,
          }]});
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        receiptIds.add(body['id'] as String);
        if (body['version_id'] == 'version-7') {
          return _jsonResponse({
            'detail': {'code': 'course_version_changed'},
          }, 409);
        }
        return _jsonResponse(_snapshot(status: 'planned', canClose: false), 201);
      }),
    );
    PrepareClassroomCommand command(String versionId) => PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: 'program-1', courseId: 'course-1',
      courseVersionId: versionId, startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const [],
    );

    expect((await repository.publishedVersion('course-1')).opaqueId, 'version-7');
    await expectLater(repository.prepare(command('version-7')),
        throwsA(isA<ClassVersionChangedException>()));
    expect((await repository.publishedVersion('course-1')).opaqueId, 'version-8');
    await repository.prepare(command('version-8'));
    expect(optionsReads, 2);
    expect(receiptIds, hasLength(2));
    expect(receiptIds.first, isNot(receiptIds.last));
  });

  test('integra options, turmas e candidatos do contrato #138', () async {
    final requests = <http.Request>[];
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(),
      ),
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer access-token');

        if (request.url.path == '/operations/classes/options') {
          return _jsonResponse({
            'options': [
              {
                'institution_id': 'institution-1',
                'program_id': 'program-1',
                'program_name': 'Programa TDS',
                'course_id': 'course-1',
                'course_title': 'Inteligência Artificial aplicada',
                'course_version_id': 'version-7',
                'version_number': 7,
                'role': 'coordinator',
                'can_prepare': true,
                'can_activate': true,
                'can_close': true,
                'can_override_capacity': false,
              },
            ],
          });
        }
        if (request.url.path == '/operations/classes') {
          return _jsonResponse({
            'classes': [_snapshot()],
          });
        }
        if (request.url.path == '/operations/classes/team-candidates') {
          expect(request.url.queryParameters, {'program_id': 'program-1'});
          return _jsonResponse({
            'program_id': 'program-1',
            'candidates': [
              {
                'user_id': 'teacher-1',
                'display_name': 'Professora responsável',
                'role': 'teacher',
              },
              {
                'user_id': 'monitor-1',
                'display_name': 'Monitor de campo',
                'role': 'monitor',
              },
            ],
          });
        }
        return http.Response('{}', 404);
      }),
    );

    final bootstrap = await repository.bootstrap();
    expect(bootstrap.capabilities.canPrepare, isTrue);
    expect(bootstrap.capabilities.canActivate, isTrue);
    expect(bootstrap.capabilities.canClose, isTrue);
    expect(bootstrap.capabilities.canOverrideCapacity, isFalse);
    expect(bootstrap.programs.single.name, 'Programa TDS');
    expect(bootstrap.manageableClasses.single.name, 'Turma Palmas — IA');
    expect(bootstrap.manageableClasses.single.statusLabel, 'Em andamento');

    final staff = await repository.staffForProgram('program-1');
    expect(staff, hasLength(2));
    expect(staff.first.kind, LifecycleStaffKind.teacher);
    expect(staff.last.kind, LifecycleStaffKind.monitor);

    expect(
      requests.map((request) => request.url.path),
      containsAll([
        '/operations/classes/options',
        '/operations/classes',
        '/operations/classes/team-candidates',
      ]),
    );
  });

  test('encerramento usa snapshot do servidor e envia CAS do #138', () async {
    final requests = <http.Request>[];
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example/',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(),
      ),
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/operations/classes/options') {
          return http.Response(
            jsonEncode({
              'options': [
                {
                  'institution_id': 'institution-1',
                  'program_id': 'program-1',
                  'program_name': 'Programa TDS',
                  'course_id': 'course-1',
                  'course_title': 'IA',
                  'course_version_id': 'version-7',
                  'version_number': 7,
                  'role': 'coordinator',
                  'can_prepare': true,
                  'can_activate': true,
                  'can_close': true,
                  'can_override_capacity': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/operations/classes') {
          return _jsonResponse({
            'classes': [_snapshot()],
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/operations/classes/class-1/readiness') {
          return _jsonResponse(_snapshot());
        }
        if (request.method == 'POST' &&
            request.url.path == '/operations/classes/class-1/transition') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['institution_id'], 'institution-1');
          expect(body['program_id'], 'program-1');
          expect(body['course_id'], 'course-1');
          expect(body['version_id'], 'version-7');
          expect(body['expected_revision'], 4);
          expect(body['target_status'], 'closed');
          expect(body['reason'], 'Atividades concluídas');
          expect(body['id'], isA<String>());
          return _jsonResponse(
            _snapshot(status: 'closed', revision: 5, canClose: false),
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await repository.bootstrap();
    final readiness = await repository.closeReadiness('class-1');
    expect(readiness.participants, 26);
    expect(readiness.pendingAttendance, 2);
    expect(readiness.pendingEvidence, 1);
    expect(readiness.pendingCertificateRequests, 3);
    expect(readiness.canClose, isTrue);

    final result = await repository.closeClassroom(
      classroomId: 'class-1',
      reason: 'Atividades concluídas',
    );
    expect(result.statusLabel, 'Encerrada');
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
  });

  test('operador ativa turma planejada com readiness e CAS do servidor', () async {
    final requests = <http.Request>[];
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(),
      ),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/operations/classes/options') {
          return _jsonResponse({
            'options': [{
              'institution_id': 'institution-1',
              'program_id': 'program-1',
              'program_name': 'Programa TDS',
              'course_id': 'course-1',
              'course_title': 'IA',
              'course_version_id': 'version-7',
              'role': 'program_operator',
              'can_prepare': true,
              'can_activate': true,
              'can_close': true,
              'can_override_capacity': false,
            }],
          });
        }
        if (request.method == 'GET' && request.url.path == '/operations/classes') {
          return _jsonResponse({'classes': [_snapshot(status: 'planned', canActivate: true, canClose: false)]});
        }
        if (request.method == 'GET' && request.url.path.endsWith('/readiness')) {
          return _jsonResponse(_snapshot(status: 'planned', canActivate: true, canClose: false));
        }
        if (request.method == 'POST' && request.url.path.endsWith('/transition')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['target_status'], 'active');
          expect(body['reason'], 'Oferta e equipe conferidas');
          expect(body['expected_revision'], 4);
          expect(body['version_id'], 'version-7');
          return _jsonResponse(_snapshot(status: 'active', revision: 5));
        }
        return http.Response('{}', 404);
      }),
    );

    final bootstrap = await repository.bootstrap();
    expect(bootstrap.capabilities.canActivate, isTrue);
    expect(bootstrap.manageableClasses.single.status, 'planned');
    final readiness = await repository.activationReadiness('class-1');
    expect(readiness.canActivate, isTrue);
    final result = await repository.activateClassroom(
      classroomId: 'class-1', reason: 'Oferta e equipe conferidas',
    );
    expect(result.statusLabel, 'Em andamento');
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
  });

  test(
    'sessão aberta do #138 bloqueia close com mensagem operacional',
    () async {
      final repository = ClassLifecycleRepository(
        apiUrl: 'https://api.example',
        authRepository: AuthRepository(
          apiUrl: 'https://api.example',
          tokenStore: _TokenStore(),
        ),
        client: MockClient((request) async {
          if (request.url.path == '/operations/classes/class-1/readiness') {
            return _jsonResponse(_snapshot(canClose: false, openSessions: 1));
          }
          return _jsonResponse({});
        }),
      );

      final readiness = await repository.closeReadiness('class-1');
      expect(readiness.canClose, isFalse);
      expect(readiness.openSessions, 1);
      expect(
        readiness.blockers,
        contains(
          'Encerre todos os encontros em aberto antes de encerrar a turma.',
        ),
      );
    },
  );
}
