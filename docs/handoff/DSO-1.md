# Handoff: DSO-1 Ingest JSON packet

Lock: free

Branch: task/DSO-1-ingest
Doc: docs/09-dso-ingestion-vee.md
Status: finished (in review)

## Next step
The coordinator runs the full build and tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`) and expects 39 `OK` lines from `test_dso.sql`, no `FAIL`. Then DSO-2 (VEE) can start.

## Done so far
- 2026-11-21 (UTC): `sql/procs_dso.sql` (sp_dso_assert, sp_dso_ingest_packet, sp_dso_list_packets, sp_dso_list_raw), `sql/tests/test_dso.sql` (39 OK checks), `sources/dso/10_ingest.php`, `docs/09-dso-ingestion-vee.md`, tasks row set to 👀. Written without running anything against a database (not tested yet).

## Blockers / open questions
- Not run on SQL Server yet: first run may expose syntax slips.
- `sp_dso_ingest_packet` never throws for a bad packet (it records it and returns the status); only the role check throws (53000).
- Zero usable readings for a known active meter = `Partially accepted`, `ReadingsStored = 0` (documented in doc 09).
- The PHP page passes the JSON as a plain string parameter: non-ASCII JSON text is not expected (appendix JSON is ASCII).

## How to test
`python sql/tools/build_all.py --tests`, then run `sql/build/ALL.sql` on a clean database. Success = 39 `OK ...` lines for DSO-1 and no `FAIL`. The test file writes 2026-11-21 rows, so a second run on the same database reports duplicates as FAIL: rebuild first.
