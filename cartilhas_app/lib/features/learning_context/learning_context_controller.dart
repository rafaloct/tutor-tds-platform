import 'package:flutter/foundation.dart';
import 'learning_context.dart';
import 'learning_context_repository.dart';

enum LearningContextState { idle, loading, ready, offline, error }

class LearningContextController extends ChangeNotifier {
  LearningContextController(this.repository);
  final LearningContextRepository repository;
  LearningContextState state = LearningContextState.idle;
  LearningContextSnapshot? snapshot;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<LearningContextSnapshot?> load(String cohortId) async {
    final generation = ++_generation;
    snapshot = null;
    error = null;
    state = LearningContextState.loading;
    notifyListeners();
    try {
      final value = await repository.resolve(cohortId);
      if (_disposed || generation != _generation) return null;
      snapshot = value;
      state = value.fromCache
          ? LearningContextState.offline
          : LearningContextState.ready;
      notifyListeners();
      return value;
    } catch (_) {
      if (_disposed || generation != _generation) return null;
      state = LearningContextState.error;
      error =
          'Não foi possível confirmar a matrícula e a edição desta turma. Atualize seu acesso e tente novamente.';
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
