# Handoff: DAT-1..4 Large data set

Lock: active since 2026-11-21 17:10 UTC

Branch: task/DAT-1-large-data
Doc: docs/13-data-sets.md
Status: in progress

## Next step
Write data/gen/large.py, run it, self-check, commit generated files.

## Done so far
- 2026-11-21: claimed.

## Blockers / open questions

## How to test
Run `python data/gen/large.py` (self-checks run before writing). Then load sql/import.sql after data/small/00_base.sql.
