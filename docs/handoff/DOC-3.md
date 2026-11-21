# Handoff: DOC-3 Data dictionary (and REL-5 select.sql)

Lock: active since 2026-11-21 17:30 UTC

Branch: task/DOC-3-dictionary
Doc: docs/20-data-dictionary.md
Status: in progress

## Next step
Write sql/select.sql (REL-5), then free the lock.

## Done so far
- 2026-11-21: sql/tools/dictionary.py generates docs/20-data-dictionary.md (56 tables) from sql/create.sql.

## Blockers / open questions
None.

## How to test
`python sql/tools/dictionary.py` rewrites the doc; `git diff` must be empty afterwards. select.sql: run once in SSMS on a loaded database; it must parse.
