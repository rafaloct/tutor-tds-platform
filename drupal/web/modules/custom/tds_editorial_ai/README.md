# Bounded editorial adapter — #208

IMPLEMENTED candidate, disabled by default. This module is not in config/sync,
not enabled by the pilot recipe, and has no CKEditor/UI integration. Installing
contrib AI is not required. No model has been called by this implementation work.

## Contract

`POST /tds/editorial-ai/suggest/{node}` accepts only JSON `{action, selection}`.
The saved node must be `tds_news` or `tds_faq`; the authenticated Drupal editor
needs `request tds editorial suggestions`, node update access and body edit
access. Routing requires `X-CSRF-Token` validated by Drupal's request header
CSRF checker. The controller independently enforces permission, authentication,
entity/field access, POST, enabled flag and payload boundaries.

Actions: `summarize`, `spell_fix`, `tone`; nonempty UTF-8 selection up to 4000
characters; JSON body up to 24576 bytes. Only the selection and server-owned
instruction are sent. The node body is not loaded into the prompt. Selecting
text is an explicit caller action; this endpoint does not prove that text is
PII-free or that it came from the saved body. Browser selection/privacy proof
remains pending until UI integration.

Returns JSON `proposed_text` with private/no-store/nosniff headers. Never saves,
publishes or renders generated HTML. Future UI must show a proposal as text,
require manual acceptance, and keep original text after failure. Existing
editorial workflow is unchanged.

## Transport and credentials

Only injected Guzzle HTTP is used, with a fixed OpenRouter HTTPS endpoint and
`google/gemini-2.5-flash-lite`, max_tokens512, streamfalse, no tools/history,
timeout15s, connect_timeout3s, TLS verification, redirects disabled and one
request without adapter retry. The shared HTTP client's middleware must also
be reviewed before activation: a site-wide retry/logging middleware could
change behavior outside this adapter. Prove the effective HTTP handler and its
total deadline: a stream handler may not enforce a total wall-clock15s deadline
across body reads. Handler/deadline verification is an activation blocker.
Content-Length and progress callbacks
abort downloads above32KiB; parsing also checks size and schema. Compression
decoding is disabled to avoid unbounded decompression. Transport may deliver
one chunk beyond the threshold before the progress callback aborts.

Credential `TDS_EDITORIAL_OPENROUTER_API_KEY` is read server-side only when a
validated, authorized request has reserved an attempt. No key field, value or
reference is exposed to the browser or config export. Constructor has no side
effects. Missing/malformed key fails closed. Tests use a synthetic environment
key and in-memory transport with network disabled; never run those tests in a
process holding real credentials.

No prompt/response/error text is logged by this module. Upstream exceptions are
replaced without chaining. Success retains only proposed text; usage/cost
telemetry is not implemented. Remote provider retention and spending controls
must be configured and approved separately before a real call.

## Quota and concurrency

Global Drupal lock `tds_editorial_ai.inference`, lease60s, covers both Flood
check/register and the provider call. The limit is10 reserved attempts per
authenticated editor per3600s. Reserve happens before provider execution;
failed calls count and are not refunded. Contention returns429 without waiting;
finally releases the slot, including upstream failures. Lock/storage failures
are sanitized; failed release leaves recovery to lease expiry.

The15s transport timeout is below the60s lease. This is a bounded lease policy,
**not proof of absolute concurrency exclusion** after long process suspension,
lock expiry/loss or database outage. Multi-process database-backed testing and
operational treatment of lease loss remain activation blockers. A future real
deployment must not infer strict single-flight behavior from the unit fake.

## Verification and remaining gates

Unit tests use mocks/fakes for HTTP, entities, config, account, quota, lock and
Flood. They cover fixed transport payload, Unicode limits, authorization,
missing credential, direct request constraints, quota ordering/contention,
11th attempt, exception privacy and lock release failure. They never call AI.
Browser route and CSRF checks, multi-process quota, existing body
selection-only UX and upstream retention/spending configuration are separate
gates. Disabled flag does not itself constitute an activation review.

Local fixture evidence: PHP8.3.29 / Drupal11.4.8, network disabled, SQLite
in-memory kernel database: **12 tests /249 assertions PASS**, PHPCS12 files PASS.
Two kernel tests verify real container wiring/defaultoff and compiled route
access checks (valid/missing/invalid CSRF, permission and entity denial).
They use synthetic account/entity doubles; they do not prove browser login,
real saved-node ownership or multi-process concurrency. The same03dec58 candidate
also passed12 tests/249 assertions on the isolated VPS fixture with
Drupal11.4.10/PHP8.3.35, SQLite and network disabled. No academic gateway is enabled
in this fixture. Test command from drupal directory:

```sh
vendor/bin/phpunit \
  -c phpunit.xml.dist web/modules/custom/tds_editorial_ai/tests
vendor/bin/phpcs web/modules/custom/tds_editorial_ai
```

Rollback: leave module disabled, or set `tds_editorial_ai.settings:enabled=false`
and remove assigned permission. No content/schema migration or academic changes.

The kernel class forces SQLite memory in its separate PHP process, so the
suite mysql default does not require an external database for these tests.
