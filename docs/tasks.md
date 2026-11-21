# Task board

[← Back to the menu](../README.md) · How tasks move: [03-workflow.md](03-workflow.md)

Anyone can take any `○` task whose **Needs** are all `✓`, in table order unless the group decides otherwise.
**In progress is not written here.** It is a pushed branch `task/<ID>-<slug>` with a note in `docs/handoff/<ID>.md`.
The row turns `👀` on the task branch when the PR opens, and `✓` on `main` at merge.

`○` free · `👀` in review · `✓` merged · `✂` cut · ★ = must be shown in the demo

## Foundation

| ID | Task | Doc | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| F-1 | Schema: `create.sql`, `drop.sql`, `test-step0.sql`, the professor's changes | [04](04-database-schema.md) | | 22/11 | ✓ | 56 tables, 17/17 OK (PR #4) |
| F-2 | Base data `data/small/00_base.sql`: one user per role, geography, OBIS, transformer tree, premises, active meters, readings, aggregates | [13](13-data-sets.md) | | 22/11 | ✓ | 10 users, 5 meters, 1,102 raw, 960 validated (PR #4) |
| F-3 | PHP skeleton + `procs_common.sql` + `test_local.sh` + `CLAUDE.md` | [12](12-php-web-app.md) | | 22/11 | ✓ | Login tested for every role; test_common 11/11 OK (PR #4) |
| F-4 | Plan, guide, task board | [03](03-workflow.md) | | 21/11 | ✓ | Replaced by REL-0 |

## ADM: admin, operator catalogs ([05](05-users-roles-login.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| ADM-1 | ★ Consumer self-registration (procedure + page) | III.1.1 | | 24/11 | ✓ | `sp_auth_register_consumer`, `register_consumer.php` (PR #4) |
| ADM-2 | Admin: create Operator/DSO/TSO/Supplier/Aggregator users, suspend/activate, view the audit log | General | | 25/11 | ○ | |
| ADM-3 | Operator catalogs: meter models, service types, tariffs | General | | 25/11 | ○ | |
| ADM-4 | PHP pages: admin users, log, operator catalogs | IV | ADM-2, ADM-3 | 29/11 | ○ | |

## CON: consumers ([06](06-consumers.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| CON-1 | ★ Premises + bank accounts | III.1.1 | | 24/11 | ✓ | `sp_consumer_add_premise`, `list_premises`, `end_holding`, `add_bank_account`, `list_bank_accounts`, pages `10_premises`, `20_bank` (PR #4) |
| CON-2 | ★ Readings: current month free, history through a purchased service, within retention | III.1.2 | | 26/11 | ○ | |
| CON-3 | Thresholds, notification channels, power-quality events | III.1.2 | | 26/11 | ○ | |
| CON-4 | ★ Check/fault requests + history | III.1.3 | | 25/11 | ✓ | `sp_consumer_submit_request`, `list_requests`, `cancel_request`, `list_meters`, page `30_requests` (PR #4) |
| CON-5 | ★ Invoices, payments, paying an invoice | III.1.3 | | 26/11 | ✓ | `sp_consumer_list_invoices`, `list_payments`, `pay_invoice`, page `40_billing` (PR #4) |
| CON-6 | PHP pages for CON-2 and CON-3 | IV | CON-2, CON-3 | 29/11 | ○ | |
| CON-7 | Fix: consumer procedures call `dbo.fn_consumer_holds`, which fails on the department server (per-user schemas) | Bug | | 22/11 | 👀 | Now an inline table-valued function; 37/37 OK on a member database |

## GDP: GDPR and retention ([07](07-gdpr-and-retention.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| GDP-1 | ★ GDPR: submit → operator pre-approves → admin decides → apply | III.1.4 | | 27/11 | ○ | |
| GDP-2 | Retention: raw 3 years, or 1 month after GDPR | III.1.4 | | 27/11 | ○ | Agreement X5 |
| GDP-3 | PHP pages: consumer, operator and admin GDPR; retention button | IV | GDP-1, GDP-2 | 29/11 | ○ | |

## TEC: technicians and meters ([08](08-technicians-and-meters.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| TEC-1 | ★ Technician registration + categories | III.2.1 | | 24/11 | ○ | |
| TEC-2 | Technician documents | III.2.1 | | 24/11 | ○ | |
| TEC-3 | Availability (time + area) | III.2.1 | | 25/11 | ○ | |
| TEC-4 | ★ Operator: approve/reject technician, review documents | III.2.1 | TEC-1, TEC-2 | 25/11 | ○ | |
| TEC-5 | ★ Field tasks: create (also from a consumer request), assign, accept, notes, complete | III.2.2 | | 26/11 | ○ | Agreement X1 |
| TEC-6 | ★ Meter install/replace + equipment documents | III.2.3 | TEC-5 | 26/11 | ○ | |
| TEC-7 | ★ Operator: confirm meter → Active | III.2.3 | TEC-6 | 26/11 | ○ | |
| TEC-8 | Remote commands + attempts until ACK | III.2.4 | | 27/11 | ○ | |
| TEC-9 | Anti-tamper checks, event → new task | III.2.4 | TEC-5 | 27/11 | ○ | Agreement X4 |
| TEC-10 | PHP pages: technician, operator (technicians, meters, tasks) | IV | TEC-4, TEC-5, TEC-7 | 29/11 | ○ | |

## MKT: suppliers and aggregators ([11](11-suppliers-aggregators.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| MKT-1 | ★ Supplier aggregates (Day-Ahead) | III.5.1–5.2 | | 27/11 | ○ | Agreement X6 |
| MKT-2 | Aggregator portfolio + aggregates | III.5.1 | | 27/11 | ○ | |
| MKT-3 | ★ Intraday provisional (from raw) | III.5.2 | | 27/11 | ○ | |
| MKT-4 | PHP pages: supplier, aggregator | IV | MKT-1, MKT-2, MKT-3 | 29/11 | ○ | |

## DSO: ingestion and VEE ([09](09-dso-ingestion-vee.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| DSO-1 | ★ Ingest JSON packet → `TELEMETRY_PACKET` + `RAW_READING`, failures as events | III.3.1 | | 25/11 | ○ | Agreements X2, X4 |
| DSO-2 | ★ VEE: validation (range, spike, gaps), estimation (interpolation), write `VALIDATED_READING` | III.3.2 | | 26/11 | ○ | Base data has Pending raw rows to work on |
| DSO-3 | Suspect readings + manual edit | III.3.2 | DSO-2 | 26/11 | ○ | |
| DSO-4 | ★ Aggregates: meter (Day/Month/Year) + leaf transformer | III.3.2 | DSO-2 | 27/11 | ○ | |
| DSO-5 | Analytics: under/over-voltage, phase imbalance → `EVENT` | II.C | | 27/11 | ○ | |
| DSO-6 | PHP pages: DSO | IV | DSO-1, DSO-2, DSO-4 | 29/11 | ○ | |

## TSO: transformer tree ([10](10-tso-transformers.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| TSO-1 | ★ New transformer + geofence, tree (recursive CTE), locate geofence from coordinates | III.4.1 | | 25/11 | ○ | |
| TSO-2 | ★ Current state (refresh leaves + sum upwards) | III.4.2 | | 27/11 | ○ | |
| TSO-3 | ★ Aggregates at any level (month → quarter) | Professor | | 27/11 | ○ | |
| TSO-4 | ★ Load shedding on every meter below a transformer | II.D | | 27/11 | ○ | Agreement X3 |
| TSO-5 | PHP pages: TSO | IV | TSO-1, TSO-2, TSO-3, TSO-4 | 29/11 | ○ | |
| TSO-6 | Leaflet map (bonus +10%) | Bonus | TSO-1 | 2/12 | ○ | Only if time allows |

## DAT: large data ([13](13-data-sets.md))

| ID | Task | Spec | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| DAT-1 | Large data: users, premises, contracts, invoices | IV | | 30/11 | ○ | |
| DAT-2 | Large data: technicians, tasks, documents, portfolios | IV | | 30/11 | ○ | |
| DAT-3 | Large data: readings (200k–500k), packets | IV | | 30/11 | ○ | |
| DAT-4 | `.dat` files + `data/import.sql` load cleanly on an empty database | V.A | DAT-1, DAT-2, DAT-3 | 30/11 | ○ | |

## PRF, SEC, CCY, EXT: quality and documents

| ID | Task | Doc | Needs | Due | Status | Notes |
|---|---|---|---|---|---|---|
| PRF-1 | Index on invoices | [14](14-indexes-and-performance.md) | | 1/12 | ○ | |
| PRF-2 | Index on field tasks | [14](14-indexes-and-performance.md) | TEC-5 | 1/12 | ○ | |
| PRF-3 | Index on readings + before/after case | [14](14-indexes-and-performance.md) | DSO-2 | 1/12 | ○ | |
| PRF-4 | 10,000-request test (95% < 2 s) | [14](14-indexes-and-performance.md) | DAT-4 | 1/12 | ○ | |
| SEC-1 | SQL injection and access check of every page | [16](16-security.md) | all page tasks | 1/12 | ○ | |
| SEC-2 | Security document | [16](16-security.md) | | 2/12 | ○ | docx (b) |
| CCY-1 | Concurrency / contention document | [15](15-concurrency.md) | DSO-2 | 2/12 | ○ | docx (b) |
| EXT-1 | Extensibility document | [17](17-extensibility.md) | | 2/12 | ○ | docx (b) |

## DOC, REL: final deliverables ([18](18-deliverables-and-timeline.md))

| ID | Task | Needs | Due | Status | Notes |
|---|---|---|---|---|---|
| REL-0 | Docs restructure: README menu, component docs, start/stop protocol, no personal ownership | | 21/11 | 👀 | PR #7 |
| REL-1 | Integration on the demo database `sharal01` + `~sharal01/public_html/mdms` | all ★ tasks | 30/11 | ○ | |
| DOC-1 | User manual (with every component's section) | | 2/12 | ○ | docx (a) |
| DOC-2 | New ER diagram (Chen, ERD+) + relational diagram matching the final `create.sql` | REL-1 | 2/12 | ○ | Decision B13 |
| DOC-3 | Data dictionary (every table and column explained) | | 2/12 | ○ | |
| REL-2 | Clean-database rehearsal: drop → create → procs → indexes → data | REL-1 | 3/12 | ○ | |
| REL-3 | 30-minute demo rehearsal (everyone presents and explains an area they did not build) | REL-2 | 3/12 | ○ | |
| REL-4 | `12.zip` + printed `docx/` + Moodle upload before 11:00 | REL-3 | 4/12 | ○ | |

## Old IDs

Commits and PR #4 use the old IDs: S1→ADM-1, S2→ADM-2, S3→ADM-3, S4→CON-1, S5→CON-2, S6→CON-3, S7→CON-4, S8→CON-5,
S9→GDP-1, S10→GDP-2, S11→ADM-4/CON-6/GDP-3, S12→DAT-1, S13→PRF-1/SEC-1, S14→SEC-2; D1–D9→TEC-1–9, D10–D12→MKT-1–3,
D13→TEC-10/MKT-4, D14→DAT-2, D15→PRF-2, D16→EXT-1, D17→DOC-1; A1–A5→DSO-1–5, A6–A9→TSO-1–4, A10→DSO-6/TSO-5,
A11→DAT-3, A12→PRF-3, A13→PRF-4, A14→CCY-1, A15→TSO-6; E1→REL-1, E2→DOC-2, E3→DOC-3, E4→REL-2, E5→REL-3, E6→REL-4.
