# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins.

**Written:** 2026-11-21 18:50 UTC · Open PRs from this session: #35 (DOC-1 draft), #36 (TEC-6..10), #37 (DAT-5), #38 (SEC-1)

## What this session did
- DOC-1: first draft of `docs/21-user-manual.md` (task stays ○, PR #35 is a draft).
- TEC-6..10: with the human's OK, after checking the branch was idle (lock free, last push ~1 h earlier, no PR), merged main and
  fixed the one failing test (a test bug); opened PR #36.
- DAT-5: `select.sql` part 2, E01–E37 (PR #37). SEC-1: `check_pages.py` + `test_security.sql` (PR #38).
- Cleaned stale rows in `docs/claims.md` on main. Rule from the human: take only tasks that can be fully finished now.
- After this, nothing on the board is fully finishable without the human: what is left needs PR #36 merged, the large data on a
  member database (PRF), screenshots from a running app (DOC-1), or the demo account `sharal01` (REL-1).

## Open PRs
| Task | Branch | State |
|---|---|---|
| TEC-6..10 meter install ★, confirm ★, commands, anti-tamper, pages | `task/TEC-6-install` | **PR #36**: main merged, test bug fixed, 748 OK / 0 FAIL locally. Review and merge. |
| DAT-5 select.sql EXEC list | `task/DAT-5-select-exec` | **PR #37**, 0 errors on a clean build |
| SEC-1 page check | `task/SEC-1-page-check` | **PR #38**, checker 0 FAIL, test_security 18 OK, ALL OK |
| DOC-1 user manual | `task/DOC-1-user-manual` | DRAFT only (PR #35). Task stays ○: finish after TEC-6 merges and the app is complete (screenshots, TEC sections, DOC-2 ER, final label check) |

## Next actions
1. DOC-1 is a draft: merge PR #35 only as a draft; the task is finished at the end (REL stage).
2. Merge TEC-6 (PR #36); then update manual sections 3.4, 3.5, 4.5 with the real TEC pages.
3. After #36 merges: rerun `python sql/tools/check_pages.py` and `bash sql/tools/test_local.sh` on main (SEC-1).
4. PRF: run `sql/perf/before_after.sql` with the large set loaded, fill docs/14; PRF-4 10,000-request test.
5. DOC-1 screenshots from the local demo; DOC-2 final ER.
6. REL-1 integration on `sharal01`; REL-2 clean rehearsal; REL-3 demo rehearsal; REL-4 zip.

## Database state
Only local Docker databases were used this session. Member database `apieri01` as described by the previous session (rebuilt without tests + base + large set).
