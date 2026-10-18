#!/usr/bin/env python3
"""Read-only verification of the LearnPress course curriculum against a TDS manifest.

No WordPress admin actions, no student information and no API writes.
When used live, requests ONLY the fixed LearnPress course GET endpoints.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
import unicodedata
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

WORDPRESS_ORIGIN = "https://ead.ipexdesenvolvimento.cloud"
MAX_RESPONSE_BYTES = 1_000_000


class AuditBlocked(ValueError):
    """The source, response, or curriculum could not be verified safely."""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, new_url):
        return None


def _int_id(value: object, label: str) -> int:
    # Avoid bool-as-int and implicit float coercion.
    if (isinstance(value, bool) or not isinstance(value, (int, str))
            or not str(value).isdigit() or int(value) <= 0):
        raise AuditBlocked(f"{label} inválido.")
    return int(value)


def _title(value: object) -> str:
    if isinstance(value, dict):
        value = value.get("rendered")
    if not isinstance(value, str):
        return ""
    return unicodedata.normalize(
        "NFC", re.sub(r"\s+", " ", html.unescape(value)).strip()
    )


def _parse_course(course_id: int, raw: object) -> dict[int, dict]:
    if not isinstance(raw, dict) or not isinstance(raw.get("sections"), list):
        raise AuditBlocked(f"Resposta LearnPress inválida no curso {course_id}.")
    if "id" in raw and _int_id(raw["id"], "course.id") != course_id:
        raise AuditBlocked(f"ID de curso inesperado para {course_id}.")
    result: dict[int, dict] = {}
    for section in raw["sections"]:
        if not isinstance(section, dict):
            raise AuditBlocked(f"Seção malformada no curso {course_id}.")
        sid = _int_id(section.get("id"), "section.id")
        if sid in result:
            raise AuditBlocked(f"Seção duplicada {sid} no curso {course_id}.")
        items = section.get("items", [])
        if not isinstance(items, list):
            raise AuditBlocked(f"Itens inválidos na seção {sid}.")
        item_ids = []
        titles = {}
        for item in items:
            if not isinstance(item, dict):
                raise AuditBlocked(f"Item inválido na seção {sid}.")
            lesson_id = _int_id(item.get("id"), "lesson.id")
            if lesson_id in item_ids:
                raise AuditBlocked(f"Lição duplicada {lesson_id} na seção {sid}.")
            item_ids.append(lesson_id)
            titles[lesson_id] = _title(item.get("title"))
        result[sid] = {
            "ids": item_ids,
            "titles": titles,
            "title": _title(section.get("title")),
        }
    return result


def compare_curriculum(manifest: dict, courses: dict) -> dict:
    """Check all 45 lesson IDs, section membership and order, without edits."""
    if manifest.get("manifest_version") != 2 or not isinstance(manifest.get("videos"), list):
        raise AuditBlocked("Manifesto v2 inválido.")
    entries = manifest["videos"]
    expected: dict[int, list[dict]] = defaultdict(list)
    global_ids: set[int] = set()
    for row in entries:
        if not isinstance(row, dict):
            raise AuditBlocked("Linha do manifesto não é objeto.")
        course_id = _int_id(row.get("wp_course_id"), "wp_course_id")
        lesson_id = _int_id(row.get("wp_lesson_id"), "wp_lesson_id")
        _int_id(row.get("wp_section_id"), "wp_section_id")
        _int_id(row.get("lesson_order"), "lesson_order")
        if lesson_id in global_ids:
            raise AuditBlocked(f"Lição {lesson_id} duplicada no manifesto.")
        global_ids.add(lesson_id)
        expected[course_id].append(row)
    if not entries:
        raise AuditBlocked("Manifesto sem aulas.")
    problems: list[dict] = []
    warnings: list[dict] = []
    for course_id, rows in sorted(expected.items()):
        key = str(course_id)
        if key not in courses:
            raise AuditBlocked(f"Curso {course_id} não foi reconsultado.")
        sections = _parse_course(course_id, courses[key])
        # Do not accept multiple locations for the same lesson in one course.
        occurrences: dict[int, list[int]] = defaultdict(list)
        for section_id, section in sections.items():
            for lid in section["ids"]:
                occurrences[lid].append(section_id)
        for row in rows:
            lid = int(row["wp_lesson_id"])
            sid = int(row["wp_section_id"])
            if lid not in occurrences:
                problems.append({"kind": "LESSON_MISSING", "course": course_id, "lesson": lid})
            elif occurrences[lid] != [sid]:
                problems.append({
                    "kind": "LESSON_MOVED_OR_DUPLICATED",
                    "course": course_id, "lesson": lid,
                    "expected_section": sid, "actual_sections": occurrences[lid],
                })
            elif row.get("mapping_status") == "verified_by_id_and_module":
                actual_title = sections[sid]["titles"].get(lid, "")
                # In the original 33 verified rows the exact lesson title came from WP REST.
                if actual_title and _title(row.get("lesson_title")) != actual_title:
                    problems.append({"kind": "TITLE_CHANGED", "course": course_id, "lesson": lid})
        by_section: dict[int, list[dict]] = defaultdict(list)
        for row in rows:
            by_section[int(row["wp_section_id"])].append(row)
        for sid, section_rows in sorted(by_section.items()):
            if sid not in sections:
                problems.append({"kind": "SECTION_MISSING", "course": course_id, "section": sid})
                continue
            ordered = sorted(section_rows, key=lambda x: int(x["lesson_order"]))
            expected_ids = [int(x["wp_lesson_id"]) for x in ordered]
            current = sections[sid]["ids"]
            if course_id == 614:
                # IA sections also contain non-video lessons; verify relative order only.
                subset = [x for x in current if x in global_ids]
                if subset != expected_ids:
                    problems.append({"kind": "IA_LESSON_ORDER_CHANGED", "course": course_id, "section": sid})
            elif current != expected_ids:
                problems.append({"kind": "VIDEO_SECTION_CHANGED", "course": course_id, "section": sid,
                                 "expected_count": len(expected_ids), "actual_count": len(current)})
            if not sections[sid]["title"]:
                warnings.append({"kind": "SECTION_TITLE_EMPTY", "course": course_id, "section": sid})
    # Missing sections can also appear above; we deliberately retain both evidence types.
    snapshot = [
        {"course": cid,
         "sections": [{ "id": sid, "ids": section["ids"] }
                      for sid, section in sorted(_parse_course(cid, courses[str(cid)]).items())]}
        for cid in sorted(expected)
    ]
    digest = hashlib.sha256(json.dumps(snapshot, sort_keys=True,
                                      separators=(",", ":")).encode("utf-8")).hexdigest()
    return {
        "status": "PASS" if not problems else "BLOCKED",
        "courses_checked": len(expected),
        "lessons_checked": len(entries),
        "problems": problems,
        "warnings": warnings,
        "structure_sha256": digest,
    }


def fetch_course(course_id: int) -> dict:
    """Same-origin GET only; refuse redirects, oversized bodies, and non-JSON."""
    url = f"{WORDPRESS_ORIGIN}/wp-json/learnpress/v1/courses/{course_id}"
    request = urllib.request.Request(
        url, method="GET",
        headers={"Accept": "application/json", "User-Agent": "tds-learnpress-audit/1.0"},
    )
    opener = urllib.request.build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=9) as response:
            if response.status != 200:
                raise AuditBlocked(f"HTTP {response.status} no curso {course_id}.")
            content_type = response.headers.get("Content-Type", "").split(";")[0].lower()
            if content_type not in {"application/json", "application/ld+json"}:
                raise AuditBlocked(f"LearnPress respondeu tipo não JSON no curso {course_id}.")
            payload = response.read(MAX_RESPONSE_BYTES + 1)
            if len(payload) > MAX_RESPONSE_BYTES:
                raise AuditBlocked(f"Resposta excessiva no curso {course_id}.")
            decoded = json.loads(payload.decode("utf-8"))
            if not isinstance(decoded, dict):
                raise AuditBlocked(f"JSON malformado no curso {course_id}.")
            return decoded
    except (urllib.error.URLError, OSError, json.JSONDecodeError, UnicodeError) as err:
        # Never print response body, cookies, credentials, or request exception details.
        raise AuditBlocked(f"LearnPress inacessível/invalidado no curso {course_id}.") from err


def audit_live(manifest: dict) -> dict:
    if manifest.get("manifest_version") != 2:
        raise AuditBlocked("Manifesto v2 obrigatório.")
    ids: set[int] = set()
    for row in manifest.get("videos", []):
        if not isinstance(row, dict):
            raise AuditBlocked("Lição inválida no manifesto.")
        ids.add(_int_id(row.get("wp_course_id"), "wp_course_id"))
    if not ids or len(ids) > 30:
        raise AuditBlocked("Quantidade inesperada de cursos.")
    courses = {str(cid): fetch_course(cid) for cid in sorted(ids)}
    return compare_curriculum(manifest, courses)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--fixture", type=Path,
                        help="JSON de respostas LearnPress, indexado pelo wp_course_id (offline).")
    args = parser.parse_args(argv)
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        courses = json.loads(args.fixture.read_text(encoding="utf-8")) if args.fixture else None
        result = (compare_curriculum(manifest, courses) if courses is not None
                  else audit_live(manifest))
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["status"] == "PASS" else 2
    except (AuditBlocked, json.JSONDecodeError, OSError) as err:
        message = str(err) if isinstance(err, AuditBlocked) else "arquivo local inválido"
        print(f"BLOCKED: {message}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
