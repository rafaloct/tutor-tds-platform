import 'package:flutter/foundation.dart';

enum StudyLoadStatus { idle, loading, ready, failure }

@immutable
class StudyLoadState<T> {
  const StudyLoadState({
    this.status = StudyLoadStatus.idle,
    this.data,
    this.error,
  });

  final StudyLoadStatus status;
  final T? data;
  final String? error;
}

class StudyMaterialController<T> extends ChangeNotifier {
  StudyLoadState<T> _state = const StudyLoadState();

  StudyLoadState<T> get state => _state;

  Future<void> generate(Future<T> Function() loader) async {
    _state = const StudyLoadState(status: StudyLoadStatus.loading);
    notifyListeners();
    try {
      final data = await loader();
      _state = StudyLoadState(status: StudyLoadStatus.ready, data: data);
    } on Object catch (error) {
      _state = StudyLoadState(
        status: StudyLoadStatus.failure,
        error: error.toString(),
      );
    }
    notifyListeners();
  }
}
