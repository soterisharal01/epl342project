# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins.

**Written:** 2026-11-21 18:35 UTC · **Branch:** `task/DOC-1-user-manual` (PR open, see below) · **Main:** unchanged by this session except the DOC-1 claim row

## What this session did
- Short session (the human keeps usage for other study). Took **DOC-1** (the only free task whose needs were met) and wrote
  `docs/21-user-manual.md`: per-role how-to from the real pages, design choices, extras, difficulties, ER/dictionary pointers,
  limitations. No SQL or PHP changed, no database run.
- Did **not** touch `task/TEC-6-install` (another member's open work).

## Still open from the previous session (unchanged)
| Task | Branch | State |
|---|---|---|
| TEC-6..10 meter install ★, confirm ★, commands, anti-tamper, pages | `task/TEC-6-install` | **PR #36**: main merged, test bug fixed, 748 OK / 0 FAIL locally. Review and merge. |
| DOC-1 user manual | `task/DOC-1-user-manual` | DRAFT only (PR #35). Task stays ○: finish after TEC-6 merges and the app is complete (screenshots, TEC sections, DOC-2 ER, final label check) |

## Next actions
1. DOC-1 is a draft: merge PR #35 only as a draft; the task is finished at the end (REL stage).
2. Merge TEC-6 (PR #36); then update manual sections 3.4, 3.5, 4.5 with the real TEC pages.
3. PRF: run `sql/perf/before_after.sql` with the large set loaded, fill docs/14; PRF-4 10,000-request test.
4. SEC-1 page-by-page injection/access check; DOC-1 screenshots from the local demo; DOC-2 final ER.
5. REL-1 integration on `sharal01`; REL-2 clean rehearsal; REL-3 demo rehearsal; REL-4 zip.
6. `docs/claims.md` on main still has stale rows (DSO-2, CON-3 twice, TEC-2 twice, MKT-4 twice, ADM-3, GDP-2) for merged tasks: delete them (`unclaim:` commit).

## Database state
Not touched this session. Member database `apieri01` as described by the previous session (rebuilt without tests + base + large set).
