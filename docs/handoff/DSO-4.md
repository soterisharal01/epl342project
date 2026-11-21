# Handoff: DSO-4 aggregates + DSO-5 analytics + DSO-6 pages

Lock: free

Branch: task/DSO-4-aggregates
Doc: docs/09-dso-ingestion-vee.md
Status: ready for review (untested: the coordinator runs the tests)

## Next step
Run `python sql/tools/build_all.py --tests` against a clean database, fix any FAIL, then open the PR.

## Done so far
- 2026-11-21: sp_dso_build_aggregates(+_day, _pending, list_aggregates, list_transformer_aggregates), sp_dso_detect_events, list_events, losses_report (sql/procs_dso.sql); 46 tests appended to sql/tests/test_dso.sql; pages sources/dso/30_aggregates.php and 40_events.php; docs/09. Nothing was run against a database.

## Blockers / open questions

## How to test
`python sql/tools/build_all.py --tests`, run ALL.sql on a clean database; every test line must start with OK.
