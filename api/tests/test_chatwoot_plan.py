import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ops"))
from chatwoot_plan import plan, validate


MANIFEST = Path(__file__).resolve().parents[2] / "docs" / "production" / "chatwoot" / "cw3_basic_manifest.json"


def load_manifest():
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def test_manifest_is_a_staging_target_without_real_email_domain():
    manifest = load_manifest()
    validate(manifest)
    assert "{{INSTITUTIONAL_DOMAIN}}" in manifest["email"]["inbox_address"]
    assert manifest["status"] == "TARGET"


def test_empty_inventory_generates_only_create_actions():
    actions = plan(load_manifest())
    assert actions
    assert {action["action"] for action in actions} == {"create"}


def test_matching_inventory_is_idempotent():
    manifest = load_manifest()
    inventory = {key: manifest[key] for key in ("inboxes", "teams", "labels", "custom_attributes", "quick_replies", "macros", "routing_intents")}
    assert {action["action"] for action in plan(manifest, inventory)} == {"unchanged"}


def test_changed_existing_resource_is_update_not_duplicate():
    manifest = load_manifest()
    inventory = {"labels": manifest["labels"][:-1] + ["retorno-humano-antigo"]}
    actions = [action for action in plan(manifest, inventory) if action["resource"] == "labels"]
    assert {action["action"] for action in actions} == {"create", "unchanged"}
