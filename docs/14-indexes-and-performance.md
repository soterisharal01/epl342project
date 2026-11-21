# 14. Indexes and performance

[← Back to the menu](../README.md) · Tasks: PRF-1 … PRF-4 in [tasks.md](tasks.md)

> **Status: written and measured.** Indexes PRF-1/2/3 with before/after numbers, and the PRF-4 10,000-request test (PASS), all measured on 21/11 on a local SQL Server 2025 with the large data set.

## Requirements

- Explain **3 indexes**: which, why, how. Show **one before/after case** where an index or a better query lowers the cost.
- Under **2 seconds** for **95%** of normal OLTP queries over **10,000** requests.

## The three indexes

All are in [sql/indexes.sql](../sql/indexes.sql) (idempotent, with a comment block per index). The primary keys
and the `UX_*` unique indexes of `create.sql` already exist; SQL Server does **not** create an index for a
foreign key, so the FK columns below had none.

| Task | Index | Query that uses it | Why the PK does not help | Expected effect |
|---|---|---|---|---|
| PRF-1 | `IX_INVOICE_User_IssueDate` on `INVOICE (UserID, IssueDate DESC)` INCLUDE `(Amount, Status, PeriodFrom, PeriodTo, ContractID)` | `sp_consumer_list_invoices`: `WHERE UserID = @u ORDER BY IssueDate DESC, InvoiceID DESC` | PK is `(InvoiceID)`: the query must read every invoice, then sort | Clustered Index Scan + Sort becomes an Index Seek on `UserID`; rows come out already sorted; the INCLUDE columns avoid Key Lookups |
| PRF-2 | `IX_FIELD_TASK_Technician_Status` on `FIELD_TASK (TechnicianID, Status)` INCLUDE `(TaskType, ScheduledFrom, ScheduledTo, PremiseID, MeterID, RequestID)` | `sp_tech_list_tasks`: `WHERE TechnicianID = @u AND (@Status IS NULL OR Status = @Status)` | PK is `(TaskID)`: every technician's list scans all tasks | Scan becomes Seek on `TechnicianID` (and `Status` when given); no Key Lookup; the sort handles only one technician's rows |
| PRF-3 | `IX_RAW_READING_Pending` on `RAW_READING (IntervalStart, MeterID, ObisCode)` INCLUDE `(ReceivedValue)` **WHERE `VeeStatus = 'Pending'`** (filtered) | `sp_dso_run_vee` step 1: `WHERE VeeStatus = 'Pending' AND IntervalStart >= @From AND IntervalStart < @To` | PK is `(MeterID, ObisCode, IntervalStart)`; the VEE query has no `MeterID`, so the PK cannot seek and the whole table (~64,000 rows and growing) is read to find a few Pending rows | Scan becomes Seek on a tiny index that holds only Pending rows. Validated rows leave the index, so it stays small and cheap to maintain |

How each one works:

- **Key columns** are what the engine seeks on: equality columns first (`UserID`, `TechnicianID`), then the
  sort or range column. For the filtered index the range column `IntervalStart` comes first, because the
  query has no `MeterID`; the clustered key (`MeterID, ObisCode, IntervalStart`) is stored in every
  non-clustered index anyway, so the index also returns the row identity.
- **INCLUDE columns** are stored only in the leaf level. They make the index *covering*: all columns the
  query returns are in the index, so no Key Lookup into the clustered index per row.
- **Filtered index** (`WHERE VeeStatus = 'Pending'`): indexes only the rows that match. The optimizer uses it
  only when the query repeats the predicate as a constant, which `sp_dso_run_vee` does.
- Reading queries by `MeterID` and interval (`sp_consumer_*` readings) are already served by the PK
  `(MeterID, ObisCode, IntervalStart)`; `sp_dso_list_packets` orders by `PacketID` (PK). No index for them.
- Cost of an index: each INSERT/UPDATE of the table also maintains it. Here writes are rare compared with
  reads (invoices monthly, tasks few, Pending rows short-lived), so the trade is good.

## Before/after method

Script: [sql/perf/before_after.sql](../sql/perf/before_after.sql). Run it on the database with the
**large data set** loaded (after `sql/indexes.sql`). It is re-runnable, makes no permanent data change
(test updates are rolled back) and leaves all three indexes in place at the end.

1. In SSMS: Query → **Include Actual Execution Plan** (Ctrl+M). Run the whole file once.
2. For each case (A invoices, B Pending readings, C technician tasks) the script prints `=== X1: BEFORE` (index
   dropped) and `=== X2: AFTER` (index created), each with `SET STATISTICS IO, TIME ON`.
3. **Screenshots to take** (for the report): (a) the **Messages** tab lines `Table 'INVOICE'. Scan count …,
   logical reads …` and `CPU time / elapsed time` for before and after; (b) the **Execution Plan** tab of
   the before query (Clustered Index Scan, plus Sort) and of the after query (Index Seek).
