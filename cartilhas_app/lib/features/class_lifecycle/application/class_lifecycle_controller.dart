import 'package:flutter/foundation.dart';

import '../data/class_lifecycle_gateway.dart';
import '../models/class_lifecycle_models.dart';

class PrepareClassroomController extends ChangeNotifier {
  PrepareClassroomController(this.gateway);

  final ClassLifecycleGateway gateway;

  ClassLifecycleBootstrap? bootstrap;
  List<LifecycleCourse> courses = const [];
  List<LifecycleStaffMember> staff = const [];
  PublishedCourseVersionInfo? publishedVersion;
  ClassCapacitySnapshot? capacity;

  int currentStep = 0;
  bool loading = false;
  bool busy = false;
  String? error;
  String? staffError;
  PreparedClassroomResult? result;

  String className = '';
  String offerMunicipality = '';
  String offerLocation = '';
  String? programId;
  String? courseId;
  DateTime? startDate;
  DateTime? endDate;
  String? teacherId;
  final Set<String> monitorIds = <String>{};
  String capacityOverrideReason = '';

  bool get isReady => bootstrap != null && !loading && error == null;
  bool get canPrepare => bootstrap?.capabilities.canPrepare ?? false;
  bool get canGoBack => currentStep > 0 && !busy;

  List<LifecycleStaffMember> get teachers => staff
      .where((member) => member.kind == LifecycleStaffKind.teacher)
      .toList(growable: false);

  List<LifecycleStaffMember> get monitors => staff
      .where((member) => member.kind == LifecycleStaffKind.monitor)
      .toList(growable: false);

  LifecycleProgram? get selectedProgram {
    for (final item in bootstrap?.programs ?? const <LifecycleProgram>[]) {
      if (item.id == programId) return item;
    }
    return null;
  }

  LifecycleCourse? get selectedCourse {
    for (final item in courses) {
      if (item.id == courseId) return item;
    }
    return null;
  }

  LifecycleStaffMember? get selectedTeacher {
    for (final item in teachers) {
      if (item.id == teacherId) return item;
    }
    return null;
  }

