import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../models/class_lifecycle_models.dart';
import 'class_lifecycle_gateway.dart';
import 'pending_class_prepare_store.dart';

class ClassLifecycleRepository implements ClassLifecycleGateway {
  ClassLifecycleRepository({
    required this.apiUrl,
    required this.authRepository,
    http.Client? client,
    PendingClassPrepareStore? pendingPrepareStore,
  }) : _client = client ?? http.Client(),
       _pendingPrepareStore =
           pendingPrepareStore ?? SecurePendingClassPrepareStore();

  final String apiUrl;
  final AuthRepository authRepository;
  final http.Client _client;
  final PendingClassPrepareStore _pendingPrepareStore;
  final Random _random = Random.secure();
  static Future<void> _prepareQueue = Future<void>.value();

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
          '30 participantes é uma referência de planejamento. Inclusões adicionais são permitidas e geram aviso no fluxo de participantes.',
    );
  }

  @override
  Future<PreparedClassroomResult> prepare(
    PrepareClassroomCommand command,
  ) => _serializedPrepare(() => _prepare(command));

  Future<PreparedClassroomResult> _prepare(
    PrepareClassroomCommand command,
  ) async {
    final requested = <String, dynamic>{
      'reason': 'Preparação territorial pelo app Tutor TDS',
      'institution_id': command.institutionId,
      'program_id': command.programId,
      'course_id': command.courseId,
      'version_id': command.courseVersionId,
      'teacher_id': command.teacherId,
      'monitor_ids': List<String>.of(command.monitorIds),
      'name': command.className,
      'offer_municipality': command.offerMunicipality,
      'offer_location': command.offerLocation,
      'start_date': _date(command.startDate),
      'end_date': _date(command.endDate),
    };
    final scope = await _prepareScope();
    final pending = await _readPending(scope);
    if (pending != null) {
      // The previous POST may have committed. Reconcile its exact receipt first,
      // even when a new wizard supplied different fields after screen re-entry.
      return _submitPending(scope, pending);
    }
    final body = <String, dynamic>{'id': _commandId(), ...requested};
    await _writePending(scope, body);
    return _submitPending(scope, body, firstAttempt: true);
  }

  @override
  Future<PreparedClassroomResult?> reconcilePendingPreparation() =>
      _serializedPrepare(_reconcilePendingPreparation);

  Future<PreparedClassroomResult?> _reconcilePendingPreparation() async {
    final scope = await _prepareScope();
    final pending = await _readPending(scope);
    if (pending == null) return null;
    return _submitPending(scope, pending);
  }

  Future<T> _serializedPrepare<T>(Future<T> Function() action) {
    final result = _prepareQueue.then((_) => action());
    _prepareQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<PreparedClassroomResult> _submitPending(
    String scope,
    Map<String, dynamic> body, {
    bool firstAttempt = false,
  }) async {
    if (await _prepareScope() != scope) {
      throw const ClassLifecycleException(
        'A conta mudou. Entre novamente para conferir a preparação pendente.',
      );
    }
    late final Map<String, dynamic> response;
    try {
      response = await _request('POST', '/operations/classes', body, scope);
    } on ClassVersionChangedException {
      _options = const [];
      await _clearPending(scope);
      rethrow;
    } on ClassLifecycleRejectedException catch (error) {
      // The API rejects 403/404/422 before creating a class or receipt. On replay,
      // any response may instead precede lookup of an existing receipt.
      if (firstAttempt &&
          (error.statusCode == 403 ||
              error.statusCode == 404 ||
              error.statusCode == 422)) {
        await _clearPending(scope);
      }
      rethrow;
    }
    final snapshot = _LifecycleSnapshot.fromJson(response);
    await _clearPending(scope);
    _snapshots[snapshot.classroomId] = snapshot;
    return PreparedClassroomResult(
      opaqueId: snapshot.classroomId,
      name: snapshot.classroomName,
      statusLabel: _statusLabel(snapshot.status),
    );
  }

  Future<String> _prepareScope() async {
    try {
      final ownerId = await authRepository.localUserId();
      if (ownerId == null) {
        throw const ClassLifecycleException(
          'Entre novamente para conferir preparações pendentes desta conta.',
        );
      }
      final base = apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      return '$base\u0000$ownerId';
    } on ClassLifecycleException {
      rethrow;
    } on Object {
      throw const ClassLifecycleException(
        'Não foi possível identificar a conta para conferir a preparação pendente.',
      );
    }
  }

  Future<Map<String, dynamic>?> _readPending(String scope) async {
    try {
      final raw = await _pendingPrepareStore.read(scope);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['schema'] != 1) {
        throw const FormatException();
      }
      final body = Map<String, dynamic>.from(decoded['body'] as Map);
      final id = body['id'];
      final digest = sha256.convert(utf8.encode(jsonEncode(body))).toString();
      if (id is! String || id.isEmpty || decoded['digest'] != digest) {
        throw const FormatException();
      }
      return body;
    } on Object {
      // A missing or damaged receipt must not be replaced by a fresh ID.
      throw const ClassLifecycleException(
        'Não foi possível ler a preparação pendente. Tente novamente antes de criar outra turma.',
      );
    }
  }

  Future<void> _writePending(String scope, Map<String, dynamic> body) async {
    try {
      await _pendingPrepareStore.write(
        scope,
        jsonEncode({
          'schema': 1,
          'body': body,
          'digest': sha256.convert(utf8.encode(jsonEncode(body))).toString(),
        }),
      );
    } on Object {
      throw const ClassLifecycleException(
        'Não foi possível guardar a preparação antes de enviá-la. Tente novamente.',
      );
    }
  }

  Future<void> _clearPending(String scope) async {
    try {
      await _pendingPrepareStore.clear(scope);
    } on Object {
      throw const ClassLifecycleException(
        'A turma respondeu, mas a preparação pendente não pôde ser liberada. '
        'Tente recuperar a turma antes de outra preparação.',
      );
    }
  }

  @override
  Future<ClassActivationReadiness> activationReadiness(String classroomId) async {
    final snapshot = await _readSnapshot(classroomId);
    _snapshots[classroomId] = snapshot;
    final blockers = snapshot.activationBlockers
        .map((blocker) => switch (blocker) {
              'offer_municipality_missing' => 'Informe o município da oferta.',
              'offer_location_missing' => 'Informe o local físico da oferta.',
              'course_version_invalid' => 'Confira a edição publicada do curso.',
              'teacher_membership_invalid' => 'Confira o vínculo do professor.',
              'monitor_membership_invalid' => 'Confira os vínculos dos monitores.',
              _ => 'O servidor ainda não liberou a ativação desta turma.',
            })
        .toList(growable: false);
    final canActivate = snapshot.canActivate && snapshot.capabilityCanActivate;
    return ClassActivationReadiness(
      classroomId: classroomId,
      classroomName: snapshot.classroomName,
      canActivate: canActivate,
      blockers: canActivate
          ? const []
          : blockers.isNotEmpty
              ? blockers
              : const ['O servidor ainda não liberou a ativação desta turma.'],
    );
  }

  @override
  Future<ActivatedClassroomResult> activateClassroom({
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
        'target_status': 'active',
      },
    );
    final snapshot = _LifecycleSnapshot.fromJson(response);
    _snapshots[classroomId] = snapshot;
    return ActivatedClassroomResult(
      classroomId: classroomId,
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
            status: snapshot.status,
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    String? expectedPrepareScope,
  ]) async {
    try {
      final base = apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base$path');
      final response = await authRepository.authorized((token) {
        if (expectedPrepareScope != null &&
            '$base\u0000${AuthRepository.unverifiedSubject(token)}' !=
                expectedPrepareScope) {
          throw const ClassLifecycleException(
            'A conta mudou. Entre novamente para conferir a preparação pendente.',
          );
        }
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
        if (response.statusCode == 409) {
          try {
            final body = jsonDecode(response.body);
            if (body is Map &&
                body['detail'] is Map &&
                (body['detail'] as Map)['code'] == 'course_version_changed') {
              throw const ClassVersionChangedException();
            }
          } on FormatException {
            // A malformed error body still receives the generic rejection.
          } on ClassVersionChangedException {
            rethrow;
          }
        }
        final message = switch (response.statusCode) {
          403 => 'Você não tem autorização para esta ação nesta turma.',
          404 => 'O ciclo de turma ainda não está habilitado neste ambiente.',
          409 =>
            'A turma mudou ou ainda não está pronta. Atualize os dados antes de continuar.',
          422 => 'Confira território, período e equipe antes de continuar.',
          _ => 'Não foi possível confirmar a operação de turma no servidor.',
        };
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ClassLifecycleRejectedException(
            message,
            statusCode: response.statusCode,
          );
        }
        throw ClassLifecycleException(message);
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
    required this.canActivate,
    required this.capabilityCanActivate,
    required this.activationBlockers,
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

    final rawActivationBlockers = ready['activation_blockers'];
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
      canActivate: ready['can_activate'] == true,
      capabilityCanActivate: abilities['can_activate'] == true,
      activationBlockers: rawActivationBlockers is List
          ? rawActivationBlockers.whereType<String>().toList(growable: false)
          : const [],
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
  final bool canActivate;
  final bool capabilityCanActivate;
  final List<String> activationBlockers;
  final bool canClose;
  final bool capabilityCanClose;
  final List<String> closureBlockers;
  final Map<String, dynamic> closureWarnings;
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
