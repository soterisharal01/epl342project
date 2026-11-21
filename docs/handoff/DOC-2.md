# Handoff: DOC-2 Final ER and relational diagrams

Lock: free

Branch: task/DOC-2-er
Doc: docs/22-er-diagram.md
Status: finished (in review)

## Next step
Review the PR. After a schema change, run `python sql/tools/er_diagram.py` and commit `docs/img/er/`.

## Done so far
- 2026-11-22: generator `sql/tools/er_diagram.py` (parses create.sql, writes .dot, renders .svg/.png), 5 Chen pictures (overview + 4 areas), 5 relational pictures (all + 4 areas), coverage table (56/56), doc 22, README row, task board set to review, claim row removed.

## Blockers / open questions
- Modelling choices to confirm: roles drawn as an attribute of USER_ACCOUNT (no ISA, plain ER); HOLDING drawn as an M:N relationship; TRANSFORMER_CURRENT_STATE as an M:N relationship with attributes; readings and aggregates as weak entities of meter or transformer and OBIS code.
- A table-level diff against Phase A is not in the repo docs, so "changes since Phase A" lists only the four documented changes.

## How to test
`python sql/tools/er_diagram.py --no-render` prints "coverage problems: 0" and a sha256; run it twice, the sha256 is identical. Open docs/22-er-diagram.md and check the pictures.
