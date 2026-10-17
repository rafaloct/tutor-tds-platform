#!/usr/bin/env python3
"""Audited LearnPress snapshot -> Tutor TDS media DRAFT bridge (Issue #216).

Read-only by default. A write requires an explicit lesson, checkpoint path,
staging URL, credentials and valid staging /version. NEVER publishes content.
WordPress supplies lesson metadata, FastAPI remains the academic authority.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

PILOT_STAGING_URL = "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
MODULE_RE = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,79}$")
YT_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
APPROVED_MAPPING = "verified_by_id_and_module"


class SyncBlocked(ValueError):
    """Unsafe or incomplete synchronization input."""


def read_object(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SyncBlocked(f"Arquivo JSON deve ser objeto: {path.name}")
    return data


def valid_key(value: object) -> bool:
    return isinstance(value, str) and bool(MODULE_RE.fullmatch(value))


def check_https(value: object, expected_host: str | None = None) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlsplit(value)
    return (parsed.scheme == "https" and parsed.username is None
            and parsed.password is None and bool(parsed.hostname)
            and not parsed.fragment and (expected_host is None
            or parsed.hostname == expected_host))


def verify_target(url: str) -> str:
    # Both host and path must match the independently verified staging API.
    if url.rstrip("/") != PILOT_STAGING_URL:
        raise SyncBlocked("Escrita permitida somente na URL fixa de staging.")
    return PILOT_STAGING_URL


def fingerprint(payload: dict) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def plan_media(manifest: dict, delivery: dict, review: dict, lineage: dict,
               lesson_filter: int | None = None) -> tuple[list[dict], list[tuple[str, str]]]:
    if manifest.get("manifest_version") != 2 or not isinstance(manifest.get("videos"), list):
        raise SyncBlocked("Esperado manifesto de auditoria v2 com videos[].")
    if not isinstance(delivery, dict) or not isinstance(review, dict):
        raise SyncBlocked("Delivery e review devem ser objetos JSON.")
    rows = manifest["videos"]
    seen: set[str] = set()
    planned: list[dict] = []
    blocked: list[tuple[str, str]] = []
    for row in rows:
        if not isinstance(row, dict):
            raise SyncBlocked("Linha inválida do manifesto.")
        lid = str(row.get("wp_lesson_id", ""))
        if not lid.isdecimal() or int(lid) <= 0:
            raise SyncBlocked("wp_lesson_id inválido.")
        if lid in seen:
            raise SyncBlocked(f"wp_lesson_id duplicado: {lid}")
        seen.add(lid)
        if lesson_filter is not None and int(lid) != lesson_filter:
            continue
        try:
            item = _make_payload(row, delivery.get(lid), review.get(lid), lineage)
        except SyncBlocked as exc:
            blocked.append((lid, str(exc)))
            continue
        planned.append({"wp_lesson_id": lid, "payload": item, "sha256": fingerprint(item)})
    if lesson_filter is not None and str(lesson_filter) not in seen:
        raise SyncBlocked("Lição selecionada não consta do manifesto.")
    return planned, blocked


def _make_payload(row: dict, delivery: object, approval: object, lineage: dict) -> dict:
    if row.get("wp_post_status") != "publish":
        raise SyncBlocked("Lição WordPress não publicada.")
    if not isinstance(delivery, dict):
        raise SyncBlocked("Upload no provedor pendente.")
    if delivery.get("provider") != "youtube" or not YT_RE.fullmatch(
        str(delivery.get("provider_asset_id", ""))
    ):
        raise SyncBlocked("Este piloto exige YouTube e videoId válido.")
    course = row.get("app_course_id")
    if not valid_key(course) or not isinstance(row.get("wp_course_id"), int):
        raise SyncBlocked("Curso ou vínculo LearnPress ausente.")
    if row.get("mapping_status") == APPROVED_MAPPING:
        module = row.get("module_id")
        if not valid_key(module):
            raise SyncBlocked("Módulo verificado inválido.")
        if isinstance(approval, dict) and approval.get("module_id") not in (None, module):
            raise SyncBlocked("Revisão diverge do módulo já verificado.")
    else:
        if not isinstance(approval, dict) or approval.get("approved") is not True:
            raise SyncBlocked("Mapeamento de módulo exige revisão humana explícita.")
        module = approval.get("module_id")
        if not valid_key(module):
            raise SyncBlocked("Módulo revisado inválido.")
    competency = (approval or {}).get("competency_id") if isinstance(approval, dict) else None
    followup = (approval or {}).get("followup_activity_id") if isinstance(approval, dict) else None
    competency = competency or delivery.get("competency_id")
    followup = followup or delivery.get("followup_activity_id")
    if not valid_key(competency) or not valid_key(followup):
        raise SyncBlocked("Competência e atividade posterior exigem IDs revisados.")
    if not check_https(row.get("source_mp4_url"), "ead.ipexdesenvolvimento.cloud"):
        raise SyncBlocked("MP4 fonte inválido ou de domínio inesperado.")
    poster = row.get("thumbnail_url")
    if poster is not None and not check_https(poster, "ead.ipexdesenvolvimento.cloud"):
        raise SyncBlocked("Poster inválido.")
    duration = row.get("duration_seconds")
    if not isinstance(duration, int) or not (0 < duration <= 86400):
        raise SyncBlocked("Duração verificada ausente/inválida.")
    title = row.get("lesson_title")
    if not isinstance(title, str) or len(title.strip()) < 2:
        raise SyncBlocked("Título ausente.")
    for field in ("institution_id", "program_id", "creator_user_id"):
        if not isinstance(lineage.get(field), str) or not lineage[field].strip():
            raise SyncBlocked("Linhagem institucional incompleta.")
    visibility = delivery.get("visibility", "enrolled")
    if visibility not in {"public", "enrolled", "institution"}:
        raise SyncBlocked("Visibilidade não admitida para catálogo.")
    return {
        "institution_id": lineage["institution_id"],
        "program_id": lineage["program_id"],
        "creator_user_id": lineage["creator_user_id"],
        "course_id": course,
        "module_id": module,
        "title": title.strip()[:240],
        "description": f"Videoaula LearnPress {row['wp_lesson_id']}, curso {course}.",
        "competency_id": competency,
        "followup_activity_id": followup,
        "provider": "youtube",
        "provider_asset_id": delivery["provider_asset_id"],
        "duration_seconds": duration,
        "thumbnail_url": poster,
        "captions": [],  # YouTube manages captions; do not depend on WordPress VTT CORS.
        "visibility": visibility,
        "offline_policy": "forbidden",
        "rights_confirmed": False,  # Only a separate, human-approved publish can change this.
    }


class Api:
    def __init__(self, base: str):
        self.base = verify_target(base)

    def request(self, path: str, *, method: str = "GET",
                body: dict | None = None, token: str | None = None) -> tuple[int, dict]:
        headers = {"Accept": "application/json", "User-Agent": "tds-learnpress-sync/1.0"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(self.base + path, headers=headers, data=data, method=method)
        try:
            with urllib.request.urlopen(req, timeout=12) as response:
                return response.status, json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as exc:
            # Deliberately do not log response bodies, which might contain PII.
            return exc.code, {}


def preflight(api: Api, environ: dict[str, str]) -> str:
    version_status, version = api.request("/version")
    if version_status != 200 or version.get("environment") != "staging":
        raise SyncBlocked("Versão da API não confirma environment=staging.")
    cpf = environ.get("TDS_ADMIN_CPF", "")
    password = environ.get("TDS_ADMIN_PASSWORD", "")
    if not cpf or not password:
        raise SyncBlocked("Credenciais de staging ausentes no ambiente.")
    status, auth = api.request("/auth/login", method="POST", body={
        "cpf": cpf, "password": password,
    })
    if status != 200 or not isinstance(auth.get("access_token"), str):
        raise SyncBlocked("Autenticação de staging falhou.")
    return auth["access_token"]


def load_checkpoint(path: Path, target: str) -> dict:
    if not path.exists():
        return {"schema_version": 1, "target": target, "items": {}}
    content = read_object(path)
    if (content.get("schema_version") != 1 or content.get("target") != target
            or not isinstance(content.get("items"), dict)):
        raise SyncBlocked("Checkpoint incompatível com ambiente ou formato.")
    return content


def persist_checkpoint(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, prefix=path.name + ".",
            suffix=".tmp", delete=False
        ) as handle:
            tmp_name = handle.name
            json.dump(state, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    finally:
        if tmp_name and os.path.exists(tmp_name):
            os.unlink(tmp_name)


def execute_one(plan: dict, api: Api, token: str, state_path: Path) -> str:
    state = load_checkpoint(state_path, api.base)
    lid = plan["wp_lesson_id"]
    old = state["items"].get(lid)
    if old is not None:
        if old.get("sha256") != plan["sha256"] or old.get("conflict"):
            raise SyncBlocked("Mudança de payload ou conflito: reconciliação manual obrigatória.")
        if old.get("media_id"):
            return "SKIP_ALREADY_RECORDED"
        raise SyncBlocked("Checkpoint sem media_id: reconciliação manual obrigatória.")
    status, result = api.request(
        "/admin/media", method="POST", body=plan["payload"], token=token
    )
    if status == 201:
        if (not isinstance(result.get("id"), str) or not result["id"]
                or result.get("status") != "draft"):
            raise SyncBlocked("API criou mídia, mas retorno não comprova draft: reconciliar manualmente.")
        state["items"][lid] = {
            "media_id": result["id"], "sha256": plan["sha256"],
            "provider_asset_id": plan["payload"]["provider_asset_id"],
        }
        persist_checkpoint(state_path, state)
        return "DRAFT_CREATED"
    if status == 409:
        state["items"][lid] = {"media_id": None, "sha256": plan["sha256"], "conflict": True}
        persist_checkpoint(state_path, state)
        return "CONFLICT_409_MANUAL_RECONCILIATION"
    raise SyncBlocked(f"POST não criou draft (HTTP {status}); verificar servidor e reconciliação.")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--delivery", type=Path, required=True)
    ap.add_argument("--review", type=Path, help="Aprovações pedagógicas por wp_lesson_id (JSON).")
    ap.add_argument("--lesson-id", type=int)
    ap.add_argument("--state", type=Path)
    ap.add_argument("--target", default=PILOT_STAGING_URL)
    ap.add_argument("--execute", action="store_true", help="Cria NO MÁXIMO um draft em staging.")
    args = ap.parse_args(argv)
    if args.execute and (args.lesson_id is None or args.state is None):
        raise SyncBlocked("--execute exige --lesson-id único e --state explícito.")
    if args.execute:
        verify_target(args.target)
    lineage = {name: os.getenv("TDS_" + name.upper(), "").strip()
               for name in ("institution_id", "program_id", "creator_user_id")}
    # Dry-run can inspect a complete manifest without operational credentials.
    if not args.execute:
        for field in lineage:
            lineage[field] = lineage[field] or "dry-run-" + field
    review = read_object(args.review) if args.review else {}
    planned, blocked = plan_media(
        read_object(args.manifest), read_object(args.delivery), review,
        lineage, args.lesson_id,
    )
    print(f"MODE={'STAGING_DRAFT' if args.execute else 'DRY_RUN'} "
          f"selected={len(planned) + len(blocked)} eligible={len(planned)} blocked={len(blocked)}")
    for lid, reason in blocked:
        print(f"BLOCKED {lid} {reason}")
    for record in planned:
        p = record["payload"]
        print(f"ELIGIBLE {record['wp_lesson_id']} {p['course_id']}/{p['module_id']} "
              f"youtube:{p['provider_asset_id']}")
    if args.execute:
        if blocked or len(planned) != 1:
            raise SyncBlocked("Execução exige uma única lição elegível.")
        api = Api(args.target)
        token = preflight(api, os.environ)
        print(execute_one(planned[0], api, token, args.state))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (SyncBlocked, OSError, ValueError, urllib.error.URLError) as exc:
        print(f"BLOCKED: {exc.__class__.__name__}: {exc if isinstance(exc, SyncBlocked) else 'verificar conexão e arquivos'}", file=sys.stderr)
        sys.exit(2)
