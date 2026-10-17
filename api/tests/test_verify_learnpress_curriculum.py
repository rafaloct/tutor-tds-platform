"""Curriculum drift detection for the read-only LearnPress GET bridge."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ops"))
import verify_learnpress_curriculum as audit


def row(course, lesson, section, order, title, mapping):
    return {
        "wp_course_id": course, "wp_lesson_id": lesson,
        "wp_section_id": section, "lesson_order": order, "lesson_title": title,
        "mapping_status": mapping, "app_course_id": "saf" if course == 1356 else "ia-cartilha",
    }


def sample():
    manifest = {
        "manifest_version": 2,
        "videos": [
            row(1356, 1425, 82, 1, "Aula SAF", "verified_by_id_and_module"),
            row(1356, 1426, 82, 2, "Benefícios", "verified_by_id_and_module"),
            row(614, 1295, 28, 1, "Onde a IA aparece", "linked_in_module_section_pending_app_module_review"),
            row(614, 1396, 28, 2, "Como IA aprende", "linked_in_module_section_pending_app_module_review"),
            row(614, 1403, 78, 11, "Privacidade", "linked_in_module_section_pending_app_module_review"),
        ],
    }
    courses = {
        "1356": {
            "id": 1356,
            "sections": [{
                "id": 82, "title": "Assista em vídeo",
                "items": [{"id": 1425, "title": "Aula SAF"},
                          {"id": 1426, "title": "Benefícios"}],
            }],
        },
        "614": {
            "id": 614,
            "sections": [{
                "id": 28, "title": "Módulo 1",
                "items": [{"id": 6000, "title": "Introdução"},
                          {"id": 1295, "title": "Onde a IA aparece"},
                          {"id": 1396, "title": "Como IA aprende"}],
            }, {
                "id": 78, "title": "Módulo 4",
                "items": [{"id": 1403, "title": "Privacidade"}],
            }],
        },
    }
    return manifest, courses


class VerifyLearnPressCurriculumTests(unittest.TestCase):
    def test_matching_curriculum_is_valid_and_deterministic(self):
        m, c = sample()
        result = audit.compare_curriculum(m, c)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["courses_checked"], 2)
        self.assertEqual(result["lessons_checked"], 5)
        self.assertEqual(result["structure_sha256"],
                         audit.compare_curriculum(m, c)["structure_sha256"])

    def test_reordered_ordinary_videos_are_blocked(self):
        m, c = sample()
        c["1356"]["sections"][0]["items"].reverse()
        result = audit.compare_curriculum(m, c)
        self.assertEqual(result["status"], "BLOCKED")
        self.assertIn("VIDEO_SECTION_CHANGED", [x["kind"] for x in result["problems"]])

    def test_added_video_requires_review(self):
        m, c = sample()
        c["1356"]["sections"][0]["items"].append({"id": 1500, "title": "Nova aula"})
        self.assertEqual(audit.compare_curriculum(m, c)["status"], "BLOCKED")

    def test_missing_lesson_blocked(self):
        m, c = sample()
        c["614"]["sections"][0]["items"] = [
            x for x in c["614"]["sections"][0]["items"] if x["id"] != 1295
        ]
        result = audit.compare_curriculum(m, c)
        self.assertIn("LESSON_MISSING", [x["kind"] for x in result["problems"]])

    def test_moved_lesson_blocked(self):
        m, c = sample()
        moved = c["614"]["sections"][0]["items"].pop()
        c["614"]["sections"][1]["items"].append(moved)
        result = audit.compare_curriculum(m, c)
        self.assertIn("LESSON_MOVED_OR_DUPLICATED", [x["kind"] for x in result["problems"]])

    def test_ia_order_changed_blocked_while_extra_text_is_allowed(self):
        m, c = sample()
        c["614"]["sections"][0]["items"].reverse()
        self.assertIn("IA_LESSON_ORDER_CHANGED",
                      [x["kind"] for x in audit.compare_curriculum(m, c)["problems"]])
        c["614"]["sections"][0]["items"].reverse()
        self.assertEqual(audit.compare_curriculum(m, c)["status"], "PASS")

    def test_title_changed_in_verified_lesson(self):
        m, c = sample()
        c["1356"]["sections"][0]["items"][0]["title"] = "Aula SAF revista"
        result = audit.compare_curriculum(m, c)
        self.assertIn("TITLE_CHANGED", [x["kind"] for x in result["problems"]])

    def test_course_mismatch_and_malformed_items_fail_closed(self):
        m, c = sample()
        c["1356"]["id"] = 614
        with self.assertRaisesRegex(audit.AuditBlocked, "inesperado"):
            audit.compare_curriculum(m, c)
        m, c = sample()
        c["1356"]["sections"][0]["items"] = [{"id": "not-id"}]
        with self.assertRaisesRegex(audit.AuditBlocked, "lesson.id"):
            audit.compare_curriculum(m, c)

    def test_no_live_network_during_fixture_audit(self):
        m, c = sample()
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "manifest.json"
            fixture = Path(tmp) / "fixture.json"
            manifest.write_text(json.dumps(m), encoding="utf-8")
            fixture.write_text(json.dumps(c), encoding="utf-8")
            with patch.object(audit, "fetch_course", side_effect=AssertionError("network")):
                self.assertEqual(audit.main([
                    "--manifest", str(manifest), "--fixture", str(fixture)
                ]), 0)

    def test_live_api_read_is_explicitly_pinned_to_expected_courses(self):
        m, _ = sample()
        called = []
        def fake_fetch(cid):
            called.append(cid)
            return sample()[1][str(cid)]
        with patch.object(audit, "fetch_course", side_effect=fake_fetch):
            self.assertEqual(audit.audit_live(m)["status"], "PASS")
        self.assertEqual(called, [614, 1356])

    def test_offline_fixture_missing_course_is_blocking(self):
        m, c = sample()
        del c["614"]
        with self.assertRaisesRegex(audit.AuditBlocked, "não foi reconsultado"):
            audit.compare_curriculum(m, c)

    def test_unsafe_redirect_is_rejected(self):
        handler = audit._NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, "redirect", {}, "https://evil.example"))

    def test_corrupted_manifest_and_duplicate_ids_block(self):
        m, c = sample()
        m["videos"].append(dict(m["videos"][0]))
        with self.assertRaisesRegex(audit.AuditBlocked, "duplicada"):
            audit.compare_curriculum(m, c)

    def test_get_only_same_origin_json_and_reject_non_json(self):
        class Response:
            status = 200
            def __init__(self, kind):
                self.headers = {"Content-Type": kind}
            def read(self, limit):
                return b'{"id":1356,"sections":[]}'
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                return None

        class Opener:
            def __init__(self, content_type):
                self.content_type = content_type
            def open(self, request, timeout=0):
                self_request = request
                assert self_request.full_url == (
                    "https://ead.ipexdesenvolvimento.cloud/wp-json/learnpress/v1/courses/1356"
                )
                assert self_request.get_method() == "GET"
                assert timeout > 0
                return Response(self.content_type)

        with patch.object(audit.urllib.request, "build_opener",
                          return_value=Opener("application/json")):
            self.assertEqual(audit.fetch_course(1356)["id"], 1356)
        with patch.object(audit.urllib.request, "build_opener",
                          return_value=Opener("text/html")):
            with self.assertRaisesRegex(audit.AuditBlocked, "não JSON"):
                audit.fetch_course(1356)

    def test_reject_oversized_live_response(self):
        class Response:
            status = 200
            headers = {"Content-Type": "application/json"}
            def read(self, limit):
                return b"x" * limit
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                return None

        class Opener:
            def open(self, *_args, **_kwargs):
                return Response()

        with patch.object(audit.urllib.request, "build_opener", return_value=Opener()):
            with self.assertRaisesRegex(audit.AuditBlocked, "excessiva"):
                audit.fetch_course(1356)


if __name__ == "__main__":
    unittest.main()
