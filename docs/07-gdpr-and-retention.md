# 07. GDPR and data retention (III.1.4)

[← Back to the menu](../README.md) · Tasks: GDP-1 … GDP-3 in [tasks.md](tasks.md)

> **Status: GDP-1, GDP-2 and GDP-3 written (in review, not yet run against the database).**

## Requirements

- A consumer can ask to be forgotten. Flow: **submit → Operator reviews and pre-approves → Admin makes the final decision → apply**. Every stage goes to the log.
- Applying erases or anonymises the personal data that may go, but **keeps** invoices and payments.
- Raw readings are kept 3 years (`RawRetentionMonths = 36`), or 1 month after a GDPR request. Aggregates stay. Transformer readings stay forever.

## What exists (GDP-1, `sql/procs_gdpr.sql`, tests in `sql/tests/test_gdpr.sql`)

| Procedure | Who | What it does |
|---|---|---|
| `sp_gdpr_submit(@UserID, @RequestType = 'Erasure')` | Active Consumer | Creates a `Submitted` request of type `'Erasure'` (right to be forgotten) or `'Retention'` (keep the account, keep detailed readings only 1 month, spec III.1.4); refused if one is open (51403), if the type is unknown (51413), or for `'Retention'` when retention is already 1 month (51414). Returns `GdprRequestID`. |
| `sp_gdpr_list(@UserID, @Status = NULL)` | Consumer, Operator, Admin | Consumer sees only own requests; Operator and Admin see all, with the consumer's username and names, who pre-approved and decided, and `RequestType`. |
| `sp_gdpr_start_review(@UserID, @GdprRequestID)` | Operator | `Submitted` to `Under review` (optional step). |
| `sp_gdpr_preapprove(@UserID, @GdprRequestID, @Approve, @Comment)` | Operator | From `Submitted` or `Under review` to `Pre-approved` or `Rejected`. |
| `sp_gdpr_decide(@UserID, @GdprRequestID, @Approve, @Comment)` | Admin | From `Pre-approved` to `Approved` or `Rejected`. |
| `sp_gdpr_apply(@UserID, @GdprRequestID)` | Admin | From `Approved` to `Applied` in one transaction. `'Erasure'`: anonymises and erases (table below). `'Retention'`: only `RawRetentionMonths = 1`, the account stays Active. **Then, automatically**, runs `sp_retention_purge_core`, so the older readings are deleted at once without the Admin pressing the retention button (if another purge is running, the apply still holds and the next purge deletes them). Returns a summary row of counts plus `RequestType, RawPurged, ValidatedPurged`. |
| `sp_gdpr_assert_role` | helper | Active user with the given role, else 51400 / 51401 / 51402. |

THROW numbers: 51400 not a consumer, 51401 not an Operator, 51402 not an Admin, 51403 open request exists, 51404 role may not list,
51405 bad status filter, 51406 request not found, 51407 start review from wrong status, 51408 Approve is NULL,
51409 preapprove from wrong status, 51410 decide from wrong status, 51411 apply from wrong status, 51412 user is not a Consumer.

Status machine: `Submitted` to `Under review` (optional) to `Pre-approved` to `Approved` to `Applied`.
`Rejected` is reached from `Submitted` / `Under review` (Operator) or from `Pre-approved` (Admin). A rejected consumer may submit again.
Every step writes an `AUDIT_LOG` row (`ObjectType = 'GDPR_REQUEST'`, old and new status; the Operator/Admin comment goes in `ResultComment`,
because the table has no comment column).

Choices made because of the CHECKs on `GDPR_REQUEST`:

- `CK_GDPR_REQUEST_Stage` requires `PreApprovedAt` on a `Rejected` row. An Operator rejection therefore stores `PreApprovedBy` / `PreApprovedAt`
  as the **review stamp** (who looked at it and when); `Status = 'Rejected'` says it was a rejection. An Admin rejection keeps the existing stamp and adds the decision columns.
