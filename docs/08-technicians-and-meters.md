# 08. Technicians and meters (III.2)

[← Back to the menu](../README.md) · Tasks: TEC-1 … TEC-10 in [tasks.md](tasks.md)

> **Status: partly built.** TEC-1, TEC-2, TEC-3, TEC-4 and TEC-5 are written and await the coordinator's test run. The other tasks are plans.

## Requirements

- A technician self-registers and can do nothing until an Operator approves. They join at least one category and give email, birth date and photo.
- Documents: ID card, installer licence, training certificate, each with number, issue date, expiry date and file.
- Daily availability in time and place.
- Field tasks (installation, replacement, check, anti-tamper): assignment, acceptance, meter location, notes, findings, evidence.
- Installing a meter on a premise: serial, type, firmware, communication, phases, amps, photos, and 3 equipment documents. The Operator confirms it, and only then is it `Active` for ingestion.
- Remote commands (disconnect, reconnect, firmware) with attempts until ACK. Anti-tamper checks: who is notified, event → new task.

## What exists

| Item | File | What it does |
|---|---|---|
| `sp_auth_register_technician` | `sql/procs_technician.sql` | Self-registration (no `@UserID`). Role `Technician`, `ApprovalStatus = 'Pending'`, `AccountStatus = 'Active'`. Checks username (>= 3, unique), email, phone chars, age >= 18, photo not empty, `@CategoryIDs` (comma list, at least one, all existing). One transaction: `USER_ACCOUNT`, `IN_CATEGORY`, `AUDIT_LOG`. Returns `UserID`. |
| `sp_ref_list_tech_categories` | same | Public lookup `CategoryID, Label` for the form. |
| `sp_tech_assert` | same | Throws 52000 unless the user is an Active, **Approved** Technician. Every later `sp_tech_*` procedure starts with it. |
| `sp_tech_set_categories` | same | Approved technician replaces their categories (at least one). Transaction + `AUDIT_LOG` with old/new list. |
| `sp_tech_list_categories` | same | The technician's own categories. |
| `register_technician.php` | `sources/` | Registration form (photo is a path text field, category checkboxes). Linked from `index.php`. `login.php` already refuses Pending/Rejected/Suspended technicians. |
| `sp_operator_assert` | `sql/procs_technician.sql` | Throws 52100 unless the user is an Active Operator (TEC-5; no such helper existed). |
| `fn_task_slot_ok` | same | Inline table-valued function: one row if the technician may take the time window. Availability rule: if they declared **no** `AVAILABILITY` for that date, any slot is allowed; if they did, the window must start and end that day inside one declared slot. |
| `sp_task_create` | same | Operator only. Creates a `FIELD_TASK` (`Assigned`) for an Active, Approved technician. Checks type, schedule, the target/install rules of the CHECKs, availability, the notify list. With `@RequestID`: request must be `Submitted`, its premise is used, request becomes `Assigned` (X1), the consumer is added to `NOTIFIES`. Transaction + `AUDIT_LOG`. Returns `TaskID`. |
| `sp_task_reassign`, `sp_task_cancel` | same | Operator. Reassign only while `Assigned`. Cancel (reason required) not when `Done`/`Cancelled`; the request is **not** reverted (X1 allows only Assigned/Resolved). |
| `sp_task_list`, `sp_task_list_requests`, `sp_task_list_technicians` | same | Operator lists: all tasks (status filter), `Submitted` requests, approved technicians. |
| `sp_tech_list_tasks` | same | The technician's own tasks with address, `Latitude`/`Longitude` (meter if any, else premise), serial, request description. |
| `sp_tech_accept_task`, `sp_tech_add_note`, `sp_tech_add_attachment`, `sp_tech_complete_task` | same | Own tasks only. Accept `Assigned` -> `Accepted`. Notes `Observation`/`Finding` with `NoteNo` per task, computed under `UPDLOCK` on the task row so concurrent notes cannot clash on the PK. Attachment = file path. Complete `Accepted` -> `Done` (`CompletedAt`, `Result`); a linked request becomes `Resolved` (X1). |
| `sp_task_get`, `sp_task_notes`, `sp_task_attachments`, `sp_task_assert_view` | same | Task row, its notes, its attachments (one result set each). Operator: any task; technician: own only. |
| `technician/20_tasks.php`, `operator/tec_20_tasks.php` | `sources/` | Technician: list, accept, notes, attachment path, complete. Operator: list, create (also from a request), reassign, cancel. |
| Tests | `sql/tests/test_technician.sql` | TEC-1: 25 `OK` checks, users `test_tec_*`; tech1's categories are restored. TEC-5: 53 `OK` checks (full request-to-Resolved path plus refusals); uses request 1 if still `Submitted`, else its own; the extra technician `test_tec_b` ends `Suspended`. |

`THROW` numbers used: 52000 role, 52001 short username, 52002 duplicate username, 52003 email, 52004 under 18, 52005 photo, 52006 categories, 52007 phone. TEC-5: 52100 operator role, 52101 task type, 52102 schedule, 52103 technician not approved, 52104 request not Submitted, 52105 request missing, 52106 premise differs from request, 52107 no target, 52108 install/replace needs premise, 52109 Installation with meter, 52110 Replacement without meter, 52111 premise/meter missing, 52112 outside availability, 52113 bad notify user, 52120 task missing or not yours, 52121 reassign only Assigned, 52122 cancel Done/Cancelled, 52123 accept only Assigned, 52124 task Cancelled, 52125 note kind, 52126 empty text/path, 52127 complete only Accepted, 52128 empty result, 52129 empty cancel reason, 52130 bad status filter. Next free: 52131.

