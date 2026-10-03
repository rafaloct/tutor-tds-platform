# WP-2 local staging boundary

This directory contains PHP behavioral tests with explicit WordPress doubles:
php -n wordpress/staging/tests/test-wp2-foundation.php

Windows wrapper tests/test-wp2-foundation.ps1 -Php <php.exe> also lints.
It replaces the earlier regex-only check, which was not runtime proof.

For real local core integration, use PowerShell 7:

    ./wordpress/staging/tests/setup-wp2-local.ps1 -Php <portable-php.exe> -Destination <new-qa-directory>

The runner downloads pinned official WordPress/SQLite packages outside the repo,
verifies integrity, creates synthetic accounts, blocks WordPress HTTP and mail,
tests real REST/settings and briefly serves only 127.0.0.1:18742 for admin tests.
It stops its process and preserves the disposable directory for inspection.
Use a fresh directory; never supply an existing site or production configuration.
See WP2_FOUNDATION_CONTRACT.md for checksums, results and SQLite limits.

No external staging environment, domain, analytics, support inbox or upstream
API is configured. Staging is UNKNOWN.
Future staging must isolate DB/uploads, use synthetic/editorial content,
SMTP sink and noindex, preserve the legacy quarantine and prove reversibility.
Theme validation and MySQL/external staging remain separate gates; no deploy or
external provisioning occurs in this slice.
