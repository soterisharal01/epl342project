# Handoff: TEC-1 Technician registration + categories

Lock: free
<!-- "active since 2026-11-22 14:00 UTC" while a session is working; "free" when it stops. -->

Branch: task/TEC-1-tech-register
Doc: docs/08-technicians-and-meters.md
Status: finished (in review)

## Next step
Coordinator runs the full build + tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`) and checks that every TEC-1 line prints `OK`.

## Done so far
- 2026-11-21 (UTC): wrote `sql/procs_technician.sql` (sp_tech_assert, sp_ref_list_tech_categories, sp_auth_register_technician, sp_tech_list_categories, sp_tech_set_categories; THROW 52000-52007), `sql/tests/test_technician.sql` (25 OK checks), `sources/register_technician.php`, doc 08, tasks row. `index.php` already links the page when the file exists. Nothing was run against a database (written without DB access).

## Blockers / open questions
- SQL not yet executed; PHP syntax checked by reading only (PHP not installed).

## How to test
Build and run the whole `sql/build/ALL.sql`. Success: all `test_technician.sql` lines start with `OK`, no `FAIL`. Page: open `register_technician.php`, register with 1+ categories; then login as that user is refused with "waiting for approval".
