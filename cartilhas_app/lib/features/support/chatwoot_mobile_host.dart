import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'chatwoot_config.dart';
import 'chatwoot_host_html.dart';

abstract interface class ChatwootMobileHost {
  Future<void> load(
    ChatwootConfig config, {
    required void Function() onReady,
    required void Function() onOpened,
    required void Function() onError,
  });
  Future<void> identify({
    required String id,
    required String name,
    required String phone,
    String? identifierHash,
  });
  Widget build();
  Future<void> close();
}

class WebViewChatwootHost implements ChatwootMobileHost {
  final WebViewController _controller = WebViewController();
  bool _closed = false;

  @override
  Future<void> load(
    ChatwootConfig config, {
    required void Function() onReady,
    required void Function() onOpened,
    required void Function() onError,
  }) async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.white);
    await _controller.addJavaScriptChannel(
      'TdsSupportStatus',
      onMessageReceived: (message) {
        if (_closed) return;
        switch (message.message) {
          case 'ready':
            onReady();
          case 'opened':
            onOpened();
          case 'error':
            onError();
        }
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        // Finishing the outer HTML does not establish SDK/widget readiness.
        onWebResourceError: (error) {
          if (!_closed && error.isForMainFrame == true) onError();
        },
        onHttpError: (error) {
          if (_closed) return;
          final uri = error.request?.uri;
          final status = error.response?.statusCode;
          if (uri == null || status == null || status < 400) return;
          final base = Uri.parse(config.baseUrl);
          if (uri.origin == base.origin &&
              (uri.path == '${base.path}/packs/js/sdk.js' ||
                  uri.path == '${base.path}/widget' ||
                  uri.path.startsWith('${base.path}/widget/') ||
                  uri.path == '${base.path}/api/v1/widget/inboxes' ||
                  uri.path.startsWith('${base.path}/api/v1/widget/inboxes/'))) {
            onError();
          }
        },
      ),
    );
    if (!_closed) {
      await _controller.loadHtmlString(
        chatwootHostHtml(config),
        baseUrl: config.baseUrl,
      );
    }
  }

  @override
  Future<void> identify({
    required String id,
    required String name,
    required String phone,
    String? identifierHash,
  }) async {
    if (_closed) return;
    await _controller.runJavaScript(
      chatwootIdentifyScript(
        id: id,
        name: name,
        phone: phone,
        identifierHash: identifierHash,
      ),
    );
  }

  @override
  Widget build() => WebViewWidget(controller: _controller);

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _controller.runJavaScript(r'''
        if (window.$chatwoot) { window.$chatwoot.toggle("close"); window.$chatwoot.reset(); }
      ''');
    } on Object {
      /* A detached view may already be destroyed. */
    }
    try {
      await _controller.loadHtmlString('<!doctype html><html></html>');
    } on Object {
      /* A detached view may already be destroyed. */
    }
  }
}
