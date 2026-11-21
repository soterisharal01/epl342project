# Handoff: PRF-4 measurements (before/after for PRF-1/2/3 and the 10,000-request test)

Lock: free

Branch: task/PRF-4-measurements
Doc: docs/14-indexes-and-performance.md
Status: finished (merged)

## Next step
For the printed report: rerun `sql/perf/before_after.sql` in SSMS with Ctrl+M on the demo database (after REL-1) and take
the plan screenshots; optionally rerun `perf_10000.py` against the department server.

## Done so far
- 2026-11-21: fixed before_after.sql (PRINT with a subquery is not allowed in T-SQL, so A1/B1 never ran; Greek PRINT text
  needed N''; temp table dropped after ROLLBACK). Measured A 17→2, B 244→5, C 21→2 logical reads. New
  sql/perf/perf_10000.py: 10,000 calls, 0 errors, 100% under 2 s, p95 62.6 ms. Doc 14 filled.

## How to test
Local or member database with the large set: run sql/perf/before_after.sql; run perf_10000.py with MDMS_* variables.
