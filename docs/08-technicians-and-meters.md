# 08. Technicians and meters (III.2)

[← Back to the menu](../README.md) · Tasks: TEC-1 … TEC-10 in [tasks.md](tasks.md)

> **Status: built, awaiting the coordinator's test run.** TEC-1 to TEC-10 are written.

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
| `register_technician.php` | `sources/` | Registration form (photo is a path text field, category checkboxes). Linked from `index.php`. `login.php` refuses Rejected technicians. Pending and Suspended technicians log in but see **only** «Τα έγγραφά μου» (FIX-2: `technician_limited()` / `require_approved_technician()` in `auth.php`, status re-read from the database on every page), so a new technician can upload the 3 documents the Operator needs before approving. |
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
- [x] 2.3 Physical meter ↔ Premise ID, with serial, type, firmware, communication, phases, Amps, photos, and the 3 equipment documents (calibration, CE & protocol, telemetry encryption) with code, dates, file.
- [x] 2.3 The meter's transformer comes from its coordinates (agreement X7).
- [x] 2.3 A new or replaced meter is **not** available automatically. The Operator checks, records the result, confirms, and **only then** `Active`.
- [x] 2.3 Replacement does **not** destroy the premise's old time series.
- [x] 2.4 A command is a **command record**, not a field change: requester/executor, target, time, status, **successive attempts** until ACK. Only where role and flow allow it (B15).
- [x] 2.4 Security / anti-tamper checks: responsible person, date, comments/findings, people to notify. Critical findings go to the event log (agreement X8) and can become a **new task** (X4).

### TEC-6 to TEC-10 (install, confirm, commands, anti-tamper, pages)

| Item | What it does |
|---|---|
| `sp_tech_install_meter` | Own `Accepted` Installation/Replacement task. One transaction: `METER` (`Pending confirmation`, `TransformerID` = **leaf** geofence containing the coordinates, X7, smallest geofence first like `sp_tso_locate`), `METER_CONNECTED_PHASE` (count must equal `METER_MODEL.PhaseCount`), `METER_INSTALLATION` (`Pending`, `TaskID`). Replacement: closes the old open installation (`RemovedAt`), old meter `Retired`, **readings untouched**. Returns `MeterID, InstallationID, TransformerID`. Photos: existing `sp_tech_add_attachment`. |
| `sp_tech_add_meter_document` | Calibration certificate / CE and protocol declaration / Encryption certificate for a meter the technician installed, while the installation is `Pending`. |
| `sp_tech_list_installs`, `sp_ref_list_comm_types` | Own installations with document count; public lookup of communication types for the form. |
| `sp_operator_list_pending_meters`, `sp_operator_list_meter_documents` | Pending installations (documents, photos, transformer, technician) and one meter's documents. |
| `sp_operator_confirm_meter` | `@Approve = 1` needs all 3 document types present, not `Rejected`, not expired; then installation `Confirmed`, valid `Pending` documents `Accepted`, meter `Active`. `@Approve = 0` needs a comment: installation `Rejected`, meter **stays** `Pending confirmation` (a new task is needed for a retry). `AUDIT_LOG` rows for each change. |
| `sp_tech_request_command` | Types `Disconnect`, `Reconnect`, `Firmware upgrade` (B15; `Load shed` is TSO only). Only for a non-retired meter where the technician has an `Accepted` task (on the meter, or on the premise where it is installed). Status `Awaiting approval`. `Parameters` must be JSON. |
| `sp_operator_approve_command` | `Awaiting approval` -> `Sent` (`ApprovedBy`), or with `@Approve = 0` + comment -> `Cancelled`. |
| `sp_command_record_attempt` | Operator or the requesting technician (simulated device). Command must be `Sent`. `AttemptNo` = max + 1 under `UPDLOCK` on the command row. `ACK` -> `Acknowledged`; `NAK`/`Timeout` keep `Sent`; the 3rd failure -> `Failed`. Audit only on status changes. Returns `AttemptNo, Status`. |
| `sp_command_list`, `sp_command_list_attempts`, `sp_tech_list_command_targets` | Operator: all commands; technician: own. Attempts of a command. Meters a technician may command. |
| `sp_tech_record_tamper_check` | Own `Accepted` Anti-tamper task: `TASK_NOTE` `Finding`, `NOTIFIES` for the user list, and if `@Critical` an `EVENT` `'Tamper finding'` (B14/X8, `Critical`, `Open`, meter from the task or its premise's open installation). |
| `sp_operator_list_open_events`, `sp_event_create_task` | Open events; X4: Open event with a meter -> `FIELD_TASK` Anti-tamper check (meter + premise of its open installation) + `LEADS_TO` + event `In progress`. Event without a meter is refused. |
| Pages | `technician/40_install.php`, `technician/50_commands.php` (also the tamper-check form), `operator/tec_30_meters.php`, `operator/tec_40_events.php` (events and command approval). |
| Tests | One block at the end of `test_technician.sql`: own premise in leaf 4, meters `SN-TEC6-*`, everything deleted at the end (Active meters on leaves 4/5/6 return to the starting count). |

`THROW` numbers: 52131 task not Accepted, 52132 task type, 52133 task already has an installation, 52134 serial/network ID exists, 52135 phases, 52136 no leaf for the coordinates (X7), 52137 invalid meter data, 52138 model/comm type missing, 52139 meter document type, 52140 meter not installed by you, 52141 installation not Pending. Confirm: 52330 installation missing, 52331 not Pending, 52332 documents missing, 52333 rejection needs a comment, 52334 no decision. Commands: 52340 command type, 52341 no Accepted task for the meter, 52342 meter missing/Retired, 52343 Parameters not JSON, 52344 command missing, 52345 not Awaiting approval, 52346 rejection needs a comment, 52347 outcome, 52348 command not Sent, 52349 role / not your command. Anti-tamper: 52360 task not Anti-tamper, 52361 task not Accepted, 52362 event missing, 52363 event not Open, 52364 event without a meter. Reused: 52102, 52103, 52112, 52113, 52120, 52126, 52302-52304. Next free: 52142 (to 52199), 52335, 52350, 52365.

