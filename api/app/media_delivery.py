from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import re
from typing import Protocol
from urllib.parse import urlsplit

from .config import Settings


_ASSET_ID = re.compile(r"^[A-Za-z0-9_-]{6,200}$")
_INTERNAL_SUFFIXES = (
    ".localhost",
    ".local",
    ".internal",
    ".lan",
    ".home",
    ".localdomain",
)
_DRIVE_HOSTS = {"drive.google.com", "docs.google.com"}


class MediaDeliveryAdapter(Protocol):
    provider: str

    def validate_asset_id(self, asset_id: str) -> None: ...

    def resolve(self, asset_id: str, settings: Settings) -> str | None: ...


@dataclass(frozen=True)
class YouTubeDeliveryAdapter:
    provider: str = "youtube"

    def validate_asset_id(self, asset_id: str) -> None:
        _validate_compact_asset_id(asset_id)

    def resolve(self, asset_id: str, settings: Settings) -> str:
        del settings
        return f"https://www.youtube-nocookie.com/embed/{asset_id}"


@dataclass(frozen=True)
class CloudflareStreamDeliveryAdapter:
    provider: str = "cloudflare_stream"

    def validate_asset_id(self, asset_id: str) -> None:
        _validate_compact_asset_id(asset_id)

    def resolve(self, asset_id: str, settings: Settings) -> str | None:
        base = settings.cloudflare_stream_delivery_base_url
        if base is None or not base.strip():
            return None
        parsed = urlsplit(base.strip())
        if parsed.query or parsed.fragment:
            return None
        return f"{base.strip().rstrip('/')}/{asset_id}/manifest/video.m3u8"


@dataclass(frozen=True)
class ExternalHlsDeliveryAdapter:
    provider: str = "external_hls"

    def validate_asset_id(self, asset_id: str) -> None:
        parsed = urlsplit(asset_id)
        if (
            parsed.scheme != "https"
            or not parsed.hostname
            or not parsed.path.lower().endswith(".m3u8")
            or _is_forbidden_host(parsed.hostname)
        ):
            raise ValueError(
                "external_hls exige HTTPS .m3u8 em host público de entrega"
            )
        _validate_port(parsed)

    def resolve(self, asset_id: str, settings: Settings) -> str:
        del settings
        return asset_id


@dataclass(frozen=True)
class FakeMediaDeliveryAdapter:
    """Deterministic local/test adapter; never registered in the application."""

    target_url: str
    provider: str = "fake"

    def validate_asset_id(self, asset_id: str) -> None:
        if not asset_id or len(asset_id) > 500:
            raise ValueError("fake asset id inválido")

    def resolve(self, asset_id: str, settings: Settings) -> str:
        del asset_id, settings
        return self.target_url


class MediaDeliveryRegistry:
    def __init__(self, adapters: list[MediaDeliveryAdapter]) -> None:
        self._adapters: dict[str, MediaDeliveryAdapter] = {}
        for adapter in adapters:
            if adapter.provider in self._adapters:
                raise ValueError(f"adapter duplicado: {adapter.provider}")
            self._adapters[adapter.provider] = adapter

    def validate_asset(self, provider: str, asset_id: str) -> None:
        adapter = self._adapters.get(provider)
        if adapter is None:
            raise ValueError("provider de mídia não suportado")
        adapter.validate_asset_id(asset_id)

    def playback_url(
        self,
        *,
        provider: str,
        asset_id: str,
        settings: Settings,
    ) -> str | None:
        adapter = self._adapters.get(provider)
        if adapter is None:
            return None
        try:
            adapter.validate_asset_id(asset_id)
            target = adapter.resolve(asset_id, settings)
            if target is None:
                return None
            return _validate_delivery_target(target, settings)
        except (RuntimeError, ValueError):
            return None


DEFAULT_MEDIA_DELIVERY = MediaDeliveryRegistry(
    [
        YouTubeDeliveryAdapter(),
        CloudflareStreamDeliveryAdapter(),
        ExternalHlsDeliveryAdapter(),
    ]
)


def _validate_compact_asset_id(asset_id: str) -> None:
    if not _ASSET_ID.fullmatch(asset_id):
        raise ValueError("provider_asset_id inválido")


def _validate_delivery_target(url: str, settings: Settings) -> str:
    parsed = urlsplit(url)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or _is_forbidden_host(parsed.hostname)
    ):
        raise ValueError("destino de mídia deve usar host público HTTPS")
    _validate_port(parsed)

    public_api_base = settings.resolved_public_api_base_url()
    if public_api_base is not None:
        api_host = (urlsplit(public_api_base).hostname or "").lower().rstrip(".")
        if api_host and parsed.hostname.lower().rstrip(".") == api_host:
            raise ValueError("a API/VPS não pode ser usada como CDN de mídia")
    return url


def _validate_port(parsed: object) -> None:
    try:
        getattr(parsed, "port")
    except ValueError as exc:
        raise ValueError("porta de entrega inválida") from exc


def _is_forbidden_host(host: str) -> bool:
    normalized = host.lower().rstrip(".")
    if (
        normalized in _DRIVE_HOSTS
        or normalized.endswith(".googleusercontent.com")
        or normalized == "googleusercontent.com"
        or normalized == "localhost"
        or normalized.endswith(_INTERNAL_SUFFIXES)
        or "." not in normalized
    ):
        return True
    try:
        ipaddress.ip_address(normalized)
    except ValueError:
        return False
    return True
