# Handoff: CON-7 Remove dbo. from consumer procedures

Lock: free

Branch: task/CON-7-no-dbo (stacked on task/REL-0-docs-restructure, PR #7)
Doc: docs/06-consumers.md
Status: finished (in review)

## Next step
Review and merge after PR #7 (this branch contains #7's commits until #7 is merged).

## Done so far
- 2026-11-21: `fn_consumer_holds` changed from a scalar function (needs `dbo.` to be called) to an inline table-valued
  function, called unqualified with `EXISTS (SELECT 1 FROM fn_consumer_holds(...))` in `sp_consumer_end_holding`,
  `sp_consumer_add_bank_account`, `sp_consumer_list_meters`, `sp_consumer_submit_request`. The script drops the old
  function first, because `CREATE OR ALTER` cannot change a scalar function into a table-valued one.

## Blockers / open questions
None.

## How to test
`python sql/tools/build_all.py --drop --tests`, then
`powershell -ExecutionPolicy Bypass -File sql/tools/run_sql.ps1 -File sql/build/ALL.sql -AllowDestructive` on your own database.
Expected: exit 0, 37 `OK` lines (11 test_common + 26 test_consumer), 0 `FAIL`. Result on 2026-11-21: 37/37 OK.