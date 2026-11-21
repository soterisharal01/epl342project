# Handoff: TEC-6 meter install/replace, confirm, commands, anti-tamper (TEC-6..10)

Lock: active since 2026-11-21 17:30 UTC

Branch: task/TEC-6-install
Doc: docs/08-technicians-and-meters.md
Status: in progress

## Next step
Write the procedures in sql/procs_technician.sql (THROW 52131-52199, 52330-52499), then tests, then pages.

## Done so far
- 2026-11-21: claim.

## Blockers / open questions
None.

## How to test
`python sql/tools/build_all.py --tests`, coordinator runs ALL.sql.
