"""Capture sanitized Chromium Network/Media evidence from a QA Android WebView.

Requires adb and websocket-client. Run before the Flutter integration test:
  py tool/ipex_cdp_probe.py --adb D:/DevTools/AndroidSDK/platform-tools/adb.exe \
    --serial emulator-5554 --output D:/AI-Shared/test-results/.../cdp.jsonl
Only media type and range metadata are retained; media URLs and cookies are not.
"""

import argparse
import hashlib
import json
import re
import subprocess
import time
import urllib.request

import websocket


def adb(args, *command):
    return subprocess.run(
        [args.adb, "-s", args.serial, *command],
        capture_output=True, text=True, timeout=10, check=True,
    ).stdout


def target_socket(args):
    sockets = re.findall(r"@(" + args.socket_prefix + r"(?:_\d+)?)\b",
                         adb(args, "shell", "cat", "/proc/net/unix"))
    return sockets[-1] if sockets else None


def kind(url):
    if url.startswith("data:"):
        return "local_html"
    if ".mp4" in url.lower():
        return "mp4"
    if ".vtt" in url.lower():
        return "vtt"
    if url.startswith("https:"):
        return "other_https"
    return "other"


def scrub(value):
    if isinstance(value, str):
        return re.sub(r"https?://[^\s\"'<>]+", "[url]", value)[:500]
    if isinstance(value, list):
        return [scrub(item) for item in value]
    if isinstance(value, dict):
        return {key: (hashlib.sha256(str(item).encode()).hexdigest()[:10]
                      if key in ("id", "requestId", "playerId", "socket") else scrub(item))
                for key, item in value.items()
                if key.lower() not in ("url", "cookie", "authorization", "referer")}
    return value


