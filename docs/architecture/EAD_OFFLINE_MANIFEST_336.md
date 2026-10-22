# #336: IPEX offline byte-integrity producer

Status: IMPLEMENTED / TESTED-LOCAL. Base #334
`a0db10254642223dad192326f88d676aaba09553`. No live plugin installation,
real-media metadata writes, Flutter UI activation, identity migration or
academic command is part of this candidate. MERGE_ALLOWED=NO;
PRODUCTION_ALLOWED=NO. Existing public version remains `1.4.1+14`.

## Root cause and contract

The editorial lesson projects a validated MP4 URL, optional VTT and revision,
but `OfflinePackageManifest` needs measured `length` and `sha256`. A source-URL
fingerprint is not a checksum of file bytes. Reuse the existing plugin and strict
Flutter parser instead of adding a download authority, LMS or media service.

`GET|HEAD /wp-json/tds-learning/v1/courses/{course_id}/lessons/{lesson_id}/offline-manifest`
returns the **exact** existing Flutter schema, without extra authority/revision
fields:

```json
{
  "schema_version": 1,
  "course_id": 1356,
  "lesson_id": 1425,
  "mobile_content": true,
  "rights_approved": true,
  "mp4": {"url": "https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/lesson.mp4", "length": 44, "sha256": "<64 lowercase hex>"},
  "vtt": {"url": "https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/lesson.vtt", "length": 37, "sha256": "<64 lowercase hex>"},
  "content_revision": "<64 lowercase hex>"
}
```

The example is synthetic; its MP4 bytes are **not a playable video**. Omit VTT
for an approved MP4-only lesson. `content_revision` binds the editorial lesson
revision, source fingerprint, parent/course and measured asset descriptors.
Strong `ETag` is a digest of the returned JSON; matching strong/weak conditional
GET returns 304 only **after all authorization, revision and file checks**.
`Cache-Control: no-store`, `X-Content-Type-Options: nosniff`. WordPress handles
HEAD through its standard readable route. All unavailable/invalid/stale states
return generic 404 without filesystem paths; no credentials/PII in the payload.

Both IDs must be canonical positive integers ≤100000000. Parent lookup uses the
existing LearnPress section tables, DISTINCT, and requires exactly this one
course. Course and lesson must be published, not password protected; the existing
lesson opt-in and source-bound rights checks are reused. YouTube, drafts,
orphan/shared lessons and unapproved sources are excluded.

## Preparation versus request handling

`TDS_Offline_Manifest::prepare_record(course_id, lesson_id)` is a trusted PHP
preparation helper, **not an HTTP write endpoint or save hook**. It returns an
array or WP_Error and never persists, approves or publishes a lesson. It:

1. Reuses the public editorial lesson and source fingerprint after unique-parent
   checks; it does not read learners, enrollment, quiz answers or certificates.
2. Resolves literal HTTPS IPEX URLs into the existing configured local uploads
   tree. `wp_upload_dir(null, false)` never creates directories. The base URL
   must be the canonical IPEX uploads URL. Encoded/ambiguous paths, traversal,
   queries, fragments, ports, other hosts and extensions fail closed.
3. Requires a normal single-link local file and canonical realpath; rejects
   symlinks at every path component, including links staying inside the tree,
   and rejects hard links. No URL fetch, redirect or remote hash request.
4. Takes a nonblocking shared lock, streams SHA-256 bounded by measured size,
   compares pre/post descriptor and pathname stat. VTT must be UTF-8 WEBVTT
   with no NUL; complete cue/pedagogical validation remains player/content QA.
5. Revalidates editorial context after measurement. Maximum MP4 is 500 MiB
   exclusive (same as Flutter); VTT limit is a deliberately tighter 2 MiB.
   Their sum is therefore within Flutter's 700 MiB exclusive package limit.

A separately authorized operator persists the complete returned record in
`_tds_mobile_offline_integrity_v1` on the lesson. GET only reads that record,
rechecks context, hash shape, URLs, lengths and current file identity
(dev/inode/mode/link-count/size/mtime/ctime), and strips internal stat fields.
It does not hash 500 MB during a request. Missing records keep downloads closed
on installation, so installing code does not publish the corpus.

