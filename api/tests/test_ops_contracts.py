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
