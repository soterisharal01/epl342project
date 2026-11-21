# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins.

**Written:** 2026-11-21 (end of a long parallel session) · **Main:** all reviewed work merged, full suite 652 OK / 0 FAIL

## Done today (merged into main)
Every area's procedures, tests and pages except the TEC-6..10 block: consumers, admin and catalogs, GDPR + retention + pages,
technicians (registration, documents, availability, approval, field tasks), market (Day-Ahead, Intraday, portfolios, pages),
DSO (ingestion, VEE, aggregates, analytics, pages), TSO (tree, state, aggregates, load shedding, Leaflet map), 3 indexes,
data dictionary, `select.sql`, the separate document (contention, security, extension), claims + lanes rules.

## In review (claimed, not merged)
| Task | Branch | State |
|---|---|---|
| TEC-6..10 meter install ★, confirm ★, commands, anti-tamper, pages | `task/TEC-6-install` | 746 OK / **3 FAIL** in test "doc foreign meter" (the installation was already decided by the Operator earlier in the test, so the check fires 52330-style instead of the expected error) — fix the test order or expected number, rerun, merge |
| DAT-1..4 large data set (78,609 rows, ~7 MB) | `task/DAT-1-large-data` | earlier versions hit the 27 MB cap; Query Store was the real culprit and is now off. Load `sql/import.sql` after a build without tests, check counts, merge |

## Next actions
1. Fix and merge TEC-6; load-test and merge DAT-1.
2. PRF: run `sql/perf/before_after.sql` with the large set loaded, fill the numbers in docs/14 (with SSMS plan screenshots); PRF-4 10,000-request test.
3. SEC-1: SQL-injection/access check of every page (run each page in the local demo).
4. DOC-1 user manual (per role, screenshots from the local demo), DOC-2 final ER (ERD+), DAT-5 `select.sql` EXEC list if still needed.
5. REL-1 integration on `sharal01` (Sotiris's account): build without tests + `sql/import.sql`; REL-2 clean rehearsal; REL-3 demo rehearsal; REL-4 zip.

## Database state
Member database `apieri01`: Query Store OFF; rebuilt for the local demo from main **without tests** + base data + the large set.

## Local demo
WSL Ubuntu has PHP 8.3 + msodbcsql18 + sqlsrv. Start: `wsl -d Ubuntu -- php -S 0.0.0.0:8000 -t /mnt/c/Users/apier/Desktop/342/epl342project/sources`, open http://localhost:8000. Needs `sources/config.php` with the member's own credentials (typed by the member) and the CS VPN.