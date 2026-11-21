# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins.

**Written:** 2026-11-21 19:55 UTC · Merged this session (at the human's request): #36 TEC-6..10, #37 DAT-5, #38 SEC-1, #39 board marks, #40 PRF-4. Open: #35 (DOC-1 draft).

## What this session did
- DOC-1: first draft of `docs/21-user-manual.md` (task stays ○, PR #35 is a draft).
- TEC-6..10: with the human's OK, after checking the branch was idle (lock free, last push ~1 h earlier, no PR), merged main and
  fixed the one failing test (a test bug); opened PR #36.
- DAT-5: `select.sql` part 2, E01–E37 (PR #37). SEC-1: `check_pages.py` + `test_security.sql` (PR #38).
- PRF-4: fixed `sql/perf/before_after.sql`, measured (VEE Pending 244 -> 5 reads), `sql/perf/perf_10000.py` 100% < 2 s.
- Cleaned stale rows in `docs/claims.md` on main. Rule from the human: take only tasks that can be fully finished now.
- Everything left needs the human or a running app (REL-1 onward, DOC-1, DOC-2).

## Open PRs
| Task | Branch | State |
|---|---|---|
| DOC-1 user manual | `task/DOC-1-user-manual` | DRAFT (PR #35). Task stays ○: finish when the app is complete (screenshots, TEC sections 3.4/3.5/4.5, DOC-2 ER, final label check) |

## Next actions
1. REL-1: build on `sharal01` without tests + `sql/import.sql`, deploy `sources/` to `~sharal01/public_html/mdms` (needs the human).
2. With the app running: DOC-1 TEC sections and screenshots; `before_after.sql` in SSMS with Ctrl+M for the plan screenshots (doc 14).
3. DOC-2 final ER (ERD+) from the final `create.sql`.
4. REL-2 clean rehearsal, REL-3 demo rehearsal, REL-4 zip and upload.

## Database state
Only local Docker databases were used this session. Member database `apieri01` as described by the previous session (rebuilt without tests + base + large set).
