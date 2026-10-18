#!/usr/bin/env python3
"""Read-only Android 35 QA replay against *synthetic* private LearnPress only.

Requires emulator-5554 API35, the exact isolated debug package, and an
adb reverse already pointing to the loopback-only audited proxy.
Never uses a physical Android device, production data, or login.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

PACKAGE = "com.tutortds_cartilhas.dev.dynamicqa.r00ad5b420ca34272893828e84024326c"
SERIAL = "emulator-5554"
QA_ADB_SERVER_PORT = "5038"  # separate from user/physical-device ADB on 5037
BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


class Blocked(RuntimeError):
    pass


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def sha(file: Path):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def adb(adb_exe, *args, timeout=25, binary=False, check=True):
    p = subprocess.run([adb_exe, "-P", QA_ADB_SERVER_PORT, "-s", SERIAL, *args], capture_output=True, timeout=timeout)
    if check and p.returncode:
        raise Blocked("ADB operation failed (code %d): %s" % (p.returncode, args[0]))
    return p.stdout if binary else p.stdout.decode("utf-8", "replace").strip()


def require_emulator(adb_exe):
    if adb(adb_exe, "shell", "getprop", "ro.kernel.qemu") != "1":
        raise Blocked("target is not an emulator")
    if adb(adb_exe, "shell", "getprop", "ro.build.version.sdk") != "35":
        raise Blocked("API is not 35")
    installed = adb(adb_exe, "shell", "pm", "list", "packages", PACKAGE)
    if ("package:" + PACKAGE) not in installed.splitlines():
        raise Blocked("isolated QA APK package missing")
    reverse = adb(adb_exe, "reverse", "--list")
    if "tcp:18731 tcp:18733" not in reverse:
        raise Blocked("private audited adb reverse missing")


def parse_nodes(text):
    begin = text.find("<?xml")
    if begin < 0:
        begin = text.find("<hierarchy")
    end = text.rfind("</hierarchy>")
    if begin < 0 or end < begin:
        raise Blocked("hierarchy incomplete")
    try:
        root = ET.fromstring(text[begin:end + len("</hierarchy>")])
    except ET.ParseError:
        raise Blocked("hierarchy malformed")
    if root.tag != "hierarchy":
        raise Blocked("hierarchy unexpected root")
    records = []
    for node in root.iter("node"):
        a = node.attrib
        match = BOUNDS.fullmatch(a.get("bounds", ""))
        if match:
            records.append({
                "label": (a.get("content-desc", "") + " " + a.get("text", "")).strip(),
                "id": a.get("resource-id", ""),
                "bounds": [int(x) for x in match.groups()],
                "enabled": a.get("enabled") == "true",
            })
    return records


def dump_nodes(adb_exe):
    for i in range(3):
        adb(adb_exe, "shell", "uiautomator", "dump",
            "/sdcard/tds-qa-private-hierarchy.xml", timeout=35, check=False)
        raw = adb(adb_exe, "exec-out", "cat",
                  "/sdcard/tds-qa-private-hierarchy.xml", timeout=18, check=False)
        try:
            parsed = parse_nodes(raw)
            if parsed:
                return parsed
        except Blocked:
            pass
        if i < 2:
            time.sleep(1.5)
    return []


def wait_node(adb_exe, phrase, timeout=48, resource_id=None):
    deadline = time.monotonic() + timeout
    target = phrase.casefold()
    while time.monotonic() < deadline:
        nodes = dump_nodes(adb_exe)
        found = [n for n in nodes if n["enabled"] and resource_id and
                 (n["id"] == resource_id or n["id"].endswith(":id/" + resource_id))]
        if not found:
            found = [n for n in nodes if n["enabled"] and target in n["label"].casefold()]
        for node in found:
            a, b, c, d = node["bounds"]
            if c > a and d > b:
                return node
        time.sleep(1.8)
    return None


def tap(adb_exe, phrase, *, timeout=40, resource_id=None):
    node = wait_node(adb_exe, phrase, timeout=timeout, resource_id=resource_id)
    if not node:
        raise Blocked("required synthetic UI action unavailable: " + phrase)
    l, t, r, b = node["bounds"]
    adb(adb_exe, "shell", "input", "tap", str((l+r)//2), str((t+b)//2))


def screenshot(adb_exe, out: Path, name, report):
    data = adb(adb_exe, "exec-out", "screencap", "-p", binary=True)
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise Blocked("Android screenshot not a PNG")
    file = out / name
    file.write_bytes(data)
    report["files"].append({"name": name, "size": len(data), "sha256": sha(file)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if not args.adb.is_file() or args.out.exists():
        raise Blocked("ADB missing or output already exists")
    require_emulator(str(args.adb))
    args.out.mkdir(parents=True)
    report = {"status": "STARTED", "started_utc": now(),
              "apk_package": PACKAGE, "serial": SERIAL,
              "adb_server_port": QA_ADB_SERVER_PORT,
              "files": [], "steps": [], "notes": []}
    remote = "/sdcard/tds-private-%s.mp4" % uuid.uuid4().hex
    proc = None
    recording_start = 0
    try:
        adb(str(args.adb), "shell", "am", "force-stop", PACKAGE)
        launch = adb(str(args.adb), "shell", "monkey", "-p", PACKAGE,
                     "-c", "android.intent.category.LAUNCHER", "1", timeout=30)
        if "Events injected: 1" not in launch:
            raise Blocked("QA app launcher did not inject an event")
        if wait_node(str(args.adb), "Explorar cursos do EAD sem cadastro", timeout=85) is None:
            raise Blocked("Flutter did not render the EAD welcome action")
        proc = subprocess.Popen([str(args.adb), "-P", QA_ADB_SERVER_PORT, "-s", SERIAL, "shell", "screenrecord",
                                 "--size", "720x1280", "--bit-rate", "4500000",
                                 "--time-limit", "75", remote],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        recording_start = time.monotonic()
        time.sleep(2)
        screenshot(str(args.adb), args.out, "01-welcome.png", report)
        tap(str(args.adb), "Explorar cursos do EAD sem cadastro")
        if wait_node(str(args.adb), "LABORATÓRIO INTERNO", timeout=65) is None:
            raise Blocked("synthetic lab entry missing: not a private QA APK")
        screenshot(str(args.adb), args.out, "02-lab-catalog.png", report)
        report["steps"].append("catalog_lab_visible")
        tap(str(args.adb), "LABORATÓRIO INTERNO")
        if wait_node(str(args.adb), "SAF QA", timeout=60) is None:
            raise Blocked("synthetic curriculum not displayed")
        screenshot(str(args.adb), args.out, "03-private-path.png", report)
        report["steps"].append("private_curriculum_visible")
        tap(str(args.adb), "Ler conteúdo autorizado no Tutor TDS", timeout=55)
        if wait_node(str(args.adb), "Aula do EAD", timeout=45) is None:
            raise Blocked("authorized lesson screen not visible")
        if wait_node(str(args.adb), "SAF QA", timeout=25) is None:
            raise Blocked("synthetic lesson content not visible")
        screenshot(str(args.adb), args.out, "04-authorized-lesson.png", report)
        report["steps"].append("authorized_lesson_visible")
        tap(str(args.adb), "Atualizar aula do LearnPress", timeout=20)
        if wait_node(str(args.adb), "Aula do EAD", timeout=35) is None:
            raise Blocked("lesson refresh failed")
        screenshot(str(args.adb), args.out, "05-lesson-refreshed.png", report)
        report["steps"].append("lesson_refreshed_same_apk")
        tap(str(args.adb), "Voltar", timeout=25)
        if wait_node(str(args.adb), "Percurso de aprendizagem", timeout=35) is None:
            raise Blocked("return to curriculum after lesson failed")
        tap(str(args.adb), "Atualizar percurso", timeout=30)
        time.sleep(5)
        if wait_node(str(args.adb), "SAF QA", timeout=35) is None:
            raise Blocked("curriculum refresh failed")
        screenshot(str(args.adb), args.out, "06-curriculum-refreshed.png", report)
        report["steps"].append("curriculum_revalidation_requested_same_apk")
        report["status"] = "NAVIGATION_PASS"
    except (Blocked, OSError, subprocess.TimeoutExpired) as exc:
        report["status"] = "BLOCKED"
        report["notes"].append(type(exc).__name__ + ": " + str(exc))
        try:
            screenshot(str(args.adb), args.out, "99-blocked.png", report)
        except Exception:
            pass
    finally:
        if proc:
            remaining = 75 - (time.monotonic() - recording_start)
            if remaining > 0:
                time.sleep(remaining + 2)
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                report["notes"].append("Screenrecord not finalized in time")
            report["screenrecord_exit"] = proc.poll()
            if proc.poll() is not None:
                clip = args.out / "raw-android-screenrecord.mp4"
                try:
                    adb(str(args.adb), "pull", remote, str(clip), timeout=60)
                except (Blocked, subprocess.TimeoutExpired):
                    raw = adb(str(args.adb), "exec-out", "cat", remote,
                              binary=True, timeout=60)
                    if isinstance(raw, bytes):
                        clip.write_bytes(raw)
                if (clip.is_file() and clip.stat().st_size > 2048 and
                    clip.read_bytes()[4:8] == b"ftyp" and
                    b"moov" in clip.read_bytes()):
                    report["files"].append({"name": clip.name,
                                            "size": clip.stat().st_size,
                                            "sha256": sha(clip)})
                else:
                    report["notes"].append("MP4 not verified")
                    clip.unlink(missing_ok=True)
            adb(str(args.adb), "shell", "rm", "-f", remote, check=False)
        if report["status"] == "NAVIGATION_PASS" and (
                report.get("screenrecord_exit") != 0 or
                not any(x["name"].endswith(".mp4") for x in report["files"])):
            report["status"] = "BLOCKED"
            report["notes"].append("Original Android screenrecord did not exit cleanly")
        report["finished_utc"] = now()
        (args.out / "receipt.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"status": report["status"], "steps": report["steps"],
                          "files": len(report["files"])}, ensure_ascii=False))
    return 0 if report["status"] == "NAVIGATION_PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
