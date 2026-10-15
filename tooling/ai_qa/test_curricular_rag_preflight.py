"""Focused offline preflight checks; no API, Drive, or RAG credentials needed."""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from curricular_rag_preflight import (
    DEFAULT_EVIDENCE,
    DEFAULT_LESSONS,
    DEFAULT_MAP,
    PreflightError,
    _digest,
    _read_json,
    _validate_map,
    build_manifest,
)


def _write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


class CurricularRagPreflightTest(unittest.TestCase):
    def test_versioned_source_map_matches_historical_evidence(self) -> None:
        source_map, _ = _read_json(DEFAULT_MAP)
        evidence, evidence_sha = _read_json(DEFAULT_EVIDENCE)
        self.assertEqual(len(_validate_map(source_map, evidence, evidence_sha)), 9)

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.exports = self.root / "exports"
        self.pdfs = self.root / "pdfs"
        self.exports.mkdir()
        self.pdfs.mkdir()
        self.map_path = self.root / "source_map.json"
        self.evidence_path = self.root / "evidence.json"
        self.source_map = deepcopy(json.loads(DEFAULT_MAP.read_text(encoding="utf-8")))
        self.evidence = deepcopy(json.loads(DEFAULT_EVIDENCE.read_text(encoding="utf-8")))

        originals = {entry["name"]: entry for entry in self.evidence["local_originals"]}
        for index, row in enumerate(self.source_map["sources"]):
            pdf = b"%PDF-1.7\n" + f"test course {index}\n".encode() + bytes([65 + index]) * 1100 + b"\n%%EOF\n"
            pdf_sha = hashlib.sha256(pdf).hexdigest()
            (self.pdfs / row["original_pdf_name"]).write_bytes(pdf)
            row["original_pdf_bytes"] = len(pdf)
            row["original_pdf_sha256"] = pdf_sha
            originals[row["original_pdf_name"]]["bytes"] = len(pdf)
            originals[row["original_pdf_name"]]["sha256"] = pdf_sha

            lesson = json.loads((DEFAULT_LESSONS / row["lesson_file"]).read_text(encoding="utf-8"))
            content = deepcopy(lesson)
            for section in content["sections"]:
                section["version_id"] = "synthetic-section-version"
                for message_index, message in enumerate(section["messages"]):
                    message["id"] = f"synthetic-message-{message_index}"
                    message["version_id"] = "synthetic-message-version"
            export = {
                "schema_version": 1,
                "course_id": row["course_id"],
                "version_id": row["course_version_id"],
                "version_number": 1,
                "content": content,
            }
            export["sha256"] = _digest(export)
            _write_json(self.exports / f'{row["course_id"]}.json', export)
        self.persist_map_and_evidence()

    def persist_map_and_evidence(self) -> None:
        _write_json(self.evidence_path, self.evidence)
        self.source_map["hosting_evidence_sha256"] = hashlib.sha256(self.evidence_path.read_bytes()).hexdigest()
        _write_json(self.map_path, self.source_map)

    def build(self) -> dict:
        return build_manifest(
            source_map_path=self.map_path,
            evidence_path=self.evidence_path,
            lesson_root=DEFAULT_LESSONS,
            exports_dir=self.exports,
            pdf_root=self.pdfs,
        )

    def first_row(self) -> dict:
        return self.source_map["sources"][0]

    def first_export(self) -> tuple[Path, dict]:
        path = self.exports / f'{self.first_row()["course_id"]}.json'
        return path, json.loads(path.read_text(encoding="utf-8"))

    def test_valid_local_materials_produce_deterministic_unindexed_manifest(self) -> None:
        first = self.build()
        self.assertEqual(first, self.build())
        self.assertEqual(len(first["sources"]), 9)
        self.assertEqual(first["validation_scope"], "offline_operator_supplied_files_only")
        self.assertFalse(first["drive_bytes_provenance_verified"])
        self.assertFalse(first["anythingllm_indexed"])
        self.assertFalse(first["editorial_approval_verified"])
        self.assertEqual(first["sha256"], _digest({key: value for key, value in first.items() if key != "sha256"}))
        self.assertEqual([row["course_id"] for row in first["sources"]], sorted(row["course_id"] for row in first["sources"]))

    def test_missing_pdf_and_html_viewer_are_rejected(self) -> None:
        row = self.first_row()
        path = self.pdfs / row["original_pdf_name"]
        pdf = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(PreflightError, "PDF ausente"):
            self.build()
        html = b"<html>Google Drive viewer</html>" + b" " * (len(pdf) - 33)
        path.write_bytes(html)
        row["original_pdf_bytes"] = len(html)
        row["original_pdf_sha256"] = hashlib.sha256(html).hexdigest()
        original = next(entry for entry in self.evidence["local_originals"] if entry["name"] == row["original_pdf_name"])
        original.update(bytes=len(html), sha256=row["original_pdf_sha256"])
        self.persist_map_and_evidence()
        with self.assertRaisesRegex(PreflightError, "não é PDF"):
            self.build()

    def test_changed_pdf_bytes_fail_even_when_size_and_signature_match(self) -> None:
        path = self.pdfs / self.first_row()["original_pdf_name"]
        payload = path.read_bytes()
        path.write_bytes(payload[:40] + b"Z" + payload[41:])
        with self.assertRaisesRegex(PreflightError, "SHA-256 divergente"):
            self.build()

    def test_export_version_and_url_mismatch_fail_with_recomputed_digest(self) -> None:
        path, exported = self.first_export()
        exported["version_id"] = "wrong-version"
        exported["sha256"] = _digest({key: value for key, value in exported.items() if key != "sha256"})
        _write_json(path, exported)
        with self.assertRaisesRegex(PreflightError, "versão divergente"):
            self.build()

        exported["version_id"] = self.first_row()["course_version_id"]
        exported["content"]["downloadUrl"] = "https://drive.google.com/file/d/different/view"
        exported["sha256"] = _digest({key: value for key, value in exported.items() if key != "sha256"})
        _write_json(path, exported)
        with self.assertRaisesRegex(PreflightError, "URL divergente"):
            self.build()

    def test_reviewed_drive_url_cannot_be_replaced_with_another_file(self) -> None:
        self.first_row()["drive_view_url"] = "https://drive.google.com/file/d/anotherFileIdentifier12345/view"
        self.persist_map_and_evidence()
        with self.assertRaisesRegex(PreflightError, "URL do Drive não canônica"):
            self.build()

    def test_lesson_drift_and_duplicate_source_hash_are_rejected(self) -> None:
        row = self.first_row()
        row["lesson_sha256"] = "0" * 64
        self.persist_map_and_evidence()
        with self.assertRaisesRegex(PreflightError, "aula: hash"):
            self.build()

        row["lesson_sha256"] = hashlib.sha256((DEFAULT_LESSONS / row["lesson_file"]).read_bytes()).hexdigest()
        second = self.source_map["sources"][1]
        second["original_pdf_sha256"] = row["original_pdf_sha256"]
        original = next(entry for entry in self.evidence["local_originals"] if entry["name"] == second["original_pdf_name"])
        original["sha256"] = row["original_pdf_sha256"]
        self.persist_map_and_evidence()
        with self.assertRaisesRegex(PreflightError, "original_pdf_sha256 duplicado"):
            self.build()

    def test_traversal_symlink_and_duplicate_json_keys_are_rejected(self) -> None:
        row = self.first_row()
        row["original_pdf_name"] = "../private.pdf"
        self.persist_map_and_evidence()
        with self.assertRaisesRegex(PreflightError, "nome do PDF inválido"):
            self.build()

        row["original_pdf_name"] = self.evidence["local_originals"][0]["name"]
        self.persist_map_and_evidence()
        pdf = self.pdfs / row["original_pdf_name"]
        target = self.root / "elsewhere.pdf"
        target.write_bytes(pdf.read_bytes())
        pdf.unlink()
        pdf.symlink_to(target)
        with self.assertRaisesRegex(PreflightError, "link simbólico"):
            self.build()

        pdf.unlink()
        pdf.write_bytes(target.read_bytes())
        export_path, _ = self.first_export()
        export_path.write_text('{"schema_version":1,"schema_version":1}', encoding="utf-8")
        with self.assertRaisesRegex(PreflightError, "chave duplicada"):
            self.build()


if __name__ == "__main__":
    unittest.main()
