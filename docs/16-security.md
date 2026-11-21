# 16. Security

[← Back to the menu](../README.md) · Tasks: SEC-1, SEC-2 in [tasks.md](tasks.md) · Part of docx (b)

> **Status: plan only.** What the skeleton already does is in [12-php-web-app.md](12-php-web-app.md).

## Requirement

Protect against unauthorized access and SQL injection, and explain it.

## Planned content

- Password hashing (`password_hash` / `password_verify`), login and session handling.
- Role checks in **two layers**: the PHP page (`require_role`) and the procedure (`@UserID` role check).
- `?` parameters only (SQL injection). `htmlspecialchars` (XSS). CSRF tokens.
- No password anywhere in the repo or the zip (`config.php` is git-ignored).
- Least privilege: the web login gets `GRANT EXECUTE` on procedures only.
- GDPR ([07-gdpr-and-retention.md](07-gdpr-and-retention.md)).
- SEC-1: check every page for injection and access to other users' data.
