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
    },
  );

  test('rejeita resposta de dashboard sem hierarquia obrigatória', () {
    expect(
      () => ClassroomDashboard.fromJson(const {'students': []}),
      throwsFormatException,
    );
  });
}