### TEC-2, TEC-3, TEC-4 (documents, availability, approval)

| Item | What it does |
|---|---|
| `sp_tech_assert_any` | Active Technician with approval status Pending, Approved or Suspended (not Rejected). Used for what a technician does **before** approval. |
| `sp_tech_add_document`, `sp_tech_list_documents` | Technician files `ID card`, `Installer licence` or `Training certificate` (number, issue, optional expiry, file path), `ReviewStatus = 'Pending'`, returns `DocumentID`. Lists own documents with the review result. |
| `sp_ref_list_municipalities` | `MunicipalityID, Label` lookup for the availability form. |
| `sp_tech_declare_availability` | Approved technician. `AVAILABILITY` + `AVAILABLE_IN` in one transaction. Not in the past, `ToTime > FromTime`, no overlap with another slot that day (`UPDLOCK, HOLDLOCK` on the day's slots), at least one municipality, all existing. |
| `sp_tech_list_availability`, `sp_tech_remove_availability` | Own slots (optional date range, municipality names joined). Remove a slot unless a non-cancelled task of the technician overlaps it. `AVAILABLE_IN` rows cascade. |
| `sp_operator_list_pending_technicians` | Pending technicians with categories and document counts (Pending / Accepted / Rejected). |
| `sp_operator_list_technician_documents`, `sp_operator_review_document` | Operator sees a technician's documents; reviews a **Pending** document once (Accepted or Rejected, a rejection needs a comment). `AUDIT_LOG` with old/new/comment. |
| `sp_operator_decide_technician` | Only for a Pending technician. **Approval rule:** at least one `Accepted`, unexpired (`ExpiryDate` NULL or after today UTC) document of **each** of the 3 types. Reject needs a comment. Sets `ApprovalStatus`, `ApprovedBy`, `ApprovalDecidedAt` and writes `AUDIT_LOG`. |
| `sp_operator_set_technician_status` | `Approved` <-> `Suspended` only; suspending needs a comment; updates `ApprovedBy`/`ApprovalDecidedAt` (the CHECK needs them) and writes `AUDIT_LOG`. |
| Pages | `technician/10_documents.php`, `technician/30_availability.php`, `operator/tec_10_technicians.php`. |
| Tests | 61 `OK` checks in `test_technician.sql`: users `test_tec2_a` (approved, suspended, reinstated) and `test_tec2_b` (rejected); tech1 availability on 2027-07-01 is removed at the end. |

`THROW` numbers: 52300 technician role/status, 52301 doc type, 52302 doc number, 52303 doc dates, 52304 doc file, 52310 availability in the past, 52311 times, 52312 overlap, 52313 municipalities, 52314 slot not found, 52315 active task inside slot, 52320 technician not found, 52321 document not found, 52322 document already reviewed, 52324 decision only for Pending, 52325 missing accepted documents, 52326 comment required, 52327 invalid decision/status, 52328 status transition not allowed. Next free: 52329 (52323 unused).

## Planned (after TEC-1)
## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [x] 2.1 A technician registers alone but **can do nothing** before an Operator approves (login **and** every procedure check it).
- [x] 2.1 At least **one** category by specialty. **Daily** time and area availability.
- [x] 2.1 Active email, date of birth, photo, and the 3 documents (ID card, installer licence, training certificate) with number, issue date, expiry where it exists, file.
- [x] 2.1 Approval, rejection and **every** status change of a technician are logged.
- [ ] 2.2 Task types: installation, replacement, technical check, anti-tamper. Each task: premise and/or meter, technician, type, schedule, status, result.
- [ ] 2.2 The technician **accepts** the task and **sees the meter's location**. Notes, findings, evidence = the task's history.
- [ ] 2.3 Physical meter ↔ Premise ID, with serial, type, firmware, communication, phases, Amps, photos, and the 3 equipment documents (calibration, CE & protocol, telemetry encryption) with code, dates, file.
- [ ] 2.3 The meter's transformer comes from its coordinates (agreement X7).
- [ ] 2.3 A new or replaced meter is **not** available automatically. The Operator checks, records the result, confirms, and **only then** `Active`.
- [ ] 2.3 Replacement does **not** destroy the premise's old time series.
- [ ] 2.4 A command is a **command record**, not a field change: requester/executor, target, time, status, **successive attempts** until ACK. Only where role and flow allow it (B15).
- [ ] 2.4 Security / anti-tamper checks: responsible person, date, comments/findings, people to notify. Critical findings go to the event log (agreement X8) and can become a **new task** (X4).

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| TEC-6 ★ | `sp_tech_install_meter`: one transaction writes `METER` (`Status = 'Pending confirmation'`), `METER_INSTALLATION`, `METER_CONNECTED_PHASE`. A replacement closes the old installation and **keeps** its readings. Then `sp_tech_add_meter_document` | `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `DOCUMENT` | `technician/install.php` |
| TEC-7 ★ | `sp_operator_confirm_meter(@UserID, @InstallationID, @Approve, @Comment)` | `METER_INSTALLATION`, `METER`, `AUDIT_LOG` | `operator/tec_meters.php` |
| TEC-8 | `sp_tech_request_command`, `sp_command_record_attempt` (simulated ACK) | `REMOTE_COMMAND`, `COMMAND_ATTEMPT` | `technician/commands.php` |
| TEC-9 | `sp_task_create` with type Anti-tamper check, `sp_event_create_task` (agreement X4) | `FIELD_TASK`, `NOTIFIES`, `EVENT`, `LEADS_TO` | `operator/tec_events.php` |
| TEC-10 | Pages for the tasks above | | |

Base data already has `tech1` (Approved), `tech2` (Pending) and meter 5 (`Pending confirmation`) for demos.
