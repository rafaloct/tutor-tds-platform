#!/usr/bin/env python3
"""Read-only LearnPress curriculum audit against Tutor TDS bundled learning blocks.

This is NOT an importer, grade calculator, LMS progress adapter or answer key.
It reads public GET endpoints and local JSON, with no tokens or user accounts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

HOST = "ead.ipexdesenvolvimento.cloud"
ORIGIN = f"https://{HOST}"
ROOT = Path(__file__).resolve().parents[3]
LOCAL = ROOT / "cartilhas_app" / "assets" / "data" / "lessons"
LIMIT = 800_000
VIDEO_SECTION_IDS = {
    614: ("ia-cartilha", {28, 76, 77, 78}, 12),
    1298: ("agricultura-sustentavel", {79}, 6),
    1307: ("atendimento-cliente", {81}, 4),
    1314: ("audiovisual", {82}, 4),
    1321: ("cooperativismo", {84}, 5),
    1328: ("economia-lar", {86}, 4),
    1335: ("educacao-financeira", {85}, 5),
    1343: ("sim-sima", {83}, 4),
    1356: ("saf", {80}, 4),
}


class AuditError(RuntimeError):
    pass


def get_json(url: str) -> object:
    p = urlsplit(url)
    if p.scheme != "https" or p.hostname != HOST or p.username or p.password:
        raise AuditError("URL fora da origem EAD autorizada")
    if p.path not in ("/wp-json/wp/v2/lp_course",
                      "/wp-json/wp/v2/lp_quiz") and not re.fullmatch(
            r"/wp-json/learnpress/v1/courses/\d+", p.path):
        raise AuditError("Rota não autorizada para auditoria")
    req = urllib.request.Request(
        url, method="GET",
        headers={"Accept": "application/json",
                 "User-Agent": "TutorTDS-read-only-curriculum-qa/1.0"},
    )
    try:
        # No headers/cookies/tokens from the learner.
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.status != 200:
                raise AuditError("Curso ou catálogo EAD indisponível")
            payload = response.read(LIMIT + 1)
            if len(payload) > LIMIT:
                raise AuditError("Resposta EAD excessiva")
            return json.loads(payload)
    except (urllib.error.URLError, OSError, ValueError) as ex:
        raise AuditError("Falha na leitura pública do EAD") from ex


def read_local(slug: str, folder: Path = LOCAL) -> dict:
    path = folder / f"{slug}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("id") != slug:
        raise AuditError(f"Cartilha local inválida: {slug}")
    counts: Counter[str] = Counter()
    correct_in_bundled = 0
    sections = data.get("sections", [])
    if not isinstance(sections, list):
        raise AuditError("Cartilha não possui seções")
    for sec in sections:
        if not isinstance(sec, dict):
            raise AuditError("Seção de cartilha inválida")
        for message in sec.get("messages", []):
            if not isinstance(message, dict) or "type" not in message:
                raise AuditError("Bloco de atividade inválido")
            counts[str(message["type"])] += 1
            # Never export any answer, feedback, personal attempt or key.
            if any(o.get("isCorrect") is True for o in (message.get("options") or [])
                   if isinstance(o, dict)):
                correct_in_bundled += 1
    return {
        "sections": len(sections),
        "formative_question_blocks": counts["question"],
        "published_quiz_blocks": counts["quiz"],
        "correct_markers_in_bundled_assets": correct_in_bundled,
        "version_id_present": bool(data.get("course_version_id")),
    }


def public_courses() -> dict[int, dict]:
    url = (f"{ORIGIN}/wp-json/wp/v2/lp_course"
           "?per_page=100&_fields=id,slug,title,status")
    raw = get_json(url)
    if not isinstance(raw, list):
        raise AuditError("Lista pública de cursos malformada")
    result = {}
    for item in raw:
        if not isinstance(item, dict) or not isinstance(item.get("id"), int):
            raise AuditError("ID WordPress inválido")
        if item.get("status") != "publish":
            continue
        result[item["id"]] = {
            "id": item["id"], "slug": item.get("slug"),
            "name": item.get("title", {}).get("rendered", ""),
        }
    return result


def public_quiz_bank() -> list[dict]:
    url = (f"{ORIGIN}/wp-json/wp/v2/lp_quiz"
           "?per_page=100&_fields=id,slug,title,status")
    raw = get_json(url)
    if not isinstance(raw, list):
        raise AuditError("Lista pública de quizzes malformada")
    quizzes = []
    seen = set()
    for item in raw:
        if not isinstance(item, dict) or not isinstance(item.get("id"), int):
            raise AuditError("Quiz inválido")
        if item.get("status") != "publish":
            continue
        if item["id"] in seen:
            raise AuditError("Quiz duplicado")
        seen.add(item["id"])
        quizzes.append({
            "id": item["id"], "slug": item.get("slug"),
            "title": item.get("title", {}).get("rendered", ""),
            "curriculum_association": "UNVERIFIED",
        })
    return sorted(quizzes, key=lambda x: x["id"])


def audit_course(wp_id: int, wordpress: dict, local: dict) -> dict:
    if wp_id not in VIDEO_SECTION_IDS:
        raise AuditError("Curso fora dos nove originais")
    canonical, video_sections, expected_video_count = VIDEO_SECTION_IDS[wp_id]
    if wordpress.get("id") != wp_id or not isinstance(wordpress.get("sections"), list):
        raise AuditError(f"Resposta inválida LearnPress curso {wp_id}")
    entries = []
    sections = []
    seen_sections = set()
    seen_lessons = set()
    current_video_count = 0
    linked_quizzes = []
    for index, sec in enumerate(wordpress["sections"]):
        if not isinstance(sec, dict) or not isinstance(sec.get("id"), int):
            raise AuditError(f"Seção inválida em curso {wp_id}")
        sid = sec["id"]
        if sid in seen_sections:
            raise AuditError("Seção repetida")
        seen_sections.add(sid)
        items = sec.get("items")
        if not isinstance(items, list):
            raise AuditError("Seção sem items[]")
        section_entries = []
        for position, item in enumerate(items, start=1):
            if not isinstance(item, dict) or not isinstance(item.get("id"), int):
                raise AuditError("Aula com ID inválido")
            lid = item["id"]
            if lid in seen_lessons:
                raise AuditError("Aula duplicada no curso")
            seen_lessons.add(lid)
            typ = item.get("type")
            if typ not in ("lp_lesson", "lp_quiz"):
                raise AuditError(f"Tipo LearnPress desconhecido: {typ}")
            is_video_candidate = typ == "lp_lesson" and sid in video_sections
            if is_video_candidate:
                current_video_count += 1
            if typ == "lp_quiz":
                linked_quizzes.append(lid)
            record = {
                "id": lid, "type": typ,
                "name": str(item.get("title") or "").strip(),
                "section_id": sid, "section_order": index + 1,
                "position_in_section": position,
                "video_candidate": is_video_candidate,
                "assessment_status": (
                    "REQUIRES_TEACHER_REVIEW" if typ == "lp_quiz"
                    else "NOT_AN_ASSESSMENT"
                ),
            }
            if not record["name"]:
                raise AuditError("Aula sem título")
            section_entries.append(record)
            entries.append(record)
        sections.append({"id": sid, "title": str(sec.get("title") or "").strip(),
                         "position": index + 1, "items": section_entries})
    if not video_sections.issubset(seen_sections):
        raise AuditError(f"Seção de vídeo ausente no curso {wp_id}")
    validation = ("PASS" if current_video_count == expected_video_count
                  else "VIDEO_CATALOG_DRIFT")
    return {
        "wp_course_id": wp_id,
        "api_course_id": canonical,
        "wp_title": str(wordpress.get("name") or "").strip(),
        "sections": sections,
        "count_sections": len(sections),
        "lesson_count": sum(x["type"] == "lp_lesson" for x in entries),
        "video_candidate_count": current_video_count,
        "expected_video_count": expected_video_count,
        "linked_quiz_ids": linked_quizzes,
        "local_cartilha": local,
        "validation": validation,
        "editorial_gates": [
            "VALIDATE_VIDEOS_MP4_YOUTUBE_HASH_RIGHTS",
            "ASSIGN_QUIZ_WITH_TEACHER_NOT_BY_TITLE",
            "REVIEW_GRADE_RULES_AND_ATTEMPTS",
            "PUBLISH_COURSE_VERSION_WITHOUT_MUTATING_CURRENT",
            "CONTEXT_BIND_TUTOR_TO_APPROVED_SOURCES",
        ],
    }


def assemble(courses: dict[int, dict], details: dict[int, dict],
             quiz_bank: list[dict], locals_: dict[str, dict]) -> dict:
    missing = sorted(set(VIDEO_SECTION_IDS) - set(courses))
    if missing:
        raise AuditError(f"Algum dos nove cursos não está publicado: {missing}")
    all_rows = []
    for cid in sorted(VIDEO_SECTION_IDS):
        canonical = VIDEO_SECTION_IDS[cid][0]
        if canonical not in locals_ or cid not in details:
            raise AuditError("Curso sem fonte local ou detalhe público")
        item = audit_course(cid, details[cid], locals_[canonical])
        item["wp_slug"] = courses[cid]["slug"]
        all_rows.append(item)
    linked = {q for item in all_rows for q in item["linked_quiz_ids"]}
    quiz_ids = {q["id"] for q in quiz_bank}
    if linked - quiz_ids:
        raise AuditError("Quiz anexado ao currículo sem cadastro público correspondente")
    output = {
        "schema": "tds-ead-read-only-curriculum-audit-v1",
        "source": ORIGIN,
        "course_count": len(all_rows),
        "wordpress_published_course_count": len(courses),
        "total_lp_lessons": sum(c["lesson_count"] for c in all_rows),
        "video_section_candidates": sum(c["video_candidate_count"] for c in all_rows),
        "local_formative_questions": sum(c["local_cartilha"]["formative_question_blocks"]
                                         for c in all_rows),
        "local_published_quizzes": sum(c["local_cartilha"]["published_quiz_blocks"]
                                      for c in all_rows),
        "wordpress_quiz_posts_published": len(quiz_bank),
        "linked_quizzes_to_current_nine": len(linked),
        "unlinked_quiz_ids": sorted(quiz_ids - linked),
        "validation": ("PASS" if all(c["validation"] == "PASS" for c in all_rows)
                       else "BLOCKED"),
        "courses": all_rows,
        "quiz_bank": quiz_bank,
        "warnings": [
            "Quizzes publicados isolados não equivalem a provas vinculadas ao curso.",
            "Video_candidate significa seção verificada; não comprova arquivo MP4 nem direitos.",
            "Sem exportação de gabaritos, tentativas, CPF, matrícula ou progresso.",
            "Mapeamentos de provas e regras de nota exigem revisão do professor.",
        ],
    }
    return output


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--fixtures", type=Path, help="Fixture offline do WordPress")
    ap.add_argument("--local-dir", type=Path, default=LOCAL)
    args = ap.parse_args(argv)
    try:
        if args.output.exists():
            raise AuditError("Destino já existe: não substituir auditoria anterior")
        if args.fixtures:
            wp = json.loads(args.fixtures.read_text(encoding="utf-8"))
            courses = {int(k): v for k, v in wp["courses"].items()}
            details = {int(k): v for k, v in wp["details"].items()}
            quiz_bank = wp["quiz_bank"]
        else:
            courses = public_courses()
            details = {cid: get_json(f"{ORIGIN}/wp-json/learnpress/v1/courses/{cid}")
                       for cid in sorted(VIDEO_SECTION_IDS)}
            quiz_bank = public_quiz_bank()
        locals_ = {data[0]: read_local(data[0], args.local_dir)
                   for data in VIDEO_SECTION_IDS.values()}
        result = assemble(courses, details, quiz_bank, locals_)
        result["verified_utc"] = datetime.now(timezone.utc).isoformat()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        overview = {key: val for key, val in result.items() if key not in ("courses", "quiz_bank")}
        print(json.dumps(overview, ensure_ascii=False, indent=2))
        print("OUTPUT_SHA256", hashlib.sha256(args.output.read_bytes()).hexdigest())
        return 0 if result["validation"] == "PASS" else 2
    except (AuditError, OSError, ValueError, KeyError, TypeError) as ex:
        print("BLOCKED:", ex, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
