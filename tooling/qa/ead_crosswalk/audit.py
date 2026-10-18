"""Read-only drift validation for the public LearnPress ↔ TDS course crosswalk.

This tool NEVER grants access, creates enrollments, or writes to services.
Only public catalog identifiers, titles, slugs and version *labels* are read.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

LP_URL = "https://ead.ipexdesenvolvimento.cloud/wp-json/learnpress/v1/courses?per_page=100"
TDS_URL = "https://ead.ipexdesenvolvimento.cloud/tutor-api/public/courses"
ALLOWED_URLS = {LP_URL, TDS_URL}
ALLOWED_HOST = "ead.ipexdesenvolvimento.cloud"
MAX_RESPONSE_BYTES = 128_000
ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SNAPSHOT = ROOT / "docs/qa/ead-crosswalk-20261018/public-source-snapshot.json"
DEFAULT_CROSSWALK = ROOT / "docs/qa/ead-crosswalk-20261018/course-crosswalk-candidates.json"
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CrosswalkError(ValueError):
    """Fail-closed validation error with no remote payload or secrets in text."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise CrosswalkError("Public catalog unexpectedly redirected; refused")


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise CrosswalkError(message)


def _object(value: Any, label: str) -> dict:
    _require(isinstance(value, dict), f"{label}: expected object")
    return value


def _text(value: Any, label: str) -> str:
    _require(isinstance(value, str) and value.strip() == value and len(value) > 0,
             f"{label}: nonempty trimmed string required")
    _require(len(value) <= 200, f"{label}: value too long")
    return value


