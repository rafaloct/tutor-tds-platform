from __future__ import annotations

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "ops" / "promotion_preflight.py"
SPEC = importlib.util.spec_from_file_location("promotion_preflight", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
promotion_preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(promotion_preflight)


def _document(paths: dict[str, dict], schemas: dict[str, dict] | None = None) -> dict:
    return {
        "paths": paths,
        "components": {"schemas": schemas or {}},
    }


def test_compare_reports_additions_schema_changes_and_aab_gap() -> None:
    production = _document(
        {"/auth/login": {"post": {"responses": {"200": {}}}}},
        {"Shared": {"type": "string"}},
    )
    candidate = _document(
        {
            "/auth/login": {"post": {"responses": {"200": {}}}},
            "/classes": {"get": {"responses": {"200": {}}}},
        },
        {"Shared": {"type": "integer"}},
    )

    result = promotion_preflight.compare(production, candidate)

    assert result["only_candidate"] == ["GET /classes"]
    assert result["only_production"] == []
    assert "GET /classes" in result["aab_14_missing_in_production"]
    assert "Shared" in result["common_schema_changes"]


def test_production_compose_uses_one_candidate_image_for_api_and_worker() -> None:
    compose = (
        Path(__file__).resolve().parents[1] / "docker-compose.production.yml"
    ).read_text(encoding="utf-8")

    assert compose.count(
        "image: ${PRODUCTION_API_IMAGE:-tutor-tds-api:production-local}"
    ) == 2
