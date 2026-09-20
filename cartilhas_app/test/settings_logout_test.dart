import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/screens/settings_screen.dart';
import 'package:cartilhas_app/screens/welcome_screen.dart';
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

  testWidgets('logout confirma, preserva dados locais e volta ao login', (
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
    });
    final tokenStore = _TokenStore();
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
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
    expect(
      find.textContaining('não são separados por usuário'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sair da conta'));
    await tester.pumpAndSettle();

    expect(tokenStore.value, isNull);
    expect(find.text('Bem-vindo ao TDS'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), 'Pessoa no aparelho');
    expect(prefs.getString('study_progress:last'), 'progresso-local');
    expect(prefs.getString('learning_events:pending:v1'), isNull);
    expect(prefs.getString('study_assessment:sync:v1'), isNull);

    // Simula o novo processo do app: o perfil local leva à Home mesmo sem
    // sessão, e Configurações precisa continuar oferecendo reentrada online.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tutor TDS'), findsOneWidget);
    expect(tokenStore.value, isNull);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conta online conectada'), findsOneWidget);
    expect(find.text('Entrar na conta online'), findsOneWidget);
    await tester.tap(find.text('Entrar na conta online'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('account-login-cpf')),
      '52998224725',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'senha-segura-2026',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar na conta'));
    await tester.pumpAndSettle();

    expect(tokenStore.value?.accessToken, 'new-access');
    expect(find.text('Conta online conectada'), findsOneWidget);
    expect(find.textContaining('Nova Pessoa • perfil monitor'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(prefs.getString('study_progress:last'), 'progresso-local');
    expect(prefs.getString('user_name'), 'Nova Pessoa');
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
