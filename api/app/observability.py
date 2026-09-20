from __future__ import annotations

import json
import logging
import re
import time
from uuid import uuid4

from fastapi import FastAPI, Request, Response

LOGGER = logging.getLogger("tutor_tds.http")
REQUEST_ID = re.compile(r"^[A-Za-z0-9_.-]{8,80}$")


def install_observability(application: FastAPI) -> None:
    @application.middleware("http")
    async def request_metrics(request: Request, call_next) -> Response:
        supplied = request.headers.get("X-Request-ID", "")
        request_id = supplied if REQUEST_ID.fullmatch(supplied) else uuid4().hex
        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            route = request.scope.get("route")
            # O template da rota evita registrar IDs pessoais presentes no path.
            route_path = getattr(route, "path", "unmatched")
            LOGGER.info(
                json.dumps(
                    {
                        "event": "http_request",
                        "request_id": request_id,
                        "method": request.method,
                        "route": route_path,
                        "status": status_code,
                        "duration_ms": round(
                            (time.perf_counter() - started) * 1000, 2
                        ),
                    },
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
