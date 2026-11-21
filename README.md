# MDMS-Cy: EPL342 Team 12

MDMS-Cy is a national smart-meter data system for Cyprus, built as a database project. Meters send 15-minute readings. The
system validates them (VEE), stores them so they can no longer change, rolls them up into aggregates, and serves them to eight kinds
of users through a PHP web app over SQL Server 2025. Phase A (ER model and schema) is submitted. Phase B (the working system) is
due **Friday 4/12/2026, 12:00**.

## How we work

Nobody owns a part. Open Claude Code in this repo and type:

- **`start`**: the AI reads the last [session note](docs/next-session.md), these docs, the task board, the handoff notes of
  unfinished tasks and the recent commits, then resumes where the team stopped or claims the next free task.
- **`stop`**: quick save. It writes the task's handoff note and pushes.
- **`finish`**: end of session. It does what `stop` does, updates every Markdown file to match the repo, and writes the session note for the next `start`.

Details: [docs/03-workflow.md](docs/03-workflow.md). The AI's exact procedure: [CLAUDE.md](CLAUDE.md).

## Menu

| # | Component | What it covers | Status |
|---|---|---|---|
| 01 | [Project overview and goals](docs/01-project-overview.md) | What we build, who uses it, grading, where we are | Written |
| 02 | [Environment setup](docs/02-environment-setup.md) | CS VPN, SSMS, SQL Server, hosting, local tools | Written |
| 03 | [Workflow](docs/03-workflow.md) | `start` / `stop`, task life cycle, handoff notes, reviews | Written |
| 04 | [Database schema](docs/04-database-schema.md) | 56 tables, triggers, the professor's 4 changes | Partly |
| 05 | [Users, roles and login](docs/05-users-roles-login.md) | One username per role, hashing, sessions, admin and catalogs | Written |
| 06 | [Consumers](docs/06-consumers.md) | Premises, bank accounts, readings, requests, invoices (III.1) | Written |
| 07 | [GDPR and data retention](docs/07-gdpr-and-retention.md) | Right to be forgotten, 3-year / 1-month retention | Written |
| 08 | [Technicians and meters](docs/08-technicians-and-meters.md) | Registration, approval, tasks, installation, commands (III.2) | Partly (TEC-6..10 in review) |
| 09 | [DSO: ingestion and VEE](docs/09-dso-ingestion-vee.md) | Packets, validation, estimation, editing, aggregates (III.3) | Written |
| 10 | [TSO: transformer tree](docs/10-tso-transformers.md) | Tree, geofences, current state, load shedding (III.4) | Written |
| 11 | [Suppliers and aggregators](docs/11-suppliers-aggregators.md) | Customer aggregates, Day-Ahead, Intraday (III.5) | Written |
| 12 | [PHP web app](docs/12-php-web-app.md) | Skeleton, automatic menu, calling procedures, deploying | Written |
| 13 | [Data sets](docs/13-data-sets.md) | Base demo data, large data, `.dat` and import | Partly (large set in review) |
| 14 | [Indexes and performance](docs/14-indexes-and-performance.md) | 3 indexes, before/after, 10,000-request test | Partly (numbers to measure) |
| 15 | [Concurrency](docs/15-concurrency.md) | Transactions, isolation, VEE during ingestion | Written |
| 16 | [Security](docs/16-security.md) | Access control, SQL injection, XSS, CSRF, secrets | Written |
| 17 | [Extensibility](docs/17-extensibility.md) | New types, codes and rules as rows, not schema changes | Written |
| 18 | [Deliverables and timeline](docs/18-deliverables-and-timeline.md) | The zip, documents, day plan, demo script, checklist | Written |
| 19 | [Conventions and decisions](docs/19-conventions.md) | Areas, code rules, table ownership, agreements, decisions B1–B13 | Written |
| 20 | [Data dictionary](docs/20-data-dictionary.md) | Every table and column explained | Written |
| 23 | [Release](docs/23-release.md) | Demo database build, web deploy, smoke test, `12.zip` checklist | Pack ready, needs the human |
| 24 | [Demo script](docs/24-demo-script.md) | 30-minute demo, presenters, fallbacks, professor questions | Pack ready, to rehearse |
| — | [Session note](docs/next-session.md) | Where the last session stopped, what to do next | Live |
| — | [Task board](docs/tasks.md) | Every task, its status and dependencies | Live |
| — | [Handoff notes](docs/handoff/) | One note per in-progress task (on its branch) | Live |
| — | [Phase A archive](docs/phase-a/README.md) | ER model tooling, design decisions D1–D32, study guide | Archive |

## Repo layout

| Folder | Content |
|---|---|
| `sql/` | `create.sql`, `drop.sql`, `procs_*.sql`, `tests/`, `tools/` (`build_all.py`, `test_local.sh`) |
| `data/` | `gen/` generators, `small/` demo data (later `large/*.dat`; their loader is `sql/import.sql`) |
| `sources/` | The PHP app (see [12](docs/12-php-web-app.md)) |
| `docs/` | Everything in the menu above |
| `er-model/`, `deliverables/phase-a/` | Phase A sources and submission |

## Quick facts

- **Database server:** `mssql.cs.ucy.ac.cy\SQL2025`, reachable only through the **CS department** VPN (not the central UCY one).
- **Demo users:** `admin`, `operator`, `consumer1`, `consumer2`, `tech1`, `tech2`, `dso1`, `tso1`, `supplier1`, `aggregator1`. Test password: header of `data/small/00_base.sql`.
- **Build order:** `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → data. One file for SSMS: `python sql/tools/build_all.py` → `sql/build/ALL.sql`.
- **The assignment PDF** is not in the repo (it is public). Each member has it from Moodle.
