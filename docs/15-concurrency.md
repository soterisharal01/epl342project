# 15. Concurrency and contention points

[← Back to the menu](../README.md) · Task: CCY-1 in [tasks.md](tasks.md) · Part of docx (b), chapter (a)

> **Status: written.** Every mechanism below exists in `sql/create.sql` or `sql/procs_*.sql` and is named with its procedure. The 10,000-request numbers (section 8) are filled in by PRF-4.

## 1. Two workloads on one database

MDMS-Cy serves two kinds of work at the same time.

- **OLTP (many short transactions):** a consumer pays an invoice, a technician adds a note, an operator assigns a task, a meter sends a telemetry packet. Each touches a few rows.
- **Analytic / batch (few long transactions):** the VEE run (`sp_dso_run_vee`) validates every pending reading of a period, `sp_tso_refresh_current_state` sums all leaf transformers and their ancestors, the retention purge (`sp_retention_purge`) deletes old rows, and the supplier, aggregator and TSO reports read `METER_AGGREGATE` and `TRANSFORMER_AGGREGATE`.

The design rule that follows: **writers of telemetry and readers of reports never touch the same table.** Data moves in one direction through intermediate tables, and each step is one transaction.

```
packet -> RAW_READING (Pending) -> [VEE] -> VALIDATED_READING (immutable) -> METER_AGGREGATE / TRANSFORMER_AGGREGATE
                                                                      \-> TRANSFORMER_CURRENT_STATE (button refresh)
```

Ingestion only inserts into `TELEMETRY_PACKET` and `RAW_READING`. VEE reads `RAW_READING` and writes `VALIDATED_READING`. Consumers, suppliers, aggregators and the TSO read only `VALIDATED_READING` and the aggregate tables (agreement X6). The one exception is the Intraday page, which reads `RAW_READING` by design. A slow report therefore never blocks a meter packet.

## 2. Isolation level and why

All connections use SQL Server's default **READ COMMITTED**. No procedure and no PHP file changes the isolation level (there is no `SET TRANSACTION ISOLATION LEVEL` in `sql/` or `sources/`). Where a procedure needs a stronger guarantee it asks for it **per statement** with a lock hint:

| Hint | Used for |
|---|---|
| `UPDLOCK` | "I read this row in order to change it". A second session asking for `UPDLOCK` on the same row waits, so a read-then-write sequence cannot interleave. |
| `HOLDLOCK` (SERIALIZABLE for that statement) | Also locks the **gap** where a key does not exist yet, so two sessions cannot both find "no row" and both insert. |
| `UPDLOCK, READPAST` | Skip rows another transaction has locked, instead of waiting. |
| `sp_getapplock` | A named lock owned by the transaction, for "only one of these at a time". |

Why not `SNAPSHOT` or `READ_COMMITTED_SNAPSHOT` (RCSI)? Both need `ALTER DATABASE ... SET ...` on the department database, and a student login may not be allowed to run it. We did not try. It is the open question to the professor ([18](18-deliverables-and-timeline.md)). With RCSI, plain readers would stop waiting for writers; today a reader can wait for a short write lock, which is acceptable at our size. The design does not depend on RCSI: every correctness rule below is enforced by explicit hints, and would behave the same under it.

## 3. The contention points

### 3.1 Telemetry arrives while VEE runs (`sp_dso_ingest_packet`, `sp_dso_run_vee`)

Risk: VEE reads a half-written packet, or blocks ingestion for the length of the run, or processes a row twice.

- `sp_dso_run_vee` reads the pending rows with `FROM RAW_READING r WITH (UPDLOCK, READPAST) WHERE VeeStatus = 'Pending' AND IntervalStart >= @From AND IntervalStart < @To`. It locks the rows it will process and **skips** any row that another transaction holds locked, for example a packet being inserted right now. A skipped or late row stays `Pending` and is handled by the next run. Nothing waits.
- New packets for **other** intervals insert freely: VEE holds row locks on rows that already exist, not key-range locks.
- The run is **one transaction**: `VEE_RUN`, `VALIDATED_READING`, `READING_EDIT`, the raw status updates, `EVENT` and `AUDIT_LOG` are all written, or none are.
- Honest limit: a packet that duplicates a pending row VEE has locked makes the duplicate check in the ingest procedure wait until VEE commits, then it is reported as a duplicate. That is correct, only slower.
- A raw reading that arrives late for an interval that already has a validated value (for example an estimate) is closed as `late` without changing anything, because validated rows are immutable.

### 3.2 Two VEE runs at once (`sp_dso_run_vee`)

Risk: two DSO users press "Run VEE" together and process the same rows, or write two estimates for one gap.

