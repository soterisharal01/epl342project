# Handoff: REL-1 Integration on the demo database (release pack for REL-1, REL-3, REL-4)

Lock: free

Branch: task/REL-1-release-pack
Doc: docs/23-release.md
Status: steps 1 to 12 done on `sharal01` (25/11); the click checklist (step 13) is still to do by a person

## Next step
A member clicks through the click checklist of [docs/23-release.md](../23-release.md) (step 13) on the real site, ticks it, and then marks REL-1 ✓ in `docs/tasks.md`.
Before the exam: if anything changed data on `sharal01` (VEE run, GDPR apply, load shed), rebuild it again (steps 3 and 4).

## Done so far
- 2026-11-25 (release on `sharal01`, from `main` at 2d9c6be):
  - `build_all.py --release --drop` → `ALL.sql` run in SSMS on `sharal01`: finished in 2 min 23 s, 0 errors.
  - `verify_release.sql`: every line OK. UsedMB 22.31 (allocated 25.00, cap 27), Query Store off, all large-set counts as expected
    (1025 / 1100 / 1000 / 2400 / 1600 / 30912 / 30912 / 322 / 280, base users 10), the three indexes exist, the eight demo users exist.
  - `select.sql`: ran to the end, no `refused` and no SQL error.
  - Web: fresh `git clone --depth 1` of `main` on the lab machine into `~/mdms_src`; `sources/` copied to a new `~/public_html/mdms/`;
    the old folder moved to `~/mdms_old_2511` (not deleted); the existing `config.php` (template unchanged since 21/11) kept; folders 755, files 644.
  - `smoke_site.py https://students.cs.ucy.ac.cy/~sharal01/mdms/ --insecure` from the lab machine: 53 pages opened, 0 problems.
    (The site is reachable only inside the CS network or VPN.)
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
