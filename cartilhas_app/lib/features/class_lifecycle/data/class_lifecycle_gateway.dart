import '../models/class_lifecycle_models.dart';

abstract interface class ClassLifecycleGateway {
  Future<ClassLifecycleBootstrap> bootstrap();

  Future<List<LifecycleCourse>> coursesForProgram(String programId);

  Future<PublishedCourseVersionInfo> publishedVersion(String courseId);

  Future<List<LifecycleStaffMember>> staffForProgram(String programId);

  Future<ClassCapacitySnapshot> preparationCapacity({
    required String programId,
    required String courseId,
  });

  Future<PreparedClassroomResult> prepare(PrepareClassroomCommand command);

  Future<ClassActivationReadiness> activationReadiness(String classroomId);

  Future<ActivatedClassroomResult> activateClassroom({
    required String classroomId,
    required String reason,
  });

  Future<ClassCloseReadiness> closeReadiness(String classroomId);

  Future<ClosedClassroomResult> closeClassroom({
    required String classroomId,
    required String reason,
  });
}

class ClassLifecycleException implements Exception {
  const ClassLifecycleException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ClassLifecycleRejectedException extends ClassLifecycleException {
  const ClassLifecycleRejectedException(super.message);
}

class ClassVersionChangedException extends ClassLifecycleRejectedException {
  const ClassVersionChangedException()
      : super('A edição publicada mudou. Selecione a formação novamente para confirmar a nova edição.');
}

/// Fake de desenvolvimento para validar a UX do contrato da Issue #138.
///
/// A UI nunca lê papel global. As diferenças entre os cenários abaixo chegam
/// exclusivamente como capabilities, como acontecerá com o backend autoritativo.
class FakeClassLifecycleGateway implements ClassLifecycleGateway {
  FakeClassLifecycleGateway({
    required this.capabilities,
    this.failBootstrap = false,
    this.readinessCanClose = true,
    this.readinessCanActivate = true,
    this.manageableClasses,
    this.failNextActivationReadiness = false,
    this.failNextCloseReadiness = false,
    this.failNextPrepareVersionChanged = false,
    this.simulatedDelay = const Duration(milliseconds: 120),
    this.occupancy = 18,
    this.capacity = 30,
  });

  factory FakeClassLifecycleGateway.coordinator({
    bool readinessCanClose = true,
  }) => FakeClassLifecycleGateway(
    capabilities: const ClassLifecycleCapabilities(
      canPrepare: true,
      canClose: true,
      canActivate: true,
      canOverrideCapacity: false,
    ),
    readinessCanClose: readinessCanClose,
  );

  factory FakeClassLifecycleGateway.programOperator() =>
      FakeClassLifecycleGateway(
        capabilities: const ClassLifecycleCapabilities(
          canPrepare: true,
          canClose: true,
          canActivate: true,
          canOverrideCapacity: false,
        ),
      );

  factory FakeClassLifecycleGateway.denied() => FakeClassLifecycleGateway(
    capabilities: const ClassLifecycleCapabilities(
      canPrepare: false,
      canClose: false,
      canActivate: false,
      canOverrideCapacity: false,
      prepareDeniedMessage:
          'O servidor não liberou a preparação de turmas para este contexto.',
      closeDeniedMessage:
          'O servidor não liberou o encerramento de turmas para este contexto.',
    ),
  );

  final ClassLifecycleCapabilities capabilities;
  final bool failBootstrap;
  final bool readinessCanClose;
  final bool readinessCanActivate;
  final List<LifecycleClassSummary>? manageableClasses;
  bool failNextActivationReadiness;
  bool failNextCloseReadiness;
  bool failNextPrepareVersionChanged;
  final Duration simulatedDelay;
  final int occupancy;
  final int capacity;

  PrepareClassroomCommand? lastPrepareCommand;
  String? lastCloseReason;
  String? lastActivationReason;

  static const _programs = [
    LifecycleProgram(
      id: 'program-tds',
      institutionId: 'institution-tds',
      name: 'Programa TDS',
    ),
  ];

  static const _courses = [
    LifecycleCourse(
      id: 'course-ia',
      programId: 'program-tds',
      name: 'Inteligência Artificial aplicada',
    ),
    LifecycleCourse(
      id: 'course-inclusao',
      programId: 'program-tds',
      name: 'Inclusão Digital',
    ),
  ];

  static const _staff = [
    LifecycleStaffMember(
      id: 'teacher-1',
      name: 'Professora responsável',
      kind: LifecycleStaffKind.teacher,
    ),
    LifecycleStaffMember(
      id: 'monitor-1',
      name: 'Monitor de campo',
      kind: LifecycleStaffKind.monitor,
    ),
    LifecycleStaffMember(
      id: 'monitor-2',
      name: 'Monitor de apoio',
      kind: LifecycleStaffKind.monitor,
    ),
  ];

  static const _classes = [
    LifecycleClassSummary(
      id: 'class-active-1',
      name: 'Turma Palmas — IA',
      statusLabel: 'Em andamento',
      status: 'active',
    ),
    LifecycleClassSummary(
      id: 'class-planned-1',
      name: 'Turma Palmas — Inclusão Digital',
      statusLabel: 'Planejada',
      status: 'planned',
    ),
  ];

  Future<void> _wait() => Future<void>.delayed(simulatedDelay);

