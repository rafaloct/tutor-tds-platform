# WP-2: local MySQL staging rehearsal

This recipe creates a new disposable WordPress/MySQL installation, with no
connection to an existing site. It is local QA, not an external deployment or
production acceptance. The public plugin/theme contract stays at PR #53 base
`b9028c238c0049b4e728a29ba3a9d6cd9179a28a`.

## Reproduce

PowerShell 7, portable PHP 8.4.26 with mysqli/openssl/mbstring, a fresh directory
without spaces, and two official archives are required:

```powershell
./wordpress/staging/tests/setup-wp2-mysql.ps1 `
  -Php <portable-php.exe> `
  -MySqlArchive <mysql-8.4.11-winx64.zip> `
  -WordPressArchive <wordpress-7.1.2.zip> `
  -Destination <new-disposable-directory>
```

The runner refuses existing destinations, checks archive SHA256, starts its own
MySQL process without installing a Windows service, and stops that process in
finally. It refuses an occupied QA port. Do not adapt the runner to existing
data directories or production configuration. It preserves its QA directory,
logs and backup for inspection; no deletion is required to complete the test.

## Integrity and environment

- MySQL 8.4.11 Windows ZIP: official
  <https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip>;
  SHA256 `a492371d687d2bab088b0062581144a0044b8964baefdf4faa579292b423d25c`.
- Its detached `.zip.asc` signature was checked before executing binaries with
  the key from <https://repo.mysql.com/RPM-GPG-KEY-mysql-2025>, fingerprint
  `BCA43417C3B485DD128EC6D4B7B3B788A8D3785C`. GPG reported a good signature;
  certification trust is not inferred. The reproducible runner pins the checked
  archive hash, and does not modify the user's GPG keyring.
- WordPress 7.1.2 ZIP: <https://wordpress.org/wordpress-7.1.2.zip>;
  SHA256 `8fc96c59a78b7219e4a130222b7fadb51b03e503e8b0123beaa7e28961c21ce2`.
  Core file manifest verification was recorded in WP2_FOUNDATION_CONTRACT.md.
- PHP portable provenance remains in that contract. No binary, core WordPress
  tree, database, generated configuration or backup is committed to Git.

The recipe generates synthetic local credentials, starts MySQL on
127.0.0.1:13342 only, disables MySQL X protocol, creates wp2_qa and wp2_restore,
and grants the WordPress account access only to those two disposable databases.
The empty initial root credential is restricted to this transient local server;
it is not a reusable staging/production credential design.

WordPress is local with noindex (`blog_public=0`), isolated uploads, no scheduled
cron/automatic updates, all WordPress HTTP intercepted and mail discarded before
delivery. Analytics/support remain disabled and courses unavailable. This is
WordPress-level egress control, not an OS network sandbox. No HTTP web listener
is needed for this MySQL slice; earlier real admin HTTP tests retain their scope.

## Recovery boundary

The runner writes a synthetic editorial page and public settings, takes a
transactional mysqldump of wp2_qa, and imports it into the separate initially
empty wp2_restore database. A new PHP process uses that restored database and
checks the public settings, editorial marker and unavailable catalog route.
It backs up a synthetic uploads marker to a separate directory and verifies
the restored marker's SHA256. No original database is dropped or overwritten.

Deactivation is exercised on the restored database. A subsequent PHP process
checks that the plugin class and route are absent while public options remain
inert; reactivation and another fresh PHP process prove recovery of the route
and configuration. Plugin code and its public contract are unchanged.

This does not prove a production-sized restore, external backup transport,
scheduled recovery, real providers, browser accessibility, theme completeness,
DNS/TLS or a deployed staging service. Those retain their separate gates.

## Observed result — 2026-10-03

**TESTED-LOCAL**: the fresh-directory recipe completed with exit 0 on Windows,
PHP 8.4.26, WordPress 7.1.2 and MySQL Community 8.4.11. Forty-three assertions
passed: seed 11, restored database 10, deactivate 5, inactive restart 7,
reactivated restart 10. mysqldump/import succeeded and the upload marker SHA256
matched `11f8d43f01ca459e70b6c83952a777cc5634a45c5069d1685be76604c565a826`.
The MySQL log records shutdown completion and port 13342 has no listener after
the recipe. The two new harnesses passed PHP lint/PowerShell parsing and diffcheck.

An initial runner initialization failed because PowerShell did not construct
the basedir/log-error arguments as complete strings. Corrected quoting was
tested in a new directory; the original failed directory was preserved.
The earlier 65 double assertions and 29 SQLite/core/HTTP assertions were not
rerun for this independent MySQL extension. CI may rerun its own focal job.
