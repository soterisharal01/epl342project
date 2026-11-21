# 15. Concurrency

[← Back to the menu](../README.md) · Task: CCY-1 in [tasks.md](tasks.md) · Part of docx (b)

> **Status: plan only.**

## Requirement

Describe how concurrency is handled (transactions, isolation levels, intermediate tables), with examples such as
new readings arriving while VEE and aggregates are running.

## Planned content

- **Ingestion during VEE:** VEE reads only Pending rows with `UPDLOCK, READPAST`, so new rows inserted meanwhile are skipped, not blocked, and handled by the next run.
- **Two VEE runs at once:** the second is blocked with `sp_getapplock`.
- **Intermediate tables:** RAW → VALIDATED, and `TRANSFORMER_CURRENT_STATE`, separate writers from readers.
- **Transactions and isolation levels** used in each area, for example `UPDLOCK` in `sp_consumer_pay_invoice`.
- **Hot spots:** `AUDIT_LOG` and IDENTITY columns.
- Open question for the professor: may we use `READ_COMMITTED_SNAPSHOT` or `SNAPSHOT` on the department server? ([18](18-deliverables-and-timeline.md)).
