#!/usr/bin/env python3
"""Opt-in offsite restore, additive upgrade and rollback rehearsal on the VPS.

Inputs are downloaded/custodied separately. Production containers are inspected
and queried read-only; migrations and HTTP probes use disposable resources only.
Private identities, plaintext dumps and isolated credentials never enter reports.
"""
from __future__ import annotations

import argparse
import ast
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import tempfile
import time
from typing import Any

try:
    from tooling import rehearse_scheduled_postgres_backup as restore
except ModuleNotFoundError:  # Direct execution of the installed companion pair.
    import rehearse_scheduled_postgres_backup as restore


PURPOSE = "scheduled-offsite-upgrade"
IMAGE_ID = re.compile(r"sha256:[0-9a-f]{64}\Z")
METHODS = {"get", "post", "put", "patch", "delete"}
SOURCE = "https://github.com/rafaloct/tutor-tds-platform"


def required_operations(candidate: Path) -> set[str]:
    """Read the reviewed client contract as data; never execute checkout code."""
    source = restore.read_git(candidate, "show", "HEAD:api/ops/promotion_preflight.py")
    try:
        module = ast.parse(source)
        assignments = [node for node in module.body if isinstance(node, ast.Assign)
                       and any(isinstance(target, ast.Name) and
                               target.id == "AAB_14_OPERATIONS" for target in node.targets)]
        restore.require(len(assignments) == 1, "client_operations_contract_invalid")
        value = ast.literal_eval(assignments[0].value)
        restore.require(isinstance(value, set) and bool(value) and
                        all(isinstance(item, str) and
                            re.fullmatch(r"(?:GET|POST|PUT|PATCH|DELETE) /\S+", item)
                            for item in value), "client_operations_contract_invalid")
        return value
    except (SyntaxError, ValueError, TypeError) as error:
        raise restore.DrillError("client_operations_contract_invalid") from error


def compare_openapi(old: dict, new: dict, required: set[str]) -> dict[str, Any]:
    def operations(document: dict) -> set[str]:
        restore.require(isinstance(document.get("paths"), dict), "openapi_invalid")
        return {f"{method.upper()} {path}" for path, item in document["paths"].items()
                for method in item if method in METHODS}

    old_ops, new_ops = operations(old), operations(new)
    old_schemas = old.get("components", {}).get("schemas", {})
    new_schemas = new.get("components", {}).get("schemas", {})
    comparison = {"production_operation_count": len(old_ops),
                  "candidate_operation_count": len(new_ops),
                  "only_production": sorted(old_ops - new_ops),
                  "only_candidate": sorted(new_ops - old_ops),
                  "aab_14_missing_in_candidate": sorted(required - new_ops),
                  "common_schema_changes": sorted(name for name in old_schemas.keys() &
                                                  new_schemas.keys()
                                                  if old_schemas[name] != new_schemas[name])}
    comparison["common_schema_deltas"] = {
        name: {"production": old_schemas[name], "candidate": new_schemas[name]}
        for name in comparison["common_schema_changes"]
    }
    restore.require(not comparison["only_production"] and
                    not comparison["aab_14_missing_in_candidate"], "openapi_routes_incompatible")
    return comparison


def legacy_matches(old: Any, new: Any) -> bool:
    if isinstance(old, dict):
        return isinstance(new, dict) and all(key in new and legacy_matches(value, new[key])
                                             for key, value in old.items())
    if isinstance(old, list):
        return isinstance(new, list) and len(old) == len(new) and all(
            legacy_matches(a, b) for a, b in zip(old, new))
    return type(old) is type(new) and old == new


