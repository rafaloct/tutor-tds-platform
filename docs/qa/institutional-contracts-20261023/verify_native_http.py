"""Isolated real HTTP/auth/Postgres proof; synthetic fixture data, never staging.

Run from api with its locked Python; capture stdout/stderr to native-http-output.txt. No configurable remote targets or credentials.
Existing test seeds/assertions are reused; identity overrides are removed before
the socket server starts. X-User is translated only in this client, never sent.
"""
from __future__ import annotations

import json
import secrets
import socket
import sys
import threading
from pathlib import Path
from uuid import uuid4

import httpx
import psycopg
from psycopg import sql
from sqlalchemy import select
from sqlalchemy.orm import Session
import uvicorn

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "api"), str(ROOT / "api/tests")]
from app.auth import AuthService, access_claims, password_hash
from app.models import User
from test_certificate_requests import requests_api
from test_class_lifecycle import (
    lifecycle_api,
    test_prepare_pins_published_version_separates_territory_and_replays,
    test_plan_team_and_strict_lifecycle_authority,
    test_capacity_30_warns_without_blocking_scoped_assignments,
)

ADMIN = "postgresql://qa_attendance@127.0.0.1:15406/postgres"
REPORT = {"classification": "TESTED-LOCAL synthetic data; real sockets/auth/Postgres",
          "source": "f345cc805d04c0e9ca1a1778be9e00f7e52e9002", "scenarios": []}


def synthetic_cpf(index):
    digits = list(map(int, f"831{index:06d}"))
    for length in (9, 10):
        digits.append((sum(n * (length + 1 - p) for p, n in enumerate(digits)) * 10 % 11) % 10)
    return "".join(map(str, digits))


class NativeClient:
    def __init__(self, app, client, tokens, trace):
        self.app, self.client, self.tokens, self.trace = app, client, tokens, trace

    def request(self, method, path, **kwargs):
        headers = dict(kwargs.pop("headers", {}))
        actor = headers.pop("X-User", "learner")
        assert not headers, "Unexpected fixture headers"
        response = self.client.request(method, path, headers={
            "Authorization": "Bearer " + self.tokens[actor]}, **kwargs)
        self.trace.append({"method": method, "path": path, "actor": actor,
                           "status": response.status_code})
        return response

    def get(self, path, **kwargs):
        return self.request("GET", path, **kwargs)

    def post(self, path, **kwargs):
        return self.request("POST", path, **kwargs)

    def put(self, path, **kwargs):
        return self.request("PUT", path, **kwargs)


def run_scenario(check):
    name = "qa_attendance_native_" + uuid4().hex
    fixture = None
    server = None
    thread = None
    listener = None
    entry = {"name": check.__name__, "result": "FAIL", "trace": []}
    REPORT["scenarios"].append(entry)
    with psycopg.connect(ADMIN, autocommit=True) as conn:
        REPORT["postgres_version"] = conn.execute("SELECT version()").fetchone()[0]
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    try:
        url = ADMIN.rsplit("/", 1)[0] + "/" + name
        fixture = requests_api.__wrapped__(url.replace("postgresql://", "postgresql+psycopg://", 1))
        seed_client, engine = lifecycle_api.__wrapped__(next(fixture))
        app = seed_client.app
        assert set(app.dependency_overrides) == {access_claims}
        app.dependency_overrides.clear()
        assert not app.dependency_overrides
        credentials = {}
        with Session(engine) as session:
            service = AuthService(session, app.state.settings)
            for index, user in enumerate(session.scalars(select(User).order_by(User.id)), 1):
                cpf, password = synthetic_cpf(index), secrets.token_urlsafe(24)
                user.cpf_digest = service._cpf_digest(cpf)
                user.password_digest = password_hash.hash(password)
                credentials[user.id] = (cpf, password)
            session.commit()
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(128)
        port = listener.getsockname()[1]
        server = uvicorn.Server(uvicorn.Config(app, lifespan="off", access_log=False, log_level="error"))
        thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
        thread.start()
        with httpx.Client(base_url=f"http://127.0.0.1:{port}", trust_env=False, timeout=20) as http:
            # Each TCP connection queues on the pre-listening socket; no sleep/retry.
            assert http.get("/operations/classes").status_code == 401
            assert http.get("/operations/classes", headers={"X-User": "admin"}).status_code == 401
            assert http.get("/operations/classes", headers={"Authorization": "Bearer invalid"}).status_code == 401
            tokens = {}
            for actor, (cpf, password) in credentials.items():
                response = http.post("/auth/login", json={"cpf": cpf, "password": password})
                assert response.status_code == 200, f"Login failed for synthetic actor {actor}"
                body = response.json()
                assert body["user"]["id"] == actor
                tokens[actor] = body["access_token"]
            entry["password_logins"] = len(tokens)
            check((NativeClient(app, http, tokens, entry["trace"]), engine))
            entry["result"] = "PASS"
    finally:
        if server:
            server.should_exit = True
        if thread:
            thread.join(timeout=20)
            assert not thread.is_alive(), "Owned HTTP server failed to stop"
        if listener:
            listener.close()
        if fixture:
            fixture.close()
        with psycopg.connect(ADMIN, autocommit=True) as conn:
            conn.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))
            entry["database_removed"] = conn.execute(
                "SELECT count(*) FROM pg_database WHERE datname = %s", (name,)
            ).fetchone()[0] == 0


if __name__ == "__main__":
    try:
        for scenario in (
            test_prepare_pins_published_version_separates_territory_and_replays,
            test_plan_team_and_strict_lifecycle_authority,
            test_capacity_30_warns_without_blocking_scoped_assignments,
        ):
            run_scenario(scenario)
    finally:
        Path(__file__).with_name("native-http.json").write_text(
            json.dumps(REPORT, indent=2) + "\n", encoding="utf-8")
    print("PASS: 3 isolated native HTTP/auth/Postgres scenarios; no identity overrides")
