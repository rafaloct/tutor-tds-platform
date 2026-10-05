"""Harness ADB seguro (somente leitura) para homologação física Xiaomi QA.

Dry-run por padrão. Nenhum comando destrutivo existe; qualquer subcomando
fora da allowlist falha fechado. Somente stdlib.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone

LEGACY_PACKAGES = frozenset({"com.tutortds_cartilhas", "com.tutortds_cartilhas.dev"})
QA_PACKAGE_RE = re.compile(r"^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$")

# Allowlist de argumentos adb (após o -s <serial>). Tudo fora disso é bloqueado.
_ALLOWED_SHELL = (
    ("getprop", "ro.product.model"),
    ("getprop", "ro.product.manufacturer"),
    ("getprop", "ro.build.version.release"),
)
_FORBIDDEN_TOKENS = frozenset({
    "uninstall", "install", "install-multiple", "clear", "rm", "reboot", "root",
    "push", "pull", "screencap", "screenrecord", "input", "force-stop", "kill",
    "disable", "disable-user", "sideload", "remount", "unroot", "tcpip", "wipe",
})


class BlockedCommand(Exception):
    pass


class InvalidPackage(ValueError):
    pass


def validate_package(package: str) -> str:
    if package in LEGACY_PACKAGES:
        raise InvalidPackage("pacote legado/.dev bloqueado")
    if not QA_PACKAGE_RE.match(package or ""):
        raise InvalidPackage("pacote deve ser QA isolado com.tutortds_cartilhas.dev.dynamicqa.r<32 hex>")
    return package


def mask_serial(serial: str) -> str:
    digest = hashlib.sha256(serial.encode()).hexdigest()[:8]
    tail = serial[-2:] if len(serial) > 4 else ""
    return f"***{tail}#{digest}"


_SENSITIVE_PATTERNS = (
    (re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"), "[CPF]"),
    (re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._\-+/=]+"), "******"),
    (re.compile(r"\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*"), "[JWT]"),
    (re.compile(r"(?i)\b(password|passwd|senha|token|secret|authorization|api[_-]?key|access_token|refresh_token)\b(\s*[=:]\s*)(\"[^\"]*\"|'[^']*'|\S+)"),
     r"\1\2[REDACTED]"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[EMAIL]"),
)


def sanitize_text(text: str, serial: str | None = None) -> str:
    out = text
    if serial:
        out = out.replace(serial, mask_serial(serial))
    for pattern, repl in _SENSITIVE_PATTERNS:
        out = pattern.sub(repl, out)
    return out


def parse_adb_devices(output: str) -> list[dict]:
    devices = []
    for line in output.splitlines()[1:] if output.startswith("List of devices") else output.splitlines():
        parts = line.split()
        if len(parts) >= 2 and not line.startswith("*"):
            devices.append({"serial": parts[0], "state": parts[1]})
    return devices


def parse_package_version(dumpsys: str) -> dict:
    name = re.search(r"versionName=(\S+)", dumpsys)
    code = re.search(r"versionCode=(\d+)", dumpsys)
    return {"versionName": name.group(1) if name else None,
            "versionCode": int(code.group(1)) if code else None}


def parse_pid(output: str) -> list[int]:
    return [int(p) for p in output.split() if p.isdigit()]


def build_command(adb: str, serial: str | None, args: list[str]) -> list[str]:
    if any(a in _FORBIDDEN_TOKENS for a in args):
        raise BlockedCommand(f"comando bloqueado: {args}")
    ok = False
    if args == ["devices"]:
        ok = True
    elif args[:1] == ["shell"]:
        rest = tuple(args[1:])
        ok = (rest in _ALLOWED_SHELL
              or (len(rest) == 3 and rest[:2] == ("dumpsys", "package") and QA_PACKAGE_RE.match(rest[2]) is not None)
              or (len(rest) == 2 and rest[0] == "pidof" and QA_PACKAGE_RE.match(rest[1]) is not None)
              or (len(rest) == 3 and rest[:2] == ("pm", "path") and QA_PACKAGE_RE.match(rest[2]) is not None))
    elif args[:1] == ["logcat"]:
        ok = args[1:3] == ["-d", "-v"] and len(args) == 4 and args[3] == "threadtime"
    if not ok:
        raise BlockedCommand(f"fora da allowlist: {args}")
    return [adb] + (["-s", serial] if serial else []) + args


def run(adb: str, serial: str | None, args: list[str], execute: bool) -> str:
    cmd = build_command(adb, serial, args)
    if not execute:
        return ""
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=False).stdout


def collect(package: str, serial: str | None, execute: bool, adb: str = "adb", log_lines: int = 500) -> dict:
    validate_package(package)
    planned = [["devices"], ["shell", "getprop", "ro.product.model"],
               ["shell", "dumpsys", "package", package], ["shell", "pidof", package], ["logcat", "-d", "-v", "threadtime"]]
    report = {
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "mode": "execute" if execute else "dry-run",
        "package": package,
        "screenshot": "disabled",
        "plannedCommands": [" ".join(build_command(adb, None, a)) for a in planned],
    }
    if not execute:
        return report
    devices = [d for d in parse_adb_devices(run(adb, None, ["devices"], True)) if d["state"] == "device"]
    if serial:
        devices = [d for d in devices if d["serial"] == serial]
    if len(devices) != 1:
        raise SystemExit("exatamente um device autorizado é necessário (use --serial)")
    serial = devices[0]["serial"]
    report["device"] = {"serial": mask_serial(serial),
                        "model": run(adb, serial, ["shell", "getprop", "ro.product.model"], True).strip()}
    report["packageInfo"] = parse_package_version(run(adb, serial, ["shell", "dumpsys", "package", package], True))
    report["pids"] = parse_pid(run(adb, serial, ["shell", "pidof", package], True))
    logs = run(adb, serial, ["logcat", "-d", "-v", "threadtime"], True).splitlines()
    pkg_lines = [l for l in logs if package in l or any(str(p) in l.split()[2:3] for p in report["pids"])]
    report["logs"] = [sanitize_text(l, serial) for l in pkg_lines[-log_lines:]]
    return report


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--package", required=True, help="package QA isolado explícito")
    p.add_argument("--serial")
    p.add_argument("--adb", default="adb")
    p.add_argument("--execute", action="store_true", help="executa leitura real (padrão: dry-run)")
    a = p.parse_args(argv)
    try:
        print(json.dumps(collect(a.package, a.serial, a.execute, a.adb), indent=2, ensure_ascii=False))
    except (InvalidPackage, BlockedCommand) as e:
        print(f"BLOCKED: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
