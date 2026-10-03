# WP-2 — Foundation contract

Status: **IMPLEMENTED / TESTED-LOCAL (contract/static checks)**. This document
describes the reversible local foundation only; no WordPress staging or
production integration was performed.

## Boundary

`wordpress/tds-portal-core/` is a public, read-only portal adapter. FastAPI is
the authority for the public course projection. WordPress must never query the
Tutor database, infer enrollment/progress, or receive PII, credentials, or
academic authority.

## Configuration

`TDS_Public_Config` is the single public configuration boundary. The only
WordPress option introduced by this slice is `tds_app_access_url`. It accepts
an HTTPS URL and returns an empty value for invalid input. Analytics and
support are `disabled` by default. Course integration is `unavailable` until
an approved upstream adapter is supplied.

Allowed integration states are `disabled`, `unavailable`, `ready`, and `error`.
The response always exposes `integration_state` semantics through the adapter
result; an unavailable/error response is explicit and user-safe.

## `/public/courses` adapter

`TDS_Courses_Adapter_Interface` is the seam for the approved read-only API.
`TDS_Fake_Courses_Adapter` is the offline-first implementation for local work:
it is deterministic, returns no records or identifiers, and caches the result
for repeated reads in a process. It performs no network request. An upstream
adapter can be introduced in a later authorized slice without changing the
controller contract.

The local REST route is `GET /wp-json/tds-portal/v1/public/courses` and returns
HTTP 503 with `state=unavailable`, or HTTP 502 with `state=error`. This is a
placeholder/fallback, not evidence that staging or the API endpoint is live.

## Disabled integrations and safety

No analytics hooks, support calls, direct DB access, secrets, or PII are
implemented. Public course payloads are the only supported data shape. The
staging directory contains only reproducibility notes; staging remains
`UNKNOWN` until an authorized environment exists and is tested.
