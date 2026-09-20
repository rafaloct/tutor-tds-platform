// Implementação web — injeta o SDK do Chatwoot na página Flutter web
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool _injected = false;

void _evaluateJavaScript(String script) {
  globalContext.callMethod('eval'.toJS, script.toJS);
}

void chatwootOpen(
  String baseUrl,
  String token,
  String supportContactId,
  String name,
  String phone,
) {
  final safeSupportId = supportContactId
      .replaceAll('"', '')
      .replaceAll("'", '');
  final safeName = name.replaceAll('"', '').replaceAll("'", '');
  final safePhone = phone.replaceAll('"', '').replaceAll("'", '');

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
        var BASE_URL = "$baseUrl";
        var g = d.createElement(t), s = d.getElementsByTagName(t)[0];
        g.src = BASE_URL + "/packs/js/sdk.js";
        g.defer = true; g.async = true;
        s.parentNode.insertBefore(g, s);
        g.onload = function() {
          window.chatwootSDK.run({ websiteToken: "$token", baseUrl: BASE_URL });
          window.addEventListener("chatwoot:ready", function() {
            window.\$chatwoot.toggle("open");
            if ("$safeSupportId" !== "") {
              window.\$chatwoot.setUser("$safeSupportId", {
                name: "$safeName",
                phone_number: "$safePhone",
              });
              window.\$chatwoot.setCustomAttributes({ origem: "App Cartilhas TDS Web" });
            }
          });
        };
      })(document, "script");
    ''');
  } else {
    // SDK já injetado — só abre o widget e reidenta
    _evaluateJavaScript(r'''
      if (window.$chatwoot) {
        window.$chatwoot.toggle("open");
      }
    ''');
  }
}

void chatwootClose() {
  _evaluateJavaScript(r'''
    if (window.$chatwoot) window.$chatwoot.toggle("close");
  ''');
}

bool get chatwootAvailable => true;
