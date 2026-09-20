from __future__ import annotations

import argparse
import getpass
import os

from fastapi import HTTPException
from pydantic import SecretStr
from sqlalchemy.orm import Session

from .auth import AuthService, LoginRequest, RegisterRequest
from .config import Settings
from .database import Database


def ensure_admin(
    session: Session,
    settings: Settings,
    *,
    name: str,
    phone: str,
    cpf: str,
    password: str,
) -> str:
    service = AuthService(session, settings)
    try:
        user = service.authenticate(
            LoginRequest(cpf=SecretStr(cpf), password=SecretStr(password))
        )
    except HTTPException as error:
        if error.status_code != 401:
            raise
        user = service.register(
            RegisterRequest(
                name=name,
                phone=phone,
                cpf=SecretStr(cpf),
                password=SecretStr(password),
            )
        )
    user.role = "admin"
    session.commit()
    return user.id


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Cria ou confirma o primeiro administrador da API."
    )
    parser.add_argument("--name", required=True)
    parser.add_argument("--phone", required=True)
    args = parser.parse_args()
    cpf = os.getenv("BOOTSTRAP_ADMIN_CPF") or getpass.getpass("CPF: ")
    password = os.getenv("BOOTSTRAP_ADMIN_PASSWORD") or getpass.getpass("Senha: ")
    settings = Settings.from_environment()
    database = Database(settings.database_url)
    try:
        with Session(database.engine) as session:
            user_id = ensure_admin(
                session,
                settings,
                name=args.name,
                phone=args.phone,
                cpf=cpf,
                password=password,
            )
    finally:
        database.dispose()
    print(f"Administrador pronto: {user_id}")


if __name__ == "__main__":
    main()
