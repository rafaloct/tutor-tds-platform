import 'dart:async';

import 'support_models.dart';

abstract class SupportGateway {
  Future<void> prepare(SupportSession session);
  Future<SupportReceipt> send(SupportCommand command);
}

enum FakeSupportMode { ready, offline, failOnce }

class FakeSupportGateway implements SupportGateway {
  FakeSupportGateway({
    this.mode = FakeSupportMode.ready,
    this.holdResponses = false,
  });

  FakeSupportMode mode;
  bool holdResponses;
  bool _failedOnce = false;
  final List<SupportCommand> commands = <SupportCommand>[];
  Completer<SupportReceipt>? _pending;

  @override
  Future<void> prepare(SupportSession session) async {
    if (mode == FakeSupportMode.offline) {
      throw const SupportUnavailableException();
    }
  }

  @override
  Future<SupportReceipt> send(SupportCommand command) {
    commands.add(command);
    if (mode == FakeSupportMode.offline) {
      return Future<SupportReceipt>.error(const SupportUnavailableException());
    }
    if (mode == FakeSupportMode.failOnce && !_failedOnce) {
      _failedOnce = true;
      return Future<SupportReceipt>.error(const SupportSendException());
    }
    if (holdResponses) {
      if (_pending != null && !_pending!.isCompleted) {
        return Future<SupportReceipt>.error(const SupportSendException());
      }
      _pending = Completer<SupportReceipt>();
      return _pending!.future;
    }
    return Future<SupportReceipt>.value(
      SupportReceipt(commandId: command.commandId),
    );
  }

  bool get hasPendingResponse => _pending != null && !_pending!.isCompleted;

  void succeedPending() {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    final command = commands.last;
    pending.complete(SupportReceipt(commandId: command.commandId));
    _pending = null;
  }

  void failPending() {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    pending.completeError(const SupportSendException());
    _pending = null;
  }
}
