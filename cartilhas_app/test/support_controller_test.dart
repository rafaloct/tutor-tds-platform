import 'package:cartilhas_app/features/support/support_controller.dart';
import 'package:cartilhas_app/features/support/support_gateway.dart';
import 'package:cartilhas_app/features/support/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

const contexts = [
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

SupportSession session(String owner, {String? sessionId, String? preselected}) {
  return SupportSession(
    sessionId: sessionId ?? 'session-$owner',
    ownerId: owner,
    displayLabel: owner,
    contexts: contexts,
    preselectedContextId: preselected,
  );
}

void prepareDraft(SupportController controller) {
  controller.selectTopic(SupportTopic.appHelp);
  controller.updateMessage('Preciso de ajuda para acessar a atividade.');
}

void main() {
  test('duas turmas não selecionam a primeira silenciosamente', () async {
    final controller = SupportController(FakeSupportGateway());

    await controller.startSession(session('A'));

    expect(controller.state, SupportViewState.ready);
    expect(controller.selectedContext, isNull);

    controller.selectTopic(SupportTopic.courseQuestion);
    controller.updateMessage('Onde encontro o material?');

    expect(controller.canSend, isFalse);
    controller.chooseContext('cohort-b');
    expect(controller.selectedContext?.id, 'cohort-b');
    expect(controller.canSend, isTrue);
  });

  test('pré-seleção só vale quando o contexto explícito existe', () async {
    final controller = SupportController(FakeSupportGateway());

    await controller.startSession(session('A', preselected: 'cohort-b'));
    expect(controller.selectedContext?.id, 'cohort-b');

    await controller.startSession(
      session('A', sessionId: 'session-A-2', preselected: 'desconhecido'),
    );
    expect(controller.selectedContext, isNull);
  });

  test('toque duplo produz um comando enquanto envio está pendente', () async {
    final gateway = FakeSupportGateway(holdResponses: true);
    final controller = SupportController(gateway);
    await controller.startSession(session('A'));
    prepareDraft(controller);

    final first = controller.send();
    final second = controller.send();

    expect(gateway.commands, hasLength(1));
    expect(controller.state, SupportViewState.sending);

    gateway.succeedPending();
    await Future.wait([first, second]);

    expect(gateway.commands, hasLength(1));
    expect(controller.state, SupportViewState.simulatedConfirmation);
    expect(controller.statusMessage, contains('DEMONSTRAÇÃO'));
  });

  test('falha exige retry explícito e reutiliza o mesmo comando', () async {
    final gateway = FakeSupportGateway(mode: FakeSupportMode.failOnce);
    final controller = SupportController(gateway);
    await controller.startSession(session('A'));
    prepareDraft(controller);

    await controller.send();

    expect(controller.state, SupportViewState.error);
    expect(controller.confirmedCommandId, isNull);
    expect(gateway.commands, hasLength(1));
    final failedId = gateway.commands.single.commandId;

    await controller.retry();

    expect(gateway.commands, hasLength(2));
    expect(gateway.commands.last.commandId, failedId);
    expect(controller.confirmedCommandId, failedId);
    expect(controller.state, SupportViewState.simulatedConfirmation);
  });

  test('troca A para B invalida resposta tardia de A', () async {
    final gateway = FakeSupportGateway(holdResponses: true);
    final controller = SupportController(gateway);
    await controller.startSession(session('A'));
    prepareDraft(controller);

    final pendingA = controller.send();
    expect(gateway.hasPendingResponse, isTrue);

    await controller.startSession(session('B'));

    expect(controller.session?.ownerId, 'B');
    expect(controller.message, isEmpty);
    expect(controller.confirmedCommandId, isNull);

    gateway.succeedPending();
    await pendingA;

    expect(controller.session?.ownerId, 'B');
    expect(controller.state, SupportViewState.ready);
    expect(controller.confirmedCommandId, isNull);
    expect(controller.statusMessage, isNull);
  });

  test('logout e retorno posterior não restauram rascunho anterior', () async {
    final controller = SupportController(FakeSupportGateway());
    await controller.startSession(session('A'));
    prepareDraft(controller);

    expect(controller.message, isNotEmpty);

    controller.endSession();
    expect(controller.message, isEmpty);
    expect(controller.session, isNull);

    await controller.startSession(session('A', sessionId: 'session-A-return'));

    expect(controller.state, SupportViewState.ready);
    expect(controller.message, isEmpty);
    expect(controller.topic, isNull);
    expect(controller.confirmedCommandId, isNull);
  });
}
