import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/cartilha.dart';
import '../widgets/linkify_text.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_wait_experience.dart';
import 'genui_assistant_screen.dart';
import '../services/data_sync_service.dart';
import '../services/privacy_preferences.dart';
import '../features/certificates/data/certificate_service.dart';
import '../features/certificates/models/certificate_record.dart';
import '../features/certificates/presentation/certificate_details_screen.dart';
import '../features/study_progress/study_progress_repository.dart';
import '../features/learning_events/learning_event.dart';
import '../features/learning_events/learning_event_queue.dart';
import '../features/learning_events/learning_event_sync_service.dart';
import '../features/learning_events/learning_activity_tracker.dart';
import 'cadunico_screen.dart';

class ChatExperienceScreen extends StatefulWidget {
  final Cartilha cartilha;
  const ChatExperienceScreen({super.key, required this.cartilha});

  @override
  State<ChatExperienceScreen> createState() => _ChatExperienceScreenState();
}

class _ChatExperienceScreenState extends State<ChatExperienceScreen>
    with WidgetsBindingObserver {
  final List<Message> _visibleMessages = [];
  int _currentSectionIndex = 0;
  int _currentMessageIndex = 0;
  bool _showOptions = false;
  bool _isCompleted = false;
  bool _isInitializing = true;
  CertificateRecord? _certificate;
  bool _issuingCertificate = false;
  int _questionsAnswered = 0;
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  static const _progressRepository = StudyProgressRepository();
  static const _eventQueue = LearningEventQueue();
  Future<void> _progressSaveQueue = Future<void>.value();
  final String _learningSessionId = LearningEvent.newSessionId();
  late final LearningActivityTracker _activityTracker;

  int get _totalQuestions => widget.cartilha.sections
      .expand((s) => s.messages)
      .where((m) => m.type == 'question')
      .length;

  bool get _earnedCertificate =>
      _questionsAnswered >= _totalQuestions && _totalQuestions > 0;

  double get _progress {
    if (_isCompleted) return 1.0;
    final totalSections = widget.cartilha.sections.length;
    return (_currentSectionIndex + 1) / totalSections;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.48);
    _activityTracker = LearningActivityTracker(
      courseId: widget.cartilha.id,
      sessionId: _learningSessionId,
    );
    DataSyncService.logEvent('STARTED', widget.cartilha.title);
    unawaited(
      _enqueueAndSync(
        LearningEvent.forSession(
          type: LearningEventType.lessonStarted,
          courseId: widget.cartilha.id,
          sessionId: _learningSessionId,
        ),
      ),
    );
    _initializeExperience();
    _loadExistingCertificate();
  }

  Future<void> _enqueueAndSync(LearningEvent event) async {
    final syncService = context.read<LearningEventSyncService>();
    await _eventQueue.enqueue(event);
    await syncService.flush();
  }

  void _recordInteraction() {
    final event = _activityTracker.recordInteraction();
    if (event != null) unawaited(_enqueueAndSync(event));
  }

  Future<void> _initializeExperience() async {
    final saved = await _progressRepository.load(widget.cartilha.id);
    if (!mounted) return;

    final sections = widget.cartilha.sections;
    var sectionIndex = saved?.sectionIndex ?? 0;
    if (sectionIndex < 0 || sectionIndex >= sections.length) sectionIndex = 0;
    var messageIndex = saved?.messageIndex ?? 0;
    if (messageIndex < 0 ||
        messageIndex >= sections[sectionIndex].messages.length) {
      messageIndex = 0;
    }
    final currentMessage = sections[sectionIndex].messages[messageIndex];
    final questionsAnswered = _bounded(
      saved?.questionsAnswered ?? 0,
      _totalQuestions,
    );

    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMessageIndex = messageIndex;
      _questionsAnswered = questionsAnswered;
      _isCompleted = saved?.isCompleted ?? false;
      _showOptions = saved?.showOptions ?? currentMessage.type != 'bot';
      if (_isCompleted) {
        _visibleMessages.add(_completionMessage());
      } else {
        if (saved != null) {
          _visibleMessages.add(
            Message(
              type: 'bot',
              content: 'Você retomou esta cartilha de onde parou.',
            ),
          );
        }
        _visibleMessages.add(currentMessage);
      }
      _isInitializing = false;
    });
    _saveProgress();
  }

  int _bounded(int value, int maximum) {
    if (value < 0) return 0;
    if (value > maximum) return maximum;
    return value;
  }

  Message _completionMessage() => Message(
    type: 'bot',
    content: _earnedCertificate
        ? '🎉 Parabéns! Você concluiu toda a cartilha e respondeu às perguntas. '
              'Quando quiser, emita seu certificado verificável pelo botão abaixo.'
        : '✅ Você chegou ao fim do conteúdo! Para solicitar o certificado, '
              'volte e responda ${_totalQuestions == 1 ? 'a questão' : 'as questões'} da cartilha.',
  );

  void _saveProgress() {
    final snapshot = StudyProgress(
      courseId: widget.cartilha.id,
      sectionIndex: _currentSectionIndex,
      messageIndex: _currentMessageIndex,
      questionsAnswered: _questionsAnswered,
      showOptions: _showOptions,
      isCompleted: _isCompleted,
      updatedAt: DateTime.now(),
    );
    _progressSaveQueue = _progressSaveQueue.then(
      (_) => _progressRepository.save(snapshot),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _activityTracker.reset();
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _displayNextMessage() {
    final section = widget.cartilha.sections[_currentSectionIndex];
    if (_currentMessageIndex < section.messages.length) {
      final msg = section.messages[_currentMessageIndex];
      setState(() {
        _visibleMessages.add(msg);
        _showOptions = (msg.type != 'bot');
      });
      _saveProgress();
      _scrollToBottom();
    }
  }

  void _advance() {
    _recordInteraction();
    final section = widget.cartilha.sections[_currentSectionIndex];
    if (_currentMessageIndex < section.messages.length - 1) {
      setState(() => _currentMessageIndex++);
      _displayNextMessage();
    } else if (_currentSectionIndex < widget.cartilha.sections.length - 1) {
      setState(() {
        _currentSectionIndex++;
        _currentMessageIndex = 0;
      });
      _displayNextMessage();
    } else {
      // Fim real do conteúdo — adiciona mensagem de conclusão no chat
      setState(() {
        _isCompleted = true;
        _showOptions = false;
        _visibleMessages.add(_completionMessage());
      });
      _saveProgress();
      unawaited(
        _enqueueAndSync(
          LearningEvent.forSession(
            type: LearningEventType.lessonCompleted,
            courseId: widget.cartilha.id,
            sessionId: _learningSessionId,
          ),
        ),
      );
      _scrollToBottom();
    }
  }

  void _handleOptionClick(Option option) {
    _recordInteraction();
    setState(() {
      _showOptions = false;
      _questionsAnswered++;
      _visibleMessages.add(Message(type: 'user', content: option.label));
    });
    _scrollToBottom();

    final currentMsg = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex];
    final feedback = option.feedback ?? currentMsg.explanation;

    if (feedback != null) {
      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _visibleMessages.add(Message(type: 'bot', content: feedback));
        });
        _saveProgress();
        _scrollToBottom();
      });
    } else {
      _saveProgress();
    }
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadExistingCertificate() async {
    final certificate = await context.read<CertificateService>().findByCourse(
      widget.cartilha.id,
    );
    if (mounted && certificate != null) {
      setState(() => _certificate = certificate);
    }
  }

  Future<void> _issueCertificate() async {
    final certificateService = context.read<CertificateService>();
    if (_certificate != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CertificateDetailsScreen(certificate: _certificate!),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString('user_name') ?? '').trim();
    final cpf = prefs.getString('user_cpf') ?? '';
    if (name.length < 2 || !CertificateService.isValidCpf(cpf)) {
      if (!mounted) return;
      final edit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete seu cadastro'),
          content: const Text(
            'Para emitir um certificado verificável, informe seu nome e um CPF válido. '
            'O CPF não aparecerá no certificado nem na página pública.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir cadastro'),
            ),
          ],
        ),
      );
      if (edit == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CadUnicoScreen()),
        );
      }
      return;
    }

    if (prefs.getBool('certificate_consent_v1') != true) {
      if (!mounted) return;
      final allowSharing = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emitir certificado verificável?'),
          content: const Text(
            'O app enviará por conexão segura seu nome, CPF e a conclusão desta cartilha. '
            'O servidor usa o CPF apenas para evitar duplicidade e armazena somente um código '
            'irreversível. A página pública e o PDF mostram nome, cartilha, data, ID e hash, '
            'mas nunca exibem o CPF.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Concordar e emitir'),
            ),
          ],
        ),
      );
      if (allowSharing != true) return;
      await prefs.setBool('certificate_consent_v1', true);
    }

    if (mounted) setState(() => _issuingCertificate = true);
    try {
      final certificate = await certificateService.issue(
        holderName: name,
        cpf: cpf,
        courseId: widget.cartilha.id,
        answeredQuestions: _questionsAnswered,
        totalQuestions: _totalQuestions,
      );
      if (!mounted) return;
      setState(() => _certificate = certificate);
      final hasAnalyticsConsent = await PrivacyPreferences.hasConsent();
      if (!mounted) return;
      if (hasAnalyticsConsent) {
        unawaited(DataSyncService.logEvent('COMPLETED', widget.cartilha.title));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Certificado emitido e salvo na sua carteira.'),
          backgroundColor: Color(0xFF093AF4),
          duration: Duration(seconds: 4),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CertificateDetailsScreen(certificate: certificate),
        ),
      );
    } on CertificateException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o certificado. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _issuingCertificate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cartilha.title,
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isInitializing
          ? const TdsWaitExperience(
              title: 'Retomando seu estudo',
              status: 'Localizando seu último ponto nesta cartilha...',
              localTip: 'Seu progresso fica salvo neste aparelho.',
            )
          : Column(
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF093AF4),
                  ),
                  minHeight: 4,
                ),
                Expanded(
                  child: ResponsiveBody(
                    maxWidth: 860,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _visibleMessages.length,
                      itemBuilder: (context, index) =>
                          _buildBubble(_visibleMessages[index]),
                    ),
                  ),
                ),
                if (!_isCompleted && _showOptions)
                  _buildOptions()
                else if (!_isCompleted)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: ElevatedButton(
                          onPressed: _advance,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Continuar'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      // FABs empilhados — tutor sempre visível, certificado aparece ao concluir
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isCompleted) ...[
            // Botão de certificado
            FloatingActionButton.extended(
              heroTag: 'cert',
              icon: _issuingCertificate
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : _certificate != null
                  ? const Icon(Icons.check_circle, color: Colors.white)
                  : Icon(
                      Icons.workspace_premium,
                      color: _earnedCertificate ? Colors.amber : Colors.white54,
                    ),
              label: Text(
                _issuingCertificate
                    ? 'Emitindo...'
                    : _certificate != null
                    ? 'Ver certificado'
                    : 'Emitir certificado',
                style: const TextStyle(fontSize: 13),
              ),
              backgroundColor: _earnedCertificate
                  ? const Color(0xFF093AF4)
                  : Colors.grey[600],
              onPressed: (_issuingCertificate || !_earnedCertificate)
                  ? null
                  : _issueCertificate,
            ),
            const SizedBox(height: 10),
          ],
          // Botão do tutor — sempre visível
          FloatingActionButton(
            heroTag: 'tutor',
            backgroundColor: const Color(0xFF093AF4),
            tooltip: 'Perguntar ao Tutor de IA',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GenUIAssistantScreen(
                  initialContext: widget.cartilha.title,
                  contextLabel: widget.cartilha.title,
                ),
              ),
            ),
            child: const Icon(Icons.psychology, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Message msg) {
    final isUser = msg.type == 'user';
    // Bolha especial de conclusão
    final isCompletion =
        _isCompleted &&
        _visibleMessages.isNotEmpty &&
        msg == _visibleMessages.last &&
        msg.type == 'bot';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCompletion
              ? Theme.of(context).colorScheme.primaryContainer
              : isUser
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
          ),
          border: isCompletion
              ? Border.all(
                  color: const Color(0xFF093AF4).withValues(alpha: 0.3),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LinkifyText(
              msg.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isCompletion
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : isUser
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isCompletion ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (!isUser)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  tooltip: 'Ouvir',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _speak(msg.content),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    final currentMsg = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex];
    if (currentMsg.options == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: currentMsg.options!.map((opt) {
          return ElevatedButton(
            onPressed: () => _handleOptionClick(opt),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(opt.label),
          );
        }).toList(),
      ),
    );
  }
}
