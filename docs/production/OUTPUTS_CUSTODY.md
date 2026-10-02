# Tutor TDS — Outputs custody manifest

**Status:** hash inventory created; physical transfer to approved private storage is pending.  
**Scope:** non-source artifacts in `outputs/` that must not enter Git (builds, BI packages, pilot planning files).  
**Working tree:** all source/documentation commits done; `outputs/` remains gitignored.  
**Total inventory:** 3,577 files / ~249 MB.

## Approved private destinations (not configured yet)

| Category | Proposed destination | Access control | Retention |
|---|---|---|---|
| APK/AAB debug candidates | Institutional cloud drive or S3-compatible bucket, path `tutor-tds/builds/<branch>/<timestamp>` | core maintainers only | 90 days or until replaced by release artifact |
| BI packages (.pbip, .pbir, .pbism) | `tutor-tds/bi/packages/<date>` | data team + mentor coordinators | keep last 5 versions + named pilot snapshots |
| CSV exports / JSON reports | `tutor-tds/reports/<environment>/<date>` | QA + admin data | 1 year, then archive |
| Pilot planning / pitch decks | `tutor-tds/planejamento/pilotos/<date>` | coordination team | permanent until superseded |

> Do not transfer anything until the provider account, bucket name and encryption-at-rest policy are confirmed by the repository owner.

## Principal artifacts — SHA-256 hashes

| File | Size class | SHA-256 |
|---|---|---|
| `outputs/Tutor-TDS-Journey-2026-10-01-staging-dev.apk` | build | `e195a7f93b0781d2c24455c893c23897f45168b3b9e5f7e08b553e053d2ffa26` |
| `outputs/Tutor_TDS_Pitch_Startups_UFT_29-09-2026_atualizado.pptx` | deck | `35f30fe7dbe09fa464a3ac846c26698d4a1706a913e6270b2d990648f221bf55` |
| `outputs/Tutor_TDS_Pre_Pitch_Identidade_TDS_29-09-2026.pptx` | deck | `ac7bf204dc043bfaa20ff89713933a87628514b9d014a00c9f86a8f2d4b394ec` |
| `outputs/Tutor_TDS_Pre_Pitch_Negocio_e_Staging_29-09-2026.pptx` | deck | `8e32dc650e1ecd7490d79730663798693fa22a53df86ff413b637fdfb9a30829` |
| `outputs/TDS_Journey_2026-10-01/TDS_Rastreio.pbip` | BI package | `4f2994dd5adb5266224c80a21c3f58146812cb101994ce99ecfc8d925d8c43cf` |
| `outputs/TDS_Journey_2026-10-01/TDS_Original.pbip` | BI original | `eb0c90073fbc02b82d42d0e83a5036ef114f2210768ad34792da9324f465d0ec` |
| `outputs/TDS_Journey_Final_QA_Export_2026-10-01/TDS_ATIVIDADE_APP.csv` | QA export | `b6812e6a9da0993fee2bd9caaf70ae87b80adafab9e9c2cac630c02cb0791b9d` |
| `outputs/TDS_Journey_Final_QA_Export_2026-10-01/TDS_JORNADA_APP.csv` | QA export | `2418565f178c33f62ef9dac62eb12236a258533580f58afd00f11ec08e8e5e2c` |
| `outputs/TDS_Journey_Final_QA_Export_2026-10-01/TDS_PARTICIPANTES_APP.csv` | QA export | `cf8279b950f5a6dfe26c553288ade3c8c58b8c193bc932c99ed132c516d6bd3f` |
| `outputs/TDS_Journey_Final_QA_Export_2026-10-01/review.json` | QA review | `93c17f7ec86d539be6b58294c18379f08fd02ffd6ab1d334400f53d167996b95` |
| `outputs/TDS_Journey_QA_Export_2026-10-01/TDS_JORNADA_APP.csv` | QA export | `0d235f677db0b6916e0d6f968673ce3cfa4d2ab7317abd116ae9fd9df30093ff` |
| `outputs/TDS_Journey_QA_Export_2026-10-01/TDS_ATIVIDADE_APP.csv` | QA export | `c402cc1b5c28b9752fc3d4dbdc2c462636cfac8a98cdc8814dd0ec39e8e0f63b` |
| `outputs/TDS_Journey_2026-10-01/rastreio-candidate.json` | traceability candidate | `2da9d2d78bc30872e4c92a7c8cfaf7cb5e30f8778d0cd7dec56ef6d79a3db3a0` |
| `outputs/TDS_Journey_Pilot_2026-10-11/pilot-registration-plan.json` | pilot plan | `a17d1055b2d3649fb9dcb069707469feed7dd5d09653c7b8ba76f82139b23c35` |
| `outputs/TDS_Journey_Pilot_2026-10-11/activation-review.json` | activation review | `afa62fcbc980261e6eb33dd4e7628699829fb9a5a83aec4b8c14c860fbadcb21` |

Duplicate files with the same hash are copies across dated folders and represent the same logical artifact.

## Transfer checklist

- [ ] Owner confirms private storage provider and credentials.
- [ ] Create destination folders matching the table above.
- [ ] Upload `outputs/` preserving directory structure.
- [ ] Re-compute SHA-256 after upload and compare with the manifest above.
- [ ] Restrict access to the listed teams; do not share public links.
- [ ] Keep `outputs/` on the local disk as a second copy until parity is confirmed.
- [ ] After confirmation, update this file with `transferred_at`, `destination` and `verified_by`.

## What stays in Git

Only source code, tests, contracts, lightweight sanitized evidence JSON and small static assets remain in Git.  
Any artifact larger than a few MB, any binary build, any BI package and any file containing QA participant data belongs in approved private storage, never in a public or shared repository path.
