#!/usr/bin/env python3
"""Read-only WordPress registration navigation using an existing isolated APK.

No build, account creation, form submission, release or browser setting changes.
Requires an emulator and an explicit APK digest/source/package/ADB port.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from urllib.request import urlopen

PLAY = "com.tutortds_cartilhas"
QA_RE = re.compile(re.escape(PLAY) + r"\.dev\.dynamicqa\.r[0-9a-f]{32}")
HOST = "ead.ipexdesenvolvimento.cloud"
CTA = "Criar conta gratuita no EAD"
STEPS = ("artifact", "device", "installed_apk", "abi", "launch", "app_ui",
         "handoff", "registration_form", "return_to_app", "play_preserved")


class CheckFailed(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise CheckFailed(message)


def digest(path):
    with open(path, "rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def flutter_abis(path):
    with zipfile.ZipFile(path) as apk:
        return sorted(n.split("/")[1] for n in apk.namelist()
                      if re.fullmatch(r"lib/[^/]+/libflutter\.so", n))


def parse_badging(text):
    pkg = re.search(r"^package: name='([^']+)'", text, re.M)
    activity = re.search(r"^launchable-activity: name='([^']+)'", text, re.M)
    require(pkg and activity, "APK package/launcher metadata absent")
    return pkg[1], activity[1]


def resumed_component(text):
    matches = re.findall(r"(?:topResumedActivity|mResumedActivity)=ActivityRecord\{[^\n]*?\bu\d+\s+([^\s}]+/[^\s}]+)", text)
    require(len(set(matches)) == 1, "no unambiguous resumed activity")
    return matches[0]


def current_tree(text, package):
    require("ERROR:" not in text and "null root" not in text.lower(), "UI dump failed")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise CheckFailed("UI dump is not XML") from exc
    require(root.tag == "hierarchy", "UI hierarchy missing")
    require(any(n.get("package") == package for n in root.iter("node")),
            "UI belongs to another package (or has no app nodes)")
    return root


def center(node):
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    require(match is not None, "missing UI bounds")
    x1, y1, x2, y2 = map(int, match.groups())
    require(x2 > x1 and y2 > y1, "empty UI bounds")
    return (x1 + x2) // 2, (y1 + y2) // 2


def select_cta(root, package):
    nodes = [n for n in root.iter("node") if n.get("package") == package
             and CTA in (n.get("text", ""), n.get("content-desc", ""))
             and n.get("enabled") == "true" and n.get("clickable") == "true"]
    require(len(nodes) == 1, "expected one enabled registration CTA")
    return nodes[0]


def registration_url(url):
    p = urlsplit(url)
    try:
        authority_ok = p.hostname == HOST and p.port is None and not p.username and not p.password
    except ValueError:
        return False
    return (p.scheme == "https" and authority_ok and p.path == "/cadastro/"
            and not p.fragment and parse_qs(p.query, keep_blank_values=True) == {
                "utm_source": ["tutor_tds_app"], "utm_medium": ["app"],
                "utm_campaign": ["ead_signup"], "utm_content": ["welcome_signup"]})


def form_visible(root, browser):
    """Require rendered web content and native accessibility edit controls, not toolbar URL."""
    for web in root.iter("node"):
        if web.get("class") != "android.webkit.WebView" or web.get("package") != browser:
            continue
        nodes = list(web.iter("node"))
        words = " ".join(n.get("text", "") + " " + n.get("content-desc", "") for n in nodes).casefold()
        edits = [n for n in nodes if n.get("class") == "android.widget.EditText"
                 and n.get("enabled") == "true"]
        if (len(edits) >= 3 and "nome" in words and "e-mail" in words
                and "senha" in words and "criar conta" in words):
            return True
    return False


FORM_PROBE = """JSON.stringify({url:location.href,ready:document.readyState,
visible:document.visibilityState,focus:document.hasFocus(),forms:[...document.forms]
.filter(f=>f.querySelector('input[name="action"]')?.value==='tds_cadastro')
.map(f=>({action:new URL(f.getAttribute('action')||location.href,location.href).href,
method:f.method,institutional:true,fields:[...f.elements].map(e=>{
const r=e.getBoundingClientRect();const s=getComputedStyle(e);return {
name:e.name,type:e.type,disabled:e.disabled,
visible:r.width>0&&r.height>0&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth
&&s.visibility!=='hidden'&&s.display!=='none'&&s.opacity!=='0'};})}))})"""


def dom_form_loaded(data):
    if not (registration_url(data.get("url", "")) and data.get("ready") == "complete"
            and data.get("visible") == "visible" and data.get("focus") is True):
        return False
    for form in data.get("forms", []):
        if (form.get("action") != f"https://{HOST}/wp-admin/admin-post.php"
                or form.get("method") != "post" or form.get("institutional") is not True):
            continue
        fields = [f for f in form.get("fields", []) if f.get("visible") and not f.get("disabled")]
        required = {("nome", "text"), ("email", "email"), ("senha", "password")}
        if required <= {(f.get("name"), f.get("type")) for f in fields} and any(
                f.get("type") == "submit" for f in fields):
            return True
    return False


class Runner:
    def __init__(self, args):
        self.a = args
        self.out = Path(args.output)
        self.out.mkdir(parents=True, exist_ok=False)
        self.run_id = uuid.uuid4().hex
        self.record = {"schema_version": 1, "started_utc": datetime.now(timezone.utc).isoformat(),
                       "source_commit": args.source_commit, "apk_sha256": args.sha256,
                       "package": args.package, "serial": args.serial, "adb_port": args.adb_port,
                       "results": {s: "NOT_RUN" for s in STEPS}, "e2e": "NOT_RUN",
                       "gates": {"privacy_ga4": "OPEN", "signature": "OPEN", "release": "OPEN"},
                       "build_performed": False, "form_submitted": False}
        self.stage = "artifact"
        self.forward = None
        self.before_play = None

    def save(self, name, content):
        path = self.out / name
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_bytes(content.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8"))

    def command(self, cmd, timeout=30, combined=False):
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            raise CheckFailed(f"command timed out after {timeout}s: {cmd[0]}") from exc
        require(proc.returncode == 0, "command failed: " + proc.stderr.decode("utf-8", "replace")[:300])
        return proc.stdout + proc.stderr if combined else proc.stdout

    def adb(self, *args, timeout=30, binary=False, combined=False):
        data = self.command([self.a.adb, "-P", str(self.a.adb_port), "-s", self.a.serial, *args], timeout, combined)
        return data if binary else data.decode("utf-8", "replace").strip()

    def shell(self, *args, **kwargs):
        return self.adb("shell", *args, **kwargs)

    def pass_step(self, name):
        self.record["results"][name] = "PASS"
        print(name + "=PASS", flush=True)

    def foreground(self):
        return resumed_component(self.shell("dumpsys", "activity", "activities", timeout=15))

    def play_snapshot(self):
        data = self.shell("dumpsys", "package", PLAY, timeout=15)
        return [line.strip() for line in data.splitlines() if re.match(
            r"\s*(versionCode=|versionName=|codePath=|lastUpdateTime=)", line)]

    def snapshot(self, label, package):
        before = self.foreground()
        require(before.split("/")[0] == package, f"wrong foreground before {label}: {before}")
        # Never read a previous run's file, even when uiautomator returns exit=0 on failure.
        remote = f"/sdcard/tds-{self.run_id}-{label}.xml"
        message = self.shell("uiautomator", "dump", remote, timeout=35, combined=True)
        self.save(label + "-dump.txt", message)
        require("UI hierchary dumped to:" in message or "UI hierarchy dumped to:" in message,
                "UIAutomator produced no hierarchy: " + message[:160])
        xml = self.shell("cat", remote, timeout=10)
        tree = current_tree(xml, package)
        after = self.foreground()
        require(before == after, "foreground changed during UI capture")
        self.save(label + ".xml", xml)
        png = self.adb("exec-out", "screencap", "-p", binary=True, timeout=15)
        require(png.startswith(b"\x89PNG\r\n\x1a\n"), "screenshot is not PNG")
        self.save(label + ".png", png)
        self.save(label + "-activity.txt", after + "\n")
        self.shell("rm", remote, timeout=10)
        return tree

    def swipe_tree(self, root):
        scroll = next((n for n in root.iter("node") if n.get("scrollable") == "true"), None)
        require(scroll is not None, "target missing; no scrollable node")
        x, y = center(scroll)
        bounds = list(map(int, re.findall(r"\d+", scroll.get("bounds"))))
        delta = max(1, (bounds[3] - bounds[1]) // 4)
        self.shell("input", "swipe", str(x), str(y + delta), str(x), str(y - delta), "500")

    def browser_targets(self):
        with urlopen(f"http://127.0.0.1:{self.forward}/json/list", timeout=5) as response:
            return json.load(response)

    def browser_form(self, target):
        try:
            import websocket
        except ImportError as exc:
            raise CheckFailed("websocket-client required for read-only Chrome DOM verification") from exc
        # Only the already-discovered active target; no navigation, input, submit or cookie reads.
        endpoint = urlsplit(target["webSocketDebuggerUrl"])
        require(endpoint.scheme == "ws" and endpoint.hostname in ("127.0.0.1", "localhost")
                and endpoint.port == int(self.forward), "non-local CDP endpoint refused")
        ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=10, suppress_origin=True)
        try:
            ws.send(json.dumps({"id": 1, "method": "Runtime.evaluate",
                                "params": {"expression": FORM_PROBE, "returnByValue": True}}))
            for _ in range(100):
                message = json.loads(ws.recv())
                if message.get("id") == 1:
                    require("exceptionDetails" not in message.get("result", {}), "DOM probe failed")
                    return json.loads(message["result"]["result"]["value"])
            raise CheckFailed("CDP response missing")
        finally:
            ws.close()

    def execute(self):
        a = self.a
        require(QA_RE.fullmatch(a.package), "production/legacy package refused")
        require(re.fullmatch(r"[0-9a-f]{40}", a.source_commit), "source SHA required")
        require(a.package.endswith("r" + a.source_commit[:32]), "package does not match source SHA")
        require(digest(a.apk) == a.sha256, "APK digest mismatch")
        pkg, activity = parse_badging(self.command([a.aapt, "dump", "badging", a.apk]).decode())
        require(pkg == a.package, "APK manifest package mismatch")
        component = pkg + "/" + activity
        engines = flutter_abis(a.apk)
        self.record["flutter_engine_abis"] = engines
        self.pass_step("artifact")

        self.stage = "device"
        require(re.fullmatch(r"emulator-\d+", a.serial), "physical device refused by this runner")
        require(self.adb("get-state") == "device", "device is not online")
        require(self.shell("getprop", "sys.boot_completed") == "1", "emulator not booted")
        self.record["device_abis"] = self.shell("getprop", "ro.product.cpu.abilist").split(",")
        self.record["android_api"] = self.shell("getprop", "ro.build.version.sdk")
        self.before_play = self.play_snapshot()
        self.record["play_before"] = self.before_play
        self.pass_step("device")

        self.stage = "installed_apk"
        if a.install_abi:
            require(a.install_abi in engines and a.install_abi in self.record["device_abis"],
                    "requested ABI not supported by Flutter engine/device")
            result = self.adb("install", "--no-streaming", "-r", "-t", "--abi", a.install_abi, a.apk, timeout=180)
            self.save("install.txt", result)
            require("Success" in result, "isolated installation failed")
        paths = self.shell("pm", "path", pkg).splitlines()
        require(len(paths) == 1 and paths[0].startswith("package:"), "expected one installed base APK")
        installed = self.shell("sha256sum", paths[0][8:]).split()[0]
        require(installed == a.sha256, "installed APK differs from supplied artifact")
        self.record["installed_sha256"] = installed
        self.pass_step("installed_apk")

        self.stage = "abi"
        metadata = self.shell("dumpsys", "package", pkg)
        match = re.search(r"primaryCpuAbi=(\S+)", metadata)
        require(match is not None, "installed ABI missing")
        self.record["primary_cpu_abi"] = match[1]
        require(match[1] in engines, "installed ABI has no libflutter.so; install exact APK with matching --install-abi")
        self.pass_step("abi")

        self.stage = "launch"
        resolved = self.shell("cmd", "package", "resolve-activity", "--brief", "-a",
                              "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", pkg)
        require(component in resolved.splitlines(), "resolved launcher differs from APK manifest")
        if a.resume:
            require(self.foreground() == component, "resume requires exact target already foreground")
            start = "Status: ok\nRESUMED existing activity; not cold-start evidence"
        else:
            start = self.shell("am", "start", "-W", "-S", "-n", component, "-a", "android.intent.action.MAIN",
                               "-c", "android.intent.category.LAUNCHER", "-f", "0x10008000", timeout=50)
        self.record["cold_start_requested"] = not a.resume
        self.save("launch.txt", start)
        # Android's -W timeout is shorter than cold Flutter/translation startup.
        # Record it, but use independently observed foreground/UI as readiness.
        require("Status: ok" in start or "Status: timeout" in start,
                "activity manager rejected launch")
        self.record["am_start_status"] = "timeout" if "Status: timeout" in start else "ok"
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            try:
                if self.foreground() == component and self.shell("pidof", pkg):
                    break
            except CheckFailed:
                pass
            time.sleep(1)
        else:
            raise CheckFailed("target did not become foreground within 60s")
        self.pass_step("launch")

        self.stage = "app_ui"
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            windows = self.shell("dumpsys", "window", "windows", timeout=15)
            blocks = re.split(r"\n  Window #\d+", windows)
            if any(component in b and "mDrawState=HAS_DRAWN" in b and "shown=true" in b
                   for b in blocks):
                break
            time.sleep(1)
        else:
            raise CheckFailed("target window did not draw within 60s")
        tree = None
        for attempt in range(2):
            try:
                tree = self.snapshot(f"01-welcome-{attempt + 1}", pkg)
                break
            except CheckFailed:
                if attempt == 1:
                    raise
                time.sleep(3)
        try:
            button = select_cta(tree, pkg)
        except CheckFailed:
            self.swipe_tree(tree)
            tree = self.snapshot("01-welcome-scrolled", pkg)
            button = select_cta(tree, pkg)
        self.pass_step("app_ui")
        self.stage = "handoff"
        # A pre-existing matching page must never be mistaken for a new handoff.
        self.forward = self.adb("forward", "tcp:0", "localabstract:chrome_devtools_remote")
        require(self.forward.isdigit(), "ADB forward did not allocate a port")
        try:
            before_targets = self.browser_targets()
        except OSError:
            before_targets = []  # Chrome not running yet; no debugging socket.
        require(not any(registration_url(t.get("url", "")) for t in before_targets),
                "existing registration target would make handoff ambiguous; close it before a new run")
        require(self.foreground() == component, "target lost foreground before CTA")
        x, y = center(button)
        self.record["cta_tap"] = {"text": CTA, "x": x, "y": y, "from": "01-welcome*.xml"}
        self.shell("input", "tap", str(x), str(y))
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            try:
                browser_component = self.foreground()
                if browser_component.split("/")[0] == "com.android.chrome":
                    break
            except CheckFailed:
                pass  # No resumed activity during the app/browser transition.
            time.sleep(1)
        else:
            raise CheckFailed("Chrome handoff not observed; no direct URL launch used as substitute")
        self.record["browser_component"] = browser_component
        # Read only existing Chrome targets; never create/navigate a browser tab via CDP.
        targets = []
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            try:
                targets = self.browser_targets()
                matching = [t for t in targets if t.get("type") == "page" and registration_url(t.get("url", ""))]
                if len(matching) == 1:
                    break
            except (OSError, ValueError):
                pass
            time.sleep(1)
        else:
            raise CheckFailed("exact registration URL not observed in browser")
        self.record["browser_url"] = matching[0]["url"]
        self.save("browser-target.json", json.dumps({k: matching[0].get(k) for k in ("id", "type", "title", "url")}, indent=2))
        self.pass_step("handoff")
        self.stage = "registration_form"
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            form = self.browser_form(matching[0])
            self.save("form-dom.json", json.dumps(form, indent=2, ensure_ascii=False))
            if dom_form_loaded(form):
                break
            time.sleep(2)
        else:
            raise CheckFailed("focused institutional form with visible fields not loaded within 60s")
        tree = self.snapshot("02-form", "com.android.chrome")
        self.record["form_oracle"] = "focused Chrome DOM + Android screenshot"
        self.record["uiautomator_exposes_web_form"] = form_visible(tree, "com.android.chrome")
        require(dom_form_loaded(self.browser_form(matching[0])), "form changed during screenshot")
        self.pass_step("registration_form")
        self.record["e2e"] = "PASS"
        self.stage = "return_to_app"
        close = next((n for n in tree.iter("node") if n.get("content-desc") in
                      ("Close tab", "Fechar guia") and n.get("enabled") == "true"), None)
        if close is not None:
            require(self.foreground().split("/")[0] == "com.android.chrome", "browser lost foreground")
            x, y = center(close)
            self.shell("input", "tap", str(x), str(y))
            self.record["return_action"] = "Custom Tab close control from UI tree"
        else:
            self.shell("input", "keyevent", "4")
            self.record["return_action"] = "Android Back"
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                if self.foreground() == component:
                    break
            except CheckFailed:
                pass
            time.sleep(1)
        self.snapshot("03-return", pkg)
        self.pass_step("return_to_app")

    def run(self):
        try:
            self.execute()
        except (CheckFailed, OSError, ValueError) as exc:
            self.record["results"][self.stage] = "FAIL"
            self.record["failure"] = {"step": self.stage, "reason": str(exc)}
            if self.stage in ("handoff", "registration_form"):
                self.record["e2e"] = "FAIL"
            print(self.stage + "=FAIL: " + str(exc), flush=True)
        finally:
            if self.forward:
                try:
                    self.adb("forward", "--remove", "tcp:" + self.forward)
                except (CheckFailed, OSError) as exc:
                    self.record["cleanup_error"] = str(exc)
            if self.before_play is not None:
                try:
                    after = self.play_snapshot()
                    self.record["play_after"] = after
                    require(after == self.before_play, "Play package changed")
                    self.pass_step("play_preserved")
                except (CheckFailed, OSError) as exc:
                    self.record["results"]["play_preserved"] = "FAIL"
                    self.record["play_error"] = str(exc)
            self.record["finished_utc"] = datetime.now(timezone.utc).isoformat()
            self.record["evidence_sha256"] = {p.name: digest(p) for p in self.out.iterdir() if p.is_file()}
            self.save("receipt.json", json.dumps(self.record, indent=2, ensure_ascii=False) + "\n")
        return 0 if all(v == "PASS" for v in self.record["results"].values()) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("adb", "aapt", "serial", "apk", "sha256", "source-commit", "package", "output"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--adb-port", type=int, required=True)
    parser.add_argument("--install-abi", choices=("arm64-v8a", "x86_64", "armeabi-v7a"))
    parser.add_argument("--resume", action="store_true", help="verify already open exact QA app; never claim cold start")
    args = parser.parse_args()
    return Runner(args).run()


if __name__ == "__main__":
    raise SystemExit(main())
