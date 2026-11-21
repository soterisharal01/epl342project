# Handoff: TSO-2 + TSO-3 + TSO-4 current state, aggregates, load shedding

Lock: free

Branch: task/TSO-2-state-shed
Doc: docs/10-tso-transformers.md
Status: finished (in review)

## Next step
The coordinator runs the full build and tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`) and sends back anything that fails.

## Done so far
- Procedures in `sql/procs_tso.sql`: `sp_tso_refresh_current_state`, `sp_tso_current_state` (TSO-2), `sp_tso_aggregates` (TSO-3), `sp_tso_load_shed`, `sp_tso_list_shed_orders` (TSO-4). THROW 53600-53601, 53610-53612, 53620-53622.
- Tests appended to `sql/tests/test_tso.sql` (after the TSO-1 part, variables prefixed `@s_`).
- Pages `sources/tso/20_state.php`, `30_aggregates.php`, `40_shed.php` (not run: PHP is not installed here).
- `docs/10-tso-transformers.md` updated; TSO-2/3/4 rows set to review in `docs/tasks.md`.
- Nothing was run against a database in this session.

## Blockers / open questions
- Tests were never executed; expect to fix small T-SQL typos if any.
- The load-shed tests create real orders and commands (3 and 4 commands) in the test database.

## How to test
`python sql/tools/build_all.py --tests`, then run `sql/build/ALL.sql` with `run_sql.ps1`. Every new check prints `OK ...` or `FAIL ...` (no FAIL expected).
