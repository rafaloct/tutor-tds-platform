import 'package:cartilhas_app/features/study_progress/study_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva progresso por cartilha e como último acesso', () async {
    const repository = StudyProgressRepository();
    final progress = StudyProgress(
      courseId: 'curso-1',
      sectionIndex: 2,
      messageIndex: 3,
      questionsAnswered: 4,
      showOptions: false,
      isCompleted: false,
      updatedAt: DateTime.utc(2026, 9, 19, 12),
    );

    await repository.save(progress);

    final byCourse = await repository.load('curso-1');
    final last = await repository.loadLast();
    expect(byCourse?.sectionIndex, 2);
    expect(byCourse?.messageIndex, 3);
    expect(byCourse?.questionsAnswered, 4);
    expect(byCourse?.showOptions, isFalse);
    expect(last?.courseId, 'curso-1');
    expect(last?.updatedAt, DateTime.utc(2026, 9, 19, 12));
  });

  test('ignora progresso local corrompido', () async {
    SharedPreferences.setMockInitialValues({'study_progress:last': '{oops'});

    expect(await const StudyProgressRepository().loadLast(), isNull);
  });
}
