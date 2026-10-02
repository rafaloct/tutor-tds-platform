"""Offline contract tests. The age/AWS doubles are NOT encryption or cloud proof."""
from dataclasses import replace
import json
import os
from types import SimpleNamespace
from pathlib import Path
import subprocess

import pytest

from ops import backup_r2_transport as backup

PUBLIC_RECIPIENT = "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"


@pytest.fixture
def options(tmp_path):
    source = tmp_path / "synthetic.dump"
    source.write_bytes(b"PGDMPsynthetic-format-signature-only")
    return backup.Options(source, tmp_path / "private-runs", PUBLIC_RECIPIENT,
                          profile="tds-backup", execute=True, key_custody_confirmed=True)


@pytest.fixture
def doubles(monkeypatch):
    calls, objects = [], {}
    if os.name != "posix":
        # Isolated fake transport only; this does NOT certify Windows ACLs.
        monkeypatch.setattr(backup, "_private_root", lambda root: root.mkdir(mode=0o700))
    monkeypatch.setattr(backup.shutil, "which", lambda name: "/approved-tools/" + name)

    def execute(arguments, stage, env):
        calls.append((list(arguments), stage, dict(env)))
        if stage == "encryption":
            target = Path(arguments[arguments.index("--output") + 1])
            target.write_bytes(backup.AGE_HEADER + b"TEST-DOUBLE-NOT-REAL-ENCRYPTION")
        elif stage == "upload":
            key = arguments[arguments.index("--key") + 1]
            assert key not in objects, "test double rejects an overwrite"
            body = Path(arguments[arguments.index("--body") + 1])
            objects[key] = body.read_bytes()
        elif stage == "download":
            key = arguments[arguments.index("--key") + 1]
            Path(arguments[-1]).write_bytes(objects[key])
        else:
            raise AssertionError(stage)
        return b"{}"

    monkeypatch.setattr(backup, "command", execute)
    return calls, objects, execute


def receipts(options):
    return [json.loads(path.read_text()) for path in options.run_root.glob("*/transport-receipt.json")]


def test_plan_does_not_run_commands_read_payload_or_write_files(options, monkeypatch):
    def forbidden(*args, **kwargs):
        pytest.fail("plan must not invoke commands, hash payloads or write directories")
    monkeypatch.setattr(backup, "command", forbidden)
    monkeypatch.setattr(backup, "digest", forbidden)
    monkeypatch.setattr(backup, "_private_root", forbidden)
    result = backup.run(replace(options, execute=False, key_custody_confirmed=False))
    assert result["status"] == "plan_only"
    assert result["network_access"] is result["file_writes"] is False
    assert not options.run_root.exists()


def test_execute_requires_independent_key_custody_attestation(options, doubles):
    with pytest.raises(backup.BackupError, match="independent_key_custody_not_confirmed"):
        backup.run(replace(options, key_custody_confirmed=False))
    assert doubles[0] == []


def test_success_orders_encrypt_put_get_and_never_claims_restore(options, doubles):
    before = options.source.read_bytes()
    result = backup.run(options)
    calls, objects, _ = doubles
    assert [entry[1] for entry in calls] == ["encryption", "upload", "download"]
    assert options.source.read_bytes() == before
    put, get = calls[1][0], calls[2][0]
    assert put[put.index("--body") + 1] != str(options.source)
    assert "--if-none-match" in put and put[put.index("--if-none-match") + 1] == "*"
    for args in (put, get):
        assert args[args.index("--endpoint-url") + 1] == backup.ENDPOINT
        assert args[args.index("--region") + 1] == "auto"
        assert args[args.index("--bucket") + 1] == "tds-backups"
        assert args[args.index("--profile") + 1] == "tds-backup"
        assert "--no-sign-request" not in args and "--no-verify-ssl" not in args
    assert all(before not in body for body in objects.values())
    assert result["status"] == "offsite_transport_verified"
    assert result["encrypted_sha256"] == result["download_sha256"]
    assert result["postgres_restore_verified"] is False
    assert result["scope_restriction_verified"] is False
    assert result["independent_key_custody_verified"] is False
    assert result["key_custody_operator_confirmed"] is True
    assert receipts(options) == [result]


@pytest.mark.parametrize("stage", ["encryption", "upload", "download"])
def test_external_failures_stop_sequence_and_leave_failed_receipt(options, doubles, monkeypatch, stage):
    calls, _, execute = doubles
    def fail_at(args, current, env):
        if current == stage:
            raise backup.BackupError(current)
        return execute(args, current, env)
    monkeypatch.setattr(backup, "command", fail_at)
    with pytest.raises(backup.BackupError, match=stage):
        backup.run(options)
    assert [item[1] for item in calls] == ["encryption", "upload", "download"][:["encryption", "upload", "download"].index(stage)]
    record = receipts(options)[0]
    assert record["status"] == "failed" and record["failed_stage"] == stage
    assert record["postgres_restore_verified"] is False
    assert options.source.exists()


def test_corrupted_return_is_rejected(options, doubles, monkeypatch):
    _, _, execute = doubles
    def corrupt(args, stage, env):
        result = execute(args, stage, env)
        if stage == "download":
            path = Path(args[-1])
            raw = path.read_bytes()
            path.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
        return result
    monkeypatch.setattr(backup, "command", corrupt)
    with pytest.raises(backup.BackupError, match="download_integrity"):
        backup.run(options)
    assert receipts(options)[0]["failed_stage"] == "download_integrity"


def test_plaintext_age_output_is_rejected_before_network(options, doubles, monkeypatch):
    def bad_encrypt(args, stage, env):
        assert stage == "encryption"
        Path(args[args.index("--output") + 1]).write_bytes(b"not-encrypted")
        return b""
    monkeypatch.setattr(backup, "command", bad_encrypt)
    with pytest.raises(backup.BackupError, match="encryption_output_invalid"):
        backup.run(options)
    assert receipts(options)[0]["network_access"] is False


