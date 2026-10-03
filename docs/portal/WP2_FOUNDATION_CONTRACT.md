# WP-2 — Foundation contract

Status: **IMPLEMENTED / TESTED-LOCAL** for the PHP contract with WordPress
doubles. Real WordPress integration and staging remain **UNKNOWN**. Issue #42
also requires theme, pages, accessibility and staging; this slice does not
complete that issue.

## Ownership

User confirmed Windsurf is not executing #42 yet. Ownership remains:
- Codex: wordpress/tds-portal-core/**, wordpress/staging/**, this contract,
  adapters, configuration, cache, security and plugin tests.
- Windsurf (future confirmed dispatch): wordpress/tds-child-theme/**,
  design system, header/footer, patterns, responsiveness and accessibility.
- Root Codex integrator: wordpress/README.md, shared workflows and final evidence.
  The integrator delegated only the new wp-portal-foundation.yml to this writer.

No shared file receives simultaneous writers. A future theme dispatch must
reference the reviewed plugin SHA and this contract; publication is not proof
that Windsurf started.

## Public boundary and configuration

FastAPI owns the published course projection. WordPress receives public
editorial fields only, never enrollment/progress or Tutor database access.
Bootstrap uses the offline fake without fixtures, always unavailable. No HTTP
client, real provider, automatic activation or legacy runtime is introduced.

TDS_Public_Config::get() is the theme contract. Its app_access_url comes only
from tds_app_access_url; integration_state.app is ready only with a validated
URL. Configure under native **Settings → General**, using WordPress's existing
capability/nonce/save handling. The field requires manage_options and the option
is not exposed through REST settings. Invalid/empty input clears the link.
Analytics/support remain disabled; courses unavailable. Theme output must escape
URLs/text for its HTML context.

Local URL validation accepts HTTPS public-looking hosts, no credentials,
control characters, backslashes, private/reserved IP literals, private host
suffixes or nonstandard ports. Store query strings are allowed. This validates
syntax, not institutional ownership or DNS. It performs no network requests
and is **not** an SSRF boundary for a future HTTP client. Administrators choose
the official destination. A future network adapter must validate resolved
targets and redirects independently.

## Catalog contract

GET /wp-json/tds-portal/v1/public/courses?page=1&per_page=12 exposes exactly:
- state: ready, unavailable, disabled or error;
- courses: validated public records, always empty outside ready;
- pagination: page, per_page (1–50), total;
- error: null when ready, otherwise generic code/message without diagnostics.

HTTP is 200 for ready (including valid empty), 503 for unavailable/disabled and
502 for error. WordPress REST schema rejects invalid pagination; direct service
callers are clamped. Required public fields: slug, title, published status,
published_version_label, updated_at. Optional: summary, cover_public_url,
public_workload_text, public_audience_text. Cover URLs prohibit query/fragment.
Extra fields are discarded. Invalid records invalidate the whole response;
exceptions produce a generic error without partial records or diagnostics.

Fake fixtures must be synthetic and are constructor-only; bootstrap never
supplies them. Repeated reads use an object-local page/size cache discarded at
request end. No persistent/stale cache exists. WP-5 must map API offset/limit to
portal pagination and provide explicit expiry/invalidation for a real provider.

## Evidence and limits (2026-10-03)

Base 1a577a6e9417772753beb1525e25757f4e97b7ea; original head
babd4f68d027394b5ebf44ffffea749298f8609d. Its static/regex claim is superseded by
51 behavioral assertions on PHP 8.4.26 NTS Windows, real lint on seven PHP files,
and git diff --check.

Run: php -n wordpress/staging/tests/test-wp2-foundation.php
PowerShell wrapper additionally lints and accepts -Php <php.exe>.
Explicit doubles cover hooks, REST responses, settings registration and
sanitizers. They do **not** prove core WordPress routing/authentication/nonce
persistence, browser rendering, DNS, upstream availability, real caching,
theme/accessibility or staging. CI WordPress portal foundation / php-contract
runs these tests; legacy quarantine / verify checks only the historical snapshot.

Portable PHP provenance: official metadata
<https://downloads.php.net/~windows/releases/releases.json>; archive
php-8.4.26-nts-Win32-vs17-x64.zip, SHA256
da68394f9193b7f6b89d0c76861a4034ae10efee7fd55a7255d8118c2acf70d7,
verified before execution outside the repository. No binary is committed.

Rollback after a future authorized installation: deactivate the plugin; its
public link option may remain inert. No migration, secrets, deploy, AAB or
production change. Independent review and merge remain gates; staging remains
UNKNOWN until an authorized isolated environment is tested.
