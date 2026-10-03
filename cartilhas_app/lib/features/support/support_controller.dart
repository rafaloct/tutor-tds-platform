import 'package:flutter/foundation.dart';

import 'support_gateway.dart';
import 'support_models.dart';

class SupportController extends ChangeNotifier {
  SupportController(this.gateway);

  final SupportGateway gateway;

  SupportViewState state = SupportViewState.loading;
  SupportSession? session;
  SupportTopic? topic;
  SupportContextOption? selectedContext;
  String message = '';
  String? statusMessage;
  String? confirmedCommandId;

  int _generation = 0;
  int _commandSequence = 0;
  SupportCommand? _retryCommand;
  bool _disposed = false;

  bool get isSending => state == SupportViewState.sending;
  bool get hasDraft => topic != null || message.trim().isNotEmpty;

  bool get canSend {
    final currentTopic = topic;
    if (session == null || currentTopic == null || isSending) return false;
    if (currentTopic.requiresContext && selectedContext == null) return false;
    if (currentTopic != SupportTopic.unsure && message.trim().isEmpty) {
      return false;
    }
    return state != SupportViewState.loading &&
        state != SupportViewState.unavailable;
  }

  Future<void> startSession(SupportSession next) async {
    final generation = ++_generation;
    session = next;
    topic = null;
    message = '';
    statusMessage = null;
    confirmedCommandId = null;
    _retryCommand = null;
    selectedContext = _preselectedContext(next);
    state = SupportViewState.loading;
    notifyListeners();

    try {
      await gateway.prepare(next);
      if (_isStale(generation, next)) return;
      state = SupportViewState.ready;
      notifyListeners();
    } on SupportUnavailableException {
      if (_isStale(generation, next)) return;
      state = SupportViewState.unavailable;
      statusMessage =
          'Não enviado. A demonstração local está indisponível nesta sessão.';
      notifyListeners();
    }
  }

  SupportContextOption? _preselectedContext(SupportSession target) {
    final id = target.preselectedContextId;
    if (id == null || id.isEmpty) return null;
    for (final context in target.contexts) {
      if (context.id == id) return context;
    }
    return null;
  }

  void selectTopic(SupportTopic next) {
    if (_disposed || isSending || session == null) return;
    topic = next;
    _retryCommand = null;
    confirmedCommandId = null;
    statusMessage = null;
    state = SupportViewState.draft;
    notifyListeners();
  }

  void chooseContext(String? contextId) {
    if (_disposed || isSending || session == null) return;
    SupportContextOption? next;
    if (contextId != null) {
      for (final context in session!.contexts) {
        if (context.id == contextId) {
          next = context;
          break;
        }
      }
    }
    selectedContext = next;
    _retryCommand = null;
    confirmedCommandId = null;
    statusMessage = null;
    state = hasDraft ? SupportViewState.draft : SupportViewState.ready;
    notifyListeners();
  }

  void clearContext() => chooseContext(null);

  void updateMessage(String value) {
    if (_disposed || isSending || session == null) return;
    message = value;
    _retryCommand = null;
    confirmedCommandId = null;
    statusMessage = null;
    state = hasDraft ? SupportViewState.draft : SupportViewState.ready;
    notifyListeners();
  }

  Future<void> send() async {
    if (!canSend) return;
    final currentSession = session!;
    final command = _retryCommand ?? _buildCommand(currentSession);
    final generation = _generation;

    state = SupportViewState.sending;
    statusMessage = 'DEMONSTRAÇÃO: simulando envio local.';
    confirmedCommandId = null;
    notifyListeners();

    try {
      final receipt = await gateway.send(command);
      if (_isStale(generation, currentSession)) return;
      _retryCommand = null;
      confirmedCommandId = receipt.commandId;
      state = SupportViewState.simulatedConfirmation;
      statusMessage =
          'DEMONSTRAÇÃO: confirmação simulada. Nenhuma equipe recebeu esta mensagem.';
      notifyListeners();
    } on SupportUnavailableException {
      if (_isStale(generation, currentSession)) return;
      _retryCommand = command;
      state = SupportViewState.unavailable;
      statusMessage =
          'Não enviado. O rascunho desta sessão continua apenas na memória.';
      notifyListeners();
    } on SupportSendException {
      if (_isStale(generation, currentSession)) return;
      _retryCommand = command;
      state = SupportViewState.error;
      statusMessage =
          'Não enviado. A falha simulada permite uma nova tentativa explícita.';
      notifyListeners();
    }
  }

  Future<void> retry() async {
    if (_retryCommand == null || isSending || session == null) return;
    if (state == SupportViewState.unavailable) {
      state = SupportViewState.draft;
    }
    await send();
  }

  SupportCommand _buildCommand(SupportSession currentSession) {
    final id = '${currentSession.sessionId}-support-${++_commandSequence}';
    return SupportCommand(
      commandId: id,
      sessionId: currentSession.sessionId,
      ownerId: currentSession.ownerId,
      topic: topic!,
      contextId: selectedContext?.id,
      message: message.trim(),
    );
  }

  void endSession() {
    if (_disposed) return;
    _generation++;
    session = null;
    topic = null;
    selectedContext = null;
    message = '';
    statusMessage = 'Sessão encerrada. Nenhum rascunho foi preservado.';
    confirmedCommandId = null;
    _retryCommand = null;
    state = SupportViewState.unavailable;
    notifyListeners();
  }

  bool _isStale(int generation, SupportSession expected) =>
      _disposed ||
      generation != _generation ||
      session?.sessionId != expected.sessionId ||
      session?.ownerId != expected.ownerId;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
