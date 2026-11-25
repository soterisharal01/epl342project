# 24. Demo script (30 minutes)

[← Back to the menu](../README.md) · Task: REL-3 in [tasks.md](tasks.md) · Order from [18](18-deliverables-and-timeline.md) · Release steps: [23](23-release.md)

> **Status: script ready, to be rehearsed on 3/12.** Written from the pages and procedures that exist on `main`; it has not been timed with people yet.

## Rules

- Four presenters: **Presenter 1 to 4**. The team fills the names in at the rehearsal. Rule: **everyone presents an area they did not build**, so every member proves they can explain the whole system. If the team has three members, Presenter 4 steps go to Presenters 1 and 2.
- Everyone must be able to answer questions on every step, not only their own. Any member may be asked anything.
- Demo address: `https://students.cs.ucy.ac.cy/~sharal01/mdms/` on the clean demo database (built with [23](23-release.md)). Password for all demo users: header of `data/small/00_base.sql`.
- Two browsers or two profiles (normal and private window) so two roles are logged in at once: switching role takes no time. Log in to all eight roles **before** the demo starts and keep the tabs open (the session lasts the whole demo).
- A second laptop opened on SSMS with `sql/select.sql` and `sql/perf/before_after.sql` as backup evidence.
- Keep one sentence ready per step on **which requirement it shows**. Say it first, then click.

## Before the exam starts (10 minutes before)

1. Clean database: rebuilt after the last rehearsal ([23](23-release.md) steps 3 to 6). The VEE step uses the Pending readings of 20/11, which can be consumed **only once**.
2. `smoke_site.py` says `0 problem(s)`.
3. Tabs open: consumer1, operator, tech1, dso1, tso1, supplier1, aggregator1, admin.
4. Copy the example JSON packet ([09](09-dso-ingestion-vee.md)) to the clipboard, with a `Meter_Network_ID` of an active meter (look it up in `sql/select.sql` or the DSO page "Πρόσφατα πακέτα").
5. Timer visible to the presenter.

## Minute by minute

| Min | Step | Presenter | Role / login |
|---|---|---|---|
| 0:00 to 2:00 | Opening | 1 | none |
| 2:00 to 6:00 | 1. Consumer | 2 | `consumer1` |
| 6:00 to 9:00 | 2. Operator | 3 | `operator` |
| 9:00 to 12:00 | 3. Technician and confirmation | 4 | `tech1`, then `operator` |
| 12:00 to 17:00 | 4. DSO: ingest, VEE, aggregates | 1 | `dso1` |
| 17:00 to 21:00 | 5. TSO | 2 | `tso1` |
| 21:00 to 24:00 | 6. Supplier and Aggregator | 3 | `supplier1`, `aggregator1` |
| 24:00 to 27:00 | 7. Admin and GDPR result | 4 | `admin` |
| 27:00 to 30:00 | Evidence: indexes, concurrency, security | 1 and 2 | SSMS |

Presenter 1 opens and closes, Presenter 2 and 3 carry the middle, Presenter 4 has the two role changes. Swap the numbers if the team prefers, keeping the rule above.

### 0:00 to 2:00, Opening (Presenter 1)

