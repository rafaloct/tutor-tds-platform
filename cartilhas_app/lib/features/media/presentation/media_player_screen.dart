import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../analytics/telemetry_route.dart';
import '../../learning_events/learning_event_sync_service.dart';
import '../../study_ai/data/assessment_attempt_repository.dart';
import '../../study_ai/presentation/assessment_screen.dart';
import '../../../screens/genui_assistant_screen.dart';
import '../data/media_event_tracker.dart';
import '../data/media_progress_repository.dart';
import '../data/media_repository.dart';
import '../models/media_models.dart';
import 'secure_media_embed.dart';

class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({
    super.key,
    required this.media,
    required this.repository,
  });
  final MediaItem media;
  final MediaRepository repository;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  static const _progressRepository = MediaProgressRepository();
  WebViewController? _controller;
  MediaEventTracker? _tracker;
  MediaProgress? _progress;
  late MediaItem _media;
  _PlaybackViewState _playbackState = _PlaybackViewState.loading;
  String? _playbackIssue;
  bool _saved = false;
  bool _ratingLoading = true;
  bool _ratingSubmitting = false;
  int? _rating;
  String? _ratingIssue;
  int _lastPersistedSecond = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tracker ??= MediaEventTracker(
      media: widget.media,
      syncService: context.read<LearningEventSyncService>(),
    );
  }

  @override
  void initState() {
    super.initState();
    _media = widget.media;
    _initialize();
    _loadRating();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _controller = null;
        _playbackState = _PlaybackViewState.loading;
        _playbackIssue = null;
      });
    }
    try {
      final progress = await _progressRepository.load(widget.media.id);
      if (!mounted) return;
      _progress = progress;
      _saved = progress?.saved ?? false;
      MediaItem playable = widget.media;
      if (playable.requiresPlaybackAuthorization || !playable.canPlay) {
        final access = await widget.repository.authorizePlayback(playable);
        playable = access.media;
      }
      if (!mounted) return;
      _media = playable;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF101012))
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => _allowNavigation(request)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
            onPageFinished: (_) {
              if (mounted) {
                setState(() => _playbackState = _PlaybackViewState.ready);
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false) return;
              if (mounted) {
                setState(() => _playbackState = _PlaybackViewState.error);
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          'TutorVideo',
          onMessageReceived: (message) => _handlePlayerMessage(message.message),
        );
      _controller = controller;
      final initial = progress?.fraction == 1
          ? 0
          : progress?.positionSeconds ?? 0;
      await controller.loadHtmlString(
        buildSecureMediaHtml(playable, initialPositionSeconds: initial),
        baseUrl: 'https://tutor-tds.invalid',
      );
      if (mounted) setState(() {});
    } on MediaRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _playbackIssue = error.message;
          _playbackState = error.issue == MediaRepositoryIssue.unavailable
              ? _PlaybackViewState.offline
              : _PlaybackViewState.error;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _playbackIssue = 'Não foi possível preparar a reprodução.';
          _playbackState = _PlaybackViewState.error;
        });
      }
    }
  }

  bool _allowNavigation(NavigationRequest request) {
    if (!request.isMainFrame) return true;
    final uri = Uri.tryParse(request.url);
    if (uri == null || uri.scheme != 'https') return false;
    if (uri.host == 'tutor-tds.invalid') return true;
    final playbackHost = _media.playbackUrl?.host;
    if (playbackHost != null && uri.host == playbackHost) return true;
    return _host(uri.host, 'youtube.com') ||
        _host(uri.host, 'youtube-nocookie.com') ||
        _host(uri.host, 'videodelivery.net') ||
        _host(uri.host, 'cloudflarestream.com');
  }

  Future<void> _handlePlayerMessage(String source) async {
    try {
      final message = jsonDecode(source);
      if (message is! Map<String, dynamic>) return;
      final type = message['type'];
      final position = (message['position'] as num?)?.toInt() ?? 0;
      final duration =
          (message['duration'] as num?)?.toInt() ??
          widget.media.durationSeconds;
      if (type == 'error') {
        if (mounted) {
          setState(() {
            _playbackIssue =
                'A fonte do vídeo não respondeu. Renove o acesso e tente novamente.';
            _playbackState = _PlaybackViewState.error;
          });
        }
        return;
      }
      if (type == 'play') await _tracker?.started();
      if (type == 'progress' || type == 'ended') {
        await _tracker?.progress(
          positionSeconds: position,
          durationSeconds: duration,
        );
        if (type == 'ended') {
          await _tracker?.completed(positionSeconds: position);
        }
        if ((position - _lastPersistedSecond).abs() >= 5 || type == 'ended') {
          _lastPersistedSecond = position;
          final progress = MediaProgress(
            mediaId: widget.media.id,
            positionSeconds: position.clamp(0, duration),
            durationSeconds: duration > 0
                ? duration
                : widget.media.durationSeconds,
            saved: _saved,
            updatedAt: DateTime.now(),
          );
          await _progressRepository.save(progress);
          if (mounted) setState(() => _progress = progress);
        }
      }
    } on Object {
      // Mensagens fora do contrato são descartadas, sem afetar a reprodução.
    }
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    final current = _progress;
    final progress = MediaProgress(
      mediaId: widget.media.id,
      positionSeconds: current?.positionSeconds ?? 0,
      durationSeconds: current?.durationSeconds ?? widget.media.durationSeconds,
      saved: next,
      updatedAt: DateTime.now(),
    );
    await _progressRepository.save(progress);
    if (next) await _tracker?.saved();
    if (mounted) {
      setState(() {
        _saved = next;
        _progress = progress;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next ? 'Vídeo salvo.' : 'Vídeo removido dos salvos.'),
        ),
      );
    }
  }

  Future<void> _loadRating() async {
    try {
      final rating = await widget.repository.fetchRating(widget.media.id);
      if (mounted) {
        setState(() {
          _rating = rating?.rating;
          _ratingLoading = false;
          _ratingIssue = null;
        });
      }
    } on MediaRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _ratingLoading = false;
          _ratingIssue = error.message;
        });
      }
    }
  }

  Future<void> _submitRating(int value) async {
    if (_ratingSubmitting) return;
    setState(() {
      _ratingSubmitting = true;
      _ratingIssue = null;
    });
    try {
      final rating = await widget.repository.rate(widget.media.id, value);
      if (mounted) {
        setState(() {
          _rating = rating.rating;
          _ratingSubmitting = false;
        });
      }
    } on MediaRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _ratingSubmitting = false;
          _ratingIssue = error.message;
        });
      }
    }
  }

  Future<void> _openQuiz() async {
    final startedAt = DateTime.now();
    await Navigator.push(
      context,
      trackedRoute(
        pageId: 'assessment',
        courseId: widget.media.courseId,
        resourceId: 'video_followup_quiz',
        featureId: 'assessment',
        builder: (_) => AssessmentScreen(
          courseId: widget.media.courseId,
          topic: widget.media.title,
          mode: AssessmentMode.quiz,
        ),
      ),
    );
    final attempt = await const AssessmentAttemptRepository().load(
      widget.media.courseId,
      AssessmentMode.quiz,
    );
    if (attempt?.isCompleted == true && attempt!.updatedAt.isAfter(startedAt)) {
      await _tracker?.followupCompleted('quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    return Scaffold(
      appBar: AppBar(title: const Text('Vídeo')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_controller != null && media.canPlay)
                    WebViewWidget(controller: _controller!),
                  if (_playbackState == _PlaybackViewState.offline)
                    _PlaybackUnavailable(
                      message:
                          _playbackIssue ??
                          'A informação do vídeo está salva, mas a reprodução protegida precisa de conexão.',
                      onRetry: _initialize,
                    ),
                  if (_playbackState == _PlaybackViewState.error)
                    _PlaybackFailure(
                      message: _playbackIssue,
                      onRetry: _initialize,
                    ),
                  if (_playbackState == _PlaybackViewState.loading)
                    const _PlaybackLoading(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(media.description),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(
                        Icons.closed_caption_outlined,
                        size: 18,
                      ),
                      label: Text(
                        media.captions.isEmpty
                            ? 'Legenda do provedor'
                            : '${media.captions.length} legenda(s)',
                      ),
                    ),
                    const Chip(
                      avatar: Icon(Icons.speed_outlined, size: 18),
                      label: Text('0,75x a 2x'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.cloud_outlined, size: 18),
                      label: Text(
                        media.offlinePolicy == MediaOfflinePolicy.allowed
                            ? 'Offline autorizado pelo provedor'
                            : 'Reprodução online',
                      ),
                    ),
                  ],
                ),
                if (_progress != null && _progress!.fraction < 1) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label:
                        'Progresso do vídeo ${(_progress!.fraction * 100).round()} por cento',
                    child: LinearProgressIndicator(value: _progress!.fraction),
                  ),
                ],
                const SizedBox(height: 20),
                _ContextCard(media: media),
                const SizedBox(height: 20),
                Text(
                  'Depois do vídeo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _openQuiz,
                      icon: const Icon(Icons.quiz_outlined),
                      label: const Text('Fazer quiz rápido'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _toggleSaved,
                      icon: Icon(
                        _saved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(_saved ? 'Salvo' : 'Salvar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        trackedRoute(
                          pageId: 'ai_assistant',
                          courseId: media.courseId,
                          resourceId: 'video_context',
                          featureId: 'ai_tutor',
                          builder: (_) => const GenUIAssistantScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.psychology_outlined),
                      label: const Text('Perguntar ao Tutor'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                MediaRatingPanel(
                  rating: _rating,
                  loading: _ratingLoading,
                  submitting: _ratingSubmitting,
                  issue: _ratingIssue,
                  onRate: _submitRating,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.media});
  final MediaItem media;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contexto pedagógico',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${media.courseId}  ›  ${media.moduleId}  ›  ${media.creatorName}  ›  ${media.sourceLabel}',
          ),
          const SizedBox(height: 8),
          Text('Competência: ${media.competencyId}'),
        ],
      ),
    ),
  );
}

