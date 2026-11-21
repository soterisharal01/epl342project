# 02. Environment setup

[← Back to the menu](../README.md)

## 1. VPN: the right one

There are **two** university VPNs, and only one works for this project:

| VPN | Software | Reaches the CS database server? |
|---|---|---|
| **CS department VPN** | OpenVPN (or Securepoint) with the `CSVPNv{n}.ovpn` profile | **Yes**, use this one |
| Central UCY VPN | Fortinet (my.ucy.ac.cy) | **No**. It does not reach CS department systems |

### Installing the current profile (v5)

The department replaced its certificate authority with **"CS OpenVPN CA 2026"**. An old profile (v3 or earlier) fails with
`VERIFY ERROR ... unknown CA ... TLS handshake failed` in the OpenVPN log. That happens before login, so it is not a
password problem, and not a client-version problem either (OpenVPN 2.7.x works).

1. In a browser open <https://ftp.cs.ucy.ac.cy/vpn/>, log in with your **CS department** username and password, and open `OpenVPN/`.
2. Download `CSVPNv5.ovpn`, `ca.crt`, `client.crt` and `client.key`. Browsers may save some as `….ovpn.txt` or `client.key.txt`: remove the `.txt`.
3. Put the four files in **either** folder:
   - `%USERPROFILE%\OpenVPN\config\CSVPNv5\` (no admin rights needed), or
   - `C:\Program Files\OpenVPN\config\` (admin rights needed).

   Delete any older `CSVPNv*.ovpn` so you don't pick it by mistake.
4. Tray icon → Exit. Start **OpenVPN GUI** again (as administrator) → tray icon → `CSVPNv5` → Connect → CS username and password.
5. Success: the tray icon turns green. If not, read the end of `%USERPROFILE%\OpenVPN\log\CSVPNv5.log`.

The VPN uses split tunnel: only traffic to department systems goes through it.

## 2. SQL Server (SSMS)

- Server: **`mssql.cs.ucy.ac.cy\SQL2025`**. Without `\SQL2025` you reach a different server where our tables don't exist.
- Authentication: SQL Server Authentication. The login and database name are your department username; the password came by email in Lab 3.
- Always check that **your own** database is selected (top left in SSMS) before you press Execute.
- Never run `drop.sql` on someone else's database, including the team demo database `sharal01`.
- First setup: run `sql/drop.sql`, then `sql/create.sql` (56 tables). Optional check: `sql/test-step0.sql` (17 `OK`), then drop + create again.
- Everything at once: `python sql/tools/build_all.py` → open `sql/build/ALL.sql` in SSMS → Execute.

## 3. Hosting the PHP app

See [12-php-web-app.md](12-php-web-app.md), "Deploying". In short: copy `sources/` to `~/public_html/mdms/` through a lab
machine (for example `101ws3.in.cs.ucy.ac.cy` over Remote Desktop), create `config.php` from `config.example.php` yourself,
folders 755 and files 644, then open `https://students.cs.ucy.ac.cy/~<username>/mdms/`.
A 403 page usually means a SQL error. The department firewall hides pages that show SQL error text.

## 4. Tools per machine

| Tool | Needed for | Without it |
|---|---|---|
| Git (+ GitHub Desktop) | Clone, branch, push | Required |
| Python 3 | `python sql/tools/build_all.py --tests` → `sql/build/ALL.sql` | Required |
| OpenVPN + CS profile v5 | Database and web server access | Required |
| SSMS | Running SQL on your database | Required |
| Docker | `bash sql/tools/test_local.sh` (local SQL Server 2025 + all tests) | Run `ALL.sql` in SSMS on your own database instead |
| GitHub CLI (`gh`) | The AI opens PRs itself | Open the PR from the compare link the AI gives you |
| PHP | `php -l` syntax check | Check pages on your department web space |

## 5. Common problems

| Problem | Fix |
|---|---|
| SSMS doesn't connect | Is the CS VPN on? Is the server `mssql.cs.ucy.ac.cy\SQL2025`? SQL Server Authentication selected? |
| `Login failed (18456)` | Wrong password. Type it again carefully. |
| PHP page shows **403** | A SQL error on that page (often the server name without `\\SQL2025` in `config.php`), or file permissions not 644. |
| `There is already an object named …` | You didn't run `drop.sql` first, or the wrong database is selected. |
| Git conflict in someone else's file | Don't resolve it alone; ask in the group. |
| The AI changed `create.sql` | Don't push it. Ask it to revert, then follow [19-conventions.md](19-conventions.md), section 6. |
