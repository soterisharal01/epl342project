# Handoff: ADM-3 + ADM-4 Operator catalogs and admin/operator pages

Lock: active since 2026-11-21 16:47 UTC

Branch: task/ADM-3-catalogs
Doc: docs/05-users-roles-login.md
Status: in progress

## Next step
Write catalog procedures in sql/procs_admin.sql, then tests, then the three pages.

## Done so far
- Claimed.

## Blockers / open questions

## How to test
python sql/tools/build_all.py --tests, then run sql/build/ALL.sql on a database; every check prints OK or FAIL.
