# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins
> (see [CLAUDE.md](../CLAUDE.md), section 1 step 2). Replace the whole file each time.

**Written:** 2026-11-21, end of a parallel-agents session (stopped early: usage limit)
**Branch of this note:** `task/CON-7-no-dbo`

## Tested and in PRs (real department server, full clean rebuild, 0 FAIL)

| PR | Task | OK checks | Stacked on |
|---|---|---|---|
| #7 | REL-0 docs restructure | links | — **conflicts with main (PR #6 plan audit)** |
| #8 | CON-7 no `dbo.` | 37 | #7 |
| #9 | TEC-1 technician registration | 62 | #8 |
| #10 | ADM-2 admin users | 80 | #8 |
| #11 | TSO-1 tree, locate | 72 | #8 |
| #12 | DSO-1 ingestion | 76 | #8 |
| #13 | MKT-1/2/3 market aggregates | 84 | #8 |
| #14 | GDP-1 GDPR flow | 84 | #8 |
| #15 | CON-2 consumer readings | 66 | #8 |
| #16 | TEC-5 field tasks | 115 | #9 |
| #17 | TSO-2/3/4 state, aggregates, load shed | 112 | #11 |

## Written, not yet tested

- Finished by their workers: `task/ADM-3-catalogs` (ADM-3 + ADM-4 pages), `task/GDP-2-retention`.
- Stopped right after claiming (nothing built yet): `task/DSO-2-vee` (VEE ★), `task/CON-3-thresholds`, `task/TEC-2-docs-approval`
  (no commit yet), `task/MKT-4-pages` (no commit yet), `task/DAT-1-large-data` (no commit yet). Their worker briefs are in
  this session's history; re-brief from the task rows and component docs.

## Database state

The member's own database was last rebuilt from `task/TSO-2-state-shed` (all OK). Every test run rebuilds it from scratch.

## Next actions

1. **Fix PR #7's conflict.** `main` got PR #6 (plan audit: per-area requirement checklists, Σ7–Σ8, Α14–Α19, E7 `select.sql`/`import.sql`,
   E8 one a/b/c document, defaults for the professor questions). Merge `origin/main` into `task/REL-0-docs-restructure` and **port**
   that content into the new docs (X7–X8 and B14–B19 in `docs/19-conventions.md`, new rows REL-5/DOC-4, checklists in each component
   doc), keeping the old Greek files deleted and no person names. A supervisor started this and was stopped; its partial merge was aborted.
2. Merge in order #7 → #8 → #9…#17 (the human asked the AI to merge). If GitHub reports a conflict, merge `main` into that branch first.
3. Test `task/ADM-3-catalogs` and `task/GDP-2-retention`; open their PRs.
4. Restart the stopped tasks, highest value first: DSO-2 (VEE ★), TEC-2/3/4 (approval ★), DAT-1 (large data, 7 points), CON-3/6, MKT-4.
5. **Requested improvement:** when a member types `start`, their task must be visibly marked as taken, so two members never pick the same
   task. Today the claim is the pushed `task/<ID>-*` branch plus `Lock:` in its handoff note (CLAUDE.md §2), and `start` checks both.
   Make it visible on `main` too (for example a one-line claim in a shared `docs/claims.md`), and agree it with the group.

## Warnings

- Workers never touch the database; the coordinating session runs `run_sql.ps1`, whose lock stops runs from overlapping.
- Worktrees live in `C:\Users\apier\Desktop\342\wt\<ID>` (the built-in agent worktrees fail on this machine: `c:` vs `C:`).
- `gh` is at `C:\Program Files\GitHub CLI\gh.exe`. Never put a password on a command line.
