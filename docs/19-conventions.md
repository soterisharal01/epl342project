# 19. Conventions and decisions

[← Back to the menu](../README.md)

These rules apply to every task and every AI session. Decisions B1–B13 are **closed**. To change one, propose
it in the group; if everyone agrees, edit it here and add a line to the change log at the end.
(Phase A design decisions D1–D32 are in [phase-a/design-decisions.md](phase-a/design-decisions.md).)

## 1. Areas

Every task, procedure file, page folder, error number and test-data ID belongs to an **area**:

| Area | Component doc | Procedure file(s) | Test file | Pages | `THROW` numbers | Data IDs |
|---|---|---|---|---|---|---|
| COM (login, shared lookups) | [05](05-users-roles-login.md) | `sql/procs_common.sql` | `sql/tests/test_common.sql` | `sources/*.php` | 50000–50999 | 1–999 (base data) |
| ADM (admin, operator catalogs) | [05](05-users-roles-login.md) | `sql/procs_admin.sql` | `sql/tests/test_admin.sql` | `sources/admin/`, `sources/operator/adm_*.php` | 51000–51999 | 1000–1999 |
| CON (consumers) | [06](06-consumers.md) | `sql/procs_consumer.sql` | `sql/tests/test_consumer.sql` | `sources/consumer/` | 51000–51999 | 1000–1999 |
| GDP (GDPR, retention) | [07](07-gdpr-and-retention.md) | `sql/procs_gdpr.sql` | `sql/tests/test_gdpr.sql` | `sources/*/gdp_*.php` | 51000–51999 | 1000–1999 |
| TEC (technicians, meters) | [08](08-technicians-and-meters.md) | `sql/procs_technician.sql` | `sql/tests/test_technician.sql` | `sources/technician/`, `sources/operator/tec_*.php`, `sources/register_technician.php` | 52000–52999 | 2000–2999 |
| MKT (suppliers, aggregators) | [11](11-suppliers-aggregators.md) | `sql/procs_market.sql` | `sql/tests/test_market.sql` | `sources/supplier/`, `sources/aggregator/` | 52000–52999 | 2000–2999 |
| DSO (ingestion, VEE) | [09](09-dso-ingestion-vee.md) | `sql/procs_dso.sql` | `sql/tests/test_dso.sql` | `sources/dso/` | 53000–53999 | 3000–3999 |
| TSO (transformer tree) | [10](10-tso-transformers.md) | `sql/procs_tso.sql` | `sql/tests/test_tso.sql` | `sources/tso/` | 53000–53999 | 3000–3999 |

- `THROW` numbers inside a range: take the next free number in that file. Check with a search before adding one.
  Areas that share a range use fixed sub-ranges, so parallel work never collides:
  CON 51000–51399, GDP 51400–51499, ADM 51500–51999 · TEC 52000–52499, MKT 52500–52999 · DSO 53000–53499, TSO 53500–53999.
- Extra small test data goes in `data/small/10_consumer.sql` (ADM, CON, GDP), `20_field_market.sql` (TEC, MKT) or
  `30_grid.sql` (DSO, TSO). Each builds **only** on `00_base.sql`, never on another file, and inserts its own
  rows with `SET IDENTITY_INSERT` and IDs in its range.
- `build_all.py` picks up every `sql/procs_*.sql` and `data/small/NN_*.sql` file automatically.

## 2. Code rules

### Stored procedures (T-SQL, SQL Server 2025)

- One procedure per operation, named `sp_<area>_<verb>`. Prefixes in use: `auth`, `user`, `ref`, `admin`, `operator`,
  `consumer`, `gdpr`, `retention`, `tech`, `task`, `command`, `supplier`, `aggregator`, `market`, `dso`, `tso`.
- The **first parameter is always `@UserID`** (who acts). The procedure first checks that user's `Role` and that
  `AccountStatus = 'Active'`.
- Writing to more than one table: `SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRY BEGIN TRAN … COMMIT END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH`.
- Every state change writes **one row to `AUDIT_LOG`** (`ObjectType`, `ObjectID`, `Action`, `OldState`, `NewState`, `PerformedBy` or `ActorMechanism`).
- Errors: `THROW <number>, N'<Greek message the user will read>', 1;`
- Files start every object with `CREATE OR ALTER`, so a file can be re-run without dropping anything.
- Before writing, look up exact column names and CHECK values in `sql/create.sql`. Never invent columns.
- **No `dbo.` prefix.** On the department server every member's objects are created in their own default schema
  (for example `apieri01`, `sharal01`), so `dbo.anything` is not found. Call procedures, tables and table-valued
  functions unqualified. T-SQL cannot call a **scalar** function without a schema, so do not write scalar functions:
  use an inline table-valued function (`EXISTS (SELECT 1 FROM fn_x(@a, @b))`) or an inline `EXISTS` check.

Template (from `sql/procs_consumer.sql`):

