from __future__ import annotations

import json
import logging
import re
import time
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import FastAPI, Request, Response

LOGGER = logging.getLogger("uvicorn.error")
REQUEST_ID = re.compile(r"^[A-Za-z0-9_.-]{8,80}$")


def install_observability(application: FastAPI) -> None:
    @application.middleware("http")
    async def request_metrics(request: Request, call_next) -> Response:
        supplied = request.headers.get("X-Request-ID", "")
        request_id = supplied if REQUEST_ID.fullmatch(supplied) else uuid4().hex
        request.state.request_id = request_id
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
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "request_id": request_id,
                        "trace_id": getattr(request.state, "trace_id", None),
                        "method": request.method,
                        "route": route_path,
                        "status": status_code,
                        "attempt": getattr(request.state, "attempt", None),
                        "result": (
                            "created" if status_code == 201 else
                            "accepted" if status_code < 400 else
                            "rejected" if status_code < 500 else "error"
                        ),
                        "error": (
                            None if status_code < 400 else
                            "client_error" if status_code < 500 else "server_error"
                        ),
                        "duration_ms": round(
                            (time.perf_counter() - started) * 1000, 2
                        ),
                    },
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
