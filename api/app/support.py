"""Authenticated identity for the existing Chatwoot website widget."""
import hashlib
import hmac
import re

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from .auth import access_claims

router = APIRouter(prefix="/support", tags=["support"])


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
