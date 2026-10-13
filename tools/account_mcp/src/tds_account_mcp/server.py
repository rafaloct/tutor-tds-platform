from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
from typing import Literal

import httpx
from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations
from pydantic import BaseModel, ConfigDict, Field, SecretStr, ValidationError

URLS = {
    "staging": "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api",
    "production": "https://ead.ipexdesenvolvimento.cloud/tutor-api",
}
Role = Literal["student", "teacher", "monitor", "creator", "coordinator",
               "program_operator", "finance", "admin"]


class Account(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=2, max_length=240)
    cpf: SecretStr
    phone: str = Field(min_length=10, max_length=32)
    password: SecretStr
    role: Role
    program_id: str = Field(min_length=1, max_length=36)


class AccountResult(BaseModel):
    # Explicit allowlist: upstream extensions cannot expose credentials.
    id: str
    name: str
    role: Role
    program_id: str
    membership_status: str


def private_read(path: Path) -> bytes:
    try:
        if path.is_symlink() or not path.is_file():
            raise ValueError
        if os.name == "posix" and path.stat().st_mode & 0o077:
            raise ValueError
        if path.stat().st_size > 16_384:
            raise ValueError
        return path.read_bytes()
    except (OSError, ValueError):
        raise ValueError("Arquivo privado ausente, excessivo ou sem proteção de acesso.") from None


class Accounts:
    def __init__(self, environment: str, inbox: Path, receipts: Path,
                 token_file: Path, *, production_enabled: bool = False,
                 transport: httpx.AsyncBaseTransport | None = None):
        if environment not in URLS:
            raise ValueError("Ambiente deve ser staging ou production.")
        if environment == "production" and not production_enabled:
            raise ValueError("Produção requer TDS_MCP_PRODUCTION_ENABLED=true no host.")
        self.environment = environment
        self.inbox = inbox.resolve()
        self.receipts = receipts.resolve()
        self.token_file = token_file
        self.transport = transport
        self.receipts.mkdir(parents=True, exist_ok=True, mode=0o700)
        if os.name == "posix" and self.receipts.stat().st_mode & 0o077:
            raise ValueError("Diretório de recibos precisa ser privado (0700).")

    def load(self, request_id: str) -> tuple[Account, str]:
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", request_id):
            raise ValueError("request_id inválido.")
        raw = private_read(self.inbox / f"{request_id}.json")
        try:
            account = Account.model_validate_json(raw)
        except ValidationError:
            raise ValueError("Cadastro inválido; confira o arquivo privado no host.") from None
        # Digest binds approval to bytes AND the selected environment.
        digest = hashlib.sha256(self.environment.encode() + b"\0" + raw).hexdigest()
        return account, digest

    def preview(self, request_id: str) -> dict:
        account, digest = self.load(request_id)
        return {"request_id": request_id, "environment": self.environment,
                "name": account.name, "role": account.role,
                "program_id": account.program_id, "approval_digest": digest}

    async def create(self, request_id: str, approval_digest: str) -> dict:
        account, digest = self.load(request_id)
        if approval_digest != digest:
            raise ValueError("Cadastro ou ambiente mudou; execute preview novamente.")
        try:
            token = private_read(self.token_file).decode().strip()
            if not token or any(c.isspace() for c in token):
                raise ValueError
        except (UnicodeError, ValueError):
            raise ValueError("Token administrativo privado ausente ou inválido.") from None
        receipt = self.receipts / f"{request_id}.json"
        # Exclusive persistent reservation precedes the write. Even a crash or an
        # ambiguous timeout cannot cause an automatic second POST for this ID.
        try:
            fd = os.open(receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            raise ValueError("Cadastro já tentado. Confira o recibo local e a API; não repita com outro ID.") from None
        with os.fdopen(fd, "w") as stream:
            json.dump({"state": "unknown", "environment": self.environment,
                       "approval_digest": digest}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        payload = account.model_dump(exclude={"cpf", "password"})
        payload.update(cpf=account.cpf.get_secret_value(), password=account.password.get_secret_value())
        try:
            async with httpx.AsyncClient(transport=self.transport, timeout=30,
                                         follow_redirects=False) as client:
                response = await client.post(URLS[self.environment] + "/admin/accounts",
                    headers={"Authorization": f"Bearer {token}", "User-Agent": "TutorTDS-Account-MCP/1.0"},
                    json=payload)
        except httpx.HTTPError:
            raise ValueError("Resultado incerto; consulte a API antes de qualquer nova tentativa.") from None
        if response.status_code != 201:
            # Do not echo upstream bodies, which may contain submitted PII.
            raise ValueError(f"API retornou HTTP {response.status_code}. Confira a conta antes de tentar novamente.")
        try:
            result = AccountResult.model_validate(response.json()).model_dump()
        except (ValueError, ValidationError):
            raise ValueError("Resposta inesperada; a conta pode ter sido criada. Confira a API.") from None
        if (result["role"], result["program_id"], result["name"], result["membership_status"]) != (
            account.role, account.program_id, account.name, "active"
        ):
            raise ValueError("Resposta divergente; confira a conta na API.")
        # Keep only the safe account projection, never token/CPF/password.
        with receipt.open("w") as stream:
            json.dump({"state": "created", "environment": self.environment,
                       "approval_digest": digest, "account": result}, stream)
        return result


def build_server(accounts: Accounts) -> FastMCP:
    server = FastMCP("Tutor TDS — contas gerenciadas", instructions=(
        "Use apenas cadastros preparados pelo operador. Mostre nome, papel, programa e ambiente "
        "do preview antes de criar. Não crie papéis ou usuários por inferência. "
        "Nunca solicite senha/token no chat. Falha incerta exige consulta humana à API."))

    @server.tool(annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False))
    def preview_account(request_id: str) -> dict:
        """Mostra cadastro privado previamente preparado no host, sem CPF, telefone ou senha."""
        return accounts.preview(request_id)

    @server.tool(annotations=ToolAnnotations(readOnlyHint=False, destructiveHint=True,
                                             idempotentHint=False, openWorldHint=True))
    async def create_account(request_id: str, approval_digest: str) -> dict:
        """Cria UMA conta e vínculo de programa pela API, após revisão do preview pelo operador."""
        return await accounts.create(request_id, approval_digest)

    return server


def main() -> None:
    try:
        accounts = Accounts(os.environ["TDS_MCP_ENVIRONMENT"],
            Path(os.environ["TDS_MCP_INBOX"]), Path(os.environ["TDS_MCP_RECEIPTS"]),
            Path(os.environ["TDS_MCP_TOKEN_FILE"]),
            production_enabled=os.environ.get("TDS_MCP_PRODUCTION_ENABLED") == "true")
    except (KeyError, ValueError):
        raise SystemExit("Configuração MCP inválida; confira ambiente e diretórios privados no host.") from None
    build_server(accounts).run(transport="stdio")


if __name__ == "__main__":
    main()
