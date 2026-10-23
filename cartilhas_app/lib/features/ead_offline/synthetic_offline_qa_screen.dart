import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ead_catalog/qa/private_editorial_qa_bridge.dart';
import 'offline_package_binding.dart';
import 'offline_package_manifest.dart';
import 'offline_package_store.dart';
import 'offline_video_player_screen.dart';

/// Bundled QA fixture. These placeholder URLs are manifest identities only;
/// fixture bytes come from assets, never from the public host.
class SyntheticOfflineQa {
  static const videoAsset = 'assets/qa/offline/synthetic.mp4';
  static const captionAsset = 'assets/qa/offline/synthetic.vtt';
  static const _base =
      'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa';

  static final manifest = OfflinePackageManifest.parse({
    'schema_version': 1,
    'course_id': PrivateEditorialQaBridge.syntheticCourseId,
    'lesson_id': PrivateEditorialQaBridge.syntheticLessonId,
    'content_revision': 'a' * 64,
    'mobile_content': true,
    'rights_approved': true,
    'title': 'Vídeo sintético de QA',
    'mp4': {
      'url': '$_base/synthetic.mp4',
      'length': 9031,
      'sha256':
          'b1c2ca035ff63b2070fb0bcf3d70b963d828226b1f03f1014a5b347de2c16ce6',
    },
    'vtt': {
      'url': '$_base/synthetic.vtt',
      'length': 148,
      'sha256':
          '7dd0700f14781baace675332cab287a59bd3156593edde696a5f4c69589df19a',
    },
  });

  static Stream<List<int>> fixtureStream(Uri url) async* {
    final asset = url.path.endsWith('/synthetic.mp4')
        ? videoAsset
        : url.path.endsWith('/synthetic.vtt')
        ? captionAsset
        : null;
    if (asset == null) throw const OfflinePackageException('unsafe_url');
    final data = await rootBundle.load(asset);
    yield data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

class SyntheticOfflineQaScreen extends StatefulWidget {
  const SyntheticOfflineQaScreen({super.key, this.testStore, this.onOperation});

  @visibleForTesting
  final OfflinePackageStore? testStore;

  /// Lets widget tests start native I/O outside the fake clock and await it.
  @visibleForTesting
  final ValueChanged<Future<void> Function()>? onOperation;

  @override
  State<SyntheticOfflineQaScreen> createState() =>
      _SyntheticOfflineQaScreenState();
}

class _SyntheticOfflineQaScreenState extends State<SyntheticOfflineQaScreen> {
  OfflinePackageStore? _store;
  File? _video;
  File? _captions;
  bool _busy = true;
  String _status = 'Verificando pacote offline…';

  @override
  void initState() {
    super.initState();
    if (kDebugMode &&
        (PrivateEditorialQaBridge.enabled || widget.testStore != null)) {
      _track(_open);
    } else {
      _busy = false;
      _status = 'QA indisponível neste build.';
    }
  }

  void _track(Future<void> Function() operation) {
    final runner = widget.onOperation;
    if (runner != null) {
      runner(operation);
    } else {
      operation();
    }
  }

  Future<void> _open() async {
    try {
      final store =
          widget.testStore ??
          await applicationOfflinePackageStore(
            namespace: 'qa_${PrivateEditorialQaBridge.offlineRunId}',
            authority: const _QaAuthority(),
            download: SyntheticOfflineQa.fixtureStream,
          );
      _store = store;
      await _refresh();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Falha ao abrir armazenamento privado.';
        });
      }
    }
  }

  Future<void> _refresh() async {
    final video = await _store!.read(SyntheticOfflineQa.manifest);
    final captions = await _store!.read(
      SyntheticOfflineQa.manifest,
      captions: true,
    );
    if (!mounted) return;
    setState(() {
      _video = video;
      _captions = captions;
      _busy = false;
      _status = video == null
          ? 'Pacote sintético ainda não preparado.'
          : 'Pacote sintético verificado neste aparelho. Pronto para modo avião.';
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _status = 'Preparando pacote sintético…';
    });
    try {
      await _store!.install(SyntheticOfflineQa.manifest);
      await _refresh();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Falha ao preparar: $error';
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _status = 'Removendo pacote…';
    });
    try {
      await _store!.revoke(
        SyntheticOfflineQa.manifest.courseId,
        SyntheticOfflineQa.manifest.lessonId,
      );
      await _refresh();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Falha ao remover: $error';
        });
      }
    }
  }

  void _watch() {
    final video = _video;
    if (video == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OfflineVideoPlayerScreen(
          video: video,
          captions: _captions,
          title: 'QA offline · vídeo sintético',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QA offline sintético')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fixture incluída no app; a preparação copia MP4 e VTT para '
            'o armazenamento privado e verifica tamanho e SHA-256. Sem download remoto.',
          ),
          const SizedBox(height: 16),
          Text(_status, key: const ValueKey('offline-status')),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _store == null ? null : () => _track(_prepare),
            child: const Text('Preparar offline'),
          ),
          FilledButton(
            onPressed: _busy || _video == null ? null : _watch,
            child: const Text('Assistir offline'),
          ),
          OutlinedButton(
            onPressed: _busy || _video == null ? null : () => _track(_remove),
            child: const Text('Remover offline'),
          ),
        ],
      ),
    ),
  );
}

class _QaAuthority implements VerifiedOfflineReleaseAuthority {
  const _QaAuthority();
  @override
  Future<bool> verify(OfflinePackageManifest manifest) async =>
      kDebugMode &&
      PrivateEditorialQaBridge.enabled &&
      jsonEncode(manifest.toJson()) ==
          jsonEncode(SyntheticOfflineQa.manifest.toJson());
}
