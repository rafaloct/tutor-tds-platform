import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../features/support/chatwoot_config.dart';
import '../features/support/chatwoot_host_html.dart';
import 'chatwoot_script_value.dart';

int _nextLease = 0;
int? _activeLease;
Timer? _loadTimer;

void _evaluate(String source) =>
    globalContext.callMethod('eval'.toJS, source.toJS);

/// Reserve before async work: an older screen cannot open over a newer screen.
int chatwootReserve() {
  chatwootClose();
  return _activeLease = ++_nextLease;
}

bool chatwootSessionCurrent(int lease) => _activeLease == lease;

int chatwootOpen(
  String baseUrl,
  String token,
  String supportContactId,
  String name,
  String phone, {
  String? identifierHash,
  int? lease,
  bool Function()? canIdentify,
  void Function()? onOpened,
  void Function()? onError,
  void Function()? onClosed,
  Duration loadTimeout = const Duration(seconds: 20),
}) {
  final current = lease ?? chatwootReserve();
  if (!chatwootSessionCurrent(current)) return current;
  final config = ChatwootConfig(baseUrl: baseUrl, websiteToken: token);
  final html = chatwootHostHtml(config, webSession: current);
  void fail() {
    if (!chatwootSessionCurrent(current)) return;
    chatwootClose(current);
    onError?.call();
  }

  final signal = ((JSString status) {
    if (!chatwootSessionCurrent(current)) return;
    if (canIdentify != null && !canIdentify()) {
      fail();
      return;
    }
    switch (status.toDart) {
      case 'ready':
        _evaluate('''
          var host = window.__tdsSupportHost;
          if (host && host.session === $current) host.frame.contentWindow.postMessage({
            kind:"tds-support-identify",session:$current,profile:{
              id:${chatwootScriptValue(supportContactId)},name:${chatwootScriptValue(name)},
              phone:${chatwootScriptValue(phone)},
              identifierHash:${identifierHash == null ? 'null' : chatwootScriptValue(identifierHash)}
            }
          }, window.location.origin);
        ''');
      case 'opened':
        _loadTimer?.cancel();
        onOpened?.call();
      case 'error':
        fail();
      case 'closed':
        _evaluate('''
          var host=window.__tdsSupportHost;
          if(host && host.session===$current) host.frame.style.display="none";
        ''');
        onClosed?.call();
    }
  }).toJS;
  globalContext.setProperty('__tdsSupportSignal'.toJS, signal);
  _loadTimer = Timer(loadTimeout, fail);
  _evaluate('''
    (function() {
      var frame=document.createElement("iframe");
      frame.id="tds-support-host-$current";
      frame.title="Suporte TDS";
      frame.setAttribute("sandbox","allow-scripts allow-forms allow-same-origin allow-popups allow-downloads");
      frame.style.cssText="position:fixed;right:0;bottom:0;width:min(440px,100vw);height:min(720px,90vh);border:0;z-index:2147483000;background:transparent;";
      var host={session:$current,frame:frame};
      host.listener=function(event) {
        var data=event.data;
        if(window.__tdsSupportHost!==host || event.source!==frame.contentWindow ||
           event.origin!==window.location.origin || !data || data.kind!=="tds-support-status" ||
           data.session!==$current || typeof data.status!=="string") return;
        window.__tdsSupportSignal(data.status);
      };
      window.__tdsSupportHost=host;
      window.addEventListener("message",host.listener);
      frame.srcdoc=${chatwootScriptValue(html)};
      document.body.appendChild(frame);
    })();
  ''');
  return current;
}

void chatwootClose([int? lease]) {
  if (lease != null && !chatwootSessionCurrent(lease)) return;
  _activeLease = null; // Invalidate callbacks before reset can emit events.
  _loadTimer?.cancel();
  _loadTimer = null;
  _evaluate(r'''
    (function() {
      var host=window.__tdsSupportHost;
      window.__tdsSupportHost=null;
      window.__tdsSupportSignal=null;
      if(!host) return;
      window.removeEventListener("message",host.listener);
      try {
        var sdk=host.frame.contentWindow.$chatwoot;
        if(sdk) { sdk.toggle("close"); sdk.reset(); }
      } catch (_) {}
      host.frame.remove();
    })();
  ''');
}

bool get chatwootAvailable => true;
