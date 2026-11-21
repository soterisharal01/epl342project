# Handoff: TEC-6 meter install/replace, confirm, commands, anti-tamper (TEC-6..10)

Lock: free

Branch: task/TEC-6-install
Doc: docs/08-technicians-and-meters.md
Status: finished (in review)

## Next step
Coordinator runs ALL.sql; fix any FAIL in the TEC-6 block of test_technician.sql (users: tech1=5, operator=2).

## Done so far
- 2026-11-21: TEC-6..10 written: 20 procedures in procs_technician.sql, test block (about 150 OK checks) appended, 4 pages (plus tamper-check form inside technician/50_commands.php). Nothing was run: no database here.

## Blockers / open questions
None.

## How to test
`python sql/tools/build_all.py --tests`, coordinator runs ALL.sql.
