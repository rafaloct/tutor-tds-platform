#!/usr/bin/env python3
"""Opt-in, offline restore of an operator-supplied scheduled R2 PostgreSQL backup.

No R2 or production endpoint is contacted. The age identity and dump remain
outside the report; PostgreSQL runs in a disposable Docker container with no
network, published port, or mounted host directory. This proves restore only.
Upgrade, old-image, and application compatibility require a separate rehearsal.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
import subprocess
import sys
import time
from typing import Any


MAX_RECEIPT_BYTES = 16 * 1024
MAX_DUMP_BYTES = 64 * 1024 * 1024
MAX_CIPHER_BYTES = MAX_DUMP_BYTES + 65536
RECEIPT_ID = re.compile(r"\d{8}T\d{6}Z-[0-9a-f]{32}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
OID = re.compile(r"[0-9a-f]{40}\Z")
REVISION = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\Z")
UTC = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z\Z")
RECEIPT_FIELDS = {
    "schema", "owner", "id", "key", "bucket", "status", "sha256", "bytes",
    "completedAt", "day", "source", "sourceReadOnly", "clientEncryption",
    "privateKeyUsed", "restoreExecuted",
}
POSTGRES_IMAGE = "postgres:16-alpine"


class DrillError(ValueError):
    """A precondition or isolated restore failed; never include private data."""


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise DrillError(reason)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def parse_utc(value: Any) -> datetime:
    require(isinstance(value, str) and UTC.fullmatch(value) is not None,
            "receipt_time_invalid")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise DrillError("receipt_time_invalid") from error


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, "receipt_duplicate_field")
        result[key] = value
    return result


def trusted_uid() -> int:
    """Bind private inputs and the checkout to sudo's original local user."""
    require(os.name == "posix", "sudo_runner_requires_posix_host")
    euid = os.geteuid()
    if euid != 0:
        return euid
    require(os.getuid() == 0, "sudo_invoker_invalid")
    if "SUDO_UID" not in os.environ and "SUDO_USER" not in os.environ:
        return 0
    uid_text = os.environ.get("SUDO_UID", "")
    user = os.environ.get("SUDO_USER", "")
    require(re.fullmatch(r"[0-9]{1,10}", uid_text) is not None and user != "",
            "sudo_invoker_invalid")
    uid = int(uid_text)
    require(0 < uid < 2**32 and str(uid) == uid_text, "sudo_invoker_invalid")
    import pwd  # POSIX only; avoid making Windows import the runner impossible.
    try:
        account = pwd.getpwnam(user)
        canonical = pwd.getpwuid(uid)
    except KeyError as error:
        raise DrillError("sudo_invoker_invalid") from error
    require(account.pw_uid == uid and canonical.pw_name == user,
            "sudo_invoker_invalid")
    return uid


def require_private_identity(details: os.stat_result) -> None:
    require(stat.S_ISREG(details.st_mode), "input_must_be_regular_file")
    require(os.name == "posix", "private_identity_requires_posix_host")
    require(stat.S_IMODE(details.st_mode) & 0o077 == 0,
            "private_identity_permissions_invalid")
    require(details.st_uid == trusted_uid(), "private_identity_owner_invalid")


def regular_file(path: Path, *, private: bool = False) -> os.stat_result:
    try:
        details = path.lstat()
    except OSError as error:
        raise DrillError("input_unavailable") from error
    if private:
        require_private_identity(details)
    else:
        require(stat.S_ISREG(details.st_mode), "input_must_be_regular_file")
    return details