4. The `SET SHOWPLAN_TEXT` batches print the estimated plans as text for the report appendix (before uses
   `WITH (INDEX(PK_…))` to reproduce the no-index plan).
5. The headline case for the report is **A (invoices)** or **B (VEE Pending)**; whichever shows the larger gap.

## Measured numbers (PRF-1/2/3)

Measured 21/11 on a local SQL Server 2025 (Docker) with a clean build, base data and the large set (`sql/import.sql`):
1,035 users, 2,403 invoices, 32,014 raw and 31,872 validated readings, 1,005 field tasks. `sql/perf/before_after.sql`
run once; each query runs with a cold cache (`DBCC DROPCLEANBUFFERS`). Logical reads are the steady number (pages read);
times of a few ms are at the edge of what `STATISTICS TIME` can show on such a small set.

| Case | Rows read/total | Logical reads before | Logical reads after | CPU ms before / after | Elapsed ms before / after | Plan before → after |
|---|---|---|---|---|---|---|
| A. Consumer invoices (`INVOICE`), UserID 100000 | 3 / 2,403 | 17 | **2** | 3 / 2 | 4 / 2 | Clustered Index Scan + Sort → Index Seek + Sort |
| B. VEE Pending (`RAW_READING`), last day marked Pending | 502 / 32,014 | 244 | **5** | 4 / 2 | 4 / 1 | Clustered Index Scan → Index Seek on the filtered index |
| C. Technician tasks (`FIELD_TASK`), TechnicianID 101000 | own tasks / 1,005 | 21 | **2** | – | – | Clustered Index Scan → Index Seek |

**Headline case: B (VEE Pending)**: 244 → 5 logical reads (about 50 times fewer pages). Without the index the engine reads
the whole `RAW_READING` table to find one day's Pending rows; with the filtered index it reads only the Pending rows of
that interval. The gap grows with the table, because the filtered index holds only the few Pending rows while the table
keeps growing every 15 minutes.

Notes: in case A the plan after still has a small **Sort**: the query orders by `IssueDate DESC, InvoiceID DESC` and the
index gives `InvoiceID` (the clustered key) ascending inside equal dates, so the engine sorts the user's 3 rows; the cost
is negligible. Case C prints no time line because the task list is too small to time.
For the report, rerun the script in SSMS with Ctrl+M on the demo database and take the plan screenshots (method above).

## PRF-4: 10,000 requests

Script: [sql/perf/perf_10000.py](../sql/perf/perf_10000.py) (Python + `pymssql`; connection from environment variables,
the password is never printed). It makes 10,000 stored-procedure calls, the same calls the PHP pages make, with users
picked at random from the data, over 4 parallel connections, and reads every result set as a page does. Read-only.

Mix (weights): consumer readings of one day 25%, consumer invoices 15%, consumer premises 15%, login lookup 15%,
technician tasks 10%, supplier Day-Ahead totals for a week 10%, DSO latest 50 packets 10%.

Result, 21/11, same local database as above:

| Procedure | Count | Errors | Mean ms | p50 | p95 | p99 | Max ms |
|---|---|---|---|---|---|---|---|
| `sp_consumer_readings` | 2,572 | 0 | 3.0 | 3.7 | 4.7 | 5.4 | 140.6 |
| `sp_consumer_list_invoices` | 1,503 | 0 | 2.9 | 3.5 | 4.7 | 5.2 | 30.8 |
| `sp_consumer_list_premises` | 1,444 | 0 | 2.7 | 3.5 | 4.3 | 4.9 | 39.8 |
| `sp_auth_get_login` | 1,496 | 0 | 2.4 | 3.3 | 4.0 | 4.5 | 8.5 |
| `sp_tech_list_tasks` | 952 | 0 | 3.6 | 4.0 | 5.5 | 12.3 | 34.3 |
| `sp_supplier_totals` | 1,008 | 0 | 6.6 | 6.5 | 11.7 | 13.2 | 116.8 |
| `sp_dso_list_packets` | 1,025 | 0 | 63.0 | 62.3 | 93.8 | 118.7 | 131.9 |
| **All** | **10,000** | **0** | 9.4 | 3.9 | **62.6** | 80.6 | 140.6 |

**100% of the requests finished under 2 seconds (target: 95%) → PASS.** 10,000 requests took 24.5 s (about 408 per second).
The slowest call is the DSO packet list (it returns the 50 newest packets with their JSON payload); still under 0.15 s.

Limits, said openly: this measures the **database** side (the stored procedure plus the network to it), not PHP and
the web server; it ran on a local server, not the department one, with the large set sized for the 27 MB department cap.
To repeat it on a member database: set `MDMS_SERVER=mssql.cs.ucy.ac.cy\SQL2025`, `MDMS_DB`, `MDMS_USER` and
`MDMS_PASSWORD` (typed by the member) and run `python sql/perf/perf_10000.py`.
