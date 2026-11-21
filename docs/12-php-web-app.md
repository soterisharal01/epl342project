# 12. PHP web app

[← Back to the menu](../README.md) · Built in task F-3

> **Status: written for the skeleton.** Pages of each area are listed in that area's doc.

## What it does

The user opens the site, types their MDMS-Cy **username** and **password**, and logs in. The app asks the database who
they are and what **role** they have (one per username), then shows **only** that role's pages. Every page talks to
the database **only through stored procedures**, never with SQL written in PHP.

## Files

| File | What it does |
|---|---|
| `config.example.php` | Template for the database connection. Copy it to `config.php` and type in your password. `config.php` is git-ignored. |
| `db.php` | The bridge to the database. `db()` opens the connection once per page. `call_proc('sp_…', [values])` runs `{CALL sp_…(?, ?)}` and returns the rows of the first result set, or `false` (then `last_error()`). `print_table($rows, $headers)` prints rows as an HTML table. Helpers: `h()`, `select_options()`, `post_or_null()`, `money()`. Only our own `THROW` messages (50000–59999) reach the user; every other SQL error is written to the error log. |
| `auth.php` | Session and roles: `require_login()`, `require_role('Role', …)`, `current_user()`, `uid()`, `url()`, `redirect()`, `csrf_field()` / `check_csrf()`, `flash()`. The `ROLES` map links each role to its folder and Greek title. |
| `layout.php` | Shared look: top bar, side menu, footer (`page_header()` / `page_footer()`). **The menu builds itself:** every `.php` file in the role's folder whose first line is `<?php // MENU: <title>` becomes a link, sorted by file name (use `10_`, `20_` prefixes for order). |
| `index.php` | Login form, with sign-up links. |
| `login.php` | Checks the password with `password_verify` against the stored hash. Refuses suspended accounts and technicians not yet approved. Logs every attempt to `AUDIT_LOG`. Starts a new session id. |
| `logout.php`, `home.php`, `profile.php` | Log out; home page with buttons to the role's pages; own details and password change. |
| `register_consumer.php` | Consumer self-registration (ADM-1). |
| `_template.php` | Template for a new page. Copy it into a role folder. |
| `css/style.css`, `images/` | Look. |
| `admin/`, `operator/`, `consumer/`, `technician/`, `dso/`, `tso/`, `supplier/`, `aggregator/` | Each role's pages. |

## Making a new page

1. Copy `sources/_template.php` into the role folder, for example `sources/dso/20_vee.php`.
2. First line: `<?php // MENU: <menu title>`.
3. `require_role('DSO')`.
4. Call procedures with `call_proc('sp_…', [uid(), …])`. `uid()` always goes first: the procedure checks the role again.
5. POST forms: `csrf_field()` inside, `check_csrf()` in the handler, then `flash()` + `redirect()` (Post/Redirect/Get).
6. Print through `h()` or `print_table`.

## Why it is safe

SQL injection: values go only as `?` parameters to procedures. Passwords: only `password_hash` (bcrypt) is stored. XSS: everything printed goes
through `htmlspecialchars` (`h()`). CSRF: hidden token on every form. Roles: checked by the page **and again** by the procedure.
Session: new id after login, HTTP-only cookie. Logging: logins (successful and failed), registrations and password changes go to `AUDIT_LOG`.
More in [16-security.md](16-security.md).

## Deploying to the department server

1. Your database already has, in order: `create.sql` → `procs_common.sql` → other procs → `data/small/00_base.sql`
   (or everything at once: `python sql/tools/build_all.py` builds `sql/build/ALL.sql` for SSMS).
2. Copy **the contents** of `sources/` to `~/public_html/mdms/` on your account.
3. There, copy `config.example.php` to `config.php` and type in your password (only you).
4. Permissions: folders 755, files 644, **including `config.php`**. PHP runs as `apache` (mod_php) and the NFS has no ACLs, so with 600 the page gives HTTP 500.
   The cost: another student with a department Linux account could read it, so this database password must not be used anywhere else.
5. Open `https://students.cs.ucy.ac.cy/~<username>/mdms/` and log in, for example as `consumer1`
   (demo users and test password: header of `data/small/00_base.sql`).
6. From a lab terminal use `curl -k` (the server certificate fails curl's check there).
