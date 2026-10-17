// Real read-only public curriculum smoke, never emits quiz keys or user data.
import 'dart:io';
import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';

Future<void> main() async {
  const courses = <int, String>{
    614: 'inteligencia-artificial-e-inclusao-digital',
    1298: 'agricultura-sustentavel',
    1307: 'atendimento-cliente',
    1314: 'audiovisual',
    1321: 'cooperativismo',
    1328: 'economia-lar',
    1335: 'educacao-financeira',
    1343: 'sim-sima',
    1356: 'saf',
  };
  final repository = EadCurriculumRepository();
  var lessonCount = 0;
  var videoCount = 0;
  for (final entry in courses.entries) {
    final course = EadCourse(
      id: entry.key,
      slug: entry.value,
      title: entry.value,
    );
    final result = await repository.fetch(course);
    lessonCount += result.lessonCount;
    videoCount += result.videoCount;
    stdout.writeln(
      '${entry.key} ${entry.value} sections=${result.sections.length} '
      'lessons=${result.lessonCount} videos=${result.videoCount}',
    );
  }
  stdout.writeln(
    'COURSES=${courses.length} LESSONS=$lessonCount VIDEOS=$videoCount',
  );
  if (courses.length == 9 && lessonCount == 95 && videoCount == 48) {
    stdout.writeln('EAD_CURRICULUM_LIVE_SMOKE=PASS');
  } else {
    stderr.writeln('BLOCKED: curriculum drift; review editorial mapping.');
    exitCode = 2;
  }
}
