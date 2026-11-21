# Handoff: PRF-1/2/3 Indexes + before/after case

Lock: active since 2026-11-21 17:30 UTC

Branch: task/PRF-1-indexes
Doc: docs/14-indexes-and-performance.md
Status: in progress

## Next step
Write sql/indexes.sql, sql/perf/before_after.sql, sql/tests/test_indexes.sql, the doc.

## Done so far
- 2026-11-21: claim.

## Blockers / open questions
No database in this lane: the coordinator runs the scripts.

## How to test
sql/tests/test_indexes.sql (3 OK lines); sql/perf/before_after.sql on the large data set.
