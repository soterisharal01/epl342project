# 18. Deliverables and timeline

[← Back to the menu](../README.md) · Tasks: DOC-*, REL-* in [tasks.md](tasks.md)

## Deadline

**Friday 4/12/2026, 12:00** on Moodle. Our target: **before 11:00**.

## What we hand in (spec section V.A)

| Folder in `12.zip` | Content | From the repo |
|---|---|---|
| `sources/` | All PHP, HTML, CSS, JS | `sources/` (without `config.php`) |
| `sql/` | Every `.sql`: `create.sql`, `drop.sql`, procedures, `indexes.sql`, `select.sql` and so on | `sql/` |
| `data/` | `.dat` files that can be imported: a small set and a large set with thousands of rows | `data/` |
| `docx/` | (a) **User manual:** how to use it, design choices, extra features, difficulties, **final ER**, data dictionary, limitations and improvements. (b) **Separate document:** contention points, security, future extension. Also printed for the lab. | Written as Markdown in `docs/`, converted at the end |

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

1. May we run `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON` on our department database, or use `SNAPSHOT` isolation?
2. Is an `import.sql` of INSERTs enough for ".dat files that can be imported", given that `BULK INSERT` cannot see our files?
3. Intraday provisional aggregates: enough to compute them on demand from raw, or must they be stored?
4. Confirm that a day is enough as the smallest stored period for transformer aggregates (month and quarter come from it).

## Final checklist (3/12)

- [ ] On a **clean** database, with no errors: `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → `data/import.sql`.
- [ ] Every role has a demo user and all its ★ features work from the UI.
- [ ] Raw → VEE → validated → aggregates visible in the DSO UI, with a spike and a gap estimate.
- [ ] Transformer tree with totals per level, and load shedding, visible in the TSO UI.
- [ ] GDPR runs end to end and invoices are kept.
- [ ] Thousands of rows in `data/`, 3 indexes in `indexes.sql`, one before/after case with a screenshot.
- [ ] 10,000-request results (95% < 2 s) in the performance/concurrency document.
- [ ] `docx/`: manual (final ER, data dictionary, assumptions) and the separate document (contention, security, extension).
- [ ] No password in the zip or the repo.
- [ ] `12.zip` with `sources/ sql/ data/ docx/` on Moodle; `docx/` printed.
- [ ] Every member can explain every area, for example a table's `create.sql`, VEE and the GDPR flow.
