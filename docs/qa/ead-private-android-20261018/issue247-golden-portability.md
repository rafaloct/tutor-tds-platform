# Golden portability EAD, Issue #247 (2026-10-18)

## Context
This is a **test-only** maintenance change, based on PR #246 HEAD `d2baed510b8affd12e45a64a9eb329490d89310b`, not a release or production change. The three EAD snapshots capture synthetic editorial fixtures, **not** live WordPress content, Android screenshots, or proof of publication.

The same test layout and locked Poppins-Regular.ttf font pass 3/3 on Windows with Flutter 3.44.9. In GitHub Actions Ubuntu 24.04 with the same pinned Flutter 3.44.9, they initially failed at exact comparison because the image renderer produced antialiasing differences:
- `ead_saf_learning_path_preview.png`: 19,342 / 382,500 pixels (5.057%)
- `ead_authorized_lesson_blue.png`: 17,727 / 382,500 pixels (4.635%)
- `ead_wp_synthetic_real_http_blue.png`: 12,261 / 382,500 pixels (3.205%)

## Resolution
Each test chooses a checked-in Linux reference if `Platform.isLinux`, and the existing Windows reference otherwise. Golden matching remains pixel exact; no test was skipped, no tolerance was increased, and no production feature was modified.

The Linux references were generated in the public CI runner with:
- `ubuntu-24.04`
- Flutter 3.44.9 (downloaded archive SHA-256 verified)
- `flutter pub get --enforce-lockfile`
- `flutter test --update-goldens` for the three EAD goldens only
- CI capture run: https://github.com/rafaloct/tutor-tds-platform/actions/runs/39123631628 (SUCCESS)
The one-use workflow file used for capture was removed before finalizing the draft PR. No permanent artifact auto-update is enabled.

## Review
Windows and Linux reference images were visually inspected side by side and keep the same texts, layout, font, blue institutional theme, video markers and disclaimers. Pixel differences (3.2%-5.1%) reflect the platform rasterization result. Both image sets must be reviewed on future deliberate UI changes; no synthetic golden proves runtime Android behavior.

GitHub's normal `flutter-app.yml` CI and Windows focal tests are the acceptance gates for this fix. The broader PR dependency stack and release gates remain separate.
