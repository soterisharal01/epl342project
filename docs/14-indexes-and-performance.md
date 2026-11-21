# 14. Indexes and performance

[← Back to the menu](../README.md) · Tasks: PRF-1 … PRF-4 in [tasks.md](tasks.md)

> **Status: indexes written (PRF-1/2/3), measured numbers pending (coordinator). PRF-4 not started.**

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

## Measured numbers (to be filled by the coordinator)

| Case | Rows read/total | Logical reads before | Logical reads after | CPU ms before / after | Elapsed ms before / after | Plan before → after |
|---|---|---|---|---|---|---|
| A. Consumer invoices (`INVOICE`) | | | | | | Scan + Sort → Seek |
| B. VEE Pending (`RAW_READING`) | | | | | | Scan → Seek (filtered) |
| C. Technician tasks (`FIELD_TASK`) | | | | | | Scan → Seek |

Notes (data volume, which UserID/TechnicianID was picked, cold or warm cache): _to fill_.

## PRF-4 plan (unchanged)

10,000 calls of a mix of OLTP procedures (login, consumer readings, task list, ingest). Measure times, show
95% < 2 s. Script `tests/perf.php` or `tests/perf.py`, results table in this document.