Mechanism: the first statement of the transaction is `sp_getapplock @Resource = N'mdms_vee_run', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 0`. The second caller does not wait: it gets error **53101** at once ("another VEE is running") and the page shows it. The lock is released automatically at COMMIT or ROLLBACK, so a crashed run cannot leave it stuck. The same pattern (`mdms_retention_purge`) stops two retention purges from running together in `sp_retention_purge`. The automatic estimate's `EditNo` (`MAX+1` inside `sp_dso_run_vee`) needs no extra lock because only one run can be inside this code at a time.

### 3.3 Duplicate packets (`sp_dso_ingest_packet`)

Risk: a meter retransmits and two copies are processed in parallel. Both see "no reading for this interval" and both insert.

Mechanism: before inserting, the procedure checks each `(MeterID, ObisCode, IntervalStart)` with `FROM RAW_READING r WITH (UPDLOCK, HOLDLOCK)`. `HOLDLOCK` locks the empty key range as well and `UPDLOCK` stops a second session from taking it, so the second session **waits** for the first COMMIT, then sees the row and records "duplicate" instead of inserting. The primary key `PK_RAW_READING` is the safety net: on an unforeseen collision the transaction is rolled back and the packet is logged as `Malformed` (CATCH block). The reason is stored in `TELEMETRY_PACKET.ErrorMessage`, so nothing is lost silently.

### 3.4 Invoice payment race (`sp_consumer_pay_invoice`)

Risk: two payments of the same invoice at the same moment both pass the "amount <= balance" check, and the invoice is overpaid.

Mechanism: inside the transaction the first read is `SELECT ... FROM INVOICE WITH (UPDLOCK, HOLDLOCK) WHERE InvoiceID = @InvoiceID`. The second payment waits, then recomputes `paid = SUM(PAYMENT)` and is refused with 51034 if the balance is now too small. The same hint pair guards the purchase of history months (`sp_consumer_buy_history`: `SERVICE_PURCHASE WITH (UPDLOCK, HOLDLOCK)` over the overlapping months, error 51110).

### 3.5 "Next number" counters (`NoteNo`, `EditNo`)

Risk: two sessions compute `MAX(n) + 1` at the same time and get the same number, which violates the key.

| Counter | Procedure | Mechanism |
|---|---|---|
| `TASK_NOTE.NoteNo` | `sp_tech_add_note` | First locks the `FIELD_TASK` row (`UPDLOCK`), then `SELECT ISNULL(MAX(NoteNo),0)+1 FROM TASK_NOTE WITH (UPDLOCK, HOLDLOCK)` for that task. |
| `READING_EDIT.EditNo` (manual edit) | `sp_dso_edit_reading` | Locks the raw row `WITH (UPDLOCK, HOLDLOCK)`, then `MAX(EditNo)+1 ... WITH (UPDLOCK, HOLDLOCK)`. |
| `READING_EDIT.EditNo` (automatic estimate) | `sp_dso_run_vee` | Protected by the single-run application lock (3.2). |

`COMMAND_ATTEMPT.AttemptNo` has the same shape (primary key `(CommandID, AttemptNo)`), but **no procedure writes it yet** (planned with the remote-command flow). We therefore make no claim about it here.

### 3.6 Status transitions guarded by a state check

Risk: two actors move the same request, task or document at the same time (two operators assign one request, a task is cancelled while a technician accepts it).

Mechanism: the row is read with `WITH (UPDLOCK)` (or `UPDLOCK, HOLDLOCK`) **before** the status test, in the same transaction as the update. Examples: `sp_task_create` locks the `SERVICE_REQUEST` row, so two operators cannot assign the same request. `sp_task_reassign`, `sp_task_cancel`, `sp_tech_accept_task` and `sp_tech_add_note` lock the `FIELD_TASK` row. `sp_operator_review_document` and `sp_operator_decide_technician` lock the `DOCUMENT` or `USER_ACCOUNT` row. `sp_admin_set_account_status` locks the `USER_ACCOUNT` row. Catalog deletes check "is it in use" with `HOLDLOCK` (`sp_operator_delete_catalog_item` looks at `METER`, `SERVICE_PURCHASE`, `SUPPLY_CONTRACT`), so nobody can start using an item between the check and the delete.

### 3.7 GDPR stages (`sp_gdpr_submit` to `sp_gdpr_apply`)

Risk: a consumer submits two requests, two admins decide the same request, or the anonymisation runs twice.

