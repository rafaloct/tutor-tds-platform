from pathlib import Path


API_ROOT = Path(__file__).resolve().parents[1]


def test_backup_does_not_mask_pg_dump_failure_in_a_pipeline() -> None:
    script = (API_ROOT / "ops" / "backup.sh").read_text(encoding="utf-8")

    assert "pg_dump --clean" in script
    assert "| gzip" not in script
    assert '> "$RAW_DUMP"' in script
    assert 'test -s "$RAW_DUMP"' in script
    assert script.index('> "$RAW_DUMP"') < script.index('gzip -9 -c "$RAW_DUMP"')


def test_encrypted_backup_fails_closed() -> None:
    script = (API_ROOT / "ops" / "backup.sh").read_text(encoding="utf-8")

    assert 'command -v age' in script
    assert 'if ! age -r "$BACKUP_AGE_RECIPIENT"' in script
    assert 'rm -f "$OUTPUT"' in script
    assert 'sha256sum "$ARTIFACT"' in script


def test_sheets_workers_have_outbound_network_without_database_exposure() -> None:
    for filename, worker, database in (
        ('docker-compose.staging.yml', 'sync-worker-staging', 'db-staging'),
        ('docker-compose.production.yml', 'sync-worker', 'db'),
    ):
        compose = (API_ROOT / filename).read_text(encoding='utf-8')
        # These are intentionally text-level deployment contract checks.
        worker_block = compose.split(f'  {worker}:\n', 1)[1].split('\n  policy-web:', 1)[0]
        worker_block = worker_block.split('\nvolumes:', 1)[0]
        assert 'sheets-egress' in worker_block
        assert 'ports:' not in worker_block
        database_block = compose.split(f'  {database}:\n', 1)[1].split('\n  api', 1)[0]
        assert 'sheets-egress' not in database_block
        assert 'ports:' not in database_block


def test_staging_api_persists_certificate_candidate_environment_contract() -> None:
    compose = (API_ROOT / "docker-compose.staging.yml").read_text(encoding="utf-8")
    api_block = compose.split("  api-staging:\n", 1)[1].split("\n  sync-worker-staging:", 1)[0]

    assert "CERTIFICATE_CANDIDATE_ENABLED: ${STAGING_CERTIFICATE_CANDIDATE_ENABLED:-false}" in api_block
    assert "CERTIFICATE_CANDIDATE_URL: ${STAGING_CERTIFICATE_CANDIDATE_URL:-}" in api_block
    assert "CERTIFICATE_CANDIDATE_SECRET: ${STAGING_CERTIFICATE_CANDIDATE_SECRET:-}" in api_block

    worker_block = compose.split("  sync-worker-staging:\n", 1)[1].split("\n  policy-web:", 1)[0]
    assert "CERTIFICATE_CANDIDATE_SECRET" not in worker_block
