# Handoff: FIX-2 Review fixes after FIX-1

Lock: free

Branch: task/FIX-2-month-close
Doc: docs/09-dso-ingestion-vee.md
Status: finished (in review); full build + tests run on a member database on 25/11: 0 FAIL

## Next step
Review and merge (tests already pass, see below). Re-run if anything changes: (`bash sql/tools/test_local.sh`, or `build_all.py --tests` + `run_sql.ps1` on your own database)
and check that the new FIX-2 lines print `OK` (`FIX-2 finished month closed…`, `FIX-2 second run…`, and `history: prosumer…`). Then merge.

## Done so far
- 2026-11-25 14:34 UTC: `build_all.py --drop --tests` run in SSMS on a member's own database on `mssql.cs.ucy.ac.cy\SQL2025`: finished in 55 s, "Query executed successfully", 0 lines starting with `FAIL` (match case), all 5 `FIX-2` lines `OK` (wrong unit, finished month closed, second run, purge keeps, purge deletes).
- 2026-11-25: review of PRs #44 and #45 (both merged). Two gaps found in FIX-1 and fixed here:
  1. `sp_dso_build_aggregates_pending` (sql/procs_dso.sql): after the day loop, a second pass closes every month/year that ended
     before `@UpTo` and has Day rows without a Month/Year row. Before, the month row was written **only** when the helper ran
     for the month's last day, so (a) a Suspect reading edited after the last day was built left that meter without a month row
     for good (FIX-1 skips it on the last day, and the late rebuild runs for the edited day, not the last day), and (b) a month whose
     last day had no readings never got a month row at all. The helper's `NOT EXISTS` guards mean nothing is written twice.
  2. `sql/tests/test_consumer.sql`: `history: prosumer import/export/net` reads 18/11 as consumer2. Since FIX-1, past months need a
     purchase, so from 1/12 this test would print FAIL. Consumer2 now buys November inside a transaction that is rolled back.
  New test in `sql/tests/test_dso.sql` (FIX-2 block, October 2026, transaction + ROLLBACK).
  (3 and 4, a purge guard and explicit isolation levels, were dropped from this branch: PR #47 / FIX-3 does both more completely.)
  5. Web app: a Pending technician could not log in, so could never upload the 3 documents that `sp_operator_decide_technician`
     requires, so a newly registered technician could never be approved. Now Pending/Suspended technicians log in and see only
     «Τα έγγραφά μου» (`technician_limited()`, `require_approved_technician()` in `sources/auth.php`; menu filtered in `layout.php`;
     pages 20-50 guarded). Checked with a fake sqlsrv driver (Pending: tasks page redirects, menu = documents; Approved: all 5).
  6. `sp_dso_ingest_packet` refuses an item whose `unit` differs from `OBIS_CODE.Unit` (spec III.3.1 «μονάδα»). Test added.

## Blockers / open questions
- The session had no SQL Server (the container image host is blocked), so this was **not executed**.
- The aggregate immutability triggers are in PR #47 (FIX-3).

## How to test
`bash sql/tools/test_local.sh` must end with `ALL OK`.
