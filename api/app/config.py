from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str
    allowed_origins: tuple[str, ...]
    jwt_secret: str | None = None
    cpf_pepper: str | None = None
    access_token_minutes: int = 15
    refresh_token_days: int = 30

    @classmethod
    def from_environment(cls) -> "Settings":
        origins = tuple(
            item.strip()
            for item in os.getenv("ALLOWED_ORIGINS", "").split(",")
            if item.strip()
        )
        return cls(
            database_url=os.getenv(
                "DATABASE_URL",
                "sqlite+pysqlite:///./tutor_tds_local.db",
            ),
            allowed_origins=origins,
            jwt_secret=os.getenv("JWT_SECRET"),
            cpf_pepper=os.getenv("CPF_PEPPER"),
            access_token_minutes=int(os.getenv("ACCESS_TOKEN_MINUTES", "15")),
            refresh_token_days=int(os.getenv("REFRESH_TOKEN_DAYS", "30")),
        )

    def require_auth_secrets(self) -> tuple[str, str]:
        if not self.jwt_secret or len(self.jwt_secret) < 32:
            raise RuntimeError("JWT_SECRET deve ter pelo menos 32 caracteres.")
        if not self.cpf_pepper or len(self.cpf_pepper) < 32:
            raise RuntimeError("CPF_PEPPER deve ter pelo menos 32 caracteres.")
        return self.jwt_secret, self.cpf_pepper
