import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_home_card.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/study_progress/study_progress_repository.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Run with tooling/test_context_android.ps1 using a fresh synthetic client and
// the existing synthetic staging seed. Server history is retained across runs;
// a nearly complete enrollment is rejected instead of resetting its evidence.
// Every phase is a separate Android process, retaining the real app data.
// No fake repository, synthetic event injection, clock override, or direct DB
// write is used here. Only an identical, UI-generated event is replayed to test
// HTTP idempotency after the real outbox has delivered it.
const _phase = String.fromEnvironment('CONTEXT_QA_PHASE');
const _studentId = String.fromEnvironment('QA_STUDENT_ID');
const _teacherId = String.fromEnvironment('QA_TEACHER_ID');
const _cohort = 'qa-cohort';
const _course = 'qa-course';
const _edition = 'qa-edition-1';
const _className = 'Turma QA Context Core';
const _courseTitle = 'Curso da turma QA — edição 1';
const _qaKey = 'context_android_gate:v1';
const _queue = LearningEventQueue();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Wave 1 real Android journey: $_phase',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(const String.fromEnvironment('TUTOR_ENVIRONMENT'), 'staging');
      expect(AppConfig.learningContextEnabled, isTrue);
      expect(AppConfig.durableLearningOutboxEnabled, isTrue);
      expect(AppConfig.tutorApiUrl, startsWith('https://'));
      expect(
        AppConfig.tutorApiUrl,
        const String.fromEnvironment('TUTOR_STAGING_API_URL'),
      );
      expect(_studentId, isNotEmpty);
      expect(_teacherId, isNotEmpty);
      expect(_studentId, isNot(_teacherId));

      final api = _Api();
      final prefs = await SharedPreferences.getInstance();
      try {
        switch (_phase) {
          case 'student_online':
            expect(
              prefs.getString(_qaKey),
              isNull,
              reason: 'Use a fresh synthetic client; preserve server history.',
            );
            expect(
              await api.auth.hasSession(),
              isFalse,
              reason: 'Never replace an existing account in this test.',
            );
            await tester.pumpWidget(const CartilhasApp());
            await _login(tester, teacher: false);
            await _home(tester);
            expect(await api.auth.localUserId(), _studentId);
            final initial = await api.context();
            final baselineEvents = await api.events();
            _checkContext(initial);
            final baselineIds = baselineEvents
                .map((event) => event['event_id'] as String)
                .toSet();
            expect(baselineIds.length, baselineEvents.length);
            for (final event in baselineEvents) {
              expect(event['course_id'], _course);
              if (const {
                'lesson_started',
                'lesson_completed',
                'study_activity',
              }.contains(event['event_type'])) {
                expect(event['payload'], {
                  'class_id': _cohort,
                  'course_version_id': _edition,
                });
              }
            }
            final baselineProgress =
                _progress(initial)['progress_percent'] as num;
            expect(
              baselineProgress,
              lessThan(95),
              reason:
                  'Synthetic enrollment has insufficient remaining progress. '
                  'Refuse this rerun; never reset append-only server evidence.',
            );
            final publicCourse = await api.get('/courses/$_course');
            expect(publicCourse['title'], 'Catálogo QA — edição 2');
            await _openReader(tester);
            await _waitFor(
              tester,
              find.text(
                'A cobertura vegetal ajuda a conservar a umidade do solo.',
              ),
            );
            await _tap(tester, find.text('Continuar'));
            await _waitFor(tester, find.text('Manter cobertura vegetal'));
            // Real reading time between actual user interactions, not fake time.
            await tester.pump(const Duration(seconds: 3));
            await _tap(tester, find.text('Manter cobertura vegetal'));
            await _waitFor(
              tester,
              find.text('Correto! A cobertura protege o solo.'),
            );
            await _waitUntil(
              tester,
              () async => (await api.events()).any(
                (event) =>
                    !baselineIds.contains(event['event_id']) &&
                    event['event_type'] == 'study_activity' &&
                    (event['validated_seconds'] as num) >= 2,
              ),
            );
            await _drained(tester);
            final after = await api.context();
            final events = await api.events();
            _checkContext(after);
            _checkProgress(after, events);
            expect(
              events.map((event) => event['event_id']).toSet(),
              containsAll(baselineIds),
            );
            _expectHistoryPreserved(baselineEvents, events);
            final newActivities = events.where(
              (event) =>
                  !baselineIds.contains(event['event_id']) &&
                  event['event_type'] == 'study_activity' &&
                  (event['validated_seconds'] as num) >= 2,
            );
            expect(newActivities, isNotEmpty);
            expect(
              _progress(after)['progress_percent'],
              greaterThan(baselineProgress),
            );
            final position = await _position(after);
            expect(position.questionsAnswered, 1);
            expect(position.messageIndex, 1);
            expect(position.showOptions, isFalse);
            await _back(tester);
            await _home(tester);
            _expectHomeProgress(after);
            await prefs.setString(
              _qaKey,
              jsonEncode({
                'completed_phase': _phase,
                'context': after['context'],
                'baseline_progress': _progress(initial),
                'baseline_event_ids': baselineIds.toList(),
                'baseline_events': baselineEvents,
                'online_progress': _progress(after),
                'online_event_ids': events.map((e) => e['event_id']).toList(),
                'online_position': position.toJson(),
              }),
            );
            _report({
              'phase': _phase,
              'context': after['context'],
              'baseline_progress': _progress(initial),
              'baseline_event_ids': baselineIds.toList(),
              'baseline_events_unchanged': true,
              'new_activity_ids': newActivities
                  .map((event) => event['event_id'])
                  .toList(),
              'progress': _progress(after),
              'events': events,
            });
          case 'student_restart':
            final state = _state(prefs, 'student_online');
            expect(await api.auth.localUserId(), _studentId);
            await tester.pumpWidget(const CartilhasApp());
            await _home(tester);
            final after = await api.context();
            expect(after['context'], state['context']);
            expect(_progress(after), state['online_progress']);
            expect(
              (await api.events()).map((e) => e['event_id']),
              unorderedEquals(state['online_event_ids'] as List),
            );
            _expectHomeProgress(after);
            await _openReader(tester);
            await _waitFor(
              tester,
              find.text('Você retomou esta cartilha de onde parou.'),
            );
            final position = await _position(after);
            _samePosition(position, state['online_position'] as Map);
            expect(find.text('Manter cobertura vegetal'), findsNothing);
            await _back(tester);
            await _home(tester);
            await _drained(tester);
            await _savePhase(prefs, state);
            _report({
              'phase': _phase,
              'progress': _progress(after),
              'restored_position': position.toJson(),
            });
          case 'student_offline':
            final state = _state(prefs, 'student_restart');
            await api.requireOffline();
            expect(await api.auth.localUserId(), _studentId);
            expect(await _pendingCourseEvents(), isEmpty);
            await tester.pumpWidget(const CartilhasApp());
            await _home(tester, offline: true);
            await _openReader(tester);
            await _waitFor(
              tester,
              find.text(
                'Conteúdo salvo da sua turma. Seu progresso será enviado quando a conexão voltar.',
              ),
            );
            await _tap(tester, find.text('Continuar'));
            await _waitFor(
              tester,
              find.text(
                'A atividade desta etapa foi concluída. Continue para revisar.',
              ),
            );
            await tester.pump(const Duration(seconds: 3));
            await _tap(tester, find.text('Continuar'));
            await _waitFor(
              tester,
              find.text(
                'Revisão QA: preservar a cobertura vegetal favorece o solo.',
              ),
            );
            await _waitUntil(
              tester,
              () async => (await _pendingCourseEvents()).any(
                (event) => event.type == LearningEventType.studyActivity,
              ),
            );
            final events = await _pendingCourseEvents();
            final activities = events
                .where((event) => event.type == LearningEventType.studyActivity)
                .toList();
            expect(activities, hasLength(1));
            expect(activities.single.activeSeconds, greaterThanOrEqualTo(2));
            await _expectDeliveryPending(tester);
            for (final event in events) {
              expect(event.localOwnerId, _studentId);
              expect(
                event.localApiUrl,
                AppConfig.tutorApiUrl.replaceFirst(RegExp(r'/+$'), ''),
              );
              // Ownership applies to every queued record. The HTTP contract
              // adds cohort/edition only to pedagogical events; analytics use
              // their own exact payload key and must also survive the restart.
              switch (event.type) {
                case LearningEventType.lessonStarted ||
                    LearningEventType.lessonCompleted ||
                    LearningEventType.studyActivity:
                  expect(event.payload, {
                    'class_id': _cohort,
                    'course_version_id': _edition,
                  });
                case LearningEventType.pageViewed ||
                    LearningEventType.resourceOpened ||
                    LearningEventType.featureUsed:
                  final key = switch (event.type) {
                    LearningEventType.pageViewed => 'page_id',
                    LearningEventType.resourceOpened => 'resource_id',
                    _ => 'feature_id',
                  };
                  expect(event.payload.keys, [key]);
                  expect(event.payload[key], isNotEmpty);
                default:
                  fail(
                    'Unexpected event in the reading journey: ${event.type}',
                  );
              }
            }
            final position = await _position({'context': state['context']});
            expect(position.sectionIndex, 1);
            expect(position.messageIndex, 0);
            state['offline_events'] = events
                .map((e) => e.toStorageJson())
                .toList();
            state['offline_position'] = position.toJson();
            await _savePhase(prefs, state);
            _report({
              'phase': _phase,
              'network_unreachable': true,
              'delivery_pending_visible': true,
              'pending_events': events.map((e) => e.toJson()).toList(),
              'position': position.toJson(),
            });
          case 'offline_restart':
            final state = _state(prefs, 'student_offline');
            await api.requireOffline();
            final expected = state['offline_events'] as List;
            final restored = await _pendingCourseEvents();
            expect(
              restored.map((e) => e.toStorageJson()),
              unorderedEquals(expected),
            );
            await tester.pumpWidget(const CartilhasApp());
            await _home(tester, offline: true);
            await _expectDeliveryPending(tester);
            await _openReader(tester);
            await _waitFor(
              tester,
              find.text(
                'Revisão QA: preservar a cobertura vegetal favorece o solo.',
              ),
            );
            final position = await _position({'context': state['context']});
            _samePosition(position, state['offline_position'] as Map);
            await _expectDeliveryPending(tester);
            await _savePhase(prefs, state);
            _report({
              'phase': _phase,
              'network_unreachable': true,
              'delivery_pending_visible_home_and_reader': true,
              'restored_event_ids': restored.map((e) => e.eventId).toList(),
              'restored_position': position.toJson(),
            });
          case 'student_reconnect':
            final state = _state(prefs, 'offline_restart');
            expect(await api.auth.localUserId(), _studentId);
            await tester.pumpWidget(const CartilhasApp());
            await _home(tester);
            await _drained(tester);
            await _expectDeliveryDrained(tester);
            final events = await api.events();
            expect(
              events.map((event) => event['event_id']).toSet(),
              containsAll(state['baseline_event_ids'] as List),
            );
            _expectHistoryPreserved(
              (state['baseline_events'] as List)
                  .map((event) => Map<String, dynamic>.from(event as Map))
                  .toList(),
              events,
            );
            expect(
              events.map((event) => event['event_id']).toSet(),
              containsAll(state['online_event_ids'] as List),
            );
            final offline = (state['offline_events'] as List)
                .map(LearningEvent.fromJson)
                .cast<LearningEvent>()
                .toList();
            for (final event in offline) {
              expect(
                events.where((item) => item['event_id'] == event.eventId),
                hasLength(1),
              );
            }
            final after = await api.context();
            expect(after['context'], state['context']);
            _checkProgress(after, events);
            expect(
              _progress(after)['progress_percent'],
              greaterThan(
                (state['online_progress'] as Map)['progress_percent'] as num,
              ),
            );
            // Replay exactly the activity originally created by the offline UI.
            final activity = offline.singleWhere(
              (event) => event.type == LearningEventType.studyActivity,
            );
            expect(await api.replay(activity), 200);
            final replayedEvents = await api.events();
            expect(replayedEvents, events);
            expect(_progress(await api.context()), _progress(after));
            // Entering the reader revalidates Home, including after sync completed.
            await _openReader(tester);
            await _waitFor(
              tester,
              find.text(
                'Revisão QA: preservar a cobertura vegetal favorece o solo.',
              ),
            );
            await _back(tester);
            await _home(tester);
            await _expectDeliveryDrained(tester);
            _expectHomeProgress(after);
            state['final_progress'] = _progress(after);
            await _savePhase(prefs, state);
            _report({
              'phase': _phase,
              'progress': _progress(after),
              'events': replayedEvents,
              'identical_replay_status': 200,
              'delivery_pending_cleared': true,
              'baseline_events_unchanged': true,
            });
          case 'instructor_observation':
            final state = _state(prefs, 'student_reconnect');
            await tester.pumpWidget(const CartilhasApp());
            await _home(tester);
            await _tap(tester, find.byTooltip('Mais opções'));
            await _tap(tester, find.text('Configurações'));
            await _tap(tester, find.text('Sair da conta'));
            await _tap(
              tester,
              find.widgetWithText(FilledButton, 'Sair da conta'),
            );
            await _login(tester, teacher: true);
            await _waitFor(tester, find.text('Sua aprendizagem'));
            expect(await api.auth.localUserId(), _teacherId);
            final teacher = await api.get('/auth/me');
            expect(
              teacher['role'],
              'student',
              reason: 'Instructor access must derive from CohortMembership.',
            );
            final observed = await api.get(
              '/classes/$_cohort/students/$_studentId/learning-context',
            );
            expect(observed['context'], state['context']);
            expect(_progress(observed), state['final_progress']);
            final dashboard = await api.get('/classes/$_cohort/dashboard');
            final students = (dashboard['students'] as List).cast<Map>();
            expect(students.single, state['final_progress']);
            await _openTeam(tester);
            await _waitFor(tester, find.text('Acompanhamento de turma'));
            // The dashboard ListView builds its lower sections lazily.
            await tester.scrollUntilVisible(
              find.text('Aluno QA Contexto'),
              300,
              scrollable: find.byType(Scrollable).last,
              maxScrolls: 25,
              duration: const Duration(milliseconds: 250),
            );
            final studentTile = find.ancestor(
              of: find.text('Aluno QA Contexto'),
              matching: find.byType(ExpansionTile),
            );
            await tester.ensureVisible(studentTile);
            await tester.pump(const Duration(milliseconds: 300));
            final progress = _progress(observed);
            final hours = (progress['validated_hours'] as num).toDouble();
            final expectedSubtitle =
                '${(progress['progress_percent'] as num).toStringAsFixed(0)}% • '
                '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} h validadas';
            expect(
              find.descendant(
                of: studentTile,
                matching: find.text(expectedSubtitle),
              ),
              findsOneWidget,
            );
            expect(find.text(_className), findsWidgets);
            await _savePhase(prefs, state);
            _report({
              'phase': _phase,
              'instructor_id': _teacherId,
              'global_role': teacher['role'],
              'context': observed['context'],
              'student_progress': state['final_progress'],
              'instructor_progress': students.single,
              'visible_progress': expectedSubtitle,
            });
          default:
            fail(
              'Unknown CONTEXT_QA_PHASE. Use tooling/test_context_android.ps1.',
            );
        }
      } finally {
        api.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) => _waitUntil(
  tester,
  () async => finder.evaluate().isNotEmpty,
  reason: 'Expected screen element did not appear: $finder',
);

