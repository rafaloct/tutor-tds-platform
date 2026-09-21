import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../models/cartilha.dart';
import '../widgets/linkify_text.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_wait_experience.dart';
import 'genui_assistant_screen.dart';
import '../features/certificates/presentation/certificate_requests_screen.dart';
import '../features/profile/data/profile_data_store.dart';
import '../features/study_progress/study_progress_repository.dart';
import '../features/learning_events/learning_event.dart';
import '../features/learning_events/learning_event_queue.dart';
import '../features/learning_events/learning_event_sync_service.dart';
import '../features/learning_events/learning_activity_tracker.dart';
import '../features/analytics/telemetry_route.dart';

class ChatExperienceScreen extends StatefulWidget {
  final Cartilha cartilha;
  final ProfileDataStore? profileDataStore;
  final String? progressOwnerId;
  final bool savedClassroomContent;
  const ChatExperienceScreen({
    super.key,
    required this.cartilha,
    this.profileDataStore,
    this.progressOwnerId,
    this.savedClassroomContent = false,
  });

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
      .where((m) => m.isAssessmentQuestion)
      .length;

  bool get _questionsComplete => _questionsAnswered >= _totalQuestions;

  double get _progress {
    if (_isCompleted) return 1.0;
    final sections = widget.cartilha.sections;
    final totalMessages = sections.fold<int>(
      0,
      (total, section) => total + section.messages.length,
    );
    if (totalMessages == 0) return 0;
    final advancedMessages =
        sections
            .take(_currentSectionIndex)
            .fold<int>(0, (total, section) => total + section.messages.length) +
        _currentMessageIndex;
    // The current message is still being read. Only advancing past it counts;
    // reaching the final message must not announce completion prematurely.
    return advancedMessages / totalMessages;
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
  }

  Future<void> _enqueueAndSync(LearningEvent event) async {
    final syncService = context.read<LearningEventSyncService>();
    await _eventQueue.enqueue(
      event.withCourseContext(
        courseVersionId: widget.cartilha.courseVersionId,
        classId: widget.cartilha.classId,
      ),
    );
    await syncService.flush();
  }

  void _recordInteraction() {
    final event = _activityTracker.recordInteraction();
    if (event != null) unawaited(_enqueueAndSync(event));
  }

  Future<void> _initializeExperience() async {
    final saved = await _progressRepository.load(
      widget.cartilha.id,
      courseVersionId: widget.cartilha.courseVersionId,
      ownerId: widget.progressOwnerId,
      allowLegacy: widget.cartilha.legacyProgressCompatible,
    );
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
    content: _questionsComplete
        ? '🎉 Parabéns! Você concluiu o conteúdo da cartilha. '
              'Você pode solicitar a análise do certificado. A equipe confere a matrícula, a edição cursada e a carga horária antes de aprovar.'
        : '✅ Você chegou ao fim do conteúdo! Ainda há perguntas para revisar. '
              'Você pode consultar os critérios e solicitar a análise do certificado; a equipe verificará sua aprendizagem e carga horária.',
  );

  void _saveProgress() {
    final snapshot = StudyProgress(
      courseId: widget.cartilha.id,
      courseVersionId: widget.cartilha.courseVersionId,
      ownerId: widget.progressOwnerId,
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
    if (!_showOptions) return;
    final currentMsg = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex];
    _recordInteraction();
    setState(() {
      _showOptions = false;
      if (currentMsg.isAssessmentQuestion) _questionsAnswered++;
      _visibleMessages.add(Message(type: 'user', content: option.label));
    });
    _scrollToBottom();

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

  Future<void> _requestCertificate() async {
    await Navigator.push(
      context,
      trackedRoute(
        pageId: 'certificate_requests',
        courseId: widget.cartilha.id,
        featureId: 'certificate_request',
        builder: (_) => CertificateRequestsScreen(
          courseId: widget.cartilha.id,
          courseVersionId: widget.cartilha.courseVersionId,
          classId: widget.cartilha.classId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cartilha.title,
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Perguntar ao Tutor de IA',
            icon: const Icon(Icons.psychology),
            onPressed: () => Navigator.push(
              context,
              trackedRoute(
                pageId: 'ai_assistant',
                courseId: widget.cartilha.id,
                resourceId: 'ai_chat',
                featureId: 'ai_tutor',
                builder: (_) => GenUIAssistantScreen(
                  initialContext: widget.cartilha.title,
                  contextLabel: widget.cartilha.title,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isInitializing
          ? const TdsWaitExperience(
              title: 'Retomando seu estudo',
              status: 'Localizando seu último ponto nesta cartilha...',
              localTip: 'Seu progresso fica salvo neste aparelho.',
            )
          : Column(
              children: [
                if (widget.savedClassroomContent)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Conteúdo salvo da sua turma. Seu progresso será enviado quando a conexão voltar.',
                    ),
                  ),
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
      floatingActionButton: _isCompleted
          ? FloatingActionButton.extended(
              heroTag: 'cert',
              icon: const Icon(Icons.workspace_premium, color: Colors.amber),
              label: const Text(
                'Solicitar certificado',
                style: TextStyle(fontSize: 13),
              ),
              backgroundColor: const Color(0xFF093AF4),
              onPressed: _requestCertificate,
            )
          : null,
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
