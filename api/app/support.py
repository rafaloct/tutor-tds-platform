"""Public widget configuration and authenticated Chatwoot identity."""
import hashlib
import hmac
import re

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict

from .auth import access_claims

router = APIRouter(prefix="/support", tags=["support"])
NO_STORE = {"Cache-Control": "no-store", "Pragma": "no-cache"}


class SupportWidgetConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")
    base_url: str
    website_token: str


@router.get(
    "/config",
    response_model=SupportWidgetConfig,
    responses={503: {"description": "Configuração pública do suporte ausente ou inválida."}},
)
def support_config(request: Request, response: Response) -> SupportWidgetConfig:
    """The website token is public; never return admin/HMAC credentials."""
    try:
        base_url, website_token = request.app.state.settings.resolved_chatwoot_widget_config()
    except ValueError:
        raise HTTPException(
            status_code=503,
            detail="Configuração do suporte indisponível.",
            headers=NO_STORE,
        ) from None
    response.headers.update(NO_STORE)
    return SupportWidgetConfig(base_url=base_url, website_token=website_token)


@router.get("/identity")
def support_identity(
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, str]:
    settings = request.app.state.settings
    secret = settings.chatwoot_identity_secret
    namespace = settings.chatwoot_identity_namespace
    if not secret or not namespace or not re.fullmatch(r"[a-z0-9-]{1,64}", namespace):
        raise HTTPException(503, "Identificação do suporte indisponível.")
    # The caller never supplies the target identity. No CPF/phone/profile data.
    identifier = f"{namespace}:{claims['sub']}"
    signature = hmac.new(secret.encode(), identifier.encode(), hashlib.sha256).hexdigest()
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    return {"identifier": identifier, "identifier_hash": signature}
