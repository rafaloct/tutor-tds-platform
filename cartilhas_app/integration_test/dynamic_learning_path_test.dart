import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/course_editor/models/course_editor_models.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_editor_screen.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_structure_editor.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_home_card.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/study_progress/study_progress_repository.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:cartilhas_app/screens/settings_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One APK, eight process launches. The checkpoint chooses the next phase; never
// rebuild with a different phase define. Host provisions only actors/offering,
// then cohort v1 after publisher_v1 and cohort v2 after publisher_v2.
// Course creation, editing, preview, submission, fork and publication use UI.
// Direct POST/PATCH are limited to documented rejection probes and an identical
// replay of a real UI-generated event. No token, CPF or password enters reports.
// This gate publishes seven supported bot blocks. Contextual quiz attempts are
// Wave 2B. Offline covers cold start and the following reconnect process; it is
// not a ninth offline_restart phase (that path was accepted in Wave 1).
const _runId = String.fromEnvironment('DYNAMIC_QA_RUN_ID');
const _program = String.fromEnvironment(
  'QA_DYNAMIC_PROGRAM_ID',
  defaultValue: 'qa-dynamic-program',
);
const _course = String.fromEnvironment(
  'QA_DYNAMIC_COURSE_ID',
  defaultValue: 'qa-dynamic-course',
);
const _author = _Actor(
  String.fromEnvironment('QA_DYNAMIC_AUTHOR_ID'),
  String.fromEnvironment('QA_DYNAMIC_AUTHOR_CPF'),
  String.fromEnvironment('QA_DYNAMIC_AUTHOR_PASSWORD'),
);
const _publisher = _Actor(
  String.fromEnvironment('QA_DYNAMIC_PUBLISHER_ID'),
  String.fromEnvironment('QA_DYNAMIC_PUBLISHER_CPF'),
  String.fromEnvironment('QA_DYNAMIC_PUBLISHER_PASSWORD'),
);
const _learner = _Actor(
  String.fromEnvironment('QA_DYNAMIC_LEARNER_ID'),
  String.fromEnvironment('QA_DYNAMIC_LEARNER_CPF'),
  String.fromEnvironment('QA_DYNAMIC_LEARNER_PASSWORD'),
);
const _priorQaTeacher = '5b7a0c42-28ba-4f5b-9b8a-c3af65b946be';
const _phases = [
  'author_v1',
  'publisher_v1',
  'learner_v1',
  'author_v2',
  'publisher_v2',
  'learner_after_v2',
  'learner_offline',
  'learner_reconnect',
];
const _queue = LearningEventQueue();
const _teachingTypes = {'lesson_started', 'lesson_completed', 'study_activity'};
String _title(int edition) => 'Curso QA Dynamic edição $edition';
String _className(int edition) => 'Turma QA Dynamic edição $edition';
String _block(int index, {int edition = 1}) => index == 0
    ? 'Publicação remota QA: edição $edition preservada.'
    : 'Etapa QA ${index + 1}: cuidar do solo ajuda a conservar a água.';

