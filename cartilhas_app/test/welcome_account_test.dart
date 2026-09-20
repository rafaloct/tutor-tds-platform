import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryTokenStore implements AuthTokenStore {
  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

String authResponse() => jsonEncode({
  'access_token': 'access-token',
  'refresh_token': 'refresh-token',
  'token_type': 'bearer',
  'expires_in': 900,
  'user': {'id': 'user-1', 'name': 'Aluno Teste', 'role': 'student'},
});

Future<void> pumpWelcome(WidgetTester tester, AuthRepository repository) async {
  await tester.pumpWidget(
    Provider<AuthRepository>.value(
      value: repository,
      child: const MaterialApp(home: WelcomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillLocalForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome completo'),
    'Aluno Teste',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'WhatsApp'),
    '63999990000',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'CPF'),
    '52998224725',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('API vazia preserva exatamente as opções locais', (tester) async {
    var networkCalled = false;
    final repository = AuthRepository(
      apiUrl: '',
      client: MockClient((_) async {
        networkCalled = true;
        return http.Response('{}', 500);
      }),
      tokenStore: MemoryTokenStore(),
    );

    await pumpWelcome(tester, repository);

    expect(find.text('Conta online opcional'), findsNothing);
    expect(find.text('Criar conta'), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
    expect(networkCalled, isFalse);
  });

  testWidgets('cria conta com loading e segue para onboarding', (tester) async {
    final release = Completer<void>();
    final store = MemoryTokenStore();
    late Map<String, dynamic> requestBody;
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        await release.future;
        return http.Response(authResponse(), 201);
      }),
      tokenStore: store,
    );
    await pumpWelcome(tester, repository);
    await fillLocalForm(tester);

    await tester.ensureVisible(find.text('Criar conta'));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta Tutor TDS'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'senha-segura-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password-confirmation')),
      'senha-segura-2026',
    );
    final passwordField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('account-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.text('Criar conta segura'));
    await tester.pump();
    expect(find.text('Criando conta...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();

    expect(requestBody['password'], 'senha-segura-2026');
    expect(store.value?.accessToken, 'access-token');
    expect(find.text('Aprenda no seu ritmo'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_cpf'), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'tutor_tds:profile_cpf:v1'),
      '529.982.247-25',
    );
    expect(
      prefs.getKeys().where((key) => key.toLowerCase().contains('password')),
      isEmpty,
    );
  });

  testWidgets('login mostra erro genérico sem repetir resposta remota', (
    tester,
  ) async {
    const leaked = 'senha-super-secreta-nao-exibir';
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response(leaked, 401)),
      tokenStore: MemoryTokenStore(),
    );
    await pumpWelcome(tester, repository);

    await tester.ensureVisible(find.text('Já tenho conta'));
    await tester.tap(find.text('Já tenho conta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-login-cpf')),
      '52998224725',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      leaked,
    );
    await tester.tap(find.text('Entrar na conta').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-error')), findsOneWidget);
    expect(find.text('CPF ou senha inválidos.'), findsOneWidget);
    final errorText = tester.widget<Text>(
      find.byKey(const ValueKey('account-error')),
    );
    expect(errorText.data, isNot(contains(leaked)));
  });

  testWidgets('login concluído segue para consentimento sem salvar CPF', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response(authResponse(), 200)),
      tokenStore: store,
    );
    await pumpWelcome(tester, repository);

    await tester.ensureVisible(find.text('Já tenho conta'));
    await tester.tap(find.text('Já tenho conta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-login-cpf')),
      '52998224725',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'senha-segura-2026',
    );
    await tester.tap(find.text('Entrar na conta').last);
    await tester.pumpAndSettle();

    expect(find.text('Você controla seus dados'), findsOneWidget);
    expect(store.value?.refreshToken, 'refresh-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), 'Aluno Teste');
    expect(prefs.getString('user_cpf'), isNull);
  });
}