def test_source_mutation_aborts_before_upload(options, doubles, monkeypatch):
    _, _, execute = doubles
    def mutate(args, stage, env):
        execute(args, stage, env)
        options.source.write_bytes(b"PGDMPchanged")
    monkeypatch.setattr(backup, "command", mutate)
    with pytest.raises(backup.BackupError, match="source_changed_during_encryption"):
        backup.run(options)
    assert [item[1] for item in doubles[0]] == ["encryption"]


def test_invalid_dump_signature_never_calls_age_or_network(options, doubles):
    options.source.write_bytes(b"not-a-pgdump")
    with pytest.raises(backup.BackupError, match="dump_signature_mismatch"):
        backup.run(options)
    assert doubles[0] == []


def test_each_run_has_new_key_and_preserves_earlier_ciphertext(options, doubles):
    first, second = backup.run(options), backup.run(options)
    assert first["object_key"] != second["object_key"]
    assert len(doubles[1]) == 2 and len(receipts(options)) == 2
    assert all(key.startswith("postgres/encrypted/") for key in doubles[1])
    assert all("delete" not in args and "delete-object" not in args for args, _, _ in doubles[0])


@pytest.mark.parametrize("kind", ["relative_source", "relative_output", "wrong_extension", "empty",
                                  "private_key", "invalid_profile", "source_symlink", "output_symlink"])
def test_invalid_inputs_fail_before_commands(options, doubles, tmp_path, kind):
    if kind == "relative_source":
        options = replace(options, source=Path("relative.dump"))
    elif kind == "relative_output":
        options = replace(options, run_root=Path("relative-runs"))
    elif kind == "wrong_extension":
        other = tmp_path / "example.env"
        other.write_text("fixture-only")
        options = replace(options, source=other)
    elif kind == "empty":
        options.source.write_bytes(b"")
    elif kind == "private_key":
        options = replace(options, recipient="AGE-SECRET-KEY-DO-NOT-ACCEPT")
    elif kind == "invalid_profile":
        options = replace(options, profile="bad profile --debug")
    elif kind == "source_symlink":
        link = tmp_path / "linked.dump"
        try:
            link.symlink_to(options.source)
        except OSError:
            pytest.skip("runner cannot create symbolic links")
        options = replace(options, source=link)
    else:
        link = tmp_path / "linked-output"
        try:
            link.symlink_to(tmp_path, target_is_directory=True)
        except OSError:
            pytest.skip("runner cannot create symbolic links")
        options = replace(options, run_root=link)
    with pytest.raises(backup.BackupError):
        backup.run(options)
    assert doubles[0] == []


def test_source_size_limit(options, doubles, monkeypatch):
    monkeypatch.setattr(backup, "MAX_BYTES", 1024 * 1024)
    with pytest.raises(backup.BackupError, match="source_size_limit"):
        backup.run(options)
    assert doubles[0] == []


@pytest.mark.skipif(os.name != "posix", reason="Linux operations-host permission gate")
def test_existing_output_permissions_are_not_weakened(options, doubles):
    options.run_root.mkdir(mode=0o755)
    with pytest.raises(backup.BackupError, match="run_root_permissions"):
        backup.run(options)
    assert options.run_root.stat().st_mode & 0o777 == 0o755
    assert doubles[0] == []


def test_output_inside_repository_is_rejected(options, doubles, monkeypatch, tmp_path):
    monkeypatch.setattr(backup, "REPO_ROOT", tmp_path)
    with pytest.raises(backup.BackupError, match="run_root_inside_repository"):
        backup.run(options)
    assert doubles[0] == []


def test_missing_tools_do_not_start_backup(options, monkeypatch):
    monkeypatch.setattr(backup.shutil, "which", lambda name: None)
    with pytest.raises(backup.BackupError, match="required_tools_missing"):
        backup.run(options)
    assert not options.run_root.exists()


def test_command_failure_sanitizes_provider_stderr(monkeypatch):
    def failed(*args, **kwargs):
        return subprocess.CompletedProcess(args[0], 1, b"", b"SYNTHETIC-DO-NOT-PRINT")
    monkeypatch.setattr(backup.subprocess, "run", failed)
    with pytest.raises(backup.BackupError) as error:
        backup.command(["aws"], "upload", {})
    assert "SYNTHETIC-DO-NOT-PRINT" not in str(error.value)


def test_command_timeout_is_sanitized(monkeypatch):
    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired(["SYNTHETIC-DO-NOT-PRINT"], 300)
    monkeypatch.setattr(backup.subprocess, "run", timeout)
    with pytest.raises(backup.BackupError) as error:
        backup.command(["aws"], "download", {})
    assert "SYNTHETIC-DO-NOT-PRINT" not in str(error.value)


def test_cli_failure_returns_nonzero_and_machine_readable_error(options, capsys):
    code = backup.main(["--source", str(options.source), "--run-root", str(options.run_root),
                        "--recipient", PUBLIC_RECIPIENT, "--execute"])
    assert code == 1
    assert json.loads(capsys.readouterr().out) == {
        "status": "failed", "stage": "independent_key_custody_not_confirmed"}


def test_operations_execution_refuses_windows_without_changing_permissions(tmp_path, monkeypatch):
    monkeypatch.setattr(backup, "os", SimpleNamespace(name="nt"))
    with pytest.raises(backup.BackupError, match="linux_operations_host_required"):
        backup._private_root(tmp_path / "not-created")
    assert not (tmp_path / "not-created").exists()