class Rehearsal:
    def __init__(self, run_id: str, docker_bin: str = "docker") -> None:
        self.run_id = run_id
        self.docker_bin = docker_bin
        self.resources: list[tuple[str, str]] = []

    def docker(self, *args: str, input_bytes: bytes | bytearray | None = None,
               timeout: int = 60) -> bytes:
        return restore.command([self.docker_bin, *args], input_bytes=input_bytes, timeout=timeout)

    def inspect(self, kind: str, name: str) -> dict:
        records = json.loads(self.docker(kind, "inspect", name))
        restore.require(isinstance(records, list) and len(records) == 1, "docker_identity_invalid")
        return records[0]

    def cleanup(self) -> None:
        failed = False
        for kind, name in reversed(self.resources):
            try:
                # A successful listing confirms absence without confusing a missing
                # object with an unavailable daemon. Registration precedes creation.
                listing = self.docker(kind, "ls", *(["--all"] if kind == "container" else []),
                                      "--filter", f"name={name}", "--format",
                                      "{{.Names}}" if kind == "container" else "{{.Name}}")
                if name not in listing.decode().splitlines():
                    continue
                record = self.inspect(kind, name)
                labels = record.get("Labels", {}) if kind == "network" else record["Config"]["Labels"]
                restore.require(labels.get("tds.purpose") == PURPOSE and
                                labels.get("tds.run") == self.run_id, "disposable_ownership_unverified")
                self.docker(kind, "rm", *(["--force"] if kind == "container" else []), name)
            except (restore.DrillError, ValueError, KeyError, TypeError):
                failed = True
                # Try the other owned resources even if one inspect/delete fails.
        restore.require(not failed, "disposable_cleanup_failed")

    def labels(self) -> list[str]:
        return ["--label", f"tds.purpose={PURPOSE}", "--label", f"tds.run={self.run_id}"]

    def create(self, kind: str, name: str, *args: str) -> None:
        # Register before Docker sends the command: transport failure may follow creation.
        self.resources.append((kind, name))
        if kind == "network":
            self.docker("network", "create", "--internal", *self.labels(), name)
        else:
            self.docker("run", "--detach", "--pull=never", "--name", name,
                        *self.labels(), *args)

    def sql(self, container: str, query: str) -> str:
        return self.docker("exec", "-e",
                           "PGOPTIONS=-c default_transaction_read_only=on -c statement_timeout=120000",
                           container, "psql", "-U", "tutor_tds", "-d", "tutor_tds", "-At",
                           "-v", "ON_ERROR_STOP=1", "-c", query, timeout=180).decode().strip()

    def columns(self, container: str) -> dict[str, list[str]]:
        rows = json.loads(self.sql(container, "SELECT json_agg(x) FROM "
                                  "(SELECT table_name,column_name FROM information_schema.columns "
                                  "WHERE table_schema='public' AND table_name!='alembic_version' "
                                  "ORDER BY table_name,ordinal_position) x"))
        result: dict[str, list[str]] = {}
        for row in rows:
            restore.require(re.fullmatch(r"[a-z_]+", row["table_name"]) is not None and
                            re.fullmatch(r"[a-z_]+", row["column_name"]) is not None,
                            "database_identifiers_invalid")
            result.setdefault(row["table_name"], []).append(row["column_name"])
        restore.require(bool(result), "restored_database_empty")
        return result

    def fingerprint(self, container: str, columns: dict[str, list[str]]) -> dict[str, str]:
        result = {}
        for table, fields in columns.items():
            projection = ",".join('"' + field + '"' for field in fields)
            result[table] = self.sql(container, f"SELECT count(*) || ':' || "
                                     "coalesce(md5(string_agg(row_to_json(x)::text,E'\\n' "
                                     "ORDER BY row_to_json(x)::text)),'empty') "
                                     f'FROM (SELECT {projection} FROM "{table}") x')
        return result

    def production_state(self) -> dict[str, Any]:
        # Request only identity/state/labels, never the source containers' Config.Env.
        template = ('{"Id":{{json .Id}},"Image":{{json .Image}},'
                    '"State":{"Running":{{json .State.Running}}},'
                    '"Config":{"Labels":{{json .Config.Labels}}}}')
        api = json.loads(self.docker("container", "inspect", "--format", template,
                                     "tutor-tds-api-api-1"))
        db = json.loads(self.docker("container", "inspect", "--format", template,
                                    "tutor-tds-api-db-1"))
        for record, service in ((api, "api"), (db, "db")):
            labels = record["Config"].get("Labels", {})
            restore.require(record["State"]["Running"] is True and
                            labels.get("com.docker.compose.project") == "tutor-tds-api" and
                            labels.get("com.docker.compose.service") == service,
                            "production_container_identity_invalid")
        columns = self.columns("tutor-tds-api-db-1")
        return {"api_id": api["Id"], "db_id": db["Id"], "image_id": api["Image"],
                "revision": self.sql("tutor-tds-api-db-1", "SELECT version_num FROM alembic_version"),
                "columns": columns, "fingerprints": self.fingerprint("tutor-tds-api-db-1", columns)}

    def get(self, container: str, path: str) -> dict:
        program = ("import urllib.request; "
                   f"print(urllib.request.urlopen('http://127.0.0.1:8000{path}',timeout=10).read().decode())")
        return json.loads(self.docker("exec", container, "python", "-c", program, timeout=15))

    def start_api(self, name: str, image: str, network: str, env_file: Path) -> dict:
        self.create("container", name, "--network", network, "--memory", "512m", "--cpus", "1",
                    "--env-file", str(env_file), image, "uvicorn", "app.main:app", "--host",
                    "0.0.0.0", "--port", "8000", "--no-access-log")
        for _ in range(40):
            try:
                health = self.get(name, "/health")
                restore.require(health == {"status": "ok", "database": "available"},
                                "isolated_api_health_invalid")
                return health
            except restore.DrillError:
                time.sleep(1)
        raise restore.DrillError("isolated_api_not_ready")


