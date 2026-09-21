import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'decodifica dashboard e calcula progresso sem depender de PII local',
    () {
      final dashboard = ClassroomDashboard.fromJson({
        'classroom': {
          'id': 'turma-1',
          'program_id': 'programa-1',
          'course_id': 'agricultura',
          'teacher_id': 'prof-1',
          'name': 'Turma Jalapão',
          'start_date': '2026-09-01',
          'end_date': '2026-12-01',
          'status': 'active',
        },
        'generated_at': '2026-09-20T12:00:00Z',
        'expected_progress_percent': 25.0,
        'summary': {
          'total_students': 1,
          'inactive_students': 1,
          'pending_students': 0,
          'below_expected_students': 1,
        },
        'students': [
          {
            'user_id': 'aluno-1',
            'name': 'Maria da Silva',
            'enrollment_id': 'matricula-1',
            'status': 'active',
            'planned_hours': 40,
            'validated_hours': 8,
            'progress_percent': 20,
            'last_activity_at': '2026-09-10T10:00:00Z',
            'inactive_days': 10,
            'alerts': [
              {'code': 'inactive_7_days'},
              {'code': 'below_expected_hours'},
            ],
          },
        ],
      });

      expect(dashboard.classroom.name, 'Turma Jalapão');
      expect(dashboard.classroom.studentIds, isEmpty);
      expect(dashboard.summary.belowExpectedStudents, 1);
      expect(dashboard.students.single.completion, 0.2);
      expect(dashboard.students.single.alerts, hasLength(2));
      expect(dashboard.students.single.baselineLinked, isNull);
      expect(dashboard.students.single.confirmedSessions, isNull);
      expect(dashboard.summary.openMentorshipCases, isNull);
    },
  );

  test('rejeita resposta de dashboard sem hierarquia obrigatória', () {
    expect(
      () => ClassroomDashboard.fromJson(const {'students': []}),
      throwsFormatException,
    );
  });

  test('decodifica acompanhamento sem confundir ausência com zero', () {
    final summary = ClassroomDashboardSummary.fromJson({
      'total_students': 2,
      'inactive_students': 0,
      'pending_students': 0,
      'below_expected_students': 0,
      'baseline_linked_students': 1,
      'confirmed_participations': 3,
      'open_mentorship_cases': 0,
    });
    expect(summary.baselineLinkedStudents, 1);
    expect(summary.confirmedParticipations, 3);
    expect(summary.openMentorshipCases, 0);
    final student = ClassroomStudent.fromJson({
      'user_id': 's',
      'name': 'Ana',
      'enrollment_id': 'e',
      'status': 'active',
      'planned_hours': 10,
      'validated_hours': 0,
      'progress_percent': 0,
      'last_activity_at': null,
      'inactive_days': 0,
      'alerts': [],
      'baseline_linked': false,
      'confirmed_sessions': 2,
      'open_mentorship_cases': 1,
    });
    expect(student.baselineLinked, false);
    expect(student.confirmedSessions, 2);
    expect(student.openMentorshipCases, 1);
  });
}
