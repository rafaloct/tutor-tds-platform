"""Offline integrity preflight for the nine legacy TDS curricular RAG sources.

This tool neither downloads Drive files nor writes to AnythingLLM. Its output
attests only to operator-supplied local PDF bytes and reviewed repository data.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MAP = REPO_ROOT / "tooling/ai_qa/curricular_source_map.json"
DEFAULT_EVIDENCE = REPO_ROOT / "docs/production/evidence/course-pdf-hosting-2026-10-01.json"
DEFAULT_LESSONS = REPO_ROOT / "cartilhas_app/assets/data/lessons"
MAP_KEYS = {"schema_version", "review_scope", "hosting_evidence_path", "hosting_evidence_sha256", "sources"}
SOURCE_KEYS = {
    "course_id", "course_version_id", "lesson_file", "lesson_sha256",
    "drive_file_id", "drive_view_url", "viewer_title", "original_pdf_name",
    "original_pdf_bytes", "original_pdf_sha256", "proposed_workspace",
}
EXPORT_KEYS = {"schema_version", "course_id", "version_id", "version_number", "content", "sha256"}
IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}\Z")
DRIVE_ID = re.compile(r"[A-Za-z0-9_-]{20,100}\Z")
DIGEST = re.compile(r"[0-9a-f]{64}\Z")


class PreflightError(ValueError):
    """A local input violates the reviewed curricular source contract."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _exact_keys(value: Any, keys: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise PreflightError(f"{label}: campos inesperados ou ausentes")
    return value


def _no_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise PreflightError(f"JSON: chave duplicada {key}")
        value[key] = item
    return value


def _reject_nonfinite(value: str) -> None:
    raise PreflightError(f"JSON: número não finito {value}")


def _no_symlink(path: Path) -> None:
    current = path
    while True:
        if current.is_symlink():
            raise PreflightError(f"link simbólico recusado: {path.name}")
        if current.parent == current:
            break
        current = current.parent


def _read_bytes(path: Path, maximum: int) -> bytes:
    _no_symlink(path)
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(descriptor, "rb") as stream:
            size = os.fstat(stream.fileno())
            if not stat.S_ISREG(size.st_mode) or size.st_size > maximum:
                raise PreflightError(f"arquivo inválido ou grande demais: {path.name}")
            return stream.read()
    except OSError as error:
        raise PreflightError(f"arquivo ausente ou ilegível: {path.name}") from error


def _read_json(path: Path, maximum: int = 2_500_000) -> tuple[dict[str, Any], str]:
    raw = _read_bytes(path, maximum)
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_no_duplicate_pairs, parse_constant=_reject_nonfinite)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise PreflightError(f"JSON inválido: {path.name}") from error
    if not isinstance(value, dict):
        raise PreflightError(f"JSON deve ser objeto: {path.name}")
    return value, hashlib.sha256(raw).hexdigest()


def _directory(path: Path, label: str) -> Path:
    _no_symlink(path)
    if not path.is_dir():
        raise PreflightError(f"{label}: diretório ausente")
    return path


def _child(root: Path, filename: str, suffix: str) -> Path:
    if not isinstance(filename, str) or not filename.endswith(suffix) or "/" in filename or "\\" in filename or filename in {".", ".."} or ".." in Path(filename).parts:
        raise PreflightError("nome de arquivo inválido ou com travessia")
    path = root / filename
    _no_symlink(path)
    if path.parent.resolve() != root.resolve():
        raise PreflightError("arquivo fora do diretório esperado")
    return path


def _require_digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or not DIGEST.fullmatch(value):
        raise PreflightError(f"{label}: SHA-256 inválido")
    return value


def _require_identifier(value: Any, label: str) -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise PreflightError(f"{label}: identificador inválido")
    return value


def _check_unique(rows: list[dict[str, Any]], key: str) -> None:
    values = [row[key] for row in rows]
    if len(values) != len(set(values)):
        raise PreflightError(f"mapa: {key} duplicado")


