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

  test(
    'contextual progress isolates cohorts and preserves ambiguous legacy',
    () async {
      const repository = StudyProgressRepository();
      StudyProgress progress(String? key, int index) => StudyProgress(
        courseId: 'course',
        courseVersionId: 'v1',
        ownerId: 'student',
        contextKey: key,
        sectionIndex: index,
        messageIndex: 0,
        questionsAnswered: 0,
        showOptions: false,
        isCompleted: false,
        updatedAt: DateTime.utc(2026),
      );
      await repository.save(progress(null, 9));
      await repository.save(progress('staging/class-a/enrollment', 1));
      await repository.save(progress('staging/class-b/enrollment', 2));
      Future<StudyProgress?> load(String? key) => repository.load(
        'course',
        courseVersionId: 'v1',
        ownerId: 'student',
        contextKey: key,
        allowLegacy: true,
      );
      expect((await load('staging/class-a/enrollment'))!.sectionIndex, 1);
      expect((await load('staging/class-b/enrollment'))!.sectionIndex, 2);
      expect(await load('production/class-a/enrollment'), isNull);
      expect((await load(null))!.sectionIndex, 9);
    },
  );

  test('mantém progresso legado e isola versões e contas', () async {
    const repository = StudyProgressRepository();
    StudyProgress progress({String? version, String? owner, int index = 3}) =>
        StudyProgress(
          courseId: 'course',
          courseVersionId: version,
          ownerId: owner,
          sectionIndex: index,
          messageIndex: 0,
          questionsAnswered: 0,
          showOptions: false,
          isCompleted: false,
          updatedAt: DateTime.utc(2026),
        );
    await repository.save(progress());
    expect(await repository.load('course', courseVersionId: 'v2'), isNull);
    expect(
      (await repository.load(
        'course',
        courseVersionId: 'v1',
        allowLegacy: true,
      ))?.sectionIndex,
      3,
    );
    expect(
      await repository.load(
        'course',
        courseVersionId: 'v1',
        ownerId: 'alice',
        allowLegacy: true,
      ),
      isNull,
    );
    await repository.save(progress(version: 'v1', owner: 'alice', index: 1));
    expect(
      (await repository.load(
        'course',
        courseVersionId: 'v1',
        ownerId: 'alice',
      ))?.sectionIndex,
      1,
    );
    expect(
      await repository.load('course', courseVersionId: 'v1', ownerId: 'bob'),
      isNull,
    );
    expect(
      await repository.load('course', courseVersionId: 'v2', ownerId: 'alice'),
      isNull,
    );
    expect((await repository.load('course'))?.sectionIndex, 3);
    expect((await repository.loadLast())?.ownerId, isNull);
  });
}
