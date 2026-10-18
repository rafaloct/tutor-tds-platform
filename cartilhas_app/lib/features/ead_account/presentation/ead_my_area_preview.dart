import 'package:flutter/material.dart';

/// Pure presentation states. No WordPress token, HTTP or academic writes.
enum EadLinkState { disconnected, linking, linked, loginRequired }

enum EadSnapshotState { unknown, loading, current, stale, offline, error }

enum EadEnrollmentState { enrolled, completed }

/// Only the authenticated LearnPress source may supply these values.
/// Null progress is UNKNOWN, not zero.
class EadAreaCourse {
  const EadAreaCourse({
    required this.wpCourseId,
    required this.title,
    required this.enrollment,
    this.progressPercent,
    this.nextLesson,
    this.resumeAuthorized = false,
  });

  final int wpCourseId;
  final String title;
  final EadEnrollmentState enrollment;
  final int? progressPercent;
  final String? nextLesson;
  final bool resumeAuthorized;
}

/// The caller, not this widget, must verify source and session provenance.
class EadMyAreaModel {
  const EadMyAreaModel({
    required this.linkState,
    required this.snapshotState,
    required this.environmentId,
    required this.snapshotEnvironmentId,
    this.authenticatedSourceVerified = false,
    this.viewerWpUserId,
    this.snapshotWpUserId,
    this.courses = const [],
  });

  final EadLinkState linkState;
  final EadSnapshotState snapshotState;
  final String environmentId;
  final String? snapshotEnvironmentId;

  /// Must come from a verified LearnPress broker, never public course data.
  final bool authenticatedSourceVerified;
  final int? viewerWpUserId;
  final int? snapshotWpUserId;
  final List<EadAreaCourse> courses;

  bool get hasVerifiedScope =>
      authenticatedSourceVerified &&
      linkState == EadLinkState.linked &&
      viewerWpUserId != null &&
      viewerWpUserId! > 0 &&
      viewerWpUserId == snapshotWpUserId &&
      environmentId.isNotEmpty &&
      environmentId == snapshotEnvironmentId;

  bool get canShowPrivate =>
      hasVerifiedScope &&
      (snapshotState == EadSnapshotState.current ||
          snapshotState == EadSnapshotState.stale ||
          snapshotState == EadSnapshotState.offline);

  bool get canResume =>
      hasVerifiedScope && snapshotState == EadSnapshotState.current;
}

/// Standalone Flutter preview. Not connected to Home or any auth broker.
/// All actions require injected callbacks and never run on build.
class EadMyAreaPreview extends StatelessWidget {
  const EadMyAreaPreview({
    super.key,
    required this.model,
    this.onLinkEad,
    this.onReauthenticate,
    this.onRetry,
    this.onResumeCourse,
    this.onPublicCatalog,
    this.onTdsParticipation,
    this.onTdsCertificates,
    this.onSupport,
  });

