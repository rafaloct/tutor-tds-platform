import 'package:flutter/foundation.dart';
import '../../models/cartilha.dart';
import '../auth/data/auth_repository.dart';
import '../classrooms/data/classroom_repository.dart';
import '../classrooms/models/classroom_models.dart';
import 'home_selection_repository.dart';
import 'learning_context_controller.dart';
import 'learning_context_repository.dart';

enum LearningHomeState { loading, choose, empty, ready, error }

/// Resolves one complete learner journey. Widgets never choose a catalog edition.
class LearningHomeController extends ChangeNotifier {
  LearningHomeController({
    required this.gateway,
    required LearningContextRepository contexts,
    required this.selection,
  }) : contextController = LearningContextController(contexts);
  final LearnerClassroomGateway gateway;
  final HomeSelectionRepository selection;
  final LearningContextController contextController;
  LearningHomeState state = LearningHomeState.loading;
  List<ClassroomDetails> classes = const [];
  ClassroomDetails? classroom;
  Cartilha? course;
  String? ownerId;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load({String? selectedCohort}) async {
    final generation = ++_generation;
    bool stale() => _disposed || generation != _generation;
    state = LearningHomeState.loading;
    classroom = null;
    course = null;
    classes = const [];
    ownerId = null;
    notifyListeners();
    try {
      final user = await gateway.currentUser();
      final available = await gateway.learnerClassrooms();
      if (stale()) return;
      if ((await gateway.currentUser()).id != user.id) {
        throw const ClassroomException('A conta mudou.');
      }
      if (stale()) return;
      final saved = selectedCohort ?? await selection.read(user.id);
      if (stale()) return;
      ownerId = user.id;
      classes = List.unmodifiable(available);
      final matching = available.where((item) => item.id == saved).toList();
      if (selectedCohort != null && matching.isEmpty) {
        throw const ClassroomException(
          'A turma selecionada não está autorizada.',
        );
      }
      final target = matching.isNotEmpty
          ? matching.single
          : available.length == 1
          ? available.single
          : null;
      if (target == null) {
        state = available.isEmpty
            ? LearningHomeState.empty
            : LearningHomeState.choose;
        notifyListeners();
        return;
      }
      final resolved = await contextController.load(target.id);
      if (stale()) return;
      if (resolved == null ||
          resolved.context.userId != user.id ||
          resolved.context.cohortId != target.id ||
          resolved.context.courseId != target.courseId ||
          resolved.context.courseVersionId != target.courseVersionId ||
          !resolved.context.permissions.contains('content.read')) {
        throw const LearningContextException('Contexto inconsistente.');
      }
      final content = await gateway.course(target.id);
      if (stale()) return;
      if (!resolved.context.matchesCourse(content) ||
          (await gateway.currentUser()).id != user.id) {
        throw const ClassroomException('A conta ou a edição mudou.');
      }
      if (stale()) return;
      await selection.write(user.id, target.id);
      if (stale()) return;
      classroom = target;
      course = content;
      state = LearningHomeState.ready;
      notifyListeners();
    } catch (error) {
      if (stale()) return;
      if (error is! ClassroomException &&
          error is! LearningContextException &&
          error is! AuthException &&
          error is! HomeSelectionException) {
        rethrow;
      }
      state = LearningHomeState.error;
      classroom = null;
      course = null;
      notifyListeners();
    }
  }

  void chooseAnother() {
    if (_disposed || state == LearningHomeState.loading) return;
    _generation++;
    classroom = null;
    course = null;
    state = classes.isEmpty
        ? LearningHomeState.empty
        : LearningHomeState.choose;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    contextController.dispose();
    super.dispose();
  }
}
