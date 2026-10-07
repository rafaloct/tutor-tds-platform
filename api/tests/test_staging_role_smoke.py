from __future__ import annotations

import sys

from ops import staging_role_smoke as smoke


def test_role_smoke_uses_role_specific_class_views(monkeypatch, capsys):
    calls: list[tuple[str, str | None]] = []

    def fake_request(
        base_url: str,
        path: str,
        *,
        method: str = "GET",
        body: dict[str, object] | None = None,
        token: str | None = None,
    ) -> object:
        assert base_url == "https://staging.example.test"
        if path == "/auth/login":
            assert method == "POST"
            assert body is not None
            role = str(body["cpf"]).split("_")[-2]
            return {"access_token": role}

        calls.append((path, token))
        if path == "/classes":
            return {"classes": [{"id": "staging-qa-class"}]}
        if path == "/classes/staging-qa-class/dashboard":
            assert token == "TEACHER"
            return {"students": []}
        if path == "/classes/staging-qa-class/monitor-exceptions":
            assert token == "MONITOR"
            return {"students": []}
        if path == "/classes/staging-qa-class/sessions/open":
            assert token == "STUDENT"
            return {
                "id": "staging-qa-class-session-refresh",
                "class_id": "staging-qa-class",
                "status": "open",
            }
        if path == "/assessment-attempts":
            assert token == "STUDENT"
            return {"attempts": []}
        if path == "/media":
            assert token == "STUDENT"
            return {"media": []}
        raise AssertionError(f"Unexpected request: {method} {path}")

    monkeypatch.setattr(smoke, "request", fake_request)
    monkeypatch.setattr(smoke, "required", lambda name: name)
    monkeypatch.setattr(
        sys,
        "argv",
        ["staging_role_smoke.py", "https://staging.example.test"],
    )

    smoke.main()

    assert (
        "/classes/staging-qa-class/dashboard",
        "MONITOR",
    ) not in calls
    assert (
        "/classes/staging-qa-class/monitor-exceptions",
        "MONITOR",
    ) in calls
    assert "Authenticated staging smoke passed" in capsys.readouterr().out
