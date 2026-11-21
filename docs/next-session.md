# Next session

> Written by `finish` at the end of every session and read first by `start`. The newest copy on any branch wins.

**Written:** 2026-11-22 · Merged this session: #35 DOC-1 user manual, #41 DOC-2 ER diagrams, #42 release pack (REL-1/3/4 prep), REL-2 rehearsal (this PR).

## State
All build work is done: every area's procedures, tests, pages, data sets, indexes, security check, 10,000-request test,
user manual (50 screenshots), final ER + relational diagrams, data dictionary, separate document, release runbook,
demo script, zip builder. Only the human steps below remain.

## REL-2 result (22/11, member database `apieri01`)
`python sql/tools/build_all.py --release --drop` then `run_sql.ps1 -File sql/build/ALL.sql -AllowDestructive`: exit 0.
`verify_release.sql`: all OK (16.7 MB of 27, Query Store off, large-set counts, 3 indexes, 8 demo users).
`select.sql`: 0 errors. `smoke_site.py` on the local demo: 53 pages, 0 problems. Screenshots retaken (`shoot.py`).
`make_zip.py`: `12.zip` 13.3 MB, 137 files, no `config.php`, two docx with images.

## Next actions (need people)
1. **REL-1 (owner of `sharal01`):** follow [docs/23-release.md](23-release.md): release build, `verify_release.sql`,
   `select.sql`, deploy `sources/` to `~sharal01/public_html/mdms` (web host name: from the Lab 7 handout), `smoke_site.py` on the deployed URL.
2. **REL-3 (team, 3/12):** fill Presenter 1-4 in [docs/24-demo-script.md](24-demo-script.md), rehearse, time it; rebuild the demo DB after the rehearsal.
3. **REL-4 (4/12 before 11:00):** `python sql/tools/make_zip.py`, open the zip, print `build/docx/`, upload `12.zip` to Moodle (check the size limit; 13 MB now).

## Database state
`apieri01`: clean release build (no tests) + base + large set, Query Store OFF. Local demo: WSL PHP on port 8342 (doc 02).
