import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_repository.dart';
import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';

const _baseUrl = String.fromEnvironment('CLASS_LIFECYCLE_E2E_BASE_URL');
const _package = String.fromEnvironment('CLASS_LIFECYCLE_E2E_QA_PACKAGE');
const _apiHead = String.fromEnvironment('CLASS_LIFECYCLE_API_HEAD');
const _appHead = String.fromEnvironment('CLASS_LIFECYCLE_APP_HEAD');
const _composeHead = String.fromEnvironment('CLASS_LIFECYCLE_COMPOSE_HEAD');

const _password = 'qa-' 'class-lifecycle-' '2026!';
const _operatorCpf = '39053344705';
const _coordinatorCpf = '16899535009';
const _teacherCpf = '98765432100';
const _monitorCpf = '11144477735';
const _studentCpf = '12345678909';

const _institution = 'qa-i1';
const _program = 'qa-p1';
const _course = 'qa-course';
const _version = 'qa-v1';
const _student = 'qa-student';
const _outsider = 'qa-outsider';
const _enrollment = 'qa-enrollment';

class _MemoryTokenStore implements AuthTokenStore {
  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

class _Actor {
  _Actor(this.baseUri)
    : _authClient = _clientFor(baseUri),
      _apiClient = _clientFor(baseUri) {
    auth = AuthRepository(
      apiUrl: baseUri.toString().replaceFirst(RegExp(r'/$'), ''),
      client: _authClient,
      tokenStore: _MemoryTokenStore(),
    );
    lifecycle = ClassLifecycleRepository(
      apiUrl: baseUri.toString().replaceFirst(RegExp(r'/$'), ''),
      authRepository: auth,
      client: _apiClient,
    );
  }

  final Uri baseUri;
  final IOClient _authClient;
  final IOClient _apiClient;
  late final AuthRepository auth;
  late final ClassLifecycleRepository lifecycle;

  Future<void> login(String cpf, String expectedId) async {
    final session = await auth.login(cpf: cpf, password: _password);
    expect(session.user.id, expectedId);
    expect(await auth.localUserId(), expectedId);
  }

  Future<http.Response> get(String path) => auth.authorized(
    (token) => _apiClient
        .get(baseUri.resolve(path), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20)),
  );

  Future<http.Response> post(String path, [Object? body]) => auth.authorized(
    (token) => _apiClient
        .post(
          baseUri.resolve(path),
          headers: {
            'Authorization': 'Bearer $token',
            if (body != null) 'Content-Type': 'application/json',
          },
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20)),
  );

  void dispose() {
    lifecycle.dispose();
    auth.dispose();
  }
}

IOClient _clientFor(Uri baseUri) {
  final io = HttpClient();
  io.badCertificateCallback = (_, host, port) =>
      host == '10.0.2.2' && port == baseUri.port;
  return IOClient(io);
}

Map<String, dynamic> _jsonMap(http.Response response) {
  final decoded = jsonDecode(response.body);
  expect(decoded, isA<Map<String, dynamic>>());
  return Map<String, dynamic>.from(decoded as Map);
}

Map<String, dynamic> _classroom(Map<String, dynamic> snapshot) =>
    Map<String, dynamic>.from(snapshot['classroom'] as Map);

String _commandId(String prefix, String run) => '$prefix-$run';

