from __future__ import annotations

import pytest

from app.config import Settings
from app.media_delivery import (
    DEFAULT_MEDIA_DELIVERY,
    FakeMediaDeliveryAdapter,
    MediaDeliveryRegistry,
)


def settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "database_url": "sqlite+pysqlite:///:memory:",
        "allowed_origins": (),
        "public_api_base_url": "https://api.tds.example/tutor-api",
    }
    values.update(overrides)
    return Settings(**values)


def test_current_providers_resolve_behind_registry() -> None:
    configured = settings(
        cloudflare_stream_delivery_base_url="https://customer-abc.cloudflarestream.com"
    )

    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="youtube",
        asset_id="abcDEF12345",
        settings=configured,
    ) == "https://www.youtube-nocookie.com/embed/abcDEF12345"
    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="cloudflare_stream",
        asset_id="streamAsset_123",
        settings=configured,
    ) == (
        "https://customer-abc.cloudflarestream.com/"
        "streamAsset_123/manifest/video.m3u8"
    )
    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="external_hls",
        asset_id="https://media.example.org/course/video.m3u8?v=1",
        settings=configured,
    ) == "https://media.example.org/course/video.m3u8?v=1"


def test_fake_adapter_is_explicit_and_not_registered_by_default() -> None:
    configured = settings()
    fake = MediaDeliveryRegistry(
        [
            FakeMediaDeliveryAdapter(
                target_url="https://fake-media.example.org/video.m3u8"
            )
        ]
    )

    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="fake", asset_id="asset-123", settings=configured
    ) is None
    assert fake.playback_url(
        provider="fake", asset_id="asset-123", settings=configured
    ) == "https://fake-media.example.org/video.m3u8"


@pytest.mark.parametrize(
    "target",
    [
        "https://127.0.0.1/video.m3u8",
        "https://10.0.0.8/video.m3u8",
        "https://media.internal/video.m3u8",
        "https://localhost/video.m3u8",
        "https://drive.google.com/video.m3u8",
        "https://docs.google.com/video.m3u8",
        "https://abc.googleusercontent.com/video.m3u8",
    ],
)
def test_external_hls_rejects_local_internal_ip_and_drive_delivery(
    target: str,
) -> None:
    with pytest.raises(ValueError):
        DEFAULT_MEDIA_DELIVERY.validate_asset("external_hls", target)


def test_api_vps_host_is_not_accepted_as_delivery_cdn() -> None:
    configured = settings(public_api_base_url="https://api.example.org/tutor-api")

    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="external_hls",
        asset_id="https://api.example.org/media/video.m3u8",
        settings=configured,
    ) is None
    assert MediaDeliveryRegistry(
        [
            FakeMediaDeliveryAdapter(
                target_url="https://api.example.org/media/video.m3u8"
            )
        ]
    ).playback_url(
        provider="fake",
        asset_id="asset-123",
        settings=configured,
    ) is None


def test_cloudflare_base_is_guarded_fail_closed() -> None:
    configured = settings(
        cloudflare_stream_delivery_base_url="https://192.168.1.20"
    )
    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="cloudflare_stream",
        asset_id="streamAsset_123",
        settings=configured,
    ) is None


def test_unsupported_provider_fails_closed() -> None:
    configured = settings()
    assert DEFAULT_MEDIA_DELIVERY.playback_url(
        provider="unsupported",
        asset_id="asset-123",
        settings=configured,
    ) is None
    with pytest.raises(ValueError, match="não suportado"):
        DEFAULT_MEDIA_DELIVERY.validate_asset("unsupported", "asset-123")
