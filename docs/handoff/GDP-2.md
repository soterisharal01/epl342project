# Handoff: GDP-2 Data retention purge

Lock: free

Branch: task/GDP-2-retention
Doc: docs/07-gdpr-and-retention.md
Status: finished (in review)

## Next step
The coordinator builds and runs the tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`) and sends back any FAIL.

## Done so far
- Written, not yet run against a database: `fn_retention_cutoff`, `sp_retention_preview`, `sp_retention_purge` (THROW 51450, 51451) in `sql/procs_gdpr.sql`;
  26 OK checks appended to `sql/tests/test_gdpr.sql`; `sources/admin/gdp_retention.php` (not syntax-checked, no php here); docs/07 updated; tasks.md row 👀.

## Blockers / open questions
- The test needs the GDP-1 part to run first in the same database (it finds test_gdp_a by its premise) and a fresh database (fixed serial numbers SN-GDP2-*).
- With @AsOf = now, the 1-month consumer's readings older than a month are deleted by design, so the "0 deleted" test uses @AsOf = 2026-05-01.

## How to test
python sql/tools/build_all.py --tests, then run sql/build/ALL.sql on a test database.
