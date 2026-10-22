"""Fail-closed offline audit. DO NOT print expanded docker compose config: it holds secrets."""
import json
import sys

VERSION = "2026.8.5"
EXPECTED = {"postgresql", "server", "worker"}
PORTS = {("19200", "9000"), ("19443", "9443")}


def audit(data):
    if not isinstance(data, dict) or set(data.get("services", {})) != EXPECTED:
        return ["unexpected_services"]
    issues = []
    if data.get("name") not in (None, "tds_authentik_lab_20261022"):
        issues.append("unexpected_project")
    if any(isinstance(v, dict) and v.get("external") for v in data.get("volumes", {}).values()):
        issues.append("external_volume")
    for service_name, service in data["services"].items():
        if not isinstance(service, dict):
            issues.append("invalid_service")
            continue
        if service.get("privileged") or service.get("network_mode") == "host" or service.get("pid") == "host":
            issues.append("elevated_service")
        for mount in service.get("volumes", []):
            if "/var/run/docker.sock" in str(mount):
                issues.append("docker_socket")
        image = str(service.get("image", ""))
        expected = "postgres:16-alpine" if service_name == "postgresql" else f"ghcr.io/goauthentik/server:{VERSION}"
        if image not in (expected, f"docker.io/library/{expected}"):
            issues.append("unpinned_image")
        ports = service.get("ports", [])
        if not isinstance(ports, list):
            issues.append("invalid_ports")
            continue
        if service_name != "server" and ports:
            issues.append("nonserver_ports")
        if service_name == "server":
            seen = set()
            for port in ports:
                if not isinstance(port, dict):
                    issues.append("invalid_port")
                    continue
                pair = (str(port.get("published")), str(port.get("target")))
                seen.add(pair)
                if port.get("host_ip") != "127.0.0.1":
                    issues.append("public_port")
                if pair not in PORTS:
                    issues.append("unexpected_port")
            if seen != PORTS:
                issues.append("missing_ports")
    return sorted(set(issues))


def main():
    try:
        problems = audit(json.load(sys.stdin))
    except (ValueError, TypeError, AttributeError):
        problems = ["invalid_input"]
    if problems:
        print("AUTHENTIK_LAB_BLOCKED " + ",".join(problems))
        return 1
    print("AUTHENTIK_LAB_PASS loopback_only isolated pinned")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