Filesystem identity is an invalidation check, **not cryptographic attestation of
current bytes**. Metadata timestamps can be coarse; privileged same-second
in-place writes may preserve observable identity. Media must be immutable to the
web/editor process, replaced atomically under a new path/revision by the trusted
ingest operator, then remeasured. Cooperating writers must respect locks. The
client still verifies complete byte length/SHA before atomic installation; a
mismatch fails, never produces a ready package. This candidate does not provide
an adversarial filesystem writer sandbox or ongoing hash daemon.

## Editorial decision

Owner's 22/10 batch approval (Issue #336 comment 6352212752) applies to existing
project-owned media, and supersedes the issue body's historical 48-approval
wording. It does not automatically set metadata or skip technical measurement.
For a later authorized corpus operation, review one batch inventory with stable
course/lesson/source/fingerprint/digest and exceptions; do not seek 48 new
consents. Exclude explicit restricted third-party assets. No batch write is run
by this source candidate.

## Reproducible source verification

From the repository root, with PHP 8.3 and Dart 3.12.2:

```sh
TDS_MANIFEST_OUTPUT=/tmp/tds-server-manifest.json php wordpress/tds-learnpress-editorial/tests/test-offline-manifest.php
php wordpress/tds-learnpress-editorial/tests/test-etag.php
python wordpress/tds-learnpress-editorial/tests/test-etag-http.py
dart wordpress/tds-learnpress-editorial/tests/verify-flutter-manifest.dart /tmp/tds-server-manifest.json
git diff --check
```

The PHP test uses real temporary files/sparse oversize file/links/locks with
WP/LP **stubs**; it is not a live WordPress installation or playable Android
fixture. The Dart check parses server-generated JSON with the unchanged #331
parser, validates counts, round-trip and rejects extra JSON revision fields.
CI extends the existing focal PHP workflow; no new service/workflow is added.
See `docs/audit/product-20261022/qa-evidence.md` for the actual environments and
results, including what has not run.

## Native runtime continuation and remaining institutional staging acceptance

A disposable native WordPress6.7.2/LearnPress4.3.6/MariaDB runtime passed44
assertions with actual HTTP and unchanged plugin source; its native payload also
passed3 checks with the unchanged Dart parser. See
`docs/qa/ead-offline-manifest-runtime-20261022/README.md`. Earlier failures were
retained. Native LP cleanup removes section associations for unpublished posts;
republished orphans stay denied until an authorized editor explicitly reattaches
them and remeasures. Never infer that relationship from prior metadata.
This is TESTED-LOCAL, not institutional staging/browser/Android acceptance.

For institutional acceptance after review, use an authorized disposable WP/LearnPress clone with a synthetic
course, unique lesson and playable MP4/VTT beneath its local uploads tree and
canonical fixture origin. Back up its metadata before installing the exact
plugin source. Set synthetic editorial opt-in/source approval using the existing
editor, then in a trusted WP-CLI/admin preparation process obtain the record:

```php
$record = TDS_Offline_Manifest::prepare_record( $course_id, $lesson_id );
if ( is_wp_error( $record ) ) { throw new RuntimeException( 'Measurement failed' ); }
// Only in the separately authorized clone preparation, never in GET/save hook:
update_post_meta( $lesson_id, TDS_Offline_Manifest::META, $record );
```

Exercise actual REST GET/HEAD/conditional requests; revise lesson or replace
bytes and prove rejection; remeasure and prove new revision; revoke and prove
404 even with old ETag. Test wrong/multiple parents, DB lookup error, protected
course and non-IPEX source. Read back academic tables to prove unchanged. Roll
back clone metadata/plugin and verify original snapshot/hash. A canonical
fixture URL can be mapped inside the isolated test environment; do not redirect
the public service to a synthetic tree.

Then implement the Flutter reader through the existing editorial repository,
validate manifest course/lesson/revision against a trusted response, preserve
its independent authorization callback and keep production fail-closed until
accepted. Test exact QA APK download→hash/atomic ready→airplane mode→kill/reopen→
play/captions→reconnect→revise/revoke and no artificial academic progress.
#335 remains a dependency. Private file URL delivery/rewriting, protected-media
authorization, progress sync, background resumable transfers, client wiring and
live corpus publication remain separate acceptance work, not claims of this PR.

Rollback source: remove the new route hook/include/helper. Existing editorial
routes are untouched. Unused integrity metadata grants no access and can be
preserved. Never delete files/student records or change signing/release gates
as a rollback for this read-only source addition.
