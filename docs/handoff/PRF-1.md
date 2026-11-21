# Handoff: PRF-1/2/3 Indexes + before/after case

Lock: free

Branch: task/PRF-1-indexes
Doc: docs/14-indexes-and-performance.md
Status: finished (in review)

## Next step
Coordinator: run sql/indexes.sql, sql/tests/test_indexes.sql, then sql/perf/before_after.sql on the large data set and fill the table in docs/14.

## Done so far
- 2026-11-21: indexes.sql, perf/before_after.sql, tests/test_indexes.sql, doc 14 written; NOT run on a database.

## Blockers / open questions
No database in this lane: the coordinator runs the scripts.

## How to test
sql/tests/test_indexes.sql (3 OK lines); sql/perf/before_after.sql on the large data set.
