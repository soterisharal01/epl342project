# Handoff: DAT-1..4 Large data set

Lock: free (was active since 2026-11-21 17:10 UTC)

Branch: task/DAT-1-large-data
Doc: docs/13-data-sets.md
Status: finished (in review)

## Next step
Coordinator: load sql/import.sql after data/small/00_base.sql on a clean DB, check row counts (see data/README.md), then DAT-4 sign-off.

## Done so far
- 2026-11-21: claimed.

## Blockers / open questions

## How to test
Run `python data/gen/large.py` (self-checks run before writing). Then load sql/import.sql after data/small/00_base.sql.

- large.py, data/large/*.dat, sql/import.sql (path from docs/13), data/README.md written; Python self-checks pass. Not loaded into SQL Server (no DB here).
