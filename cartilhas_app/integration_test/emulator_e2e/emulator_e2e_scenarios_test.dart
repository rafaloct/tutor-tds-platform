import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/classrooms/presentation/classroom_dashboard_screen.dart';
import 'package:cartilhas_app/features/classrooms/presentation/learner_classrooms_screen.dart';
import 'package:cartilhas_app/features/course_editor/presentation/course_editor_screen.dart';
import 'package:cartilhas_app/features/management/presentation/management_workspace_screen.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:cartilhas_app/screens/privacy_screen.dart';
import 'package:cartilhas_app/screens/settings_screen.dart';
import 'package:cartilhas_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _environment = String.fromEnvironment('TUTOR_ENVIRONMENT');
const _baseUrl = String.fromEnvironment('EMULATOR_E2E_BASE_URL');
const _package = String.fromEnvironment('EMULATOR_E2E_QA_PACKAGE');
const _scenario = String.fromEnvironment('EMULATOR_E2E_SCENARIO');
const _runId = String.fromEnvironment('EMULATOR_E2E_RUN_ID');
const _offlinePhase = String.fromEnvironment('EMULATOR_E2E_OFFLINE_PHASE');
const _certificateContext = String.fromEnvironment(
  'EMULATOR_E2E_CERTIFICATE_CONTEXT_ID',
);

const _studentCpf = String.fromEnvironment('STAGING_SEED_STUDENT_CPF');
const _studentPassword = String.fromEnvironment(
  'STAGING_SEED_STUDENT_PASSWORD',
);
const _teacherCpf = String.fromEnvironment('STAGING_SEED_TEACHER_CPF');
const _teacherPassword = String.fromEnvironment(
  'STAGING_SEED_TEACHER_PASSWORD',
);
const _monitorCpf = String.fromEnvironment('STAGING_SEED_MONITOR_CPF');
const _monitorPassword = String.fromEnvironment(
  'STAGING_SEED_MONITOR_PASSWORD',
);
const _adminCpf = String.fromEnvironment('STAGING_SEED_ADMIN_CPF');
const _adminPassword = String.fromEnvironment('STAGING_SEED_ADMIN_PASSWORD');
const _operatorCpf = String.fromEnvironment('STAGING_SEED_OPERATOR_CPF');
const _operatorPassword = String.fromEnvironment(
  'STAGING_SEED_OPERATOR_PASSWORD',
);

const _studentId = 'staging-qa-student';
const _teacherId = 'staging-qa-teacher';
const _monitorId = 'staging-qa-monitor';
const _adminId = 'staging-qa-admin';
const _className = 'Turma Sintética QA [STAGING]';