Future<void> _waitUntil(
  WidgetTester tester,
  Future<bool> Function() check, {
  String reason = 'Expected condition did not become true',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(deadline)) {
    if (await check()) return;
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail(reason);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _back(WidgetTester tester) async {
  // WidgetTester.pageBack assumes the English tooltip "Back". This app is pt-BR.
  final button = find.byType(BackButton);
  if (button.evaluate().isNotEmpty) {
    await _tap(tester, button);
  } else {
    // Popup menus have no back button; dispatch Android's normal back action.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _login(WidgetTester tester, {required bool teacher}) async {
  await _tap(tester, find.text('Já tenho conta'));
  final cpf = teacher
      ? const String.fromEnvironment('QA_TEACHER_CPF')
      : const String.fromEnvironment('QA_STUDENT_CPF');
  final password = teacher
      ? const String.fromEnvironment('QA_TEACHER_PASSWORD')
      : const String.fromEnvironment('QA_STUDENT_PASSWORD');
  expect(cpf.length, 11);
  // Only test the length, so a failing assertion cannot disclose the password.
  expect(password.length, greaterThanOrEqualTo(12));
  await tester.enterText(find.byKey(const Key('account-login-cpf')), cpf);
  await tester.enterText(find.byKey(const Key('account-password')), password);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _waitFor(tester, find.text('Concordar e continuar'));
  await _tap(tester, find.text('Concordar e continuar'));
}

Future<void> _home(WidgetTester tester, {bool offline = false}) async {
  await _waitFor(tester, find.text('Continuar estudo'));
  final card = find.byType(LearningHomeCard);
  expect(
    find.descendant(of: card, matching: find.textContaining(_className)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: card, matching: find.textContaining(_courseTitle)),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.textContaining('Catálogo QA — edição 2'),
    ),
    findsNothing,
  );
  if (offline) {
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('Offline • Última sincronização'),
      ),
      findsOneWidget,
    );
  }
}

