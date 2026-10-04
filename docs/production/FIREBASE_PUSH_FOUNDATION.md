# Firebase push foundation

Status: IMPLEMENTED as an inactive client foundation. It does not upload,
persist, log, display, or send FCM tokens. Push has no authority to change
authentication, enrollment, attendance, study progress, completion, or
certificates.

The default is `PUSH_NOTIFICATIONS_ENABLED=false`. With that value the app
uses a no-op provider, Firebase is not initialized, and no permission prompt is
shown. Permission is requested only by an explicit future user action; this
foundation deliberately adds no such UI action yet.

## Staging activation — HUMAN-GATE

Before any staging activation, a responsible human must approve the Firebase
project, platform registration, notification copy, privacy review, a token
handling design, and device QA. Do not add `google-services.json`,
`GoogleService-Info.plist`, a Google Services Gradle plugin, or production
Firebase values in this slice.

After that approval, supply only these non-secret `--dart-define` values to a
staging build:

- `PUSH_NOTIFICATIONS_ENABLED=true`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`

All four Firebase values must be non-empty. Missing or failed initialization
fails closed to the no-op provider without delaying application startup. The
production release gate accepts only `PUSH_NOTIFICATIONS_ENABLED=false`; it
does not allow any Firebase project define.

Only a version-one payload with exactly
`{"version":"1","destination":"support"}` is navigable, and it opens
support. Foreground messages, notification taps, and initial messages use that
same allowlist. Unknown, malformed, or academic payloads are ignored.
