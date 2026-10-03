import 'dart:async';

import 'package:flutter/material.dart';

import 'support_controller.dart';
import 'support_models.dart';

class SupportDemoScreen extends StatefulWidget {
  const SupportDemoScreen({
    super.key,
    required this.controller,
    required this.session,
  });

  final SupportController controller;
  final SupportSession session;

  @override
  State<SupportDemoScreen> createState() => _SupportDemoScreenState();
}

class _SupportDemoScreenState extends State<SupportDemoScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    widget.controller.addListener(_onControllerChanged);
    unawaited(widget.controller.startSession(widget.session));
  }

  @override
  void didUpdateWidget(covariant SupportDemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.session.sessionId != widget.session.sessionId ||
        oldWidget.session.ownerId != widget.session.ownerId) {
      unawaited(widget.controller.startSession(widget.session));
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_messageController.text != widget.controller.message) {
      _messageController.value = TextEditingValue(
        text: widget.controller.message,
        selection: TextSelection.collapsed(
          offset: widget.controller.message.length,
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final session = controller.session ?? widget.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Central TDS')),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SafeArea(
          child: SingleChildScrollView(
            key: const Key('support-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _demoBanner(context),
                    const SizedBox(height: 16),
                    Text(
                      session.isVisitor
                          ? 'Ajuda de acesso para visitante'
                          : 'Como podemos orientar você?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    _identityNote(context, session),
                    const SizedBox(height: 20),
                    _topics(controller),
                    if (controller.topic != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.topic!.help,
                        key: const Key('support-topic-help'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _contextArea(context, controller, session),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('support-message'),
                      controller: _messageController,
                      minLines: 3,
                      maxLines: 6,
                      enabled: !controller.isSending,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem de rascunho',
                        hintText:
                            'Escreva somente o necessário para pedir ajuda.',
                        alignLabelWithHint: true,
                      ),
                      onChanged: controller.updateMessage,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'O rascunho existe somente nesta sessão de demonstração. '
                      'Troca de sessão ou logout descarta o conteúdo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    _statusArea(context, controller),
                    const SizedBox(height: 16),
                    _sendButton(controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoBanner(BuildContext context) {
    return Semantics(
      label:
          'DEMONSTRAÇÃO. Central local simulada, sem conexão com Chatwoot ou equipe.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'DEMONSTRAÇÃO • fluxo local e isolado. '
                  'Nenhuma mensagem sai deste aplicativo e nenhuma equipe recebe algo.',
                  key: Key('support-demo-banner'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityNote(BuildContext context, SupportSession session) {
    final privacy = session.optionalConsentGranted
        ? 'Dados opcionais continuam fora desta simulação.'
        : 'Consentimento opcional negado não bloqueia a ajuda básica.';
    return Text(
      session.isVisitor
          ? 'Você pode pedir ajuda sem CPF ou identidade acadêmica. $privacy'
          : 'Sessão fictícia: ${session.displayLabel}. $privacy',
      key: const Key('support-identity-note'),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _topics(SupportController controller) {
    return Semantics(
      container: true,
      label: 'Assunto do pedido de ajuda',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final topic in SupportTopic.values)
            ChoiceChip(
              key: Key('support-topic-${topic.name}'),
              label: Text(topic.label),
              selected: controller.topic == topic,
              onSelected: controller.isSending
                  ? null
                  : (_) => controller.selectTopic(topic),
            ),
        ],
      ),
    );
  }

  Widget _contextArea(
    BuildContext context,
    SupportController controller,
    SupportSession session,
  ) {
    final requiresContext = controller.topic?.requiresContext ?? false;
    if (session.contexts.isEmpty) {
      return Text(
        requiresContext
            ? 'Nenhum contexto acadêmico está disponível nesta sessão. '
                  'Use Ajuda com o aplicativo ou Ainda não sei para ajuda básica.'
            : 'Contexto acadêmico não é necessário para este assunto.',
        key: const Key('support-context-empty'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          requiresContext
              ? 'Escolha o contexto correto'
              : 'Contexto opcional e corrigível',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'support-context-dropdown-${controller.selectedContext?.id ?? 'none'}',
          ),
          initialValue: controller.selectedContext?.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Turma e curso'),
          hint: const Text('Nenhum contexto selecionado'),
          items: [
            for (final option in session.contexts)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.summary, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: controller.isSending ? null : controller.chooseContext,
        ),
        if (controller.selectedContext != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Remover contexto selecionado',
              child: TextButton.icon(
                key: const Key('support-clear-context'),
                onPressed: controller.isSending
                    ? null
                    : controller.clearContext,
                icon: const Icon(Icons.close),
                label: const Text('Remover contexto'),
              ),
            ),
          ),
        ],
        if (requiresContext && controller.selectedContext == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Com mais de uma turma, nenhuma é escolhida automaticamente.',
              key: Key('support-context-required'),
            ),
          ),
      ],
    );
  }

  Widget _statusArea(BuildContext context, SupportController controller) {
    if (controller.state == SupportViewState.loading) {
      return Semantics(
        liveRegion: true,
        child: const Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Carregando demonstração local...')),
          ],
        ),
      );
    }

    final message = controller.statusMessage;
    if (message == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      label: message,
      child: Card(
        key: const Key('support-status'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              if (controller.state == SupportViewState.error ||
                  controller.state == SupportViewState.unavailable) ...[
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Tentar novamente a simulação',
                  child: FilledButton.tonalIcon(
                    key: const Key('support-retry'),
                    onPressed: controller.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendButton(SupportController controller) {
    return Semantics(
      button: true,
      label: 'Simular envio da demonstração',
      child: FilledButton.icon(
        key: const Key('support-send'),
        onPressed: controller.canSend ? controller.send : null,
        icon: controller.isSending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: Text(controller.isSending ? 'Simulando...' : 'Simular envio'),
      ),
    );
  }
}
