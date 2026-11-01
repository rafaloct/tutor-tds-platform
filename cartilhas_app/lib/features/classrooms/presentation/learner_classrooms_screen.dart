import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../models/cartilha.dart';
import '../../../screens/chat_experience_screen.dart';
import '../../analytics/telemetry_route.dart';
import '../../auth/data/auth_repository.dart';
import '../data/classroom_repository.dart';
import '../data/learner_offline_repository.dart';
import '../models/classroom_models.dart';
import '../../learning_context/learning_context_controller.dart';
import '../../learning_context/learning_context_repository.dart';
import '../data/self_enrollment_repository.dart';

/// Class membership is verified by the API; the public catalog stays separate.
class LearnerClassroomsScreen extends StatefulWidget {
  const LearnerClassroomsScreen({
    super.key,
    this.gateway,
    this.onOpenCourse,
    this.contextRepository,
    this.selfEnrollmentGateway,
  });
  final LearnerClassroomGateway? gateway;
  final LearningContextRepository? contextRepository;
  final SelfEnrollmentGateway? selfEnrollmentGateway;
  final void Function(Cartilha course, String ownerId)? onOpenCourse;

  @override
  State<LearnerClassroomsScreen> createState() =>
      _LearnerClassroomsScreenState();
}

class _LearnerClassroomsScreenState extends State<LearnerClassroomsScreen> {
  late final LearnerClassroomGateway _gateway;
  ClassroomRepository? _ownedRemote;
  RemoteLearningContextRepository? _ownedContextRepository;
  LearningContextController? _contextController;
  SelfEnrollmentGateway? _selfEnrollment;
  RemoteSelfEnrollmentRepository? _ownedSelfEnrollment;
  List<ClassroomDetails> _classes = const [];
  List<OpenClassItem> _openClasses = const [];
  String? _ownerId;
  String? _error;
  bool _loading = true;
  String? _opening;

  @override
  void initState() {
    super.initState();
    if (widget.gateway != null) {
      _gateway = widget.gateway!;
    } else {
      final auth = context.read<AuthRepository>();
      _ownedRemote = ClassroomRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      _gateway = LearnerOfflineRepository(
        remote: _ownedRemote!,
        auth: auth,
        apiUrl: AppConfig.tutorApiUrl,
      );
    }
    if (widget.contextRepository != null) {
      _contextController = LearningContextController(widget.contextRepository!);
    } else if (AppConfig.learningContextEnabled) {
      _ownedContextRepository = RemoteLearningContextRepository(
        apiUrl: AppConfig.tutorApiUrl,
        auth: context.read<AuthRepository>(),
      );
      _contextController = LearningContextController(_ownedContextRepository!);
    }
    _selfEnrollment =
        widget.selfEnrollmentGateway ??
        (AppConfig.selfEnrollmentEnabled
            ? (_ownedSelfEnrollment = RemoteSelfEnrollmentRepository(
                apiUrl: AppConfig.tutorApiUrl,
                auth: context.read<AuthRepository>(),
              ))
            : null);
    _load();
  }

