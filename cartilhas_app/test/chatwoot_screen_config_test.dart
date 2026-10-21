import 'dart:async';

import 'package:cartilhas_app/features/support/chatwoot_config.dart';
import 'package:cartilhas_app/features/support/chatwoot_config_repository.dart';
import 'package:cartilhas_app/features/support/chatwoot_mobile_host.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/screens/chatwoot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/testing.dart';
import 'auth_repository_test.dart' show MemoryTokenStore;

class ConfigSource implements ChatwootConfigRepository {
  int calls = 0;
  Future<ChatwootConfig> Function() response = () async => ChatwootConfig(
    baseUrl: 'https://chat.example.org',
    websiteToken: 'token_a',
  );
  @override
  Future<ChatwootConfig> fetch() {
    calls++;
    return response();
  }
}

class FakeHost implements ChatwootMobileHost {
  ChatwootConfig? config;
  void Function()? ready, opened, error;
  int identifications = 0;
  bool closed = false;
  bool acknowledgeOpen = true;
  String? name, phone;
  Completer<void>? closing;
  @override
  Future<void> load(
    ChatwootConfig value, {
    required void Function() onReady,
    required void Function() onOpened,
    required void Function() onError,
  }) async {
    config = value;
    ready = onReady;
    opened = onOpened;
    error = onError;
  }

  @override
  Future<void> identify({
    required String id,
    required String name,
    required String phone,
    String? identifierHash,
  }) async {
    identifications++;
    this.name = name;
    this.phone = phone;
    if (acknowledgeOpen) opened?.call();
  }

  @override
  Widget build() => const SizedBox(key: Key('fake-chatwoot-host'));
  @override
  Future<void> close() async {
    closed = true;
    await closing?.future;
  }
}

