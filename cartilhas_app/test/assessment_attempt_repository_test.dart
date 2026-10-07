import 'package:cartilhas_app/features/study_ai/data/assessment_attempt_repository.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final sampleDeck = AssessmentDeck(
    title: 'Quiz de Cooperativismo',
    durationMinutes: 15,
    items: [
      StudyQuestion(
        question: 'O que é intercooperação?',
        options: [
          'Ajuda mútua entre cooperativas',
          'Competição',
          'Lucro individual',
          'Nenhuma',
        ],
        correctIndex: 0,
        explanation: 'Intercooperação é um dos princípios fundamentais.',
        topic: 'Princípios do cooperativismo',
      ),
      StudyQuestion(
        question: 'Qual a assembleia soberana?',
        options: [
          'Diretoria',
          'Assembleia Geral',
          'Conselho Fiscal',
          'Auditoria',
        ],
        correctIndex: 1,
        explanation: 'A Assembleia Geral é soberana nas decisões.',
        topic: 'Governança cooperativa',
      ),
    ],
  );

  test('salva e recupera tentativa de quiz e simulado isoladamente', () async {
    const repository = AssessmentAttemptRepository();
    final quizAttempt = AssessmentAttempt(
      id: 'attempt-quiz-1',
      courseId: 'cooperativismo',
      topic: 'Cooperativismo',
      mode: AssessmentMode.quiz,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: 2,
      deck: sampleDeck,
      answers: {0: 0},
      currentIndex: 1,
      remainingSeconds: 0,
      score: 1,
      weakTopics: const [],
      isCompleted: false,
      createdAt: DateTime.utc(2026, 9, 19, 11, 0),
      updatedAt: DateTime.utc(2026, 9, 19, 11, 5),
    );

    final examAttempt = AssessmentAttempt(
      id: 'attempt-exam-1',
      courseId: 'cooperativismo',
      topic: 'Cooperativismo',
      mode: AssessmentMode.exam,
      difficulty: StudyDifficulty.advanced,
      totalQuestions: 2,
      deck: sampleDeck,
      answers: {0: 0, 1: 1},
      currentIndex: 1,
      remainingSeconds: 420,
      score: 2,
      weakTopics: const [],
      isCompleted: true,
      createdAt: DateTime.utc(2026, 9, 19, 12, 0),
      updatedAt: DateTime.utc(2026, 9, 19, 12, 10),
    );

    await repository.save(quizAttempt);
    await repository.save(examAttempt);

    final loadedQuiz = await repository.load(
      'cooperativismo',
      AssessmentMode.quiz,
    );
    final loadedExam = await repository.load(
      'cooperativismo',
      AssessmentMode.exam,
    );
    final last = await repository.loadLast();

    expect(loadedQuiz, isNotNull);
    expect(loadedQuiz?.id, 'attempt-quiz-1');
    expect(loadedQuiz?.assessmentContentId, 'content:attempt-quiz-1');
    expect(loadedQuiz?.isCompleted, isFalse);
    expect(loadedQuiz?.answers[0], 0);

    expect(loadedExam, isNotNull);
    expect(loadedExam?.id, 'attempt-exam-1');
    expect(loadedExam?.isCompleted, isTrue);
    expect(loadedExam?.score, 2);

    expect(last, isNotNull);
    expect(last?.id, 'attempt-exam-1');
  });

  test('ignora tentativa local corrompida com retorno null', () async {
    SharedPreferences.setMockInitialValues({
      'study_assessment:course:agro:quiz': '{invalido}',
      'study_assessment:last': '{"courseId": "agro"}',
    });

    const repository = AssessmentAttemptRepository();
    expect(await repository.load('agro', AssessmentMode.quiz), isNull);
    expect(await repository.loadLast(), isNull);
  });

  test('serializa e deserializa AssessmentAttempt mantendo integridade', () {
    final attempt = AssessmentAttempt(
      id: 'attempt-123',
      courseId: 'horta',
      topic: 'Horta Comunitária',
      mode: AssessmentMode.exam,
      difficulty: StudyDifficulty.basic,
      totalQuestions: 2,
      deck: sampleDeck,
      answers: {0: 2},
      reviewQuestionIndexes: {1},
      currentIndex: 1,
      remainingSeconds: 300,
      score: 0,
      weakTopics: ['Princípios do cooperativismo'],
      isCompleted: false,
      createdAt: DateTime.utc(2026, 9, 19, 8),
      updatedAt: DateTime.utc(2026, 9, 19, 8, 15),
    );

    final jsonMap = attempt.toJson();
    final parsed = AssessmentAttempt.tryParse(
      '{"id": "${jsonMap['id']}", "courseId": "${jsonMap['courseId']}", "topic": "${jsonMap['topic']}", "mode": "${jsonMap['mode']}", "difficulty": "${jsonMap['difficulty']}", "totalQuestions": ${jsonMap['totalQuestions']}, "deck": {"title": "Quiz", "durationMinutes": 10, "items": []}, "answers": {"0": 2}, "reviewQuestionIndexes": [1], "currentIndex": 1, "remainingSeconds": 300, "score": 0, "weakTopics": ["Princípios do cooperativismo"], "isCompleted": false, "createdAt": "${jsonMap['createdAt']}", "updatedAt": "${jsonMap['updatedAt']}"}',
    );

    expect(parsed, isNotNull);
    expect(parsed?.id, 'attempt-123');
    expect(parsed?.assessmentContentId, 'content:attempt-123');
    expect(parsed?.answers[0], 2);
    expect(parsed?.reviewQuestionIndexes, {1});
    expect(parsed?.weakTopics, ['Princípios do cooperativismo']);
    expect(parsed?.remainingSeconds, 300);
  });

  test('isola bloco publicado por owner, API, turma e edição', () async {
    const repository = AssessmentAttemptRepository();
    final first = _publishedContext();
    final otherOwner = _publishedContext(owner: 'student-2');
    final otherApi = _publishedContext(api: 'https://other.example');
    final otherClass = _publishedContext(classId: 'class-2');
    final otherVersion = _publishedContext(courseVersion: 'version-2');
    final attempt = _publishedAttempt(first);

    await repository.saveConfirmed(attempt);

    expect((await repository.loadPublished(first))?.id, attempt.id);
    expect(await repository.loadPublished(otherOwner), isNull);
    expect(await repository.loadPublished(otherApi), isNull);
    expect(await repository.loadPublished(otherClass), isNull);
    expect(await repository.loadPublished(otherVersion), isNull);
    expect(await repository.loadLast(), isNull);
  });
}

