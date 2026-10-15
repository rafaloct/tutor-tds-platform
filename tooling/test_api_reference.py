"""Regression checks for executable examples; only disposable local SQLite is used."""
from __future__ import annotations

from datetime import datetime, timezone
import json
import shlex
import unittest
from unittest.mock import patch

import generate_api_reference as reference
from fastapi.testclient import TestClient
from pydantic import TypeAdapter
from sqlalchemy.orm import Session

from app.auth import access_claims
from app.config import Settings
from app.main import create_app
from app.media import MediaCreate
from app.models import Base, MediaAsset


class ExecutableExamplesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        artifacts, _ = reference.generate()
        cls.examples = json.loads(artifacts["examples.json"])
        cls.by_key = {
            f"{method} {route.path}": route
            for route in reference.routes(reference.app.routes)
            for method in route.methods
        }

    def setUp(self):
        self.application = create_app(settings=Settings(
            database_url="sqlite+pysqlite:///:memory:",
            allowed_origins=(),
            jwt_secret="local-example-test-secret-at-least-32-chars",
            cpf_pepper="local-example-test-pepper-at-least-32-chars",
        ))
        Base.metadata.create_all(self.application.state.database.engine)
        self.client = TestClient(self.application)
        self.media_id = self.examples["POST /admin/media"]["response"]["body"]["id"]
        request = self.examples["POST /admin/media"]["request"]["body"]
        payload = MediaCreate.model_validate(request)
        # The docs explicitly require editorial rights confirmation before publish.
        with Session(self.application.state.database.engine) as session:
            session.add(MediaAsset(
                id=self.media_id,
                creator_user_id=payload.creator_user_id or reference.UUID,
                status="draft",
                **(payload.model_dump(exclude={"creator_user_id"}) | {"rights_confirmed": True}),
            ))
            session.commit()

    def tearDown(self):
        self.client.close()
        self.application.state.database.dispose()

    def test_anonymous_curl_succeeds_without_a_token(self):
        """The previous optional Bearer header caused 401 for public fixtures."""
        with Session(self.application.state.database.engine) as session:
            media = session.get(MediaAsset, self.media_id)
            media.status = "published"
            media.published_at = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)
            session.commit()
        for key in ("GET /media", "GET /media/{media_id}"):
            with self.subTest(operation=key):
                example = self.examples[key]["request"]
                command = reference.curl_example("GET", example["path"], self.by_key[key], None)
                self.assertNotIn("Authorization", shlex.split(command))
                self.assertNotIn("TDS_ACCESS_TOKEN", command)
                self.assertEqual(self.client.get(example["path"]).status_code, 200)
                self.assertEqual(self.client.get(example["path"], headers={"Authorization": "Bearer "}).status_code, 401)
        required = reference.curl_example("GET", "/auth/me", self.by_key["GET /auth/me"], None)
        self.assertIn("Authorization: Bearer ${TDS_ACCESS_TOKEN}", required)

    def test_documented_media_transitions_match_real_handlers(self):
        """Compare generated examples to real publish/block/archive effects."""
        # This verifies state transitions and serializers, not authorization policy.
        self.application.dependency_overrides[access_claims] = lambda: {"sub": reference.UUID, "role": "admin"}
        for action in ("publish", "block", "archive"):
            key = f"POST /admin/media/{{media_id}}/{action}"
            example = self.examples[key]
            published_at = datetime.fromisoformat(example["response"]["body"]["published_at"])
            with self.subTest(operation=key), patch("app.media.datetime", wraps=datetime) as clock:
                clock.now.return_value = published_at
                response = self.client.post(example["request"]["path"], json=example["request"]["body"])
                self.assertEqual(response.status_code, example["response"]["status"], response.text)
                adapter = TypeAdapter(self.by_key[key].response_model)
                actual = adapter.validate_python(response.json()).model_dump()
                expected = adapter.validate_python(example["response"]["body"]).model_dump()
                # SQLite drops the UTC offset on roundtrip; compare the same instant.
                for body in (actual, expected):
                    body["published_at"] = body["published_at"].replace(tzinfo=timezone.utc)
                self.assertEqual(actual, expected)

    def test_json_request_survives_shell_quoting(self):
        """A synthetic apostrophe must remain part of the JSON body, not shell code."""
        payload = {"title": "D'água $(not-a-command)"}
        command = reference.curl_example("POST", "/admin/media", self.by_key["POST /admin/media"], payload)
        words = shlex.split(command)
        self.assertEqual(json.loads(words[words.index("--data") + 1]), payload)


if __name__ == "__main__":
    unittest.main()
