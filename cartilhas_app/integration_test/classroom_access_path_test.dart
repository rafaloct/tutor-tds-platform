import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/data/learner_offline_repository.dart';
import 'package:cartilhas_app/features/classrooms/presentation/learner_classrooms_screen.dart';
import 'package:cartilhas_app/features/courses/presentation/course_pdf_button.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/study_progress/study_progress_repository.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:cartilhas_app/services/privacy_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _run = String.fromEnvironment('QA_ACCESS_RUN_ID');
const _cohort = String.fromEnvironment('QA_ACCESS_COHORT_ID');
const _course = String.fromEnvironment('QA_ACCESS_COURSE_ID');
const _version = String.fromEnvironment('QA_ACCESS_VERSION_ID');
const _name = String.fromEnvironment('QA_ACCESS_CLASS_NAME');
const _student = String.fromEnvironment('QA_STUDENT_ID');
const _phases = [
  'online',
  'cold_offline',
  'offline_restart',
  'reconnect',
  'wrong_account',
  'revoked_online',
  'revoked_offline',
  'pdf',
];
const _queue = LearningEventQueue();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Physical classroom access and public PDF handoff',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(const bool.fromEnvironment('dart.vm.product'), isFalse);
      expect(
        AppConfig.tutorApiUrl,
        'https://tutor-tds-staging.fastapicloud.dev',
      );
      expect(
        AppConfig.learningContextEnabled &&
            AppConfig.durableLearningOutboxEnabled &&
            AppConfig.journeyTraceabilityEnabled,
        isTrue,
      );
      expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(_run), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final key = 'tds.qa.access.$_run';
      final encoded = prefs.getString(key);
      final state = encoded == null
          ? <String, dynamic>{'run_id': _run, 'pids': <dynamic>[]}
          : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      expect(state['run_id'], _run);
      final next = state['completed_phase'] == null
          ? 0
          : _phases.indexOf(state['completed_phase'] as String) + 1;
      expect(next, inInclusiveRange(0, _phases.length - 1));
      final phase = _phases[next];
      expect((state['pids'] as List).contains(pid), isFalse);
      debugPrint('ACCESS_QA phase=$phase action=start');
      final auth = AuthRepository(apiUrl: AppConfig.tutorApiUrl);
      final sync = LearningEventSyncService(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      final remote = ClassroomRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      final gateway = LearnerOfflineRepository(
        remote: remote,
        auth: auth,
        apiUrl: AppConfig.tutorApiUrl,
      );
      final contexts = RemoteLearningContextRepository(
        apiUrl: AppConfig.tutorApiUrl,
        auth: auth,
      );
      final client = http.Client();
      Future<http.Response> response(String path) => auth.authorized(
        (token) => client
            .get(
              Uri.parse('${AppConfig.tutorApiUrl}$path'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 20)),
      );
      Future<Map<String, dynamic>> get(String path) async {
        final r = await response(path);
        expect(r.statusCode, 200);
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      }

      Future<void> login(bool outsider) async {
        await auth.login(
          cpf: outsider
              ? const String.fromEnvironment('QA_OUTSIDER_CPF')
              : const String.fromEnvironment('QA_STUDENT_CPF'),
          password: outsider
              ? const String.fromEnvironment('QA_OUTSIDER_PASSWORD')
              : const String.fromEnvironment('QA_STUDENT_PASSWORD'),
        );
        expect(
          await auth.localUserId(),
          outsider ? const String.fromEnvironment('QA_OUTSIDER_ID') : _student,
        );
      }

      Future<void> showClasses() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider.value(value: auth),
              Provider.value(value: sync),
            ],
            child: MaterialApp(
              home: LearnerClassroomsScreen(
                gateway: gateway,
                contextRepository: contexts,
              ),
            ),
          ),
        );
        await _until(
          tester,
          () async => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
      }

      Future<void> reader() async {
        await showClasses();
        await _tap(tester, find.text(_name));
        await _until(
          tester,
          () async => find.byType(ChatExperienceScreen).evaluate().isNotEmpty,
        );
        final screen = tester.widget<ChatExperienceScreen>(
          find.byType(ChatExperienceScreen),
        );
        expect(screen.cartilha.courseVersionId, _version);
        expect(screen.cartilha.classId, _cohort);
        expect(screen.progressOwnerId, _student);
        await _until(
          tester,
          () async => find.text('Continuar').evaluate().isNotEmpty,
        );
      }

      Future<StudyProgress> position() async {
        final context = LearningContext.fromJson(
          Map<String, dynamic>.from(state['context'] as Map),
        );
        final value = await const StudyProgressRepository().load(
          _course,
          courseVersionId: _version,
          ownerId: _student,
          contextKey: context.resumeKey(AppConfig.tutorApiUrl),
        );
        expect(value, isNotNull);
        return value!;
      }

      Future<void> drain() => _until(tester, () async {
        await sync.flush();
        return (await _queue.pending()).isEmpty;
      });
      final checks = <String, dynamic>{};
      try {
        if (phase == 'online') {
          expect(
            await auth.localUserId(),
            isNull,
            reason: 'New isolated QA package required',
          );
          await PrivacyPreferences.saveDecision(
            consent: true,
            journeyEnabled: true,
          );
          await login(false);
          final snapshot = await contexts.resolve(_cohort);
          expect(snapshot.context.courseVersionId, _version);
          state['context'] = snapshot.context.toJson();
          expect(
            (await get(
              '/classes/$_cohort/learning-context',
            ))['progress']['progress_percent'],
            0,
          );
          await reader();
          await _tap(tester, find.text('Continuar'));
          await tester.pump(const Duration(seconds: 3));
          await _tap(tester, find.text('Continuar'));
          await drain();
          expect((await position()).messageIndex, 2);
          state['online_progress'] = (await get(
            '/classes/$_cohort/learning-context',
          ))['progress'];
          checks['online_position'] = 2;
        } else {
          expect(
            await auth.localUserId(),
            _student,
            reason: 'Same encrypted session must survive process restart',
          );
        }
        if ([
          'cold_offline',
          'offline_restart',
          'revoked_offline',
        ].contains(phase)) {
          var unreachable = false;
          try {
            await client
                .get(Uri.parse('${AppConfig.tutorApiUrl}/live'))
                .timeout(const Duration(seconds: 3));
          } on Object {
            unreachable = true;
          }
          expect(unreachable, isTrue);
          checks['network_unreachable'] = true;
        }
        switch (phase) {
          case 'cold_offline':
            await reader();
            expect(gateway.usingSavedData, isTrue);
            expect((await position()).messageIndex, 2);
            await _tap(tester, find.text('Continuar'));
            await tester.pump(const Duration(seconds: 3));
            await _tap(tester, find.text('Continuar'));
            await _until(
              tester,
              () async => (await position()).messageIndex == 4,
            );
            final events = (await _queue.pending())
                .where((e) => e.payload['class_id'] == _cohort)
                .toList();
            expect(events, isNotEmpty);
            expect(
              events.every(
                (e) =>
                    e.localOwnerId == _student &&
                    e.payload['course_version_id'] == _version,
              ),
              isTrue,
            );
            state['offline_event_ids'] = events.map((e) => e.eventId).toList();
            checks['position'] = 4;
            checks['offline_pending'] = events.length;
          case 'offline_restart':
            final pending = (await _queue.pending())
                .map((e) => e.eventId)
                .toSet();
            expect(
              pending.containsAll(
                (state['offline_event_ids'] as List).cast<String>(),
              ),
              isTrue,
            );
            await reader();
            expect((await position()).messageIndex, 4);
            checks['position_and_queue_survived'] = true;
          case 'reconnect':
            await reader();
            expect((await position()).messageIndex, 4);
            await drain();
            final rows = <Map>[];
            for (var offset = 0; offset < 1000; offset += 100) {
              final page =
                  (await get(
                        '/events?course_id=$_course&limit=100&offset=$offset',
                      ))['events']
                      as List;
              rows.addAll(page.cast<Map>());
              if (page.length < 100) break;
            }
            for (final id in state['offline_event_ids'] as List) {
              expect(rows.where((e) => e['event_id'] == id), hasLength(1));
            }
            final progress =
                (await get('/classes/$_cohort/learning-context'))['progress']
                    as Map;
            expect(
              progress['progress_percent'],
              greaterThan(
                (state['online_progress'] as Map)['progress_percent'],
              ),
            );
            checks['offline_events_delivered_once'] = true;
            checks['progress'] = progress;
          case 'wrong_account':
            await auth.logout();
            await login(true);
            expect(
              (await response('/classes/$_cohort/course')).statusCode,
              403,
            );
            await showClasses();
            expect(find.text(_name), findsNothing);
            expect(find.byType(ChatExperienceScreen), findsNothing);
            await auth.logout();
            await login(false);
            checks['other_account_cannot_open'] = true;
          case 'revoked_online':
            expect(
              (await response('/classes/$_cohort/course')).statusCode,
              403,
            );
            await expectLater(
              contexts.resolve(_cohort),
              throwsA(isA<LearningContextException>()),
            );
            await gateway.currentUser();
            await expectLater(
              gateway.course(_cohort),
              throwsA(isA<ClassroomException>()),
            );
            await showClasses();
            expect(find.text(_name), findsNothing);
            checks['known_revocation_invalidates_cache'] = true;
          case 'revoked_offline':
            await expectLater(
              contexts.resolve(_cohort),
              throwsA(isA<LearningContextException>()),
            );
            await showClasses();
            expect(find.text(_name), findsNothing);
            expect(find.byType(ChatExperienceScreen), findsNothing);
            checks['revoked_content_unavailable_offline'] = true;
          case 'pdf':
            final telemetry = AppTelemetryService(syncService: sync);
            final material = Cartilha(
              id: _course,
              title: 'Cartilha de IA — PDF público',
              author: 'TDS',
              sections: [],
              downloadUrl:
                  'https://drive.google.com/file/d/1vjwT_uoi_tw2rmSL2Y4kldjkqo5P-n4f/view',
            );
            await tester.pumpWidget(
              Provider.value(
                value: telemetry,
                child: MaterialApp(
                  home: Scaffold(
                    body: Center(child: CoursePdfButton(course: material)),
                  ),
                ),
              ),
            );
            await _tap(tester, find.text('PDF'));
            await _until(
              tester,
              () async =>
                  tester
                      .widget<FilledButton>(find.byType(FilledButton))
                      .onPressed !=
                  null,
            );
            expect(
              find.text('Não foi possível abrir o PDF. Tente novamente.'),
              findsNothing,
            );
            checks['pdf_external_handoff_requested'] = true;
            checks['pdf_rendering_requires_host_observation'] = true;
            await sync.flush();
            final pdfEvents =
                (await get(
                      '/events?course_id=$_course&limit=100&offset=0',
                    ))['events']
                    as List;
            final requests = pdfEvents
                .cast<Map>()
                .where(
                  (event) =>
                      event['session_id'] == telemetry.sessionId &&
                      (event['payload'] as Map)['feature_id'] ==
                          'course_pdf_open_requested',
                )
                .toList();
            expect(requests, hasLength(1));
            expect(requests.single['validated_seconds'], 0);
            checks['pdf_request_received_once_without_credit'] = true;
        }
        state['completed_phase'] = phase;
        (state['pids'] as List).add(pid);
        expect(await prefs.setString(key, jsonEncode(state)), isTrue);
        binding.reportData = {
          'run_id': _run,
          'phase': phase,
          'pid': pid,
          'cohort_id': _cohort,
          'course_id': _course,
          'course_version_id': _version,
          'checks': checks,
          'checkpoint': state,
          'production_changed': false,
        };
        debugPrint('ACCESS_QA phase=$phase action=passed');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        contexts.dispose();
        remote.dispose();
        sync.dispose();
        auth.dispose();
        client.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _until(WidgetTester tester, Future<bool> Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 150));
  while (DateTime.now().isBefore(end)) {
    if (await ready()) return;
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('Physical access condition did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
    final scroll = find.byType(Scrollable).first;
    if (scroll.evaluate().isNotEmpty) {
      await tester.drag(scroll, const Offset(0, -250));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  await _until(tester, () async => target.evaluate().length == 1);
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(target, warnIfMissed: true);
  await tester.pump(const Duration(milliseconds: 350));
}
