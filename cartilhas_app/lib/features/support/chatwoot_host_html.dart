import '../../services/chatwoot_script_value.dart';
import 'chatwoot_config.dart';

/// An isolated SDK document. Personal identity is supplied only after the host
/// has checked that this opening and authentication session are still current.
String chatwootHostHtml(ChatwootConfig config, {int? webSession}) {
  final signal = webSession == null
      ? 'window.TdsSupportStatus.postMessage(status);'
      : '''window.parent.postMessage({
          kind: "tds-support-status", session: $webSession, status: status
        }, window.origin);''';
  final identifyListener = webSession == null
      ? ''
      : '''window.addEventListener("message", function(event) {
          var data = event.data;
          if (event.source !== window.parent || event.origin !== window.origin ||
              !data || data.kind !== "tds-support-identify" || data.session !== $webSession) return;
          window.__tdsSupportIdentify(data.profile);
        });''';
  return '''<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>html,body{margin:0;height:100%;width:100%;background:transparent;}
#loading{font-family:Arial,sans-serif;color:#666;text-align:center;padding:24px;}</style>
</head><body><div id="loading">Conectando ao suporte TDS...</div><script>
  function signal(status) { $signal }
  window.chatwootSettings = {hideMessageBubble:true,locale:"pt_BR",type:"standard",darkMode:"auto"};
  window.__tdsSupportIdentify = function(profile) {
    try {
      if (!window.\$chatwoot || !profile) return;
      var fields = {name: profile.name || "Aluno TDS", phone_number: profile.phone};
      if (profile.identifierHash) fields.identifier_hash = profile.identifierHash;
      window.\$chatwoot.setUser(profile.id, fields);
      window.\$chatwoot.setCustomAttributes({origem:"App Cartilhas TDS"});
      window.\$chatwoot.toggle("open");

    } catch (_) { signal("error"); }
  };
  $identifyListener
  window.addEventListener("chatwoot:ready", function() { signal("ready"); });
  window.addEventListener("chatwoot:opened", function() {
    document.getElementById("loading").style.display = "none";
    signal("opened");
  });
  window.addEventListener("chatwoot:error", function() { signal("error"); });
  window.addEventListener("chatwoot:closed", function() { signal("closed"); });
  var base = ${chatwootScriptValue(config.baseUrl)};
  var script = document.createElement("script");
  script.src = base + "/packs/js/sdk.js";
  script.async = true;
  script.onerror = function() { signal("error"); };
  script.onload = function() {
    try {
      if (!window.chatwootSDK) { signal("error"); return; }
      window.chatwootSDK.run({websiteToken:${chatwootScriptValue(config.websiteToken)},baseUrl:base});
    } catch (_) { signal("error"); }
  };
  document.head.appendChild(script);
</script></body></html>''';
}

String chatwootIdentifyScript({
  required String id,
  required String name,
  required String phone,
  String? identifierHash,
}) =>
    '''window.__tdsSupportIdentify({
  id:${chatwootScriptValue(id)},name:${chatwootScriptValue(name)},phone:${chatwootScriptValue(phone)},
  identifierHash:${identifierHash == null ? 'null' : chatwootScriptValue(identifierHash)}
});''';
