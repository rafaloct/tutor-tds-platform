import 'package:flutter/foundation.dart';
import 'operations_gateway.dart';
import 'operations_models.dart';

class OperationsController extends ChangeNotifier {
  OperationsController(
    this.gateway, {
    required String sessionKey,
    required String Function() nextCommandId,
    // Keep public injection names while state remains private.
    // ignore: prefer_initializing_formals
  }) : _sessionKey = sessionKey,
       // ignore: prefer_initializing_formals
       _nextCommandId = nextCommandId;
  final OperationsGateway gateway;
  final String Function() _nextCommandId;
  String _sessionKey;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  List<OperationScope> scopes = const [];
  List<OperationPerson> people = const [];
  OperationScope? scope;
  OperationSnapshot? snapshot;
  OperationCommand? _pending;
  String? message;
  bool get isSimulation => gateway.isSimulation;
  bool get canRetry => _pending != null && !busy;
  bool get canNavigate => !busy && _pending == null;
  int get sessionGeneration => _generation;

  bool _current(int generation) => !_disposed && generation == _generation;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  /// Host must call on logout, account switch AND API/environment change.
  /// The old response cannot restore the new session's state.
  void replaceSession(String sessionKey) {
    _generation++;
    _sessionKey = sessionKey;
    busy = false;
    scopes = const [];
    people = const [];
    scope = null;
    snapshot = null;
    _pending = null;
    message = null;
    _emit();
  }

  Future<void> load() async {
    if (!canNavigate) return;
    await _read(() async {
      final result = await gateway.scopes(_sessionKey);
      return () {
        scopes = List.unmodifiable(result);
        scope = null;
        people = const [];
        snapshot = null;
      };
    });
  }

  void selectScope(OperationScope value) {
    if (!canNavigate || !scopes.contains(value)) return;
    scope = value;
    people = const [];
    snapshot = null;
    message = null;
    _emit();
  }

  void beginRegistration() {
    if (!canNavigate) return;
    snapshot = null;
    message = null;
    _emit();
  }

  Future<void> search(String query) async {
    final selected = scope;
    if (!canNavigate || selected == null) return;
    if (query.trim().length < 2) {
      message = 'Informe pelo menos dois caracteres para localizar a pessoa.';
      _emit();
      return;
    }
    snapshot = null;
    people = const [];
    await _read(() async {
      final result = await gateway.search(_sessionKey, selected, query.trim());
      return () {
        people = List.unmodifiable(result);
      };
    });
  }

  Future<void> selectPerson(OperationPerson person) async {
    final selected = scope;
    if (!canNavigate || selected == null || !people.contains(person)) return;
    snapshot = null;
    await _read(() async {
      final result = await gateway.inspect(_sessionKey, selected, person.id);
      _validate(result, selected, person.id);
      return () {
        snapshot = result;
      };
    });
  }

  Future<void> _read(Future<VoidCallback> Function() read) async {
    final generation = _generation;
    busy = true;
    message = null;
    _emit();
    try {
      final apply = await read();
      if (_current(generation)) apply();
    } catch (error) {
      if (_current(generation)) _failure(error, command: false);
    } finally {
      if (_current(generation)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> register(
    OperationRegistration registration,
    String reason,
  ) async {
    if (!canNavigate) return;
    beginRegistration();
    if (registration.name.trim().isEmpty ||
        registration.cpf.trim().isEmpty ||
        registration.phone.trim().isEmpty ||
        registration.password.isEmpty) {
      message =
          'Preencha os dados de cadastro. Use apenas dados sintéticos nesta demonstração.';
      _emit();
      return;
    }
    await _command(
      OperationAction.register,
      reason,
      registration: registration,
    );
  }

  Future<void> enroll(String reason) =>
      _command(OperationAction.enroll, reason);
  Future<void> assign(String reason) =>
      _command(OperationAction.assign, reason);
  Future<void> revoke(String reason) =>
      _command(OperationAction.revoke, reason);

  Future<void> _command(
    OperationAction action,
    String reason, {
    OperationRegistration? registration,
  }) async {
    final selected = scope;
    if (!canNavigate || selected == null) return;
    if (reason.trim().length < 3 || reason.trim().length > 500) {
      message =
          'Registre um motivo entre 3 e 500 caracteres, sem dados sensíveis.';
      _emit();
      return;
    }
    if (action != OperationAction.register && snapshot == null) return;
    if (action == OperationAction.register) snapshot = null;
    _pending = OperationCommand(
      id: _nextCommandId(),
      sessionKey: _sessionKey,
      scope: selected,
      action: action,
      reason: reason.trim(),
      personId: action == OperationAction.register ? null : snapshot!.person.id,
      expectedRevision: action == OperationAction.register
          ? null
          : snapshot!.revision,
      registration: registration,
    );
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  Future<void> _send() async {
    final command = _pending;
    if (busy || command == null) return;
    final generation = _generation;
    busy = true;
    message = null;
    _emit();
    try {
      final result = await gateway.execute(command);
      _validate(result, command.scope, command.personId);
      if (!_current(generation)) return;
      snapshot = result;
      _pending = null;
      final confirmation = result.enrolled && result.assigned
          ? 'Fluxo completo confirmado: matrícula e vínculo à turma estão ativos no contexto selecionado.'
          : switch (command.action) {
              OperationAction.register =>
                'Cadastro confirmado. Continue com a matrícula e o vínculo à turma.',
              OperationAction.enroll =>
                result.enrolled
                    ? 'Matrícula confirmada. Próxima etapa: vincular à turma.'
                    : 'Matrícula ainda não confirmada pelo serviço.',
              OperationAction.assign =>
                result.assigned
                    ? 'Vínculo à turma confirmado; a matrícula ainda não está confirmada.'
                    : 'Vínculo à turma ainda não confirmado pelo serviço.',
              OperationAction.revoke => 'Revogação do vínculo confirmada.',
            };
      message = isSimulation
          ? 'Simulação concluída. $confirmation Nenhuma conta ou matrícula real foi alterada.'
          : confirmation;
    } catch (error) {
      if (_current(generation)) _failure(error, command: true);
    } finally {
      if (_current(generation)) {
        busy = false;
        _emit();
      }
    }
  }

  void _validate(
    OperationSnapshot result,
    OperationScope selected,
    String? personId,
  ) {
    final other = result.scope;
    if (other.institutionId != selected.institutionId ||
        other.programId != selected.programId ||
        other.courseId != selected.courseId ||
        other.classId != selected.classId ||
        other.versionId != selected.versionId ||
        (personId != null && result.person.id != personId)) {
      throw const OperationFailure(OperationFailureKind.unavailable);
    }
  }

  void _failure(Object error, {required bool command}) {
    final kind = error is OperationFailure
        ? error.kind
        : OperationFailureKind.unavailable;
    switch (kind) {
      case OperationFailureKind.denied:
        _pending = null;
        snapshot = null;
        people = const [];
        scope = null;
        scopes = const [];
        message =
            'Acesso negado ou revogado. Recarregue os contextos autorizados.';
      case OperationFailureKind.conflict:
      case OperationFailureKind.invalid:
        _pending = null;
        snapshot = null;
        message =
            'Os dados precisam de conferência. Localize a pessoa novamente antes de continuar.';
      case OperationFailureKind.unavailable:
        message = command
            ? 'Resultado não confirmado. Retome a mesma operação; não faça outro cadastro.'
            : 'Serviço indisponível. Nenhuma alteração foi solicitada. Tente novamente.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pending = null;
    snapshot = null;
    people = const [];
    super.dispose();
  }
}
