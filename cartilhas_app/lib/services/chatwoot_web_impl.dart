// Implementação web — injeta o SDK do Chatwoot na página Flutter web
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'chatwoot_script_value.dart';

bool _injected = false;

void _evaluateJavaScript(String script) {
  globalContext.callMethod('eval'.toJS, script.toJS);
}

void chatwootOpen(
  String baseUrl,
  String token,
  String supportContactId,
  String name,
  String phone, {
  String? identifierHash,
}) {
  final signedField = identifierHash == null
      ? ''
      : 'identifier_hash: ${chatwootScriptValue(identifierHash)},';
  final safeSupportId = chatwootScriptValue(supportContactId);
  final safeName = chatwootScriptValue(name);
  final safePhone = chatwootScriptValue(phone);
  final safeBase = chatwootScriptValue(baseUrl);
  final safeToken = chatwootScriptValue(token);

  // Keep only the latest opening request while the SDK loads. Closing clears
  // this callback so a late ready event cannot reopen a disposed screen.
  _evaluateJavaScript('''
    window.__tdsSupportOpen = function() {
      if (!window.\$chatwoot) return;
      window.\$chatwoot.setUser($safeSupportId, {
        name: $safeName, phone_number: $safePhone, $signedField
      });
      window.\$chatwoot.setCustomAttributes({ origem: "App Cartilhas TDS Web" });
      window.\$chatwoot.toggle("open");
    };
  ''');

  if (!_injected) {
    _injected = true;
    _evaluateJavaScript('''
      window.chatwootSettings = {
        hideMessageBubble: true,
        locale: "pt_BR",
        type: "standard",
        darkMode: "auto",
      };
      (function(d,t){
        var BASE_URL = $safeBase;
        var g = d.createElement(t), s = d.getElementsByTagName(t)[0];
        g.src = BASE_URL + "/packs/js/sdk.js";
        g.defer = true; g.async = true;
        s.parentNode.insertBefore(g, s);
        g.onload = function() {
          window.addEventListener("chatwoot:ready", function() {
            if (window.__tdsSupportOpen) window.__tdsSupportOpen();
          });
          window.chatwootSDK.run({ websiteToken: $safeToken, baseUrl: BASE_URL });
        };
      })(document, "script");
    ''');
  } else {
    // SDK já injetado: atualizar também identidade/assinatura, não só abrir.
    _evaluateJavaScript(r'''
      if (window.$chatwoot) {
        window.__tdsSupportOpen();
      }
    ''');
  }
}

void chatwootClose() {
  _evaluateJavaScript(r'''
    window.__tdsSupportOpen = null;
    if (window.$chatwoot) {
      window.$chatwoot.toggle("close");
      window.$chatwoot.reset();
    }
  ''');
}

bool get chatwootAvailable => true;
