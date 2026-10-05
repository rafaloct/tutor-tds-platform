import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tutor_learning_context.dart';
import '../services/anything_llm_service.dart';
import '../widgets/linkify_text.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_wait_experience.dart';
import '../widgets/tutor_conversation_starter.dart';
import '../widgets/tutor_response_card.dart';
import 'guide_screen.dart';
import '../features/analytics/app_telemetry_service.dart';
import '../features/analytics/telemetry_route.dart';
import '../features/study_ai/presentation/assessment_screen.dart';
import '../features/study_ai/presentation/flashcards_screen.dart';
import '../models/chat_message.dart';
import '../genui/genui_renderer.dart';
import '../genui/atui_parser.dart';

class GenUIAssistantScreen extends StatefulWidget {
  final String initialContext;
  final String? contextLabel;
  final TutorLearningContext? learningContext;

  /// A content-authored suggestion only; it is never sent automatically.
  final String? starterPrompt;

  const GenUIAssistantScreen({
    super.key,
    this.initialContext = '',
    this.contextLabel,
    this.learningContext,
    this.starterPrompt,
  });

  @override
  State<GenUIAssistantScreen> createState() => _GenUIAssistantScreenState();
}

class _GenUIAssistantScreenState extends State<GenUIAssistantScreen> {
  static Future<void> _speechOperationQueue = Future<void>.value();

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  // 'Tutor' = explicação geral | 'Minha Realidade' = mapeia contexto do aluno e adapta o que é viável
  String _chatMode = 'Tutor';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _addInitialMessage();
    final starter = widget.starterPrompt?.trim();
    if (starter != null && starter.isNotEmpty) _controller.text = starter;
  }

  @override
  void dispose() {
    _tts.stop();
    final speechToStop = _speech;
    _speechOperationQueue = _speechOperationQueue.then((_) async {
      await speechToStop.stop();
    });
    _controller.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _initSpeech() async {
    final operation = _speechOperationQueue.then((_) async {
      if (!mounted) return;
      try {
        final available = await _speech.initialize(
          onError: (e) {
            if (mounted) setState(() => _isListening = false);
            _showSnack('Microfone: ${e.errorMsg}');
          },
          onStatus: (status) {
            // 'done' ou 'notListening' sinaliza fim da escuta
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
        );
        if (mounted) setState(() => _speechAvailable = available);
      } on Exception {
        if (mounted) setState(() => _speechAvailable = false);
      }
    });
    _speechOperationQueue = operation;
    await operation;
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('microphone_notice_seen_v1') ?? false)) {
      if (!mounted) return;
      final understood = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usar o microfone'),
          content: const Text(
            'O microfone é usado somente enquanto você dita uma pergunta ao Tutor. '
            'O texto reconhecido aparece no campo antes de ser enviado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (understood != true) return;
      await prefs.setBool('microphone_notice_seen_v1', true);
    }

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showSnack('Permissão de microfone negada. Ative nas configurações.');
      return;
    }
    if (!_speechAvailable) {
      _showSnack('Reconhecimento de voz não disponível neste dispositivo.');
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          if (result.finalResult) _isListening = false;
        });
      },
      listenOptions: SpeechListenOptions(
        localeId: 'pt_BR',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _trackTutorFeedback(TutorResponseFeedback feedback) {
    final telemetry = Provider.of<AppTelemetryService?>(context, listen: false);
    final id = switch (feedback) {
      TutorResponseFeedback.useful => 'useful',
      TutorResponseFeedback.notUseful => 'not_useful',
      TutorResponseFeedback.report => 'report',
    };
    telemetry?.trackFeature(featureId: 'tutor_feedback_$id');
    _showSnack(
      feedback == TutorResponseFeedback.report
          ? 'Problema registrado para análise.'
          : 'Obrigado pelo feedback.',
    );
  }

  String get _studyTopic {
    final label = widget.contextLabel?.trim();
    return label != null && label.isNotEmpty
        ? label
        : 'Conteúdo das cartilhas TDS';
  }

  void _openCards() {
    Navigator.push(
      context,
      trackedRoute(
        pageId: 'flashcards',
        featureId: 'flashcards',
        builder: (_) => FlashcardsScreen(topic: _studyTopic),
      ),
    );
  }

  void _openQuiz() {
    Navigator.push(
      context,
      trackedRoute(
        pageId: 'assessment',
        featureId: 'quiz',
        builder: (_) => AssessmentScreen(
          topic: _studyTopic,
          courseId: _studyTopic,
          mode: AssessmentMode.quiz,
        ),
      ),
    );
  }

  void _focusComposer() {
    _inputFocus.requestFocus();
  }

  Future<void> _launchUrlWithConfirmation(String url) async {
    final uri = Uri.parse(url);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar redirecionamento'),
        content: Text('Você deseja abrir este link externo?\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _addInitialMessage() {
    final label = widget.contextLabel?.trim();
    _messages.add(
      ChatMessage(
        role: 'bot',
        text: label != null && label.isNotEmpty
            ? 'Estou com você em "$label". Escolha uma sugestão ou escreva sua dúvida.'
            : 'Olá! Sou seu tutor das cartilhas TDS. Escolha uma sugestão ou escreva sua dúvida.',
      ),
    );
  }

  void _sendMessage([String? message, bool hidden = false]) async {
    final text = message ?? _controller.text.trim();
    if (text.isEmpty || !mounted || _isLoading) return;

    final telemetry = Provider.of<AppTelemetryService?>(context, listen: false);
    if (telemetry?.journeyEnabled == true) {
      telemetry?.trackFeature(featureId: 'tutor_help_requested');
    }

    setState(() {
      if (!hidden) _messages.add(ChatMessage(role: 'user', text: text));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    final service = context.read<AnythingLLMService>();
    final response = await service.getChatResponse(
      text,
      mode: _chatMode == 'Minha Realidade' ? 'adaptive' : 'tutor',
      context: widget.learningContext == null ? widget.initialContext : null,
      learningContext: widget.learningContext,
    );
    _processResponse(response);
  }

  void _processResponse(String response) {
    if (!mounted) return;
    try {
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final Map<String, dynamic> data = jsonDecode(
          response.substring(jsonStart, jsonEnd + 1),
        );
        final List<Map<String, dynamic>> uiMaps = data['ui'] != null
            ? List<Map<String, dynamic>>.from(data['ui'])
            : [];
        final components = uiMaps.map(ATUIParser.parse).toList();
        if (!mounted) return;
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'bot',
              text: data['text'],
              components: components,
            ),
          );
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(role: 'bot', text: response));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'bot', text: response));
        _isLoading = false;
      });
    }
    _scrollToBottom();
    // TTS não dispara automaticamente — usuário decide ouvir tocando no ícone da bolha
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleMode() {
    final next = _chatMode == 'Tutor' ? 'Minha Realidade' : 'Tutor';
    setState(() {
      _chatMode = next;
      if (next == 'Minha Realidade') {
        _messages.add(
          ChatMessage(
            role: 'bot',
            text:
                'Vou te ajudar a ver o que se aplica pra você de verdade. '
                'Me conta um pouco da sua situação: você tem terra própria ou trabalha na terra de alguém? '
                'E atualmente tem alguma renda, mesmo que pequena?',
          ),
        );
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdaptiveMode = _chatMode == 'Minha Realidade';
    final contextLabel = widget.contextLabel?.trim();
    final hasContext = contextLabel != null && contextLabel.isNotEmpty;
    final showStarter = _messages.length == 1 && !_isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logos/logo_tds.png', height: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tutor TDS'),
                  if (hasContext)
                    Text(
                      contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleMode,
              child: Tooltip(
                message: isAdaptiveMode
                    ? 'Modo: tutor adapta ao que é viável pra você\nToque para voltar ao modo geral'
                    : 'Toque para ativar o modo personalizado',
                child: Chip(
                  avatar: Icon(
                    isAdaptiveMode ? Icons.person_pin : Icons.school,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: Text(
                    isAdaptiveMode ? 'Minha Realidade' : 'Geral',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: isAdaptiveMode
                      ? Colors.deepPurple
                      : Colors.green,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveBody(
              maxWidth: 860,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (showStarter ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return TutorConversationStarter(
                      contextLabel: contextLabel,
                      onSelected: _sendMessage,
                    );
                  }
                  return _buildMessageBubble(
                    _messages[index],
                    isGreeting: index == 0,
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            const TdsWaitExperience(
              title: 'Tutor preparando a resposta',
              status: 'Consultando o contexto da sua trilha...',
              localTip:
                  'Enquanto isso, pense em um exemplo da sua realidade para comparar com a explicação.',
              compact: true,
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, {bool isGreeting = false}) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser && msg.text != null) LinkifyText(msg.text!),
            if (!isUser && isGreeting && msg.text != null)
              LinkifyText(msg.text!),
            if (!isUser && !isGreeting && msg.text != null)
              TutorResponseCard(
                text: msg.text!,
                contextLabel: widget.contextLabel,
                onListen: () => _speak(msg.text!),
                onCreateCards: _openCards,
                onPracticeQuiz: _openQuiz,
                onContinue: _focusComposer,
                onFollowUp: _sendMessage,
                onFeedback: _trackTutorFeedback,
                child: msg.components == null
                    ? null
                    : GenUIRenderer(
                        components: msg.components!,
                        onAction: _launchUrlWithConfirmation,
                        onError: (error) => _sendMessage(
                          'Erro ao renderizar: $error. Corrija o JSON.',
                          true,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    final contextLabel = widget.contextLabel?.trim();
    final hintText = _isListening
        ? 'Estou ouvindo...'
        : _chatMode == 'Minha Realidade'
        ? 'Conte sua situação ou faça uma pergunta...'
        : contextLabel != null && contextLabel.isNotEmpty
        ? 'Pergunte sobre $contextLabel...'
        : 'Pergunte sobre uma cartilha...';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _inputFocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _MicButton(
            isListening: _isListening,
            available: _speechAvailable,
            onStart: _startListening,
            onStop: _stopListening,
          ),
          HumanHelpButton(
            duvida: _controller.text.isNotEmpty ? _controller.text : null,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: 'Enviar pergunta',
            onPressed: _isLoading ? null : () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isListening;
  final bool available;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _MicButton({
    required this.isListening,
    required this.available,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!available) {
      return const Tooltip(
        message: 'Microfone indisponível',
        child: Icon(Icons.mic_off, color: Colors.grey),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isListening
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: IconButton(
        icon: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: isListening ? Colors.red : Colors.green,
        ),
        tooltip: isListening ? 'Parar gravação' : 'Falar',
        onPressed: isListening ? onStop : onStart,
      ),
    );
  }
}
