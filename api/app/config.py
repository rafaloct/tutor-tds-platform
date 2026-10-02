from __future__ import annotations

import os
from dataclasses import dataclass
from urllib.parse import unquote, urlsplit


@dataclass(frozen=True)
class Settings:
    database_url: str
    allowed_origins: tuple[str, ...]
    jwt_secret: str | None = None
    cpf_pepper: str | None = None
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    google_sheet_id: str | None = None
    google_sheet_range: str = "EventosAPI!A:J"
    google_service_account_json: str | None = None
    google_service_account_file: str | None = None
    sync_batch_size: int = 100
    sync_poll_seconds: int = 30
    sync_max_attempts: int = 3
    sync_lease_seconds: int = 300
    certificate_verification_url_prefix: str | None = None
    cloudflare_stream_delivery_base_url: str | None = None
    commercial_simulation_enabled: bool = False
    payment_adapter: str = "disabled"
    sheets_pseudonym_secret: str | None = None
    public_api_base_url: str | None = None
    chatwoot_identity_secret: str | None = None
    chatwoot_identity_namespace: str | None = None
    certificate_approval_required: bool = False
    learning_context_enabled: bool = False
    journey_traceability_enabled: bool = False
    environment: str = "development"

    @classmethod
    def from_environment(cls) -> "Settings":
        environment = os.getenv("TUTOR_ENVIRONMENT", "development").strip().lower()
        if environment not in {"development", "staging", "production"}:
            raise RuntimeError("TUTOR_ENVIRONMENT deve ser development, staging ou production.")
        database_url = os.getenv("DATABASE_URL")
        if environment in {"staging", "production"} and not database_url:
            raise RuntimeError("DATABASE_URL PostgreSQL é obrigatória em staging e production.")
        origins = tuple(
            item.strip()
            for item in os.getenv("ALLOWED_ORIGINS", "").split(",")
            if item.strip()
        )
        settings = cls(
            database_url=database_url or "sqlite+pysqlite:///./tutor_tds_local.db",
            environment=environment,
            allowed_origins=origins,
            jwt_secret=os.getenv("JWT_SECRET"),
            cpf_pepper=os.getenv("CPF_PEPPER"),
            access_token_minutes=int(os.getenv("ACCESS_TOKEN_MINUTES", "15")),
            refresh_token_days=int(os.getenv("REFRESH_TOKEN_DAYS", "30")),
            google_sheet_id=os.getenv("GOOGLE_SHEET_ID"),
            google_sheet_range=os.getenv(
                "GOOGLE_SHEET_RANGE", "EventosAPI!A:J"
            ),
            google_service_account_json=os.getenv(
                "GOOGLE_SERVICE_ACCOUNT_JSON"
            ),
            google_service_account_file=os.getenv(
                "GOOGLE_SERVICE_ACCOUNT_FILE"
            ),
            sync_batch_size=int(os.getenv("SYNC_BATCH_SIZE", "100")),
            sync_poll_seconds=int(os.getenv("SYNC_POLL_SECONDS", "30")),
            sync_max_attempts=int(os.getenv("SYNC_MAX_ATTEMPTS", "3")),
            sync_lease_seconds=int(os.getenv("SYNC_LEASE_SECONDS", "300")),
            certificate_verification_url_prefix=os.getenv(
                "CERTIFICATE_VERIFICATION_URL_PREFIX"
            ),
            cloudflare_stream_delivery_base_url=os.getenv(
                "CLOUDFLARE_STREAM_DELIVERY_BASE_URL"
            ),
            commercial_simulation_enabled=os.getenv(
                "COMMERCIAL_SIMULATION_ENABLED", "false"
            ).lower()
            in {"1", "true", "yes"},
            payment_adapter=os.getenv("PAYMENT_ADAPTER", "disabled"),
            sheets_pseudonym_secret=os.getenv("SHEETS_PSEUDONYM_SECRET"),
            public_api_base_url=os.getenv("PUBLIC_API_BASE_URL"),
            chatwoot_identity_secret=os.getenv("CHATWOOT_IDENTITY_SECRET"),
            chatwoot_identity_namespace=os.getenv("CHATWOOT_IDENTITY_NAMESPACE"),
            certificate_approval_required=os.getenv("CERTIFICATE_APPROVAL_REQUIRED", "false").lower() in {"1", "true", "yes"},
            learning_context_enabled=os.getenv("LEARNING_CONTEXT_ENABLED", "false").lower() in {"1", "true", "yes"},
            journey_traceability_enabled=os.getenv("JOURNEY_TRACEABILITY_ENABLED", "false").lower() in {"1", "true", "yes"},
        )
        settings.validate_database_url()
        return settings

    def validate_database_url(self, url: str | None = None) -> None:
        if self.environment not in {"staging", "production"}:
            return
        parsed = urlsplit(url or self.database_url)
        host = (parsed.hostname or "").lower()
        if (
            parsed.scheme not in {"postgres", "postgresql", "postgresql+psycopg"}
            or not parsed.username
            or not parsed.password
            or not parsed.path.strip("/")
            or host in {"localhost", "127.0.0.1", "::1", "10.0.2.2"}
            or host.endswith(".local")
            or (self.environment == "production" and ("staging" in host or "lgtphbbpgqnzduhtyate" in host))
            or (self.environment == "staging" and host == "db")
        ):
            raise RuntimeError("DATABASE_URL exige PostgreSQL persistente do ambiente, fora de SQLite/localhost.")

    def require_auth_secrets(self) -> tuple[str, str]:
        if not self.jwt_secret or len(self.jwt_secret) < 32:
            raise RuntimeError("JWT_SECRET deve ter pelo menos 32 caracteres.")
        if not self.cpf_pepper or len(self.cpf_pepper) < 32:
            raise RuntimeError("CPF_PEPPER deve ter pelo menos 32 caracteres.")
        self.resolved_public_api_base_url()
        return self.jwt_secret, self.cpf_pepper

    def resolved_public_api_base_url(self) -> str | None:
        """Return a canonical public base without trusting proxy request headers."""
        if self.public_api_base_url is None or not self.public_api_base_url.strip():
            return None
        value = self.public_api_base_url.strip()
        parsed = urlsplit(value)
        try:
            parsed.port
        except ValueError as exc:
            raise RuntimeError("PUBLIC_API_BASE_URL possui porta inválida.") from exc
        decoded_path = unquote(parsed.path)
        invalid_path = (
            "\\" in decoded_path
            or "//" in decoded_path
            or any(part in {".", ".."} for part in decoded_path.split("/"))
            or any(ord(character) < 32 for character in decoded_path)
        )
        if (
            any(character.isspace() or ord(character) < 32 for character in value)
            or "\\" in value
            or parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
            or parsed.query
            or parsed.fragment
            or invalid_path
        ):
            raise RuntimeError(
                "PUBLIC_API_BASE_URL deve ser uma base HTTPS canônica, sem "
                "credenciais, query, fragmento ou segmentos relativos."
            )
        return value.rstrip("/")
