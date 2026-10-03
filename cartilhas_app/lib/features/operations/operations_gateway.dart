import 'operations_models.dart';

/// No HTTP adapter is shipped by this slice. The gateway must authorize each
/// read/command again on the server; scopes are display options, not grants.
abstract interface class OperationsGateway {
  bool get isSimulation;
  Future<List<OperationScope>> scopes(String sessionKey);
  Future<List<OperationPerson>> search(
    String sessionKey,
    OperationScope scope,
    String query,
  );
  Future<OperationSnapshot> inspect(
    String sessionKey,
    OperationScope scope,
    String personId,
  );

  /// Repeating the exact command ID/body must reconcile the same result, even
  /// after response loss. A different body with that ID must fail explicitly.
  Future<OperationSnapshot> execute(OperationCommand command);
}
