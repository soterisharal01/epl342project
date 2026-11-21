# Handoff: TSO-1 Transformer tree, geofences, locate

Lock: free
<!-- "active since 2026-11-22 14:00 UTC" while a session is working; "free" when it stops. -->

Branch: task/TSO-1-tree
Doc: docs/10-tso-transformers.md
Status: finished (in review)

## Next step
The coordinator runs the full build + tests (`sql/build/ALL.sql`) and checks that every `test_tso.sql` line prints OK. Nothing was run against a database by the worker.

## Done so far
- 2026-11-21: `sql/procs_tso.sql` (sp_tso_assert, sp_tso_add_transformer, sp_tso_tree, sp_tso_locate, sp_tso_check_meter_locations), `sql/tests/test_tso.sql` (35 OK checks), page `sources/tso/10_tree.php` (syntax checked by reading only, PHP not installed), doc 10 updated, tasks row set to 👀.

## Blockers / open questions
- Rerunning test_tso.sql on the same database (without rebuild) adds another T-TEST-LIM-A and the "locate leaf only" check would then see two leaves. A normal build recreates the database.
- Child geofence outside the parent's is enforced (53507), not only a warning.

## How to test
`python sql\tools\build_all.py --tests`, then run `sql/build/ALL.sql` with `run_sql.ps1`. Success: all `OK` lines from test_tso.sql, no `FAIL`.
