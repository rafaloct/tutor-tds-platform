"""Offline, dependency-free safety regression tests for the candidate course map."""
from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit import (  # noqa: E402
    DEFAULT_CROSSWALK,
    DEFAULT_SNAPSHOT,
    CrosswalkError,
    LP_URL,
    TDS_URL,
    compare_live,
    main,
    normalize_lp,
    normalize_tds,
    read_public_json,
    validate,
)


class CrosswalkSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.snapshot = json.loads(DEFAULT_SNAPSHOT.read_text(encoding="utf-8"))
        cls.crosswalk = json.loads(DEFAULT_CROSSWALK.read_text(encoding="utf-8"))

    def setUp(self) -> None:
        self.source = copy.deepcopy(self.snapshot)
        self.map = copy.deepcopy(self.crosswalk)

    def blocked(self, message_fragment: str | None = None) -> None:
        with self.assertRaises(CrosswalkError) as raised:
            validate(self.source, self.map)
        if message_fragment is not None:
            self.assertIn(message_fragment, str(raised.exception))

    def test_frozen_snapshot_is_public_metadata_only(self) -> None:
        for item in self.source["learnpress"]:
            self.assertEqual({"id", "name"}, set(item))
        for item in self.source["tds"]:
            self.assertEqual(
                {"slug", "title", "status", "published_version_label"},
                set(item),
            )
        raw = json.dumps(self.source).lower()
        for forbidden in ("cpf", "email", "token", "password", "phone",
                          "instructor", "user_id", "meta_data"):
            self.assertNotIn(forbidden, raw)

    def test_baseline_passes_without_institutional_grants(self) -> None:
        result = validate(self.source, self.map)
        self.assertEqual(11, result["ead_offers"])
        self.assertEqual(9, result["candidate_matches"])
        self.assertEqual([1474, 1709], result["unmapped_wp_ids"])
        self.assertEqual(0, result["institutional_permissions_granted"])
        self.assertEqual("CANDIDATE_ONLY", result["status"])

    def test_no_fictitious_course_version_id(self) -> None:
        self.map["entries"][0]["tds_course_version_id"] = "v1"
        self.blocked("CourseVersion ID")

    def test_mapping_must_not_grant_institutional_access(self) -> None:
        self.map["entries"][0]["institutional_access"] = True
        self.blocked("institutional_access")

    def test_mapping_must_not_grant_rag_context(self) -> None:
        self.map["entries"][0]["rag_authorized"] = True
        self.blocked("rag_authorized")

    def test_mapping_must_not_grant_certificate(self) -> None:
        self.map["entries"][0]["certificate_authorized"] = True
        self.blocked("certificate_authorized")

    def test_editorial_review_cannot_be_fabricated(self) -> None:
        self.map["entries"][0]["editorial_approval"] = "approved"
        self.blocked("Editorial sign-off")

    def test_entire_map_cannot_self_approve(self) -> None:
        self.map["review_state"] = "APPROVED"
        self.blocked("cannot self-approve")

    def test_learnpress_duplicate_id_rejected(self) -> None:
        self.source["learnpress"][1]["id"] = self.source["learnpress"][0]["id"]
        self.blocked("duplicate course id")

    def test_tds_duplicate_slug_rejected(self) -> None:
        self.source["tds"][1]["slug"] = self.source["tds"][0]["slug"]
        self.blocked("duplicate slug")

    def test_crosswalk_duplicate_id_rejected(self) -> None:
        self.map["entries"][1]["wp_course_id"] = self.map["entries"][0]["wp_course_id"]
        self.blocked("repeats LearnPress ID")

    def test_unknown_wp_course_rejected(self) -> None:
        self.map["entries"][0]["wp_course_id"] = 999999
        self.blocked("unknown LearnPress ID")

    def test_unknown_tds_slug_rejected(self) -> None:
        row = next(e for e in self.map["entries"] if e["mapping_status"] == "candidate_review")
        row["tds_candidate_slug"] = "made-up-slug"
        self.blocked("unknown institutional slug")

    def test_duplicate_tds_assignment_rejected(self) -> None:
        rows = [e for e in self.map["entries"] if e["mapping_status"] == "candidate_review"]
        rows[1]["tds_candidate_slug"] = rows[0]["tds_candidate_slug"]
        self.blocked("assigned more than once")

    def test_unmapped_additional_lp_course_cannot_be_assigned(self) -> None:
        row = next(e for e in self.map["entries"] if e["wp_course_id"] == 1474)
        row["mapping_status"] = "candidate_review"
        row["tds_candidate_slug"] = "saf"
        self.blocked()

    def test_unmapped_does_not_keep_accidental_tds_field(self) -> None:
        row = next(e for e in self.map["entries"] if e["wp_course_id"] == 1709)
        row["tds_candidate_slug"] = "saf"
        self.blocked("must not acquire")

    def test_mapping_review_state_required(self) -> None:
        self.map["entries"][0]["mapping_status"] = "auto_approved"
        self.blocked("candidate_review or unmapped")

    def test_missing_lp_row_rejected(self) -> None:
        self.map["entries"].pop()
        self.blocked("exactly 11")

    def test_title_drift_requires_review(self) -> None:
        self.source["learnpress"][0]["name"] += " revisado"
        self.blocked("LearnPress title drift")

    def test_institutional_title_drift_requires_review(self) -> None:
        row = next(e for e in self.map["entries"] if e["mapping_status"] == "candidate_review")
        row["tds_title_observed"] += " revisado"
        self.blocked("institutional title drift")

    def test_version_label_drift_requires_review(self) -> None:
        row = next(e for e in self.map["entries"] if e["mapping_status"] == "candidate_review")
        row["tds_version_label_observed"] = "v999"
        self.blocked("version label drift")

    def test_alternate_source_host_rejected(self) -> None:
        self.map["sources"]["learnpress"] = "https://third-party.example/courses"
        self.blocked("source URLs differ")

    def test_snapshot_must_reject_private_extra_fields(self) -> None:
        self.source["learnpress"][0]["email"] = "must-not-ship@example.invalid"
        self.blocked("unexpected LearnPress fields")

    def test_snapshot_must_reject_private_tds_fields(self) -> None:
        self.source["tds"][0]["user_id"] = "must-not-ship"
        self.blocked("unexpected TDS fields")

    def test_extra_private_data_field_rejected(self) -> None:
        self.map["entries"][0]["cpf"] = "forbidden"
        self.blocked("unexpected or missing")

    def test_real_lp_drift_fails_closed(self) -> None:
        live = copy.deepcopy(self.source["learnpress"])
        live[0]["name"] += " nova edicao"
        with self.assertRaisesRegex(CrosswalkError, "DRIFT"):
            compare_live(self.source, live, {"courses": self.source["tds"]})

    def test_real_tds_drift_fails_closed(self) -> None:
        live = copy.deepcopy(self.source["tds"])
        live[0]["published_version_label"] = "v2"
        with self.assertRaisesRegex(CrosswalkError, "DRIFT"):
            compare_live(self.source, self.source["learnpress"], {"courses": live})

    def test_live_comparison_current_snapshot(self) -> None:
        compare_live(self.source, self.source["learnpress"],
                     {"courses": self.source["tds"], "total": 9})

    def test_bad_url_refused_before_network(self) -> None:
        for bad_url in ("http://" + LP_URL[8:],
                        "https://other.example/wp-json/learnpress/v1/courses",
                        LP_URL + "&password=example",
                        TDS_URL + "/extra"):
            with self.subTest(bad_url=bad_url):
                with self.assertRaisesRegex(CrosswalkError, "allowlisted"):
                    read_public_json(bad_url)

    def test_lp_bool_id_rejected(self) -> None:
        self.source["learnpress"][0]["id"] = True
        self.blocked("invalid course id")

    def test_tds_unpublished_state_rejected(self) -> None:
        self.source["tds"][0]["status"] = "draft"
        self.blocked("unpublished")

    def test_no_automatic_snapshot_update(self) -> None:
        self.assertEqual(0, main(["--snapshot", str(DEFAULT_SNAPSHOT),
                                   "--crosswalk", str(DEFAULT_CROSSWALK)]))
        self.assertEqual(self.source, json.loads(DEFAULT_SNAPSHOT.read_text("utf-8")))
        self.assertEqual(self.map, json.loads(DEFAULT_CROSSWALK.read_text("utf-8")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
