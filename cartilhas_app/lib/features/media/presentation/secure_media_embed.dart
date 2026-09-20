import 'dart:convert';

import '../models/media_models.dart';

String buildSecureMediaHtml(MediaItem media, {int initialPositionSeconds = 0}) {
  final captionTracks = media.captions
      .where((caption) => caption.isWebVtt)
      .map(
        (caption) =>
            '<track kind="subtitles" src=${_attribute(caption.url.toString())} '
            'srclang=${_attribute(caption.language)} label=${_attribute(caption.label)}>',
      )
      .join();
  final controls = '''
    <div id="toolbar" aria-label="Controles adicionais">
      <label for="speed">Velocidade</label>
      <select id="speed" aria-label="Velocidade de reprodução">
        <option value="0.75">0,75x</option><option value="1" selected>1x</option>
        <option value="1.25">1,25x</option><option value="1.5">1,5x</option>
        <option value="2">2x</option>
      </select>
    </div>
  ''';
  final body = switch (media.provider) {
    MediaProvider.youtube => _youtube(media, initialPositionSeconds),
    MediaProvider.cloudflareStream => _cloudflare(
      media,
      initialPositionSeconds,
      captionTracks,
    ),
    MediaProvider.externalHls => _htmlVideo(
      media.playbackUrl!,
      initialPositionSeconds,
      captionTracks,
    ),
  };
  return '''<!doctype html>
<html lang="pt-BR"><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{margin:0;background:#101012;color:white;font-family:Arial,sans-serif;height:100%}
#stage{display:flex;flex-direction:column;height:100%}.player{border:0;width:100%;flex:1;background:#000}
#toolbar{display:flex;align-items:center;justify-content:flex-end;gap:8px;padding:8px 12px;background:#171719}
select{font-size:16px;padding:6px;background:#262626;color:white;border:1px solid #929292;border-radius:8px}
</style></head><body><div id="stage">$body$controls</div>
<script>
function notify(type,position,duration){
  if(window.TutorVideo){TutorVideo.postMessage(JSON.stringify({type:type,position:Math.floor(position||0),duration:Math.floor(duration||0)}));}
}
</script></body></html>''';
}

String _youtube(MediaItem media, int initialPosition) {
  final videoId = jsonEncode(media.providerAssetId);
  return '''<div id="player" class="player"></div>
<script src="https://www.youtube.com/iframe_api"></script><script>
let player; function onYouTubeIframeAPIReady(){player=new YT.Player('player',{host:'https://www.youtube-nocookie.com',videoId:$videoId,playerVars:{rel:0,playsinline:1,start:$initialPosition,cc_load_policy:1},events:{onStateChange:onState,onError:()=>notify('error',0,0)}});}
function onState(e){if(e.data===YT.PlayerState.PLAYING){notify('play',player.getCurrentTime(),player.getDuration());}if(e.data===YT.PlayerState.ENDED){notify('ended',player.getDuration(),player.getDuration());}}
setInterval(()=>{if(player&&player.getCurrentTime){notify('progress',player.getCurrentTime(),player.getDuration());}},5000);
window.addEventListener('DOMContentLoaded',()=>document.getElementById('speed').addEventListener('change',e=>{if(player&&player.setPlaybackRate)player.setPlaybackRate(Number(e.target.value));}));
</script>''';
}

String _cloudflare(MediaItem media, int initialPosition, String captionTracks) {
  final uri = media.playbackUrl!;
  if (uri.path.toLowerCase().endsWith('.m3u8')) {
    return _htmlVideo(uri, initialPosition, captionTracks);
  }
  final source = _attribute(uri.toString());
  return '''<iframe id="player" class="player" src=$source allow="accelerometer; autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
<script src="https://embed.cloudflarestream.com/embed/sdk.latest.js"></script><script>
const player=Stream(document.getElementById('player'));
player.addEventListener('play',()=>notify('play',player.currentTime,player.duration));
player.addEventListener('timeupdate',()=>notify('progress',player.currentTime,player.duration));
player.addEventListener('ended',()=>notify('ended',player.duration,player.duration));
player.addEventListener('error',()=>notify('error',player.currentTime,player.duration));
player.addEventListener('loadedmetadata',()=>{if($initialPosition>0)player.currentTime=$initialPosition;});
window.addEventListener('DOMContentLoaded',()=>document.getElementById('speed').addEventListener('change',e=>player.playbackRate=Number(e.target.value)));
</script>''';
}

String _htmlVideo(Uri uri, int initialPosition, String captionTracks) {
  final source = _attribute(uri.toString());
  return '''<video id="player" class="player" controls playsinline preload="metadata" src=$source>$captionTracks</video>
<script>
const player=document.getElementById('player');
player.addEventListener('play',()=>notify('play',player.currentTime,player.duration));
player.addEventListener('timeupdate',()=>notify('progress',player.currentTime,player.duration));
player.addEventListener('ended',()=>notify('ended',player.duration,player.duration));
player.addEventListener('error',()=>notify('error',player.currentTime,player.duration));
player.addEventListener('loadedmetadata',()=>{if($initialPosition>0)player.currentTime=Math.min($initialPosition,Math.max(0,player.duration-2));});
window.addEventListener('DOMContentLoaded',()=>document.getElementById('speed').addEventListener('change',e=>player.playbackRate=Number(e.target.value)));
</script>''';
}

String _attribute(String value) =>
    '"${const HtmlEscape(HtmlEscapeMode.attribute).convert(value)}"';
