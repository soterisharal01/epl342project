# 05. Users, roles and login

[← Back to the menu](../README.md) · Tasks: ADM-1 … ADM-4 in [tasks.md](tasks.md)

> **Status: plan only.** Filled in as tasks finish and when we walk through this component.

## Requirements

- Every user logs in with username and password. Passwords are stored only as a hash.
- The Admin is root and creates staff accounts. Consumers register themselves. Technicians register themselves and wait for Operator approval.
- One username = one role (the professor's rule). Roles: [19-conventions.md](19-conventions.md), section 5.
- Every critical change is logged in `AUDIT_LOG`.

## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] Every person has a **unique** account. One username = one role (professor, 20/11).
- [ ] Passwords are stored **only** in a non-reversible form (hash), so that not even someone reading the tables can see them.
- [ ] The Admin is the root role and is inserted by hand in the database (`00_base.sql`).
- [ ] Operators are created **by an Admin**. `CreatedBy` is set **only** for Operators (`CK_USER_ACCOUNT_Operator`).
- [ ] The Operator checks technician registrations, technical documents and meters (TEC-4, TEC-7), defines **meter models**, **service types** and **tariff types** (ADM-3), and **records the result** of every check (comment + `AUDIT_LOG`).
- [ ] The Admin sees the log with filters (object, user, period).

## What exists

| Procedure (`sql/procs_common.sql`) | What it does |
|---|---|
| `sp_auth_get_login(@Username)` | Returns UserID, PasswordHash, Role, AccountStatus, ApprovalStatus, names, company IDs. PHP runs `password_verify`. Zero rows if unknown. |
| `sp_auth_log_login(@Username, @Success, @ClientIP)` | Logs every attempt, successful or not, to `AUDIT_LOG`. |
| `sp_auth_register_consumer(...)` | Self-registration: Active at once, `RawRetentionMonths = 36`, notification channels, audit row. |
| `sp_user_get_profile(@UserID)` | Own profile, never the hash. |
| `sp_user_change_password(@UserID, @NewPasswordHash)` | After PHP verified the old password. |
| `sp_ref_list_parishes`, `sp_ref_list_schemes` | Lists for form drop-downs. |

Pages: `index.php` (login form), `login.php`, `logout.php`, `home.php`, `profile.php`, `register_consumer.php`.
A Pending technician who logs in sees only "waiting for approval". Tests: `sql/tests/test_common.sql` (11 checks).

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| ADM-2 | `sp_admin_create_user(@UserID, @Role, …)` for Operator, DSO, TSO, Supplier, Aggregator; `sp_admin_set_account_status`; `sp_admin_audit_log(@UserID, @ObjectType, @From, @To)` | `USER_ACCOUNT`, `SUPPLIER`, `AGGREGATOR`, `AUDIT_LOG` | `admin/users.php`, `admin/log.php` |
| ADM-3 | `sp_operator_save_meter_model`, `sp_operator_save_service_type`, `sp_operator_save_tariff_type` | `METER_MODEL`, `SERVICE_TYPE`, `TARIFF_TYPE` | `operator/adm_catalogs.php` |
| ADM-4 | Pages for ADM-2 and ADM-3 | | |
