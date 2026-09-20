from __future__ import annotations

import argparse
import json
from urllib import parse, request


def get_json(base_url: str, path: str) -> dict[str, object]:
    url = parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    with request.urlopen(url, timeout=10) as response:
        if response.status != 200:
            raise RuntimeError(f"{path} respondeu {response.status}")
        return json.loads(response.read())


def main() -> None:
    parser = argparse.ArgumentParser(description="Smoke test Tutor TDS API")
    parser.add_argument("base_url")
    arguments = parser.parse_args()
    health = get_json(arguments.base_url, "/health")
    if health != {"status": "ok", "database": "available"}:
        raise RuntimeError(f"health inesperado: {health}")
    courses = get_json(arguments.base_url, "/courses")
    if not isinstance(courses.get("courses"), list):
        raise RuntimeError("contrato de cursos inválido")
    print("Smoke test concluído: health e cursos OK")


if __name__ == "__main__":
    main()
