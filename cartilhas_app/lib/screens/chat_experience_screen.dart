import 'dart:async';
import '../config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../models/cartilha.dart';
import '../features/remote_materials/module_materials_screen.dart';
import '../features/media/data/media_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../widgets/linkify_text.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_wait_experience.dart';
import 'genui_assistant_screen.dart';
import '../features/certificates/presentation/certificate_requests_screen.dart';
import '../features/profile/data/profile_data_store.dart';
import '../models/tutor_learning_context.dart';
import '../features/study_progress/study_progress_repository.dart';
import '../features/learning_events/learning_event.dart';
import '../features/learning_events/learning_event_queue.dart';
import '../features/learning_events/learning_event_sync_service.dart';
import '../features/learning_events/learning_activity_tracker.dart';
import '../features/analytics/telemetry_route.dart';
import '../features/learning_context/learning_context_controller.dart';
import '../features/learning_events/learning_delivery_controller.dart';
import '../features/learning_events/learning_delivery_status.dart';
import '../features/learning_events/learning_outbox.dart';
import '../features/study_ai/application/published_assessment_controller.dart';
import '../features/study_ai/data/assessment_attempt_repository.dart';
import '../features/study_ai/data/assessment_sync_service.dart';
import '../features/study_ai/models/assessment_sync_models.dart';
import '../features/study_ai/models/study_models.dart';

