import '../../auth/models/auth_session.dart';
import '../data/classroom_repository.dart';
import '../models/classroom_models.dart';

enum ClassroomStaffCapability { teacher, monitor }

class TeamCapabilitySnapshot {
  TeamCapabilitySnapshot({
    required this.user,
    required List<ClassroomDetails> classrooms,
    required Map<String, ClassroomStaffCapability> capabilities,
  }) : classrooms = List.unmodifiable(classrooms),
       capabilities = Map.unmodifiable(capabilities);

  final AuthUser user;
  final List<ClassroomDetails> classrooms;
  final Map<String, ClassroomStaffCapability> capabilities;

  bool get hasAccess => classrooms.isNotEmpty;
  bool get hasTeacherCockpit => capabilities.values.any(
    (value) => value == ClassroomStaffCapability.teacher,
  );

  ClassroomStaffCapability? forClass(String? classId) =>
      classId == null ? null : capabilities[classId];
}

class TeamCapabilityResolver {
  const TeamCapabilityResolver(this.gateway);

  final ClassroomGateway gateway;

  Future<TeamCapabilitySnapshot> resolve() async {
    final user = await gateway.currentUser();
    final visible = await gateway.classrooms();
    final allowed = <ClassroomDetails>[];
    final capabilities = <String, ClassroomStaffCapability>{};

    for (final classroom in visible) {
      if (user.role == 'admin' || classroom.teacherId == user.id) {
        allowed.add(classroom);
        capabilities[classroom.id] = ClassroomStaffCapability.teacher;
        continue;
      }
      try {
        final details = await gateway.classroom(classroom.id);
        if (details.monitorIds.contains(user.id)) {
          allowed.add(details);
          capabilities[classroom.id] = ClassroomStaffCapability.monitor;
        }
      } on Object {
        // Uma turma visível como estudante não concede acesso à equipe.
      }
    }

    return TeamCapabilitySnapshot(
      user: user,
      classrooms: allowed,
      capabilities: capabilities,
    );
  }
}
