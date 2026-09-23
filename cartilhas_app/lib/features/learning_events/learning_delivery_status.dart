import 'package:flutter/material.dart';

import 'learning_delivery_controller.dart';

/// Stitch 9d6e0e93f2c448058d3f4afac70a7c4a, with honest error states in the
/// same compact component. Counts describe this cohort's committed evidence.
class LearningDeliveryStatus extends StatelessWidget {
  const LearningDeliveryStatus({super.key, required this.controller});
  final LearningDeliveryController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.snapshot;
      final unsaved = controller.hasUnsavedEvent;
      final issue = controller.issue;
      if (!unsaved && issue == null && state?.isEmpty == true) {
        return const SizedBox.shrink();
      }
      final pending = (state?.pendingCount ?? 0) + (state?.retryCount ?? 0);
      final blocked = state?.blockedCount ?? 0;
      final pendingLabel = pending == 1
          ? '1 registro do estudo aguardando envio'
          : '$pending registros do estudo aguardando envio';
      final blockedLabel = blocked == 1
          ? '1 envio preservado'
          : '$blocked envios preservados';
      final isError = unsaved || issue != null || blocked > 0;
      late final String title;
      late final String body;
      String? action;
      VoidCallback? command;
      var statusKey = 'learning-delivery-pending';
      if (unsaved) {
        statusKey = 'learning-delivery-storage-error';
        title = controller.saving
            ? 'Salvando atividade...'
            : 'Atividade ainda não salva';
        body =
            'Mantenha esta tela aberta. Novas atividades estão pausadas até salvar.';
        action = 'Tentar salvar novamente';
        command = () {
          controller.retrySave();
        };
      } else if (issue != null) {
        statusKey = 'learning-delivery-error';
        title = issue == LearningDeliveryIssue.access
            ? 'Seu acesso precisa ser atualizado'
            : 'Não foi possível conferir os envios';
        body = issue == LearningDeliveryIssue.access
            ? 'Entre na conta desta turma e confira seu acesso. As atividades salvas foram preservadas.'
            : 'Não podemos confirmar o armazenamento agora. Os registros existentes não foram apagados.';
        action = 'Verificar novamente';
        command = () {
          if (issue == LearningDeliveryIssue.access) {
            controller.synchronize();
          } else {
            controller.refresh();
          }
        };
      } else if (controller.loading || state == null) {
        statusKey = 'learning-delivery-loading';
        title = 'Conferindo atividades salvas';
        body = 'Verificando os envios desta turma...';
      } else if (blocked > 0) {
        statusKey = 'learning-delivery-blocked';
        title = 'Há envios que precisam de revisão';
        body =
            '$blockedLabel. Depois de corrigir a causa com a equipe, tente novamente.';
        action = 'Tentar os mesmos envios';
        command = () {
          controller.synchronize(retryBlocked: true);
        };
      } else {
        title = 'Atividades salvas neste aparelho';
        body = !controller.consent
            ? '$pendingLabel. O acompanhamento está pausado pela sua escolha de privacidade.'
            : state.requiresAccessRefresh
            ? '$pendingLabel. Confira seu acesso à turma para continuar.'
            : '$pendingLabel. O progresso confirmado será atualizado após a sincronização.';
        if (controller.consent) {
          action = state.requiresAccessRefresh
              ? 'Verificar acesso'
              : 'Tentar sincronizar';
          command = () {
            controller.synchronize();
          };
        }
      }
      final colors = Theme.of(context).colorScheme;
      return Semantics(
        liveRegion: true,
        child: Container(
          key: ValueKey(statusKey),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isError ? colors.errorContainer : const Color(0xFFFFFBEB),
            border: Border.all(
              color: isError ? colors.error : const Color(0xFFFCD34D),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.cloud_off_outlined,
                    size: 20,
                    color: isError
                        ? colors.onErrorContainer
                        : const Color(0xFF92400E),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isError
                          ? colors.onErrorContainer
                          : const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isError
                      ? colors.onErrorContainer
                      : const Color(0xFF78350F),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('learning-delivery-retry'),
                  onPressed: controller.busy ? null : command,
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(controller.busy ? 'Verificando...' : action),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
