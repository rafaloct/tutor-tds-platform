# WP-2 local staging boundary

This directory contains PHP behavioral tests with explicit WordPress doubles,
not a running WordPress installation. Run:
php -n wordpress/staging/tests/test-wp2-foundation.php

Windows wrapper tests/test-wp2-foundation.ps1 -Php <php.exe> also lints.
It replaces the earlier regex-only check, which was not runtime proof.

No WordPress staging environment, domain, database, credentials, analytics,
support inbox or upstream API is configured. Staging is UNKNOWN.
Future staging must isolate DB/uploads, use synthetic/editorial content,
SMTP sink and noindex, preserve the legacy quarantine and prove reversibility.
Theme validation and actual WordPress REST/settings integration are separate
gates; no deploy or external provisioning occurs in this slice.
