# Handoff: MKT-1 + MKT-3 supplier aggregates + Intraday provisional

Lock: free
<!-- "active since 2026-11-22 14:00 UTC" while a session is working; "free" when it stops. -->

Branch: task/MKT-1-market-aggregates
Doc: docs/11-suppliers-aggregators.md
Status: finished (in review)

## Next step
The coordinator runs the full build + tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`) and fixes anything that fails. Then MKT-4 (PHP pages) can start.

## Done so far
- Session 1: wrote `sql/procs_market.sql` (sp_market_assert, fn_market_premises, sp_supplier_aggregates, sp_supplier_totals, sp_market_intraday, MKT-2 portfolio procedures), `sql/tests/test_market.sql`, updated `docs/11-suppliers-aggregators.md` and the MKT-1/2/3 rows of `docs/tasks.md`. Nothing was run against the database (written blind).

## Blockers / open questions

## How to test
`python sql/tools/build_all.py --tests`, run `sql/build/ALL.sql`; every line from `test_market.sql` must print `OK` (no `FAIL`). A `INFO` line for the Month check is not a failure.
