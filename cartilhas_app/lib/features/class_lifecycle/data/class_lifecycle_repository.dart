import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../models/class_lifecycle_models.dart';
import 'class_lifecycle_gateway.dart';

class ClassLifecycleRepository implements ClassLifecycleGateway {
  ClassLifecycleRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;
  final Random _random = Random.secure();

  List<_LifecycleOption> _options = const [];
  final Map<String, _LifecycleSnapshot> _snapshots = {};

  @override
  Future<ClassLifecycleBootstrap> bootstrap() async {
    final payload = await _request('GET', '/operations/classes/options');
    final rawOptions = payload['options'];
    if (rawOptions is! List) {
      throw const ClassLifecycleException(
        'O servidor retornou um contexto de turmas inválido.',
      );
    }

    _options = rawOptions
        .whereType<Map>()
        .map(
          (item) => _LifecycleOption.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);

    final programs = <String, LifecycleProgram>{};
    var canPrepare = false;
    var canClose = false;
    var canActivate = false;
    var canOverrideCapacity = false;
    for (final option in _options) {
      programs[option.programId] = LifecycleProgram(
        id: option.programId,
        institutionId: option.institutionId,
        name: option.programName,
      );
      canPrepare = canPrepare || option.canPrepare;
      canClose = canClose || option.canClose;
      canActivate = canActivate || option.canActivate;
      canOverrideCapacity = canOverrideCapacity || option.canOverrideCapacity;
    }

    return ClassLifecycleBootstrap(
      capabilities: ClassLifecycleCapabilities(
        canPrepare: canPrepare,
        canClose: canClose,
        canActivate: canActivate,
        canOverrideCapacity: canOverrideCapacity,
        prepareDeniedMessage: canPrepare
            ? null
            : 'O servidor não liberou a preparação de turmas para este contexto.',
        closeDeniedMessage: canClose
            ? null
            : 'O servidor não liberou o encerramento de turmas para este contexto.',
      ),
      programs: programs.values.toList(growable: false),
      manageableClasses: await _manageableClasses(),
    );
  }

