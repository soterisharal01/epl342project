# Handoff: DOC-3 Data dictionary (and REL-5 select.sql)

Lock: free

Branch: task/DOC-3-dictionary
Doc: docs/20-data-dictionary.md
Status: finished (in review)

## Next step
Coordinator: run sql/select.sql once on a loaded database to confirm it parses (it was written without a database).

## Done so far
- 2026-11-21: REL-5 sql/select.sql, 27 queries (not in build_all.py).
- 2026-11-21: sql/tools/dictionary.py generates docs/20-data-dictionary.md (56 tables) from sql/create.sql.

## Blockers / open questions
None.

## How to test
`python sql/tools/dictionary.py` rewrites the doc; `git diff` must be empty afterwards. select.sql: run once in SSMS on a loaded database; it must parse.
