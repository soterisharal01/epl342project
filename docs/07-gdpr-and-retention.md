# 07. GDPR and data retention (III.1.4)

[← Back to the menu](../README.md) · Tasks: GDP-1 … GDP-3 in [tasks.md](tasks.md)

> **Status: plan only.**

## Requirements

- A consumer can ask to be forgotten. Flow: **submit → Operator reviews and pre-approves → Admin makes the final decision → apply**. Every stage goes to the log.
- Applying erases or anonymises the personal data that may go, but **keeps** invoices and payments.
- Raw readings are kept 3 years (`RawRetentionMonths = 36`), or 1 month after a GDPR request. Aggregates stay. Transformer readings stay forever.

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
