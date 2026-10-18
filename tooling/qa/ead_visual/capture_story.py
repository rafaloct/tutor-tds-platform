#!/usr/bin/env python3
"""ADB evidence recorder for an isolated Tutor TDS QA emulator (never Play app).

Outputs genuine Android MP4 + PNG, a per-profile JSON receipt and hashes.
Runs on a single emulator only; no network credentials, raw PII or fake screens.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

QA_PACKAGE = re.compile(r"^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$")
EMULATOR_SERIAL = re.compile(r"^emulator-\d{4,5}$")
BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")
PROFILES = {
    "android35-compact": {"api": "35", "size": "720x1600", "density": "320", "font": "1.0"},
    "android35-offline": {"api": "35", "size": "720x1600", "density": "320", "font": "1.0"},
    "android36-large-text": {"api": "36", "size": "1080x2400", "density": "420", "font": "1.5"},
}
MAX_SECONDS = 180


class QAError(RuntimeError):
    pass


def run(argv: list[str], *, timeout: int = 20, check: bool = True,
        binary: bool = False) -> str | bytes:
    result = subprocess.run(argv, check=False, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise QAError(f"Comando de teste falhou (exit {result.returncode}): {argv[0]}.")
    return result.stdout if binary else result.stdout.decode("utf-8", "replace").strip()


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def adb(executable: str, serial: str, *args: str, timeout: int = 20,
        binary: bool = False, check: bool = True) -> str | bytes:
    return run([executable, "-s", serial, *args], timeout=timeout, binary=binary, check=check)


def screenshot(executable: str, serial: str, base: Path, label: str) -> dict:
    name = f"{label}.png"
    output = base / name
    result = adb(executable, serial, "exec-out", "screencap", "-p", timeout=20, binary=True)
    if not isinstance(result, bytes) or not result.startswith(b"\x89PNG"):
        raise QAError(f"Screenshot {label} inválido.")
    output.write_bytes(result)
    return {"file": name, "sha256": sha(output), "bytes": output.stat().st_size,
            "utc": datetime.now(timezone.utc).isoformat()}


def parse_hierarchy(raw: str | bytes) -> list[dict]:
    """Parse a *complete* hierarchy; never log raw XML or user-visible text."""
    value = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else raw
    start = value.find("<?xml")
    if start < 0:
        start = value.find("<hierarchy")
    end = value.rfind("</hierarchy>")
    if start < 0 or end < start:
        raise QAError("UI hierarchy missing or incomplete")
    try:
        root = ET.fromstring(value[start:end + len("</hierarchy>")])
    except ET.ParseError as exc:
        raise QAError("UI hierarchy XML invalid") from exc
    if root.tag != "hierarchy":
        raise QAError("UI hierarchy root unexpected")
    records = []
    for node in root.iter("node"):
        attrs = node.attrib
        bounds = BOUNDS.fullmatch(attrs.get("bounds", ""))
        if bounds:
            coords = tuple(map(int, bounds.groups()))
            records.append({
                "label": " ".join((attrs.get("text", ""), attrs.get("content-desc", ""))).strip(),
                "resource_id": attrs.get("resource-id", ""),
                "bounds": coords,
                "clickable": attrs.get("clickable") == "true",
                "enabled": attrs.get("enabled") == "true",
            })
    return records


def visible_nodes(executable: str, serial: str) -> list[dict]:
    # UIAutomator dumps during Flutter's splash/first frame can be empty or
    # truncated; wait for a complete hierarchy rather than failing on one read.
    target = "/sdcard/qa-tds-uidump.xml"
    for attempt in range(3):
        adb(executable, serial, "shell", "uiautomator", "dump", target,
            timeout=25, check=False)
        raw = adb(executable, serial, "exec-out", "cat", target,
                  timeout=15, check=False)
        try:
            nodes = parse_hierarchy(raw)
            if nodes:
                return nodes
        except QAError:
            pass
        if attempt < 2:
            time.sleep(2)
    return []


def locate_node(executable: str, serial: str, needle: str, *,
                resource_id: str = "", timeout: int = 65) -> dict | None:
    end = time.monotonic() + timeout
    wanted = needle.casefold().strip()
    while time.monotonic() < end:
        nodes = visible_nodes(executable, serial)
        # Prefer the stable Flutter Semantics identifier when the app exposes it,
        # then Android content-desc/text. ValueKey alone is not an Android id.
        matches = [
            n for n in nodes if n["enabled"] and
            (resource_id and (n["resource_id"] == resource_id or
                              n["resource_id"].endswith(":id/" + resource_id)))
        ]
        if not matches:
            matches = [n for n in nodes if n["enabled"] and wanted in n["label"].casefold()]
        for candidate in matches:
            left, top, right, bottom = candidate["bounds"]
            if right > left and bottom > top:
                return candidate
        time.sleep(2)
    return None


def tap_text(executable: str, serial: str, needle: str, *,
             resource_id: str = "", timeout: int = 35) -> bool:
    candidate = locate_node(executable, serial, needle, resource_id=resource_id,
                            timeout=timeout)
    if candidate is None:
        return False
    left, top, right, bottom = candidate["bounds"]
    adb(executable, serial, "shell", "input", "tap",
        str((left + right) // 2), str((top + bottom) // 2))
    return True


def ensure_isolated(executable: str, serial: str, package: str, profile: str) -> dict:
    if not EMULATOR_SERIAL.fullmatch(serial):
        raise QAError("Proibido capturar ou alterar aparelhos físicos por este runner.")
    if not QA_PACKAGE.fullmatch(package):
        raise QAError("Pacote deve ser QA isolado. Nunca usar o app da Play Store.")
    emulator = str(adb(executable, serial, "shell", "getprop", "ro.kernel.qemu"))
    api = str(adb(executable, serial, "shell", "getprop", "ro.build.version.sdk"))
    if emulator != "1" or api != PROFILES[profile]["api"]:
        raise QAError(f"Identidade do AVD divergente: emulator={emulator}, API={api}.")
    packages = str(adb(executable, serial, "shell", "pm", "list", "packages", package))
    if f"package:{package}" not in packages.splitlines():
        raise QAError(f"Aplicativo QA isolado ausente: {package}.")
    return {"android_api": api, "avd_serial": serial,
            "device_model": str(adb(executable, serial, "shell", "getprop", "ro.product.model")),
            "fingerprint": str(adb(executable, serial, "shell", "getprop", "ro.build.fingerprint"))}


def app_launch(executable: str, serial: str, package: str) -> None:
    adb(executable, serial, "shell", "am", "force-stop", package)
    result = str(adb(executable, serial, "shell", "monkey", "-p", package,
                     "-c", "android.intent.category.LAUNCHER", "1", timeout=20))
    if "Events injected: 1" not in result:
        raise QAError("App QA não abriu pelo launcher.")
    time.sleep(7)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--package", required=True)
    parser.add_argument("--profile", choices=sorted(PROFILES), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--git-sha", default="unknown")
    args = parser.parse_args()
    if not (15 <= args.seconds <= MAX_SECONDS):
        raise QAError("Gravação deve durar entre 15 e 180 segundos.")
    identity = ensure_isolated(args.adb, args.serial, args.package, args.profile)
    out = args.output
    if out.exists():
        raise QAError("Saída já existe. Não sobrescrever evidências anteriores.")
    out.mkdir(parents=True)
    report = {
        "status": "STARTED", "profile": args.profile, "package": args.package,
        "git_sha": args.git_sha, "identity": identity, "started_utc": datetime.now(timezone.utc).isoformat(),
        "evidence": [], "events": [], "notes": ["Vídeo é captura real e não contém áudio do sistema."],
    }
    original = {}
    proc = None
    remote_video = f"/sdcard/tds-evidence-{uuid.uuid4().hex}.mp4"
    begin = time.monotonic()
    try:
        for prop, command in (
            ("size", ("shell", "wm", "size")),
            ("density", ("shell", "wm", "density")),
            ("font", ("shell", "settings", "get", "system", "font_scale")),
        ):
            original[prop] = str(adb(args.adb, args.serial, *command))
        profile = PROFILES[args.profile]
        adb(args.adb, args.serial, "shell", "wm", "size", profile["size"])
        adb(args.adb, args.serial, "shell", "wm", "density", profile["density"])
        adb(args.adb, args.serial, "shell", "settings", "put", "system", "font_scale", profile["font"])
        app_launch(args.adb, args.serial, args.package)
        # Do not equate Android's launcher/splash with a fully rendered
        # Flutter screen. Only begin navigation/recording after a real node.
        landing = locate_node(args.adb, args.serial,
                              "Explorar cursos do EAD sem cadastro",
                              resource_id="ead-public-explore",
                              timeout=85)
        if landing is None:
            raise QAError("Flutter welcome action not accessible after bounded wait")
        report["events"].append("00: botão EAD acessível após primeira renderização")
        proc = subprocess.Popen(
            [args.adb, "-s", args.serial, "shell", "screenrecord",
             "--bit-rate", "5000000", "--size", "720x1600",
             "--time-limit", str(args.seconds), remote_video],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        begin = time.monotonic()
        time.sleep(2)
        report["evidence"].append(screenshot(args.adb, args.serial, out, "01-welcome"))
        if not tap_text(args.adb, args.serial, "Explorar cursos do EAD sem cadastro",
                        resource_id="ead-public-explore", timeout=18):
            raise QAError("Botão EAD desapareceu após ter ficado acessível.")
        report["events"].append("01: clique em Explorar cursos do EAD sem cadastro")
        if locate_node(args.adb, args.serial, "Ofertas publicadas:", timeout=35) is None:
            raise QAError("Navegação EAD não apresentou lista publicada; não inferir sucesso")
        report["evidence"].append(screenshot(args.adb, args.serial, out, "02-ead-catalog"))
        report["events"].append("02: catálogo exibiu contador público de ofertas")
        if args.profile == "android35-offline":
            adb(args.adb, args.serial, "shell", "svc", "wifi", "disable")
            adb(args.adb, args.serial, "shell", "svc", "data", "disable")
            report["events"].append("03: conexão desligada temporariamente em AVD QA")
            if not tap_text(args.adb, args.serial, "Atualizar cursos do EAD"):
                # Refresh is an icon: semantic target may differ across versions.
                report["notes"].append("Não localizei atualização por acessibilidade; offline sem refresh")
            time.sleep(5)
            report["evidence"].append(screenshot(args.adb, args.serial, out, "03-offline"))
        else:
            # Tapping a card title is not proof of navigation: the actionable
            # Flutter control is the per-course native learning-path button.
            if not tap_text(args.adb, args.serial, "Ver percurso e prática no app",
                            timeout=25):
                raise QAError("Botão de percurso nativo ausente no catálogo")
            if locate_node(args.adb, args.serial, "Percurso de aprendizagem",
                           timeout=35) is None:
                raise QAError("Navegação ao percurso nativo não confirmada")
            report["events"].append("03: tela Percurso de aprendizagem confirmada")
            report["evidence"].append(screenshot(args.adb, args.serial, out,
                                                 "03-learning-path"))
        report["status"] = "CAPTURED"
    except (QAError, OSError, subprocess.TimeoutExpired) as error:
        report["status"] = "BLOCKED"
        report["notes"].append(type(error).__name__ + ": " + str(error))
        try:
            report["evidence"].append(screenshot(args.adb, args.serial, out, "99-blocked"))
        except Exception:
            pass
    finally:
        # Always attempt to collect screenrecord, including on QA failure.
        # Verify MP4 container; never label an unfinished/raw stream a valid video.
        if proc:
            remaining = args.seconds - (time.monotonic() - begin)
            if remaining > 0:
                time.sleep(remaining + 2)
            try:
                proc.wait(timeout=16)
            except subprocess.TimeoutExpired:
                report["notes"].append("Screenrecord timeout; recording incomplete")
            report["screenrecord_exit"] = proc.poll()
            clip = out / "raw-android-screenrecord.mp4"
            try:
                if proc.poll() is not None:
                    try:
                        adb(args.adb, args.serial, "pull", remote_video, str(clip),
                            timeout=65)
                    except (QAError, subprocess.TimeoutExpired):
                        # ADB pull sometimes fails on emulator file services.
                        # Streaming from the same explicitly scoped QA path is
                        # an independent fallback; never read other device data.
                        raw = adb(args.adb, args.serial, "exec-out", "cat",
                                  remote_video, timeout=65, binary=True)
                        if isinstance(raw, bytes):
                            clip.write_bytes(raw)
                    if (clip.exists() and clip.stat().st_size > 1024 and
                            clip.read_bytes()[4:8] == b"ftyp"):
                        report["evidence"].append({
                            "file": clip.name, "sha256": sha(clip),
                            "bytes": clip.stat().st_size,
                            "utc": datetime.now(timezone.utc).isoformat()})
                    else:
                        report["notes"].append("MP4 ausente ou contêiner inválido")
                        clip.unlink(missing_ok=True)
            except (QAError, OSError, subprocess.TimeoutExpired) as exc:
                report["notes"].append("MP4 não recuperado: " + type(exc).__name__)
            finally:
                # Best-effort cleanup of our randomly named *emulator* media.
                try:
                    adb(args.adb, args.serial, "shell", "rm", "-f", remote_video,
                        timeout=10, check=False)
                except (QAError, OSError, subprocess.TimeoutExpired):
                    pass
        # Reset only this isolated emulator, never touch the physical device.
        try:
            if args.profile == "android35-offline":
                adb(args.adb, args.serial, "shell", "svc", "wifi", "enable")
                adb(args.adb, args.serial, "shell", "svc", "data", "enable")
            adb(args.adb, args.serial, "shell", "wm", "size", "reset")
            adb(args.adb, args.serial, "shell", "wm", "density", "reset")
            adb(args.adb, args.serial, "shell", "settings", "put", "system",
                "font_scale", "1.0")
        except Exception:
            report["notes"].append("Falha ao restaurar display; AVD read-only descartável.")
        if (report["status"] == "CAPTURED" and
                not any(e.get("file", "").endswith(".mp4") for e in report["evidence"])):
            report["status"] = "BLOCKED"
            report["notes"].append("A sequência de telas não comprova vídeo MP4 válido")
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        (out / "receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"status": report["status"], "profile": args.profile,
                          "evidence": len(report["evidence"]), "output": str(out)}, ensure_ascii=False))
    return 0 if report["status"] == "CAPTURED" else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (QAError, OSError, subprocess.TimeoutExpired) as exc:
        print("BLOCKED:", exc, file=sys.stderr)
        sys.exit(2)
