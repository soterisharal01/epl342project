# 14. Indexes and performance

[← Back to the menu](../README.md) · Tasks: PRF-1 … PRF-4 in [tasks.md](tasks.md)

> **Status: plan only.**

## Requirements

- Explain **3 indexes**: which, why, how. Show **one before/after case** where an index or a better query lowers the cost.
- Under **2 seconds** for **95%** of normal OLTP queries over **10,000** requests.

## Plan

| Task | What |
|---|---|
| PRF-1 | `INVOICE (UserID, IssueDate)` for the consumer billing page |
| PRF-2 | `FIELD_TASK (TechnicianID, Status)` for the technician task list |
| PRF-3 | `RAW_READING (VeeStatus) WHERE VeeStatus = 'Pending'` (filtered) for VEE, **or** an index for reading queries. The before/after case: `SET STATISTICS IO, TIME ON` + execution plan, with screenshots |
| PRF-4 | 10,000 calls of a mix of OLTP procedures (login, consumer readings, task list, ingest). Measure times, show 95% < 2 s. Script `tests/perf.php` or `tests/perf.py`, results table in the document |

All indexes go in `sql/indexes.sql`, one section per task.
