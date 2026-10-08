import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../screens/chat_experience_screen.dart';
import '../../widgets/tds_wait_experience.dart';
import '../analytics/telemetry_route.dart';
import '../auth/data/auth_repository.dart';
import '../classrooms/data/classroom_repository.dart';
import '../classrooms/data/learner_offline_repository.dart';
import '../learning_events/learning_delivery_controller.dart';
import '../learning_events/learning_delivery_status.dart';
import '../learning_events/learning_event_queue.dart';
import '../learning_events/learning_event_sync_service.dart';
import '../learning_events/learning_outbox.dart';
import 'home_selection_repository.dart';
import 'learning_context_repository.dart';
import 'learning_home_controller.dart';

/// Stitch derivative 75ac62c1bb3241aba1b3092f908b7c5f; values come from context.
class LearningHomeCard extends StatefulWidget {
  const LearningHomeCard({super.key, this.controller});
  final LearningHomeController? controller;
  @override
  State<LearningHomeCard> createState() => _LearningHomeCardState();
}

class _LearningHomeCardState extends State<LearningHomeCard> {
  late final LearningHomeController _controller;
  ClassroomRepository? _remote;
  RemoteLearningContextRepository? _contexts;
  LearningDeliveryController? _delivery;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      final auth = context.read<AuthRepository>();
      _remote = ClassroomRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      _contexts = RemoteLearningContextRepository(
        apiUrl: AppConfig.tutorApiUrl,
        auth: auth,
      );
      _controller = LearningHomeController(
        gateway: LearnerOfflineRepository(
          remote: _remote!,
          auth: auth,
          apiUrl: AppConfig.tutorApiUrl,
          dynamicActivityEnabled: AppConfig.dynamicActivityEnabled,
        ),
        contexts: _contexts!,
        selection: LocalHomeSelectionRepository(AppConfig.tutorApiUrl),
      );
    }
    _controller.addListener(_bindDelivery);
    _controller.load();
  }

  void _deliveryChanged() {
    if (mounted) setState(() {});
  }

  void _bindDelivery() {
    if (!AppConfig.durableLearningOutboxEnabled ||
        _controller.state != LearningHomeState.ready) {
      return;
    }
    final learning = _controller.contextController.snapshot?.context;
    if (learning == null) return;
    final scope = LearningDeliveryScope(
      ownerId: learning.userId,
      apiUrl: AppConfig.tutorApiUrl,
      cohortId: learning.cohortId,
      courseId: learning.courseId,
      courseVersionId: learning.courseVersionId,
    );
    if (_delivery?.scope == scope) {
      unawaited(_delivery!.refresh());
      return;
    }
    // Never silently discard an uncommitted event when the context changes.
    if (_delivery?.hasUnsavedEvent == true) return;
    _delivery?.removeListener(_deliveryChanged);
    _delivery?.dispose();
    _delivery = LearningDeliveryController(
      scope: scope,
      queue: const LearningEventQueue(),
      sync: context.read<LearningEventSyncService>(),
      auth: context.read<AuthRepository>(),
      revalidateAccess: () async {
        final resolved = await _controller.contextController.load(
          scope.cohortId,
        );
        final current = resolved?.context;
        return current != null &&
            current.userId == scope.ownerId &&
            current.cohortId == scope.cohortId &&
            current.courseId == scope.courseId &&
            current.courseVersionId == scope.courseVersionId &&
            current.permissions.contains('activity.record');
      },
      onDelivered: () async {
        await _controller.contextController.load(scope.cohortId);
      },
    )..addListener(_deliveryChanged);
    unawaited(_delivery!.refresh());
  }

  @override
  void dispose() {
    _controller.removeListener(_bindDelivery);
    _delivery?.removeListener(_deliveryChanged);
    _delivery?.dispose();
    if (widget.controller == null) _controller.dispose();
    _remote?.dispose();
    _contexts?.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_delivery?.canRecord == false) return;
    final cohort = _controller.classroom?.id;
    if (cohort == null || _controller.state != LearningHomeState.ready) return;
    await _controller.load(selectedCohort: cohort);
    if (!mounted || _controller.state != LearningHomeState.ready) return;
    final course = _controller.course!;
    await Navigator.of(context).push(
      trackedRoute(
        pageId: 'classroom_course',
        courseId: course.id,
        featureId: 'contextual_home_continue',
        builder: (_) => ChatExperienceScreen(
          cartilha: course,
          progressOwnerId: _controller.ownerId,
          savedClassroomContent:
              _controller.contextController.snapshot!.fromCache,
          learningContextController: _controller.contextController,
          deliveryController: _delivery,
        ),
      ),
    );
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.state == LearningHomeState.loading) {
        return const TdsWaitExperience(
          compact: true,
          title: 'Preparando sua aprendizagem',
          status: 'Conferindo sua turma e a edição do curso...',
          localTip:
              'Sua atividade é guardada no aparelho quando a conexão cai.',
        );
      }
      final colors = Theme.of(context).colorScheme;
      final snapshot = _controller.contextController.snapshot;
      final course = _controller.course;
      return Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Sua aprendizagem',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_controller.state == LearningHomeState.ready)
                    TextButton(
                      onPressed:
                          _delivery?.hasUnsavedEvent == true ||
                              _delivery?.saving == true
                          ? null
                          : _controller.chooseAnother,
                      child: const Text('Trocar turma'),
                    ),
                ],
              ),
              if (_controller.state == LearningHomeState.empty)
                const Text(
                  'Você ainda não tem uma turma disponível. Explore as cartilhas abaixo.',
                ),
              if (_controller.state == LearningHomeState.error) ...[
                const Text(
                  'Não foi possível confirmar sua turma e edição. Confira sua conexão ou procure a equipe.',
                ),
                OutlinedButton(
                  onPressed: () => _controller.load(),
                  child: const Text('Tentar novamente'),
                ),
              ],
              if (_controller.state == LearningHomeState.choose) ...[
                const Text('Escolha a turma em que você quer estudar.'),
                for (final classroom in _controller.classes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(classroom.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _controller.load(selectedCohort: classroom.id),
                  ),
              ],
              if (_controller.state == LearningHomeState.ready &&
                  snapshot != null &&
                  course != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_controller.classroom!.name}\n${course.title}${course.versionNumber == null ? '' : ' • Edição ${course.versionNumber}'}',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Progresso confirmado: ${snapshot.progressPercent.toStringAsFixed(0)}%',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: snapshot.progressPercent / 100,
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.fromCache ? 'Offline • ' : ''}Última sincronização: ${_date(snapshot.resolvedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_delivery case final delivery?)
                  LearningDeliveryStatus(controller: delivery),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _delivery?.canRecord == false ? null : _continue,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar estudo'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  String _date(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