def _validate_map(source_map: dict[str, Any], evidence: dict[str, Any], evidence_sha: str) -> list[dict[str, Any]]:
    _exact_keys(source_map, MAP_KEYS, "mapa")
    if source_map["schema_version"] != 1 or type(source_map["schema_version"]) is not int:
        raise PreflightError("mapa: schema_version inválido")
    if source_map["hosting_evidence_path"] != "docs/production/evidence/course-pdf-hosting-2026-10-01.json":
        raise PreflightError("mapa: evidência de origem inesperada")
    if _require_digest(source_map["hosting_evidence_sha256"], "evidência") != evidence_sha:
        raise PreflightError("mapa: evidência de hospedagem alterada")
    if source_map["review_scope"] != "historical_originals_and_bundled_lessons; editorial_approval_and_drive_bytes_unverified":
        raise PreflightError("mapa: escopo de revisão inesperado")
    rows = source_map["sources"]
    if not isinstance(rows, list) or len(rows) != 9:
        raise PreflightError("mapa: são exigidas as nove cartilhas legadas")
    if evidence.get("status") != "hosting_audit_completed" or not isinstance(evidence.get("courses"), list) or not isinstance(evidence.get("local_originals"), list) or len(evidence["courses"]) != 9 or len(evidence["local_originals"]) != 9:
        raise PreflightError("evidência: inventário de nove fontes inválido")
    evidence_courses = {entry.get("course_id"): entry for entry in evidence["courses"] if isinstance(entry, dict)}
    originals = {entry.get("name"): entry for entry in evidence["local_originals"] if isinstance(entry, dict)}
    if len(evidence_courses) != 9 or len(originals) != 9:
        raise PreflightError("evidência: itens duplicados")
    for row in rows:
        _exact_keys(row, SOURCE_KEYS, "fonte")
        course_id = _require_identifier(row["course_id"], "course_id")
        version_id = _require_identifier(row["course_version_id"], "course_version_id")
        _require_digest(row["lesson_sha256"], "lesson_sha256")
        _require_digest(row["original_pdf_sha256"], "original_pdf_sha256")
        if row["lesson_file"] != f"{course_id}.json":
            raise PreflightError("fonte: JSON de aulas diverge do curso")
        if not isinstance(row["drive_file_id"], str) or not DRIVE_ID.fullmatch(row["drive_file_id"]):
            raise PreflightError("fonte: ID do Drive inválido")
        expected_url = f'https://drive.google.com/file/d/{row["drive_file_id"]}/view'
        if row["drive_view_url"] != expected_url:
            raise PreflightError("fonte: URL do Drive não canônica")
        if row["proposed_workspace"] != f"tds-rag-{course_id}-{version_id}" or len(row["proposed_workspace"]) > 100:
            raise PreflightError("fonte: workspace proposto inválido")
        if not isinstance(row["original_pdf_name"], str) or not row["original_pdf_name"].endswith(".pdf") or "/" in row["original_pdf_name"] or "\\" in row["original_pdf_name"]:
            raise PreflightError("fonte: nome do PDF inválido")
        if type(row["original_pdf_bytes"]) is not int or not 1_000 <= row["original_pdf_bytes"] <= 100_000_000:
            raise PreflightError("fonte: tamanho do PDF inválido")
        if row["viewer_title"] != row["original_pdf_name"] + " - Google Drive":
            raise PreflightError("fonte: título do visualizador divergente")
        observed = evidence_courses.get(course_id)
        original = originals.get(row["original_pdf_name"])
        if (not observed or observed.get("download_url") != expected_url or observed.get("title") != row["viewer_title"] or observed.get("status") != 200 or not str(observed.get("content_type", "")).startswith("text/html") or observed.get("pdf_bytes_validated") is not False or not original or original.get("bytes") != row["original_pdf_bytes"] or original.get("sha256") != row["original_pdf_sha256"]):
            raise PreflightError(f"fonte: evidência histórica divergente para {course_id}")
    if set(evidence_courses) != {row["course_id"] for row in rows}:
        raise PreflightError("mapa: cursos divergem da evidência")
    for key in ("course_id", "course_version_id", "lesson_file", "drive_file_id", "drive_view_url", "original_pdf_name", "original_pdf_sha256", "proposed_workspace"):
        _check_unique(rows, key)
    return sorted(rows, key=lambda row: row["course_id"])


def _lesson_from_snapshot(content: dict[str, Any]) -> dict[str, Any]:
    lesson = deepcopy(content)
    if lesson.get("thumbnailUrl") not in (None, ""):
        raise PreflightError("export: thumbnailUrl não consta do JSON de aulas revisado")
    lesson.pop("thumbnailUrl", None)
    sections = lesson.get("sections")
    if not isinstance(sections, list):
        raise PreflightError("export: módulos inválidos")
    for section in sections:
        if not isinstance(section, dict) or not isinstance(section.get("messages"), list):
            raise PreflightError("export: módulo inválido")
        section.pop("version_id", None)
        for message in section["messages"]:
            if not isinstance(message, dict):
                raise PreflightError("export: mensagem inválida")
            message.pop("id", None)
            message.pop("version_id", None)
    return lesson


