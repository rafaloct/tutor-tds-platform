import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/application/team_capability.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapabilityGateway implements ClassroomGateway {
  _CapabilityGateway({
    required this.userId,
    required this.teacherId,
    this.monitorIds = const [],
    this.role = 'student',
  });

  final String userId;
  final String teacherId;
  final List<String> monitorIds;
  final String role;

  ClassroomDetails get _base => ClassroomDetails(
    id: 'class-1',
    programId: 'program-1',
    courseId: 'course-1',
    teacherId: teacherId,
    name: 'Turma 1',
    startDate: DateTime.utc(2026, 9),
    endDate: DateTime.utc(2026, 12),
    status: 'active',
    studentIds: const [],
    monitorIds: const [],
  );

  @override
  Future<AuthUser> currentUser() async =>
      AuthUser(id: userId, name: 'Pessoa', role: role);

  @override
  Future<List<ClassroomDetails>> classrooms() async => [_base];

  @override
  Future<ClassroomDetails> classroom(String classId) async => ClassroomDetails(
    id: _base.id,
    programId: _base.programId,
    courseId: _base.courseId,
    teacherId: _base.teacherId,
    name: _base.name,
    startDate: _base.startDate,
    endDate: _base.endDate,
    status: _base.status,
    studentIds: const ['student-1'],
    monitorIds: monitorIds,
  );

  @override
  Future<ClassroomDashboard> dashboard(String classId) =>
      throw UnimplementedError();

  @override
  Future<StudentHours> studentHours({
    required ClassroomDetails classroom,
    required String userId,
  }) => throw UnimplementedError();

  @override
  Future<UsageSummary> usage(String classId, {int days = 30}) =>
      throw UnimplementedError();
}

void main() {
  test(
    'deriva professor pelo vínculo da turma, não pelo papel global',
    () async {
      final snapshot = await TeamCapabilityResolver(
        _CapabilityGateway(userId: 'teacher-1', teacherId: 'teacher-1'),
      ).resolve();

      expect(snapshot.hasAccess, isTrue);
      expect(snapshot.hasTeacherCockpit, isTrue);
      expect(snapshot.forClass('class-1'), ClassroomStaffCapability.teacher);
    },
  );

  test('deriva monitor somente do detalhe autorizado da turma', () async {
    final snapshot = await TeamCapabilityResolver(
      _CapabilityGateway(
        userId: 'monitor-1',
        teacherId: 'teacher-1',
        monitorIds: const ['monitor-1'],
        role: 'monitor',
      ),
    ).resolve();

    expect(snapshot.hasAccess, isTrue);
    expect(snapshot.hasTeacherCockpit, isFalse);
    expect(snapshot.forClass('class-1'), ClassroomStaffCapability.monitor);
  });

  test('estudante visível na turma não recebe entrypoint de equipe', () async {
    final snapshot = await TeamCapabilityResolver(
      _CapabilityGateway(userId: 'student-1', teacherId: 'teacher-1'),
    ).resolve();

    expect(snapshot.hasAccess, isFalse);
    expect(snapshot.classrooms, isEmpty);
    expect(snapshot.capabilities, isEmpty);
  });
}
