import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:cartilhas_app/services/privacy_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Physical Android: one .dev APK and three cold starts. Real clock, UI,
// secure storage, SQLite queue and HTTPS. Host controls/restores connectivity.
// Existing DEV tokens/preferences are backed up in secure storage and restored;
// production package and all prior queue/history are preserved. No AI/KV call.
const _run = String.fromEnvironment('JOURNEY_QA_RUN_ID');
const _student = String.fromEnvironment('QA_STUDENT_ID');
const _teacher = String.fromEnvironment('QA_TEACHER_ID');
const _key = 'tds.qa.journey.v1';
const _backupKey = 'tds.qa.journey.backup.v1';
const _queue = LearningEventQueue();
const _secure = FlutterSecureStorage();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Owned journey on real Android', (tester) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('dart.vm.product'), isFalse);
    expect(AppConfig.journeyTraceabilityEnabled, isTrue);
    expect(AppConfig.durableLearningOutboxEnabled, isTrue);
    expect(AppConfig.tutorGatewayUrl, isEmpty);
    expect(
      AppConfig.tutorApiUrl,
      'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api',
    );
    expect(_run, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(_student, isNotEmpty);
    expect(_teacher, isNot(_student));
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    final state = encoded == null
        ? <String, dynamic>{'run_id': _run, 'pids': <int>[]}
        : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    expect(state['run_id'], _run);
    final phase = switch (state['completed_phase']) {
      null => 'online',
      'online' => 'offline',
      'offline' => 'reconnect',
      _ => throw StateError('Run complete; no implicit replay'),
    };
    expect(state['pids'] as List, isNot(contains(pid)));
    debugPrint('JOURNEY_QA phase=$phase action=start');
    final staffStore = _MemoryTokens();
    final staff = AuthRepository(
      apiUrl: AppConfig.tutorApiUrl,
      tokenStore: staffStore,
    );
    final client = http.Client();
    final evidence = <String, dynamic>{};
    try {
      if (phase == 'online') {
        expect(
          await _secure.read(key: _backupKey),
          isNull,
          reason: 'A previous QA backup requires explicit recovery',
        );
        final original = await SecureAuthTokenStore().read();
        await _secure.write(
          key: _backupKey,
          value: jsonEncode({
            'run_id': _run,
            'tokens': original?.toJson(),
            'name': prefs.getString('user_name'),
            'consent': prefs.getBool(PrivacyPreferences.consentKey),
            'notice': prefs.getBool(PrivacyPreferences.noticeSeenKey),
            'journey_consent': prefs.getBool(
              PrivacyPreferences.journeyConsentKey,
            ),
            'journey_notice': prefs.getBool(
              PrivacyPreferences.journeyNoticeSeenKey,
            ),
          }),
        );
        await SecureAuthTokenStore().clear();
        await prefs.remove('user_name');
        await PrivacyPreferences.saveDecision(consent: false);
        await _staffLogin(staff);
        final baseline =
            await ClassroomRepository(
              apiUrl: AppConfig.tutorApiUrl,
              authRepository: staff,
            ).saveStudentBaseline(
              classId: 'qa-cohort',
              userId: _student,
              source: 'qa_journey_forms',
              recordId: 'qa-tablet-$_run',
              baselineDate: '2026-10-01',
              biRecordId: 'QA-DIG-$_run',
              expectedRevision: 0,
              reason: 'Conferência sintética no gate Android de identidade',
              idempotencyKey: 'qa-bridge-$_run',
            );
        expect(baseline['bi_record_id'], 'QA-DIG-$_run');
        await tester.pumpWidget(const CartilhasApp());
        await _tap(tester, find.text('Já tenho conta'));
        await tester.enterText(
          find.byKey(const Key('account-login-cpf')),
          const String.fromEnvironment('QA_STUDENT_CPF'),
        );
        final password = const String.fromEnvironment('QA_STUDENT_PASSWORD');
        expect(password.length, greaterThanOrEqualTo(12));
        await tester.enterText(
          find.byKey(const Key('account-password')),
          password,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _tap(tester, find.text('Concordar e continuar'));
        await _home(tester);
        final auth = tester
            .element(find.byType(HomeScreen))
            .read<AuthRepository>();
        expect(await auth.localUserId(), _student);
        await _readScreens(tester);
        final telemetry = tester
            .element(find.byType(HomeScreen))
            .read<AppTelemetryService>();
        await telemetry.checkpointScreen();
        await _until(tester, () async {
          final data = await _get(
            client,
            staff,
            '/classes/qa-cohort/journey-activity',
          );
          final rows = (data['items'] as List).cast<Map>();
          return rows.any(
                (e) =>
                    e['evento'] == 'screen_engagement' &&
                    e['alvo_id'] == 'home',
              ) &&
              rows.any(
                (e) =>
                    e['evento'] == 'screen_engagement' &&
                    e['alvo_id'] == 'ai_assistant',
              ) &&
              rows.any((e) => e['alvo_id'] == 'tutor_help_requested');
        });
        // Change the actual app repository's account while the same route is
        // mounted. The old screen interval must not become the teacher's data.
        await auth.logout();
        await _staffLogin(auth);
        await telemetry.heartbeatScreen();
        await tester.pump(const Duration(seconds: 3));
        await telemetry.checkpointScreen();
        await auth.logout();
        await auth.login(
          cpf: const String.fromEnvironment('QA_STUDENT_CPF'),
          password: password,
        );
        await telemetry.heartbeatScreen();
        expect(await auth.localUserId(), _student);
        final journey = await _get(
          client,
          staff,
          '/classes/qa-cohort/journey-export',
        );
        final item = (journey['items'] as List).single as Map;
        expect(item['registro_id'], 'QA-DIG-$_run');
        expect((item['pessoa_id'] as String).length, 64);
        expect(item['concluiu_frequencia_flag'], isNull);
        expect(item['certificado_flag'], isNull);
        expect(item['horas_estudo_validadas'], 0);
        state['pessoa_id'] = item['pessoa_id'];
        evidence.addAll({
          'ui_login_and_consent': true,
          'reviewed_bridge': true,
          'home_and_tutor_duration': true,
          'help_request_without_question_text': true,
          'account_switch': true,
          'learning_hours': 0,
          'attendance': null,
          'certificate': null,
        });
      } else if (phase == 'offline') {
        var offline = false;
        try {
          await client
              .get(Uri.parse('${AppConfig.tutorApiUrl}/health'))
              .timeout(const Duration(seconds: 4));
        } on TimeoutException {
          offline = true;
        } on http.ClientException {
          offline = true;
        }
        expect(offline, isTrue, reason: 'Host must disable phone connectivity');
        await tester.pumpWidget(const CartilhasApp());
        await _home(tester);
        await _readScreens(tester);
        final telemetry = tester
            .element(find.byType(HomeScreen))
            .read<AppTelemetryService>();
        await telemetry.checkpointScreen();
        await tester.pump(const Duration(milliseconds: 500));
        final pending = (await _queue.pending())
            .where(
              (e) =>
                  e.localOwnerId == _student &&
                  e.localApiUrl == AppConfig.tutorApiUrl,
            )
            .toList();
        expect(
          pending.where((e) => e.type == LearningEventType.screenEngagement),
          isNotEmpty,
        );
        state['offline_ids'] = pending.map((e) => e.eventId).toList();
        evidence.addAll({
          'network_off': true,
          'persisted_owned_events': pending.length,
          'durable_sqlite': true,
        });
      } else {
        final offlineIds = (state['offline_ids'] as List)
            .cast<String>()
            .toSet();
        expect(offlineIds, isNotEmpty);
        final preserved = (await _queue.pending())
            .where((e) => offlineIds.contains(e.eventId))
            .toList();
        expect(preserved.length, offlineIds.length);
        expect(preserved.every((e) => e.localOwnerId == _student), isTrue);
        await _staffLogin(staff);
        await tester.pumpWidget(const CartilhasApp());
        await _home(tester);
        await _until(
          tester,
          () async => (await _queue.pending()).every(
            (e) => !offlineIds.contains(e.eventId),
          ),
        );
        final data = await _get(
          client,
          staff,
          '/classes/qa-cohort/journey-activity',
        );
        final rows = (data['items'] as List).cast<Map>();
        for (final id in offlineIds) {
          final matches = rows.where((e) => e['event_id'] == id).toList();
          expect(matches, hasLength(1));
          expect(matches.single['pessoa_id'], state['pessoa_id']);
          expect(matches.single['atribuicao_turma'], isNull);
        }
        final auth = tester
            .element(find.byType(HomeScreen))
            .read<AuthRepository>();
        final events = await _get(
          client,
          auth,
          '/events?course_id=_app&limit=100',
        );
        expect(
          (events['events'] as List).every((e) => e['validated_seconds'] == 0),
          isTrue,
        );
        expect(
          rows.every(
            (e) => !e.containsKey('text') && !e.containsKey('question'),
          ),
          isTrue,
        );
        evidence.addAll({
          'cold_start_queue_preserved': true,
          'delivered_once': offlineIds.length,
          'same_pseudonym': true,
          'screen_time_never_learning_credit': true,
        });
      }
      state['completed_phase'] = phase;
      (state['pids'] as List).add(pid);
      await prefs.setString(_key, jsonEncode(state));
      // Dispose timers before restoring the original account so no QA producer
      // can enqueue an event under a restored real DEV account.
      await tester.pumpWidget(const SizedBox.shrink());
      if (phase == 'reconnect') {
        await _restore(prefs);
        evidence['original_dev_session_and_preferences_restored'] = true;
      }
      binding.reportData = {
        'run_id': _run,
        'phase': phase,
        'pid': pid,
        'package': 'com.tutortds_cartilhas.dev',
        'api': AppConfig.tutorApiUrl,
        'production_changed': false,
        'assertions': evidence,
      };
      debugPrint('JOURNEY_QA phase=$phase action=passed');
    } finally {
      staff.dispose();
      client.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _staffLogin(AuthRepository auth) => auth
    .login(
      cpf: const String.fromEnvironment('QA_TEACHER_CPF'),
      password: const String.fromEnvironment('QA_TEACHER_PASSWORD'),
    )
    .then((_) {});

Future<void> _restore(SharedPreferences prefs) async {
  final value = await _secure.read(key: _backupKey);
  expect(value == null, isFalse);
  final backup = jsonDecode(value!) as Map;
  expect(backup['run_id'], _run);
  final store = SecureAuthTokenStore();
  if (backup['tokens'] == null) {
    await store.clear();
  } else {
    await store.write(
      AuthTokens.fromJson(Map<String, dynamic>.from(backup['tokens'] as Map)),
    );
  }
  for (final pair in [
    ('name', 'user_name'),
    ('consent', PrivacyPreferences.consentKey),
    ('notice', PrivacyPreferences.noticeSeenKey),
    ('journey_consent', PrivacyPreferences.journeyConsentKey),
    ('journey_notice', PrivacyPreferences.journeyNoticeSeenKey),
  ]) {
    final old = backup[pair.$1];
    if (old == null) {
      await prefs.remove(pair.$2);
    } else if (old is bool) {
      await prefs.setBool(pair.$2, old);
    } else {
      await prefs.setString(pair.$2, old as String);
    }
  }
  await _secure.delete(key: _backupKey);
  await prefs.remove(_key);
}

Future<void> _home(WidgetTester tester) =>
    _until(tester, () async => find.byType(HomeScreen).evaluate().isNotEmpty);

Future<void> _readScreens(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await _tap(tester, find.text('Perguntar ao Tutor'));
  await tester.pump(const Duration(seconds: 4));
  await tester.enterText(
    find.byType(TextField).last,
    'Pergunta sintética de QA',
  );
  await _tap(tester, find.byTooltip('Enviar pergunta'));
  await tester.pump(const Duration(seconds: 2));
  await _tap(tester, find.byType(BackButton).first);
  await _home(tester);
}

Future<void> _until(WidgetTester tester, Future<bool> Function() check) async {
  final end = DateTime.now().add(const Duration(seconds: 70));
  while (DateTime.now().isBefore(end)) {
    if (await check()) return;
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('Journey QA boundary did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () async => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Map<String, dynamic>> _get(
  http.Client client,
  AuthRepository auth,
  String path,
) async {
  final response = await auth.authorized(
    (token) => client
        .get(
          Uri.parse('${AppConfig.tutorApiUrl}$path'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 12)),
  );
  expect(response.statusCode, 200, reason: 'QA GET rejected at $path');
  return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
}

class _MemoryTokens implements AuthTokenStore {
  AuthTokens? value;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async {
    value = tokens;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
