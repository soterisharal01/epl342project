# 07. GDPR and data retention (III.1.4)

[← Back to the menu](../README.md) · Tasks: GDP-1 … GDP-3 in [tasks.md](tasks.md)

> **Status: GDP-1 written (in review, not yet run against the database); GDP-2 and GDP-3 planned.**

## Requirements

- A consumer can ask to be forgotten. Flow: **submit → Operator reviews and pre-approves → Admin makes the final decision → apply**. Every stage goes to the log.
- Applying erases or anonymises the personal data that may go, but **keeps** invoices and payments.
- Raw readings are kept 3 years (`RawRetentionMonths = 36`), or 1 month after a GDPR request. Aggregates stay. Transformer readings stay forever.

## What exists (GDP-1, `sql/procs_gdpr.sql`, tests in `sql/tests/test_gdpr.sql`)

| Procedure | Who | What it does |
|---|---|---|
| `sp_gdpr_submit(@UserID)` | Active Consumer | Creates a `Submitted` request; refused (51403) if one is open (Submitted / Under review / Pre-approved / Approved). Returns `GdprRequestID`. |
| `sp_gdpr_list(@UserID, @Status = NULL)` | Consumer, Operator, Admin | Consumer sees only own requests; Operator and Admin see all, with the consumer's username and names, and who pre-approved and decided. |
| `sp_gdpr_start_review(@UserID, @GdprRequestID)` | Operator | `Submitted` to `Under review` (optional step). |
| `sp_gdpr_preapprove(@UserID, @GdprRequestID, @Approve, @Comment)` | Operator | From `Submitted` or `Under review` to `Pre-approved` or `Rejected`. |
| `sp_gdpr_decide(@UserID, @GdprRequestID, @Approve, @Comment)` | Admin | From `Pre-approved` to `Approved` or `Rejected`. |
| `sp_gdpr_apply(@UserID, @GdprRequestID)` | Admin | From `Approved` to `Applied`: anonymises and erases in one transaction; returns a summary row of counts. |
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
| `CONSUMPTION_THRESHOLD` rows deactivated (`IsActive = 0`) | Aggregates and readings (raw readings older than 1 month are removed later by GDP-2) |
| `PAYMENT.BankAccountID` set to NULL, `ACCOUNT_FOR` and `BANK_ACCOUNT` rows deleted | The `AUDIT_LOG` history |

`AUDIT_LOG` rows written by apply contain only counts and IDs. Older audit rows (for example `Add bank account`, which stores the last 4 IBAN digits) are not rewritten.
No procedure here refuses to erase the base demo users; the tests never do it.
## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 1.4 GDPR is **not** an immediate deletion: submit → review → pre-approval → final approval, with a log row at every stage (the five `GDPR_REQUEST` stages and `CK_GDPR_REQUEST_Stage`: `'Rejected'` needs `PreApprovedAt`). After approval only the personal data that may be erased is erased **permanently**. Payment accounting stays (B17).
- [ ] 1.4 Raw 15-minute readings: 3 years, then deleted; aggregates stay. With an approved GDPR request: 1 month, and older rows are deleted **automatically**. Transformer readings/aggregates are not affected and are kept forever.
- [ ] 1.4 Statistics prefer aggregates; detailed data only for those entitled to it.

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| GDP-1 ★ | `sp_gdpr_submit`, `sp_gdpr_preapprove` (Operator), `sp_gdpr_decide` (Admin), `sp_gdpr_apply` (sets `RawRetentionMonths = 1`) | `GDPR_REQUEST`, `USER_ACCOUNT`, `BANK_ACCOUNT`, `AUDIT_LOG` | `consumer/gdp_request.php`, `operator/gdp_review.php`, `admin/gdp_decide.php` |
| GDP-2 | `sp_retention_purge(@UserID, @AsOf)`: `sp_set_session_context N'mdms_purge', 1`, then deletes old rows from `RAW_READING` and `VALIDATED_READING` (agreement X5) | `RAW_READING`, `VALIDATED_READING` | button on an admin page |
| GDP-3 | Pages for GDP-1 and GDP-2 | | |

Schema hooks: the CHECKs `CK_GDPR_REQUEST_Stage` and `CK_GDPR_REQUEST_Order` enforce the stage order, and the trigger
`TR_VALIDATED_READING_Immutable` allows DELETE only under the purge flag ([04-database-schema.md](04-database-schema.md)).