SAMPLE = """(() => {
  const v = document.getElementById('lesson-video');
  if (!v) return {video:false};
  if (!v.__ipexProbe) {
    const stats = {waiting:0, stalled:0, timeupdate:0, playing:0,
      progress:0, error:0, firstFrame:null, lastEvent:null};
    for (const name of ['waiting','stalled','timeupdate','playing','progress','error'])
      v.addEventListener(name, () => {
        stats[name]++;
        stats.lastEvent = name;
      });
    if (v.requestVideoFrameCallback)
      v.requestVideoFrameCallback((now, metadata) => {
        stats.firstFrame = {at:+now.toFixed(1),
          presented:metadata.presentedFrames};
      });
    v.__ipexProbe = stats;
  }
  const q = v.getVideoPlaybackQuality?.();
  const ranges = [];
  for (let i=0; i<v.buffered.length; i++)
    ranges.push([+v.buffered.start(i).toFixed(3), +v.buffered.end(i).toFixed(3)]);
  return {video:true, time:+v.currentTime.toFixed(3), duration:+v.duration.toFixed(3),
    paused:v.paused, seeking:v.seeking, ended:v.ended, ready:v.readyState,
    network:v.networkState, buffered:ranges, error:v.error?.code ?? null,
    errorMessage:v.error?.message ?? null, frames:q?.totalVideoFrames ??
      v.webkitDecodedFrameCount ?? null, dropped:q?.droppedVideoFrames ?? null,
    cues:v.textTracks[0]?.cues?.length ?? null,
    activeCues:v.textTracks[0]?.activeCues?.length ?? null,
    captionVisible:document.getElementById('caption-toggle')?.getAttribute('aria-pressed'),
    events:v.__ipexProbe};
})()"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--output", required=True)
    parser.add_argument("--duration", type=int, default=420)
    parser.add_argument("--port", type=int, default=9333)
    parser.add_argument("--socket-prefix", choices=("webview_devtools_remote",
                                                  "chrome_devtools_remote"),
                        default="webview_devtools_remote")
    args = parser.parse_args()
    started = time.monotonic()
    current_socket = None
    ws = None
    attached_target = None
    requests = {}
    last_sample = 0
    message_id = 0

    with open(args.output, "w", encoding="utf-8", buffering=1) as out:
        def emit(event, **fields):
            out.write(json.dumps({"elapsed": round(time.monotonic()-started, 3),
                                  "event": event, **scrub(fields)}, ensure_ascii=False)+"\n")

        while time.monotonic()-started < args.duration:
            if ws is None:
                try:
                    socket_id = target_socket(args)
                    if socket_id is None:
                        time.sleep(1)
                        continue
                    if socket_id != current_socket:
                        adb(args, "forward", f"tcp:{args.port}",
                            f"localabstract:{socket_id}")
                        current_socket = socket_id
                    with urllib.request.urlopen(
                        f"http://127.0.0.1:{args.port}/json", timeout=2,
                    ) as response:
                        targets = json.load(response)
                    pages = [t for t in targets if t.get("type") == "page"
                             and t.get("webSocketDebuggerUrl")]
                    if not pages:
                        time.sleep(1)
                        continue
                    ws = websocket.create_connection(
                        pages[0]["webSocketDebuggerUrl"], timeout=1,
                        origin="http://localhost",
                        suppress_origin=True,
                    )
                    attached_target = pages[0]["id"]
                    emit("attached", socket=socket_id)
                    for method in ("Network.enable", "Media.enable", "Runtime.enable"):
                        message_id += 1
                        ws.send(json.dumps({"id": message_id, "method": method}))
                except Exception as exc:
                    emit("attach_error", detail=str(exc))
                    time.sleep(1)
                continue

            try:
                if time.monotonic()-last_sample >= 1:
                    last_sample = time.monotonic()
                    with urllib.request.urlopen(
                        f"http://127.0.0.1:{args.port}/json", timeout=2,
                    ) as response:
                        targets = json.load(response)
                    pages = [t for t in targets if t.get("type") == "page"
                             and t.get("webSocketDebuggerUrl")]
                    if pages and pages[0]["id"] != attached_target:
                        emit("target_changed")
                        ws.close()
                        ws = None
                        attached_target = None
                        requests.clear()
                        continue
                    message_id += 1
                    ws.send(json.dumps({"id": message_id, "method": "Runtime.evaluate",
                                        "params": {"expression": SAMPLE, "returnByValue": True}}))
                try:
                    event = json.loads(ws.recv())
                except websocket.WebSocketTimeoutException:
                    continue
                method = event.get("method", "")
                p = event.get("params", {})
                if method == "Network.requestWillBeSent":
                    request = p.get("request", {})
                    media_kind = kind(request.get("url", ""))
                    requests[p["requestId"]] = media_kind
                    emit("request", id=p["requestId"], kind=media_kind,
                         method=request.get("method"),
                         range=request.get("headers", {}).get("Range"),
                         type=p.get("type"), initiator=p.get("initiator", {}).get("type"))
                elif method == "Network.responseReceived":
                    response = p.get("response", {})
                    headers = {k.lower(): v for k,v in response.get("headers", {}).items()}
                    emit("response", id=p.get("requestId"),
                         kind=requests.get(p.get("requestId"), kind(response.get("url", ""))),
                         status=response.get("status"), mime=response.get("mimeType"),
                         range=headers.get("content-range"),
                         acceptRanges=headers.get("accept-ranges"),
                         fromDiskCache=response.get("fromDiskCache"),
                         fromServiceWorker=response.get("fromServiceWorker"))
                elif method == "Network.loadingFailed":
                    emit("loading_failed", id=p.get("requestId"),
                         kind=requests.get(p.get("requestId")),
                         error=p.get("errorText"), canceled=p.get("canceled"),
                         blockedReason=p.get("blockedReason"),
                         corsError=p.get("corsErrorStatus"))
                elif method == "Network.loadingFinished":
                    emit("loading_finished", id=p.get("requestId"),
                         kind=requests.get(p.get("requestId")),
                         bytes=p.get("encodedDataLength"))
                elif method.startswith("Media."):
                    emit("media", method=method, payload=p)
                elif "id" in event and "result" in event:
                    result = event["result"].get("result", {})
                    if result.get("type") == "object" and "value" in result:
                        emit("sample", **result["value"])
            except (OSError, websocket.WebSocketException) as exc:
                emit("disconnected", detail=str(exc))
                try:
                    ws.close()
                except Exception:
                    pass
                ws = None
                current_socket = None
                time.sleep(1)
        emit("probe_complete")


if __name__ == "__main__":
    main()
