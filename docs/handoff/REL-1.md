# Handoff: REL-1 Integration on the demo database (release pack for REL-1, REL-3, REL-4)

Lock: free

Branch: task/REL-1-release-pack
Doc: docs/23-release.md
Status: finished (in review); the pack is ready, **the human steps on `sharal01` are still to do**

## Next step
The owner of the `sharal01` account follows [docs/23-release.md](../23-release.md) section 1 (steps 1 to 13) and ticks the click checklist. Then records the result here and marks REL-1 done in `docs/tasks.md`.

## Done so far
- 2026-11-22: `build_all.py --release [--drop]` (create, procs, indexes, base data, `import.sql`; no tests), `sql/tools/verify_release.sql` (space, Query Store, counts, indexes, demo users), `sql/tools/smoke_site.py` (8 roles, every menu page; local demo: 53 pages, 0 problems), `sql/tools/make_zip.py` (REL-4, builds `12.zip` and two Word files, refuses on secrets), `docs/23-release.md` (runbook, REL-4 checklist), `docs/24-demo-script.md` (REL-3, 30 minutes, questions and answers).

## Blockers / open questions
- Nothing was run against a database. `verify_release.sql` and the release `ALL.sql` are untested on SQL Server.
- The host name for scp/WinSCP to the CS web space is not in our docs (doc 02 names the lab machine `101ws3.in.cs.ucy.ac.cy` for Remote Desktop). The owner uses what Lab 7 gave.
- Docs 21 (manual) and 22 (ER) were not merged when this was written: `make_zip.py` skips them with a warning. Build the zip again after their PRs merge.
- The demo script needs the team to fill in who is Presenter 1 to 4 (everyone presents an area they did not build) and to time it on 3/12.

## How to test
- `python sql/tools/build_all.py --release --drop` writes `sql/build/ALL.sql` (13 files). Default and `--tests` output unchanged.
- `MDMS_DEMO_PASSWORD=<demo password> python sql/tools/smoke_site.py <base url> [--insecure]` ends with `0 problem(s)`.
- `python sql/tools/make_zip.py` prints a manifest and writes `12.zip` (git-ignored); `--check-only` runs only the secret scan.