def _validate_export(export: dict[str, Any], row: dict[str, Any], lesson: dict[str, Any]) -> None:
    _exact_keys(export, EXPORT_KEYS, "export")
    if type(export["schema_version"]) is not int or export["schema_version"] != 1 or type(export["version_number"]) is not int or export["version_number"] < 1:
        raise PreflightError("export: schema ou número de edição inválido")
    if export["course_id"] != row["course_id"] or export["version_id"] != row["course_version_id"]:
        raise PreflightError("export: curso ou versão divergente")
    if _require_digest(export["sha256"], "export") != _digest({key: value for key, value in export.items() if key != "sha256"}):
        raise PreflightError("export: SHA-256 divergente")
    content = export["content"]
    if not isinstance(content, dict) or content.get("id") != row["course_id"] or content.get("course_version_id") != row["course_version_id"] or content.get("downloadUrl") != row["drive_view_url"]:
        raise PreflightError("export: conteúdo, versão ou URL divergente")
    if _lesson_from_snapshot(content) != lesson:
        raise PreflightError("export: conteúdo publicado diverge do JSON de aulas revisado")


def _validate_pdf(path: Path, expected_bytes: int, expected_sha: str) -> str:
    _no_symlink(path)
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(descriptor, "rb") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size != expected_bytes:
                raise PreflightError(f"PDF ausente ou tamanho divergente: {path.name}")
            digest = hashlib.sha256()
            first = b""
            tail = b""
            while chunk := stream.read(1024 * 1024):
                if not first:
                    first = chunk[:5]
                tail = (tail + chunk)[-2048:]
                digest.update(chunk)
    except OSError as error:
        raise PreflightError(f"PDF ausente ou ilegível: {path.name}") from error
    if first != b"%PDF-" or b"%%EOF" not in tail:
        raise PreflightError(f"arquivo não é PDF: {path.name}")
    if digest.hexdigest() != expected_sha:
        raise PreflightError(f"PDF com SHA-256 divergente: {path.name}")
    return digest.hexdigest()


def build_manifest(*, source_map_path: Path = DEFAULT_MAP, evidence_path: Path = DEFAULT_EVIDENCE, lesson_root: Path = DEFAULT_LESSONS, exports_dir: Path, pdf_root: Path) -> dict[str, Any]:
    source_map, map_sha = _read_json(source_map_path)
    evidence, evidence_sha = _read_json(evidence_path)
    rows = _validate_map(source_map, evidence, evidence_sha)
    lesson_root = _directory(lesson_root, "aulas")
    exports_dir = _directory(exports_dir, "exports")
    pdf_root = _directory(pdf_root, "PDFs")
    expected_exports = {f'{row["course_id"]}.json' for row in rows}
    if {path.name for path in exports_dir.iterdir()} != expected_exports:
        raise PreflightError("exports: requer exatamente um arquivo por cartilha revisada")
    results = []
    for row in rows:
        lesson, lesson_sha = _read_json(_child(lesson_root, row["lesson_file"], ".json"))
        if lesson_sha != row["lesson_sha256"] or lesson.get("id") != row["course_id"] or lesson.get("course_version_id") != row["course_version_id"] or lesson.get("downloadUrl") != row["drive_view_url"]:
            raise PreflightError(f"aula: hash, versão ou URL divergente para {row['course_id']}")
        export, _ = _read_json(_child(exports_dir, f'{row["course_id"]}.json', ".json"))
        _validate_export(export, row, lesson)
        pdf_sha = _validate_pdf(_child(pdf_root, row["original_pdf_name"], ".pdf"), row["original_pdf_bytes"], row["original_pdf_sha256"])
        results.append({
            "course_id": row["course_id"],
            "course_version_id": row["course_version_id"],
            "operator_export_sha256": export["sha256"],
            "lesson_sha256": lesson_sha,
            "drive_file_id": row["drive_file_id"],
            "drive_view_url": row["drive_view_url"],
            "historical_original_pdf": {"name": row["original_pdf_name"], "bytes": row["original_pdf_bytes"], "sha256": row["original_pdf_sha256"]},
            "operator_local_pdf": {"bytes": row["original_pdf_bytes"], "sha256": pdf_sha, "signature_checked": True},
            "proposed_workspace": row["proposed_workspace"],
        })
    manifest = {
        "schema_version": 1,
        "validation_scope": "offline_operator_supplied_files_only",
        "source_map_sha256": map_sha,
        "hosting_evidence_sha256": evidence_sha,
        "drive_bytes_provenance_verified": False,
        "anythingllm_indexed": False,
        "editorial_approval_verified": False,
        "sources": results,
    }
    manifest["sha256"] = _digest(manifest)
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Confere offline exports, aulas e PDFs curriculares sem acessar Drive ou RAG.")
    parser.add_argument("--exports-dir", required=True, type=Path)
    parser.add_argument("--pdf-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        manifest = build_manifest(exports_dir=args.exports_dir, pdf_root=args.pdf_root)
        _directory(args.output.parent, "destino")
        _no_symlink(args.output)
        with args.output.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(manifest, stream, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)
            stream.write("\n")
    except (PreflightError, OSError) as error:
        print(f"Preflight recusado: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"status": "verified_local_only", "courses": len(manifest["sources"]), "sha256": manifest["sha256"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