def read_public_json(url: str) -> Any:
    # Exact URL allowlist, not just hostname. No token/cookie, no redirects.
    parsed = urlsplit(url)
    _require(url in ALLOWED_URLS and parsed.scheme == "https"
             and parsed.hostname == ALLOWED_HOST
             and not parsed.username and not parsed.password,
             "Public source is not allowlisted")
    request = Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "TutorTDS-Public-Crosswalk-Audit/1.0",
    })
    try:
        with build_opener(NoRedirect()).open(request, timeout=16) as response:
            _require(response.status == 200, "Public endpoint did not return HTTP 200")
            content_type = response.headers.get("Content-Type", "").lower()
            _require("json" in content_type, "Public endpoint did not provide JSON")
            body = response.read(MAX_RESPONSE_BYTES + 1)
            _require(len(body) <= MAX_RESPONSE_BYTES, "Public response exceeded size limit")
    except CrosswalkError:
        raise
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        # Never log response bodies or authentication headers.
        raise CrosswalkError(f"Public endpoint unavailable ({type(exc).__name__})") from None
    try:
        return json.loads(body.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        raise CrosswalkError("Public endpoint returned malformed JSON") from None


def normalize_lp(data: Any) -> list[dict]:
    _require(isinstance(data, list), "LearnPress: expected list")
    _require(0 < len(data) <= 100, "LearnPress: invalid course count")
    output: list[dict] = []
    ids: set[int] = set()
    for item in data:
        row = _object(item, "LearnPress course")
        course_id = row.get("id")
        _require(type(course_id) is int and course_id > 0, "LearnPress: invalid course id")
        _require(course_id not in ids, "LearnPress: duplicate course id")
        ids.add(course_id)
        output.append({"id": course_id, "name": _text(row.get("name"), "LearnPress title")})
    return sorted(output, key=lambda course: course["id"])


def normalize_tds(data: Any) -> list[dict]:
    payload = _object(data, "TDS catalog")
    courses = payload.get("courses")
    _require(isinstance(courses, list) and 0 < len(courses) <= 100,
             "TDS: expected course list")
    total = payload.get("total")
    if total is not None:
        _require(type(total) is int and total == len(courses),
                 "TDS: total differs from returned catalog")
    result: list[dict] = []
    slugs: set[str] = set()
    for item in courses:
        row = _object(item, "TDS course")
        slug = _text(row.get("slug"), "TDS slug")
        _require(SLUG.fullmatch(slug) is not None, "TDS: invalid slug")
        _require(slug not in slugs, "TDS: duplicate slug")
        slugs.add(slug)
        title = _text(row.get("title"), "TDS title")
        _require(row.get("status") == "published", "TDS: unpublished course in public list")
        label = _text(row.get("published_version_label"), "TDS version label")
        result.append({"slug": slug, "title": title, "status": "published",
                       "published_version_label": label})
    return sorted(result, key=lambda course: course["slug"])


def _exact_keys(row: dict, allowed: set[str], label: str) -> None:
    _require(set(row.keys()) == allowed, f"{label}: unexpected or missing schema fields")


def validate(snapshot: Any, crosswalk: Any) -> dict:
    data = _object(snapshot, "Snapshot")
    _exact_keys(data, {"schema_version", "observed_date", "sources", "learnpress", "tds"},
                "Snapshot")
    _require(data["schema_version"] == "ead-public-catalog-v1", "Unknown snapshot version")
    _require(data["observed_date"] == "2026-10-18", "Snapshot date is not the audited date")
    sources = _object(data["sources"], "Snapshot sources")
    _require(sources == {"learnpress": LP_URL, "tds": TDS_URL},
             "Snapshot source URLs differ from audited endpoints")
    _require(isinstance(data["learnpress"], list) and isinstance(data["tds"], list),
             "Snapshot catalog structure invalid")
    for entry in data["learnpress"]:
        _require(isinstance(entry, dict) and set(entry) == {"id", "name"},
                 "Snapshot includes unexpected LearnPress fields")
    for entry in data["tds"]:
        _require(isinstance(entry, dict) and set(entry)
                 == {"slug", "title", "status", "published_version_label"},
                 "Snapshot includes unexpected TDS fields")
    lp_courses = normalize_lp(data["learnpress"])
    tds_courses = normalize_tds({"courses": data["tds"], "total": len(data["tds"])})
    _require(len(lp_courses) == 11 and len(tds_courses) == 9,
             "Audited snapshot is not the 11 LearnPress / 9 TDS catalog")

    mapping = _object(crosswalk, "Crosswalk")
    _exact_keys(mapping, {"schema_version", "observed_date", "review_state", "sources",
                          "entries"}, "Crosswalk")
    _require(mapping["schema_version"] == "ead-crosswalk-candidate-v1",
             "Unknown crosswalk version")
    _require(mapping["observed_date"] == data["observed_date"],
             "Crosswalk and source dates differ")
    _require(mapping["review_state"] == "PENDING_EDITORIAL_REVIEW",
             "Crosswalk cannot self-approve editorial mappings")
    _require(mapping["sources"] == sources, "Crosswalk source URLs differ from snapshot")
    entries = mapping.get("entries")
    _require(isinstance(entries, list) and len(entries) == 11,
             "Crosswalk must contain exactly 11 EAD offers")
    indexed_lp = {course["id"]: course for course in lp_courses}
    indexed_tds = {course["slug"]: course for course in tds_courses}
    wp_ids: set[int] = set()
    assigned_slugs: set[str] = set()
    mapped = 0
    unmapped_ids: set[int] = set()

    required_fields = {
        "wp_course_id", "wp_title", "tds_candidate_slug", "tds_title_observed",
        "tds_version_label_observed", "tds_course_version_id", "mapping_status",
        "institutional_access", "rag_authorized", "certificate_authorized",
        "editorial_approval",
    }
    for row in entries:
        entry = _object(row, "Crosswalk entry")
        _exact_keys(entry, required_fields, "Crosswalk entry")
        course_id = entry.get("wp_course_id")
        _require(type(course_id) is int and course_id in indexed_lp,
                 "Crosswalk references unknown LearnPress ID")
        _require(course_id not in wp_ids, "Crosswalk repeats LearnPress ID")
        wp_ids.add(course_id)
        _require(entry["wp_title"] == indexed_lp[course_id]["name"],
                 "Crosswalk LearnPress title drift")
        for field in ("institutional_access", "rag_authorized", "certificate_authorized"):
            _require(entry[field] is False, f"Candidate mapping cannot enable {field}")
        _require(entry["tds_course_version_id"] is None,
                 "Public version label cannot become a CourseVersion ID")
        _require(entry["editorial_approval"] is None,
                 "Editorial sign-off cannot be inferred from public titles")
        status = entry.get("mapping_status")
        if status == "candidate_review":
            slug = entry.get("tds_candidate_slug")
            _require(isinstance(slug, str) and slug in indexed_tds,
                     "Mapped row references unknown institutional slug")
            _require(slug not in assigned_slugs, "TDS slug was assigned more than once")
            assigned_slugs.add(slug)
            authoritative = indexed_tds[slug]
            _require(entry["tds_title_observed"] == authoritative["title"],
                     "Crosswalk institutional title drift")
            _require(entry["tds_version_label_observed"]
                     == authoritative["published_version_label"],
                     "Crosswalk version label drift")
            mapped += 1
        elif status == "unmapped":
            _require(entry["tds_candidate_slug"] is None
                     and entry["tds_title_observed"] is None
                     and entry["tds_version_label_observed"] is None,
                     "Unmapped course must not acquire institutional identifiers")
            unmapped_ids.add(course_id)
        else:
            raise CrosswalkError("Mapping status must be candidate_review or unmapped")

    _require(wp_ids == set(indexed_lp), "Crosswalk did not cover all observed EAD IDs")
    _require(assigned_slugs == set(indexed_tds), "Crosswalk did not cover 9 TDS slugs")
    _require(mapped == 9 and unmapped_ids == {1474, 1709},
             "The two additional EAD offers must remain explicitly unmapped")
    return {"snapshot": "PASS", "crosswalk": "PASS", "ead_offers": len(lp_courses),
            "tds_courses": len(tds_courses), "candidate_matches": mapped,
            "unmapped_wp_ids": sorted(unmapped_ids), "authoritative_links": 0,
            "institutional_permissions_granted": 0, "status": "CANDIDATE_ONLY"}


def compare_live(snapshot: dict, lp_live: Any, tds_live: Any) -> None:
    lp = normalize_lp(lp_live)
    tds = normalize_tds(tds_live)
    expected_lp = normalize_lp(snapshot["learnpress"])
    expected_tds = normalize_tds({"courses": snapshot["tds"]})
    _require(lp == expected_lp, "DRIFT: live LearnPress public course IDs/titles changed")
    _require(tds == expected_tds, "DRIFT: live TDS public slugs/titles/labels changed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Public-only LearnPress/TDS crosswalk audit")
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--crosswalk", type=Path, default=DEFAULT_CROSSWALK)
    parser.add_argument("--live", action="store_true",
                        help="GET allowlisted public endpoints, never update snapshots")
    args = parser.parse_args(argv)
    try:
        snap = json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
        crosswalk = json.loads(args.crosswalk.read_text(encoding="utf-8-sig"))
        result = validate(snap, crosswalk)
        if args.live:
            compare_live(snap, read_public_json(LP_URL), read_public_json(TDS_URL))
            result["live"] = "PASS"
        else:
            result["live"] = "NOT_RUN"
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    except (CrosswalkError, ValueError, OSError, json.JSONDecodeError) as exc:
        # Do not log raw HTTP responses or full path contents.
        print(f"AUDIT_BLOCKED: {type(exc).__name__}: {str(exc)[:180]}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