  List<LifecycleStaffMember> get selectedMonitors => monitors
      .where((member) => monitorIds.contains(member.id))
      .toList(growable: false);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      bootstrap = await gateway.bootstrap();
    } on Object catch (caught) {
      error = caught.toString();
      bootstrap = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setClassName(String value) {
    className = value;
    notifyListeners();
  }

  void setOfferMunicipality(String value) {
    offerMunicipality = value;
    notifyListeners();
  }

  void setOfferLocation(String value) {
    offerLocation = value;
    notifyListeners();
  }

  Future<void> selectProgram(String? value) async {
    if (value == null || value == programId || busy) return;
    programId = value;
    courseId = null;
    teacherId = null;
    monitorIds.clear();
    courses = const [];
    staff = const [];
    publishedVersion = null;
    capacity = null;
    busy = true;
    error = null;
    staffError = null;
    notifyListeners();
    try {
      courses = await gateway.coursesForProgram(value);
      try {
        staff = await gateway.staffForProgram(value);
      } on Object catch (caught) {
        staff = const [];
        staffError = caught.toString();
      }
    } on Object catch (caught) {
      error = caught.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> selectCourse(String? value) async {
    final selectedProgramId = programId;
    if (value == null ||
        value == courseId ||
        selectedProgramId == null ||
        busy) {
      return;
    }
    courseId = value;
    publishedVersion = null;
    capacity = null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        gateway.publishedVersion(value),
        gateway.preparationCapacity(
          programId: selectedProgramId,
          courseId: value,
        ),
      ]);
      publishedVersion = results[0] as PublishedCourseVersionInfo;
      capacity = results[1] as ClassCapacitySnapshot;
    } on Object catch (caught) {
      error = caught.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setDates(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    notifyListeners();
  }

  void setTeacher(String? value) {
    teacherId = value;
    notifyListeners();
  }

  void toggleMonitor(String id, bool selected) {
    if (selected) {
      monitorIds.add(id);
    } else {
      monitorIds.remove(id);
    }
    notifyListeners();
  }

  void setCapacityOverrideReason(String value) {
    capacityOverrideReason = value;
    notifyListeners();
  }

  String? get stepValidationMessage {
    switch (currentStep) {
      case 0:
        if (className.trim().isEmpty) {
          return 'Dê um nome para identificar a turma.';
        }
        if (offerMunicipality.trim().isEmpty) {
          return 'Informe o município da oferta.';
        }
        if (offerLocation.trim().isEmpty) {
          return 'Informe o local onde a formação acontecerá.';
        }
        return null;
      case 1:
        if (programId == null) return 'Selecione o programa.';
        if (courseId == null) return 'Selecione a formação.';
        if (publishedVersion == null || capacity == null) {
          return 'Aguarde a confirmação da formação pelo servidor.';
        }
        return null;
      case 2:
        final start = startDate;
        final end = endDate;
        if (start == null || end == null) {
          return 'Informe o período da turma.';
        }
        if (end.isBefore(start)) {
          return 'A data final não pode ser anterior à data inicial.';
        }
        return null;
      case 3:
        if (staffError != null) return staffError;
        if (teacherId == null) return 'Selecione o professor responsável.';
        return null;
      case 4:
        final snapshot = capacity;
        if (snapshot == null) {
          return 'A capacidade ainda não foi confirmada pelo servidor.';
        }
        if (!snapshot.canProceed) return snapshot.message;
        return null;
      case 5:
        final snapshot = capacity;
        if (!canPrepare) {
          return bootstrap?.capabilities.prepareDeniedMessage ??
              'O servidor não autorizou preparar esta turma.';
        }
        if (snapshot == null || !snapshot.canProceed) {
          return snapshot?.message ??
              'A capacidade ainda não foi confirmada pelo servidor.';
        }
        if (snapshot.requiresOverrideReason &&
            capacityOverrideReason.trim().isEmpty) {
          return 'Informe a justificativa da exceção de capacidade.';
        }
        return null;
      default:
        return null;
    }
  }

  bool get canAdvance =>
      !busy && result == null && stepValidationMessage == null;

  void next() {
    if (!canAdvance || currentStep >= 5) return;
    currentStep += 1;
    notifyListeners();
  }

  void back() {
    if (!canGoBack) return;
    currentStep -= 1;
    notifyListeners();
  }

  Future<void> submit() async {
    if (currentStep != 5 || !canAdvance) return;
    final version = publishedVersion;
    final start = startDate;
    final end = endDate;
    final teacher = teacherId;
    final program = programId;
    final course = courseId;
    final selectedProgram = this.selectedProgram;
    if (version == null ||
        start == null ||
        end == null ||
        teacher == null ||
        program == null ||
        course == null ||
        selectedProgram == null) {
      return;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      result = await gateway.prepare(
        PrepareClassroomCommand(
          className: className.trim(),
          offerMunicipality: offerMunicipality.trim(),
          offerLocation: offerLocation.trim(),
          institutionId: selectedProgram.institutionId,
          programId: program,
          courseId: course,
          courseVersionId: version.opaqueId,
          startDate: start,
          endDate: end,
          teacherId: teacher,
          monitorIds: monitorIds.toList(growable: false),
          capacityOverrideReason: capacity?.requiresOverrideReason == true
              ? capacityOverrideReason.trim()
              : null,
        ),
      );
    } on Object catch (caught) {
      error = caught.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class CloseClassroomController extends ChangeNotifier {
  CloseClassroomController(this.gateway);

  final ClassLifecycleGateway gateway;

  ClassLifecycleBootstrap? bootstrap;
  ClassCloseReadiness? readiness;
  ClosedClassroomResult? result;
  String? selectedClassId;
  String closeReason = '';
  bool certificateNoticeConfirmed = false;
  bool loading = false;
  bool busy = false;
  String? error;

  bool get canCloseCapability => bootstrap?.capabilities.canClose ?? false;

  LifecycleClassSummary? get selectedClass {
    for (final item
        in bootstrap?.manageableClasses ?? const <LifecycleClassSummary>[]) {
      if (item.id == selectedClassId) return item;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      bootstrap = await gateway.bootstrap();
      final classes = bootstrap!.manageableClasses;
      if (classes.isNotEmpty) {
        selectedClassId = classes.first.id;
        readiness = await gateway.closeReadiness(classes.first.id);
      }
    } on Object catch (caught) {
      error = caught.toString();
      readiness = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectClass(String? value) async {
    if (value == null || value == selectedClassId || busy) return;
    selectedClassId = value;
    readiness = null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      readiness = await gateway.closeReadiness(value);
    } on Object catch (caught) {
      error = caught.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setCloseReason(String value) {
    closeReason = value;
    notifyListeners();
  }

  void setCertificateNoticeConfirmed(bool value) {
    certificateNoticeConfirmed = value;
    notifyListeners();
  }

  bool get canSubmit {
    final snapshot = readiness;
    return !busy &&
        result == null &&
        canCloseCapability &&
        snapshot != null &&
        snapshot.canClose &&
        certificateNoticeConfirmed &&
        closeReason.trim().isNotEmpty;
  }

  Future<void> submit() async {
    final classId = selectedClassId;
    if (!canSubmit || classId == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      result = await gateway.closeClassroom(
        classroomId: classId,
        reason: closeReason.trim(),
      );
    } on Object catch (caught) {
      error = caught.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
