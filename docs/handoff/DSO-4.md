# Handoff: DSO-4 aggregates + DSO-5 analytics + DSO-6 pages

Lock: active since 2026-11-21 17:30 UTC

Branch: task/DSO-4-aggregates
Doc: docs/09-dso-ingestion-vee.md
Status: in progress

## Next step
Write sp_dso_build_aggregates (+ pending, list), then sp_dso_detect_events, then the pages.

## Done so far
- 2026-11-21: claimed.

## Blockers / open questions

## How to test
`python sql/tools/build_all.py --tests`, run ALL.sql on a clean database; every test line must start with OK.
