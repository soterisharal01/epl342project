# Handoff: FIX-2 Review fixes after FIX-1

Lock: free

Branch: task/FIX-2-month-close
Doc: docs/09-dso-ingestion-vee.md
Status: finished (in review), **not yet run on a database**

## Next step
Run the full build with tests (`bash sql/tools/test_local.sh`, or `build_all.py --tests` + `run_sql.ps1` on your own database)
and check that the new FIX-2 lines print `OK` (`FIX-2 finished month closed…`, `FIX-2 second run…`, and `history: prosumer…`). Then merge.

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
  3. `sp_retention_preview` / `sp_retention_purge_core` (sql/procs_gdpr.sql): a cumulative value (1.8.0/2.8.0) younger than
     36 months is deleted only if its day already has a `METER_AGGREGATE` Day row, so the automatic GDPR purge (FIX-1) can never
     delete the data a day total is built from. Test setup of GDP-2 got Day rows for meter A; two new tests; the cleanup now
     deletes the test aggregates under the `mdms_purge` flag (ready for the trigger in open question 1).
  4. Explicit `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` in `sp_consumer_buy_history` and `sp_gdpr_submit` (spec IV asks for
     isolation levels); doc 15 section 2 updated.
  5. Web app: a Pending technician could not log in, so could never upload the 3 documents that `sp_operator_decide_technician`
     requires, so a newly registered technician could never be approved. Now Pending/Suspended technicians log in and see only
     «Τα έγγραφά μου» (`technician_limited()`, `require_approved_technician()` in `sources/auth.php`; menu filtered in `layout.php`;
     pages 20-50 guarded). Checked with a fake sqlsrv driver (Pending: tasks page redirects, menu = documents; Approved: all 5).
  6. `sp_dso_ingest_packet` refuses an item whose `unit` differs from `OBIS_CODE.Unit` (spec III.3.1 «μονάδα»). Test added.

## Blockers / open questions
- The session had no SQL Server (the container image host is blocked), so this was **not executed**.
- 1. **Schema change for the team to agree (not done):** spec III.3.2 says aggregates are final and immutable, but only
  `VALIDATED_READING` has an immutability trigger. Proposal: `TR_METER_AGGREGATE_Immutable` and
  `TR_TRANSFORMER_AGGREGATE_Immutable` (AFTER UPDATE, DELETE; UPDATE -> THROW 50007; DELETE without the `mdms_purge` flag -> THROW 50008),
  same shape as `TR_VALIDATED_READING_Immutable` in `create.sql`. No procedure updates or deletes aggregates today.

## How to test
`bash sql/tools/test_local.sh` must end with `ALL OK`.
