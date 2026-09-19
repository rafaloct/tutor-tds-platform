import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/anything_llm_service.dart';
import '../widgets/linkify_text.dart';
import '../widgets/responsive_body.dart';
import 'guide_screen.dart';
import '../models/chat_message.dart';
import '../genui/genui_renderer.dart';
import '../genui/atui_parser.dart';

class GenUIAssistantScreen extends StatefulWidget {
  final String initialContext;

  const GenUIAssistantScreen({super.key, this.initialContext = ''});

  @override
  State<GenUIAssistantScreen> createState() => _GenUIAssistantScreenState();
}

class _GenUIAssistantScreenState extends State<GenUIAssistantScreen> {
  static Future<void> _speechOperationQueue = Future<void>.value();

  final TextEditingController _controller = TextEditingController();
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
  }

  @override
  void dispose() {
    _tts.stop();
    final speechToStop = _speech;
    _speechOperationQueue = _speechOperationQueue.then((_) async {
      await speechToStop.stop();
    });
    _controller.dispose();
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
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'bot',
          text: 'Olá! Sou seu tutor de IA. Como posso te ajudar hoje?',
        ),
      );
    });
    if (widget.initialContext.isNotEmpty) {
      Future.microtask(() => _sendMessage(widget.initialContext, true));
    }
  }

  void _sendMessage([String? message, bool hidden = false]) async {
    final text = message ?? _controller.text.trim();
    if (text.isEmpty || !mounted) return;

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
      context: widget.initialContext,
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logos/logo_tds.png', height: 28),
            const SizedBox(width: 8),
            const SizedBox(width: 8),
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
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildMessageBubble(_messages[index]),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Tutor pensando...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
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
            if (msg.text != null) LinkifyText(msg.text!),
            if (msg.components != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GenUIRenderer(
                  components: msg.components!,
                  onAction: _launchUrlWithConfirmation,
                  onError: (error) => _sendMessage(
                    'Erro ao renderizar: $error. Corrija o JSON.',
                    true,
                  ),
                ),
              ),
            if (!isUser && msg.text != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  tooltip: 'Ouvir resposta',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _speak(msg.text!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
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
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Fale ou digite...',
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
