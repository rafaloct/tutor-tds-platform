import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/presentation/student_followup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

// Real feature UI, scoped repository and HTTPS. Staff tokens exist only in RAM;
// no existing phone account, preferences, consent or queue is read/overwritten.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Reviewed BI reference without historical tablet code',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(AppConfig.journeyTraceabilityEnabled, isTrue);
      expect(
        AppConfig.tutorApiUrl,
        'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api',
      );
      final run = const String.fromEnvironment('JOURNEY_QA_RUN_ID');
      final student = const String.fromEnvironment('QA_STUDENT_ID');
      final teacher = const String.fromEnvironment('QA_TEACHER_ID');
      final auth = AuthRepository(
        apiUrl: AppConfig.tutorApiUrl,
        tokenStore: _RamTokens(),
      );
      final repo = ClassroomRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      final client = http.Client();
      Future<Map<String, dynamic>> get(String path) async {
        final response = await auth.authorized(
          (token) => client
              .get(
                Uri.parse('${AppConfig.tutorApiUrl}$path'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 15)),
        );
        expect(response.statusCode, 200);
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }

      try {
        await auth.login(
          cpf: const String.fromEnvironment('QA_TEACHER_CPF'),
          password: const String.fromEnvironment('QA_TEACHER_PASSWORD'),
        );
        final initial = await repo.studentBaseline('qa-cohort', student);
        expect(
          initial['baseline'],
          isNull,
          reason: 'Fresh disposable participant required; never reset history',
        );
        expect((initial['pessoa_id'] as String).length, 64);
        final before = await get('/classes/qa-cohort/journey-export');
        expect(before['items'], isEmpty);
        expect((before['pending'] as List).single['status'], 'bi_link_pending');
        final dashboard = await repo.dashboard('qa-cohort');
        await tester.pumpWidget(
          MaterialApp(
            home: StudentFollowupScreen(
              repository: repo,
              classroom: dashboard.classroom,
              students: dashboard.students,
              staffId: teacher,
              journeyEnabled: true,
            ),
          ),
        );
        await _tap(tester, find.byType(DropdownButtonFormField<String>));
        await _tap(tester, find.text(dashboard.students.single.name).last);
        await _wait(tester, find.text('Baseline ainda não vinculado'));
        expect(
          find.text('ID de acompanhamento: ${initial['pessoa_id']}'),
          findsOneWidget,
        );
        await _tap(tester, find.text('Conferir vínculo do baseline'));
        await _tap(tester, find.byKey(const ValueKey('baseline-bi-reference')));
        expect(find.text('ID local do registro'), findsNothing);
        await _fill(tester, 'Data da coleta (AAAA-MM-DD)', '2026-10-01');
        await _fill(
          tester,
          'Inscrição no BI (ex.: DIG-0001; opcional)',
          'QA-DIG-$run',
        );
        await _fill(
          tester,
          'Justificativa da vinculação',
          'Conferência sintética do método de controle por Rafael',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await _tap(tester, find.byType(CheckboxListTile).last);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Salvar online'),
              )
              .onPressed,
          isNotNull,
        );
        await _tap(tester, find.text('Salvar online'));
        await _wait(tester, find.text('Inscrição do programa: QA-DIG-$run'));
        final confirmed = await repo.studentBaseline('qa-cohort', student);
        final baseline = confirmed['baseline'] as Map;
        expect(baseline['source'], 'fabric:tds-inscription-v1');
        expect(baseline['record_id'], 'QA-DIG-$run');
        expect(baseline['bi_record_id'], 'QA-DIG-$run');
        expect(confirmed['pessoa_id'], initial['pessoa_id']);
        expect(confirmed['history'], hasLength(1));
        final exported = await get('/classes/qa-cohort/journey-export');
        final item = (exported['items'] as List).single as Map;
        expect(item['pessoa_id'], initial['pessoa_id']);
        expect(item['registro_id'], 'QA-DIG-$run');
        expect(item['horas_estudo_validadas'], 0);
        expect(item['certificado_flag'], isNull);
        expect(item['concluiu_frequencia_flag'], isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        binding.reportData = {
          'run_id': run,
          'phase': 'baseline',
          'pid': pid,
          'package': 'com.tutortds_cartilhas.dev',
          'api': AppConfig.tutorApiUrl,
          'production_changed': false,
          'assertions': {
            'scoped_feature_ui_real_https': true,
            'pending_identity_before_baseline': true,
            'reviewed_bi_only_reference': true,
            'same_id_before_and_after': true,
            'audit_history': true,
            'no_phone_account_or_queue_mutation': true,
            'learning_hours': 0,
            'attendance': null,
            'certificate': null,
          },
        };
      } finally {
        repo.dispose();
        auth.dispose();
        client.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _wait(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(finder, findsWidgets);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _wait(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fill(WidgetTester tester, String label, String value) async {
  final finder = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  await _wait(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(finder, value);
}

class _RamTokens implements AuthTokenStore {
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
