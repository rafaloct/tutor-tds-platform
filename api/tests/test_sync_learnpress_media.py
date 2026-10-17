"""Fail-closed contract tests for the LearnPress media snapshot bridge."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ops"))
import sync_learnpress_media as sync


def row(**changes):
    data = {
        "wp_course_id": 1356, "wp_lesson_id": 1425, "app_course_id": "saf",
        "mapping_status": "verified_by_id_and_module", "module_id": "introducao",
        "wp_post_status": "publish",
        "source_mp4_url": "https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/a.mp4",
        "thumbnail_url": "https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/a.jpg",
        "duration_seconds": 242, "lesson_title": "Aula SAF",
    }
    data.update(changes)
    return data


DELIVERY = {"1425": {
    "provider": "youtube", "provider_asset_id": "FG14ksTaMCE",
    "competency_id": "video-saf-introducao", "followup_activity_id": "quiz-saf",
}}
LINEAGE = {"institution_id": "qa-inst", "program_id": "qa-program",
           "creator_user_id": "qa-creator"}


def plan(rows=None, delivery=None, review=None):
    return sync.plan_media(
        {"manifest_version": 2, "videos": [row()] if rows is None else rows},
        DELIVERY if delivery is None else delivery,
        {} if review is None else review, LINEAGE,
    )


class FakeApi:
    base = sync.PILOT_STAGING_URL

    def __init__(self, status=201):
        self.status = status
        self.calls = []

    def request(self, path, *, method="GET", body=None, token=None):
        self.calls.append((method, path, body, token))
        if path == "/admin/media":
            return self.status, {"id": "qa-media-1", "status": "draft"}
        if path == "/version":
            return 200, {"environment": "staging"}
        if path == "/auth/login":
            return 200, {"access_token": "test-token"}
        raise AssertionError(path)


class SyncLearnPressMediaTests(unittest.TestCase):
    def test_pilot_payload_is_draft_safe(self):
        eligible, blocked = plan()
        self.assertFalse(blocked)
        self.assertEqual(len(eligible), 1)
        p = eligible[0]["payload"]
        self.assertFalse(p["rights_confirmed"])
        self.assertEqual(p["offline_policy"], "forbidden")
        self.assertEqual(p["visibility"], "enrolled")
        self.assertEqual(p["provider_asset_id"], "FG14ksTaMCE")
        self.assertEqual(p["captions"], [])

    def test_unuploaded_and_unreviewed_block(self):
        eligible, blocked = plan(delivery={})
        self.assertEqual(len(eligible), 0)
        self.assertIn("Upload", blocked[0][1])
        unreviewed = {**DELIVERY["1425"], "competency_id": None}
        eligible, blocked = plan(delivery={"1425": unreviewed})
        self.assertFalse(eligible)
        self.assertIn("Competência", blocked[0][1])

    def test_ia_proposed_mapping_needs_approval(self):
        item = row(mapping_status="linked_in_module_section_pending_app_module_review",
                   module_id=None)
        eligible, blocked = plan(rows=[item])
        self.assertFalse(eligible)
        self.assertIn("revisão humana", blocked[0][1])
        review = {"1425": {"approved": True, "module_id": "tipos"}}
        eligible, blocked = plan(rows=[item], review=review)
        self.assertFalse(blocked)
        self.assertEqual(eligible[0]["payload"]["module_id"], "tipos")

    def test_review_cannot_override_verified_module(self):
        eligible, blocked = plan(review={"1425": {"approved": True, "module_id": "pratica"}})
        self.assertFalse(eligible)
        self.assertIn("diverge", blocked[0][1])

    def test_duplicate_lesson_fails_closed(self):
        with self.assertRaisesRegex(sync.SyncBlocked, "duplicado"):
            plan(rows=[row(), row()])

    def test_provider_asset_cannot_be_reused_in_another_lesson(self):
        second = row(wp_lesson_id=1426, lesson_title="Aula nova")
        delivery = {**DELIVERY, "1426": dict(DELIVERY["1425"])}
        with self.assertRaisesRegex(sync.SyncBlocked, "Mesmo asset"):
            plan(rows=[row(), second], delivery=delivery)

    def test_bogus_source_and_provider_are_rejected(self):
        eligible, blocked = plan(rows=[row(source_mp4_url="http://localhost/asset.mp4")])
        self.assertFalse(eligible)
        self.assertIn("MP4", blocked[0][1])
        d = {"1425": {**DELIVERY["1425"], "provider": "external_hls",
                      "provider_asset_id": "https://a.example/video.m3u8"}}
        eligible, blocked = plan(delivery=d)
        self.assertFalse(eligible)
        self.assertIn("YouTube", blocked[0][1])

    def test_unpublished_lesson_rejected(self):
        eligible, blocked = plan(rows=[row(wp_post_status="draft")])
        self.assertFalse(eligible)
        self.assertIn("não publicada", blocked[0][1])

    def test_production_and_tricky_urls_rejected(self):
        for u in ("https://ead.ipexdesenvolvimento.cloud/tutor-api",
                  "http://ead.ipexdesenvolvimento.cloud/tutor-staging-api",
                  "https://evil.example/tutor-staging-api",
                  "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api/../tutor-api",
                  "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api?prod=1"):
            with self.subTest(url=u), self.assertRaises(sync.SyncBlocked):
                sync.verify_target(u)
        self.assertEqual(sync.verify_target(sync.PILOT_STAGING_URL + "/"),
                         sync.PILOT_STAGING_URL)

    def test_preflight_requires_environment_and_secret(self):
        fake = FakeApi()
        with self.assertRaisesRegex(sync.SyncBlocked, "Credenciais"):
            sync.preflight(fake, {})
        self.assertEqual([c[1] for c in fake.calls], ["/version"])
        class ProdApi(FakeApi):
            def request(self, path, **kw):
                return 200, {"environment": "production"}
        with self.assertRaisesRegex(sync.SyncBlocked, "staging"):
            sync.preflight(ProdApi(), {"TDS_ADMIN_CPF": "a", "TDS_ADMIN_PASSWORD": "b"})

    def test_preflight_validates_token(self):
        self.assertEqual(sync.preflight(FakeApi(), {
            "TDS_ADMIN_CPF": "fake", "TDS_ADMIN_PASSWORD": "fake",
        }), "test-token")

    def test_draft_created_once_with_atomic_checkpoint(self):
        entry = plan()[0][0]
        api = FakeApi()
        with tempfile.TemporaryDirectory() as t:
            state = Path(t) / "state.json"
            self.assertEqual(sync.execute_one(entry, api, "token", state), "DRAFT_CREATED")
            record = json.loads(state.read_text(encoding="utf-8"))
            self.assertEqual(record["items"]["1425"]["media_id"], "qa-media-1")
            self.assertEqual(record["target"], sync.PILOT_STAGING_URL)
            self.assertEqual(sync.execute_one(entry, api, "token", state), "SKIP_ALREADY_RECORDED")
            self.assertEqual(len(api.calls), 1)
            self.assertEqual(api.calls[0][2]["rights_confirmed"], False)
            self.assertNotIn("/publish", api.calls[0][1])
            changed = {**entry, "sha256": "other"}
            with self.assertRaisesRegex(sync.SyncBlocked, "Mudança"):
                sync.execute_one(changed, api, "token", state)

    def test_409_recorded_and_requires_manual_reconciliation(self):
        entry = plan()[0][0]
        api = FakeApi(status=409)
        with tempfile.TemporaryDirectory() as t:
            state = Path(t) / "state.json"
            result = sync.execute_one(entry, api, "token", state)
            self.assertIn("CONFLICT_409", result)
            with self.assertRaises(sync.SyncBlocked):
                sync.execute_one(entry, api, "token", state)
            self.assertEqual(len(api.calls), 1)

    def test_checkpoint_cannot_move_to_other_target(self):
        with tempfile.TemporaryDirectory() as t:
            state = Path(t) / "state.json"
            state.write_text(json.dumps({"schema_version": 1, "target": "production",
                                         "items": {}}), encoding="utf-8")
            with self.assertRaisesRegex(sync.SyncBlocked, "Checkpoint"):
                sync.load_checkpoint(state, sync.PILOT_STAGING_URL)

    def test_dry_run_does_not_call_api_or_write_state(self):
        with tempfile.TemporaryDirectory() as t:
            td = Path(t)
            manifest = td / "manifest.json"
            delivery = td / "delivery.json"
            manifest.write_text(json.dumps({"manifest_version": 2, "videos": [row()]}), encoding="utf-8")
            delivery.write_text(json.dumps(DELIVERY), encoding="utf-8")
            with patch.object(sync.Api, "request", side_effect=AssertionError("network used")):
                self.assertEqual(sync.main(["--manifest", str(manifest),
                                            "--delivery", str(delivery)]), 0)
            self.assertEqual(sorted(p.name for p in td.iterdir()),
                             ["delivery.json", "manifest.json"])
            with self.assertRaisesRegex(sync.SyncBlocked, "lesson-id"):
                sync.main(["--manifest", str(manifest), "--delivery", str(delivery),
                           "--execute"])

    def test_execute_refuses_stale_wordpress_before_login_or_post(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "manifest.json"
            delivery = root / "delivery.json"
            state = root / "checkpoint.json"
            manifest.write_text(json.dumps({"manifest_version": 2, "videos": [row()]}),
                                encoding="utf-8")
            delivery.write_text(json.dumps(DELIVERY), encoding="utf-8")
            env = {"TDS_INSTITUTION_ID": "staging-qa-institution",
                   "TDS_PROGRAM_ID": "staging-qa-program",
                   "TDS_CREATOR_USER_ID": "staging-qa-admin"}
            with patch.dict(sync.os.environ, env), patch.object(
                    sync, "audit_live", side_effect=sync.AuditBlocked("WordPress HTTP 522")):
                with patch.object(sync.Api, "request",
                                  side_effect=AssertionError("staging API must not be contacted")):
                    with self.assertRaisesRegex(sync.AuditBlocked, "522"):
                        sync.main(["--manifest", str(manifest), "--delivery", str(delivery),
                                   "--lesson-id", "1425", "--state", str(state),
                                   "--execute"])
            self.assertFalse(state.exists())

    def test_execute_requires_verified_live_curriculum_before_draft(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "manifest.json"
            delivery = root / "delivery.json"
            state = root / "checkpoint.json"
            manifest.write_text(json.dumps({"manifest_version": 2, "videos": [row()]}),
                                encoding="utf-8")
            delivery.write_text(json.dumps(DELIVERY), encoding="utf-8")
            env = {"TDS_INSTITUTION_ID": "staging-qa-institution",
                   "TDS_PROGRAM_ID": "staging-qa-program",
                   "TDS_CREATOR_USER_ID": "staging-qa-admin",
                   "TDS_ADMIN_CPF": "synthetic",
                   "TDS_ADMIN_PASSWORD": "synthetic"}
            called = []
            def request(_self, path, **kwargs):
                called.append(path)
                if path == "/version":
                    return 200, {"environment": "staging"}
                if path == "/auth/login":
                    return 200, {"access_token": "fake"}
                if path == "/admin/media":
                    return 201, {"id": "draft-synthetic", "status": "draft"}
                raise AssertionError(path)
            with patch.dict(sync.os.environ, env), patch.object(
                    sync, "audit_live", return_value={"status": "PASS"}) as check:
                with patch.object(sync.Api, "request", request):
                    self.assertEqual(sync.main([
                        "--manifest", str(manifest), "--delivery", str(delivery),
                        "--lesson-id", "1425", "--state", str(state), "--execute"
                    ]), 0)
            check.assert_called_once()
            self.assertEqual(called, ["/version", "/auth/login", "/admin/media"])
            self.assertTrue(state.exists())


if __name__ == "__main__":
    unittest.main()
