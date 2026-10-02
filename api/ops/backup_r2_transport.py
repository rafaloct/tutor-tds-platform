"""Opt-in encrypted R2 transport; never a database restore or release acceptance.

Requires age and AWS CLI v2 on an authorized Linux operations host. Credentials
are supplied by the AWS CLI's normal provider; this module never opens a secret
file, decrypts DPAPI, changes permissions, or configures a credential provider.
Default mode is a local plan with no subprocess, network request or file write.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
from uuid import uuid4

ACCOUNT_ID = "8b1d9dad829dd6927091666a1f186717"
BUCKET = "tds-backups"
ENDPOINT = f"https://{ACCOUNT_ID}.r2.cloudflarestorage.com"
REPO_ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 1024 ** 3  # Deliberate single-PUT bound; no implicit multipart.
AGE_HEADER = b"age-encryption.org/v1\n"


class BackupError(RuntimeError):
    def __init__(self, stage: str):
        self.stage = stage
        super().__init__(f"Backup stopped at {stage}; no acceptance granted.")


@dataclass(frozen=True)
class Options:
    source: Path
    run_root: Path
    recipient: str  # Public age recipient, never a private recovery key.
    profile: str | None = None
    execute: bool = False
    key_custody_confirmed: bool = False  # Operator attestation, not automated proof.


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def validate(options: Options) -> None:
    if not options.source.is_absolute() or not options.run_root.is_absolute():
        raise BackupError("absolute_paths_required")
    if options.source.is_symlink() or not options.source.is_file():
        raise BackupError("source_not_regular_file")
    if not options.source.name.endswith((".sql.gz", ".dump")):
        raise BackupError("unsupported_dump_format")
    if not 0 < options.source.stat().st_size < MAX_BYTES - 1024 * 1024:
        raise BackupError("source_size_limit")
    if options.run_root.is_symlink():
        raise BackupError("unsafe_run_root")
    if options.run_root.resolve().is_relative_to(REPO_ROOT.resolve()):
        raise BackupError("run_root_inside_repository")
    if not re.fullmatch(r"age1[023456789acdefghjklmnpqrstuvwxyz]{10,4096}", options.recipient):
        raise BackupError("public_recipient_required")
    if options.profile is not None and not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", options.profile):
        raise BackupError("invalid_profile_name")
    if options.execute and not options.key_custody_confirmed:
        raise BackupError("independent_key_custody_not_confirmed")


def command(arguments: list[str], stage: str, env: dict[str, str]) -> bytes:
    try:
        result = subprocess.run(arguments, capture_output=True, timeout=300, env=env, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise BackupError(stage) from None
    if result.returncode != 0:
        # Never forward stderr, a command line, a provider response or secrets.
        raise BackupError(stage)
    return result.stdout


def _private_root(root: Path) -> None:
    if os.name != "posix":
        raise BackupError("linux_operations_host_required")
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    mode = root.stat().st_mode
    if not stat.S_ISDIR(mode) or stat.S_IMODE(mode) & 0o077:
        # Do not silently rewrite an existing directory's permissions.
        raise BackupError("run_root_permissions")


def run(options: Options) -> dict[str, object]:
    validate(options)
    plan: dict[str, object] = {
        "status": "plan_only", "bucket": BUCKET, "endpoint": ENDPOINT,
        "network_access": False, "file_writes": False,
        "postgres_restore_verified": False, "scope_restriction_verified": False,
        "independent_key_custody_verified": False,
    }
    if not options.execute:
        return plan
    age, aws = shutil.which("age"), shutil.which("aws")
    if age is None or aws is None:
        raise BackupError("required_tools_missing")
    _private_root(options.run_root)
    env = os.environ.copy()
    env.update(AWS_PAGER="", AWS_CLI_AUTO_PROMPT="off", AWS_EC2_METADATA_DISABLED="true")
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex
    directory = options.run_root / run_id
    directory.mkdir(mode=0o700)  # Unique, never reuse an earlier backup directory.
    encrypted, returned = directory / "archive.age", directory / "download.age"
    key = f"postgres/encrypted/{run_id}/archive.age"
    receipt: dict[str, object] = {
        **plan, "status": "failed", "run_id": run_id, "object_key": key,
        "file_writes": True, "key_custody_operator_confirmed": True,
    }
    old_umask = os.umask(0o077)
    try:
        # Validate only the file-format signature, not PostgreSQL recoverability.
        with options.source.open("rb") as stream:
            header = stream.read(5)
        valid = (options.source.name.endswith(".dump") and header == b"PGDMP") or (
            options.source.name.endswith(".sql.gz") and header[:2] == b"\x1f\x8b")
        if not valid:
            raise BackupError("dump_signature_mismatch")
        before = digest(options.source)
        command([age, "--encrypt", "--recipient", options.recipient, "--output", str(encrypted),
                 str(options.source)], "encryption", env)
        if digest(options.source) != before:
            raise BackupError("source_changed_during_encryption")
        with encrypted.open("rb") as stream:
            if stream.read(len(AGE_HEADER)) != AGE_HEADER:
                raise BackupError("encryption_output_invalid")
        size = encrypted.stat().st_size
        if not len(AGE_HEADER) < size <= MAX_BYTES:
            raise BackupError("encrypted_size_limit")
        checksum = digest(encrypted)
        receipt.update(encrypted_sha256=checksum, encrypted_bytes=size)
        args = [aws, "--endpoint-url", ENDPOINT, "--region", "auto", "--no-cli-pager",
                "--cli-connect-timeout", "15", "--cli-read-timeout", "60", "--output", "json"]
        if options.profile is not None:
            args += ["--profile", options.profile]
        receipt["network_access"] = True
        command(args + ["s3api", "put-object", "--bucket", BUCKET, "--key", key,
                        "--body", str(encrypted), "--if-none-match", "*",
                        "--content-type", "application/octet-stream", "--storage-class", "STANDARD"],
                "upload", env)
        command(args + ["s3api", "get-object", "--bucket", BUCKET, "--key", key, str(returned)],
                "download", env)
        if returned.stat().st_size != size or digest(returned) != checksum:
            raise BackupError("download_integrity")
        receipt.update(status="offsite_transport_verified", download_sha256=checksum)
        return receipt
    except BackupError as error:
        receipt["failed_stage"] = error.stage
        raise
    except OSError:
        receipt["failed_stage"] = "local_io"
        raise BackupError("local_io") from None
    finally:
        try:
            receipt["observed_at"] = datetime.now(timezone.utc).isoformat()
            # Local evidence only. Never write a production-release acceptance file.
            with (directory / "transport-receipt.json").open("x", encoding="utf-8") as stream:
                json.dump(receipt, stream, indent=2)
                stream.write("\n")
        finally:
            os.umask(old_umask)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--run-root", required=True, type=Path)
    parser.add_argument("--recipient", required=True)
    parser.add_argument("--profile")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--key-custody-confirmed", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = run(Options(**vars(args)))
    except BackupError as error:
        print(json.dumps({"status": "failed", "stage": error.stage}))
        return 1
    except OSError:
        print(json.dumps({"status": "failed", "stage": "local_io"}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
