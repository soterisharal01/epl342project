# 23. Release: demo database, web deploy, zip

[← Back to the menu](../README.md) · Tasks: REL-1, REL-2, REL-3, REL-4 in [tasks.md](tasks.md) · Demo script: [24-demo-script.md](24-demo-script.md)

> **Status: pack ready, needs the human.** Everything below was prepared without access to the department account.
> Nothing here has been run against `sharal01` yet. The scripts that can run locally were tested locally (see "What was tested").

The demo runs on the team demo database `sharal01` and the web space `~sharal01/public_html/mdms`. We do **not** have its
password, so a team member who owns that account does the steps. The scripts are the same ones everybody already uses.

## 1. REL-1: build the demo database

Who: the owner of `sharal01`. Where: Windows, in the repo, on `main` after all PRs are merged (`git pull`).

1. **VPN.** Connect the **CS department** VPN (profile `CSVPNv5`, see [02](02-environment-setup.md) section 1). The tray icon must be green.
2. **Save the login once** (skip if `%USERPROFILE%\.mdms_sql.xml` exists): `powershell -ExecutionPolicy Bypass -File sql\tools\save_credential.ps1`. Use the `sharal01` SQL login. The password stays on this PC (encrypted), never in the repo.
3. **Generate the release script** (nothing runs yet):
   `python sql/tools/build_all.py --release --drop`
   It writes `sql/build/ALL.sql` with this order: `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → `data/small/00_base.sql` → `sql/import.sql`. It has **no tests** and not the extra small files (the 27 MB cap), and it turns Query Store off at the start. Without `--drop` the drop is left out (for a database that is already empty).
4. **Run it** on the demo database. Only the owner, and only on `sharal01`:
   `powershell -ExecutionPolicy Bypass -File sql\tools\run_sql.ps1 -File sql\build\ALL.sql -AllowDestructive -Timeout 1200`
   (or open `ALL.sql` in SSMS with `sharal01` selected top left and press Execute). It stops at the first error. If it stops: read the message, do not edit `ALL.sql` by hand, tell the team, fix in the repo, run again from step 3 (the `--drop` makes the run repeatable).
5. **Check the result** (read-only; every line must say `OK`):
   `powershell -ExecutionPolicy Bypass -File sql\tools\run_sql.ps1 -File sql\tools\verify_release.sql`
   It reports: used space (must be under **27 MB**), Query Store off, row counts of the large set, the three indexes, and the eight demo users.

| Check | Expected |
|---|---|
| `UsedMB` | under 27 (the large set needs about 7 MB, system objects about 16.5 MB) |
| Query Store | off |
| USER_ACCOUNT (large, ID ≥ 100000) | 1,025 |
| PREMISE (large) | 1,100 |
| METER (large) | 1,000 |
| INVOICE (large) | 2,400 |
| PAYMENT (large) | 1,600 |
| RAW_READING / VALIDATED_READING (large meters) | 30,912 each |
| METER_AGGREGATE (large) | 322 |
| TELEMETRY_PACKET (large) | 280 |
| Base users | 10 |
| Indexes | `IX_INVOICE_User_IssueDate`, `IX_FIELD_TASK_Technician_Status`, `IX_RAW_READING_Pending` |

   The same numbers are in [13](13-data-sets.md). If the space is over the cap, Query Store is probably on:
   `ALTER DATABASE CURRENT SET QUERY_STORE = OFF; ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;`. The one-line check by hand:
   `SELECT SUM(FILEPROPERTY(name,'SpaceUsed'))*8/1024.0 AS UsedMB FROM sys.database_files WHERE type_desc='ROWS'`.
6. **Smoke queries:** `powershell -ExecutionPolicy Bypass -File sql\tools\run_sql.ps1 -File sql\select.sql`. It changes nothing. Expected: runs to the end with no error and no refused call ([13](13-data-sets.md), `select.sql`). Paste any error into the PR.

### Deploy the web app

7. **Zip the app** (no `config.php` exists in the repo): `Compress-Archive -Path sources\* -DestinationPath build\mdms.zip -Force` (PowerShell, from the repo root).
8. **Copy it to the department web space.** Use a lab machine over Remote Desktop (for example `101ws3.in.cs.ucy.ac.cy`, see [02](02-environment-setup.md) section 3) with the CS VPN on, or WinSCP/scp to the CS login host from the lab handout (the host name is not in our docs: ask the lab handout, it is the one used in Lab 7). Target folder: `~sharal01/public_html/mdms/`.
   On the server: `mkdir -p ~/public_html/mdms && cd ~/public_html/mdms && unzip -o ~/mdms.zip && rm ~/mdms.zip`.
9. **Create `config.php` by hand on the server** (never in git, never in chat): `cp config.example.php config.php`, edit it: `Database` and `Uid` = `sharal01`, `PWD` = the password, `serverName` stays `mssql.cs.ucy.ac.cy\SQL2025`, `debug` = `false`.
10. **Permissions:** `find ~/public_html/mdms -type d -exec chmod 755 {} +` and `find ~/public_html/mdms -type f -exec chmod 644 {} +` (including `config.php`: with 600 the page gives HTTP 500, see [12](12-php-web-app.md)). This password must not be used anywhere else.
11. **Open** `https://students.cs.ucy.ac.cy/~sharal01/mdms/` in a browser. A **403** usually means a SQL error (server name without `\SQL2025`, wrong password) or a file with the wrong permissions.
12. **Smoke test the site** (logs in as the eight demo roles and opens every menu page, read-only). In PowerShell:
    `$env:MDMS_DEMO_PASSWORD = '<demo password, header of data/small/00_base.sql>'; python sql/tools/smoke_site.py https://students.cs.ucy.ac.cy/~sharal01/mdms/ --insecure`
    Expected: `0 problem(s)`. A `FAIL` line names the user and page. The script fails a page on any HTTP status other than 200, on PHP warning/notice/fatal text and on raw SQL Server error text. (`--insecure` is the same as `curl -k`; the department certificate may fail Python's check.)
13. **Click checklist** below. Every role once, on the real site, as a person (not only the script).

### Click checklist per role

Password for every demo user: the test password in the header of `data/small/00_base.sql`. Tick when it works.

- [ ] **Consumer** (`consumer1`): "Τα υποστατικά μου" lists premises; "Μετρήσεις" shows 15-minute readings (import and export); "Αιτήματα ελέγχου / βλάβης" lets you submit; "Τιμολόγια και πληρωμές" shows invoices; "Δικαίωμα στη λήθη" shows the request form. Log out.
- [ ] **Operator** (`operator`): "Έγκριση τεχνικών" lists `tech2` as Pending; "Εργασίες πεδίου" opens; "Επιβεβαίωση μετρητών" lists the pending meter; "Αιτήματα GDPR" opens; "Κατάλογοι" opens.
- [ ] **Technician** (`tech1`): "Οι εργασίες μου", "Εγκατάσταση μετρητή", "Διαθεσιμότητα", "Εντολές" open. (`tech2` must be refused at login: Pending.)
- [ ] **DSO** (`dso1`): "Εισαγωγή πακέτου" shows the example JSON and recent packets; "VEE" shows suspect readings; "Aggregates" opens; "Συμβάντα δικτύου" lists the unmatched packet event.
- [ ] **TSO** (`tso1`): "Δέντρο μετασχηματιστών" shows totals per level; "Τρέχουσα κατάσταση" opens; "Load shedding" opens; "Χάρτης δικτύου" draws the Leaflet map (no blank grey box: the library is inside the app).
- [ ] **Supplier** (`supplier1`): "Day-Ahead" and "Intraday" show totals only, no per-meter rows.
- [ ] **Aggregator** (`aggregator1`): "Day-Ahead", "Intraday", "Χαρτοφυλάκια" open.
- [ ] **Admin** (`admin`): "Χρήστες", "Αρχείο καταγραφής" (login rows of the checks above), "Αιτήματα GDPR", "Διατήρηση δεδομένων" open.
- [ ] A wrong password shows the same message for a wrong user and a wrong password (no user hints).

Record the result in `docs/handoff/REL-1.md` (what failed, what was fixed) and only then mark REL-1 ✓ in [tasks.md](tasks.md).

## 2. REL-2: clean-database rehearsal (reminder)

On 3/12, repeat section 1 steps 3 to 6 from a clean checkout of `main`, **then** the full test run on a personal database (`python sql/tools/build_all.py --drop --tests`, expect `ALL OK` style: only `OK`, no `FAIL`). After any rehearsal that changed data (VEE run, GDPR apply, load shed), **rebuild the demo database** (step 3 and 4) so the exam starts from the clean state: VEE consumes the Pending readings of 20/11 only once.

## 3. REL-3: demo rehearsal

The 30-minute script is in [24-demo-script.md](24-demo-script.md). Rehearse it twice on 3/12 with a timer, once on the real site, then rebuild the database.

## 4. REL-4: build `12.zip` and hand in

Build (any machine with the repo and Python; pandoc comes from `python -m pip install pypandoc_binary`, already tried locally):

```
python sql/tools/make_zip.py
```

It writes `12.zip` in the repo root (git-ignored) and the two Word files in `build/docx/` (git-ignored). `12.zip` contains `sources/`, `sql/`, `data/` and `docx/`:

| Folder | Content |
|---|---|
| `sources/` | The PHP app with Leaflet in `lib/leaflet/`, **without `config.php`**; `config.example.php` is the template |
| `sql/` | `create.sql`, `drop.sql`, `import.sql`, `select.sql`, `indexes.sql`, `procs_*.sql`, `tests/`, `perf/`, `tools/` (not the generated `sql/build/`) |
| `data/` | `small/00_base.sql`, `large/*.dat` (26 files, 78,609 rows in total), `gen/` generators |
| `docx/` | `MDMS-Cy_User_Manual.docx`: docs 21 (manual), 22 (final ER), 20 (data dictionary). `MDMS-Cy_Contention_Security_Extension.docx`: docs 15 (contention), 16 (security), 17 (extension), 14 (indexes, before/after, 10,000-request test) |

The builder prints a manifest, always leaves `config.php`, `.env` and key files out, and **refuses to build** (exit code 2) if a line that looks like a password assignment would go into the zip. Missing documents (for example 21 or 22 while their PRs are open) are skipped with a `WARNING`: **run it again after those PRs are merged** and read the warnings; there must be none. `python sql/tools/make_zip.py --check-only` runs only the scan.

### REL-4 checklist (Thursday 3/12 evening and Friday morning)

- [ ] All PRs merged, `git pull` on `main`, `python sql/tools/make_zip.py` ends with `wrote 12.zip` and **no WARNING** (docs 21 and 22 included).
- [ ] Open `12.zip` in a file explorer: four folders `sources/ sql/ data/ docx/`, no `config.php`, no `.git`, no `__pycache__`.
- [ ] Unzip into a fresh folder and look: `sources/lib/leaflet/leaflet.js` exists, `sql/` has `create.sql drop.sql import.sql select.sql indexes.sql`, `data/large/` has the `.dat` files.
- [ ] Open both Word files: the table of contents is there, tables are readable, images (final ER) are shown, no `[link text](...)` leftovers. Fix the Markdown, rebuild.
- [ ] No password in the zip (the builder checks; also search the Word files for the word "password").
- [ ] **Print `docx/`** (both Word files; only `docx/` is printed, see [18](18-deliverables-and-timeline.md)).
- [ ] **Upload `12.zip` to Moodle before 11:00** on Fri 4/12 (deadline 12:00). Open the submission page afterwards and check the file name `12.zip` and its size.
- [ ] Note the time of upload in `docs/next-session.md`.

## What was tested

| Tool | Result |
|---|---|
| `build_all.py --release --drop` | Generates `ALL.sql` (13 files, no tests, 6.4 MB); the default and `--tests` output is unchanged. Not run against any database. |
| `smoke_site.py` | Run on the local demo (`http://localhost:8342`): 8 roles, 53 pages, 0 problems. The failure detection was checked with a fake PHP warning and a fake HTTP 500. |
| `make_zip.py` | Built `12.zip` locally (1.5 MB without docs 21 and 22); `config.php` is left out even when it exists in the folder; the refusal (exit code 2) was checked with a planted password line. |
| `verify_release.sql`, deploy steps 7 to 13, `select.sql` on `sharal01` | **Not run: needs the owner of `sharal01`.** |
