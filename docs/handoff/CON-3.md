# Handoff: CON-3 + CON-6

Lock: free
<!-- "active since 2026-11-22 14:00 UTC" while a session is working; "free" when it stops. -->

Branch: task/CON-3-thresholds
Doc: docs/06-consumers.md
Status: ready for test (👀)

## Next step
Coordinator: run `python sql/tools/build_all.py --tests` against the database and check all CON-3 lines print OK; check the two pages in a browser.
<!-- One concrete action the next session starts with. Example: "write sp_dso_run_vee spike check, then its tests". -->

## Done so far
2026-11-21: sp_consumer_set/remove/list_thresholds, set/list_channels, quality_events (THROW 51200-51208) + ~30 test checks in sql/tests/test_consumer.sql; pages consumer/60_settings.php and 70_events.php; docs/06-consumers.md.
<!-- Newest first. One line per session: date (UTC), what was built, files touched. -->

## Blockers / open questions

## How to test
`python sql/tools/build_all.py --tests`, run `sql/build/ALL.sql`, look for FAIL lines (none expected). The test creates user `test_con3_nophone`.
<!-- Exact commands or SSMS scripts, and what output means success. -->