- The Admin decision is stored in `DecidedByAdmin` (`DecidedBy` stays NULL), which satisfies `CK_GDPR_REQUEST_OneFinal`. `sp_gdpr_list` shows `COALESCE(DecidedByAdmin, DecidedBy)` as `DecidedBy`.
- Timestamps are `DATETIME2(0)` and never earlier than the previous stage (`CK_GDPR_REQUEST_Order`).
- Each procedure reads the request row `WITH (UPDLOCK, HOLDLOCK)` and checks the status inside the transaction.

What `sp_gdpr_apply` does:

| Erased or anonymised | Kept |
|---|---|
| `USER_ACCOUNT`: `Username = deleted_<id>`, name `Διαγραμμένος Διαγραμμένος`, `Email = deleted<id>@anon.invalid`, `Phone = NULL`, `PasswordHash = '!ERASED!' + GUID` (not a valid hash, nobody can log in), `AccountStatus = 'Suspended'`, `RawRetentionMonths = 1` | `INVOICE`, `PAYMENT` (legal obligation) |
| `CONSUMER_NOTIFICATION_CHANNEL` rows deleted | `HOLDING`, `PREMISE`, `SUPPLY_CONTRACT` |
| `CONSUMPTION_THRESHOLD` rows deactivated (`IsActive = 0`) | Aggregates and readings (raw readings older than 1 month are removed at once by the automatic purge) |
| `PAYMENT.BankAccountID` set to NULL, `ACCOUNT_FOR` and `BANK_ACCOUNT` rows deleted | The `AUDIT_LOG` history |

`AUDIT_LOG` rows written by apply contain only counts and IDs. Older audit rows (for example `Add bank account`, which stores the last 4 IBAN digits) are not rewritten.
No procedure here refuses to erase the base demo users; the tests never do it.
## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 1.4 GDPR is **not** an immediate deletion: submit → review → pre-approval → final approval, with a log row at every stage (the five `GDPR_REQUEST` stages and `CK_GDPR_REQUEST_Stage`: `'Rejected'` needs `PreApprovedAt`). After approval only the personal data that may be erased is erased **permanently**. Payment accounting stays (B17).
- [ ] 1.4 Raw 15-minute readings: 3 years, then deleted; aggregates stay. With an approved GDPR request: 1 month, and older rows are deleted **automatically**. Transformer readings/aggregates are not affected and are kept forever.
- [ ] 1.4 Statistics prefer aggregates; detailed data only for those entitled to it.

## What exists (GDP-2, `sql/procs_gdpr.sql`, tests in `sql/tests/test_gdpr.sql`, page `sources/admin/gdp_retention.php`)

| Object | Who | What it does |
|---|---|---|
| `fn_retention_cutoff(@AsOf)` | inline TVF | Time segments per meter: `METER_INSTALLATION` (not Rejected) joined to the `HOLDING` of the premise and the holder's `RawRetentionMonths`. Columns `MeterID, SegFrom, SegTo, UserID, RetentionMonths, Cutoff`. |
| `sp_retention_preview(@UserID, @AsOf = NULL)` | Admin | Read only. One row per meter and retention length: `MeterID, SerialNumber, RetentionMonths, Cutoff, RawToDelete, ValidatedToDelete, EditsToDelete, AsOf`. Meters with nothing to delete show 0. |
| `sp_retention_purge_core(@UserID, @AsOf, @Raw OUTPUT, @Validated OUTPUT, @Edits OUTPUT)` | Admin (internal) | The purge itself, no result set; called by the button and by `sp_gdpr_apply`. |
| `sp_retention_purge(@UserID, @AsOf = NULL)` | Admin | The button: calls the core. Deletes expired rows; returns `RawDeleted, ValidatedDeleted, EditsDeleted, AsOf`. Writes one `AUDIT_LOG` row (`ObjectType = 'RETENTION'`, counts in `ResultComment`). |

