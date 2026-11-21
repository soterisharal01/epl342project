# Handoff: ADM-2 Admin users, account status, audit log

Lock: free

Branch: task/ADM-2-admin-users
Doc: docs/05-users-roles-login.md
Status: finished (in review)

## Next step
Coordinator runs the tests (full build + run on a database) and reviews.

## Done so far
- sql/procs_admin.sql: sp_admin_assert, sp_admin_create_user, sp_admin_list_users, sp_admin_set_account_status, sp_admin_audit_log, sp_admin_list_companies (THROW 51500-51530).
- sql/tests/test_admin.sql: 43 OK checks, every procedure has success and refusal cases.
- docs/05 updated. Not run against a database by the worker.

## Blockers / open questions
- Not executed yet; expect possible small fixes after the first run.

## How to test
python sql	oolsuild_all.py --drop --tests, then run_sql.ps1 -File sqluild\ALL.sql -AllowDestructive
