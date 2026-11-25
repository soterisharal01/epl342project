# 01. Project overview and goals

[← Back to the menu](../README.md)

## What we are building

**MDMS-Cy** ("Smart National Meter Data Management System") is the central database for about
400,000 smart electricity meters in Cyprus. Every meter sends a packet every 15 minutes with readings
identified by **OBIS codes**, for example `1.8.0` for imported energy, `2.8.0` for exported solar energy
and `32.7.0` for phase L1 voltage. The system has to:

1. **Accept** each packet, match it to a real, active meter, and store its readings in the right 15-minute slot. A packet that cannot be matched is recorded as a failure, never silently dropped.
2. **Clean** the readings with **VEE**:
   - **Validation** flags bad values. Example: 1.8, 2.0, 1.9, then **25.4 kWh** is a spike.
   - **Estimation** fills gaps. Example: 2.0 at 10:15 and 2.2 at 10:45 give an estimated **2.1** for 10:30.
   - **Editing** is a controlled manual fix that keeps the old value, the new value and who made the change.
3. **Freeze** the result. After VEE, readings are **immutable**, and aggregates (day, month, year) are computed **only** from frozen readings, so they never need recomputing.
4. **Serve** the data to each stakeholder, showing each one only what they are allowed to see.

The course is a database course, so the grade rewards **correct design and logic in the database**: stored
procedures, transactions, constraints and triggers. The web pages are a thin layer on top.

## Who uses it (one role per username)

| Role | Who | What they do |
|---|---|---|
| **Admin** | System administrator (root) | Creates staff users, makes the final GDPR decision, sees the audit log |
| **Operator** | System operator | Approves technicians, confirms installed meters, maintains catalogs, pre-approves GDPR requests |
| **Consumer** | Household or business (also *prosumer* with solar) | Signs up alone. Manages premises and bank accounts, views own 15-min readings, submits fault or check requests, pays invoices, asks to be forgotten |
| **Technician** | Field technician | Signs up and waits for approval. Uploads documents, declares availability, accepts tasks, installs or replaces meters, sends remote commands |
| **DSO** | Distribution system operator | Ingests telemetry, runs VEE, fixes suspect readings, builds aggregates, detects voltage and phase problems |
| **TSO** | Transmission system operator | Manages the **transformer tree** and geofences, views current load per tree node, orders **load shedding** |
| **Supplier** | Electricity retailer | Sees aggregates for **its own** customers only, never raw data. Day-Ahead (validated, daily) and Intraday (provisional, 15-min) |
| **Aggregator** | Demand-response / renewables aggregator | Same as Supplier, but for the premises in **its portfolios** |

## The professor's 4 changes (meeting of 20/11/2026)

These changed the Phase A design and are already in `sql/create.sql`:

1. **One users table.** `USER_ACCOUNT` has a `Role` column, and the seven separate role tables are gone. A person with two roles gets two usernames.
2. **Raw, then validated.** `RAW_READING` holds what arrived. `VALIDATED_READING` holds what VEE produced, and a trigger blocks every update to it.
3. **Transformers are a strict tree.** Each transformer has one parent (the root has none). Meters attach only to **leaf** transformers. Every transformer has one rectangular geofence.
4. **Aggregates on leaf transformers.** `TRANSFORMER_AGGREGATE` (day, month, year) is stored only for leaves. Higher levels are computed on demand with a recursive query, for example month rolled up to quarter.

## How it works

```
Browser ──HTML──> PHP pages (university web server, ~user/public_html/mdms)
                    │  only {CALL sp_...(?, ?)} : no SQL in PHP
                    ▼
              SQL Server 2025 (mssql.cs.ucy.ac.cy\SQL2025)
              56 tables · CHECKs · triggers · stored procedures · AUDIT_LOG
```

Data pipeline:

```
JSON packet ─> TELEMETRY_PACKET ─> RAW_READING (Pending)
                                       │ VEE run
                                       ▼
                         VALIDATED_READING (immutable) ──> METER_AGGREGATE (Day/Month/Year)
                                       │                    └─> TRANSFORMER_AGGREGATE (leaves)
                                       └─> TRANSFORMER_CURRENT_STATE (latest 15-min, every node)
                                                   └─> any tree level: computed on demand
```