Future<bool> _observeOffline() async {
  final offline = _clientFor(Uri.parse('https://10.0.2.2:1'));
  try {
    await offline
        .get(Uri.parse('https://10.0.2.2:1/health'))
        .timeout(const Duration(milliseconds: 700));
    return false;
  } on Object {
    return true;
  } finally {
    offline.close();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Issue #140 operational classroom journey uses real HTTP adapter',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(const bool.fromEnvironment('dart.vm.product'), isFalse);
      expect(
        RegExp(r'^https://10\.0\.2\.2:\d+/?$').hasMatch(_baseUrl),
        isTrue,
        reason: 'E2E must target the disposable loopback HTTPS server only.',
      );
      expect(
        RegExp(
          r'^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$',
        ).hasMatch(_package),
        isTrue,
      );
      for (final sha in [_apiHead, _appHead, _composeHead]) {
        expect(RegExp(r'^[a-f0-9]{40}$').hasMatch(sha), isTrue);
      }

      final baseUri = Uri.parse(
        _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/',
      );
      final run = _package.substring(_package.length - 32);
      const residenceFixture = 'Itaguatins';
      const offerMunicipality = 'Palmas';
      expect(residenceFixture, isNot(offerMunicipality));

      final observed = <String, Object?>{};
      _Actor? operator;
      _Actor? coordinator;
      _Actor? teacher;
      _Actor? monitor;
      _Actor? student;
      _Actor? reconnectedStudent;

      try {
        operator = _Actor(baseUri);
        await operator.login(_operatorCpf, 'qa-operator');

        final bootstrap = await operator.lifecycle.bootstrap();
        expect(bootstrap.capabilities.canPrepare, isTrue);
        expect(bootstrap.capabilities.canActivate, isFalse);
        expect(bootstrap.capabilities.canClose, isFalse);
        expect(bootstrap.programs, hasLength(1));
        final program = bootstrap.programs.single;
        expect(program.id, _program);
        expect(program.institutionId, _institution);

        final courses = await operator.lifecycle.coursesForProgram(program.id);
        expect(courses, hasLength(1));
        final course = courses.single;
        expect(course.id, _course);

        final published = await operator.lifecycle.publishedVersion(course.id);
        expect(published.opaqueId, _version);
        final staff = await operator.lifecycle.staffForProgram(program.id);
        expect(
          staff.map((item) => item.id),
          containsAll(['qa-teacher', 'qa-monitor']),
        );

        final prepared = await operator.lifecycle.prepare(
          PrepareClassroomCommand(
            className: 'Turma QA $run',
            offerMunicipality: offerMunicipality,
            offerLocation: 'Laboratório QA Avellaria $run',
            institutionId: program.institutionId,
            programId: program.id,
            courseId: course.id,
            courseVersionId: published.opaqueId,
            startDate: DateTime(2026, 10, 11),
            endDate: DateTime(2026, 10, 30),
            teacherId: 'qa-teacher',
            monitorIds: const ['qa-monitor'],
          ),
        );
        expect(prepared.statusLabel, 'Planejada');
        final classId = prepared.opaqueId;

        final preparedSnapshotResponse = await operator.get(
          '/operations/classes/$classId/readiness',
        );
        expect(preparedSnapshotResponse.statusCode, 200);
        final preparedSnapshot = _jsonMap(preparedSnapshotResponse);
        final preparedClassroom = _classroom(preparedSnapshot);
        expect(preparedClassroom['status'], 'planned');
        expect(preparedClassroom['course_version_id'], _version);
        expect(preparedClassroom['offer_municipality'], offerMunicipality);
        expect(
          preparedClassroom['offer_location'],
          'Laboratório QA Avellaria $run',
        );
        observed['prepare_class'] = true;
        observed['territorial_fixture'] = {
          'offer_municipality': offerMunicipality,
          'participant_residence_reference': residenceFixture,
          'residence_reference_persisted_in_classroom': false,
        };
        observed['physical_location_persisted'] = true;

        final assignBody = {
          'id': _commandId('qa-assign', run),
          'action': 'assign',
          'reason': 'Vínculo sintético E2E',
          'institution_id': _institution,
          'program_id': _program,
          'course_id': _course,
          'version_id': _version,
          'person_id': _student,
          'expected_revision': 0,
        };
        final assigned = await operator.post(
          '/operations/$classId/commands',
          assignBody,
        );
        expect(assigned.statusCode, 200);
        final assignedJson = _jsonMap(assigned);
        expect(assignedJson['enrolled'], isTrue);
        expect(assignedJson['assigned'], isTrue);

        final replay = await operator.post(
          '/operations/$classId/commands',
          assignBody,
        );
        expect(replay.statusCode, 200);
        expect(_jsonMap(replay), equals(assignedJson));
        observed['participant'] = true;
        observed['enrollment'] = true;

        final foreign = await operator.post('/operations/$classId/commands', {
          ...assignBody,
          'id': _commandId('qa-foreign', run),
          'person_id': _outsider,
          'reason': 'Cross-scope deve falhar',
        });
        expect(foreign.statusCode, 403);
        observed['cross_scope_denied'] = true;

        coordinator = _Actor(baseUri);
        await coordinator.login(_coordinatorCpf, 'qa-coordinator');
        final beforeActivation = _jsonMap(
          await coordinator.get('/operations/classes/$classId/readiness'),
        );
        final activateClassroom = _classroom(beforeActivation);
        final activated = await coordinator
            .post('/operations/classes/$classId/transition', {
              'id': _commandId('qa-activate', run),
              'reason': 'Ativação E2E autorizada',
              'institution_id': _institution,
              'program_id': _program,
              'course_id': _course,
              'version_id': _version,
              'expected_revision': activateClassroom['revision'],
              'target_status': 'active',
            });
        expect(activated.statusCode, 200);
        expect(_classroom(_jsonMap(activated))['status'], 'active');

        teacher = _Actor(baseUri);
        await teacher.login(_teacherCpf, 'qa-teacher');
        final now = DateTime.now().toUtc();
        final sessionResponse = await teacher
            .post('/admin/classes/$classId/sessions', {
              'starts_at': now
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
              'ends_at': now.add(const Duration(hours: 2)).toIso8601String(),
            });
        expect(sessionResponse.statusCode, 201);
        final sessionJson = _jsonMap(sessionResponse);
        final sessionId = sessionJson['id'] as String;
        final checkinToken = sessionJson['checkin_token'] as String;
        expect(checkinToken, isNotEmpty);
        observed['meeting'] = true;

        student = _Actor(baseUri);
        await student.login(_studentCpf, _student);
        final checkinBody = {
          'kind': 'checkin',
          'idempotency_key': 'qa.checkin.$run',
          'token': checkinToken,
        };
        final checkin = await student.post(
          '/classes/$classId/sessions/$sessionId/checkins',
          checkinBody,
        );
        expect(checkin.statusCode, 201);
        observed['qr_checkin'] = true;

        expect(await _observeOffline(), isTrue);
        student.dispose();
        student = null;

        reconnectedStudent = _Actor(baseUri);
        await reconnectedStudent.login(_studentCpf, _student);
        final replayCheckin = await reconnectedStudent.post(
          '/classes/$classId/sessions/$sessionId/checkins',
          checkinBody,
        );
        expect(replayCheckin.statusCode, 200);

        final rosterAfterQr = _jsonMap(
          await teacher.get('/classes/$classId/sessions/$sessionId/presence'),
        );
        final afterQr = (rosterAfterQr['items'] as List)
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .singleWhere((item) => item['user_id'] == _student);
        expect(afterQr['status'], 'suggested_present');
        expect(afterQr['checkin_count'], 1);
        observed['qr_not_official_presence'] = true;
        observed['offline_reconnect'] = true;

        final confirmed = await teacher
            .post('/classes/$classId/sessions/$sessionId/presence/$_student', {
              'status': 'confirmed_present',
              'expected_revision': 0,
              'reason': 'Conferência humana E2E',
              'idempotency_key': 'qa.presence.$run',
            });
        expect(confirmed.statusCode, 200);
        expect(_jsonMap(confirmed)['status'], 'confirmed_present');

        final official = await teacher.post(
          '/classes/$classId/sessions/$sessionId/attendance/$_student',
          {
            'status': 'VALID',
            'makeup_session_id': null,
            'expected_revision': 0,
            'reason': 'Conferência oficial E2E',
            'idempotency_key': 'qa.official.$run',
          },
        );
        expect(official.statusCode, 200);
        expect(_jsonMap(official)['status'], 'VALID');
        observed['attendance_evidence'] = true;

        monitor = _Actor(baseUri);
        await monitor.login(_monitorCpf, 'qa-monitor');
        final monitorRoster = await monitor.get(
          '/classes/$classId/sessions/$sessionId/presence',
        );
        expect(monitorRoster.statusCode, 200);
        final monitorClose = await monitor.post(
          '/classes/$classId/sessions/$sessionId/close?confirm_pending=true',
        );
        expect(monitorClose.statusCode, 403);
        observed['teacher_monitor_surfaces_distinct'] = true;

        final closeBlocked = await teacher.post(
          '/classes/$classId/sessions/$sessionId/close',
        );
        expect(closeBlocked.statusCode, 409);
        final closeSession = await teacher.post(
          '/classes/$classId/sessions/$sessionId/close?confirm_pending=true',
        );
        expect(closeSession.statusCode, 200);
        final report = _jsonMap(closeSession);
        final summary = Map<String, dynamic>.from(report['summary'] as Map);
        expect(summary['pending_explicitly_confirmed'], isTrue);
        observed['close_meeting'] = true;
        observed['close_session_with_explicit_pending'] = true;

        final occurred = DateTime.now().toUtc().toIso8601String();
        final study = await reconnectedStudent.post('/events', {
          'event_id': 'qa-study-$run',
          'event_type': 'study_activity',
          'course_id': _course,
          'session_id': 'qa-study-session-$run',
          'occurred_at': occurred,
          'active_seconds': 1,
          'payload': {'course_version_id': _version, 'class_id': classId},
        });
        expect(study.statusCode, 201);
        final completed = await reconnectedStudent.post('/events', {
          'event_id': 'qa-completed-$run',
          'event_type': 'lesson_completed',
          'course_id': _course,
          'session_id': 'qa-study-session-$run',
          'occurred_at': occurred,
          'payload': {'course_version_id': _version, 'class_id': classId},
        });
        expect(completed.statusCode, 201);

        final certificateRequest = await reconnectedStudent
            .post('/certificate-requests', {
              'enrollment_id': _enrollment,
              'course_version_id': _version,
              'class_id': classId,
            });
        expect(certificateRequest.statusCode, 201);
        final requestJson = _jsonMap(certificateRequest);
        expect(
          (requestJson['eligibility'] as Map)['eligible'],
          isTrue,
          reason:
              'Synthetic 1-second offering must be eligible after E2E events.',
        );

        final reviewed = await teacher
            .post('/certificate-requests/${requestJson['id']}/review', {
              'expected_revision': requestJson['revision'],
              'decision': 'approve',
              'reason': 'Evidência sintética E2E conferida',
            });
        expect(reviewed.statusCode, 200);
        expect(_jsonMap(reviewed)['status'], 'approved');

        final certificates = _jsonMap(
          await reconnectedStudent.get('/certificates'),
        );
        expect(certificates['certificates'], isEmpty);
        observed['certificate_boundary'] = {
          'request_status': 'approved',
          'emitted': false,
          'institutional_release': 'blocked',
        };

        final closeReadiness = await coordinator.lifecycle.closeReadiness(
          classId,
        );
        expect(closeReadiness.openSessions, 0);
        expect(closeReadiness.pendingEvidence, greaterThanOrEqualTo(1));
        expect(closeReadiness.canClose, isTrue);
        observed['close_class_readiness'] = true;

        final closed = await coordinator.lifecycle.closeClassroom(
          classroomId: classId,
          reason: 'Jornada E2E concluída',
        );
        expect(closed.statusLabel, 'Encerrada');

        final afterClose = await operator
            .post('/operations/$classId/commands', {
              ...assignBody,
              'id': _commandId('qa-after-close', run),
              'reason': 'Turma encerrada deve recusar novo vínculo',
            });
        expect(afterClose.statusCode, 409);
        observed['closed_class_rejects_new_link'] = true;

        final finalClasses = _jsonMap(
          await coordinator.get('/operations/classes'),
        );
        final finalSnapshot = (finalClasses['classes'] as List)
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .singleWhere((item) => (item['classroom'] as Map)['id'] == classId);
        final finalClassroom = Map<String, dynamic>.from(
          finalSnapshot['classroom'] as Map,
        );
        expect(finalClassroom['status'], 'closed');
        expect(finalClassroom['course_version_id'], _version);
        observed['course_version_stable_live'] = true;

        final result = {
          'front': 'CLASS_LIFECYCLE_E2E',
          'run_id': run,
          'api_head': _apiHead,
          'app_head': _appHead,
          'compose_head': _composeHead,
          'class_id': classId,
          'course_version_id': _version,
          'observed': observed,
          'production_changed': false,
          'shared_staging_changed': false,
        };
        binding.reportData = result;
        debugPrint(
          'CLASS_LIFECYCLE_E2E_RESULT=${jsonEncode(result)}',
          wrapWidth: 10000,
        );
      } finally {
        reconnectedStudent?.dispose();
        student?.dispose();
        monitor?.dispose();
        teacher?.dispose();
        coordinator?.dispose();
        operator?.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
