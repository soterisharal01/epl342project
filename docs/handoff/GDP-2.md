# Handoff: GDP-2 Data retention purge

Lock: active since 2026-11-21 16:47 UTC

Branch: task/GDP-2-retention
Doc: docs/07-gdpr-and-retention.md
Status: in progress

## Next step
Write sp_retention_purge / sp_retention_preview / fn_retention_cutoff in sql/procs_gdpr.sql, then tests.

## Done so far
- Claimed.

## Blockers / open questions

## How to test
python sql/tools/build_all.py --tests, then run sql/build/ALL.sql on a test database.
