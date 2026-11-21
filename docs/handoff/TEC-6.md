# Handoff: TEC-6 meter install/replace, confirm, commands, anti-tamper (TEC-6..10)

Lock: free

Branch: task/TEC-6-install
Doc: docs/08-technicians-and-meters.md
Status: finished (in review)

## Next step
Review and merge the TEC-6 PR (a member who did not write it).

## Done so far
- 2026-11-21 18:40 UTC (another session, asked by the human): merged main; the one FAIL "doc foreign meter" was a test bug, not a procedure bug.
  All base meters 1-5 were installed by tech1, so meter 1 is not foreign to him and the procedure correctly answered 52141
  (installation already confirmed). Test now checks 52141 on meter 1 and 52140 on a meter with no installation of his.
  `bash sql/tools/test_local.sh` → 748 OK, 0 FAIL, ALL OK.
- 2026-11-21: TEC-6..10 written: 20 procedures in procs_technician.sql, test block (about 150 OK checks) appended, 4 pages (plus tamper-check form inside technician/50_commands.php). Nothing was run: no database here.

## Blockers / open questions
None.

## How to test
`python sql/tools/build_all.py --tests`, coordinator runs ALL.sql.
