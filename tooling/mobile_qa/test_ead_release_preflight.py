"""Synthetic regressions for the read-only release preflight."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from ead_release_preflight import inspect_sources


SOURCE = Path(__file__).resolve().parents[2] / "cartilhas_app"
def sources() -> dict[str, object]:
    return {
        "pubspec": (SOURCE / "pubspec.yaml").read_text(encoding="utf-8"),
        "status": json.loads((SOURCE / "release/release_status.json").read_text(encoding="utf-8")),
        "gradle": (SOURCE / "android/app/build.gradle.kts").read_text(encoding="utf-8"),
        "settings": (SOURCE / "android/settings.gradle.kts").read_text(encoding="utf-8"),
        "wrapper": (SOURCE / "android/gradle/wrapper/gradle-wrapper.properties").read_text(
            encoding="utf-8"
        ),
        "key_properties_present": False,
    }


class EadReleasePreflightTest(unittest.TestCase):
    def test_current_structural_contract_and_unsigned_boundary(self) -> None:
        result = inspect_sources(**sources())
        self.assertTrue(result["structural_pass"], result["structural"])
        self.assertEqual(result["artifact_status"], "superseded")
        self.assertFalse(result["artifact_upload_allowed"])
        self.assertFalse(result["aab_generated_by_this_check"])

    def test_version_mismatch_fails_closed(self) -> None:
        fixture = sources()
        fixture["pubspec"] = str(fixture["pubspec"]).replace(
            "version: 1.4.0+13", "version: 1.4.0+14"
        )
        result = inspect_sources(**fixture)
        self.assertFalse(result["structural_pass"])
        self.assertFalse(result["structural"]["version_matches_status"])

    def test_removed_release_define_gate_fails_closed(self) -> None:
        fixture = sources()
        fixture["gradle"] = str(fixture["gradle"]).replace(
            "validateReleaseProductionDefines(", "removedReleaseProductionDefines("
        )
        result = inspect_sources(**fixture)
        self.assertFalse(result["structural_pass"])
        self.assertFalse(result["structural"]["release_define_and_freeze_gates"])


if __name__ == "__main__":
    unittest.main()
