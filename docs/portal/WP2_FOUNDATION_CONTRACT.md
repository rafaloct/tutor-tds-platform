# WP-2 — Foundation contract

Status: **IMPLEMENTED / TESTED-LOCAL** for PHP contract tests and a disposable
WordPress 7.1.2 / SQLite integration. External staging remains **UNKNOWN**. Issue #42
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

Additional explicit public options (empty by default): tds_ga4_measurement_id,
tds_public_api_base_url and tds_support_base_url. get() exposes corresponding
ga4_measurement_id, public_api_base_url and support_base_url. Configuring them
never activates integrations, network calls or scripts. Base URLs additionally
reject query/fragment. No arbitrary options bag, token, inbox or widget secret
is supported. Real legacy values are not imported. Future adapter configuration
requires its own reviewed public schema.

The GA4 check accepts G- followed by 6–20 uppercase letters/digits, a local
conservative input bound, not proof that a stream exists. Google's public
[measurement-ID description](https://support.google.com/analytics/answer/12270356?hl=en)
specifies G- plus letters/numbers. Collection remains disabled.

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
65 behavioral assertions on PHP 8.4.26 NTS Windows, real lint on eight PHP files,
and git diff --check.

Run: php -n wordpress/staging/tests/test-wp2-foundation.php
PowerShell wrapper additionally lints and accepts -Php <php.exe>.
Explicit doubles cover hooks, REST responses, settings registration and
sanitizers. They do **not** prove real core behavior. Separate local integration
below proves the bounded core/HTTP cases. Neither suite proves browser rendering,
DNS, upstream availability, persistent caching, theme/accessibility or staging.
CI WordPress portal foundation / php-contract
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

## Disposable real WordPress integration

The separate setup-wp2-local.ps1 runner requires PHP with pdo_sqlite, sqlite3,
openssl and mbstring, plus a **new** destination outside the repository. It
rejects an existing destination, downloads pinned official packages, verifies
archives and file manifests, generates its own synthetic configuration and
creates a QA marker before loading core. Never point it at an existing site.
test-wp2-wordpress.php rejects a missing marker before wp-load and verifies
local environment/loopback URL/SQLite after boot.

WordPress 7.1.2: official wordpress.org/wordpress-7.1.2.zip, SHA256
8fc96c59a78b7219e4a130222b7fadb51b03e503e8b0123beaa7e28961c21ce2.
3,782 core files matched the official core/checksums/1.0 manifest (MD5).
SQLite Database Integration 3.0.2: official downloads.wordpress.org plugin ZIP,
SHA256 1602e75577ad9b3a7e3e4a6a44a81b9541cdee2124d48928faf61c6fd3cd4f74;
45 files matched the official plugin-checksums manifest (SHA256).

Observed local results: 20 core assertions (real REST dispatch/defaults/invalid
pagination/methods, sanitizer/options, inactive integrations, capability/nonce
primitives, HTTP/mail isolation), two assertions of persistence in a new PHP
process, seven HTTP assertions through real wp-login.php and options.php.
The HTTP cases prove admin nonce save, invalid nonce 403, subscriber 403,
unchanged persisted value after denial and real save-path URL sanitization.
The listener binds only 127.0.0.1:18742 and is stopped in finally.

WP_HTTP_BLOCK_EXTERNAL, pre_http_request, DISABLE_WP_CRON and disabled updates
prevent WordPress HTTP activity; pre_wp_mail is a discard sink, not an SMTP
delivery test. This is application-level isolation, not an OS network sandbox.
No production credentials or content are read. QA archives/core/SQLite files
stay outside Git. No MySQL, browser visual/accessibility, external staging,
provider integration or deployment is proven by this local SQLite experiment.

Initial CLI harness failure: admin_init called without core template.php,
causing undefined add_settings_field. The harness now loads real admin template
functions first. This was a harness setup defect, not a plugin production fix.
