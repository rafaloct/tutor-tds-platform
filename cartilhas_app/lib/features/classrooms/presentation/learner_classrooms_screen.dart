import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../models/cartilha.dart';
import '../../../screens/chat_experience_screen.dart';
import '../../analytics/telemetry_route.dart';
import '../../auth/data/auth_repository.dart';
import '../data/classroom_repository.dart';
import '../models/classroom_models.dart';

/// Class membership is verified by the API; the public catalog stays separate.
class LearnerClassroomsScreen extends StatefulWidget {
  const LearnerClassroomsScreen({super.key, this.gateway, this.onOpenCourse});
  final LearnerClassroomGateway? gateway;
  final void Function(Cartilha course, String ownerId)? onOpenCourse;

  @override
  State<LearnerClassroomsScreen> createState() =>
      _LearnerClassroomsScreenState();
}

class _LearnerClassroomsScreenState extends State<LearnerClassroomsScreen> {
  late final LearnerClassroomGateway _gateway;
  List<ClassroomDetails> _classes = const [];
  String? _ownerId;
  String? _error;
  bool _loading = true;
  String? _opening;

  @override
  void initState() {
    super.initState();
    _gateway =
        widget.gateway ??
        ClassroomRepository(
          apiUrl: AppConfig.tutorApiUrl,
          authRepository: context.read<AuthRepository>(),
        );
    _load();
  }

  @override
  void dispose() {
    if (widget.gateway == null && _gateway is ClassroomRepository) {
      _gateway.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _gateway.currentUser();
      final classes = await _gateway.learnerClassrooms();
      if (!mounted) return;
      setState(() {
        _ownerId = user.id;
        _classes = classes;
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

  Future<void> _open(ClassroomDetails classroom) async {
    if (_opening != null || _ownerId == null) return;
    setState(() {
      _opening = classroom.id;
      _error = null;
    });
    try {
      final course = await _gateway.course(classroom.id);
      if (!mounted) return;
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
            ],
          ),
  );
}