PublishedAssessmentContext _publishedContext({
  String owner = 'student-1',
  String api = 'https://api.example/',
  String classId = 'class-1',
  String courseVersion = 'version-1',
}) => PublishedAssessmentContext(
  ownerId: owner,
  apiUrl: api,
  lineage: PublishedAssessmentLineage(
    organizationId: 'org-1',
    programId: 'program-1',
    classId: classId,
    membershipId: 'membership-$classId',
    enrollmentId: 'context-enrollment-$classId',
    legacyEnrollmentId: 'legacy-enrollment-1',
    courseId: 'course-1',
    courseVersionId: courseVersion,
    sectionId: 'section-1',
    sectionVersionId: 'section-version-1',
    blockId: 'block-1',
    blockVersionId: 'block-version-1',
  ),
);

AssessmentAttempt _publishedAttempt(PublishedAssessmentContext context) =>
    AssessmentAttempt(
      id: 'attempt:published:stable',
      origin: AssessmentOrigin.publishedBlock,
      publishedContext: context,
      courseId: 'course-1',
      topic: 'Módulo',
      mode: AssessmentMode.quiz,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: 1,
      deck: AssessmentDeck(
        title: 'Bloco',
        durationMinutes: 0,
        items: [
          StudyQuestion(
            question: 'Pergunta?',
            options: const ['A', 'B'],
            correctIndex: -1,
            correctIndexes: const {},
            graded: false,
            explanation: '',
            topic: 'Módulo',
          ),
        ],
      ),
      answers: const {0: 1},
      currentIndex: 0,
      remainingSeconds: 0,
      score: 0,
      weakTopics: const [],
      isCompleted: false,
      createdAt: DateTime.utc(2026, 10, 7),
      updatedAt: DateTime.utc(2026, 10, 7),
    );