## How it is graded

| Part | Weight | Content |
|---|---|---|
| Phase A | 30% | Chen ER diagram + relational schema (ERD+). **Submitted 19/10.** |
| Phase B | 70% | Working system, SQL code, data, documentation, live exam |
| Bonus | +10% | Leaflet maps or other originality |

Phase B requirements the graders check:

- **Login** for every user, with passwords stored only as hashes.
- **Logic in the database.** Queries, checks and operations live in stored procedures; PHP only calls them.
- **Atomic operations.** Each operation runs as one transaction with TRY/CATCH.
- **Traceability.** Every important change writes a row to `AUDIT_LOG`: what changed, who changed it, when, old and new state, and a comment.
- **Synthetic data.** A small set and a large set with thousands of rows. Size counts.
- **3 indexes,** with the reason for each, plus one before/after case showing a cost reduction.
- **Performance.** 95% of normal OLTP queries finish under **2 seconds** across 10,000 requests.
- **Security** against unauthorized access and SQL injection.
- **Concurrency:** transactions, isolation levels and intermediate tables. Example: new readings arriving while VEE runs.
- **Extensibility without schema changes:** new meter types, protocols, prosumer classes and VEE rules.

**Exam:** every member presents the design and the implementation, and an absent member gets zero. Graded
on the correctness of the ER and schema, correct behaviour, performance and concurrency, how much is built,
and originality. **Each member must be able to explain the whole system**, not just their own part.

## Deliverables (Phase B)

`12.zip` uploaded to Moodle, containing:

- `sources/`: all PHP, HTML, CSS and JS.
- `sql/`: `create.sql`, `drop.sql`, the procedures, `indexes.sql`, `import.sql` and so on.
- `data/`: `.dat` files that can be imported, one small set and one large set.
- `docx/`: (a) a **user manual** (how to use it, design choices, extra features, difficulties, final ER, data dictionary, limitations); (b) a **separate document** on contention points, security and future extension. A printed copy goes to the lab.

## Where the team is now (21/11/2026)

| Done (merged to `main`) | Not started |
|---|---|
| Schema: 56 tables, 96 FKs, 106 CHECKs, 4 triggers, tested 17/17 | Technicians and meters, suppliers and aggregators |
| Shared demo data: 10 users, 6 transformers, 5 meters, 1,102 raw and 960 validated readings | DSO ingestion and VEE, TSO tree and load shedding |
| PHP skeleton: login, role menus, CSRF, error handling | Admin and catalogs, consumer readings and thresholds, GDPR, retention |
| Consumers: premises, bank accounts, requests, invoices and payments | Large data, indexes, performance test, every document |

Nobody owns a part: any member takes any free task ([tasks.md](tasks.md)), and the AI resumes the team's work on `start`
([03-workflow.md](03-workflow.md)). The live status is always the [task board](tasks.md), not this page.

## Goals

**System goals**

1. Every role logs in and every ★ demo screen works from the UI against **our** database.
2. The full pipeline runs: packet → raw → VEE (spike caught, gap estimated) → validated → aggregates.
3. The TSO sees the tree with totals per level, current state, and can shed load under any node.
4. GDPR runs end to end: submitted → operator pre-approves → admin decides → applied. Invoices are kept.
5. Large data set loads cleanly; 3 indexes with a measured before/after case; 95% of requests under 2 s.
6. The whole build runs from an empty database in order, with no errors.

**Team goals**

1. Every task through a reviewed PR, with its component doc updated, so anyone can continue it.
2. Every member understands every component well enough to answer exam questions about any of them.

## Key dates

| Date | Milestone |
|---|---|
| 22/11 | Foundation merged (done) |
| 24–27/11 | Stored procedures for every area |
| 27/11 | Last day for schema changes (after this, only for a ★ blocker) |
| 28–29/11 | PHP pages. Every role logs in and sees its ★ screens |
| 30/11 | Integration on the `sharal01` database, large data import |
| 1/12 | Indexes, SQL injection check, 10,000-request test |
| 2/12 | Documents, new ER diagram, **code freeze in the evening** |
| 3/12 | Clean-database rehearsal, 30-minute demo rehearsal |
| **4/12** | **Submit before 11:00** (deadline 12:00) |