const _scenarios = <String>[
  'login_activation',
  'account_switch',
  'participant_flow',
  'offline_reconnect',
  'teacher_dashboard',
  'monitor_projection',
  'creator_surface',
  'operator_flow',
  'certificate',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('emulator E2E configuration (fail-closed)', () {
    test('QA configuration is present and staging only', () {
      expect(Platform.isAndroid, isTrue);
      expect(_environment, 'staging');
      expect(AppConfig.tutorApiUrl, _baseUrl);
      expect(_baseUrl, startsWith('https://'));
      expect(_baseUrl, contains('staging'));
      expect(_runId, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(_package, 'com.tutortds_cartilhas.dev.dynamicqa.r$_runId');
      expect(_scenarios, contains(_scenario));
    });
  });

  testWidgets('selected emulator E2E scenario', (tester) async {
    final evidence = <String, Object?>{
      'scenario': _scenario,
      'run_id': _runId,
      'package': _package,
      'api': _baseUrl,
      'production_changed': false,
    };

    switch (_scenario) {
      case 'login_activation':
        _require(_studentCpf, 'STAGING_SEED_STUDENT_CPF');
        _require(_studentPassword, 'STAGING_SEED_STUDENT_PASSWORD');
        await _startFresh(tester);
        await _assertActivationEntryPoint(tester);
        await _loginFromWelcome(
          tester,
          cpf: _studentCpf,
          password: _studentPassword,
          expectedUserId: _studentId,
        );
        evidence['activation_field_visible'] = true;
        evidence['student_login'] = true;

      case 'account_switch':
        _require(_studentCpf, 'STAGING_SEED_STUDENT_CPF');
        _require(_studentPassword, 'STAGING_SEED_STUDENT_PASSWORD');
        _require(_teacherCpf, 'STAGING_SEED_TEACHER_CPF');
        _require(_teacherPassword, 'STAGING_SEED_TEACHER_PASSWORD');
        await _startFresh(tester);
        await _loginFromWelcome(
          tester,
          cpf: _studentCpf,
          password: _studentPassword,
          expectedUserId: _studentId,
        );
        await _logoutViaSettings(tester);
        await _loginFromWelcome(
          tester,
          cpf: _teacherCpf,
          password: _teacherPassword,
          expectedUserId: _teacherId,
        );
        evidence['student_logged_out'] = true;
        evidence['teacher_logged_in_after_switch'] = true;

      case 'participant_flow':
        _require(_studentCpf, 'STAGING_SEED_STUDENT_CPF');
        _require(_studentPassword, 'STAGING_SEED_STUDENT_PASSWORD');
        await _startFresh(tester);
        await _loginFromWelcome(
          tester,
          cpf: _studentCpf,
          password: _studentPassword,
          expectedUserId: _studentId,
        );
        await _openLearnerClass(tester);
        expect(find.byType(ChatExperienceScreen), findsOneWidget);
        evidence['class_visible'] = true;
        evidence['class_course_opened'] = true;

      case 'teacher_dashboard':
        _require(_teacherCpf, 'STAGING_SEED_TEACHER_CPF');
        _require(_teacherPassword, 'STAGING_SEED_TEACHER_PASSWORD');
        await _startFresh(tester);
        await _loginFromWelcome(
          tester,
          cpf: _teacherCpf,
          password: _teacherPassword,
          expectedUserId: _teacherId,
        );
        await _openManagement(tester);
        expect(find.text('Turmas e equipe'), findsOneWidget);
        await _tap(tester, find.text('Turmas e equipe'));
        await _until(
          tester,
          () async =>
              find.byType(ClassroomDashboardScreen).evaluate().isNotEmpty,
        );
        expect(find.text('Área da equipe'), findsWidgets);
        await _until(
          tester,
          () async => find
              .text('Revisar pedidos de certificado')
              .evaluate()
              .isNotEmpty,
        );
        expect(find.text('Revisar pedidos de certificado'), findsOneWidget);
        evidence['full_teacher_dashboard'] = true;

      case 'monitor_projection':
        _require(_monitorCpf, 'STAGING_SEED_MONITOR_CPF');
        _require(_monitorPassword, 'STAGING_SEED_MONITOR_PASSWORD');
        await _startFresh(tester);
        await _loginFromWelcome(
          tester,
          cpf: _monitorCpf,
          password: _monitorPassword,
          expectedUserId: _monitorId,
        );
        final auth = _authFromHome(tester);
        await _openManagement(tester);
        expect(find.text('Acompanhamento da turma'), findsOneWidget);
        await _tap(tester, find.text('Acompanhamento da turma'));
        await _until(
          tester,
          () async =>
              find.byType(ClassroomDashboardScreen).evaluate().isNotEmpty,
        );
        await _until(
          tester,
          () async =>
              find.text('Quem precisa de atenção').evaluate().isNotEmpty,
        );
        expect(find.text('Incluir estudantes'), findsNothing);
        expect(find.text('Baseline e mentoria dos estudantes'), findsNothing);
        expect(find.textContaining('Matrícula interna'), findsNothing);
        final monitor = await _authorizedGet(
          auth,
          '/classes/staging-qa-class/monitor-exceptions',
        );
        expect(monitor.statusCode, 200);
        final monitorPayload = Map<String, dynamic>.from(
          jsonDecode(monitor.body) as Map,
        );
        expect(monitorPayload.keys.toSet(), {
          'generated_at',
          'total_students',
          'attention_students',
          'students',
        });
        final serialized = jsonEncode(monitorPayload);
        for (final forbidden in [
          'planned_hours',
          'validated_hours',
          'progress_percent',
          'enrollment_id',
          'baseline',
          'mentorship',
        ]) {
          expect(serialized, isNot(contains(forbidden)));
        }
        final dashboard = await _authorizedGet(
          auth,
          '/classes/staging-qa-class/dashboard',
        );
        expect(dashboard.statusCode, 403);
        evidence['monitor_projection_200'] = true;
        evidence['monitor_dashboard_403'] = true;
        evidence['minimal_payload'] = true;

      case 'creator_surface':
        _require(_adminCpf, 'STAGING_SEED_ADMIN_CPF');
        _require(_adminPassword, 'STAGING_SEED_ADMIN_PASSWORD');
        await _startFresh(tester);
        await _loginFromWelcome(
          tester,
          cpf: _adminCpf,
          password: _adminPassword,
          expectedUserId: _adminId,
        );
        await _openManagement(tester);
        await _until(
          tester,
          () async => find.text('Conteúdos').evaluate().isNotEmpty,
        );
        await _tap(tester, find.text('Conteúdos'));
        await _until(
          tester,
          () async =>
              find.byType(CourseEditorCatalogScreen).evaluate().isNotEmpty,
        );
        expect(find.text('Meus conteúdos'), findsOneWidget);
        await _until(
          tester,
          () async => find.text('Criar curso').evaluate().isNotEmpty,
        );
        expect(find.text('Criar curso'), findsOneWidget);
        evidence['creator_catalog'] = true;
        evidence['creator_create_entrypoint'] = true;

      case 'offline_reconnect':
        _require(_studentCpf, 'STAGING_SEED_STUDENT_CPF');
        _require(_studentPassword, 'STAGING_SEED_STUDENT_PASSWORD');
        await _offlineScenario(tester, evidence);

      case 'operator_flow':
        _require(_operatorCpf, 'STAGING_SEED_OPERATOR_CPF');
        _require(_operatorPassword, 'STAGING_SEED_OPERATOR_PASSWORD');
        fail(
          'operator_flow requires the canonical program_operator fixture. '
          'Blocked by Issue #120; no admin/creator substitution is allowed.',
        );

      case 'certificate':
        _require(_certificateContext, 'EMULATOR_E2E_CERTIFICATE_CONTEXT_ID');
        fail(
          'certificate remains an explicit optional gate and is not part of '
          'the #122 profile acceptance run.',
        );

      default:
        fail('Unknown scenario $_scenario');
    }

    binding.reportData = evidence;
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _startFresh(WidgetTester tester) async {
  await tester.pumpWidget(const CartilhasApp());
  await _until(
    tester,
    () async =>
        find.byType(WelcomeScreen).evaluate().isNotEmpty ||
        find.byType(HomeScreen).evaluate().isNotEmpty ||
        find.byType(PrivacyConsentScreen).evaluate().isNotEmpty,
  );
}

Future<void> _assertActivationEntryPoint(WidgetTester tester) async {
  expect(find.byType(WelcomeScreen), findsOneWidget);
  final fields = find.byType(TextFormField);
  expect(fields, findsAtLeastNWidgets(3));
  await tester.enterText(fields.at(0), 'Pessoa QA E2E');
  await tester.enterText(fields.at(1), '61999990000');
  await tester.enterText(fields.at(2), _studentCpf);
  await _tap(tester, find.text('Criar conta'));
  await _until(
    tester,
    () async => find
        .byKey(const ValueKey('account-activation-code'))
        .evaluate()
        .isNotEmpty,
  );
  expect(
    find.text('Código de ativação fornecido pela instituição'),
    findsOneWidget,
  );
  await _tap(tester, find.text('Cancelar'));
}

Future<void> _loginFromWelcome(
  WidgetTester tester, {
  required String cpf,
  required String password,
  required String expectedUserId,
}) async {
  await _until(
    tester,
    () async => find.byType(WelcomeScreen).evaluate().isNotEmpty,
  );
  await _tap(tester, find.text('Já tenho conta'));
  await _until(
    tester,
    () async =>
        find.byKey(const ValueKey('account-login-cpf')).evaluate().isNotEmpty,
  );
  await tester.enterText(find.byKey(const ValueKey('account-login-cpf')), cpf);
  await tester.enterText(
    find.byKey(const ValueKey('account-password')),
    password,
  );
  await _tap(tester, find.text('Entrar na conta'));
  await _until(
    tester,
    () async =>
        find.byType(PrivacyConsentScreen).evaluate().isNotEmpty ||
        find.byType(HomeScreen).evaluate().isNotEmpty,
  );
  if (find.byType(PrivacyConsentScreen).evaluate().isNotEmpty) {
    await _tap(tester, find.text('Concordar e continuar'));
  }
  await _home(tester);
  final auth = _authFromHome(tester);
  expect(await auth.localUserId(), expectedUserId);
}

AuthRepository _authFromHome(WidgetTester tester) =>
    tester.element(find.byType(HomeScreen)).read<AuthRepository>();

Future<void> _logoutViaSettings(WidgetTester tester) async {
  await _openMoreOption(tester, 'Configurações');
  await _until(
    tester,
    () async => find.byType(SettingsScreen).evaluate().isNotEmpty,
  );
  await _until(
    tester,
    () async => find.text('Sair da conta').evaluate().isNotEmpty,
  );
  await _tap(tester, find.text('Sair da conta').first);
  await _until(
    tester,
    () async => find.text('Sair da conta online?').evaluate().isNotEmpty,
  );
  await _tap(tester, find.widgetWithText(FilledButton, 'Sair da conta'));
  await _until(
    tester,
    () async => find.byType(WelcomeScreen).evaluate().isNotEmpty,
  );
}

Future<void> _openMoreOption(WidgetTester tester, String label) async {
  await _home(tester);
  await _tap(tester, find.byTooltip('Mais opções'));
  await _until(tester, () async => find.text(label).evaluate().isNotEmpty);
  await _tap(tester, find.text(label).last);
}

Future<void> _openManagement(WidgetTester tester) async {
  await _home(tester);
  await _until(tester, () async => find.text('Gestão').evaluate().isNotEmpty);
  await _tap(tester, find.text('Gestão').last);
  await _until(
    tester,
    () async => find.byType(ManagementWorkspaceScreen).evaluate().isNotEmpty,
  );
  expect(find.text('Gestão do programa'), findsOneWidget);
}

Future<void> _openLearnerClass(WidgetTester tester) async {
  await _openMoreOption(tester, 'Minhas turmas');
  await _until(
    tester,
    () async => find.byType(LearnerClassroomsScreen).evaluate().isNotEmpty,
  );
  await _until(tester, () async => find.text(_className).evaluate().isNotEmpty);
  await _tap(tester, find.text(_className));
  await _until(
    tester,
    () async => find.byType(ChatExperienceScreen).evaluate().isNotEmpty,
  );
}

Future<void> _offlineScenario(
  WidgetTester tester,
  Map<String, Object?> evidence,
) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'tds.e2e.offline.$_runId';
  switch (_offlinePhase) {
    case 'prime':
      await _startFresh(tester);
      await _loginFromWelcome(
        tester,
        cpf: _studentCpf,
        password: _studentPassword,
        expectedUserId: _studentId,
      );
      await _openLearnerClass(tester);
      await prefs.setString(key, 'primed');
      evidence['online_cache_primed'] = true;
    case 'offline':
      expect(prefs.getString(key), 'primed');
      await tester.pumpWidget(const CartilhasApp());
      await _home(tester);
      await _openMoreOption(tester, 'Minhas turmas');
      await _until(
        tester,
        () async => find
            .textContaining('Sem conexão: exibindo turmas salvas')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text(_className), findsOneWidget);
      await _tap(tester, find.text(_className));
      await _until(
        tester,
        () async => find.byType(ChatExperienceScreen).evaluate().isNotEmpty,
      );
      await prefs.setString(key, 'offline');
      evidence['offline_saved_class_opened'] = true;
    case 'reconnect':
      expect(prefs.getString(key), 'offline');
      await tester.pumpWidget(const CartilhasApp());
      await _home(tester);
      await _openMoreOption(tester, 'Minhas turmas');
      await _until(
        tester,
        () async => find.text(_className).evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('Sem conexão: exibindo turmas salvas'),
        findsNothing,
      );
      await prefs.remove(key);
      evidence['reconnected'] = true;
    default:
      fail('offline_reconnect requires prime/offline/reconnect host phase');
  }
}

Future<http.Response> _authorizedGet(AuthRepository auth, String path) =>
    auth.authorized(
      (token) => http
          .get(
            Uri.parse('${AppConfig.tutorApiUrl}$path'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15)),
    );

Future<void> _home(WidgetTester tester) =>
    _until(tester, () async => find.byType(HomeScreen).evaluate().isNotEmpty);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () async => finder.evaluate().isNotEmpty);
  final target = finder.evaluate().length > 1 ? finder.last : finder;
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(target, warnIfMissed: true);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _until(WidgetTester tester, Future<bool> Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    if (await ready()) return;
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('E2E condition did not become ready for scenario $_scenario');
}

void _require(String value, String name) {
  expect(value.trim(), isNotEmpty, reason: '$name is required');
}