class ChatExperienceScreen extends StatefulWidget {
  final Cartilha cartilha;
  final ProfileDataStore? profileDataStore;
  final String? progressOwnerId;
  final bool savedClassroomContent;
  final LearningContextController? learningContextController;
  final LearningDeliveryController? deliveryController;
  final bool? dynamicActivityEnabled;
  final String? assessmentApiUrl;
  final PublishedAssessmentAttemptStore assessmentAttemptStore;
  final AssessmentSyncCoordinator? assessmentSyncCoordinator;
  const ChatExperienceScreen({
    super.key,
    required this.cartilha,
    this.profileDataStore,
    this.progressOwnerId,
    this.savedClassroomContent = false,
    this.learningContextController,
    this.deliveryController,
    this.dynamicActivityEnabled,
    this.assessmentApiUrl,
    this.assessmentAttemptStore = const AssessmentAttemptRepository(),
    this.assessmentSyncCoordinator,
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
  late final String? _contextKey;
  late final Future<String?> _deliveryOwner;
  LearningDeliveryController? _delivery;
  bool _ownsDelivery = false;
  bool _hadSaveFailure = false;
  bool _startingLesson = false;
  bool _startingRequest = false;
  bool _enteringAssessmentBlock = false;
  PublishedAssessmentController? _publishedAssessmentController;
  LearningEvent? _startedEvent;
  String? _startedEventId;
  String? _pendingActionEventId;
  VoidCallback? _pendingReadingAction;
  bool get _canRecordActivities =>
      !_startingLesson &&
      _pendingReadingAction == null &&
      (_delivery?.canRecord ?? true);

  bool get _dynamicActivityEnabled =>
      widget.dynamicActivityEnabled ?? AppConfig.dynamicActivityEnabled;
  String get _assessmentApiUrl =>
      widget.assessmentApiUrl ?? AppConfig.tutorApiUrl;

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
    final learningContext = widget.learningContextController?.snapshot?.context;
    _deliveryOwner = learningContext != null
        ? Future.value(learningContext.userId)
        : _eventQueue.isDurable
        ? context.read<LearningEventSyncService>().authRepository.localUserId()
        : Future.value(null);
    _contextKey = learningContext?.resumeKey(AppConfig.tutorApiUrl);
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.48);
    _activityTracker = LearningActivityTracker(
      courseId: widget.cartilha.id,
      sessionId: _learningSessionId,
    );
    _delivery = widget.deliveryController;
    if (_delivery == null &&
        AppConfig.durableLearningOutboxEnabled &&
        learningContext != null) {
      final sync = context.read<LearningEventSyncService>();
      final scope = LearningDeliveryScope(
        ownerId: learningContext.userId,
        apiUrl: sync.apiUrl,
        cohortId: learningContext.cohortId,
        courseId: learningContext.courseId,
        courseVersionId: learningContext.courseVersionId,
      );
      _ownsDelivery = true;
      _delivery = LearningDeliveryController(
        scope: scope,
        queue: _eventQueue,
        sync: sync,
        auth: sync.authRepository,
        revalidateAccess: () async {
          final resolved = await widget.learningContextController!.load(
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
          await widget.learningContextController!.load(scope.cohortId);
        },
      );
    }
    _delivery?.addListener(_deliveryChanged);
    final started = LearningEvent.forSession(
      type: LearningEventType.lessonStarted,
      courseId: widget.cartilha.id,
      sessionId: _learningSessionId,
    );
    if (_delivery != null) {
      _startingLesson = true;
      _startedEvent = started;
      _startedEventId = started.eventId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_delivery!.refresh());
        unawaited(_startLesson());
      });
    } else {
      unawaited(_enqueueAndSync(started));
    }
    _initializeExperience();
  }

  void _deliveryChanged() {
    if (!mounted) return;
    final failed =
        _delivery?.hasUnsavedEvent == true && _delivery?.issue != null;
    if (failed) _activityTracker.reset();
    if (failed && !_hadSaveFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _hadSaveFailure = failed;
    if (_delivery?.lastStoredEventId == _startedEventId &&
        _delivery?.saving == false &&
        _delivery?.issue == null) {
      _startingLesson = false;
    }
    setState(() {});
    _applyStoredAction();
    if (_startingLesson && !_startingRequest && _delivery?.canRecord == true) {
      // A failed projection may prevent the initial command from even starting.
      // Resume that same captured event only when the observed state recovers.
      scheduleMicrotask(() {
        if (mounted) unawaited(_startLesson());
      });
    }
  }

  Future<void> _startLesson() async {
    final event = _startedEvent;
    if (!mounted ||
        !_startingLesson ||
        _startingRequest ||
        _delivery?.canRecord != true ||
        event == null) {
      return;
    }
    // A committed event only waits for projection recovery, not another insert.
    if (_delivery?.lastStoredEventId == event.eventId) {
      setState(() => _startingLesson = false);
      return;
    }
    _startingRequest = true;
    try {
      await _enqueueAndSync(event);
    } finally {
      _startingRequest = false;
    }
  }

  Future<bool> _enqueueAndSync(LearningEvent event) async {
    final syncService = context.read<LearningEventSyncService>();
    var scopedEvent = event.withCourseContext(
      courseVersionId: widget.cartilha.courseVersionId,
      classId: widget.cartilha.classId,
    );
    final delivery = _delivery;
    if (delivery != null) {
      // Scope is captured from the resolved enrollment, before any await. The
      // controller blocks concurrent actions only until the local commit.
      return delivery.record(
        scopedEvent.forLocalOwner(
          userId: delivery.scope.ownerId,
          apiUrl: delivery.scope.apiUrl,
        ),
      );
    }
    final owner = await _deliveryOwner;
    if (owner != null) {
      scopedEvent = scopedEvent.forLocalOwner(
        userId: owner,
        apiUrl: syncService.apiUrl,
      );
    }
    await _eventQueue.enqueue(scopedEvent);
    final synced = await syncService.flush();
    final controller = widget.learningContextController;
    if (synced > 0 &&
        mounted &&
        controller != null &&
        widget.cartilha.classId != null) {
      await controller.load(widget.cartilha.classId!);
    }
    return true;
  }

  void _act(VoidCallback action) {
    if (!_canRecordActivities) return;
    final event = _activityTracker.recordInteraction();
    if (event == null || _delivery == null) {
      if (event != null) unawaited(_enqueueAndSync(event));
      action();
      return;
    }
    unawaited(_recordThen(event, action));
  }

  Future<void> _recordThen(LearningEvent event, VoidCallback action) async {
    _pendingActionEventId = event.eventId;
    _pendingReadingAction = action;
    await _enqueueAndSync(event);
    _applyStoredAction();
  }

  void _applyStoredAction() {
    final delivery = _delivery;
    if (!mounted ||
        delivery == null ||
        delivery.saving ||
        delivery.hasUnsavedEvent ||
        delivery.issue != null ||
        delivery.lastStoredEventId != _pendingActionEventId) {
      return;
    }
    final action = _pendingReadingAction;
    _pendingReadingAction = null;
    _pendingActionEventId = null;
    action?.call();
  }

  Future<void> _initializeExperience() async {
    final saved = await _progressRepository.load(
      widget.cartilha.id,
      courseVersionId: widget.cartilha.courseVersionId,
      ownerId: widget.progressOwnerId,
      allowLegacy: widget.cartilha.legacyProgressCompatible,
      contextKey: _contextKey,
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
    var questionsAnswered = _bounded(
      saved?.questionsAnswered ?? 0,
      _totalQuestions,
    );
    final publishedController = await _openPublishedAssessment(
      sections[sectionIndex],
      currentMessage,
    );
    if (!mounted) return;
    final publishedBlocked = _publishedAssessmentBlockedFor(
      sections[sectionIndex],
      currentMessage,
    );
    final restoredOption = publishedController?.selectionReady == true
        ? publishedController?.selectedOptionIndex
        : null;
    if (restoredOption != null &&
        currentMessage.isAssessmentQuestion &&
        (saved == null || saved.showOptions)) {
      questionsAnswered = _bounded(questionsAnswered + 1, _totalQuestions);
    }

    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMessageIndex = messageIndex;
      _questionsAnswered = questionsAnswered;
      _isCompleted = saved?.isCompleted ?? false;
      _showOptions = publishedBlocked
          ? false
          : restoredOption == null
          ? (saved?.showOptions ?? currentMessage.type != 'bot')
          : false;
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
        _appendRestoredAssessmentAnswer(
          currentMessage,
          restoredOption,
          notify: false,
        );
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

  PublishedAssessmentContext? _publishedContextFor(
    Section section,
    Message message,
  ) {
    if (!_isContextualPublishedAssessment(message) ||
        !_hasCompletePublishedLineage(section, message)) {
      return null;
    }
    final learning = widget.learningContextController?.snapshot?.context;
    final legacyEnrollmentId = learning?.legacyEnrollmentId;
    if (learning == null ||
        legacyEnrollmentId == null ||
        !learning.matchesCourse(widget.cartilha) ||
        !learning.permissions.contains('activity.record') ||
        _assessmentApiUrl.trim().isEmpty) {
      return null;
    }
    return PublishedAssessmentContext(
      ownerId: learning.userId,
      apiUrl: _assessmentApiUrl,
      lineage: PublishedAssessmentLineage(
        organizationId: learning.organizationId,
        programId: learning.programId,
        classId: learning.cohortId,
        membershipId: learning.membershipId,
        enrollmentId: learning.enrollmentId,
        legacyEnrollmentId: legacyEnrollmentId,
        courseId: learning.courseId,
        courseVersionId: learning.courseVersionId,
        sectionId: section.id,
        sectionVersionId: section.versionId!,
        blockId: message.id!,
        blockVersionId: message.versionId!,
      ),
    );
  }

  bool _isContextualPublishedAssessment(Message message) =>
      _dynamicActivityEnabled &&
      message.isAssessmentQuestion &&
      !widget.cartilha.legacyProgressCompatible &&
      widget.cartilha.classId?.trim().isNotEmpty == true &&
      widget.cartilha.courseVersionId?.trim().isNotEmpty == true;

  bool _hasCompletePublishedLineage(Section section, Message message) =>
      section.id.trim().isNotEmpty &&
      section.versionId?.trim().isNotEmpty == true &&
      message.id?.trim().isNotEmpty == true &&
      message.versionId?.trim().isNotEmpty == true;

  bool _publishedAssessmentBlockedFor(Section section, Message message) =>
      _isContextualPublishedAssessment(message) &&
      _publishedContextFor(section, message) == null;

  Future<PublishedAssessmentController?> _openPublishedAssessment(
    Section section,
    Message message,
  ) async {
    final publishedContext = _publishedContextFor(section, message);
    if (publishedContext == null) return null;
    var controller = _publishedAssessmentController;
    if (controller == null) {
      final sync =
          widget.assessmentSyncCoordinator ??
          context.read<AssessmentSyncCoordinator>();
      controller = PublishedAssessmentController(
        widget.assessmentAttemptStore,
        sync,
      );
      controller.addListener(_publishedAssessmentChanged);
      _publishedAssessmentController = controller;
    }
    await controller.open(
      PublishedAssessmentBlock(
        courseId: widget.cartilha.id,
        courseTitle: widget.cartilha.title,
        section: section,
        message: message,
        context: publishedContext,
      ),
    );
    return controller;
  }

  void _publishedAssessmentChanged() {
    if (mounted) setState(() {});
  }

  PublishedAssessmentController? get _activePublishedAssessment {
    if (_isCompleted || widget.cartilha.sections.isEmpty) return null;
    final section = widget.cartilha.sections[_currentSectionIndex];
    final message = section.messages[_currentMessageIndex];
    final publishedContext = _publishedContextFor(section, message);
    final controller = _publishedAssessmentController;
    return publishedContext != null &&
            controller?.matches(publishedContext) == true
        ? controller
        : null;
  }

  bool get _activePublishedAssessmentBlocked {
    if (_isCompleted || widget.cartilha.sections.isEmpty) return false;
    final section = widget.cartilha.sections[_currentSectionIndex];
    final message = section.messages[_currentMessageIndex];
    return _publishedAssessmentBlockedFor(section, message);
  }

  void _appendRestoredAssessmentAnswer(
    Message message,
    int? optionIndex, {
    required bool notify,
  }) {
    final options = message.options ?? const <Option>[];
    if (optionIndex == null ||
        optionIndex < 0 ||
        optionIndex >= options.length) {
      return;
    }
    final option = options[optionIndex];
    _visibleMessages.add(Message(type: 'user', content: option.label));
    final feedback = option.feedback ?? message.explanation;
    if (feedback != null && feedback.trim().isNotEmpty) {
      _visibleMessages.add(Message(type: 'bot', content: feedback));
    }
    if (notify) setState(() {});
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
      contextKey: _contextKey,
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
    _delivery?.removeListener(_deliveryChanged);
    if (_ownsDelivery) _delivery?.dispose();
    _publishedAssessmentController?.removeListener(_publishedAssessmentChanged);
    _publishedAssessmentController?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _activityTracker.reset();
    if (state == AppLifecycleState.resumed && _delivery != null) {
      unawaited(_delivery!.refresh());
    }
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _displayNextMessage() async {
    final section = widget.cartilha.sections[_currentSectionIndex];
    if (_currentMessageIndex < section.messages.length) {
      final msg = section.messages[_currentMessageIndex];
      setState(() => _enteringAssessmentBlock = true);
      final published = await _openPublishedAssessment(section, msg);
      if (!mounted) return;
      final publishedBlocked = _publishedAssessmentBlockedFor(section, msg);
      final restoredOption = published?.selectionReady == true
          ? published?.selectedOptionIndex
          : null;
      setState(() {
        _enteringAssessmentBlock = false;
        _visibleMessages.add(msg);
        _showOptions =
            !publishedBlocked && restoredOption == null && msg.type != 'bot';
        if (restoredOption != null) {
          _appendRestoredAssessmentAnswer(msg, restoredOption, notify: false);
        }
      });
      _saveProgress();
      _scrollToBottom();
    }
  }

  void _advance() {
    if (_activePublishedAssessment != null) {
      unawaited(_completePublishedAssessment());
      return;
    }
    _act(_advanceContent);
  }

  Future<void> _completePublishedAssessment() async {
    final controller = _activePublishedAssessment;
    if (controller == null || controller.saving) return;
    final stored = await controller.complete();
    if (!mounted) return;
    if (!stored) {
      _showAssessmentIssue();
      return;
    }
    _act(_advanceContent);
  }

  void _advanceContent() {
    final section = widget.cartilha.sections[_currentSectionIndex];
    if (_currentMessageIndex < section.messages.length - 1) {
      setState(() => _currentMessageIndex++);
      unawaited(_displayNextMessage());
    } else if (_currentSectionIndex < widget.cartilha.sections.length - 1) {
      setState(() {
        _currentSectionIndex++;
        _currentMessageIndex = 0;
      });
      unawaited(_displayNextMessage());
    } else {
      final event = LearningEvent.forSession(
        type: LearningEventType.lessonCompleted,
        courseId: widget.cartilha.id,
        sessionId: _learningSessionId,
      );
      if (_delivery == null) {
        unawaited(_enqueueAndSync(event));
        _finishContent();
      } else {
        unawaited(_recordThen(event, _finishContent));
      }
    }
  }

  void _finishContent() {
    setState(() {
      _isCompleted = true;
      _showOptions = false;
      _visibleMessages.add(_completionMessage());
    });
    _saveProgress();
    _scrollToBottom();
  }

  void _handleOptionClick(Option option) {
    if (!_showOptions || !_canRecordActivities) return;
    final published = _activePublishedAssessment;
    if (published != null) {
      unawaited(_persistPublishedOption(published, option));
      return;
    }
    _act(() => _applyOption(option));
  }

  Future<void> _persistPublishedOption(
    PublishedAssessmentController controller,
    Option option,
  ) async {
    if (controller.saving) return;
    final current = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex];
    final optionIndex = current.options?.indexOf(option) ?? -1;
    final stored = await controller.selectOption(optionIndex);
    if (!mounted) return;
    if (stored) {
      _applyOption(option);
      final event = _activityTracker.recordInteraction();
      if (event != null) unawaited(_enqueueAndSync(event));
    }
    if (!stored) _showAssessmentIssue();
  }

  Future<void> _togglePublishedReview() async {
    final controller = _activePublishedAssessment;
    if (controller == null || controller.saving) return;
    final stored = await controller.toggleReview();
    if (!mounted || stored) return;
    _showAssessmentIssue();
  }

  Future<void> _retryPublishedAssessment() async {
    final controller = _activePublishedAssessment;
    if (controller == null || controller.saving) return;
    final stored = await controller.retry();
    if (!mounted) return;
    if (!stored) {
      _showAssessmentIssue();
      return;
    }
    final optionIndex = controller.selectedOptionIndex;
    final options = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex]
        .options;
    if (_showOptions &&
        controller.selectionReady &&
        optionIndex != null &&
        options != null &&
        optionIndex >= 0 &&
        optionIndex < options.length) {
      _applyOption(options[optionIndex]);
    }
  }

  void _showAssessmentIssue() {
    final message =
        _activePublishedAssessment?.error ??
        'A atividade não foi salva. Tente novamente.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyOption(Option option) {
    final currentMsg = widget
        .cartilha
        .sections[_currentSectionIndex]
        .messages[_currentMessageIndex];
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

  String? get _tutorCourseVersionId {
    final contextVersion = widget.learningContextController?.snapshot?.context;
    final cartilhaVersion = widget.cartilha.courseVersionId;
    if (contextVersion?.courseId == widget.cartilha.id) {
      if (cartilhaVersion != null &&
          cartilhaVersion.trim().isNotEmpty &&
          cartilhaVersion != contextVersion!.courseVersionId) {
        return null;
      }
      return contextVersion!.courseVersionId;
    }
    return cartilhaVersion;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _delivery?.hasUnsavedEvent != true &&
          _delivery?.saving != true &&
          _pendingReadingAction == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final message =
              _delivery?.hasUnsavedEvent == true || _delivery?.saving == true
              ? 'Esta atividade ainda não foi salva. Tente salvar novamente antes de sair.'
              : 'A atividade foi salva. Verifique os envios para retomar antes de sair.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.cartilha.title,
            style: const TextStyle(fontSize: 15),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          actions: [
            if (!_isInitializing &&
                widget.cartilha.sections.isNotEmpty &&
                widget
                    .cartilha
                    .sections[_currentSectionIndex]
                    .materials
                    .isNotEmpty)
              IconButton(
                tooltip: 'Materiais do módulo',
                icon: const Icon(Icons.folder_open),
                onPressed: () {
                  final section =
                      widget.cartilha.sections[_currentSectionIndex];
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ModuleMaterialsScreen(
                        courseId: widget.cartilha.id,
                        moduleId: section.id,
                        materials: section.materials,
                        repository: MediaRepository(
                          apiUrl: AppConfig.tutorApiUrl,
                          authRepository: context.read<AuthRepository>(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              tooltip: 'Perguntar ao Tutor de IA',
              icon: const Icon(Icons.psychology),
              onPressed: () {
                final section = widget.cartilha.sections.isEmpty
                    ? null
                    : widget.cartilha.sections[_currentSectionIndex];
                final courseVersionId = _tutorCourseVersionId;
                final learningContext =
                    courseVersionId != null && courseVersionId.trim().isNotEmpty
                    ? TutorLearningContext(
                        courseId: widget.cartilha.id,
                        courseVersionId: courseVersionId,
                        moduleId: section?.id,
                      )
                    : null;
                Navigator.push(
                  context,
                  trackedRoute(
                    pageId: 'ai_assistant',
                    courseId: widget.cartilha.id,
                    resourceId: 'ai_chat',
                    featureId: 'ai_tutor',
                    builder: (_) => GenUIAssistantScreen(
                      initialContext: widget.cartilha.title,
                      contextLabel: widget.cartilha.title,
                      learningContext: learningContext,
                    ),
                  ),
                );
              },
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
                  if (widget.learningContextController case final controller?)
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        final snapshot = controller.snapshot;
                        final text = snapshot == null
                            ? (controller.error ??
                                  'Atualizando o progresso confirmado...')
                            : 'Progresso confirmado: ${snapshot.progressPercent.toStringAsFixed(1)}%'
                                  ' • ${snapshot.validatedHours.toStringAsFixed(2)} h'
                                  '${snapshot.fromCache ? ' • última sincronização' : ''}';
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            text,
                            key: const Key('learning-context-progress'),
                          ),
                        );
                      },
                    ),
                  Expanded(
                    child: ResponsiveBody(
                      maxWidth: 860,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount:
                            _visibleMessages.length +
                            (_delivery == null ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (_delivery != null && index == 0) {
                            return LearningDeliveryStatus(
                              controller: _delivery!,
                            );
                          }
                          return _buildBubble(
                            _visibleMessages[index -
                                (_delivery == null ? 0 : 1)],
                          );
                        },
                      ),
                    ),
                  ),
                  if (!_isCompleted) _buildReaderActions(),
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
            onPressed: _canRecordActivities
                ? () => _handleOptionClick(opt)
                : null,
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

  Widget _buildReaderActions() {
    if (_enteringAssessmentBlock) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final published = _activePublishedAssessment;
    if (published == null) {
      if (_activePublishedAssessmentBlocked) {
        return const Padding(
          key: Key('published-assessment-blocked'),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Text(
            'Atividade indisponível. Atualize seu acesso à turma antes de responder.',
            textAlign: TextAlign.center,
          ),
        );
      }
      return _showOptions ? _buildOptions() : _buildContinueButton();
    }
    return ListenableBuilder(
      listenable: published,
      builder: (context, _) {
        final record = published.syncRecord;
        final status = record?.status.label ?? 'Salvo neste aparelho';
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    key: const Key('published-assessment-review-toggle'),
                    onPressed:
                        published.saving ||
                            published.isCompleted ||
                            published.accessDenied ||
                            published.activityUnavailable
                        ? null
                        : _togglePublishedReview,
                    icon: Icon(
                      published.markedForReview
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    label: Text(
                      published.markedForReview
                          ? 'Remover marca de revisão'
                          : 'Marcar para revisar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (published.accessDenied)
                    const Padding(
                      key: Key('published-assessment-access-denied'),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Atividade bloqueada porque seu acesso à turma não está ativo.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (published.activityUnavailable)
                    const Padding(
                      key: Key('published-assessment-unavailable'),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Atividade indisponível neste ambiente até a liberação do serviço.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (!published.selectionReady)
                    _buildOptions()
                  else
                    _buildContinueButton(
                      enabled: !published.saving && _canRecordActivities,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    key: const Key('published-assessment-sync-status'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (published.error case final issue?) ...[
                    const SizedBox(height: 4),
                    Text(
                      issue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: published.saving
                          ? null
                          : () => unawaited(_retryPublishedAssessment()),
                      child: const Text('Tentar envio novamente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinueButton({bool? enabled}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton(
          onPressed: (enabled ?? _canRecordActivities) ? _advance : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Continuar'),
        ),
      ),
    ),
  );
}