Future<void> _openReader(WidgetTester tester) async {
  await _tap(tester, find.text('Continuar estudo'));
  await _waitFor(tester, find.byType(ChatExperienceScreen));
  final screen = tester.widget<ChatExperienceScreen>(
    find.byType(ChatExperienceScreen),
  );
  expect(screen.cartilha.courseVersionId, _edition);
  expect(screen.cartilha.classId, _cohort);
  expect(screen.cartilha.title, _courseTitle);
  expect(
    screen.learningContextController!.snapshot!.context.userId,
    _studentId,
  );
}

Future<void> _openTeam(WidgetTester tester) async {
  // Team capability resolves independently from the public catalog and Home.
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    await _tap(tester, find.byTooltip('Mais opções'));
    if (find.text('Área da equipe').evaluate().isNotEmpty) {
      await _tap(tester, find.text('Área da equipe'));
      return;
    }
    await _back(tester);
    await tester.pump(const Duration(seconds: 1));
  }
  fail('Cohort instructor capability never appeared.');
}

Map<String, dynamic> _state(SharedPreferences prefs, String previousPhase) {
  final encoded = prefs.getString(_qaKey);
  expect(encoded, isNotNull, reason: 'Previous Android phase is missing.');
  final state = jsonDecode(encoded!) as Map<String, dynamic>;
  expect(state['completed_phase'], previousPhase);
  return state;
}