  @override
  void dispose() {
    _ownedRemote?.dispose();
    _contextController?.dispose();
    _ownedContextRepository?.dispose();
    _ownedSelfEnrollment?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _classes = const [];
      _ownerId = null;
    });
    try {
      final user = await _gateway.currentUser();
      final classes = await _gateway.learnerClassrooms();
      var openClasses = const <OpenClassItem>[];
      final selfEnrollment = _selfEnrollment;
      if (selfEnrollment != null) {
        try {
          openClasses = (await selfEnrollment.openClasses())
              .where((item) => !item.viewerEnrolled)
              .toList(growable: false);
        } on Object {
          // Open-class discovery is additive; its failure must not hide
          // the learner's existing classes.
          openClasses = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _ownerId = user.id;
        _classes = classes;
        _openClasses = openClasses;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar suas turmas. Confira sua conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ClassroomDetails classroom) => _openClass(classroom.id);

  Future<void> _enrollAndOpen(OpenClassItem item) async {
    final selfEnrollment = _selfEnrollment;
    if (_opening != null || _ownerId == null || selfEnrollment == null) {
      return;
    }
    setState(() {
      _opening = item.id;
      _error = null;
    });
    try {
      // The server creates membership -> enrollment -> class enrollment ->
      // cohort binding atomically and returns the resolved context. The
      // standard guarded open below re-resolves it so offline caching keeps
      // a single writer.
      await selfEnrollment.selfEnroll(item.courseId);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível concluir sua matrícula agora. Verifique sua conexão e tente novamente; você não será matriculado duas vezes.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _opening = null);
    }
    await _load();
    if (mounted && _error == null) await _openClass(item.id);
  }

  Future<void> _openClass(String classId) async {
    if (_opening != null || _ownerId == null) return;
    setState(() {
      _opening = classId;
      _error = null;
    });
    try {
      final snapshot = await _contextController?.load(classId);
      if (!mounted) return;
      if (_contextController != null &&
          (snapshot == null || snapshot.context.userId != _ownerId)) {
        throw const ClassroomException('Contexto da matrícula indisponível.');
      }
      final course = await _gateway.course(classId);
      if (!mounted) return;
      if (snapshot != null && !snapshot.context.matchesCourse(course)) {
        throw const ClassroomException('A edição não corresponde à matrícula.');
      }
      if (widget.onOpenCourse != null) {
        widget.onOpenCourse!(course, _ownerId!);
      } else {
        await Navigator.of(context).push(
          trackedRoute(
            pageId: 'classroom_course',
            courseId: course.id,
            builder: (_) => ChatExperienceScreen(
              cartilha: course,
              progressOwnerId: _ownerId,
              savedClassroomContent: _usingSavedData,
              learningContextController: _contextController,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível abrir a edição vinculada à turma. Nenhuma outra edição foi aberta no lugar. Tente novamente ou procure a equipe.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  bool get _usingSavedData =>
      _gateway is LearnerOfflineRepository && _gateway.usingSavedData;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minhas turmas')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Abra o conteúdo que sua equipe preparou para cada turma. A edição é preservada mesmo quando o catálogo recebe atualizações.',
              ),
              const SizedBox(height: 16),
              if (_usingSavedData)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Sem conexão: exibindo turmas salvas neste aparelho. Abra somente conteúdos já salvos. Reconecte em até 7 dias para atualizar seu acesso.',
                    ),
                  ),
                )
              else
                const Text(
                  'Ao abrir o conteúdo com internet, uma cópia da edição da sua turma fica salva para estudar sem rede por até 7 dias.',
                ),
              TextButton.icon(
                onPressed: _opening == null ? _load : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar turmas'),
              ),
              if (_error != null) ...[
                Text(_error!, key: const Key('classroom-course-error')),
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
              if (_classes.isEmpty && _error == null)
                const Text(
                  'Você ainda não tem turmas vinculadas. Peça ajuda ao professor ou monitor. Os cursos públicos continuam disponíveis no início.',
                ),
              for (final classroom in _classes)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(classroom.name),
                    subtitle: Text(
                      classroom.status == 'closed'
                          ? 'Turma encerrada • consultar conteúdo'
                          : 'Conteúdo da turma',
                    ),
                    trailing: _opening == classroom.id
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _opening == null ? () => _open(classroom) : null,
                  ),
                ),
              if (_openClasses.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Cursos abertos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toque para criar sua matrícula e abrir a edição da turma. O registro do seu progresso fica vinculado à sua conta.',
                ),
                const SizedBox(height: 8),
                for (final item in _openClasses)
                  Card(
                    child: ListTile(
                      key: Key('open-class-${item.id}'),
                      leading: const Icon(Icons.lock_open_outlined),
                      title: Text(item.courseTitle),
                      subtitle: Text('${item.name} • matrícula espontânea'),
                      trailing: _opening == item.id
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.how_to_reg_outlined),
                      onTap: _opening == null
                          ? () => _enrollAndOpen(item)
                          : null,
                    ),
                  ),
              ],
            ],
          ),
  );
}
