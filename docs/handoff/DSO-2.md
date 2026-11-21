# Handoff: DSO-2 + DSO-3 VEE

Lock: active since 2026-11-21 16:49 UTC
<!-- "active since 2026-11-22 14:00 UTC" while a session is working; "free" when it stops. -->

Branch: task/DSO-2-vee
Doc: docs/09-dso-ingestion-vee.md
Status: ready for review (untested: the coordinator runs the tests)

## Next step
Run `python sql/tools/build_all.py --tests` against a clean database, fix any FAIL, then open the PR. Aggregates after VEE are DSO-4.

## Done so far
<!-- Newest first. One line per session: date (UTC), what was built, files touched. -->
- 2026-11-21: sp_dso_run_vee, sp_dso_list_suspect, sp_dso_edit_reading, sp_dso_list_runs (sql/procs_dso.sql); tests appended to sql/tests/test_dso.sql; page sources/dso/20_vee.php; docs/09. Nothing was run against a database yet.

## Blockers / open questions

## How to test
`python sql/tools/build_all.py --tests`, run ALL.sql on a clean database; every test line must start with OK.
