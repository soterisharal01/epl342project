# Handoff: TSO-6 Leaflet map (bonus)

Lock: free

Branch: task/TSO-6-map
Doc: docs/10-tso-transformers.md
Status: finished (in review)

## Next step
Run `sql/procs_tso.sql` and `sql/tests/test_tso.sql` on a database (not run yet), open `tso/50_map.php` as tso1.

## Done so far
- 2026-11-21: `sp_tso_map_data`, 5 checks, Leaflet 1.9.4 vendored in `sources/lib/leaflet/`, page `sources/tso/50_map.php`, docs/10 updated.

## Blockers / open questions
None. PHP and SQL were not executed (no database, no php binary in the worker environment).

## How to test
Run procs_tso.sql then test_tso.sql: the new lines say `map data`, all OK. Log in as tso1, open "Χάρτης δικτύου".