`@AsOf` defaults to now (UTC); the demo and the tests pass a later date.
THROW numbers: 51450 `@AsOf` more than one year in the future (protects against a typo wiping everything), 51451 another purge is running (`sp_getapplock`), 51402 not an Admin.

Design choices:

- **Holder at the time of the reading.** A reading is covered by the segment where `InstalledAt <= IntervalStart < RemovedAt` and the holding covers that date.
  A reading in no segment (premise with no holder then, or before the installation) falls back to **36 months**. Overlapping segments: the longer retention wins.
- Rule: delete when `IntervalStart < DATEADD(MONTH, -months, @AsOf)`; the cutoff instant itself is kept.
- **Agreement X5**: `sp_set_session_context N'mdms_purge', 1`, then `DELETE` only (never UPDATE), flag reset to 0 afterwards and in `CATCH`.
- **Batches of 5000, one transaction per batch**: short locks and a small log while meters keep inserting. The rule is monotone, so an interrupted run just continues next time;
  the price is that the whole purge is not atomic.
- **`READING_EDIT`**: the edit rows of purged readings are deleted too, because they hold `OldValue`/`NewValue`, the same values we erase. Order: edits, validated, raw.
- Never touched: `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE`, transformer data.
- The page `admin/gdp_retention.php` shows the preview (optional reference date) and a purge button with a confirmation and CSRF.

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| GDP-3 | Pages for GDP-1 (consumer, operator, admin) | | `consumer/gdp_request.php`, `operator/gdp_review.php`, `admin/gdp_decide.php` |

Schema hooks: the CHECKs `CK_GDPR_REQUEST_Stage` and `CK_GDPR_REQUEST_Order` enforce the stage order, and the trigger
`TR_VALIDATED_READING_Immutable` allows DELETE only under the purge flag ([04-database-schema.md](04-database-schema.md)).

## Pages (GDP-3)

| Page | Role | Procedures |
|---|---|---|
| `sources/consumer/80_gdpr.php` (menu: Δικαίωμα στη λήθη) | Consumer | `sp_gdpr_submit` (needs a confirmation checkbox), `sp_gdpr_list`. Explains the stages, what is erased, that invoices and payments stay, the 1-month retention and that login stops after apply. Shows own requests with the date of each stage. |
| `sources/operator/gdp_10_review.php` (menu: Αιτήματα GDPR) | Operator | `sp_gdpr_list` (status filter), `sp_gdpr_start_review`, `sp_gdpr_preapprove` (approve or reject, with comment). |
| `sources/admin/gdp_10_decide.php` (menu: Αιτήματα GDPR) | Admin | `sp_gdpr_list` (status filter), `sp_gdpr_decide` (approve or reject, with comment), `sp_gdpr_apply` (confirmation checkbox; the returned summary row is shown in the flash message: what was erased and what was kept). |
| `sources/admin/gdp_retention.php` (GDP-2) | Admin | `sp_retention_preview`, `sp_retention_purge`. |

All pages use `call_proc`, `check_csrf()` on every POST, `h()` on output and Post/Redirect/Get with `flash()`. No new procedure was needed: the stage dates in `sp_gdpr_list` are the status history (comments are in `AUDIT_LOG.ResultComment`).

### FIX-2: the purge never loses a day aggregate
A cumulative value (`1.8.0`, `2.8.0`) younger than 36 months is deleted by `sp_retention_purge` / `sp_retention_purge_core` (and counted by `sp_retention_preview`) **only if** its day already has a `METER_AGGREGATE` Day row. Otherwise it stays until the DSO builds that day (for example a Suspect value still waiting for an edit), so a 1-month GDPR retention can never delete the data a day total is built from. After 36 months every row is deleted as before. Tests: `FIX-2 purge keeps …` and `FIX-2 purge deletes it once …` in `sql/tests/test_gdpr.sql`.
