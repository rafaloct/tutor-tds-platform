"""Authenticated candidate protocol. No institutional certificate authority.

The injected exchange replaces HTTP only; signing and receipt validation remain real.
An uncertain POST is never repeated: recovery uses authenticated lookup only.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import time
from urllib import request as urlrequest
from urllib.error import HTTPError


def canonical(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


class TransportError(Exception):
    pass


class _NoRedirect(urlrequest.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise TransportError("candidate redirect forbidden")


class CandidateTransport:
    def __init__(self, base_url: str, secret: str, exchange=None):
        self.base_url = base_url.rstrip("/")
        self.secret = secret.encode()
        self.exchange = exchange or self._http

    def _http(self, method, path, body, headers):
        req = urlrequest.Request(self.base_url + path, data=body if method == "POST" else None, headers=headers, method=method)
        try:
            with urlrequest.build_opener(urlrequest.ProxyHandler({}), _NoRedirect()).open(req, timeout=5) as response:
                return response.status, dict(response.headers), response.read(32769)
        except HTTPError as error:
            return error.code, dict(error.headers), error.read(32769)

    def call(self, command: dict, *, issue: bool) -> dict | None:
        method = "POST" if issue else "GET"
        path = "/internal/certificate-candidates/" + command["id"]
        body = canonical(command) if issue else b""
        timestamp = str(int(time.time()))
        digest = hashlib.sha256(body).hexdigest()
        signed = f"candidate-request-v1\n{method}\n{path}\n{timestamp}\n{digest}".encode()
        signature = hmac.new(self.secret, signed, hashlib.sha256).hexdigest()
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "Tutor-TDS-Certificate-Candidate/1.0",
            "X-Candidate-Time": timestamp,
            "X-Candidate-Signature": signature,
        }
        try:
            status, response_headers, raw = self.exchange(method, path, body, headers)
            if len(raw) > 32768:
                raise TransportError("oversized receipt")
            returned_signature = next((v for k, v in response_headers.items() if k.lower() == "x-candidate-signature"), "")
            receipt_input = f"candidate-response-v1\n{method}\n{path}\n{timestamp}\n{status}\n".encode() + raw
            expected = hmac.new(self.secret, receipt_input, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(expected, returned_signature):
                raise TransportError("unauthenticated receipt")
            document = json.loads(raw)
            if status == 404 and document == {"state": "absent"} and not issue:
                return None
            if status != 200 or document.get("state") != "candidate_confirmed":
                raise TransportError("unconfirmed receipt")
            if document.get("command") != command or document.get("content_hash") != hashlib.sha256(canonical(command)).hexdigest():
                raise TransportError("divergent context")
            if document.get("verification_url") != "https://synthetic.invalid/certificate-candidates/" + command["id"]:
                raise TransportError("divergent verification origin")
            return document
        except TransportError:
            raise
        except Exception as error:
            raise TransportError("indeterminate transport") from error