Mechanism: `sp_gdpr_submit` takes `UPDLOCK, HOLDLOCK` on the consumer's `USER_ACCOUNT` row, so the "only one open request" check is race free (error 51403). Every later stage (`sp_gdpr_start_review`, `sp_gdpr_preapprove`, `sp_gdpr_decide`, `sp_gdpr_apply`) reads `GDPR_REQUEST ... WITH (UPDLOCK, HOLDLOCK)` and tests the old status, so a request moves `Submitted`, `Under review`, `Pre-approved`, `Approved`, `Applied` exactly once per step. `sp_gdpr_apply` runs the whole anonymisation (user row, channels, bank accounts, payments detached) in one transaction.

### 3.8 Retention purge (`sp_retention_purge`)

Risk: a big delete holds locks for a long time, or runs twice, or deletes by accident.

Mechanism: an application lock (`mdms_retention_purge`) allows one purge at a time. The delete runs in **batches of 5,000 rows, one transaction per batch**, so locks are short and telemetry ingestion continues meanwhile. This is safe because the rule is monotonic: whatever was deleted would have been deleted anyway, so an interrupted purge simply runs again. The cost, stated in the procedure, is that the whole job is not atomic. Deletion of validated rows is allowed only while the session flag `mdms_purge` is set (3.10).

### 3.9 Load shedding (`sp_tso_load_shed`)

Risk: an order exists without commands, or commands exist without an order, if the connection drops half way.

Mechanism: one transaction inserts the `LOAD_SHED_ORDER`, then **one `REMOTE_COMMAND` per active meter in a single set-based `INSERT ... SELECT`**, then the `AUDIT_LOG` row. `SET XACT_ABORT ON` plus TRY/CATCH rolls back everything on any error. The meter list is computed before the transaction. If no active meter exists the procedure refuses (53622) and leaves nothing behind.

### 3.10 Current state refresh (`sp_tso_refresh_current_state`)

Risk: a refresh must not show a half-updated tree to the TSO page.

Mechanism: the leaf sums and then the sums of every ancestor are first computed into table variables, then applied with a **single `MERGE` into `TRANSFORMER_CURRENT_STATE`** (update, insert, and delete rows of removed nodes) in one transaction. Readers (`sp_tso_current_state`) see the whole tree before or after the commit, never a leaf updated without its ancestors. The refresh is a button, not a scheduler, so no background job competes with users.

### 3.11 Immutability instead of locking (`TR_VALIDATED_READING_Immutable`)

Validated readings are never updated. The trigger refuses every `UPDATE` (error 50005) and refuses `DELETE` (50006) unless the session has run `sp_set_session_context N'mdms_purge', 1`, which only the retention procedure does (agreement X5, and it resets the flag to 0 afterwards, also in CATCH). A corrected value is a **new** row with `Quality = 'Edited'` plus a `READING_EDIT` row. Immutable rows need no update locks, so report queries and VEE never fight over them, and the history stays auditable.

### 3.12 Hot spots

| Hot spot | Why it is hot | How it is handled |
|---|---|---|
| `AUDIT_LOG` inserts | every state change and every login | Append-only, one narrow row, `LogID` IDENTITY, so inserts go to the end of the clustered key. The row is written inside the caller's transaction, so it commits with the change. |
| `IDENTITY` columns (`PacketID`, `EventID`, `LogID`, ...) | many sessions insert at once | IDENTITY allocation is not transactional and takes no long lock. Gaps after a rollback are accepted, nothing depends on gap-free numbers. |
| `RAW_READING` | 96 rows per meter per day per OBIS code | Key `(MeterID, ObisCode, IntervalStart)`: different meters write to different key ranges. Partitioning is future work ([17](17-extensibility.md)). |
| `TRANSFORMER_CURRENT_STATE` | one MERGE rewrites all node rows | Small table (transformers times two codes), refreshed on demand only. |
| Filtered unique indexes `UX_HOLDING_Open`, `UX_METER_INSTALLATION_Open`, `UX_SUPPLY_CONTRACT_Open` | "at most one open row" | The database refuses a second open row even if two sessions race, so the application needs no lock for this rule. |

## 4. Deadlock avoidance

SQL Server resolves a deadlock by killing one session, so we avoid creating them.

