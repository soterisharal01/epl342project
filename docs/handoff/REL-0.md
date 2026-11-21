# Handoff: REL-0 Docs restructure

Lock: free

Branch: task/REL-0-docs-restructure
Doc: README.md, docs/03-workflow.md, docs/19-conventions.md
Status: finished (in review)

## Next step
Open the PR, get one member's approval, merge. After the merge, every member runs `git pull` and starts sessions with `start`.

## Done so far
- 2026-11-21: Replaced personal ownership with areas. New: `README.md` (brief + menu), `CLAUDE.md` (start/stop protocol),
  `docs/01`–`19` component docs, `docs/tasks.md` (area IDs, old-ID map), `docs/handoff/` (template + notes).
  Moved Phase A files to `docs/phase-a/`. Removed `docs/phase-b/*`, `sql/ALLAGES.md`, `COLLABORATION.md` after moving their content.
  Removed person names and old task IDs from code comments; `config.example.php` now uses `<username>`.
  Agreement X3 corrected: load-shed commands use `CommandType = 'Load shed'` (the CHECK requires it).

## Blockers / open questions
- The group must agree to the new rules (no owners, merge by any non-author, area-based error and ID ranges).

## How to test
- Every Markdown link resolves (checked with a script: 0 broken).
- SQL changes are comment-only: `git diff main -- sql data sources` shows only comment lines and `config.example.php` placeholders.
