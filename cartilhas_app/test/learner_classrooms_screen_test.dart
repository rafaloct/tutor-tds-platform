import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/learner_classrooms_screen.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClasses implements LearnerClassroomGateway {
  bool fails = false;
  @override
  Future<AuthUser> currentUser() async =>
      const AuthUser(id: 'student', name: 'Aluno', role: 'student');
  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async => [
    ClassroomDetails(
      id: 'class-1',
      programId: 'program',
      courseId: 'course',
      teacherId: 'teacher',
      name: 'Minha turma',
      startDate: DateTime(2026),
      endDate: DateTime(2027),
      status: 'active',
      studentIds: const [],
      monitorIds: const [],
    ),
  ];
  @override
  Future<Cartilha> course(String classId) async {
    if (fails) throw const ClassroomException('Falha');
    return Cartilha(
      id: 'course',
      title: 'Edição antiga',
      author: 'TDS',
      sections: [
        Section(
          id: 's1',
          title: 'Módulo',
          messages: [Message(type: 'bot', content: 'Conteúdo')],
        ),
      ],
      courseVersionId: 'version-1',
      classId: classId,
      legacyProgressCompatible: false,
    );
  }
}

void main() {
  test('contagem de aprendizagem inclui quiz e não conta falas do usuário', () {
    expect(Message(type: 'quiz', content: 'Quiz').isAssessmentQuestion, isTrue);
    expect(
      Message(type: 'question', content: 'Questão').isAssessmentQuestion,
      isTrue,
    );
    expect(
      Message(type: 'user', content: 'Fala').isAssessmentQuestion,
      isFalse,
    );
    expect(
      Message(type: 'bot', content: 'Texto').isAssessmentQuestion,
      isFalse,
    );
  });
  testWidgets('abre somente edição da turma e passa identidade do aluno', (
    tester,
  ) async {
    Cartilha? opened;
    String? owner;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerClassroomsScreen(
          gateway: FakeClasses(),
          onOpenCourse: (course, userId) {
            opened = course;
            owner = userId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minha turma'));
    await tester.pumpAndSettle();
    expect(opened?.courseVersionId, 'version-1');
    expect(opened?.classId, 'class-1');
    expect(owner, 'student');
  });
  testWidgets('falha não troca para catálogo público', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerClassroomsScreen(
          gateway: FakeClasses()..fails = true,
          onOpenCourse: (_, _) => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minha turma'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(find.byKey(const Key('classroom-course-error')), findsOneWidget);
  });
  test('evento mantém contexto de versão e turma ao reabrir fila offline', () {
    final event = LearningEvent.forSession(
      type: LearningEventType.lessonStarted,
      courseId: 'course',
      sessionId: 'session',
    ).withCourseContext(courseVersionId: 'version-1', classId: 'class-1');
    final restored = LearningEvent.fromJson(event.toJson());
    expect(restored?.payload, {
      'course_version_id': 'version-1',
      'class_id': 'class-1',
    });
    expect(restored?.eventId, event.eventId);
  });
}
