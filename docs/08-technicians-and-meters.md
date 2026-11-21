# 08. Technicians and meters (III.2)

[← Back to the menu](../README.md) · Tasks: TEC-1 … TEC-10 in [tasks.md](tasks.md)

> **Status: partly built.** TEC-1 (registration + categories) is written and awaiting the coordinator's test run. TEC-2 … TEC-10 are plans.

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
| Tests | `sql/tests/test_technician.sql` | 25 `OK` checks (each with a `FAIL` branch), users `test_tec_*`; tech1's categories are restored. |

`THROW` numbers used: 52000 role, 52001 short username, 52002 duplicate username, 52003 email, 52004 under 18, 52005 photo, 52006 categories, 52007 phone. Next free: 52008.

## Planned (after TEC-1)

| Task | Procedures | Tables | Page |
|---|---|---|---|
| TEC-2 | `sp_tech_add_document`, `sp_tech_list_documents` | `DOCUMENT` | `technician/documents.php` |
| TEC-3 | `sp_tech_declare_availability` (AVAILABILITY + AVAILABLE_IN) | `AVAILABILITY`, `AVAILABLE_IN`, `MUNICIPALITY` | `technician/availability.php` |
| TEC-4 ★ | `sp_operator_list_pending_technicians`, `sp_operator_review_document`, `sp_operator_decide_technician` | `USER_ACCOUNT`, `DOCUMENT`, `AUDIT_LOG` | `operator/tec_technicians.php` |
| TEC-5 ★ | `sp_task_create` (also from a `SERVICE_REQUEST`, agreement X1), `sp_task_assign` (checks Approved, category, availability), `sp_tech_list_tasks` (with lat/lon), `sp_tech_accept_task`, `sp_tech_add_note`, `sp_tech_add_attachment`, `sp_tech_complete_task` | `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES` | `technician/tasks.php`, `operator/tec_tasks.php` |
| TEC-6 ★ | `sp_tech_install_meter`: one transaction writes `METER` (`Status = 'Pending confirmation'`), `METER_INSTALLATION`, `METER_CONNECTED_PHASE`. A replacement closes the old installation and **keeps** its readings. Then `sp_tech_add_meter_document` | `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `DOCUMENT` | `technician/install.php` |
| TEC-7 ★ | `sp_operator_confirm_meter(@UserID, @InstallationID, @Approve, @Comment)` | `METER_INSTALLATION`, `METER`, `AUDIT_LOG` | `operator/tec_meters.php` |
| TEC-8 | `sp_tech_request_command`, `sp_command_record_attempt` (simulated ACK) | `REMOTE_COMMAND`, `COMMAND_ATTEMPT` | `technician/commands.php` |
| TEC-9 | `sp_task_create` with type Anti-tamper check, `sp_event_create_task` (agreement X4) | `FIELD_TASK`, `NOTIFIES`, `EVENT`, `LEADS_TO` | `operator/tec_events.php` |
| TEC-10 | Pages for the tasks above | | |

Base data already has `tech1` (Approved), `tech2` (Pending) and meter 5 (`Pending confirmation`) for demos.
