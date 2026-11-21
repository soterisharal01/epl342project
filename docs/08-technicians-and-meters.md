# 08. Technicians and meters (III.2)

[← Back to the menu](../README.md) · Tasks: TEC-1 … TEC-10 in [tasks.md](tasks.md)

> **Status: plan only.**

## Requirements

- A technician self-registers and can do nothing until an Operator approves. They join at least one category and give email, birth date and photo.
- Documents: ID card, installer licence, training certificate, each with number, issue date, expiry date and file.
- Daily availability in time and place.
- Field tasks (installation, replacement, check, anti-tamper): assignment, acceptance, meter location, notes, findings, evidence.
- Installing a meter on a premise: serial, type, firmware, communication, phases, amps, photos, and 3 equipment documents. The Operator confirms it, and only then is it `Active` for ingestion.
- Remote commands (disconnect, reconnect, firmware) with attempts until ACK. Anti-tamper checks: who is notified, event → new task.

## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 2.1 A technician registers alone but **can do nothing** before an Operator approves (login **and** every procedure check it).
- [ ] 2.1 At least **one** category by specialty. **Daily** time and area availability.
- [ ] 2.1 Active email, date of birth, photo, and the 3 documents (ID card, installer licence, training certificate) with number, issue date, expiry where it exists, file.
- [ ] 2.1 Approval, rejection and **every** status change of a technician are logged.
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
| TEC-1 ★ | `sp_auth_register_technician`, `sp_tech_set_categories` | `USER_ACCOUNT`, `IN_CATEGORY`, `TECHNICIAN_CATEGORY` | `register_technician.php` |
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
