# Handoff: DAT-5 select.sql EXEC list

Lock: free

Branch: task/DAT-5-select-exec
Doc: docs/13-data-sets.md (section "sql/select.sql")
Status: finished (in review)

## Next step
Review and merge. Optional after TEC-6 (PR #36) merges: add `sp_tech_list_installs` (technician's installations) as E12b.

## Done so far
- 2026-11-21: Part 2 of sql/select.sql: E01–E37, one EXEC of the read procedure behind every main page of every role,
  parameters picked from the data, TRY/CATCH per call. Doc 13 section, board row.

## Blockers / open questions
None.

## How to test
Build without tests + base data (`python sql/tools/build_all.py`, run sql/build/ALL.sql), then run sql/select.sql in SSMS.
Expect result grids and no `Msg` / `refused:` lines in Messages. Done locally (SQL Server 2025, Docker): 0 errors on a clean
build and on a database after all tests.
