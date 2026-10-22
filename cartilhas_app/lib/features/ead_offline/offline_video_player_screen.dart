import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays only verified private files returned by OfflinePackageStore.read.
class OfflineVideoPlayerScreen extends StatefulWidget {
  const OfflineVideoPlayerScreen({
    super.key,
    required this.video,
    this.captions,
    required this.title,
  });

  final File video;
  final File? captions;
  final String title;

  @override
  State<OfflineVideoPlayerScreen> createState() =>
      _OfflineVideoPlayerScreenState();
}

class _OfflineVideoPlayerScreenState extends State<OfflineVideoPlayerScreen>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _captionsVisible = true;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.file(
      widget.video,
      closedCaptionFile: widget.captions == null
          ? null
          : _loadCaption(widget.captions!),
    );
    _controller.addListener(_changed);
    _initialize();
  }

  static Future<ClosedCaptionFile> _loadCaption(File file) async =>
      WebVTTCaptionFile(await file.readAsString());

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Não foi possível abrir o vídeo offline.');
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  Future<void> _seek(double seconds) async {
    await _controller.seekTo(Duration(milliseconds: (seconds * 1000).round()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final duration = value.duration.inMilliseconds / 1000.0;
    final position = value.position.inMilliseconds / 1000.0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _error != null
            ? Text(_error!)
            : !_ready
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: value.aspectRatio > 0
                        ? value.aspectRatio
                        : 16 / 9,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        if (_captionsVisible && widget.captions != null)
                          ClosedCaption(text: value.caption.text),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Posição do vídeo',
                    value:
                        '${value.position.inSeconds} de ${value.duration.inSeconds} segundos',
                    child: Slider(
                      value: position.clamp(0.0, duration > 0 ? duration : 1.0),
                      max: duration > 0 ? duration : 1.0,
                      onChanged: _seek,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: value.isPlaying
                            ? 'Pausar vídeo'
                            : 'Reproduzir vídeo',
                        onPressed: () => value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      if (widget.captions != null)
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _captionsVisible = !_captionsVisible,
                          ),
                          icon: const Icon(Icons.closed_caption),
                          label: Text(
                            _captionsVisible
                                ? 'Ocultar legendas'
                                : 'Mostrar legendas',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
