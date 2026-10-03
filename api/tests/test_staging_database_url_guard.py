from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import textwrap
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPOSITORY_ROOT / ".github" / "workflows" / "staging-alembic-migrate.yml"
PROJECT_REF = "lgtphbbpgqnzduhtyate"
DIRECT_HOST = f"db.{PROJECT_REF}.supabase.co"
POOLER_HOST = "aws-0-us-east-1.pooler.supabase.com"


def extract_guard() -> str:
    lines = WORKFLOW.read_text(encoding="utf-8").splitlines()
    start = lines.index("          python - <<'PY'") + 1
    end = lines.index("          PY", start)
    return textwrap.dedent("\n".join(lines[start:end]))


class StagingDatabaseUrlGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.guard = extract_guard()

    def run_guard(self, database_url: str, environment: str = "staging") -> subprocess.CompletedProcess[str]:
        env = {
            "TUTOR_ENVIRONMENT": environment,
            "DATABASE_URL": database_url,
            "EXPECTED_STAGING_DATABASE_HOST": DIRECT_HOST,
            "EXPECTED_STAGING_PROJECT_REF": PROJECT_REF,
        }
        return subprocess.run(
            [sys.executable, "-c", self.guard],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_rejected(self, database_url: str, environment: str = "staging") -> None:
        result = self.run_guard(database_url, environment)
        self.assertNotEqual(0, result.returncode, result.stdout)

    def test_accepts_existing_direct_staging_endpoint(self) -> None:
        result = self.run_guard(f"postgresql://postgres:synthetic@{DIRECT_HOST}:5432/postgres")
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_project_session_pooler_ipv4_endpoint(self) -> None:
        url = f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:5432/postgres"
        result = self.run_guard(url)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_pooler_with_secure_sslmode(self) -> None:
        url = f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:5432/postgres?sslmode=require"
        result = self.run_guard(url)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_pooler_username_for_another_project(self) -> None:
        self.assert_rejected(f"postgresql://postgres.otherproject:synthetic@{POOLER_HOST}:5432/postgres")

    def test_rejects_pooler_on_transaction_mode_port(self) -> None:
        self.assert_rejected(f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:6543/postgres")

    def test_rejects_pooler_database_other_than_postgres(self) -> None:
        self.assert_rejected(f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:5432/other")

    def test_rejects_connection_parameter_overrides(self) -> None:
        overrides = (
            "host=db.production.supabase.co",
            "hostaddr=192.0.2.10",
            "service=production",
            "dbname=production",
            "sslmode=disable",
        )
        for override in overrides:
            with self.subTest(override=override):
                self.assert_rejected(
                    f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:5432/postgres?{override}"
                )

    def test_rejects_direct_host_override(self) -> None:
        self.assert_rejected(
            f"postgresql://postgres:synthetic@{DIRECT_HOST}:5432/postgres?host=db.production.supabase.co"
        )

    def test_rejects_url_fragment(self) -> None:
        self.assert_rejected(
            f"postgresql://postgres.{PROJECT_REF}:synthetic@{POOLER_HOST}:5432/postgres#production"
        )

    def test_rejects_unknown_database_host(self) -> None:
        self.assert_rejected("postgresql://postgres:synthetic@db.production.supabase.co:5432/postgres")

    def test_rejects_production_environment_even_with_staging_host(self) -> None:
        self.assert_rejected(f"postgresql://postgres:synthetic@{DIRECT_HOST}:5432/postgres", "production")


if __name__ == "__main__":
    unittest.main()
