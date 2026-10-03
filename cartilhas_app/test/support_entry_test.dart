import 'package:cartilhas_app/features/support/support_controller.dart';
import 'package:cartilhas_app/features/support/support_demo_screen.dart';
import 'package:cartilhas_app/features/support/support_gateway.dart';
import 'package:cartilhas_app/features/support/support_models.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const demoContexts = [
  SupportContextOption(
    id: 'cohort-a',
    cohortLabel: 'Turma A',
    courseLabel: 'Curso TDS',
  ),
  SupportContextOption(
    id: 'cohort-b',
    cohortLabel: 'Turma B',
    courseLabel: 'Curso TDS',
  ),
];

const demoSession = SupportSession(
  sessionId: 'session-a',
  ownerId: 'owner-a',
  displayLabel: 'Participante A',
  contexts: demoContexts,
);

const visitorSession = SupportSession(
  sessionId: 'visitor-session',
  ownerId: 'visitor-owner',
  displayLabel: 'Visitante',
  isVisitor: true,
  optionalConsentGranted: false,
);

Future<SupportController> pumpSupport(
  WidgetTester tester, {
  FakeSupportGateway? gateway,
  SupportSession session = demoSession,
  MediaQueryData? media,
}) async {
  final fake = gateway ?? FakeSupportGateway();
  final controller = SupportController(fake);
  final screen = SupportDemoScreen(controller: controller, session: session);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: media == null ? screen : MediaQuery(data: media, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> chooseTopic(WidgetTester tester, SupportTopic topic) async {
  await tester.tap(find.byKey(Key('support-topic-${topic.name}')));
  await tester.pump();
}

Future<void> enterMessage(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('support-message')), value);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  testWidgets('visitar, escolher assunto e ler ajuda não envia', (
    tester,
  ) async {
    final gateway = FakeSupportGateway();
    await pumpSupport(tester, gateway: gateway);

    expect(find.text('Central TDS'), findsOneWidget);
    expect(find.byKey(const Key('support-demo-banner')), findsOneWidget);
    expect(gateway.commands, isEmpty);

    await chooseTopic(tester, SupportTopic.appHelp);

    expect(find.byKey(const Key('support-topic-help')), findsOneWidget);
    expect(gateway.commands, isEmpty);
  });

  testWidgets('visitante recebe ajuda básica sem identidade acadêmica', (
    tester,
  ) async {
    final gateway = FakeSupportGateway();
    await pumpSupport(tester, gateway: gateway, session: visitorSession);

    expect(find.text('Ajuda de acesso para visitante'), findsOneWidget);
    expect(
      find.textContaining('sem CPF ou identidade acadêmica'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);

    await chooseTopic(tester, SupportTopic.appHelp);
    await enterMessage(tester, 'Não consigo abrir o conteúdo.');
    await tapVisible(tester, find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();

    expect(gateway.commands, hasLength(1));
    expect(
      find.textContaining('Nenhuma equipe recebeu esta mensagem'),
      findsOneWidget,
    );
  });

  testWidgets('duas turmas exigem escolha explícita para assunto contextual', (
    tester,
  ) async {
    final controller = await pumpSupport(tester);

    await chooseTopic(tester, SupportTopic.courseQuestion);
    await enterMessage(tester, 'Tenho uma dúvida sobre a atividade.');

    expect(controller.selectedContext, isNull);
    expect(find.byKey(const Key('support-context-required')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('support-send')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('contexto pode ser escolhido e removido', (tester) async {
    final controller = await pumpSupport(tester);

    await chooseTopic(tester, SupportTopic.courseQuestion);
    await tester.tap(
      find.byKey(const ValueKey('support-context-dropdown-none')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma B • Curso TDS').last);
    await tester.pumpAndSettle();

    expect(controller.selectedContext?.id, 'cohort-b');
    expect(find.byKey(const Key('support-clear-context')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('support-clear-context')));
    await tester.pump();

    expect(controller.selectedContext, isNull);
    expect(find.byKey(const Key('support-context-required')), findsOneWidget);
  });

  testWidgets('toque duplo dispara somente um comando', (tester) async {
    final gateway = FakeSupportGateway(holdResponses: true);
    await pumpSupport(tester, gateway: gateway);
    await chooseTopic(tester, SupportTopic.appHelp);
    await enterMessage(tester, 'O botão não responde.');

    final send = find.byKey(const Key('support-send'));
    await tester.ensureVisible(send);
    await tester.pump();
    await tester.tap(send);
    await tester.tap(send);
    await tester.pump();

    expect(gateway.commands, hasLength(1));

    gateway.succeedPending();
    await tester.pumpAndSettle();

    expect(gateway.commands, hasLength(1));
    expect(find.textContaining('confirmação simulada'), findsOneWidget);
  });

  testWidgets('offline preserva rascunho e informa Não enviado', (
    tester,
  ) async {
    final gateway = FakeSupportGateway();
    final controller = await pumpSupport(tester, gateway: gateway);
    await chooseTopic(tester, SupportTopic.appHelp);
    await enterMessage(tester, 'Meu rascunho deve permanecer.');

    gateway.mode = FakeSupportMode.offline;
    await tapVisible(tester, find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();

    expect(controller.message, 'Meu rascunho deve permanecer.');
    expect(find.textContaining('Não enviado'), findsOneWidget);
    expect(find.textContaining('Recebido'), findsNothing);
    expect(find.byKey(const Key('support-retry')), findsOneWidget);
  });

  testWidgets('falha permite retry explícito sem confirmação duplicada', (
    tester,
  ) async {
    final gateway = FakeSupportGateway(mode: FakeSupportMode.failOnce);
    final controller = await pumpSupport(tester, gateway: gateway);
    await chooseTopic(tester, SupportTopic.appHelp);
    await enterMessage(tester, 'Teste de falha.');

    await tapVisible(tester, find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();

    expect(controller.state, SupportViewState.error);
    expect(controller.confirmedCommandId, isNull);
    expect(gateway.commands, hasLength(1));

    await tapVisible(tester, find.byKey(const Key('support-retry')));
    await tester.pumpAndSettle();

    expect(gateway.commands, hasLength(2));
    expect(gateway.commands.first.commandId, gateway.commands.last.commandId);
    expect(controller.state, SupportViewState.simulatedConfirmation);
    expect(find.textContaining('confirmação simulada'), findsOneWidget);
  });

  testWidgets('consentimento opcional negado não bloqueia ajuda', (
    tester,
  ) async {
    final gateway = FakeSupportGateway();
    await pumpSupport(
      tester,
      gateway: gateway,
      session: const SupportSession(
        sessionId: 'no-consent',
        ownerId: 'fictional-owner',
        displayLabel: 'Pessoa fictícia',
        optionalConsentGranted: false,
      ),
    );

    expect(
      find.textContaining('Consentimento opcional negado'),
      findsOneWidget,
    );

    await chooseTopic(tester, SupportTopic.appHelp);
    await enterMessage(tester, 'Ajuda básica.');
    await tapVisible(tester, find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();

    expect(gateway.commands, hasLength(1));
    expect(gateway.commands.single.ownerId, 'fictional-owner');
    expect(gateway.commands.single.contextId, isNull);
  });

  testWidgets('botão voltar retorna à atividade anterior', (tester) async {
    final controller = SupportController(FakeSupportGateway());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SupportDemoScreen(
                      controller: controller,
                      session: demoSession,
                    ),
                  ),
                );
              },
              child: const Text('Abrir Central TDS'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Central TDS'));
    await tester.pumpAndSettle();

    expect(find.text('Central TDS'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Abrir Central TDS'), findsOneWidget);
    expect(find.text('Central TDS'), findsNothing);
  });

  testWidgets('tela estreita e texto 2.0 permanecem roláveis', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpSupport(
      tester,
      media: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(find.byKey(const Key('support-scroll')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('support-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('controles principais expõem semântica e foco de teclado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSupport(tester);

    expect(
      find.bySemanticsLabel('Simular envio da demonstração'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'DEMONSTRAÇÃO. Central local simulada, sem conexão com Chatwoot ou equipe.',
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    handle.dispose();
  });
}
