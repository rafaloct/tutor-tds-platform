"""Read-only, offline structural preflight for the EAD Android candidate.

This is deliberately not an AAB builder or an Android playback test. It reads
only source-controlled release metadata and Gradle scripts, never key material.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def inspect_sources(
    *,
    pubspec: str,
    status: dict[str, object],
    gradle: str,
    settings: str,
    wrapper: str,
    key_properties_present: bool,
) -> dict[str, object]:
    version_match = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec)
    if version_match is None:
        raise ValueError("pubspec version not found")
    name, code = version_match.groups()
    release = status["release"]
    artifact = status["artifact"]
    structural = {
        "version_matches_status": (
            release["version_name"] == name and release["version_code"] == int(code)
        ),
        "gradle_uses_flutter_version": (
            "versionCode = flutter.versionCode" in gradle
            and "versionName = flutter.versionName" in gradle
        ),
        "debug_define_gate": (
            'it.name == "preDebugBuild"' in gradle
            and "validateDebugStagingDefines(" in gradle
            and "TDS_EDITORIAL_QA_HTTP_BASE" in gradle
            and "DYNAMIC_QA_ISOLATED_PACKAGE" in gradle
        ),
        "release_define_and_freeze_gates": (
            'it.name == "preReleaseBuild"' in gradle
            and "validateReleaseFreezeState(" in gradle
            and "validateReleaseProductionDefines(" in gradle
            and '"DYNAMIC_ACTIVITY_ENABLED"' in gradle
        ),
        "release_signing_conditional": (
            'if (keystorePropertiesFile.exists())' in gradle
            and 'signingConfig = signingConfigs.getByName("release")' in gradle
        ),
        "gradle_wrapper_pinned": "gradle-9.1.0-all.zip" in wrapper,
        "android_plugin_pinned": 'id("com.android.application") version "9.0.1"' in settings,
        "kotlin_plugin_pinned": 'id("org.jetbrains.kotlin.android") version "2.3.20"' in settings,
    }
    required = [
        gate["id"]
        for gate in status["required_physical_evidence"]
        if gate["required_for_release_build"] and gate["status"] != "passed"
    ]
    return {
        "structural": structural,
        "structural_pass": all(structural.values()),
        "version_name": name,
        "version_code": int(code),
        "compile_sdk": release["compile_sdk"],
        "target_sdk": release["target_sdk"],
        "min_sdk": release["min_sdk"],
        "release_build_allowed_in_manifest": status["release_build_allowed"],
        "required_physical_gates_pending_in_manifest": required,
        "artifact_status": artifact["status"],
        "artifact_matches_current_source": artifact["matches_current_source"],
        "artifact_upload_allowed": artifact["upload_allowed"],
        "key_properties_present": key_properties_present,
        "aab_generated_by_this_check": False,
        "abi_in_aab": "UNKNOWN: no candidate AAB inspected",
        "android_mp4_audio_vtt": "UNKNOWN: no original device receipt inspected",
    }


def inspect(app: Path) -> dict[str, object]:
    return inspect_sources(
        pubspec=(app / "pubspec.yaml").read_text(encoding="utf-8"),
        status=json.loads((app / "release/release_status.json").read_text(encoding="utf-8")),
        gradle=(app / "android/app/build.gradle.kts").read_text(encoding="utf-8"),
        settings=(app / "android/settings.gradle.kts").read_text(encoding="utf-8"),
        wrapper=(app / "android/gradle/wrapper/gradle-wrapper.properties").read_text(
            encoding="utf-8"
        ),
        key_properties_present=(app / "android/key.properties").exists(),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--app", type=Path, default=Path(__file__).resolve().parents[2] / "cartilhas_app"
    )
    args = parser.parse_args()
    result = inspect(args.app.resolve())
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["structural_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