Future<void> _savePhase(
  SharedPreferences prefs,
  Map<String, dynamic> state,
) async {
  state['completed_phase'] = _phase;
  expect(await prefs.setString(_qaKey, jsonEncode(state)), isTrue);
}

Map<String, dynamic> _progress(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(value['progress'] as Map);

void _checkContext(Map<String, dynamic> value) {
  final snapshot = LearningContextSnapshot.fromJson(value);
  expect(snapshot.contractVersion, 'cohort-enrollment-v2');
  expect(snapshot.context.userId, _studentId);
  expect(snapshot.context.organizationId, 'qa-org');
  expect(snapshot.context.programId, 'qa-program');
  expect(snapshot.context.cohortId, _cohort);
  expect(snapshot.context.courseId, _course);
  expect(snapshot.context.courseVersionId, _edition);
  expect(snapshot.context.role, 'student');
  expect(snapshot.context.membershipId, isNotEmpty);
  expect(snapshot.context.legacyEnrollmentId, 'qa-legacy-enrollment');
  expect(
    snapshot.context.permissions,
    containsAll({'content.read', 'progress.read', 'activity.record'}),
  );
  expect(
    snapshot.context.enrollmentId,
    isNot(snapshot.context.legacyEnrollmentId),
  );
}

void _checkProgress(
  Map<String, dynamic> context,
  List<Map<String, dynamic>> events,
) {
  expect(
    events.map((event) => event['event_id']).toSet().length,
    events.length,
  );
  final seconds = events
      .where((event) => event['event_type'] == 'study_activity')
      .fold<int>(
        0,
        (total, event) => total + (event['validated_seconds'] as num).toInt(),
      );
  expect(seconds, greaterThan(0));
  final percent = double.parse((seconds * 100 / 120).toStringAsFixed(2));
  expect(_progress(context)['progress_percent'], percent.clamp(0, 100));
  expect(
    _progress(context)['validated_hours'],
    double.parse((seconds / 3600).toStringAsFixed(4)),
  );
}

void _expectHomeProgress(Map<String, dynamic> context) {
  final percent = (_progress(context)['progress_percent'] as num)
      .toStringAsFixed(0);
  expect(
    find.descendant(
      of: find.byType(LearningHomeCard),
      matching: find.text('Progresso confirmado: $percent%'),
    ),
    findsOneWidget,
  );
}

Future<StudyProgress> _position(Map<String, dynamic> value) async {
  final context = LearningContext.fromJson(
    Map<String, dynamic>.from(value['context'] as Map),
  );
  final saved = await const StudyProgressRepository().load(
    _course,
    courseVersionId: _edition,
    ownerId: _studentId,
    contextKey: context.resumeKey(AppConfig.tutorApiUrl),
  );
  expect(saved, isNotNull);
  return saved!;
}

void _samePosition(StudyProgress actual, Map expected) {
  final fields = actual.toJson()..remove('updatedAt');
  expect(fields, Map.of(expected)..remove('updatedAt'));
}

Future<List<LearningEvent>> _pendingCourseEvents() async =>
    (await _queue.pending()).where((e) => e.courseId == _course).toList();

Future<void> _drained(WidgetTester tester) => _waitUntil(
  tester,
  () async => (await _pendingCourseEvents()).isEmpty,
  reason: 'The real outbox did not deliver the learner events.',
);

Future<void> _expectDeliveryPending(WidgetTester tester) async {
  final pending = find.byKey(const ValueKey('learning-delivery-pending'));
  final reader = find.byType(ChatExperienceScreen);
  if (reader.evaluate().isNotEmpty) {
    // The reader keeps delivery status at the top of its lazy content list.
    // Scrolling reveals that real status without advancing the learning step.
    await tester.scrollUntilVisible(
      pending,
      -300,
      scrollable: find
          .descendant(of: reader, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 25,
      duration: const Duration(milliseconds: 250),
    );
  }
  await _waitFor(tester, pending);
  await tester.ensureVisible(pending);
  await tester.pump(const Duration(milliseconds: 300));
  expect(pending, findsOneWidget);
  expect(pending.hitTestable(), findsOneWidget);
  expect(
    find.descendant(
      of: pending,
      matching: find.text('Atividades salvas neste aparelho'),
    ),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('learning-delivery-blocked')), findsNothing);
  expect(
    find.byKey(const ValueKey('learning-delivery-storage-error')),
    findsNothing,
  );
}

Future<void> _expectDeliveryDrained(WidgetTester tester) => _waitUntil(
  tester,
  () async => const [
    'learning-delivery-pending',
    'learning-delivery-blocked',
    'learning-delivery-storage-error',
  ].every((key) => find.byKey(ValueKey(key)).evaluate().isEmpty),
  reason: 'Delivered activities still appear as pending or failed in the UI.',
);

void _expectHistoryPreserved(
  List<Map<String, dynamic>> baseline,
  List<Map<String, dynamic>> current,
) {
  for (final previous in baseline) {
    final matches = current.where(
      (event) => event['event_id'] == previous['event_id'],
    );
    expect(matches, hasLength(1));
    // No sync worker is enabled in this isolated staging. The complete API
    // record, including sync_status and validated_seconds, must stay unchanged.
    expect(matches.single, previous);
  }
}

void _report(Map<String, dynamic> evidence) => debugPrint(
  'TDS_CONTEXT_QA_EVIDENCE ${jsonEncode(evidence)}',
  wrapWidth: null,
);

class _Api {
  final auth = AuthRepository(apiUrl: AppConfig.tutorApiUrl);
  final client = http.Client();
  Uri uri(String path) => Uri.parse(
    '${AppConfig.tutorApiUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
  );

  Future<Map<String, dynamic>> get(String path) async {
    final response = await auth.authorized(
      (token) => client
          .get(uri(path), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15)),
    );
    expect(response.statusCode, 200, reason: 'GET $path failed');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> context() =>
      get('/classes/$_cohort/learning-context');

  Future<List<Map<String, dynamic>>> events() async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 100) {
      final page = await get(
        '/events?course_id=$_course&limit=100&offset=$offset',
      );
      final events = (page['events'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      result.addAll(events);
      if (events.length < 100) return result;
    }
  }

  Future<int> replay(LearningEvent event) async => (await auth.authorized(
    (token) => client
        .post(
          uri('/events'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(event.toJson()),
        )
        .timeout(const Duration(seconds: 15)),
  )).statusCode;

  Future<void> requireOffline() async {
    try {
      await client.get(uri('/health')).timeout(const Duration(seconds: 4));
    } on http.ClientException {
      return;
    } on TimeoutException {
      return;
    }
    fail('Offline phase has a working network; disable emulator connectivity.');
  }

  void dispose() {
    auth.dispose();
    client.close();
  }
}