```sql
CREATE OR ALTER PROCEDURE sp_consumer_pay_invoice
    @UserID INT, @InvoiceID INT, @BankAccountID INT, @Amount DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;                        -- role + Active, else THROW 51000
    IF NOT EXISTS (SELECT 1 FROM INVOICE WHERE InvoiceID = @InvoiceID AND UserID = @UserID)
        THROW 51001, N'Το τιμολόγιο δεν είναι δικό σας.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(14) = (SELECT Status FROM INVOICE WITH (UPDLOCK) WHERE InvoiceID = @InvoiceID);
        INSERT PAYMENT (...) VALUES (...);
        UPDATE INVOICE SET Status = ... WHERE InvoiceID = @InvoiceID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        SELECT 'INVOICE', @InvoiceID, 'Payment', @old, Status, @UserID FROM INVOICE WHERE InvoiceID = @InvoiceID;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
```

### Tests

- Each procedure has at least one call in `sql/tests/test_<area>.sql` that succeeds and one that must be refused
  (wrong role or bad data). Each check prints `OK …` or `FAIL …`. Template: `sql/tests/test_common.sql`.
- No `BEGIN TRAN` around a whole test file: one `THROW` under `XACT_ABORT` would kill the rest.

### PHP (PHP 8.0 on the department server, sqlsrv driver)

- New page = copy `sources/_template.php` into the role's folder. First line `<?php // MENU: <title>` puts it in the menu automatically.
- **No SQL in PHP.** Only `call_proc('sp_…', [uid(), …])`, which runs `{CALL sp_…(?, ?)}`.
- `require_role('<Role>')` at the top. `csrf_field()` in every POST form and `check_csrf()` in its handler. Print through `h()` or `print_table`.
- Passwords: `password_hash()` on write, `password_verify()` on login. The database stores only the hash.
- Never print SQL error text (the department firewall answers with a 403). `db.php` already filters errors: only our own `THROW` messages (50000–59999) reach the user.

## 3. Who writes to which table

Each table is written (INSERT/UPDATE/DELETE) only by procedures of its area. Other areas only read it.

| Area | Writes to |
|---|---|
| COM, ADM, CON, GDP | `USER_ACCOUNT` (every role **except** Technician), `CONSUMER_NOTIFICATION_CHANNEL`, `PREMISE`, `HOLDING`, `BANK_ACCOUNT`, `ACCOUNT_FOR`, `CONSUMPTION_THRESHOLD`, `SUPPLY_CONTRACT`, `INVOICE`, `PAYMENT`, `SERVICE_TYPE`, `SERVICE_PURCHASE`, `SERVICE_REQUEST`, `TARIFF_TYPE`, `METER_MODEL`, `SUPPLIER`, `AGGREGATOR`, `GDPR_REQUEST` |
| TEC, MKT | `USER_ACCOUNT` (**only** Technician rows: registration, approval), `TECHNICIAN_CATEGORY`, `IN_CATEGORY`, `DOCUMENT`, `AVAILABILITY`, `AVAILABLE_IN`, `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES`, `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `COMM_TYPE`, `REMOTE_COMMAND`, `COMMAND_ATTEMPT`, `LEADS_TO`, `PORTFOLIO`, `INCLUDES` |
| DSO, TSO | `TELEMETRY_PACKET`, `RAW_READING`, `VALIDATED_READING`, `READING_EDIT`, `OBIS_CODE`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE`, `TRANSFORMER_CURRENT_STATE`, `EVENT`, `TRANSFORMER`, `GEOFENCE`, `LOAD_SHED_ORDER` |
| Every area | `AUDIT_LOG`, INSERT only |
| Base data only | `DISTRICT`, `MUNICIPALITY`, `PARISH`, `SUPPLY_SCHEME` |

## 4. Cross-area agreements (the only exceptions)

| # | Task | What it does to another area's table | Exactly how |
|---|---|---|---|
| X1 | TEC-5 | Creating a task from a consumer request | `UPDATE SERVICE_REQUEST SET Status = 'Assigned'`; when the task is Done, `'Resolved'`. Nothing else. |
| X2 | DSO-1 | Accept readings only from active meters | Read only: `METER.Status = 'Active'`. Active meters exist in the base data. |
| X3 | TSO-4 | Load shedding creates commands | `INSERT REMOTE_COMMAND (CommandType = 'Load shed', Status = 'Sent', ShedOrderID = …)`. The CHECK `CK_REMOTE_COMMAND_ShedOrder` requires `'Load shed'` whenever `ShedOrderID` is set. (The old team plan said `'Disconnect'`, which the schema rejects.) |
| X4 | DSO-1, DSO-5 → TEC-9 | Event that leads to a field task | DSO writes `EVENT`. TEC reads events with `Status = 'Open'`, writes `FIELD_TASK` + `LEADS_TO`, then `UPDATE EVENT SET Status = 'In progress'`. That is TEC's only change to `EVENT`. |
| X5 | GDP-2 | Deleting old readings (retention, GDPR) | `EXEC sp_set_session_context N'mdms_purge', 1;` then `DELETE` from `RAW_READING` and `VALIDATED_READING`. Never UPDATE. |
| X6 | CON-2, MKT-1–3 | Reading DSO results | SELECT only on `VALIDATED_READING`, `METER_AGGREGATE`, and `RAW_READING` (Intraday only). Column meaning: B2. |