class _Actor {
  const _Actor(this.id, this.cpf, this.password);
  final String id;
  final String cpf;
  final String password;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Dynamic Learning publishes and reads with one installed APK',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(const bool.fromEnvironment('dart.vm.product'), isFalse);
      expect(const String.fromEnvironment('TUTOR_ENVIRONMENT'), 'staging');
      expect(
        AppConfig.tutorApiUrl,
        'https://tutor-tds-staging.fastapicloud.dev',
      );
      expect(
        AppConfig.tutorApiUrl,
        const String.fromEnvironment('TUTOR_STAGING_API_URL'),
      );
      expect(AppConfig.learningContextEnabled, isTrue);
      expect(AppConfig.durableLearningOutboxEnabled, isTrue);
      expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(_runId), isTrue);
      expect(_program, 'qa-dynamic-program');
      expect(_course, 'qa-dynamic-course');
      for (final actor in [_author, _publisher, _learner]) {
        expect(actor.id, isNotEmpty);
        expect(actor.cpf.length, 11);
        expect(actor.password.length, greaterThanOrEqualTo(12));
      }
      expect({_author.id, _publisher.id, _learner.id}, hasLength(3));
      final prefs = await SharedPreferences.getInstance();
      final key = 'tds.qa.dynamic_learning.v1.$_runId';
      final encoded = prefs.getString(key);
      final state = encoded == null
          ? <String, dynamic>{
              'run_id': _runId,
              'course_id': _course,
              'program_id': _program,
              'pids': <dynamic>[],
            }
          : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      expect(state['run_id'], _runId);
      expect(state['course_id'], _course);
      expect(state['program_id'], _program);
      final previous = state['completed_phase'];
      final index = previous == null
          ? 0
          : _phases.indexOf(previous as String) + 1;
      if (previous != null) expect(_phases, contains(previous));
      expect(
        index,
        lessThan(_phases.length),
        reason: 'Run already complete; never restart it silently.',
      );
      final phase = _phases[index];
      expect(
        state['pids'] as List,
        isNot(contains(pid)),
        reason: 'Each phase needs a new Android process.',
      );
      final api = _Api();
      final evidence = <String, dynamic>{};
      try {
        switch (phase) {
          case 'author_v1':
            expect(await api.publicStatus('/courses/$_course'), 404);
            expect(await api.publicContainsCourse(), isFalse);
            await _signedIn(tester, api, prefs, _author, evidence: evidence);
            expect((await api.auth.currentUser()).role, 'student');
            await _openEditor(tester, api);
            await _tap(
              tester,
              find.text('Criar curso'),
              within: find.byType(CourseEditorCatalogScreen),
            );
            await _fill(tester, 'Título', _title(1));
            await _fill(tester, 'Autoria', 'Equipe QA Dynamic');
            await _fill(tester, 'Código permanente', _course);
            await _tap(tester, find.text('Criar rascunho'));
            await _waitFor(tester, find.byType(CourseStructureEditor));
            await _editorLoaded(tester);
            await _tap(tester, find.text('Adicionar módulo'), within: _editor);
            await _fill(tester, 'Título do módulo', 'Aprendizagem dinâmica QA');
            await _tap(tester, find.widgetWithText(FilledButton, 'Aplicar'));
            for (var block = 0; block < 7; block++) {
              await _tap(
                tester,
                find.text('Adicionar mensagem'),
                within: _editor,
              );
              await _fill(tester, 'Conteúdo', _block(block));
              await _tap(tester, find.text('Aplicar mensagem'));
            }
            await _saveEditor(tester, api, title: _title(1));
            final draft = await api.editor();
            expect(draft['status'], 'draft');
            expect(
              (draft['sections'] as List).single['messages'],
              hasLength(7),
            );
            expect(await api.publicContainsCourse(), isFalse);
            await _preview(tester, api, _block(0));
            await _transition(tester, 'Enviar para revisão');
            final review = await _editorStatus(tester, api, 'in_review');
            state['v1'] = _versionSummary(review);
            expect(
              await api.probe(
                'POST',
                '/courses/$_course/publish',
                _revision(review),
              ),
              403,
            );
            expect(
              await api.editor(),
              review,
              reason:
                  'Denied author publication must not alter the editorial snapshot.',
            );
            expect(await api.publicContainsCourse(), isFalse);
            evidence.addAll({
              'draft_not_public': true,
              'author_global_role': 'student',
              'author_publish_status': 403,
              'preview_without_learning_events': true,
            });
          case 'publisher_v1':
            await _signedIn(tester, api, prefs, _publisher, evidence: evidence);
            await _openEditor(tester, api);
            await _openEditorialCourse(tester, _title(1));
            expect(
              (await api.editor())['version_id'],
              (state['v1'] as Map)['version_id'],
            );
            await _transition(tester, 'Publicar');
            final published = await _editorStatus(tester, api, 'published');
            await _assertPublic(api, 1, published['version_id'] as String);
            state['v1'] = _versionSummary(published);
            evidence['host_next_action'] =
                'after_v1: provision cohort/enrollment before learner_v1';
          case 'learner_v1':
            await _signedIn(tester, api, prefs, _learner, evidence: evidence);
            final cohort = await api.cohort(1, _version(state, 1));
            state['cohort_v1'] = cohort;
            final initial = await api.context(cohort);
            _checkContext(initial, cohort, _version(state, 1));
            expect(_progress(initial)['progress_percent'], 0);
            expect(
              await api.events(),
              isEmpty,
              reason: 'Course fixture must not have prior learner evidence.',
            );
            await _refreshCatalog(tester);
            await _reveal(
              tester,
              find.text(_title(1)),
              within: find.byType(HomeScreen),
            );
            await _selectCohort(tester, 1);
            await _openReader(tester, cohort, _version(state, 1), _title(1));
            await _waitFor(tester, find.text(_block(0)));
            await _tap(tester, find.text('Continuar'), within: _reader);
            await _waitFor(tester, find.text(_block(1)));
            await tester.pump(const Duration(seconds: 3));
            await _tap(tester, find.text('Continuar'), within: _reader);
            await _waitFor(tester, find.text(_block(2)));
            await _drained(tester);
            final after = await api.context(cohort);
            final events = await api.events();
            _checkProgress(after, events, cohort);
            expect(_progress(after)['progress_percent'], greaterThan(0));
            final position = await _position(after);
            expect(position.messageIndex, 2);
            expect(position.isCompleted, isFalse);
            state['context_v1'] = after['context'];
            state['online_progress'] = _progress(after);
            state['online_events'] = events;
            state['online_position'] = position.toJson();
            final publication = await api.publicGet('/courses/$_course');
            expect(
              await api.status('/editor/courses?program_id=$_program'),
              403,
            );
            // Version visibility is checked before capabilities. The learner is
            // deliberately not told whether an editorial version exists.
            expect(
              await api.probe(
                'POST',
                '/courses/$_course/publish',
                _revision(state['v1'] as Map),
              ),
              404,
            );
            expect(await api.publicGet('/courses/$_course'), publication);
            expect(_progress(await api.context(cohort)), _progress(after));
            await _back(tester);
            await _expectHome(tester, 1, after);
            evidence.addAll({
              'learner_editor_status': 403,
              'learner_publish_status': 404,
              'denied_publication_unchanged': true,
            });
          case 'author_v2':
            await _signedIn(tester, api, prefs, _author, evidence: evidence);
            await _openEditor(tester, api);
            await _openEditorialCourse(tester, _title(1));
            expect(
              _versionSummary(await api.editor()),
              state['v1'],
              reason:
                  'The preceding learner rejection must leave revision, state and content unchanged.',
            );
            await _tap(tester, find.text('Criar nova versão'), within: _editor);
            final fork = await _editorStatus(tester, api, 'draft');
            expect(fork['version_id'], isNot(_version(state, 1)));
            expect(fork['version_number'], 2);
            await _fill(tester, 'Título do curso', _title(2), within: _editor);
            await _tap(tester, find.text(_block(0)), within: _editor);
            await _fill(tester, 'Conteúdo', _block(0, edition: 2));
            await _tap(tester, find.text('Aplicar mensagem'));
            await _saveEditor(tester, api, title: _title(2));
            final saved = await api.editor();
            // Exact old revision is intentionally rejected; this cannot create or
            // modify publication. All successful mutations above use real widgets.
            final stale = EditableCourse.fromJson(saved).saveBody;
            stale['expected_revision'] = (saved['revision'] as int) - 1;
            expect(await api.probe('PATCH', '/courses/$_course', stale), 409);
            expect(
              await api.editor(),
              saved,
              reason:
                  'Obsolete revision must not change content, revision or state.',
            );
            await _assertPublic(api, 1, _version(state, 1));
            await _preview(tester, api, _block(0, edition: 2));
            await _transition(tester, 'Enviar para revisão');
            final review = await _editorStatus(tester, api, 'in_review');
            state['v2'] = _versionSummary(review);
            evidence['stale_revision_status'] = 409;
          case 'publisher_v2':
            await _signedIn(tester, api, prefs, _publisher, evidence: evidence);
            await _openEditor(tester, api);
            await _openEditorialCourse(tester, _title(2));
            await _transition(tester, 'Publicar');
            final published = await _editorStatus(tester, api, 'published');
            expect(published['version_id'], _version(state, 2));
            await _assertPublic(api, 2, _version(state, 2));
            final old = await api.editor(version: _version(state, 1));
            expect(old['status'], 'archived');
            expect(
              _digest(old['sections']),
              (state['v1'] as Map)['sections_sha256'],
            );
            state['v2'] = _versionSummary(published);
            evidence.addAll({
              'old_snapshot_unchanged': true,
              'host_next_action':
                  'after_v2: provision cohort/enrollment before learner_after_v2',
            });
          case 'learner_after_v2':
            await _signedIn(tester, api, prefs, _learner, evidence: evidence);
            final old = await api.cohort(1, _version(state, 1));
            final latest = await api.cohort(2, _version(state, 2));
            expect(old, state['cohort_v1']);
            expect(latest, isNot(old));
            state['cohort_v2'] = latest;
            await _refreshCatalog(tester);
            await _reveal(
              tester,
              find.text(_title(2)),
              within: find.byType(HomeScreen),
            );
            await _assertPublic(api, 2, _version(state, 2));
            await _selectCohort(tester, 1, explicit: true);
            final first = await api.context(old);
            expect(first['context'], state['context_v1']);
            expect(_progress(first), state['online_progress']);
            await _expectHome(tester, 1, first);
            await _openReader(tester, old, _version(state, 1), _title(1));
            await _waitFor(tester, find.text(_block(2)));
            _samePosition(
              await _position(first),
              state['online_position'] as Map,
            );
            await _back(tester);
            await _selectCohort(tester, 2, explicit: true);
            final second = await api.context(latest);
            _checkContext(second, latest, _version(state, 2));
            expect(_progress(second)['progress_percent'], 0);
            expect(
              (second['context'] as Map)['enrollment_id'],
              isNot((first['context'] as Map)['enrollment_id']),
            );
            await _openReader(tester, latest, _version(state, 2), _title(2));
            await _waitFor(tester, find.text(_block(0, edition: 2)));
            await _back(tester);
            await _drained(tester);
            expect(_progress(await api.context(latest))['progress_percent'], 0);
            await _selectCohort(tester, 1, explicit: true);
            await _expectHome(tester, 1, first);
            expect(_progress(await api.context(old)), state['online_progress']);
            state['context_v2'] = second['context'];
            state['before_offline_events'] = await api.events();
            evidence.addAll({
              'public_edition': 2,
              'old_cohort_edition': 1,
              'new_cohort_progress': 0,
              'old_progress_unchanged': true,
            });
          case 'learner_offline':
            await api.requireOffline();
            expect(await api.auth.localUserId(), _learner.id);
            expect(await _pending(), isEmpty);
            await tester.pumpWidget(const CartilhasApp());
            await _expectHome(tester, 1, {
              'progress': state['online_progress'],
            }, offline: true);
            final first = {'context': state['context_v1']};
            _samePosition(
              await _position(first),
              state['online_position'] as Map,
            );
            await _openReader(
              tester,
              state['cohort_v1'] as String,
              _version(state, 1),
              _title(1),
            );
            await _waitFor(tester, find.text(_block(2)));
            await _tap(tester, find.text('Continuar'), within: _reader);
            await _waitFor(tester, find.text(_block(3)));
            await tester.pump(const Duration(seconds: 3));
            await _tap(tester, find.text('Continuar'), within: _reader);
            await _waitFor(tester, find.text(_block(4)));
            await _waitUntil(
              tester,
              () async => (await _pending()).any(
                (e) => e.type == LearningEventType.studyActivity,
              ),
            );
            final pending = await _pending();
            for (final event in pending) {
              expect(event.localOwnerId, _learner.id);
              expect(event.localApiUrl, AppConfig.tutorApiUrl);
              if (_teachingTypes.contains(event.type.apiValue)) {
                expect(event.payload, {
                  'class_id': state['cohort_v1'],
                  'course_version_id': _version(state, 1),
                });
              }
            }
            final activities = pending
                .where((e) => e.type == LearningEventType.studyActivity)
                .toList();
            expect(activities, hasLength(1));
            expect(activities.single.activeSeconds, greaterThanOrEqualTo(2));
            await _reveal(
              tester,
              find.byKey(const Key('learning-delivery-pending')),
              within: _reader,
            );
            expect(
              find.byKey(const Key('learning-delivery-pending')).hitTestable(),
              findsOneWidget,
            );
            final position = await _position(first);
            expect(position.messageIndex, 4);
            expect(position.isCompleted, isFalse);
            state['offline_events'] = pending
                .map((e) => e.toStorageJson())
                .toList();
            state['offline_position'] = position.toJson();
            evidence.addAll({
              'network_unreachable': true,
              'pending_visible': true,
              'cold_start_retained_edition': 1,
            });
          case 'learner_reconnect':
            expect(await api.auth.localUserId(), _learner.id);
            final offline = (state['offline_events'] as List)
                .map((e) => LearningEvent.fromJson(e)!)
                .toList();
            final persisted = await _pending();
            for (final event in offline) {
              expect(
                persisted
                    .singleWhere((item) => item.eventId == event.eventId)
                    .toStorageJson(),
                event.toStorageJson(),
              );
            }
            await tester.pumpWidget(const CartilhasApp());
            await _waitFor(tester, find.text('Continuar estudo'));
            await _drained(tester);
            final first = await api.context(state['cohort_v1'] as String);
            final events = await api.events();
            expect(first['context'], state['context_v1']);
            _checkProgress(first, events, state['cohort_v1'] as String);
            expect(
              _progress(first)['progress_percent'],
              greaterThan(
                (state['online_progress'] as Map)['progress_percent'] as num,
              ),
            );
            _historyPreserved(state['before_offline_events'] as List, events);
            for (final event in offline) {
              expect(
                events.where((row) => row['event_id'] == event.eventId),
                hasLength(1),
              );
            }
            final activity = offline.singleWhere(
              (e) => e.type == LearningEventType.studyActivity,
            );
            expect(await api.probe('POST', '/events', activity.toJson()), 200);
            expect(await api.events(), events);
            expect(
              _progress(await api.context(state['cohort_v1'] as String)),
              _progress(first),
            );
            final second = await api.context(state['cohort_v2'] as String);
            expect(second['context'], state['context_v2']);
            expect(_progress(second)['progress_percent'], 0);
            await _openReader(
              tester,
              state['cohort_v1'] as String,
              _version(state, 1),
              _title(1),
            );
            await _waitFor(tester, find.text(_block(4)));
            _samePosition(
              await _position(first),
              state['offline_position'] as Map,
            );
            await _back(tester);
            await _drained(tester);
            await _expectHome(tester, 1, first);
            await _waitUntil(
              tester,
              () async => find
                  .byKey(const Key('learning-delivery-pending'))
                  .evaluate()
                  .isEmpty,
            );
            expect(
              find.byKey(const Key('learning-delivery-storage-error')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('learning-delivery-blocked')),
              findsNothing,
            );
            state['final_progress'] = _progress(first);
            state['final_v2_progress'] = _progress(second);
            state['final_events'] = await api.events();
            evidence.addAll({
              'pending_survived_process_restart': true,
              'identical_replay_status': 200,
              'duplicate_evidence': false,
              'second_enrollment_progress': 0,
              'v1_progress': _progress(first),
              'v2_progress': _progress(second),
            });
        }
        state['completed_phase'] = phase;
        (state['pids'] as List).add(pid);
        expect(await prefs.setString(key, jsonEncode(state)), isTrue);
        await prefs.reload();
        expect(jsonDecode(prefs.getString(key)!), state);
        binding.reportData = {
          'run_id': _runId,
          'phase': phase,
          'pid': pid,
          'completed_phase': phase,
          'course_id': _course,
          'program_id': _program,
          'checkpoint': state,
          ...evidence,
          'limits': [
            'Eight phases; no separate offline_restart phase.',
            'Seven bot blocks; contextual quiz attempts remain Wave 2B.',
            'Transition audit rows are verified by the host; the app API exposes editorial snapshots only.',
            'No release or production acceptance.',
          ],
        };
      } finally {
        api.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Finder get _editor => find.byType(CourseStructureEditor);
Finder get _reader => find.byType(ChatExperienceScreen);
String _version(Map state, int edition) =>
    (state['v$edition'] as Map)['version_id'] as String;
Map<String, dynamic> _progress(Map value) =>
    Map<String, dynamic>.from(value['progress'] as Map);
Map<String, dynamic> _revision(Map value) => {
  'version_id': value['version_id'],
  'expected_revision': value['revision'],
};
Map<String, dynamic> _versionSummary(Map value) => {
  'version_id': value['version_id'],
  'version_number': value['version_number'],
  'revision': value['revision'],
  'status': value['status'],
  'title': value['title'],
  'content_sha256': _digest(_courseContent(value)),
  'sections_sha256': _digest(value['sections']),
};
Map<String, dynamic> _courseContent(Map value) {
  const metadata = {
    'course_id',
    'program_id',
    'course_version_id',
    'version_id',
    'version_number',
    'revision',
    'status',
    'created_at',
    'updated_at',
    'can_edit',
    'can_submit',
    'can_publish',
    'can_archive',
    'can_fork',
    'versions',
    'legacy_progress_compatible',
    'class_id',
  };
  return {
    for (final entry in value.entries)
      if (!metadata.contains(entry.key)) entry.key as String: entry.value,
  };
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _digest(Object? value) {
  // Same sorted, compact, ASCII-escaped JSON as the read-only Python audit.
  final asciiJson = jsonEncode(_canonical(value)).codeUnits
      .map(
        (unit) => unit > 127
            ? '\\u${unit.toRadixString(16).padLeft(4, '0')}'
            : String.fromCharCode(unit),
      )
      .join();
  return sha256.convert(utf8.encode(asciiJson)).toString();
}

Future<void> _waitUntil(
  WidgetTester tester,
  Future<bool> Function() check, {
  String reason = 'Expected QA condition did not become true',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(deadline)) {
    if (await check()) return;
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail(reason);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) => _waitUntil(
  tester,
  () async => finder.evaluate().isNotEmpty,
  reason: 'Expected widget: $finder',
);

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  Finder? within,
}) async {
  final dialog = find.byType(AlertDialog);
  final root =
      within ??
      (dialog.evaluate().isNotEmpty ? dialog.last : find.byType(Scaffold).last);
  if (finder.evaluate().isEmpty) {
    final scroll = find
        .descendant(of: root, matching: find.byType(Scrollable))
        .first;
    await _waitFor(tester, scroll);
    await tester.drag(scroll, const Offset(0, 5000));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      finder,
      300,
      maxScrolls: 40,
      scrollable: scroll,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _tap(WidgetTester tester, Finder finder, {Finder? within}) async {
  await _reveal(tester, finder, within: within);
  final buttons = find.ancestor(
    of: finder,
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  if (buttons.evaluate().isNotEmpty) {
    await _waitUntil(
      tester,
      () async =>
          tester.widget<ButtonStyleButton>(buttons.last).onPressed != null,
    );
  }
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fill(
  WidgetTester tester,
  String label,
  String value, {
  Finder? within,
}) async {
  final field = find
      .byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      )
      .last;
  await _reveal(tester, field, within: within);
  await _waitUntil(
    tester,
    () async => tester.widget<TextField>(field).enabled != false,
  );
  await tester.enterText(field, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _back(WidgetTester tester) async {
  final button = find.byType(BackButton);
  if (button.evaluate().isNotEmpty) {
    await _tap(tester, button.last);
  } else {
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _menu(WidgetTester tester, String label) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await _waitFor(tester, find.byTooltip('Mais opções'));
    await _tap(tester, find.byTooltip('Mais opções'));
    final labelFinder = find.text(label);
    if (labelFinder.evaluate().isNotEmpty) {
      final item = find.ancestor(
        of: labelFinder,
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
      );
      if (item.evaluate().isEmpty ||
          tester.widget<PopupMenuItem<String>>(item.last).enabled) {
        await _tap(tester, labelFinder);
        return;
      }
    }
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
  }
  fail('Menu capability/action unavailable: $label');
}

Future<void> _refreshCatalog(WidgetTester tester) async {
  await _menu(tester, 'Atualizar catálogo');
  final catalog = find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byWidgetPredicate((w) => w is FutureBuilder<List<Cartilha>>),
  );
  await _reveal(tester, catalog, within: find.byType(HomeScreen));
  // Await the request started by the real menu; do not issue another request
  // or invoke a controller command to make the visible catalog pass.
  await tester
      .widget<FutureBuilder<List<Cartilha>>>(catalog)
      .future!
      .timeout(const Duration(seconds: 120));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _signedIn(
  WidgetTester tester,
  _Api api,
  SharedPreferences prefs,
  _Actor actor, {
  required Map<String, dynamic> evidence,
}) async {
  final current = await api.auth.localUserId();
  final hasSession = await api.auth.hasSession();
  final accountEvidence = <String, dynamic>{
    'initial_has_session': hasSession,
    'initial_owner_matches_requested_actor': current == actor.id,
    'settings_state': 'not_opened',
  };
  evidence['account_access'] = accountEvidence;
  Future<bool> inspectAccountSettings() async {
    final connected = await _accountSettingsReady(tester);
    final resolvedSession = await api.auth.hasSession();
    final resolvedOwner = await api.auth.localUserId();
    accountEvidence.addAll({
      'settings_state': connected ? 'connected' : 'signed_out',
      'resolved_has_session': resolvedSession,
      'resolved_owner_matches_initial': resolvedOwner == current,
      'session_invalidated_during_verification': hasSession && !resolvedSession,
    });
    expect(
      resolvedSession,
      connected,
      reason: 'Settings account state disagrees with the local session.',
    );
    return connected;
  }

  expect(
    hasSession && current == null,
    isFalse,
    reason: 'Cannot identify existing session; refuse account replacement.',
  );
  expect(
    current == null ||
        {
          _author.id,
          _publisher.id,
          _learner.id,
          _priorQaTeacher,
        }.contains(current),
    isTrue,
    reason: 'Refuse logout of an unknown identity.',
  );
  await tester.pumpWidget(const CartilhasApp());
  await _waitUntil(
    tester,
    () async =>
        find.byType(HomeScreen).evaluate().isNotEmpty ||
        find.text('Já tenho conta').evaluate().isNotEmpty,
  );
  var settingsOpen = false;
  if (current != null && current != actor.id) {
    // Existing Settings logout clears these legacy drafts. Refuse that operation
    // if unrelated data would be removed; never clear or rewrite it in the test.
    expect(
      (await _queue.pending()).where((e) => e.localOwnerId == null),
      isEmpty,
      reason: 'Anonymous evidence must be reconciled before account switching.',
    );
    final assessment = prefs.getString('study_assessment:sync:v1');
    expect(
      assessment == null || (jsonDecode(assessment) as Map).isEmpty,
      isTrue,
      reason: 'Refuse logout that would clear assessment synchronization data.',
    );
    expect(
      prefs.get('evidence:pending_checkin:v1'),
      isNull,
      reason: 'Refuse logout that would clear an attendance draft.',
    );
    await _menu(tester, 'Configurações');
    settingsOpen = true;
    final connected = await inspectAccountSettings();
    if (connected) {
      expect(
        await api.auth.localUserId(),
        current,
        reason:
            'The account changed during Settings verification; refuse logout.',
      );
      await _tap(
        tester,
        find.text('Sair da conta'),
        within: find.byType(SettingsScreen),
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Sair da conta'));
      await _waitFor(tester, find.text('Já tenho conta'));
      settingsOpen = false;
    } else {
      // Settings can invalidate an expired session while verifying /auth/me.
      // Follow its explicit signed-out UI; never force logout or clear tokens.
      expect(
        await api.auth.hasSession(),
        isFalse,
        reason: 'Signed-out Settings disagrees with the local session.',
      );
      expect(await api.auth.localUserId(), isNull);
    }
  }
  if (current != actor.id) {
    final welcome = find.text('Já tenho conta').evaluate().isNotEmpty;
    if (welcome) {
      await _tap(tester, find.text('Já tenho conta'));
    } else {
      if (!settingsOpen) {
        await _menu(tester, 'Configurações');
      }
      expect(
        await inspectAccountSettings(),
        isFalse,
        reason:
            'Refuse replacing a connected account through the login action.',
      );
      expect(await api.auth.hasSession(), isFalse);
      await _tap(
        tester,
        find.byKey(const Key('account-login-action')),
        within: find.byType(SettingsScreen),
      );
    }
    await _waitFor(tester, find.byKey(const Key('account-login-cpf')));
    await tester.enterText(
      find.byKey(const Key('account-login-cpf')),
      actor.cpf,
    );
    await tester.enterText(
      find.byKey(const Key('account-password')),
      actor.password,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _waitUntil(
      tester,
      () async => await api.auth.localUserId() == actor.id,
    );
    if (welcome) {
      await _waitFor(tester, find.text('Concordar e continuar'));
      await _tap(tester, find.text('Concordar e continuar'));
    } else {
      await _waitUntil(
        tester,
        () async => find.byType(AlertDialog).evaluate().isEmpty,
      );
      await _back(tester);
    }
  }
  await _waitFor(tester, find.byType(HomeScreen));
  expect((await api.auth.currentUser()).id, actor.id);
  accountEvidence['final_owner_verified'] = true;
}

Future<bool> _accountSettingsReady(WidgetTester tester) async {
  final settings = find.byType(SettingsScreen);
  await _waitFor(tester, settings);
  const labels = {
    'Verificando conta online',
    'Conta online conectada',
    'Sem conta online conectada',
  };
  final accountState = find.descendant(
    of: settings,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && labels.contains(widget.data),
    ),
  );
  // This row exists during loading, unlike the conditional login/logout tile.
  // Reveal it once, then wait for the real asynchronous account verification.
  await _reveal(tester, accountState, within: settings);
  final connected = find.descendant(
    of: settings,
    matching: find.text('Conta online conectada'),
  );
  final disconnected = find.descendant(
    of: settings,
    matching: find.text('Sem conta online conectada'),
  );
  await _waitUntil(
    tester,
    () async =>
        connected.evaluate().isNotEmpty || disconnected.evaluate().isNotEmpty,
    reason: 'Settings did not finish its explicit account verification.',
  );
  return connected.evaluate().isNotEmpty;
}

Future<void> _openEditor(WidgetTester tester, _Api api) async {
  final programs = (await api.get('/editor/context'))['programs'] as List;
  final program = programs.singleWhere((p) => p['id'] == _program) as Map;
  await _menu(tester, 'Meus conteúdos');
  await _waitFor(tester, find.byType(CourseEditorCatalogScreen));
  final chooser = find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField<String>,
  );
  await _waitFor(tester, chooser);
  if (tester.widget<DropdownButtonFormField<String>>(chooser).initialValue !=
      _program) {
    await _tap(tester, chooser);
    await _tap(tester, find.text(program['name'] as String).last);
  }
}

Future<void> _openEditorialCourse(WidgetTester tester, String title) async {
  await _waitFor(tester, find.text(title));
  await _tap(
    tester,
    find.text(title),
    within: find.byType(CourseEditorCatalogScreen),
  );
  await _waitFor(tester, _editor);
  await _editorLoaded(tester);
}

Future<void> _editorLoaded(WidgetTester tester) => _waitUntil(
  tester,
  () async =>
      find
          .descendant(
            of: _editor,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.labelText == 'Título do curso',
            ),
          )
          .evaluate()
          .isNotEmpty &&
      find
          .descendant(
            of: _editor,
            matching: find.byType(LinearProgressIndicator),
          )
          .evaluate()
          .isEmpty,
);

Future<void> _saveEditor(
  WidgetTester tester,
  _Api api, {
  required String title,
}) async {
  await _tap(tester, find.text('Salvar rascunho'), within: _editor);
  await _waitUntil(
    tester,
    () async =>
        (await api.editor())['title'] == title &&
        find.text('Alterações não salvas').evaluate().isEmpty,
  );
}

Future<void> _transition(WidgetTester tester, String action) async {
  await _tap(tester, find.text(action), within: _editor);
  await _waitFor(tester, find.byType(AlertDialog));
  await _tap(tester, find.widgetWithText(FilledButton, 'Confirmar'));
}

Future<Map<String, dynamic>> _editorStatus(
  WidgetTester tester,
  _Api api,
  String status,
) async {
  Map<String, dynamic>? value;
  await _waitUntil(tester, () async {
    value = await api.editor();
    return value!['status'] == status;
  });
  return value!;
}

Future<void> _preview(WidgetTester tester, _Api api, String content) async {
  final before = (await api.events())
      .where((e) => _teachingTypes.contains(e['event_type']))
      .toList();
  await _tap(tester, find.text('Pré-visualizar'), within: _editor);
  await _waitFor(
    tester,
    find.text('Leitura de conferência. Não registra progresso nem respostas.'),
  );
  await _reveal(tester, find.text(content));
  expect(find.text('Continuar'), findsNothing);
  await _back(tester);
  final after = (await api.events())
      .where((e) => _teachingTypes.contains(e['event_type']))
      .toList();
  expect(after, before);
}

Future<void> _assertPublic(_Api api, int edition, String version) async {
  final value = await api.publicGet('/courses/$_course');
  expect(value['course_version_id'], version);
  expect(value['title'], _title(edition));
  expect(
    ((value['sections'] as List).single['messages'] as List).first['content'],
    _block(0, edition: edition),
  );
}

Future<void> _selectCohort(
  WidgetTester tester,
  int edition, {
  bool explicit = false,
}) async {
  await _waitFor(tester, find.byType(HomeScreen));
  await _reveal(
    tester,
    find.byType(LearningHomeCard),
    within: find.byType(HomeScreen),
  );
  await _waitUntil(
    tester,
    () async =>
        find.text('Continuar estudo').evaluate().isNotEmpty ||
        find
            .text('Escolha a turma em que você quer estudar.')
            .evaluate()
            .isNotEmpty,
  );
  final card = find.byType(LearningHomeCard);
  final selected = find.descendant(
    of: card,
    matching: find.textContaining(_className(edition)),
  );
  if (!explicit &&
      find.text('Continuar estudo').evaluate().isNotEmpty &&
      selected.evaluate().isNotEmpty) {
    return;
  }
  if (find.text('Trocar turma').evaluate().isNotEmpty) {
    await _tap(tester, find.text('Trocar turma'), within: card);
  }
  await _tap(
    tester,
    find.descendant(of: card, matching: find.text(_className(edition))),
    within: find.byType(HomeScreen),
  );
  await _waitFor(tester, find.text('Continuar estudo'));
}

Future<void> _expectHome(
  WidgetTester tester,
  int edition,
  Map value, {
  bool offline = false,
}) async {
  await _waitFor(tester, find.byType(HomeScreen));
  await _reveal(
    tester,
    find.byType(LearningHomeCard),
    within: find.byType(HomeScreen),
  );
  await _waitFor(tester, find.text('Continuar estudo'));
  final card = find.byType(LearningHomeCard);
  expect(
    find.descendant(
      of: card,
      matching: find.textContaining(_className(edition)),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: card, matching: find.textContaining(_title(edition))),
    findsOneWidget,
  );
  final percent = (_progress(value)['progress_percent'] as num).toStringAsFixed(
    0,
  );
  await _waitFor(
    tester,
    find.descendant(
      of: card,
      matching: find.text('Progresso confirmado: $percent%'),
    ),
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

Future<void> _openReader(
  WidgetTester tester,
  String cohort,
  String version,
  String title,
) async {
  await _tap(
    tester,
    find.text('Continuar estudo'),
    within: find.byType(HomeScreen),
  );
  await _waitFor(tester, _reader);
  final screen = tester.widget<ChatExperienceScreen>(_reader);
  expect(screen.cartilha.id, _course);
  expect(screen.cartilha.classId, cohort);
  expect(screen.cartilha.courseVersionId, version);
  expect(screen.cartilha.title, title);
  expect(
    screen.learningContextController!.snapshot!.context.userId,
    _learner.id,
  );
}

void _checkContext(Map value, String cohort, String version) {
  final snapshot = LearningContextSnapshot.fromJson(
    Map<String, dynamic>.from(value),
  );
  expect(snapshot.contractVersion, 'cohort-enrollment-v2');
  expect(snapshot.context.userId, _learner.id);
  expect(snapshot.context.programId, _program);
  expect(snapshot.context.cohortId, cohort);
  expect(snapshot.context.courseId, _course);
  expect(snapshot.context.courseVersionId, version);
  expect(snapshot.context.role, 'student');
  expect(
    snapshot.context.permissions,
    containsAll({'content.read', 'progress.read', 'activity.record'}),
  );
}

void _checkProgress(
  Map value,
  List<Map<String, dynamic>> events,
  String cohort,
) {
  expect(events.map((e) => e['event_id']).toSet().length, events.length);
  final seconds = events
      .where(
        (e) =>
            e['event_type'] == 'study_activity' &&
            (e['payload'] as Map)['class_id'] == cohort,
      )
      .fold<int>(
        0,
        (total, event) => total + (event['validated_seconds'] as num).toInt(),
      );
  expect(seconds, greaterThanOrEqualTo(2));
  expect(
    _progress(value)['progress_percent'],
    double.parse((seconds * 100 / 120).toStringAsFixed(2)).clamp(0, 100),
  );
  expect(
    _progress(value)['validated_hours'],
    double.parse((seconds / 3600).toStringAsFixed(4)),
  );
}

Future<StudyProgress> _position(Map value) async {
  final context = LearningContext.fromJson(
    Map<String, dynamic>.from(value['context'] as Map),
  );
  final saved = await const StudyProgressRepository().load(
    _course,
    courseVersionId: context.courseVersionId,
    ownerId: _learner.id,
    contextKey: context.resumeKey(AppConfig.tutorApiUrl),
  );
  expect(saved, isNotNull);
  return saved!;
}

void _samePosition(StudyProgress value, Map expected) => expect(
  value.toJson()..remove('updatedAt'),
  Map.of(expected)..remove('updatedAt'),
);
Future<List<LearningEvent>> _pending() async =>
    // Account switching preserves other actors' queues. The learner cannot
    // deliver an author's record, nor should this gate adopt it.
    (await _queue.pending())
        .where(
          (e) =>
              e.courseId == _course &&
              e.localOwnerId == _learner.id &&
              e.localApiUrl == AppConfig.tutorApiUrl,
        )
        .toList();
Future<void> _drained(WidgetTester tester) => _waitUntil(
  tester,
  () async => (await _pending()).isEmpty,
  reason: 'Real dynamic-course outbox did not drain.',
);
void _historyPreserved(List before, List<Map<String, dynamic>> after) {
  for (final event in before.cast<Map>()) {
    final saved = after.singleWhere((e) => e['event_id'] == event['event_id']);
    for (final key in [
      'event_id',
      'course_id',
      'event_type',
      'session_id',
      'occurred_at',
      'payload',
      'active_seconds',
      'validated_seconds',
    ]) {
      expect(
        saved[key],
        event[key],
        reason: 'Existing event field changed: $key',
      );
    }
  }
}

class _Api {
  final auth = AuthRepository(apiUrl: AppConfig.tutorApiUrl);
  final client = http.Client();
  Uri uri(String path) => Uri.parse('${AppConfig.tutorApiUrl}$path');
  Future<Map<String, dynamic>> get(String path) async {
    final response = await auth.authorized(
      (token) => client
          .get(uri(path), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15)),
    );
    expect(response.statusCode, 200, reason: 'GET $path failed.');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> publicGet(String path) async {
    final response = await client
        .get(uri(path))
        .timeout(const Duration(seconds: 15));
    expect(response.statusCode, 200, reason: 'Public GET $path failed.');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<int> publicStatus(String path) async =>
      (await client.get(uri(path)).timeout(const Duration(seconds: 15)))
          .statusCode;
  Future<int> status(String path) async => (await auth.authorized(
    (token) => client
        .get(uri(path), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15)),
  )).statusCode;
  Future<bool> publicContainsCourse() async =>
      ((await publicGet('/courses'))['courses'] as List).any(
        (e) => e['id'] == _course,
      );
  Future<Map<String, dynamic>> editor({String? version}) => get(
    '/editor/courses/$_course${version == null ? '' : '?version_id=${Uri.encodeComponent(version)}'}',
  );
  Future<Map<String, dynamic>> context(String cohort) =>
      get('/classes/${Uri.encodeComponent(cohort)}/learning-context');
  Future<String> cohort(int edition, String version) async {
    final rows = ((await get('/classes?enrolled_only=true'))['classes'] as List)
        .where((e) => e['name'] == _className(edition))
        .toList();
    expect(
      rows,
      hasLength(1),
      reason:
          'Host must provision exactly one named cohort between publication phases.',
    );
    final value = rows.single as Map;
    expect(value['program_id'], _program);
    expect(value['course_id'], _course);
    expect(value['course_version_id'], version);
    return value['id'] as String;
  }

  Future<List<Map<String, dynamic>>> events() async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; offset < 10000; offset += 100) {
      final page =
          (await get(
                '/events?course_id=$_course&limit=100&offset=$offset',
              ))['events']
              as List;
      result.addAll(page.map((e) => Map<String, dynamic>.from(e as Map)));
      if (page.length < 100) return result;
    }
    throw StateError(
      'Unexpected event volume in synthetic dynamic-course fixture.',
    );
  }

  Future<int> probe(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async => (await auth.authorized((token) {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    return (method == 'PATCH'
            ? client.patch(uri(path), headers: headers, body: jsonEncode(body))
            : client.post(uri(path), headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 15));
  })).statusCode;
  Future<void> requireOffline() async {
    try {
      await client.get(uri('/health')).timeout(const Duration(seconds: 4));
    } on http.ClientException {
      return;
    } on TimeoutException {
      return;
    }
    fail(
      'Offline phase requires unreachable staging; host must disconnect QA emulator.',
    );
  }

  void dispose() {
    auth.dispose();
    client.close();
  }
}