Future<void> start(
  WidgetTester tester,
  ConfigSource source,
  List<FakeHost> hosts, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatwootScreen(
        configurationRepository: source,
        mobileHostFactory: () {
          final h = FakeHost();
          hosts.add(h);
          return h;
        },
        widgetReadyTimeout: timeout,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> reload(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Recarregar'));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'support_contact_id_v1': 'anonymous-id',
      'user_name': 'Private Name',
      'user_phone': 'Private Phone',
      'privacy_consent_v1': false,
    }),
  );
  testWidgets(
    'reload fetches new config and creates a new host without rebuilding the app',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      await start(tester, source, hosts);
      expect(source.calls, 1);
      expect(hosts.single.config!.websiteToken, 'token_a');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      hosts.single.ready!();
      await tester.pump();
      expect(hosts.single.identifications, 1);
      expect(hosts.single.name, 'Aluno TDS');
      expect(hosts.single.phone, '');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      source.response = () async => ChatwootConfig(
        baseUrl: 'https://other.example.org',
        websiteToken: 'token_b',
      );
      await reload(tester);
      expect(source.calls, 2);
      expect(hosts.length, 2);
      expect(hosts.first.closed, isTrue);
      expect(hosts.last.config!.websiteToken, 'token_b');
      expect(hosts.last.config!.baseUrl, 'https://other.example.org');
      hosts.first.error!();
      hosts.first.ready!();
      await tester.pump();
      expect(hosts.first.identifications, 1);
      expect(find.text('Não foi possível conectar ao suporte.'), findsNothing);
      hosts.last.ready!();
      await tester.pump();
      expect(hosts.last.identifications, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'late config response cannot restore the old inbox after reload',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      final pending = Completer<ChatwootConfig>();
      source.response = () => pending.future;
      await start(tester, source, hosts);
      source.response = () async => ChatwootConfig(
        baseUrl: 'https://other.example.org',
        websiteToken: 'token_b',
      );
      await reload(tester);
      pending.complete(
        ChatwootConfig(
          baseUrl: 'https://chat.example.org',
          websiteToken: 'token_a',
        ),
      );
      await tester.pump();
      expect(hosts.length, 1);
      expect(hosts.single.config!.websiteToken, 'token_b');
      hosts.single.ready!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '503/config failure exposes retry and WhatsApp, then fetches fresh',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      source.response = () => Future.error(const ChatwootConfigUnavailable());
      await start(tester, source, hosts);
      expect(hosts, isEmpty);
      expect(
        find.text('Não foi possível conectar ao suporte.'),
        findsOneWidget,
      );
      expect(find.text('WhatsApp +55 63 9301-0823'), findsOneWidget);
      source.response = () async => ChatwootConfig(
        baseUrl: 'https://chat.example.org',
        websiteToken: 'token_b',
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump();
      expect(source.calls, 2);
      expect(hosts.single.config!.websiteToken, 'token_b');
      hosts.single.ready!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('HTML host loaded without ready times out and never identifies', (
    tester,
  ) async {
    final source = ConfigSource(), hosts = <FakeHost>[];
    await start(
      tester,
      source,
      hosts,
      timeout: const Duration(milliseconds: 50),
    );
    expect(hosts.length, 1);
    expect(hosts.single.identifications, 0);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Não foi possível conectar ao suporte.'), findsOneWidget);
    expect(hosts.single.closed, isTrue);
    hosts.single.ready!();
    await tester.pump();
    expect(hosts.single.identifications, 0);
  });
  testWidgets(
    'ready without real opened acknowledgement keeps loading then exposes retry',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      await start(
        tester,
        source,
        hosts,
        timeout: const Duration(milliseconds: 50),
      );
      hosts.single.acknowledgeOpen = false;
      hosts.single.ready!();
      await tester.pump();
      expect(hosts.single.identifications, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(hosts.single.closed, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('SDK load failure closes old context and retry creates another', (
    tester,
  ) async {
    final source = ConfigSource(), hosts = <FakeHost>[];
    await start(tester, source, hosts);
    hosts.single.error!();
    await tester.pump();
    expect(hosts.single.closed, isTrue);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump();
    expect(source.calls, 2);
    expect(hosts.length, 2);
    hosts.last.ready!();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'reload waits for previous SDK cookie reset before new host is loaded',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      await start(tester, source, hosts);
      hosts.single.ready!();
      await tester.pump();
      hosts.single.closing = Completer<void>();
      await reload(tester);
      expect(hosts.length, 1);
      expect(source.calls, 1);
      hosts.single.closing!.complete();
      await tester.pump();
      await tester.pump();
      expect(source.calls, 2);
      expect(hosts.length, 2);
      hosts.last.ready!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'logout during config fetch discards the old opening before SDK creation',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      final pending = Completer<ChatwootConfig>();
      source.response = () => pending.future;
      final auth = AuthRepository(
        apiUrl: 'https://api.example.org',
        tokenStore: MemoryTokenStore(),
        client: MockClient((_) => throw StateError('No auth request expected')),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        Provider<AuthRepository>.value(
          value: auth,
          child: MaterialApp(
            home: ChatwootScreen(
              configurationRepository: source,
              mobileHostFactory: () {
                final h = FakeHost();
                hosts.add(h);
                return h;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await auth.logout();
      pending.complete(
        ChatwootConfig(
          baseUrl: 'https://chat.example.org',
          websiteToken: 'token_a',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(hosts, isEmpty);
      expect(
        find.text('Não foi possível conectar ao suporte.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('logout before SDK ready never sends the previous profile', (
    tester,
  ) async {
    final source = ConfigSource(), hosts = <FakeHost>[];
    final auth = AuthRepository(
      apiUrl: 'https://api.example.org',
      tokenStore: MemoryTokenStore(),
      client: MockClient((_) => throw StateError('No auth request expected')),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      Provider<AuthRepository>.value(
        value: auth,
        child: MaterialApp(
          home: ChatwootScreen(
            configurationRepository: source,
            mobileHostFactory: () {
              final h = FakeHost();
              hosts.add(h);
              return h;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await auth.logout();
    hosts.single.ready!();
    await tester.pump();
    expect(hosts.single.identifications, 0);
    expect(hosts.single.closed, isTrue);
    expect(find.text('Não foi possível conectar ao suporte.'), findsOneWidget);
  });
  testWidgets(
    'logout after opened closes the host without requiring another SDK callback',
    (tester) async {
      final source = ConfigSource(), hosts = <FakeHost>[];
      final auth = AuthRepository(
        apiUrl: 'https://api.example.org',
        tokenStore: MemoryTokenStore(),
        client: MockClient((_) => throw StateError('No auth request expected')),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        Provider<AuthRepository>.value(
          value: auth,
          child: MaterialApp(
            home: ChatwootScreen(
              configurationRepository: source,
              mobileHostFactory: () {
                final h = FakeHost();
                hosts.add(h);
                return h;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      hosts.single.ready!();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await auth.logout();
      await tester.pump(const Duration(milliseconds: 250));
      expect(hosts.single.closed, isTrue);
      expect(
        find.text('Não foi possível conectar ao suporte.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
