# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins
> (see [CLAUDE.md](../CLAUDE.md), section 1 step 2). Replace the whole file each time.

**Written:** 2026-11-21 16:25 UTC
**Branch:** `task/CON-7-no-dbo` (on top of REL-0) · **Open PRs:** #7 (REL-0) and #8 (CON-7), both waiting for another member's review

## What the last session did

- Restructured the repo: no personal ownership, area-based tasks, `start` / `stop` / `finish` protocol, one doc per component.
- Fixed the CS VPN on this machine (profile v5) and added terminal SQL access (`sql/tools/save_credential.ps1`, `run_sql.ps1`).
- Built everything on the member's own database for the first time, found and fixed CON-7 (`dbo.` does not work on the department server).

## Database state (the member's own database on `mssql.cs.ucy.ac.cy\SQL2025`)

- Last run: `build_all.py --drop --tests` → `run_sql.ps1 -File sql/build/ALL.sql -AllowDestructive`.
- Loaded: 56 MDMS tables (+ one lab table `DEPARTMENT`), 20 procedures, 1 function, 4 triggers, base data (10 users, 5 meters, 1,102 raw, 960 validated).
- With the CON-7 branch: `test_common.sql` and `test_consumer.sql` **37/37 OK**, 0 FAIL. Objects live in the user's own schema (for example `apieri01`), not `dbo`.

## Next actions

1. Get PR #7 (REL-0) and then #8 (CON-7) reviewed and merged by another member, in that order.
2. Claim the first free task in [tasks.md](tasks.md) order: **ADM-2** (admin creates staff users, suspends/activates accounts, views the audit log).
   New task branches should start from `task/CON-7-no-dbo` until #7 and CON-7 are merged, then from `main`.

## Warnings

- Never pass the password on a command line: the safety check blocks it, and it would leak into logs. Use `run_sql.ps1`.
- `gh` on this machine: `C:\Program Files\GitHub CLI\gh.exe` (not on the bash PATH).