  final EadMyAreaModel model;
  final VoidCallback? onLinkEad;
  final VoidCallback? onReauthenticate;
  final VoidCallback? onRetry;
  final ValueChanged<int>? onResumeCourse;
  final VoidCallback? onPublicCatalog;
  final VoidCallback? onTdsParticipation;
  final VoidCallback? onTdsCertificates;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minha área')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          key: const ValueKey('ead-my-area-content'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            Text(
              'Sua jornada de aprendizagem',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cursos EAD, participação no TDS e certificados '
              'possuem origens e regras próprias.',
            ),
            const SizedBox(height: 16),
            _accountCard(),
            const SizedBox(height: 12),
            _coursesCard(context),
            const SizedBox(height: 12),
            _panel(
              icon: Icons.groups_outlined,
              title: 'Minha participação no TDS',
              source: 'Fonte: Tutor TDS / FastAPI institucional',
              description:
                  'Turmas e frequência são independentes '
                  'das inscrições nos cursos LearnPress.',
              actionText: 'Consultar participação',
              onAction: onTdsParticipation,
            ),
            const SizedBox(height: 12),
            _panel(
              icon: Icons.workspace_premium_outlined,
              title: 'Meus certificados oficiais',
              source: 'Fonte: Tutor TDS / emissão institucional',
              description:
                  'Concluir lições ou quizzes no EAD não emite '
                  'certificado oficial do Programa TDS. '
                  'Aprovação e assinatura seguem o fluxo institucional.',
              actionText: 'Consultar certificados TDS',
              onAction: onTdsCertificates,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Precisa de ajuda?'),
                subtitle: const Text('Atendimento Tutor TDS'),
                onTap: onSupport,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _panel({
    required IconData icon,
    required String title,
    required String source,
    required String description,
    required String actionText,
    required VoidCallback? onAction,
    bool hasAction = true,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(icon, title),
          const SizedBox(height: 8),
          Text(source),
          const SizedBox(height: 8),
          Text(description),
          if (hasAction) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionText)),
          ],
        ],
      ),
    ),
  );

  Widget _accountCard() {
    final String title;
    final String message;
    final String actionText;
    final VoidCallback? action;
    bool hasAction = true;
    switch (model.linkState) {
      case EadLinkState.disconnected:
        title = 'Conta EAD ainda não vinculada';
        message =
            'Conecte sua conta LearnPress para consultar '
            'inscrições e progresso. A conta TDS é independente.';
        actionText = 'Vincular conta EAD';
        action = onLinkEad;
      case EadLinkState.linking:
        title = 'Vinculação EAD em andamento';
        message =
            'Aguardando comprovação das duas contas. '
            'Nenhuma matrícula foi importada.';
        actionText = '';
        action = null;
        hasAction = false;
      case EadLinkState.loginRequired:
        title = 'Sessão EAD precisa de novo acesso';
        message =
            'Seu login institucional TDS não autentica '
            'automaticamente o LearnPress.';
        actionText = 'Entrar novamente no EAD';
        action = onReauthenticate;
      case EadLinkState.linked:
        title = model.hasVerifiedScope
            ? 'Conta EAD vinculada'
            : 'Confirme sua conta EAD novamente';
        message = model.hasVerifiedScope
            ? 'As inscrições exibidas vêm da autoridade LearnPress.'
            : 'A identidade da consulta não corresponde a esta sessão.';
        actionText = 'Entrar novamente no EAD';
        action = model.hasVerifiedScope ? null : onReauthenticate;
        hasAction = !model.hasVerifiedScope;
    }
    return _panel(
      icon: Icons.verified_user_outlined,
      title: title,
      source: 'Fonte: WordPress / LearnPress',
      description: message,
      actionText: actionText,
      onAction: action,
      hasAction: hasAction,
    );
  }

  Widget _coursesCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.school_outlined, 'Meus cursos no EAD'),
          const SizedBox(height: 8),
          const Text('Fonte: LearnPress, inscrição na oferta EAD.'),
          const SizedBox(height: 8),
          if (!model.hasVerifiedScope)
            const Text(
              'Vincule sua conta para consultar inscrições. '
              'O catálogo público não demonstra matrícula.',
            )
          else ...[
            _statusMessage(),
            if (model.canShowPrivate) ...[
              if (model.courses.isEmpty)
                const Text('Nenhuma inscrição EAD confirmada nesta consulta.')
              else
                ...model.courses
                    .where((c) => c.wpCourseId > 0 && c.title.trim().isNotEmpty)
                    .map((c) => _courseCard(context, c)),
            ],
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPublicCatalog,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Explorar cursos públicos'),
          ),
        ],
      ),
    ),
  );

  Widget _statusMessage() {
    switch (model.snapshotState) {
      case EadSnapshotState.unknown:
        return const Text(
          'Inscrições não consultadas. '
          'Isso não significa que você não esteja matriculado.',
        );
      case EadSnapshotState.loading:
        return const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Consultando inscrições no EAD...')),
          ],
        );
      case EadSnapshotState.current:
        return const Text('Dados consultados na conta LearnPress.');
      case EadSnapshotState.stale:
        return const Text(
          'Consulta anterior, possivelmente desatualizada. '
          'Atualize antes de continuar aulas.',
        );
      case EadSnapshotState.offline:
        return const Text(
          'Sem conexão. Dados de uma consulta anterior. '
          'Nenhuma atividade será concluída offline.',
        );
      case EadSnapshotState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Não foi possível consultar suas inscrições. '
              'Nenhum progresso foi alterado.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('ead-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        );
    }
  }

  Widget _courseCard(BuildContext context, EadAreaCourse course) {
    final percent = course.progressPercent;
    final known = percent != null && percent >= 0 && percent <= 100;
    final canResume =
        model.canResume &&
        course.enrollment == EadEnrollmentState.enrolled &&
        course.resumeAuthorized &&
        course.nextLesson != null &&
        course.nextLesson!.trim().isNotEmpty &&
        onResumeCourse != null;
    return Padding(
      key: ValueKey('ead-course-${course.wpCourseId}'),
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                course.enrollment == EadEnrollmentState.completed
                    ? 'Curso concluído no EAD'
                    : 'Inscrição no EAD confirmada',
              ),
              const SizedBox(height: 8),
              if (known) ...[
                Text('Progresso no LearnPress: $percent%'),
                const SizedBox(height: 6),
                Semantics(
                  label: 'Progresso LearnPress: $percent por cento',
                  child: LinearProgressIndicator(value: percent / 100),
                ),
              ] else
                const Text('Progresso EAD ainda não disponível.'),
              if (course.nextLesson != null) ...[
                const SizedBox(height: 8),
                Text('Próxima aula: ${course.nextLesson}'),
              ],
              if (course.enrollment == EadEnrollmentState.enrolled) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: ValueKey('ead-resume-${course.wpCourseId}'),
                  onPressed: canResume
                      ? () => onResumeCourse?.call(course.wpCourseId)
                      : null,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Continuar aula no EAD'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 23),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
    ],
  );
}
