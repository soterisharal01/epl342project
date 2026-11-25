# Handoff: FIX-3 Review follow-up (aggregates, retention, isolation)

Lock: free

Branch: claude/project-thread-l9t34v (built on top of task/FIX-2-month-close, PR #46)
Doc: docs/07-gdpr-and-retention.md, docs/15-concurrency.md, docs/04-database-schema.md
Status: finished (in review)

## Done
- 2026-11-25: ran PR #46 (FIX-2) on a local SQL Server 2025 (Docker): 784 OK, 0 FAIL. Reviewed the code: correct.
- Three points from the review of FIX-1:
  1. **Purge could lose aggregates.** `fn_retention_unaggregated_days` (sql/procs_gdpr.sql) lists (meter, 1.8.0/2.8.0, day) with a
     validated or Pending/Suspect raw reading but no Day aggregate. `sp_retention_preview` and `sp_retention_purge_core` skip the raw,
     validated and edit rows of those days. They go at the first purge after the DSO builds the aggregates.
  2. **Aggregates immutable.** `TR_METER_AGGREGATE_Immutable` and `TR_TRANSFORMER_AGGREGATE_Immutable` in sql/create.sql:
     UPDATE -> 50007, DELETE -> 50008 unless `mdms_purge` = 1 (only test clean-up uses it). Schema change: triggers only.
  3. **Explicit isolation levels**: SERIALIZABLE in `sp_consumer_pay_invoice`, `sp_consumer_buy_history`, `sp_tech_add_note`;
     READ COMMITTED in `sp_dso_losses_report`. The hints stay. SQL Server restores the caller's level on return (tested).
- Tests: test_gdpr (unaggregated day kept, then purged after the aggregate exists), test_dso (4 trigger refusals),
  test_consumer (isolation level). Local: 792 OK, 0 FAIL.

## Next step
Merge PR #46 first, then this PR. Every member rebuilds their own database; then rebuild `sharal01` with the REL-1 runbook.

## How to test
`bash sql/tools/test_local.sh` must end with `ALL OK`.