- Say: MDMS-Cy collects 15-minute readings of smart meters, validates them, keeps validated data immutable, aggregates them and serves eight kinds of users. SQL Server 2025, PHP only through stored procedures, 56 tables.
- Show: the login page; one slide or the final ER ([22](22-er-diagram.md)) for 20 seconds.
- Fallback: if the site is down, say so, go to the local copy or to SSMS with `sql/select.sql` (E01 to E37 show every role's main read) and continue with the script there.

### 2:00 to 6:00, 1. Consumer (Presenter 2), shows III.1

Login `consumer1`.
1. "Τα υποστατικά μου": premises and the meter on each. Say: a consumer sees only own data (the procedure takes the user id from the session).
2. "Μετρήσεις": on 3-4/12 the base readings (18-23/11) are a **past** month, so first "Αγορά ιστορικού" for November (shows the paid-history rule and its invoice), then pick 18/11-20/11, "Εμφάνιση". Say: 15-minute import (1.8.0) and export (2.8.0) readings, validated only. "Ιστορικό (αθροίσματα)" shows aggregates: statistics use aggregates, detail only for the entitled.
3. "Αιτήματα ελέγχου / βλάβης": "Νέο αίτημα", choose a premise and type, "Υποβολή". Say: this request is what the operator turns into a task in step 2.
4. "Τιμολόγια και πληρωμές": invoices sorted by date (the index from step 8 serves this page).
5. "Δικαίωμα στη λήθη": "Υποβολή αιτήματος διαγραφής". Say: not an immediate delete; it goes through review, pre-approval and a final admin decision (step 7).
- Fallback: a submit fails with a message → read it aloud (messages are ours, in Greek), show the same list page, continue. If the request cannot be created, use an existing one from the base data in step 2.

### 6:00 to 9:00, 2. Operator (Presenter 3), shows III.1 and III.2

Login `operator`.
1. "Έγκριση τεχνικών": `tech2` is Pending. Say: a technician cannot log in until approved. Press "Έγκριση" for `tech2` only if you want to show the approval; otherwise leave it Pending and say so.
2. "Εργασίες πεδίου": "Νέα εργασία" from the consumer's request, type Installation, assign `tech1`, "Δημιουργία εργασίας". Say: the task, the status and the log row.
3. "Αιτήματα GDPR": find the consumer's request, "Έναρξη εξέτασης" then "Προέγκριση" with a comment. Say: stage 2 of 4; every stage is a row in the log.
- Fallback: task creation refused → read the message; use an existing open task from the base data for step 3.

### 9:00 to 12:00, 3. Technician and meter confirmation (Presenter 4), shows III.2

Login `tech1`.
1. "Οι εργασίες μου": open the new task, "Αποδοχή". Say: only the assigned technician can accept (checked in the procedure).
2. "Εγκατάσταση μετρητή": "Καταχώριση μετρητή" for that premise with a serial and network id from the demo list; add a photo or document if the page offers it. Say: the meter is created as Pending confirmation.
3. "Ολοκλήρωση" of the task.
4. Switch to `operator`, "Επιβεβαίωση μετρητών": "Επιβεβαίωση". Say: the meter becomes **Active**, and only now may telemetry be matched to it.
- Fallback: if the install form refuses, use the base meter that is already "Pending confirmation": confirm it as the operator and say the install form was shown before. Do not debug on stage.

### 12:00 to 17:00, 4. DSO: ingest, VEE, aggregates (Presenter 1), shows III.3

Login `dso1`.
1. "Εισαγωγή πακέτου": paste the JSON packet, "Αποστολή". Say: the packet is stored first, then matched to an active meter; unknown meters become an event, never lost (show the unmatched packet in "Συμβάντα δικτύου" in ten seconds).
2. "VEE": period 20/11/2026 00:00 to 21/11/2026 00:00, "Εκτέλεση VEE". Say: Range, Spike, Gap and linear estimate rules come from tables. Result: the spike of 25.4 at 04:00 is **Suspect**, the missing 02:30 reading is **Estimated** (about 2.1) and marked as such.
3. "Ύποπτες μετρήσεις": show the suspect row, "Διόρθωση" with a new value. Say: the old value, new value and who changed it are kept; validated rows cannot be updated directly (trigger).
4. "Aggregates": "Χτίσιμο aggregates ημέρας" for that day, then "Εμφάνιση". Say: raw → VEE → validated → aggregates.
- Fallback: VEE run says another run is active (53101) → wait 10 seconds and repeat (that is the lock working: show it as a feature). VEE already consumed (rehearsal data) → show the VEE run list and the suspect rows that exist, and explain.

### 17:00 to 21:00, 5. TSO (Presenter 2), shows III.4

Login `tso1`.
1. "Δέντρο μετασχηματιστών": expand the tree. Say: recursive query from the root; totals per level (leaf, middle, root).
2. "Τρέχουσα κατάσταση": "Ανανέωση τρέχουσας κατάστασης". Say: sum of import/export of the latest validated readings per transformer, stored in an intermediate table with ancestors updated.
3. "Load shedding": choose a middle transformer, reason, "Αποστολή εντολής". Say: one order and one command per **active** meter under that node, in one transaction.
4. "Χάρτης δικτύου": the Leaflet map with geofences. Say: Leaflet is bundled inside the app, no CDN.
- Fallback: map blank → skip it (it is a bonus) and show the tree totals; state refresh slow → move on, come back at the end.

### 21:00 to 24:00, 6. Supplier and Aggregator (Presenter 3), shows III.5

Login `supplier1`: "Day-Ahead": daily validated totals; "Intraday": 15-minute provisional totals for today. Say: Day-Ahead waits for VEE, Intraday does not; a supplier sees **only own customers** and **never raw rows**, only sums per transformer.
Switch to `aggregator1`: "Χαρτοφυλάκια": the portfolio and its premises; "Day-Ahead" for the portfolio.
- Fallback: an empty Intraday table → choose the day of the base readings (18 to 20/11) and say why (the table shows the day you pick).

### 24:00 to 27:00, 7. Admin and GDPR result (Presenter 4), shows III.1.4

Login `admin`.
1. "Αιτήματα GDPR": the pre-approved request, "Έγκριση" then "Εφαρμογή". Say: final decision by the admin, then anonymisation.
2. Show what was erased and what was kept: the consumer's account is now `deleted_<id>`, name and e-mail removed, bank accounts removed, **invoices and payments kept**, aggregates kept.
3. "Αρχείο καταγραφής": the log rows of every GDPR stage and of the demo (who, when, old and new status).
4. "Διατήρηση δεδομένων": "Προεπισκόπηση" of the retention purge (3 years, or 1 month after a GDPR request).
- Fallback: apply refused → read the message, show the log and the request list; explain the rule from [07](07-gdpr-and-retention.md).

### 27:00 to 30:00, Evidence (Presenters 1 and 2)

- Indexes (1 minute): three indexes in `sql/indexes.sql`: invoices by user and date, field tasks by technician and status, a filtered index on Pending readings. Before/after: reads 244 → 5 ([14](14-indexes-and-performance.md), `sql/perf/before_after.sql`).
- Concurrency (1 minute): `READ COMMITTED` with `UPDLOCK`, `READPAST` and `sp_getapplock`; ingestion continues while VEE runs ([15](15-concurrency.md)). 10,000 requests: 100% under 2 seconds, p95 about 63 ms.
- Security (30 seconds): procedures with parameters only, role checked twice, CSRF tokens, escaped output, bcrypt ([16](16-security.md)).
- Close: thank the examiners, offer to show any table or procedure.

## Likely questions, short answers

| Question | Short answer |
|---|---|
| Two users change the same thing at the same time? | Every write is one procedure with a transaction. The row is read with `UPDLOCK` and the status is checked inside the transaction, so the second caller sees the new status and is refused (for example a double invoice payment, [15](15-concurrency.md) 3.4). |
| Ingestion and VEE at once? | VEE reads Pending rows `WITH (UPDLOCK, READPAST)`: rows it holds are skipped by ingestion's neighbours; new packets are accepted meanwhile. `sp_getapplock` allows one VEE run at a time (second run gets 53101 at once, no waiting). |
| Which isolation level and why? | `READ COMMITTED` plus explicit hints. We did not enable snapshot isolation on the shared department database (open question to the professor); the hints give the same protection where we need it. |
| Deadlocks? | Fixed lock order across procedures, short transactions, no user interaction inside a transaction ([15](15-concurrency.md) section 4). |
| Which indexes and why? | PRF-1 invoices (user, date) for the consumer list; PRF-2 field tasks (technician, status) for task lists; PRF-3 filtered on Pending readings for VEE. Foreign keys have no automatic index in SQL Server, and the primary keys do not match these queries. |
| Proof an index helps? | Before/after case: reads 244 → 5 on the same query ([14](14-indexes-and-performance.md)). |
| 10,000 requests? | `sql/perf/perf_10000.py`: a mix of read and write procedures, parallel workers, 100% under 2 s, p95 about 63 ms (requirement: 95% under 2 s). |
| How does VEE work? | Rules are rows (`VEE_RULE`, `RULE_FOR`): range from `MinValid`/`MaxValid`, spike (more than 5 times the average of the last 3), gap, linear estimate, voltage band. Pending raw rows become validated, estimated or suspect; every edit keeps old and new value. |
| Why can validated data not change? | A trigger blocks `UPDATE`/`DELETE` on validated readings; corrections go through `READING_EDIT` and a new run. Immutability replaces locking ([15](15-concurrency.md) 3.11). |
| Raw counter vs energy? | Raw 1.8.0 is the meter's cumulative counter; validated is the energy per 15 minutes (decision B2). Intraday uses the difference between consecutive counter readings. |
| GDPR: what is deleted? | Name, e-mail, phone, password hash, bank accounts, channels; the account is anonymised and suspended. Invoices, payments, aggregates and the log stay (legal and statistical need, decision B17). Raw readings older than 1 month are purged after a request, 3 years otherwise. |
| Is deletion immediate? | No: submit, operator pre-approval, admin approval, apply; each stage is logged. |
| SQL injection? | No SQL text in PHP at all: only `call_proc('sp_…', [params])` with `?`. `sql/tools/check_pages.py` checks every page automatically (0 FAIL). |
| XSS and CSRF? | Every output goes through `htmlspecialchars` (`h()`); every POST form has a session token checked before the action. |
| Who can do what? | Role checked by the page and again inside every procedure (`@UserID` first). Passwords: bcrypt only. Same login message for wrong user and wrong password. |
| Secrets? | `config.php` is not in git or in the zip; the repository is public. |
| How would you add a new reading type or rule? | Rows in `OBIS_CODE`, `VEE_RULE`, `RULE_FOR`: no schema change ([17](17-extensibility.md) section 3). |
| Load shedding on 400,000 meters? | One set-based insert per order from the transformer subtree (recursive CTE), indexes on the tree; the demo data has 1,000 meters. |
| Why 56 tables? | One table per entity and relationship of the ER (Phase A), normalised; [20](20-data-dictionary.md) explains every column. |
| What would you improve? | Limits listed in the manual and in [16](16-security.md) section 6: no TLS pinning to the database, no snapshot isolation, estimated technical losses. |

If you do not know: say what the table or procedure is called, open it, and read the comment at the top of the file. Do not invent.

## After the rehearsal

Write what took too long or failed into `docs/handoff/REL-3.md`, fix the script here, and rebuild the demo database ([23](23-release.md)).
