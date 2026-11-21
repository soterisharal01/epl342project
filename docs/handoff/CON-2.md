# Handoff: CON-2 Consumer readings

Lock: free

Branch: task/CON-2-readings
Doc: docs/06-consumers.md
Status: finished (in review)

## Next step
Coordinator runs the full build + tests (`python sql/tools/build_all.py --tests`, then run_sql on ALL.sql) and checks the CON-2 block of OK lines (29 expected when the current month is Nov 2026; tests that depend on the base data month print an OK "skipped" line otherwise).

## Done so far
- Procedures appended to sql/procs_consumer.sql: fn_consumer_meters, sp_consumer_readings, sp_consumer_history, sp_consumer_buy_history, sp_consumer_list_purchases (THROW 51100-51112).
- Tests appended to sql/tests/test_consumer.sql (29 checks, before the final PRINT).
- Page sources/consumer/50_readings.php (not syntax-checked, PHP not installed).
- docs/06-consumers.md updated; tasks.md row set to review.

## Blockers / open questions
- Nothing was run against the database.
- Design choices: aggregates (Day/Month/Year) are free and unlimited; readings range max 31 days, `[From, To)`; purchasing the current or a future month is refused; overlap with an earlier purchase of the same premise is refused; a past meter's history is visible while the user holds the premise today.
- The page lists only currently installed meters (sp_consumer_list_meters), so a replaced meter's history is reachable by the procedures but not from the page.

## How to test
`python sql/tools/build_all.py --tests`, then `powershell -ExecutionPolicy Bypass -File sql/tools/run_sql.ps1 -File sql/build/ALL.sql`. All lines starting with `OK` and none with `FAIL` in the CON-2 section.
