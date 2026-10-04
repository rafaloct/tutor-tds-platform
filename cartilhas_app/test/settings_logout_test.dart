import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/evidence/data/checkin_draft_store.dart';
import 'package:cartilhas_app/screens/settings_screen.dart';
import 'package:cartilhas_app/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenStore implements AuthTokenStore {
  AuthTokens? value = const AuthTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
  );

  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logout confirma, apaga dados acadêmicos e volta ao login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'user_name': 'Pessoa no aparelho',
      'privacy_notice_seen_v1': true,
      'study_progress:last': 'progresso-local',
      'learning_events:pending:v1': '[{"event_id":"old-user"}]',
      'study_assessment:sync:v1': '{"old-attempt":{}}',
      SharedPreferencesCheckinDraftStore.storageKey:
          '{"class_id":"class-1","session_id":"session-1","kind":"checkin","idempotency_key":"mobile:1","created_at":"2026-09-20T14:00:00Z"}',
    });
    final tokenStore = _TokenStore();
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      onSessionEnded: () async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.clear();
      },
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/auth/me') {
          return http.Response(
            '{"id":"old-user","name":"Pessoa anterior","role":"student"}',
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          return http.Response(
            '{"access_token":"new-access","refresh_token":"new-refresh","user":{"id":"monitor-1","name":"Nova Pessoa","role":"monitor"}}',
            200,
          );
        }
        return http.Response('{}', 500);
      }),
      tokenStore: tokenStore,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conta online conectada'), findsOneWidget);
    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Sair da conta online?'), findsOneWidget);
    expect(find.textContaining('conteúdo acadêmico local'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sair da conta'));
    await tester.pumpAndSettle();

    expect(tokenStore.value, isNull);
    expect(find.text('Bem-vindo ao TDS'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(prefs.getString('learning_events:pending:v1'), isNull);
    expect(prefs.getString('study_assessment:sync:v1'), isNull);
    expect(
      prefs.getString(SharedPreferencesCheckinDraftStore.storageKey),
      isNull,
    );
  });

  testWidgets('cancelar mantém sessão ativa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tokenStore = _TokenStore();
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: tokenStore,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tokenStore.value, isNotNull);
    expect(find.text('Configurações'), findsOneWidget);
  });
}