def image_identity(run: Rehearsal, image: str, candidate: Path) -> str:
    record = run.inspect("image", image)
    digest = record.get("Id", "")
    labels = record.get("Config", {}).get("Labels", {})
    commit = restore.read_git(candidate, "rev-parse", "HEAD").decode().strip()
    created = restore.read_git(candidate, "show", "-s", "--format=%cI", "HEAD").decode().strip()
    restore.require(IMAGE_ID.fullmatch(digest) is not None and
                    labels.get("org.opencontainers.image.revision") == commit and
                    labels.get("org.opencontainers.image.version") == commit and
                    labels.get("org.opencontainers.image.source") == SOURCE and
                    labels.get("org.opencontainers.image.created") == created,
                    "candidate_image_provenance_invalid")
    return digest


def rehearse(dump: bytearray, candidate: Path, image: str, run: Rehearsal,
             api_tree: str, schema: str, tmpfs_mib: int) -> tuple[dict, datetime]:
    restore.require(256 <= tmpfs_mib <= 1536, "tmpfs_size_invalid")
    candidate_digest = image_identity(run, image, candidate)
    required = required_operations(candidate)
    before = run.production_state()
    restore.require(IMAGE_ID.fullmatch(before["image_id"]) is not None, "rollback_image_invalid")
    postgres_digest = run.inspect("image", restore.POSTGRES_IMAGE)["Id"]
    restore.require(IMAGE_ID.fullmatch(postgres_digest) is not None, "postgres_image_invalid")
    prefix = f"tds-offsite-upgrade-{run.run_id}"
    network, database = prefix + "-net", prefix + "-db"
    with tempfile.TemporaryDirectory(prefix="tds-upgrade-private-") as private_dir:
        private = Path(private_dir)
        private.chmod(0o700)
        env_file = private / "isolated.env"
        password = secrets.token_hex(24)
        environment = {
            "TUTOR_ENVIRONMENT": "production",
            "DATABASE_URL": f"postgresql+psycopg://tutor_tds:{password}@{database}:5432/tutor_tds",
            "JWT_SECRET": secrets.token_hex(32), "CPF_PEPPER": secrets.token_hex(32),
            "SHEETS_PSEUDONYM_SECRET": secrets.token_hex(32),
            "LEARNING_CONTEXT_ENABLED": "false", "JOURNEY_TRACEABILITY_ENABLED": "false",
            "DYNAMIC_ACTIVITY_ENABLED": "false", "PAYMENT_ADAPTER": "disabled",
            "COMMERCIAL_SIMULATION_ENABLED": "false",
            "ALLOWED_ORIGINS": "https://cartilhas.ipexdesenvolvimento.cloud",
            "PUBLIC_API_BASE_URL": "https://ead.ipexdesenvolvimento.cloud/tutor-api",
        }
        # Use the same randomly generated password in the clone and API, without argv secrets.
        with env_file.open("x") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write("".join(f"{key}={value}\n" for key, value in environment.items()))
        db_env = private / "db.env"
        with db_env.open("x") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write(f"POSTGRES_USER=tutor_tds\nPOSTGRES_DB=tutor_tds\nPOSTGRES_PASSWORD={password}\n")
        try:
            run.create("network", network)
            run.create("container", database, "--network", network, "--memory", "2g", "--cpus", "2",
                       "--tmpfs", f"/var/lib/postgresql/data:rw,size={tmpfs_mib}m", "--env-file",
                       str(db_env), postgres_digest)
            metadata = run.inspect("container", database)
            restore.require(metadata.get("Mounts") == [] and
                            metadata["HostConfig"]["Tmpfs"] == {
                                "/var/lib/postgresql/data": f"rw,size={tmpfs_mib}m"} and
                            metadata["HostConfig"]["NetworkMode"] == network and
                            not metadata["HostConfig"].get("PortBindings"), "isolated_database_not_disposable")
            network_info = run.inspect("network", network)
            restore.require(network_info.get("Internal") is True, "isolated_network_has_egress")
            for _ in range(40):
                try:
                    run.docker("exec", database, "pg_isready", "-h", "127.0.0.1", "-U", "tutor_tds", "-d", "tutor_tds")
                    break
                except restore.DrillError:
                    time.sleep(1)
            else:
                raise restore.DrillError("isolated_postgres_not_ready")
            filesystem = run.docker("exec", database, "df", "-T", "/var/lib/postgresql/data").decode().splitlines()
            restore.require(len(filesystem) >= 2 and filesystem[-1].split()[1:2] == ["tmpfs"],
                            "isolated_database_not_tmpfs")
            run.docker("exec", "-i", database, "pg_restore", "--exit-on-error", "--no-owner",
                       "--no-privileges", "-U", "tutor_tds", "-d", "tutor_tds", input_bytes=dump, timeout=900)
            restored_at = restore.utc_now()
            dump[:] = b"\x00" * len(dump)
            postgres_version = run.sql(database, "SELECT current_setting('server_version_num')")
            restore.require(postgres_version.isdigit() and 160000 <= int(postgres_version) < 170000,
                            "isolated_postgres_major_not_16")
            columns = run.columns(database)
            restore.require({"users", "courses", "learning_events"} <= columns.keys(),
                            "restored_core_tables_missing")
            restored = run.fingerprint(database, columns)
            restored_schema = run.sql(database, "SELECT version_num FROM alembic_version")
            restore.require(restore.REVISION.fullmatch(restored_schema) is not None, "restored_schema_invalid")
            migrator = prefix + "-migrate"
            run.create("container", migrator, "--network", network, "--memory", "512m", "--cpus", "1",
                       "--env-file", str(env_file), candidate_digest, "alembic", "upgrade", "head")
            restore.require(run.docker("wait", migrator, timeout=900).decode().strip() == "0",
                            "isolated_migration_failed")
            clone_schema = run.sql(database, "SELECT version_num FROM alembic_version")
            restore.require(clone_schema == schema, "upgraded_schema_differs_from_candidate")
            restore.require(run.fingerprint(database, columns) == restored, "migration_changed_original_data")
            candidate_api, rollback_api = prefix + "-new", prefix + "-old"
            run.start_api(candidate_api, candidate_digest, network, env_file)
            run.start_api(rollback_api, before["image_id"], network, env_file)
            comparison = compare_openapi(run.get(rollback_api, "/openapi.json"),
                                         run.get(candidate_api, "/openapi.json"), required)
            restore.require(legacy_matches(run.get(rollback_api, "/courses"),
                                           run.get(candidate_api, "/courses")), "public_catalog_incompatible")
            restore.require(run.production_state() == before, "production_changed_during_rehearsal")
            restore.require(restore.candidate_identity(candidate) == (api_tree, schema),
                            "candidate_changed_during_rehearsal")
            return {"status": "passed", "run_id": run.run_id, "api_tree_oid": api_tree,
                    "clone_revision": clone_schema, "restored_schema_version": restored_schema,
                    "candidate_image_id": candidate_digest, "production_image_id": before["image_id"],
                    "postgres_image_id": postgres_digest, "postgres_version_num": postgres_version,
                    "restore_verified": True, "production_unchanged": True,
                    "original_columns_preserved": True, "old_image_runs_on_upgraded_database": True,
                    "public_catalog_compatible": True, "openapi_comparison": comparison,
                    "production_writes": False}, restored_at
        finally:
            run.cleanup()


