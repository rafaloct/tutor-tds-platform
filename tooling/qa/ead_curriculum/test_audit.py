"""Contracts for read-only curriculum comparison; all inputs are synthetic."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit


def fixtures():
    courses = {}
    details = {}
    locals_ = {}
    for cid, (canonical, sections, amount) in audit.VIDEO_SECTION_IDS.items():
        courses[cid] = {"id": cid, "slug": f"course-{cid}", "name": "Course"}
        sec = []
        for sid in sorted(sections):
            ids = [{"id": cid * 100 + i, "type": "lp_lesson",
                    "title": f"Aula {i}"} for i in range(amount)]
            # IA uses several video sections, split the 12 across four sections.
            if cid == 614:
                offset = sorted(sections).index(sid) * 3
                ids = [{"id": cid * 100 + offset + i, "type": "lp_lesson",
                        "title": f"Aula {offset + i}"} for i in range(3)]
            sec.append({"id": sid, "title": "Vídeos", "items": ids})
        details[cid] = {"id": cid, "name": "Course", "sections": sec}
        locals_[canonical] = {"sections": 5, "formative_question_blocks": 4,
                             "published_quiz_blocks": 0,
                             "correct_markers_in_bundled_assets": 0,
                             "version_id_present": True}
    quizzes = [{"id": 42, "title": "Quiz legado", "slug": "quiz-legado",
                "curriculum_association": "UNVERIFIED"}]
    return courses, details, quizzes, locals_


class CurriculumAuditTests(unittest.TestCase):
    def test_nine_courses_and_no_fabricated_quiz_association(self):
        cases = fixtures()
        result = audit.assemble(*cases)
        self.assertEqual(result["validation"], "PASS")
        self.assertEqual(result["course_count"], 9)
        self.assertEqual(result["video_section_candidates"], 48)
        self.assertEqual(result["local_formative_questions"], 36)
        self.assertEqual(result["linked_quizzes_to_current_nine"], 0)
        self.assertEqual(result["unlinked_quiz_ids"], [42])
        self.assertFalse(any("isCorrect" in str(r) for r in result["courses"]))

    def test_changed_video_section_detected_without_guessing(self):
        courses, details, quizzes, locals_ = fixtures()
        details[1356]["sections"][0]["items"].pop()
        result = audit.assemble(courses, details, quizzes, locals_)
        self.assertEqual(result["validation"], "BLOCKED")
        changed = next(c for c in result["courses"] if c["wp_course_id"] == 1356)
        self.assertEqual(changed["validation"], "VIDEO_CATALOG_DRIFT")

    def test_duplicate_lesson_blocks(self):
        _, details, _, locals_ = fixtures()
        details[1356]["sections"][0]["items"][1]["id"] = details[1356]["sections"][0]["items"][0]["id"]
        with self.assertRaisesRegex(audit.AuditError, "duplicada"):
            audit.audit_course(1356, details[1356], locals_["saf"])

    def test_unknown_kind_blocks_not_assumed_quiz(self):
        _, details, _, locals_ = fixtures()
        details[1356]["sections"][0]["items"][0]["type"] = "lp_unknown"
        with self.assertRaisesRegex(audit.AuditError, "desconhecido"):
            audit.audit_course(1356, details[1356], locals_["saf"])

    def test_real_quiz_item_needs_review_and_is_not_video(self):
        courses, details, quizzes, locals_ = fixtures()
        extra = {"id": 42, "type": "lp_quiz", "title": "Quiz comprovado"}
        details[1356]["sections"][0]["items"].append(extra)
        result = audit.assemble(courses, details, quizzes, locals_)
        course = next(c for c in result["courses"] if c["wp_course_id"] == 1356)
        self.assertEqual(course["linked_quiz_ids"], [42])
        row = course["sections"][0]["items"][-1]
        self.assertEqual(row["assessment_status"], "REQUIRES_TEACHER_REVIEW")
        self.assertFalse(row["video_candidate"])

    def test_quiz_in_curriculum_must_exist_in_public_bank(self):
        cases = fixtures()
        courses, details, quizzes, locals_ = cases
        details[1356]["sections"][0]["items"].append(
            {"id": 99, "type": "lp_quiz", "title": "Quiz não indexado"})
        with self.assertRaisesRegex(audit.AuditError, "sem cadastro público"):
            audit.assemble(courses, details, quizzes, locals_)

    def test_read_local_hides_options_and_answer_text(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            payload = {
                "id": "saf",
                "course_version_id": "synthetic-version",
                "sections": [{"id": "x", "messages": [
                    {"type": "question", "content": "Sensitive question",
                     "options": [{"label": "SECRET ANSWER", "isCorrect": True}]},
                    {"type": "quiz", "content": "Secret quiz",
                     "options": [{"label": "B", "isCorrect": False}]},
                ]}],
            }
            (folder / "saf.json").write_text(json.dumps(payload), encoding="utf-8")
            output = audit.read_local("saf", folder)
            self.assertEqual(output["formative_question_blocks"], 1)
            self.assertEqual(output["published_quiz_blocks"], 1)
            self.assertEqual(output["correct_markers_in_bundled_assets"], 1)
            self.assertNotIn("SECRET", str(output))
            self.assertNotIn("Sensitive", str(output))

    def test_reject_unsafe_url(self):
        for url in (
            "http://ead.ipexdesenvolvimento.cloud/wp-json/wp/v2/lp_quiz",
            "https://example.com/wp-json/wp/v2/lp_quiz",
            "https://ead.ipexdesenvolvimento.cloud/wp-json/wp/v2/users",
            "https://ead.ipexdesenvolvimento.cloud/wp-admin/",
        ):
            with self.subTest(url=url), self.assertRaises(audit.AuditError):
                audit.get_json(url)

    def test_result_is_read_only_and_does_not_write_without_output(self):
        cases = fixtures()
        with patch.object(audit, "get_json", side_effect=AssertionError("no network")):
            result = audit.assemble(*cases)
        self.assertEqual(result["validation"], "PASS")


if __name__ == "__main__":
    unittest.main()
