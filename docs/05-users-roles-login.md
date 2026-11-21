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

| Procedure (`sql/procs_admin.sql`, ADM-2, errors 51500-51999) | What it does |
|---|---|
| `sp_admin_assert(@UserID)` | Helper: THROW 51500 unless the user is an Active Admin. |
| `sp_admin_create_user(@UserID, @Role, @Username, @PasswordHash, @Email, @Phone, @FirstName, @LastName, @SupplierID, @AggregatorID)` | Creates an Operator (`CreatedBy` = admin), DSO, TSO, Supplier (needs `SupplierID`) or Aggregator (needs `AggregatorID`). Refuses Admin, Consumer, Technician and duplicate usernames (51505). Audit row. Returns `UserID`. |
| `sp_admin_list_users(@UserID, @Role)` | All users (never the hash), optional role filter, with company name. |
| `sp_admin_set_account_status(@UserID, @TargetUserID, @Status)` | `Active` or `Suspended`; an admin cannot suspend himself (51522). Audit row with OldState/NewState. |
| `sp_admin_audit_log(@UserID, @ObjectType, @From, @To)` | Newest first, top 500, with the performer's username; dates are inclusive days. |
| `sp_admin_list_companies(@UserID)` | Suppliers and aggregators, for drop-downs. |

Tests: `sql/tests/test_admin.sql` (43 checks).

| Procedure (`sql/procs_admin.sql`, ADM-3, errors 51600-51699) | What it does |
|---|---|
| `sp_admin_operator_assert(@UserID)` | Helper: THROW 51600 unless the user is an Active Operator. (Not named `sp_operator_assert`: TEC-5 already defines that name.) |
| `sp_operator_save_meter_model(@UserID, @ModelID, @Manufacturer, @ModelName, @MeterType, @PhaseCount)` | Insert (`@ModelID` NULL) or update; duplicate manufacturer+model refused (51603); audit row with old/new state. Returns `ModelID`. |
| `sp_operator_save_service_type(@UserID, @ServiceTypeID, @Name, @Fee)` | Same pattern; Fee >= 0. A new Fee does not change past purchases (they store their own Amount). Returns `ServiceTypeID`. |
| `sp_operator_save_tariff_type(@UserID, @TariffTypeID, @Name)` | Same pattern. Returns `TariffTypeID`. |
| `sp_operator_delete_catalog_item(@UserID, @Catalog, @ID)` | `@Catalog` = `MeterModel`, `ServiceType` or `TariffType`. Refused with 51632 if any meter / purchase / contract uses it. Audit row. |
| `sp_ref_list_meter_models`, `sp_ref_list_service_types`, `sp_ref_list_tariff_types` | Public lookups for drop-downs (no `@UserID`). |

ADM-3 tests are appended to `test_admin.sql` (names `TEST-ADM3-*`).

Pages (ADM-4): `admin/10_users.php` (user list with role filter, create-user form with `password_hash`, suspend/activate),
`admin/20_log.php` (audit log filtered by object type and dates), `operator/adm_10_catalogs.php` (three catalogs: list, add/edit, delete).