def execute(receipt_path: Path, archive_path: Path, identity_path: Path,
            candidate: Path, image: str, output_dir: Path, *, age_bin: str = "age",
            docker_bin: str = "docker", tmpfs_mib: int = 1024) -> Path:
    restore.require(IMAGE_ID.fullmatch(image) is not None or
                    re.fullmatch(r"tutor-tds-(?:candidate|context-gate):[a-z0-9.-]+", image) is not None,
                    "candidate_image_reference_invalid")
    receipt = restore.load_receipt(receipt_path, restore.utc_now())
    cipher = restore.load_cipher(archive_path, receipt)
    restore.regular_file(identity_path, private=True)
    api_tree, schema = restore.candidate_identity(candidate)
    restore.require(output_dir.is_dir() and not output_dir.is_symlink(), "output_directory_invalid")
    run_id = restore.utc_now().strftime("%Y%m%dT%H%M%SZ") + "-" + secrets.token_hex(8)
    dump = restore.decrypt_dump(cipher, identity_path, age_bin)
    try:
        plain_sha = hashlib.sha256(dump).hexdigest()
        record, restored_at = rehearse(dump, candidate, image, Rehearsal(run_id, docker_bin),
                                       api_tree, schema, tmpfs_mib)
        restore.require(restore.parse_utc(receipt["completedAt"]) <= restored_at,
                        "receipt_completed_after_restore")
    finally:
        dump[:] = b"\x00" * len(dump)
    offsite, _ = restore.evidence_records(receipt, hashlib.sha256(cipher).hexdigest(), plain_sha,
                                         run_id, restored_at, api_tree, schema,
                                         {key: record[key] for key in
                                          ("restored_schema_version", "postgres_image_id", "postgres_version_num")})
    record.update({"source_backup": {"receipt_id": receipt["id"], "object_key": receipt["key"],
                                     "plaintext_sha256": plain_sha}, "backup": {"sha256": plain_sha},
                   "completed_at": restore.iso_utc(restore.utc_now()), "isolated_resources_removed": True})
    run_dir = output_dir / f"scheduled-upgrade-{run_id}"
    run_dir.mkdir(mode=0o700)
    references = {}
    for gate, name, value in (("offsite_backup", f"scheduled-postgres-offsite-{run_id}.json", offsite),
                              ("postgres_restore", f"postgres-upgrade-{run_id}.json", record)):
        payload = (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()
        with (run_dir / name).open("xb") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write(payload)
        references[gate] = {"file": name, "sha256": hashlib.sha256(payload).hexdigest()}
    references.update({gate: references["postgres_restore"] for gate in
                       ("upgrade_compatibility", "backend_schema_compatibility")})
    manifest = {"status": "postgres_compatibility_verified_pending_critical_volumes_review",
                "candidate_schema_version": schema, "candidate_api_tree_oid": api_tree,
                "evidence": references, "remaining_gates": ["critical_volumes_custody_review",
                                                             "schema_changes_review",
                                                             "final_acceptance_review"]}
    path = run_dir / f"recovery-run-{run_id}.json"
    with path.open("x") as handle:
        os.fchmod(handle.fileno(), 0o600)
        handle.write(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    return path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    for name in ("receipt", "archive", "identity", "candidate-root", "output-dir"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--candidate-image", required=True)
    parser.add_argument("--age-bin", default="age")
    parser.add_argument("--tmpfs-mib", type=int, default=1024)
    args = parser.parse_args(argv)
    if not args.execute:
        print("OFFSITE_POSTGRES_UPGRADE=BLOCKED: --execute is required")
        return 2
    try:
        manifest = execute(args.receipt, args.archive, args.identity, args.candidate_root,
                           args.candidate_image, args.output_dir, age_bin=args.age_bin,
                           tmpfs_mib=args.tmpfs_mib)
    except restore.DrillError as error:
        print(f"OFFSITE_POSTGRES_UPGRADE=FAIL: {error}")
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        # A raw exception may contain paths, SQL, a DSN or values from subprocesses.
        print("OFFSITE_POSTGRES_UPGRADE=FAIL: inspect prerequisites and isolated resources")
        return 1
    print(f"OFFSITE_POSTGRES_UPGRADE=COMPATIBILITY_VERIFIED_PENDING_REVIEW; manifest={manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
