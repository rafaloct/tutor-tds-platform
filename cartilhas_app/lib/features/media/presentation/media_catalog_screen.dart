import 'package:flutter/material.dart';

import '../../analytics/telemetry_route.dart';
import '../data/media_repository.dart';
import '../models/media_models.dart';
import 'media_player_screen.dart';

class MediaCatalogScreen extends StatefulWidget {
  const MediaCatalogScreen({super.key, required this.repository});
  final MediaRepository repository;

  @override
  State<MediaCatalogScreen> createState() => _MediaCatalogScreenState();
}

class _MediaCatalogScreenState extends State<MediaCatalogScreen> {
  List<MediaItem> _media = const [];
  bool _loading = true;
  String? _courseFilter;
  String? _catalogWarning;
  bool _usingCachedData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final media = await widget.repository.fetch();
    if (!mounted) return;
    setState(() {
      _media = media;
      _loading = false;
      _usingCachedData = widget.repository.usedCachedData;
      _catalogWarning =
          widget.repository.lastIssue ??
          (widget.repository.rejectedItems > 0
              ? '${widget.repository.rejectedItems} item(ns) incompatível(is) foram ocultados.'
              : null);
      if (_courseFilter != null &&
          !media.any((item) => item.courseId == _courseFilter)) {
        _courseFilter = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = _media.map((item) => item.courseId).toSet().toList()
      ..sort();
    final visible = _courseFilter == null
        ? _media
        : _media.where((item) => item.courseId == _courseFilter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Vídeos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const _CatalogLoading()
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    'Aprenda com propósito',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cada vídeo está ligado a um curso, uma competência e uma próxima atividade.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (courses.length > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _courseFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por curso',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos os cursos'),
                        ),
                        ...courses.map(
                          (course) => DropdownMenuItem<String?>(
                            value: course,
                            child: Text(course),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _courseFilter = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_catalogWarning != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        child: ListTile(
                          leading: Icon(
                            _usingCachedData
                                ? Icons.offline_pin_outlined
                                : Icons.info_outline,
                          ),
                          title: Text(
                            _usingCachedData
                                ? 'Conteúdo salvo no aparelho'
                                : 'Biblioteca parcialmente disponível',
                          ),
                          subtitle: Text(
                            _usingCachedData
                                ? 'Você está vendo informações salvas. A reprodução protegida precisa de conexão. ${_catalogWarning!}'
                                : _catalogWarning!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (visible.isEmpty)
                    _catalogWarning == null
                        ? _EmptyCatalog(onRetry: _load)
                        : _CatalogError(onRetry: _load)
                  else
                    ...visible.map(
                      (media) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MediaCard(
                          media: media,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.media, required this.repository});
  final MediaItem media;
  final MediaRepository repository;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            trackedRoute(
              pageId: 'video_player',
              courseId: media.courseId,
              resourceId: 'video_content',
              featureId: 'video_learning',
              builder: (_) =>
                  MediaPlayerScreen(media: media, repository: repository),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: media.thumbnailUrl == null
                        ? const Icon(Icons.play_circle_outline, size: 64)
                        : Image.network(
                            media.thumbnailUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.play_circle_outline, size: 64),
                          ),
                  ),
                  const Center(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xDD093AF4),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          _duration(media.durationSeconds),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${media.courseId} › ${media.moduleId}'),
                  const SizedBox(height: 6),
                  Text(
                    '${media.creatorName} • Competência ${media.competencyId}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (media.requiresPlaybackAuthorization) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Acesso protegido • conexão necessária'),
                        ),
                      ],
                    ),
                  ] else if (!media.canPlay) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.cloud_off_outlined, size: 18),
                        SizedBox(width: 6),
                        Expanded(child: Text('Conecte-se para reproduzir')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Carregando biblioteca de vídeos',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 100),
        Center(
          child: CircularProgressIndicator(semanticsLabel: 'Carregando vídeos'),
        ),
        SizedBox(height: 18),
        Text(
          'Organizando os vídeos do seu curso...',
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Suas cartilhas continuam disponíveis enquanto a biblioteca é atualizada.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Vídeos indisponíveis agora',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Não foi possível atualizar a biblioteca. Seu progresso e suas cartilhas continuam seguros neste aparelho.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum vídeo publicado ainda',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Você pode continuar pelas cartilhas e pelo Tutor. Puxe a tela para atualizar quando estiver conectado.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
