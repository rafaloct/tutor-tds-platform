import 'package:flutter/material.dart';
import '../courses/application/course_pdf_controller.dart';
import '../media/data/media_repository.dart';
import '../media/presentation/media_player_screen.dart';
import 'course_material.dart';

class ModuleMaterialsScreen extends StatefulWidget {
  const ModuleMaterialsScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.materials,
    required this.repository,
    this.externalController,
  });
  final String courseId;
  final String moduleId;
  final List<CourseMaterial> materials;
  final MediaRepository repository;
  final CoursePdfController? externalController;
  @override
  State<ModuleMaterialsScreen> createState() => _ModuleMaterialsScreenState();
}

class _ModuleMaterialsScreenState extends State<ModuleMaterialsScreen> {
  late final _external = widget.externalController ?? CoursePdfController();
  String? _opening;
  String? _error;
  @override
  void dispose() {
    widget.repository.dispose();
    super.dispose();
  }

  Future<void> _open(CourseMaterial material) async {
    if (_opening != null) return;
    setState(() {
      _opening = material.id;
      _error = null;
    });
    try {
      if (material.kind == 'video') {
        final generation = widget.repository.authRepository?.sessionGeneration;
        final media = await widget.repository.fetchPublishedById(
          material.mediaId!,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
        );
        if (!mounted ||
            generation != widget.repository.authRepository?.sessionGeneration) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                MediaPlayerScreen(media: media, repository: widget.repository),
          ),
        );
      } else {
        if (!isPublicMaterialUrl(material.url)) throw const FormatException();
        final result = await _external.open(
          url: material.url,
          courseId: widget.courseId,
        );
        if (result != CoursePdfResult.requested) throw const FormatException();
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Material indisponível. Verifique sua conexão e seu acesso e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Materiais do módulo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Materiais desta edição. Abrir um material não registra conclusão. Vídeos exigem conexão; arquivos e sites abrem em outro aplicativo.',
        ),
        if (_opening != null)
          const LinearProgressIndicator(semanticsLabel: 'Abrindo material'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, semanticsLabel: _error),
          ),
        if (widget.materials.isEmpty)
          const Text('Este módulo ainda não tem materiais.'),
        for (final material in widget.materials)
          ListTile(
            title: Text(material.title),
            subtitle: Text(material.kindLabel),
            leading: Icon(
              material.kind == 'video'
                  ? Icons.play_circle_outline
                  : material.kind == 'pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.link,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: _opening == null ? () => _open(material) : null,
          ),
      ],
    ),
  );
}
