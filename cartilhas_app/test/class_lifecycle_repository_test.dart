import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/class_lifecycle/application/class_lifecycle_controller.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_repository.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/pending_class_prepare_store.dart';
import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements AuthTokenStore {
  _TokenStore({String accessToken = 'access-token'})
    : value = AuthTokens(
        accessToken: accessToken,
        refreshToken: 'refresh-token',
      );

  AuthTokens? value;
  int reads = 0;
  int? replaceOnRead;
  String? replacementAccessToken;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async {
    reads++;
    if (reads == replaceOnRead) {
      value = AuthTokens(
        accessToken: replacementAccessToken!,
        refreshToken: 'refresh-token',
      );
    }
    return value;
  }

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

String _jwt(String subject) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': subject})));
  return 'header.$payload.signature';
}

class _PendingStore implements PendingClassPrepareStore {
  final values = <String, String>{};
  bool failWrite = false;
  bool failRead = false;

  @override
  Future<String?> read(String scope) async {
    if (failRead) throw const FileSystemException('storage unavailable');
    return values[scope];
  }

  @override
  Future<void> write(String scope, String body) async {
    if (failWrite) throw const FileSystemException('storage unavailable');
    values[scope] = body;
  }

  @override
  Future<void> clear(String scope) async {
    values.remove(scope);
  }
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
  test('armazenamento seguro mantém recibo entre instâncias e separa contas', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = SecurePendingClassPrepareStore();
    await first.write('https://api.example\u0000operator-1', '{"id":"app-1"}');
    final reopened = SecurePendingClassPrepareStore();
    expect(
      await reopened.read('https://api.example\u0000operator-1'),
      '{"id":"app-1"}',
    );
    expect(await reopened.read('https://api.example\u0000operator-2'), isNull);
    expect(
      await reopened.read('https://another-api.example\u0000operator-1'),
      isNull,
    );
    await reopened.clear('https://api.example\u0000operator-1');
    expect(await first.read('https://api.example\u0000operator-1'), isNull);
  });

  test('preparo após resposta perdida repete corpo e recibo sem outra turma', () async {
    final requests = <http.Request>[];
    final createdByReceipt = <String, Map<String, dynamic>>{};
    final pendingStore = _PendingStore();
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
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
    expect(requests, hasLength(1));
    final result = await repository.prepare(PrepareClassroomCommand(
      className: 'Outra turma digitada após a falha',
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
    ));
    expect(result.opaqueId, 'class-1');
    expect(createdByReceipt, hasLength(1));
    expect(requests, hasLength(2));
    expect(requests.first.body, requests.last.body);
    expect(pendingStore.values, isEmpty);
  });

  test('reentrada recupera recibo pendente antes de outro preparo', () async {
    final pendingStore = _PendingStore();
    final posts = <String>[];
    final committed = <String, Map<String, dynamic>>{};
    final first = ClassLifecycleRepository(
      apiUrl: 'https://api.example/',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        posts.add(request.body);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        committed[body['id'] as String] =
            _snapshot(status: 'planned', revision: 1, canClose: false);
        throw const SocketException('Resposta perdida após commit');
      }),
    );
    final command = PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: 'program-1', courseId: 'course-1',
      courseVersionId: 'version-7', startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const ['monitor-1'],
    );
    await expectLater(first.prepare(command), throwsA(isA<ClassLifecycleException>()));
    expect(pendingStore.values, hasLength(1));

    final anotherAccount = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-2')),
      ),
      pendingPrepareStore: pendingStore,
    );
    expect(await anotherAccount.reconcilePendingPreparation(), isNull);

    // HomeScreen constructs a fresh repository when the preparation screen
    // is opened again. A process restart has the same persisted-store path.
    var replayStatus = 422;
    final reopened = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts.add(request.body);
          if (replayStatus != 201) return http.Response('{}', replayStatus);
          final id = (jsonDecode(request.body) as Map<String, dynamic>)['id'];
          return _jsonResponse(committed[id]!, 201);
        }
        if (request.url.path == '/operations/classes/options') {
          return _jsonResponse({'options': [{
            'institution_id': 'institution-1', 'program_id': 'program-1',
            'program_name': 'Programa TDS', 'course_id': 'course-1',
            'course_title': 'IA', 'course_version_id': 'version-7',
            'can_prepare': true, 'can_activate': true, 'can_close': true,
          }]});
        }
        if (request.url.path == '/operations/classes') {
          return _jsonResponse({'classes': [committed.values.single]});
        }
        return http.Response('{}', 404);
      }),
    );
    await expectLater(
      reopened.reconcilePendingPreparation(),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, hasLength(1));
    replayStatus = 403;
    await expectLater(
      reopened.reconcilePendingPreparation(),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, hasLength(1));
    replayStatus = 404;
    await expectLater(
      reopened.reconcilePendingPreparation(),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, hasLength(1));
    replayStatus = 201;
    final screenController = PrepareClassroomController(reopened);
    await screenController.load();
    expect(screenController.result?.opaqueId, 'class-1');
    expect(screenController.result?.name, 'Turma Palmas — IA');
    expect(posts, hasLength(5));
    expect(posts[1], posts.first);
    expect(posts[2], posts.first);
    expect(posts[3], posts.first);
    expect(posts.last, posts.first);
    expect(committed, hasLength(1));
    expect(pendingStore.values, isEmpty);
    screenController.dispose();
  });

  test('falha de armazenamento impede novo POST e mantém pendência', () async {
    final pendingStore = _PendingStore()..failWrite = true;
    var posts = 0;
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        posts++;
        return _jsonResponse(_snapshot(status: 'planned'), 201);
      }),
    );
    final command = PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: 'program-1', courseId: 'course-1',
      courseVersionId: 'version-7', startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const [],
    );
    await expectLater(repository.prepare(command), throwsA(isA<ClassLifecycleException>()));
    expect(posts, 0);
    pendingStore.failWrite = false;
    pendingStore.failRead = true;
    await expectLater(repository.prepare(command), throwsA(isA<ClassLifecycleException>()));
    expect(posts, 0);
    pendingStore.failRead = false;
    pendingStore.values['https://api.example\u0000operator-1'] =
        '{"schema":1,"body":{"id":"damaged"},"digest":"wrong"}';
    await expectLater(repository.prepare(command), throwsA(isA<ClassLifecycleException>()));
    expect(posts, 0);
  });

  test('403/404 iniciais liberam preparo em outro programa autorizado', () async {
    final pendingStore = _PendingStore();
    final requests = <Map<String, dynamic>>[];
    var rejectedStatus = 403;
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (body['program_id'] == 'program-revoked') {
          return http.Response('{}', rejectedStatus);
        }
        return _jsonResponse(_snapshot(status: 'planned', canClose: false), 201);
      }),
    );
    PrepareClassroomCommand command(String programId) => PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: programId, courseId: 'course-1',
      courseVersionId: 'version-7', startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const [],
    );

    await expectLater(
      repository.prepare(command('program-revoked')),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, isEmpty);
    rejectedStatus = 404;
    await expectLater(
      repository.prepare(command('program-revoked')),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, isEmpty);
    await repository.prepare(command('program-authorized'));
    expect(requests, hasLength(3));
    expect(requests.last['program_id'], 'program-authorized');
    expect(requests.last['id'], isNot(requests.first['id']));
    expect(requests.last['id'], isNot(requests[1]['id']));
  });

  test('troca de token antes do POST não envia preparo na conta nova', () async {
    final tokenStore = _TokenStore(accessToken: _jwt('operator-1'))
      ..replaceOnRead = 3
      ..replacementAccessToken = _jwt('operator-2');
    final pendingStore = _PendingStore();
    final requests = <Map<String, dynamic>>[];
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: tokenStore,
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _jsonResponse(_snapshot(status: 'planned', canClose: false), 201);
      }),
    );
    final command = PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: 'program-1', courseId: 'course-1',
      courseVersionId: 'version-7', startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const [],
    );

    await expectLater(
      repository.prepare(command),
      throwsA(isA<ClassLifecycleException>()),
    );
    expect(requests, isEmpty);
    expect(pendingStore.values, hasLength(1));
    final pending = jsonDecode(pendingStore.values.values.single)
        as Map<String, dynamic>;
    final pendingId = (pending['body'] as Map<String, dynamic>)['id'];

    tokenStore.value = AuthTokens(
      accessToken: _jwt('operator-1'),
      refreshToken: 'refresh-token',
    );
    await repository.reconcilePendingPreparation();
    expect(requests, hasLength(1));
    expect(requests.single['id'], pendingId);
    expect(pendingStore.values, isEmpty);
  });

  test('422 recebido na primeira tentativa libera correção dos dados', () async {
    final pendingStore = _PendingStore();
    final receiptIds = <String>[];
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        receiptIds.add(body['id'] as String);
        if (receiptIds.length == 1) return http.Response('{}', 422);
        return _jsonResponse(_snapshot(status: 'planned', canClose: false), 201);
      }),
    );
    final command = PrepareClassroomCommand(
      className: 'Turma Palmas', offerMunicipality: 'Palmas',
      offerLocation: 'Laboratório', institutionId: 'institution-1',
      programId: 'program-1', courseId: 'course-1',
      courseVersionId: 'version-7', startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 30), teacherId: 'teacher-1',
      monitorIds: const [],
    );

    await expectLater(
      repository.prepare(command),
      throwsA(isA<ClassLifecycleRejectedException>()),
    );
    expect(pendingStore.values, isEmpty);
    await repository.prepare(command);
    expect(receiptIds, hasLength(2));
    expect(receiptIds.last, isNot(receiptIds.first));
  });

  test('version conflict releases pending receipt for confirmed new edition', () async {
    final receiptIds = <String>[];
    final pendingStore = _PendingStore();
    var optionsReads = 0;
    final repository = ClassLifecycleRepository(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: _TokenStore(accessToken: _jwt('operator-1')),
      ),
      pendingPrepareStore: pendingStore,
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
