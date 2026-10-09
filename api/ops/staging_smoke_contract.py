"""Guards shared by authenticated staging smoke runners."""

from __future__ import annotations

import re
from urllib.parse import urlsplit


CANONICAL_STAGING_BASE_URL = "https://tutor-tds-staging.fastapicloud.dev"
_FIXTURE_ID = re.compile(r"staging-qa-[a-z0-9-]{1,80}")


def validate_canonical_staging_base_url(value: str) -> str:
    base_url = value.rstrip("/")
    parsed = urlsplit(base_url)
    try:
        port = parsed.port
    except ValueError as exc:
        raise RuntimeError("Refusing non-canonical staging base URL") from exc
    if (
        parsed.scheme != "https"
        or parsed.username is not None
        or parsed.password is not None
        or port is not None
        or parsed.query
        or parsed.fragment
        or base_url != CANONICAL_STAGING_BASE_URL
    ):
        raise RuntimeError("Refusing non-canonical staging base URL")
    return base_url


def validate_fixture_class_id(value: str) -> str:
    class_id = value.strip()
    if not _FIXTURE_ID.fullmatch(class_id):
        raise RuntimeError("Refusing non-disposable staging fixture")
    return class_id