## 5. Roles (`USER_ACCOUNT.Role`)

| Role | Who | Created by |
|---|---|---|
| `Admin` | System administrator, root | Base data |
| `Operator` | System operator | Admin (`CreatedBy`) |
| `Consumer` | Consumer or prosumer | Self-registration, active at once |
| `Technician` | Field technician | Self-registration, `ApprovalStatus = 'Pending'` until an Operator decides |
| `DSO`, `TSO` | Network operators | Admin |
| `Supplier`, `Aggregator` | Market company staff | Admin, with `SupplierID` / `AggregatorID` |

One username has exactly one role (the professor's rule). A person with two roles has two usernames.

## 6. Changing the schema

`sql/create.sql`, `sql/drop.sql` and `data/small/00_base.sql` are shared. Every change can break other areas:

1. Post in the group what should change (table/column), why (which spec feature cannot work otherwise) and which areas it affects.
2. If everyone agrees: one PR with `create.sql`, `drop.sql` (for a new table), a note in [04-database-schema.md](04-database-schema.md),
   and for base data a change to `data/gen/base.py` followed by regenerating `00_base.sql` (never edit it by hand).
3. After the merge every member rebuilds their database: drop → create → procedures → data.
4. After **27/11**, only if a ★ demo feature cannot be done otherwise.

## 7. Decisions B1–B13 (Phase B)

| # | Topic | Decision |
|---|---|---|
| B1 | Time | Every time is stored in **UTC** (`SYSUTCDATETIME()`). Readings have `IntervalStart` on :00, :15, :30, :45. |
| B2 | Reading values | `RAW_READING.ReceivedValue` = what the meter sent; for `1.8.0` that is the **counter since installation**. `VALIDATED_READING.Value` = **energy in that 15 minutes** (difference from the previous interval) for cumulative codes (`OBIS_CODE.Kind = 'Cumulative register'`), and the **measured value** for instantaneous codes (voltage, current). Aggregates and current state sum `Value`, and only for cumulative codes. |
| B3 | Passwords | `password_hash()` in PHP, `password_verify()` at login, only the hash in the database. All demo users share one test password, written in the header of `data/small/00_base.sql`. It is nobody's real password. |
| B4 | Error numbers | By area, section 1. |
| B5 | Language | UI and `THROW` messages in Greek. Tables, columns, procedures and docs in English. Files in UTF-8. |
| B6 | Where the app runs | Each member tests in their own `~/public_html/mdms/` with their own database. The final demo runs on the team demo database `sharal01` and `~sharal01/mdms/`. Server: `mssql.cs.ucy.ac.cy\SQL2025`. |
| B7 | Database password | Only in `sources/config.php`, which is git-ignored. The repo has `config.example.php`. |
| B8 | Data files (.dat) | The generators in `data/gen/` write each table as a `.dat` (CSV, UTF-8) **and** an `.sql` with the same INSERTs. Importing means running the `.sql` in SSMS, because `BULK INSERT` on the department server cannot read files from our computers. The manual says so. |
| B9 | Run order | `drop.sql` → `create.sql` → `procs_common.sql` → other `procs_*.sql` → `indexes.sql` → `data/small/00_base.sql` → `data/small/10–30_*.sql` (or `data/import.sql` for the large set). |
| B10 | Schema changes | Only through section 6. |
| B11 | Merging | A member who did not author the PR merges it after approving. If nobody reviews within 24 hours, any other member may review and merge. An AI merges only when its human explicitly asks for that PR. |
| B12 | Code freeze | Wednesday 2/12 evening. After that, only bug fixes. |
| B13 | Final ER | Redrawn at the end (task DOC-2) from the final `create.sql`. Until then the truth is `create.sql` and [04-database-schema.md](04-database-schema.md). |

## Change log

| Date | Change |
|---|---|
| 21/11 | First version of the Phase B plan, rules and decisions. |
| 21/11 | Restructure: no personal ownership, areas instead of people, task IDs by area, start/stop protocol in `CLAUDE.md`, agreement X3 fixed to `'Load shed'`. |
| 21/11 | `THROW` sub-ranges per area; `run_sql.ps1` serialises full runs with a database lock (parallel sessions). |
| 21/11 | `finish` command and `docs/next-session.md`. Rule: no `dbo.` and no scalar functions (department server uses per-user schemas). |
