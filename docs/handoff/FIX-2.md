# Handoff: FIX-2 Review fixes after FIX-1

Lock: free

Branch: task/FIX-2-month-close
Doc: docs/09-dso-ingestion-vee.md
Status: finished (in review), **not yet run on a database**

## Next step
Run the full build with tests (`bash sql/tools/test_local.sh`, or `build_all.py --tests` + `run_sql.ps1` on your own database)
and check that the three new lines print `OK` (`FIX-2 finished month closed…`, `FIX-2 second run…`, and `history: prosumer…`). Then merge.

## Done so far
- 2026-11-25: review of PRs #44 and #45 (both merged). Two gaps found in FIX-1 and fixed here:
  1. `sp_dso_build_aggregates_pending` (sql/procs_dso.sql): after the day loop, a second pass closes every month/year that ended
     before `@UpTo` and has Day rows without a Month/Year row. Before, the month row was written **only** when the helper ran
     for the month's last day, so (a) a Suspect reading edited after the last day was built left that meter without a month row
     for good (FIX-1 skips it on the last day, and the late rebuild runs for the edited day, not the last day), and (b) a month whose
     last day had no readings never got a month row at all. The helper's `NOT EXISTS` guards mean nothing is written twice.
  2. `sql/tests/test_consumer.sql`: `history: prosumer import/export/net` reads 18/11 as consumer2. Since FIX-1, past months need a
     purchase, so from 1/12 this test would print FAIL. Consumer2 now buys November inside a transaction that is rolled back.
  New test in `sql/tests/test_dso.sql` (FIX-2 block, October 2026, transaction + ROLLBACK).

## Blockers / open questions
- The session had no SQL Server (the container image host is blocked), so this was **not executed**.

## How to test
`bash sql/tools/test_local.sh` must end with `ALL OK`.