class _PlaybackUnavailable extends StatelessWidget {
  const _PlaybackUnavailable({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_outlined, color: Colors.white, size: 44),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.refresh),
          label: const Text('Renovar acesso'),
        ),
      ],
    ),
  );
}

class _PlaybackLoading extends StatelessWidget {
  const _PlaybackLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Preparando reprodução segura',
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: Colors.white,
          semanticsLabel: 'Carregando vídeo',
        ),
        SizedBox(height: 12),
        Text(
          'Preparando reprodução segura...',
          style: TextStyle(color: Colors.white),
        ),
      ],
    ),
  );
}

class _PlaybackFailure extends StatelessWidget {
  const _PlaybackFailure({this.message, required this.onRetry});
  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Não foi possível reproduzir o vídeo',
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 42),
          const SizedBox(height: 8),
          Text(
            message ??
                'Não foi possível iniciar a reprodução. Verifique sua conexão e tente renovar o acesso.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class MediaRatingPanel extends StatelessWidget {
  const MediaRatingPanel({
    super.key,
    required this.rating,
    required this.loading,
    required this.submitting,
    required this.issue,
    required this.onRate,
  });

  final int? rating;
  final bool loading;
  final bool submitting;
  final String? issue;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: issue != null || submitting,
    child: Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avalie este conteúdo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              rating == null
                  ? 'Disponível após a conclusão qualificada do vídeo.'
                  : 'Sua avaliação: $rating de 5.',
            ),
            const SizedBox(height: 8),
            if (loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Consultando sua avaliação',
              )
            else
              Wrap(
                spacing: 2,
                children: [
                  for (var value = 1; value <= 5; value++)
                    Semantics(
                      button: true,
                      selected: rating == value,
                      label: 'Avaliar com $value de 5',
                      child: IconButton(
                        tooltip: '$value de 5',
                        onPressed: submitting ? null : () => onRate(value),
                        icon: Icon(
                          value <= (rating ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                        ),
                      ),
                    ),
                ],
              ),
            if (submitting) ...[
              const SizedBox(height: 4),
              const Text('Enviando avaliação...'),
            ],
            if (issue != null) ...[
              const SizedBox(height: 6),
              Text(
                issue!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

enum _PlaybackViewState { loading, ready, offline, error }

bool _host(String host, String suffix) =>
    host == suffix || host.endsWith('.$suffix');