  @override
  Future<ClassLifecycleBootstrap> bootstrap() async {
    await _wait();
    if (failBootstrap) {
      throw const ClassLifecycleException(
        'Não foi possível carregar as permissões de turma.',
      );
    }
    return ClassLifecycleBootstrap(
      capabilities: capabilities,
      programs: _programs,
      manageableClasses: manageableClasses ?? _classes,
    );
  }

  @override
  Future<List<LifecycleCourse>> coursesForProgram(String programId) async {
    await _wait();
    return _courses
        .where((course) => course.programId == programId)
        .toList(growable: false);
  }

  @override
  Future<PublishedCourseVersionInfo> publishedVersion(String courseId) async {
    await _wait();
    if (!_courses.any((course) => course.id == courseId)) {
      throw const ClassLifecycleException('Formação indisponível.');
    }
    return const PublishedCourseVersionInfo(
      opaqueId: 'version-server-only',
      label: 'Edição publicada atual',
    );
  }

  @override
  Future<List<LifecycleStaffMember>> staffForProgram(String programId) async {
    await _wait();
    if (!_programs.any((program) => program.id == programId)) {
      return const [];
    }
    return _staff;
  }

  @override
  Future<ClassCapacitySnapshot> preparationCapacity({
    required String programId,
    required String courseId,
  }) async {
    await _wait();
    return ClassCapacitySnapshot(
      occupancy: occupancy,
      capacity: capacity,
      canProceed: true,
      requiresOverrideReason: false,
      message: occupancy >= capacity
          ? 'A referência de $capacity participantes foi atingida. Você pode continuar; o servidor mostrará o aviso de capacidade.'
          : 'Capacidade de referência informada pelo servidor.',
    );
  }

  @override
  Future<PreparedClassroomResult> prepare(
    PrepareClassroomCommand command,
  ) async {
    await _wait();
    if (failNextPrepareVersionChanged) {
      failNextPrepareVersionChanged = false;
      throw const ClassVersionChangedException();
    }
    if (!capabilities.canPrepare) {
      throw const ClassLifecycleException(
        'O servidor não autorizou preparar esta turma.',
      );
    }
    lastPrepareCommand = command;
    return const PreparedClassroomResult(
      opaqueId: 'class-prepared-1',
      name: 'Nova turma preparada',
      statusLabel: 'Planejada',
    );
  }

  @override
  Future<ClassActivationReadiness> activationReadiness(String classroomId) async {
    await _wait();
    if (failNextActivationReadiness) {
      failNextActivationReadiness = false;
      throw const ClassLifecycleException('Falha temporária ao consultar prontidão.');
    }
    final classes = manageableClasses ?? _classes;
    final classroom = classes.where((item) => item.id == classroomId).firstOrNull;
    return ClassActivationReadiness(
      classroomId: classroomId,
      classroomName: classroom?.name ?? 'Turma Palmas — Inclusão Digital',
      canActivate: capabilities.canActivate && readinessCanActivate,
      blockers: readinessCanActivate
          ? const []
          : const ['A turma ainda não está pronta para ativação.'],
    );
  }

  @override
  Future<ActivatedClassroomResult> activateClassroom({
    required String classroomId,
    required String reason,
  }) async {
    await _wait();
    if (!capabilities.canActivate || !readinessCanActivate) {
      throw const ClassLifecycleException('O servidor não autorizou ativar esta turma.');
    }
    if (reason.trim().isEmpty) {
      throw const ClassLifecycleException('Informe o motivo da ativação.');
    }
    lastActivationReason = reason.trim();
    return ActivatedClassroomResult(
      classroomId: classroomId,
      statusLabel: 'Em andamento',
    );
  }

  @override
  Future<ClassCloseReadiness> closeReadiness(String classroomId) async {
    await _wait();
    if (failNextCloseReadiness) {
      failNextCloseReadiness = false;
      throw const ClassLifecycleException('Falha temporária ao consultar prontidão.');
    }
    final classes = manageableClasses ?? _classes;
    final classroom = classes.where((item) => item.id == classroomId).firstOrNull;
    final blockers = readinessCanClose
        ? const <String>[]
        : const <String>[
            'Encerre a sessão aberta antes de encerrar a turma.',
          ];
    return ClassCloseReadiness(
      classroomId: classroomId,
      classroomName: classroom?.name ?? 'Turma Palmas — IA',
      openSessions: readinessCanClose ? 0 : 1,
      pendingAttendance: readinessCanClose ? 0 : 2,
      pendingEvidence: readinessCanClose ? 0 : 1,
      participants: 26,
      pendingCertificateRequests: 4,
      canClose: readinessCanClose,
      blockers: blockers,
    );
  }

  @override
  Future<ClosedClassroomResult> closeClassroom({
    required String classroomId,
    required String reason,
  }) async {
    await _wait();
    if (!capabilities.canClose) {
      throw const ClassLifecycleException(
        'O servidor não autorizou encerrar esta turma.',
      );
    }
    if (!readinessCanClose) {
      throw const ClassLifecycleException(
        'A turma ainda possui pendências para encerramento.',
      );
    }
    if (reason.trim().isEmpty) {
      throw const ClassLifecycleException('Informe o motivo do encerramento.');
    }
    lastCloseReason = reason.trim();
    return ClosedClassroomResult(
      classroomId: classroomId,
      statusLabel: 'Encerrada',
    );
  }
}
