# 16. Security

[← Back to the menu](../README.md) · Tasks: SEC-1, SEC-2 in [tasks.md](tasks.md) · Part of docx (b), chapter (b)

> **Status: written, including the SEC-1 page-by-page review (section 7).** What the web skeleton does is described in [12-php-web-app.md](12-php-web-app.md).

## 1. Approach in one paragraph

Security is built in **layers, so that one mistake does not open the system**. The web page checks the role (`require_role`). Every stored procedure checks the role again from the database (`@UserID` plus an assert). The web code never builds SQL. Passwords are stored only as hashes. Every state change is written to `AUDIT_LOG`. The most important rule: **the user id always comes from the server-side session (`uid()`), never from a form field**, and the procedure also checks that the data belongs to that user.

## 2. Threat list and countermeasures

| Threat | Countermeasure in our code | Where |
|---|---|---|
| Unauthorized access (not logged in) | `require_login()` redirects to the login page. Every role page starts with `require_role(...)`. All 27 role pages under `sources/<role>/` (28 files, one is the shared view `_market_view.php`, included by pages that call it) call it. | `sources/auth.php` |
| Privilege escalation between roles | Two independent checks: the PHP page (`require_role`, answer 403) **and** the procedure. Each area has an assert procedure that reads the role from `USER_ACCOUNT` and refuses with a THROW if the user has another role or an inactive account: `sp_admin_assert`, `sp_admin_operator_assert`, `sp_operator_assert`, `sp_tech_assert`, `sp_consumer_assert`, `sp_dso_assert`, `sp_tso_assert`, `sp_market_assert`, `sp_gdpr_assert_role`. Every procedure of an area starts with its assert or an equivalent inline role check (`sp_gdpr_list`). The only procedures without one are the public login, registration and profile procedures (`sp_auth_*`, `sp_user_*`, which act only on the given user or username), the reference lists for drop-down boxes (`sp_ref_list_*`) and helper functions. A forged request that skips the PHP check still hits the procedure. | `sql/procs_*.sql` |
| Access to another user's data (horizontal escalation) | `UserID` is taken from the session. Procedures also test ownership, for example `sp_consumer_pay_invoice` refuses with 51030 when the invoice is not the caller's and 51031 for a foreign bank account. A technician sees only tasks assigned to them (`sp_tech_*` compare `TechnicianID = @UserID`). | `sql/procs_consumer.sql`, `procs_technician.sql` |
| SQL injection | The PHP code contains **no SQL text**. All database access goes through `call_proc()` in `sources/db.php`, which builds `{CALL sp_name(?, ?)}` and passes values as bound parameters, never concatenated. The procedure name is checked against the regular expression `^sp_[a-z0-9_]+$` before use. Inside procedures we use no dynamic SQL built from input. | `sources/db.php` |
| XSS (script in stored or reflected text) | All output goes through `h()` (`htmlspecialchars(..., ENT_QUOTES, 'UTF-8')`). `print_table()` and `select_options()` escape every cell and option. | `sources/db.php` |
| CSRF (a foreign site makes the user's browser post a form) | Every POST form carries `csrf_field()` and every handler starts with `check_csrf()`, which compares a random 128-bit session token with `hash_equals`. In `sources/` all forms that change data are POST with a token (26 files). The five remaining forms are `GET` filters (date, year) that change nothing. The session cookie is also `SameSite=Lax`. | `sources/auth.php` |
| Session fixation and theft | After a successful login `session_regenerate_id(true)` issues a new id. The cookie is `HttpOnly` (no JavaScript access) and `SameSite=Lax`. Logout runs `session_destroy()`. The password hash is removed from the session (`unset($u['PasswordHash'])`). | `sources/login.php`, `logout.php`, `auth.php` |
| Password theft from the database or repo | Only `password_hash(..., PASSWORD_DEFAULT)` is stored in `USER_ACCOUNT.PasswordHash`; login uses `password_verify`. The database never sees the clear password and the procedures take `@PasswordHash`. A GDPR-erased user gets a value that is not a valid hash, so nobody can log in as it. | `sources/login.php`, register pages, `sp_user_change_password` |
| User enumeration at login | The same message "wrong username or password" is shown for an unknown user and a wrong password. Every attempt, successful or not, is written to `AUDIT_LOG` with the client IP by `sp_auth_log_login`. | `sources/login.php`, `procs_common.sql` |
| Secrets in the repository | `sources/config.php` (database password) is in `.gitignore`; only `config.example.php` is committed. The `.zip` files and `p.txt` are ignored too. For terminal tools, the SQL login is stored with Windows DPAPI (`sql/tools/save_credential.ps1` writes `%USERPROFILE%\.mdms_sql.xml`, readable only by that Windows user), and `run_sql.ps1` never prints or passes the password on a command line and refuses `DROP`/`DELETE`/`TRUNCATE` without `-AllowDestructive`. | `.gitignore`, `sql/tools/` |
| Information leaking through error messages | `remember_error()` shows the user only our own `THROW` messages (numbers 50000-59999, Greek, written to be safe). Any other SQL error becomes a generic message and the details go to the server error log. The department web application firewall answers 403 when it sees SQL error text in a page, so this also keeps the site working. `debug` in `config.php` is `false` on the server. | `sources/db.php` |
| Data leakage to suppliers and aggregators | A supplier or aggregator sees **only sums** over its own customers, never rows per customer. `fn_market_premises(@UserID, @From, @To)` is the only way to find "own customers": premises with a `SUPPLY_CONTRACT` of the user's supplier, or premises included in the user's own portfolios, overlapping the period. Other roles or inactive accounts get no rows. The market procedures read `METER_AGGREGATE` (and `RAW_READING` only for Intraday sums), agreement X6. | `sql/procs_market.sql` |
| Misuse of personal data / GDPR | A consumer can request erasure; the request needs an Operator pre-approval and an Admin decision (`sp_gdpr_*`, separate roles, checked by `sp_gdpr_assert_role`). `sp_gdpr_apply` **anonymises** the user (name, email, phone, username replaced, password hash made unusable, account suspended, bank accounts deleted, payments detached from them) and **keeps** invoices, payments and holdings, because accounting records must survive. Raw readings are then deleted after 1 month instead of 36 (`sp_retention_purge`). `AUDIT_LOG` receives only counts and ids, never personal data. See [07](07-gdpr-and-retention.md). | `sql/procs_gdpr.sql` |
| Tampering with measurements | `TR_VALIDATED_READING_Immutable` refuses `UPDATE`, and refuses `DELETE` unless the retention procedure set the session flag. A correction is a new row plus a `READING_EDIT` row with who, when and why. | `sql/create.sql` |
| Untraceable changes | `AUDIT_LOG` gets a row for each state change, inside the same transaction, with the actor (`PerformedBy` or, for a system step, `ActorMechanism`; the check `CK_AUDIT_LOG_Actor` requires one of them). Logins are logged too. The Admin reads the log in `sources/admin/20_log.php` (`sp_admin_audit_log`). | all procedures |

## 3. Least privilege (recommended deployment)

The department gives each student one SQL login that owns the database, so our own deployment uses that one login in `config.php`. In a real installation the web application should connect with a login that has **only**:

```sql
GRANT EXECUTE ON SCHEMA::dbo TO mdms_web;   -- or EXECUTE on each sp_* procedure
-- and no SELECT / INSERT / UPDATE / DELETE on any table
```

Because the PHP code only calls procedures, such a login would need nothing else, and even a successful injection or stolen `config.php` could not read or change a table directly. The scripts do not create this login: this is a **recommendation, not implemented**. The `sp_*` procedures run with the caller's permissions, so granting the schema `EXECUTE` is enough only because the owner of the procedures and the tables is the same (ownership chaining). We have not tested this configuration on the department server.

## 4. Data stored and its protection

| Data | Protection |
|---|---|
| Passwords | hash only (`password_hash`), never logged |
| Email, phone, name | in `USER_ACCOUNT`; erased or anonymised by GDPR; shown only to the owner and to Admin/Operator pages |
| IBAN | in `BANK_ACCOUNT`, shown only to the owner; deleted on GDPR apply |
| Meter readings | per consumer only through `sp_consumer_*` with ownership checks; suppliers and aggregators only as sums |
| Audit trail | append-only by convention (no procedure updates or deletes `AUDIT_LOG`) |

## 5. How we tested it

The test scripts `sql/tests/test_<area>.sql` print `OK` or `FAIL` for each case. Each procedure area has a block "role check" that calls its procedures as the **wrong role** (for example a consumer calling `sp_dso_ingest_packet`) and expects the specific refusal number (53000 for DSO, 53500 for TSO, 52500 for market, 51400 to 51402 for GDPR, and so on). Counting with `grep`, the eight test files contain about 600 lines that print `OK` (the same number of checks), of which roughly 70 are role refusals, and about 70 explicit assertions on the assert error numbers. These numbers are approximate (a text search, not a test report). PHP pages were checked by hand: a logged-in user of one role opening a page of another role gets the 403 page.

## 6. Known limits (said openly)

- **No lockout or delay after failed logins.** Failed attempts are logged but not blocked, so password guessing is possible. A lockout is planned, not built.
- **No HTTPS enforcement and no `Secure` cookie flag in our code.** This depends on the department web server, which we do not control.
- **No session timeout** beyond the PHP default, and no Content-Security-Policy header.
- **Login timing:** for an unknown username `password_verify` is not run, so the response is slightly faster. The message is identical.
- **The recommended least-privilege login** (section 3) is not used on the department server.
- **Static checks have limits.** `check_pages.py` (section 7) reads the code with regular expressions; it does not run the pages. A page written in an unusual style could slip past it, so the horizontal tests in `test_security.sql` check the procedures themselves.

## 7. Page-by-page review (SEC-1)

**Automatic check of every page.** `python sql/tools/check_pages.py` reads every PHP file in `sources/` (no database needed)
and prints `OK` or `FAIL` per page for six rules. It exits with code 1 if anything fails, so it can be rerun after every change.

| Rule | What it checks |
|---|---|
| R1 | Every role page (`sources/<role>/*.php`) calls `require_role()` with the role of its folder |
| R2 | No SQL text and no direct `sqlsrv_query/prepare/execute` outside `db.php`: pages only use `call_proc` with `?` |
| R3 | Every procedure whose first parameter is `@UserID` receives `uid()` (the session) as its first value, never a request value. The list of such procedures is read from `sql/procs_*.sql` |
| R4 | Every POST form prints `csrf_field()`, and every page that reads `$_POST` calls `check_csrf()` |
| R5 | No request value (`$_GET`, `$_POST`, `$_REQUEST`) is printed without `h()` |
| R6 | Every `<?= ... ?>` goes through `h()` or a helper that escapes. Ten outputs that print only fixed text, an integer or values already inside `h()` were reviewed by hand and are listed with the reason in the script (`REVIEWED`) |

**Result (21/11):** `main`: 41 pages, **0 FAIL**. The TEC-6..10 branch (PR #36, four more pages and their procedures): 45 pages, **0 FAIL**.
A deliberately bad page (request value as user id, SQL text, form without token, unescaped `$_GET`) gives 7 FAIL, so the
check does detect each rule.

**Horizontal access tests.** R3 proves the user id comes from the session, but a page also passes ids of objects
(premise, request, threshold, meter, task, portfolio) from the form. A forged form can change those, so the procedure must
check that the object belongs to the caller. `sql/tests/test_security.sql` attacks another user's objects through the
procedures, exactly as a forged form would, and checks the objects stay unchanged:

| Role | Forged call on another user's object | Refused with |
|---|---|---|
| Consumer | end holding, file a request, set a threshold on a premise of another consumer | 51006, 51006, 51200 |
| Consumer | cancel request, remove threshold of another consumer | 51023, 51203 |
| Consumer | read 15-minute readings or history of another consumer's meter | 51100, 51100 |
| Technician | open, read notes of, add a note to, accept, complete another technician's task | 52120 (all five) |
| Aggregator | list, rename, add a premise to another company's portfolio | 52512 (all three) |

The staff roles (Operator, Admin, DSO, TSO) act on every object by design, so for them only the role check applies
(R1 and the area asserts, section 2). Supplier pages take no object ids: they read only sums over their own customers.

**Result:** full build + all tests (`bash sql/tools/test_local.sh`): **ALL OK**, 18 of them from `test_security.sql`.
