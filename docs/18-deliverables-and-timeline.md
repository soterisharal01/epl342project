# 18. Deliverables and timeline

[← Back to the menu](../README.md) · Tasks: DOC-*, REL-* in [tasks.md](tasks.md)

## Deadline

**Friday 4/12/2026, 12:00** on Moodle. Our target: **before 11:00**.

## What we hand in (spec section V.A)

| Folder in `12.zip` | Content | From the repo |
|---|---|---|
| `sources/` | All PHP, HTML, CSS, JS, **and the libraries it needs** (e.g. Leaflet copied into `sources/js/`, not only from a CDN), so the zip works on its own | `sources/` (without `config.php`) |
| `sql/` | Every `.sql`, with the **recognisable names** the spec gives as examples: `create.sql`, `drop.sql`, `import.sql` (loads the large set, DAT-4), `select.sql` (the main queries of every role and the analytics, DAT-5), `indexes.sql`; plus our `procs_*.sql` and `tests/` | `sql/` |
| `data/` | `.dat` files that can be imported: a small set and a large set with thousands of rows | `data/` |
| `docx/` | (a) **User manual:** how to use it, design choices, extra features, difficulties, **final ER**, data dictionary, limitations and improvements. (b) **One separate document** with three chapters: (a) contention points and how we handle them, (b) security, (c) future extension, including the 3 indexes, the before/after case and the 10,000-request test (DOC-4). Only `docx/` is handed in printed. | Written as Markdown in `docs/`, converted at the end. Manual: [21-user-manual.md](21-user-manual.md) (DOC-1) |

**Exam:** on a date announced on Moodle, **every member** presents design and implementation. An absent member gets zero.
Graded: correct ER and schema, correct behaviour, performance and concurrency, extent of implementation, originality.

## Timeline

| Day | Work |
|---|---|
| Sat 21/11 | Foundation done. Everyone: GitHub, SSMS, VPN, drop + create on own database. |
| Sun 22/11 | Procedure lists for every area in PRs (name, parameters, result). |
| Mon 23/11 | Small data per area. `data/small/` runs on a clean database. |
| Tue 24 – Thu 26/11 | Procedures: consumers; technicians and meters; ingestion → VEE → validated. Every procedure has a test. |
| Fri 27/11 | GDPR, admin/operator, market procedures, aggregates, TSO. **Last day for schema changes.** |
| Sat 28 – Sun 29/11 | PHP pages. **Milestone:** every role logs in and sees its ★ screens. |
| Mon 30/11 | Integration on the demo database (`sharal01`) and its `public_html`. Large data. `import.sql` runs clean. |
| Tue 1/12 | Indexes, SQL injection check, 10,000-request test, before/after. |
| Wed 2/12 | Documents, new ER and data dictionary. **Code freeze in the evening.** |
| Thu 3/12 | Zip, printing, clean-database test, **30-minute demo rehearsal**. |
| **Fri 4/12** | **Submit before 11:00.** |

Calls: 21/11 (30 min, plan), 26/11 (15 min, status), 30/11 (integration), 3/12 (rehearsal).

## Demo script (30 minutes)

1. **Consumer:** premises → current-month readings (import/export) → fault request → invoices → GDPR request.
2. **Operator:** approve a technician → task from the request → assign it.
3. **Technician:** accept → install a meter → Operator confirms → it becomes Active.
4. **DSO:** ingest a JSON packet → VEE (spike caught, gap estimated) → validated → aggregates.
5. **TSO:** tree with totals per level → current state → load shedding (and the map, if done).
6. **Supplier / Aggregator:** Day-Ahead (daily) and Intraday (provisional).
7. **Admin:** final GDPR approval → what was erased and what was kept → log.

## Open questions for the professor (one email)

Until he answers, the default after each question applies, so nobody waits.

1. May we run `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON` on our department database, or use `SNAPSHOT` isolation? *Default: no; `READ COMMITTED` with hints (`UPDLOCK`, `READPAST`) and `sp_getapplock`.*
2. Is an `import.sql` of INSERTs enough for ".dat files that can be imported", given that `BULK INSERT` cannot see our files? *Default: yes (B8).*
3. Intraday provisional aggregates: enough to compute them on demand from raw, or must they be stored? *Default: on demand (MKT-3).*
4. Confirm that a day is enough as the smallest stored period for transformer aggregates (month and quarter come from it). *Default: yes.*
5. **Technical losses (II.C):** we have no meter at the transformer input. Is an estimate enough (fixed no-load loss + a share of the energy through the transformer), or should we model an input meter? *Default: estimate with parameters (DSO-5).*
6. **GDPR and retention:** are the "right to be forgotten" and the 1-month retention **one** request, and does the account stay with anonymised data afterwards? *Default: one request; the account stays anonymised; invoices, payments and aggregates stay (B17).*
7. **What retention deletes:** are the "raw 15-minute readings" deleted after 3 years only the raw rows, or also the consumer's validated 15-minute rows? *Default: both; only aggregates stay (B17).*
8. **Current state (III.4.2):** for history you said aggregates on leaves only. For the current-state intermediate table we keep a row for the whole hierarchy (as the spec says, with ancestor updates). Is that right? *Default: yes (B16).*
9. **Exam:** when is the exam date, and when is the detailed grading guide (section VI) published?

## Final checklist (3/12)

- [ ] On a **clean** database, with no errors: `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → `data/small/*.sql` → `sql/import.sql`.
- [ ] `sql/` has the spec's file names: `create.sql`, `drop.sql`, `import.sql`, `select.sql`, `indexes.sql`. `data/` has the `.dat` files.
- [ ] Every line of the **Spec checklists** (docs 05–11 and section 8 of [19-conventions.md](19-conventions.md)) is ticked.
- [ ] `sources/` works on its own from the zip (libraries such as Leaflet inside), without `config.php`.
- [ ] Every role has a demo user and all its ★ features work from the UI.
- [ ] Raw → VEE → validated → aggregates visible in the DSO UI, with a spike and a gap estimate.
- [ ] Transformer tree with totals per level, and load shedding, visible in the TSO UI.
- [ ] GDPR runs end to end and invoices are kept.
- [ ] Thousands of rows in `data/`, 3 indexes in `indexes.sql`, one before/after case with a screenshot.
- [ ] 10,000-request results (95% < 2 s) in the performance/concurrency document.
- [ ] `docx/`: manual (instructions, design choices, extra features, difficulties, final ER, data dictionary, limitations/improvements) and **one** separate document with (a) contention, (b) security, (c) extension (DOC-4).
- [ ] No password in the zip or the repo.
- [ ] `12.zip` with `sources/ sql/ data/ docx/` on Moodle; `docx/` printed.
- [ ] Every member can explain every area, for example a table's `create.sql`, VEE and the GDPR flow.