  @override
  Future<List<LifecycleCourse>> coursesForProgram(String programId) async {
    await _ensureOptions();
    return _options
        .where((item) => item.programId == programId)
        .map(
          (item) => LifecycleCourse(
            id: item.courseId,
            programId: item.programId,
            name: item.courseTitle,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PublishedCourseVersionInfo> publishedVersion(String courseId) async {
    await _ensureOptions();
    _LifecycleOption? option;
    for (final item in _options) {
      if (item.courseId == courseId) {
        option = item;
        break;
      }
    }
    if (option == null || option.courseVersionId == null) {
      throw const ClassLifecycleException(
        'Esta formação ainda não possui uma edição publicada.',
      );
    }
    return PublishedCourseVersionInfo(
      opaqueId: option.courseVersionId!,
      label: option.versionNumber == null
          ? 'Edição publicada atual'
          : 'Edição publicada ${option.versionNumber}',
    );
  }

  @override
  Future<List<LifecycleStaffMember>> staffForProgram(String programId) async {
    await _ensureOptions();
    if (!_options.any((item) => item.programId == programId)) return const [];

    final payload = await _request(
      'GET',
      '/operations/classes/team-candidates?program_id=${Uri.encodeQueryComponent(programId)}',
    );
    final rawCandidates = payload['candidates'];
    if (rawCandidates is! List) {
      throw const ClassLifecycleException(
        'O servidor retornou uma equipe de turma inválida.',
      );
    }

    return rawCandidates
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final id = item['user_id'];
          final name = item['display_name'];
          final role = item['role'];
          if (id is! String ||
              id.trim().isEmpty ||
              name is! String ||
              name.trim().isEmpty ||
              (role != 'teacher' && role != 'monitor')) {
            throw const ClassLifecycleException(
              'O servidor retornou uma equipe de turma incompleta.',
            );
          }
          return LifecycleStaffMember(
            id: id,
            name: name,
            kind: role == 'teacher'
                ? LifecycleStaffKind.teacher
                : LifecycleStaffKind.monitor,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ClassCapacitySnapshot> preparationCapacity({
    required String programId,
    required String courseId,
  }) async {
    await _ensureOptions();
    final known = _options.any(
      (item) => item.programId == programId && item.courseId == courseId,
    );
    if (!known) {
      throw const ClassLifecycleException(
        'A formação não pertence ao contexto autorizado.',
      );
    }
    return const ClassCapacitySnapshot(
      occupancy: 0,
      capacity: 30,
      canProceed: true,
      requiresOverrideReason: false,
      deferredToParticipants: true,
      message:
          'O limite de 30 e eventual exceção são validados pelo servidor ao adicionar participantes.',
    );
  }

  @override
  Future<PreparedClassroomResult> prepare(
    PrepareClassroomCommand command,
  ) async {
    final response = await _request('POST', '/operations/classes', {
      'id': _commandId(),
      'reason': 'Preparação territorial pelo app Tutor TDS',
      'institution_id': command.institutionId,
      'program_id': command.programId,
      'course_id': command.courseId,
      'teacher_id': command.teacherId,
      'monitor_ids': command.monitorIds,
      'name': command.className,
      'offer_municipality': command.offerMunicipality,
      'offer_location': command.offerLocation,
      'start_date': _date(command.startDate),
      'end_date': _date(command.endDate),
    });
    final snapshot = _LifecycleSnapshot.fromJson(response);
    _snapshots[snapshot.classroomId] = snapshot;
    return PreparedClassroomResult(
      opaqueId: snapshot.classroomId,
      name: snapshot.classroomName,
      statusLabel: _statusLabel(snapshot.status),
    );
  }

  @override
  Future<ClassCloseReadiness> closeReadiness(String classroomId) async {
    final response = await _request(
      'GET',
      '/operations/classes/${Uri.encodeComponent(classroomId)}/readiness',
    );
    final snapshot = _LifecycleSnapshot.fromJson(response);
    _snapshots[classroomId] = snapshot;

    final warnings = snapshot.closureWarnings;
    final canClose = snapshot.canClose && snapshot.capabilityCanClose;
    final blockers = snapshot.closureBlockers
        .map(
          (blocker) => switch (blocker) {
            'open_sessions' =>
              'Encerre todos os encontros em aberto antes de encerrar a turma.',
            _ => 'O servidor ainda não liberou o encerramento desta turma.',
          },
        )
        .toList(growable: false);
    return ClassCloseReadiness(
      classroomId: classroomId,
      classroomName: snapshot.classroomName,
      openSessions: _int(warnings['open_sessions']),
      pendingAttendance: _int(warnings['pending_makeup']),
      pendingEvidence: _int(warnings['pending_evidence']),
      participants: snapshot.occupancy,
      pendingCertificateRequests: _int(
        warnings['pending_certificate_requests'],
      ),
      canClose: canClose,
      blockers: canClose
          ? const []
          : blockers.isNotEmpty
          ? blockers
          : const ['O servidor ainda não liberou o encerramento desta turma.'],
    );
  }

  @override
  Future<ClosedClassroomResult> closeClassroom({
    required String classroomId,
    required String reason,
  }) async {
    final current = _snapshots[classroomId] ?? await _readSnapshot(classroomId);
    final response = await _request(
      'POST',
      '/operations/classes/${Uri.encodeComponent(classroomId)}/transition',
      {
        'id': _commandId(),
        'reason': reason,
        'institution_id': current.institutionId,
        'program_id': current.programId,
        'course_id': current.courseId,
        'version_id': current.courseVersionId,
        'expected_revision': current.revision,
        'target_status': 'closed',
      },
    );
    final snapshot = _LifecycleSnapshot.fromJson(response);
    _snapshots[classroomId] = snapshot;
    return ClosedClassroomResult(
      classroomId: classroomId,
      statusLabel: _statusLabel(snapshot.status),
    );
  }

  Future<_LifecycleSnapshot> _readSnapshot(String classroomId) async {
    final response = await _request(
      'GET',
      '/operations/classes/${Uri.encodeComponent(classroomId)}/readiness',
    );
    return _LifecycleSnapshot.fromJson(response);
  }

  Future<void> _ensureOptions() async {
    if (_options.isNotEmpty) return;
    final payload = await _request('GET', '/operations/classes/options');
    final rawOptions = payload['options'];
    if (rawOptions is! List) {
      throw const ClassLifecycleException(
        'O servidor retornou um contexto de turmas inválido.',
      );
    }
    _options = rawOptions
        .whereType<Map>()
        .map(
          (item) => _LifecycleOption.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<LifecycleClassSummary>> _manageableClasses() async {
    final payload = await _request('GET', '/operations/classes');
    final rawClasses = payload['classes'];
    if (rawClasses is! List) {
      throw const ClassLifecycleException(
        'O servidor retornou uma lista de turmas inválida.',
      );
    }

    return rawClasses
        .whereType<Map>()
        .map(
          (item) =>
              _LifecycleSnapshot.fromJson(Map<String, dynamic>.from(item)),
        )
        .map((snapshot) {
          _snapshots[snapshot.classroomId] = snapshot;
          return LifecycleClassSummary(
            id: snapshot.classroomId,
            name: snapshot.classroomName,
            statusLabel: _statusLabel(snapshot.status),
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final base = apiUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base$path');
      final response = await authRepository.authorized((token) {
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        return switch (method) {
          'POST' =>
            _client
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(const Duration(seconds: 15)),
          _ =>
            _client
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 15)),
        };
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClassLifecycleException(switch (response.statusCode) {
          403 => 'Você não tem autorização para esta ação nesta turma.',
          404 => 'O ciclo de turma ainda não está habilitado neste ambiente.',
          409 =>
            'A turma mudou ou ainda não está pronta. Atualize os dados antes de continuar.',
          422 => 'Confira território, período e equipe antes de continuar.',
          _ => 'Não foi possível confirmar a operação de turma no servidor.',
        });
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on ClassLifecycleException {
      rethrow;
    } on AuthException catch (error) {
      throw ClassLifecycleException(error.message);
    } on Object {
      throw const ClassLifecycleException(
        'Não foi possível conectar ao ciclo de turma agora.',
      );
    }
  }

  String _commandId() {
    final bytes = List<int>.generate(20, (_) => _random.nextInt(256));
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'app-$hex';
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _statusLabel(String status) => switch (status) {
    'planned' => 'Planejada',
    'active' => 'Em andamento',
    'closed' => 'Encerrada',
    _ => status,
  };

  void dispose() => _client.close();
}

class _LifecycleOption {
  const _LifecycleOption({
    required this.institutionId,
    required this.programId,
    required this.programName,
    required this.courseId,
    required this.courseTitle,
    required this.courseVersionId,
    required this.versionNumber,
    required this.canPrepare,
    required this.canActivate,
    required this.canClose,
    required this.canOverrideCapacity,
  });

  factory _LifecycleOption.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException();
      }
      return value;
    }

    return _LifecycleOption(
      institutionId: requiredString('institution_id'),
      programId: requiredString('program_id'),
      programName: requiredString('program_name'),
      courseId: requiredString('course_id'),
      courseTitle: requiredString('course_title'),
      courseVersionId: json['course_version_id'] is String
          ? json['course_version_id'] as String
          : null,
      versionNumber: json['version_number']?.toString(),
      canPrepare: json['can_prepare'] == true,
      canActivate: json['can_activate'] == true,
      canClose: json['can_close'] == true,
      canOverrideCapacity: json['can_override_capacity'] == true,
    );
  }

  final String institutionId;
  final String programId;
  final String programName;
  final String courseId;
  final String courseTitle;
  final String? courseVersionId;
  final String? versionNumber;
  final bool canPrepare;
  final bool canActivate;
  final bool canClose;
  final bool canOverrideCapacity;
}

class _LifecycleSnapshot {
  const _LifecycleSnapshot({
    required this.classroomId,
    required this.classroomName,
    required this.institutionId,
    required this.programId,
    required this.courseId,
    required this.courseVersionId,
    required this.status,
    required this.revision,
    required this.occupancy,
    required this.canClose,
    required this.capabilityCanClose,
    required this.closureBlockers,
    required this.closureWarnings,
  });

  factory _LifecycleSnapshot.fromJson(Map<String, dynamic> json) {
    final classroom = json['classroom'];
    final capacity = json['capacity'];
    final readiness = json['readiness'];
    final capabilities = json['capabilities'];
    if (classroom is! Map ||
        capacity is! Map ||
        readiness is! Map ||
        capabilities is! Map) {
      throw const ClassLifecycleException(
        'O servidor retornou um snapshot de turma inválido.',
      );
    }

    final c = Map<String, dynamic>.from(classroom);
    final cap = Map<String, dynamic>.from(capacity);
    final ready = Map<String, dynamic>.from(readiness);
    final abilities = Map<String, dynamic>.from(capabilities);

    String requiredString(String key) {
      final value = c[key];
      if (value is! String || value.trim().isEmpty) {
        throw const ClassLifecycleException(
          'O servidor retornou um contexto de turma incompleto.',
        );
      }
      return value;
    }

    final rawBlockers = ready['closure_blockers'];
    final warnings = ready['closure_warnings'];
    return _LifecycleSnapshot(
      classroomId: requiredString('id'),
      classroomName: requiredString('name'),
      institutionId: requiredString('institution_id'),
      programId: requiredString('program_id'),
      courseId: requiredString('course_id'),
      courseVersionId: requiredString('course_version_id'),
      status: requiredString('status'),
      revision: _int(c['revision']),
      occupancy: _int(cap['occupancy']),
      canClose: ready['can_close'] == true,
      capabilityCanClose: abilities['can_close'] == true,
      closureBlockers: rawBlockers is List
          ? rawBlockers.whereType<String>().toList(growable: false)
          : const [],
      closureWarnings: warnings is Map
          ? Map<String, dynamic>.from(warnings)
          : const {},
    );
  }

  final String classroomId;
  final String classroomName;
  final String institutionId;
  final String programId;
  final String courseId;
  final String courseVersionId;
  final String status;
  final int revision;
  final int occupancy;
  final bool canClose;
  final bool capabilityCanClose;
  final List<String> closureBlockers;
  final Map<String, dynamic> closureWarnings;
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
