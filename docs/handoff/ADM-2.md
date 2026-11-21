# Handoff: ADM-2 Admin users, account status, audit log

Lock: active since 2026-11-21 16:34 UTC

Branch: task/ADM-2-admin-users
Doc: docs/05-users-roles-login.md
Status: in progress

## Next step
Write sql/procs_admin.sql and sql/tests/test_admin.sql.

## Done so far
- Claimed.

## Blockers / open questions

## How to test
python sql\tools\build_all.py --drop --tests, then run_sql.ps1 -File sql\build\ALL.sql -AllowDestructive