- **Short transactions.** A transaction starts after the argument checks and ends in the same procedure. Nothing waits for the user inside a transaction.
- **A fixed order inside a procedure:** lock the parent or "header" row first (`FIELD_TASK`, `INVOICE`, `GDPR_REQUEST`, the raw row), then count or insert child rows. `sp_tech_add_note` shows it: task row, then notes.
- **`UPDLOCK` instead of read-then-upgrade.** Two sessions that both take a shared lock and then try to upgrade is the classic deadlock. `UPDLOCK` makes the second session wait at the read.
- **`sp_getapplock` with `@LockTimeout = 0`** in `sp_dso_run_vee`: the loser leaves at once instead of waiting.
- **`SET XACT_ABORT ON` and TRY/CATCH with `ROLLBACK`** in every procedure that writes (convention in [19](19-conventions.md)). An error never leaves an open transaction holding locks.
- The PHP side calls one procedure per action (`call_proc` in `sources/db.php`), so no transaction spans several HTTP requests.

If a deadlock still happens, the victim gets error 1205, the page shows the generic error and the user retries. The 10,000-request test (section 8) reports the count.

## 5. Summary table

| Contention point | Risk | Mechanism | Where in code |
|---|---|---|---|
| Ingest during VEE | blocking, half-read packet, double processing | `UPDLOCK, READPAST` on Pending rows, one transaction, RAW then VALIDATED separation | `sp_dso_run_vee`, `sp_dso_ingest_packet` |
| Two VEE runs | same rows processed twice | `sp_getapplock mdms_vee_run`, timeout 0, error 53101 | `sp_dso_run_vee` |
| Duplicate packets | two identical readings | `UPDLOCK, HOLDLOCK` key-range check + `PK_RAW_READING` | `sp_dso_ingest_packet` |
| Invoice payment | overpayment | `UPDLOCK, HOLDLOCK` on `INVOICE`, balance recomputed | `sp_consumer_pay_invoice` |
| History purchase | same month bought twice | `UPDLOCK, HOLDLOCK` on `SERVICE_PURCHASE` | `sp_consumer_buy_history` |
| `NoteNo`, `EditNo` | duplicate counter value | lock parent row, then `MAX()+1` under `UPDLOCK, HOLDLOCK` | `sp_tech_add_note`, `sp_dso_edit_reading` |
| Task, request, document status | lost update, double assignment | `UPDLOCK` before the status test | `sp_task_create`, `sp_task_reassign`, `sp_tech_accept_task`, `sp_operator_*` |
| GDPR stages | duplicate request, double apply | `UPDLOCK, HOLDLOCK` on the user row and on `GDPR_REQUEST` | `sp_gdpr_*` |
| Retention purge | two purges, long locks, accidental delete | `sp_getapplock mdms_retention_purge`, 5,000-row batches, session flag `mdms_purge` | `sp_retention_purge`, trigger |
| Load shedding | order without commands | one transaction, set-based insert, XACT_ABORT | `sp_tso_load_shed` |
| Current state | half-updated tree | one `MERGE` in one transaction, on demand | `sp_tso_refresh_current_state` |
| Validated readings | updates behind reports | trigger refuses UPDATE and DELETE | `TR_VALIDATED_READING_Immutable` in `sql/create.sql` |
| Open holding, installation, contract | two open rows | filtered unique indexes `UX_*_Open` | `sql/create.sql` |
| `AUDIT_LOG`, IDENTITY | insert hot spot | append-only, written inside the caller's transaction | all writing procedures |

## 6. How concurrency is tested

The files `sql/tests/test_*.sql` run on one connection. They check the **logic** of each guard (a payment above the balance is refused, a duplicate packet is recorded as a duplicate), not true parallelism. Parallelism is exercised by the 10,000-request test below, which runs several workers at once. We have not written a dedicated two-session test for each hint.

## 7. Limits we state openly

- No `SNAPSHOT` or RCSI (open question to the professor).
- Ingesting a duplicate of a VEE-locked row waits for the run to finish (3.1).
- A VEE run over a very large period holds many row locks, and SQL Server may escalate them to a table lock. We have not measured where this happens. PRF-4 should try a large period while the load test runs.

## 8. The 10,000-request test (PRF-4)

**Method (planned, script written by PRF-4):** a script calls a mix of OLTP procedures 10,000 times with several parallel workers, measures each call, and reports the share under 2 seconds (requirement: 95%). The mix, from [14](14-indexes-and-performance.md): login, consumer readings and billing, technician task list, telemetry ingest. While it runs, one VEE run is started to show that OLTP calls are not blocked by it.

**Results (to be filled in by PRF-4):**

| Item | Value |
|---|---|
| Date, machine, network (VPN or on campus) | _pending_ |
| Workers (parallel connections) | _pending_ |
| Mix (share of each procedure) | _pending_ |
| Requests | 10,000 |
| Median / p95 / p99 / max (ms) | _pending_ |
| Share under 2 s | _pending_ (target 95%) |
| Errors, deadlocks (1205), 53101 refusals | _pending_ |
| VEE running during the test? | _pending_ |