def validate_receipt(receipt: Any, now: datetime) -> dict[str, Any]:
    require(isinstance(receipt, dict) and set(receipt) == RECEIPT_FIELDS,
            "receipt_shape_invalid")
    receipt_id = receipt["id"]
    require(isinstance(receipt_id, str) and RECEIPT_ID.fullmatch(receipt_id) is not None,
            "receipt_id_invalid")
    require(type(receipt["schema"]) is int and receipt["schema"] == 1 and
            receipt["owner"] == "tutor-tds-issue2-scheduled-v1" and
            receipt["status"] == "verified" and
            receipt["bucket"] == "tds-backups" and
            receipt["key"] == f"postgres/scheduled/v1/{receipt_id}/archive.dump.age" and
            receipt["source"] == "tutor-tds-api-db-1/tutor_tds" and
            receipt["sourceReadOnly"] is True and
            receipt["clientEncryption"] == "age" and
            receipt["privateKeyUsed"] is False and
            receipt["restoreExecuted"] is False,
            "receipt_origin_invalid")
    require(type(receipt["bytes"]) is int and 200 < receipt["bytes"] <= MAX_CIPHER_BYTES and
            isinstance(receipt["sha256"], str) and SHA256.fullmatch(receipt["sha256"]) is not None,
            "receipt_archive_metadata_invalid")
    completed = parse_utc(receipt["completedAt"])
    try:
        started = datetime.strptime(receipt_id[:16], "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    except ValueError as error:
        raise DrillError("receipt_id_clock_invalid") from error
    require(receipt["day"] == completed.date().isoformat() and
            receipt_id[:8] == completed.strftime("%Y%m%d") and
            started <= completed and
            completed <= now + timedelta(minutes=5), "receipt_day_or_clock_invalid")
    return receipt


def load_receipt(path: Path, now: datetime) -> dict[str, Any]:
    details = regular_file(path)
    require(details.st_size <= MAX_RECEIPT_BYTES, "receipt_too_large")
    try:
        receipt = json.loads(path.read_bytes(), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DrillError("receipt_unreadable") from error
    return validate_receipt(receipt, now)


def load_cipher(path: Path, receipt: dict[str, Any]) -> bytes:
    details = regular_file(path)
    require(details.st_size == receipt["bytes"], "archive_size_mismatch")
    try:
        cipher = path.read_bytes()
    except OSError as error:
        raise DrillError("archive_unreadable") from error
    require(len(cipher) == receipt["bytes"] and
            hashlib.sha256(cipher).hexdigest() == receipt["sha256"],
            "archive_hash_mismatch")
    require(cipher.startswith(b"age-encryption.org/v1\n"), "archive_age_header_invalid")
    return cipher


def command(args: list[str], *, input_bytes: bytes | bytearray | None = None,
            timeout: int = 60, env: dict[str, str] | None = None,
            pass_fds: tuple[int, ...] = ()) -> bytes:
    try:
        result = subprocess.run(args, input=input_bytes, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, timeout=timeout,
                                env=env, pass_fds=pass_fds, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DrillError("isolated_command_unavailable_or_timed_out") from error
    require(result.returncode == 0, "isolated_command_failed")
    return result.stdout


def read_git(root: Path, *args: str) -> bytes:
    # Reset inherited safe.directory entries, then trust only this resolved
    # candidate path. Disable repository-provided fsmonitor/hooks under sudo.
    clean_env = {key: value for key, value in os.environ.items()
                 if not key.startswith("GIT_")}
    return command([
        "git", "--no-optional-locks", "-c", "safe.directory=", "-c",
        f"safe.directory={root}", "-c", "core.fsmonitor=false", "-c",
        f"core.hooksPath={os.devnull}", "-c", "submodule.recurse=false",
        "-C", str(root), *args,
    ], env=clean_env)


def candidate_identity(root: Path) -> tuple[str, str]:
    try:
        root = root.resolve(strict=True)
    except OSError as error:
        raise DrillError("candidate_checkout_unavailable") from error
    try:
        details = root.stat()
    except OSError as error:
        raise DrillError("candidate_checkout_unavailable") from error
    require(stat.S_ISDIR(details.st_mode), "candidate_checkout_unavailable")
    require(details.st_uid == trusted_uid(), "candidate_checkout_owner_invalid")
    top = read_git(root, "rev-parse", "--show-toplevel").decode().strip()
    require(Path(top).resolve() == root, "candidate_root_not_git_top_level")
    dirty_api = read_git(root, "status", "--porcelain=v1", "-uall", "--", "api")
    require(not dirty_api.strip(), "candidate_api_tree_dirty")
    oid = read_git(root, "rev-parse", "HEAD:api").decode().strip()
    require(OID.fullmatch(oid) is not None, "candidate_api_tree_invalid")
    versions = root / "api" / "migrations" / "versions"
    require(versions.is_dir() and not versions.is_symlink(), "candidate_migrations_unavailable")
    revisions: set[str] = set()
    parents: set[str] = set()
    for path in versions.glob("*.py"):
        require(path.is_file() and not path.is_symlink(), "candidate_migration_invalid")
        text = path.read_text(encoding="utf-8")
        revision = re.search(r"(?m)^revision\s*=\s*['\"]([A-Za-z0-9_-]+)['\"]\s*$", text)
        parent = re.search(r"(?m)^down_revision\s*=\s*['\"]([A-Za-z0-9_-]+)['\"]\s*$", text)
        root_revision = re.search(r"(?m)^down_revision\s*=\s*None\s*$", text)
        require(revision is not None and (parent is not None or root_revision is not None),
                "candidate_migration_invalid")
        rev = revision.group(1)
        require(REVISION.fullmatch(rev) is not None and rev not in revisions,
                "candidate_migration_invalid")
        revisions.add(rev)
        if parent is not None:
            parents.add(parent.group(1))
    heads = revisions - parents
    require(len(heads) == 1 and parents <= revisions, "candidate_alembic_head_invalid")
    return oid, heads.pop()


def age_executable(value: str) -> str:
    found = shutil.which(value)
    require(found is not None, "age_executable_unavailable")
    path = Path(found)
    if os.geteuid() == 0:
        require(path.is_absolute(), "root_owned_age_required")
        for candidate in (path, *path.parents):
            try:
                details = candidate.lstat()
            except OSError as error:
                raise DrillError("root_owned_age_required") from error
            require(details.st_uid == 0 and
                    stat.S_IMODE(details.st_mode) & 0o022 == 0 and
                    (stat.S_ISREG(details.st_mode) if candidate == path
                     else stat.S_ISDIR(details.st_mode)),
                    "root_owned_age_required")
    return str(path)


def decrypt_dump(cipher: bytes, identity: Path, age_bin: str) -> bytearray:
    executable = age_executable(age_bin)
    fd_root = next((path for path in (Path("/proc/self/fd"), Path("/dev/fd"))
                    if path.is_dir()), None)
    require(fd_root is not None and hasattr(os, "O_NOFOLLOW"),
            "private_identity_fd_unavailable")
    try:
        identity_fd = os.open(identity, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError as error:
        raise DrillError("private_identity_unavailable") from error
    try:
        require_private_identity(os.fstat(identity_fd))
        try:
            raw = command([executable, "--decrypt", "--identity",
                           str(fd_root / str(identity_fd))],
                          input_bytes=cipher, timeout=180,
                          pass_fds=(identity_fd,))
        except DrillError as error:
            raise DrillError("age_decryption_failed") from error
    finally:
        os.close(identity_fd)
    require(5 < len(raw) <= MAX_DUMP_BYTES and raw.startswith(b"PGDMP"),
            "decrypted_dump_not_pg_custom")
    return bytearray(raw)


def remove_owned_container(docker_bin: str, reference: str, run_id: str,
                           *, allow_missing: bool = False) -> None:
    try:
        container_id = command([docker_bin, "inspect", "--format", "{{.Id}}",
                                reference]).decode().strip()
    except DrillError:
        if allow_missing:
            return
        raise
    require(re.fullmatch(r"[0-9a-f]{64}", container_id) is not None,
            "disposable_container_identity_invalid")
    labels = command([docker_bin, "inspect", "--format", "{{json .Config.Labels}}",
                      container_id])
    try:
        owned = json.loads(labels)
    except json.JSONDecodeError as error:
        raise DrillError("disposable_container_ownership_unverified") from error
    require(isinstance(owned, dict) and
            owned.get("tds.purpose") == "scheduled-offsite-restore" and
            owned.get("tds.run") == run_id,
            "disposable_container_ownership_unverified")
    command([docker_bin, "rm", "--force", container_id], timeout=60)


def restore_disposable(dump: bytearray, docker_bin: str, run_id: str,
                       tmpfs_mib: int) -> dict[str, str]:
    """Use only a newly owned, networkless container and always remove it."""
    require(256 <= tmpfs_mib <= 1536, "tmpfs_size_invalid")
    image_id = command([docker_bin, "image", "inspect", "--format", "{{.Id}}",
                        POSTGRES_IMAGE]).decode().strip()
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", image_id) is not None,
            "postgres_image_unavailable")
    name = f"tds-offsite-drill-{run_id}"
    try:
        container_id = command([
            docker_bin, "run", "--detach", "--pull=never", "--name", name,
            "--network", "none", "--rm", "--memory", "2g", "--cpus", "2",
            "--tmpfs", f"/var/lib/postgresql/data:rw,size={tmpfs_mib}m",
            "--label", "tds.purpose=scheduled-offsite-restore",
            "--label", f"tds.run={run_id}",
            "--env", "POSTGRES_HOST_AUTH_METHOD=trust",
            "--env", "POSTGRES_USER=tds_restore", "--env", "POSTGRES_DB=tds_restore",
            image_id,
        ], timeout=60).decode().strip()
        require(re.fullmatch(r"[0-9a-f]{64}", container_id) is not None,
                "disposable_container_identity_invalid")
    except DrillError:
        # A transport failure can occur after Docker created the container.
        # Query the generated name and remove it only if our labels match.
        remove_owned_container(docker_bin, name, run_id, allow_missing=True)
        raise
    try:
        actual_image_id = command([docker_bin, "inspect", "--format", "{{.Image}}",
                                   container_id]).decode().strip()
        require(actual_image_id == image_id, "disposable_postgres_image_changed")
        # Docker reports --tmpfs in HostConfig.Tmpfs, not .Mounts. The
        # postgres image declares VOLUME here; an explicit tmpfs must shadow
        # it, with no anonymous volume or host bind in .Mounts.
        mounts = json.loads(command([docker_bin, "inspect", "--format",
                                     "{{json .Mounts}}", container_id]))
        tmpfs = json.loads(command([docker_bin, "inspect", "--format",
                                    "{{json .HostConfig.Tmpfs}}", container_id]))
        require(mounts == [] and
                tmpfs == {"/var/lib/postgresql/data": f"rw,size={tmpfs_mib}m"},
                "disposable_postgres_mounts_invalid")
        filesystem = command([docker_bin, "exec", container_id, "df", "-T",
                              "/var/lib/postgresql/data"]).decode().splitlines()
        require(len(filesystem) >= 2 and
                filesystem[-1].split()[1:2] == ["tmpfs"],
                "disposable_postgres_data_not_tmpfs")
        network = command([docker_bin, "inspect", "--format",
                           "{{.HostConfig.NetworkMode}}", container_id]).decode().strip()
        require(network == "none", "disposable_postgres_network_invalid")
        for _ in range(40):
            try:
                command([docker_bin, "exec", container_id, "pg_isready", "-h",
                         "127.0.0.1", "-U",
                         "tds_restore", "-d", "tds_restore"], timeout=5)
                break
            except DrillError:
                time.sleep(1)
        else:
            raise DrillError("disposable_postgres_not_ready")
        command([docker_bin, "exec", "-i", container_id, "pg_restore",
                 "--exit-on-error", "--no-owner", "--no-privileges", "-U",
                 "tds_restore", "-d", "tds_restore"], input_bytes=dump,
                timeout=900)
        version = command([docker_bin, "exec", container_id, "psql", "-U",
                           "tds_restore", "-d", "tds_restore", "-At", "-v",
                           "ON_ERROR_STOP=1", "-c",
                           "SELECT current_setting('server_version_num')"])
        require(version.decode().strip().isdigit() and
                160000 <= int(version.decode().strip()) < 170000,
                "disposable_postgres_major_not_16")
        revision = command([docker_bin, "exec", container_id, "psql", "-U",
                            "tds_restore", "-d", "tds_restore", "-At", "-v",
                            "ON_ERROR_STOP=1", "-c", "SELECT version_num FROM alembic_version"])
        restored_revision = revision.decode().strip()
        require(REVISION.fullmatch(restored_revision) is not None and
                "\n" not in restored_revision, "restored_revision_invalid")
        tables = command([docker_bin, "exec", container_id, "psql", "-U",
                          "tds_restore", "-d", "tds_restore", "-At", "-v",
                          "ON_ERROR_STOP=1", "-c",
                          "SELECT count(*) FROM information_schema.tables "
                          "WHERE table_schema='public' AND table_name IN "
                          "('users','courses','learning_events','alembic_version')"])
        require(tables.decode().strip() == "4", "restored_core_tables_missing")
        return {"postgres_image_id": image_id, "postgres_version_num": version.decode().strip(),
                "restored_schema_version": restored_revision}
    finally:
        remove_owned_container(docker_bin, container_id, run_id)


def evidence_records(receipt: dict[str, Any], cipher_sha: str, plaintext_sha: str,
                     run_id: str, restored_at: datetime, api_tree: str,
                     candidate_schema: str, result: dict[str, str]) -> tuple[dict[str, Any], dict[str, Any]]:
    source = {"receipt_id": receipt["id"], "object_key": receipt["key"],
              "plaintext_sha256": plaintext_sha}
    offsite = {
        "status": "passed", "scope": "postgres-prod-scheduled",
        "offsite": {"uploaded_sha256": receipt["sha256"],
                    "downloaded_sha256": cipher_sha},
        "isolated_restore_from_offsite_verified": True,
        "scheduled_receipt": receipt,
        "restore_drill": {
            "run_id": run_id, "source_receipt_id": receipt["id"],
            "source_object_key": receipt["key"],
            "source_cipher_sha256": cipher_sha,
            "decrypted_dump_sha256": plaintext_sha,
            "restored_at": iso_utc(restored_at),
        },
    }
    postgres = {
        "status": "restore_verified_pending_upgrade", "run_id": run_id,
        "completed_at": iso_utc(restored_at), "api_tree_oid": api_tree,
        "candidate_schema_version": candidate_schema,
        "source_backup": source, "backup": {"sha256": plaintext_sha},
        "restore_verified": True,
        "restored_schema_version": result["restored_schema_version"],
        "isolated_postgres_version_num": result["postgres_version_num"],
        "isolated_postgres_image_id": result["postgres_image_id"],
        "production_accessed": False,
    }
    return offsite, postgres


def write_reports(output_dir: Path, run_id: str, api_tree: str,
                  candidate_schema: str, offsite: dict[str, Any],
                  postgres: dict[str, Any]) -> Path:
    require(output_dir.is_dir() and not output_dir.is_symlink(), "output_directory_invalid")
    run_dir = output_dir / f"scheduled-postgres-{run_id}"
    try:
        run_dir.mkdir(mode=0o700)
    except OSError as error:
        raise DrillError("output_run_directory_unavailable") from error
    offsite_name = f"scheduled-postgres-offsite-{run_id}.json"
    postgres_name = f"postgres-restore-partial-{run_id}.json"
    files = [(offsite_name, offsite), (postgres_name, postgres)]
    references: dict[str, dict[str, str]] = {}
    try:
        for name, record in files:
            payload = (json.dumps(record, sort_keys=True, indent=2) + "\n").encode()
            path = run_dir / name
            with path.open("xb") as handle:
                os.fchmod(handle.fileno(), 0o600)
                handle.write(payload)
            gate = "offsite_backup" if name == offsite_name else "postgres_restore_partial"
            references[gate] = {"file": name, "sha256": hashlib.sha256(payload).hexdigest()}
        manifest = {
            "schema_version": 1, "status": "restore_verified_pending_upgrade",
            "run_id": run_id, "candidate_schema_version": candidate_schema,
            "candidate_api_tree_oid": api_tree,
            "completed_at": postgres["completed_at"], "source_receipt_id":
                offsite["scheduled_receipt"]["id"],
            "evidence": references,
            "remaining_gates": ["postgres_upgrade", "old_image_compatibility",
                                "backend_schema_compatibility", "critical_volumes_review"],
        }
        manifest_path = run_dir / f"recovery-run-{run_id}.json"
        with manifest_path.open("xb") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write((json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode())
    except (OSError, TypeError, ValueError) as error:
        for path in run_dir.iterdir():
            if path.is_file() and not path.is_symlink():
                path.unlink()
        run_dir.rmdir()
        raise DrillError("sanitized_report_write_failed") from error
    return manifest_path


def execute(receipt_path: Path, archive_path: Path, identity_path: Path,
            candidate_root: Path, output_dir: Path, *, age_bin: str = "age",
            docker_bin: str = "docker", tmpfs_mib: int = 1024,
            now: datetime | None = None) -> Path:
    now = now or utc_now()
    require(now.tzinfo is not None and now.utcoffset() == timedelta(0),
            "clock_not_utc")
    receipt = load_receipt(receipt_path, now)
    cipher = load_cipher(archive_path, receipt)
    cipher_sha = hashlib.sha256(cipher).hexdigest()
    regular_file(identity_path, private=True)
    api_tree, candidate_schema = candidate_identity(candidate_root)
    require(output_dir.is_dir() and not output_dir.is_symlink(), "output_directory_invalid")
    dump = decrypt_dump(cipher, identity_path, age_bin)
    try:
        plaintext_sha = hashlib.sha256(dump).hexdigest()
        run_id = utc_now().strftime("%Y%m%dT%H%M%SZ") + "-" + secrets.token_hex(8)
        result = restore_disposable(dump, docker_bin, run_id, tmpfs_mib)
        restored_at = utc_now()
        require(parse_utc(receipt["completedAt"]) <= restored_at,
                "receipt_completed_after_restore")
        require(candidate_identity(candidate_root) == (api_tree, candidate_schema),
                "candidate_changed_during_restore")
    finally:
        dump[:] = b"\x00" * len(dump)
    offsite, postgres = evidence_records(receipt, cipher_sha, plaintext_sha,
                                         run_id, restored_at,
                                         api_tree, candidate_schema, result)
    return write_reports(output_dir, run_id, api_tree, candidate_schema,
                         offsite, postgres)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="explicitly start local decryption and disposable restore")
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--identity", type=Path, required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--tmpfs-mib", type=int, default=1024)
    parser.add_argument("--age-bin", default="age",
                        help="root-owned age executable when using sudo")
    args = parser.parse_args(argv)
    if not args.execute:
        print("OFFSITE_POSTGRES_DRILL=BLOCKED: --execute is required", file=sys.stderr)
        return 2
    try:
        manifest = execute(args.receipt, args.archive, args.identity,
                           args.candidate_root, args.output_dir,
                           age_bin=args.age_bin, tmpfs_mib=args.tmpfs_mib)
    except DrillError as error:
        print(f"OFFSITE_POSTGRES_DRILL=FAIL: {error}", file=sys.stderr)
        return 1
    print(f"OFFSITE_POSTGRES_DRILL=RESTORE_VERIFIED_PENDING_UPGRADE; manifest={manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
