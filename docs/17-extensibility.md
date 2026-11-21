# 17. Future extension

[← Back to the menu](../README.md) · Task: EXT-1 in [tasks.md](tasks.md) · Part of docx (b), chapter (c)

> **Status: written.** "Added with a row" means the schema and the procedures stay as they are. Where something is only planned, the text says "planned".

## 1. Principle

New kinds of things (meter models, protocols, OBIS codes, rules) are **data, not structure**. We keep them in small lookup tables that other tables reference by key, and we avoid hard-coded lists in CHECK constraints for anything that is likely to grow. Business rules are read from those tables at run time (the VEE reads its rules and limits from `OBIS_CODE`, `VEE_RULE` and `RULE_FOR`). The closed lists that remain (for example the eight roles or the invoice statuses) are closed on purpose, because code depends on them.

## 2. What can be added without a structural change

| New thing | How it is added | Why no structure changes |
|---|---|---|
| Meter model or type | A row in `METER_MODEL`. The Operator does it on the catalog page (`sp_operator_save_meter_model`, audited). | `MeterType` is open text, only `(Manufacturer, ModelName)` is unique and `PhaseCount` is 1 to 3. |
| Communication type (protocol) | A row in `COMM_TYPE` (`Name`). | Meters reference it by `CommTypeID`, and `Name` is only unique, with no CHECK list. No page for this yet (SQL insert). |
| OBIS code | A row in `OBIS_CODE`: `ObisCode`, `Description`, `Unit`, `Kind` (cumulative or instantaneous), `Phase`, `MinValid`, `MaxValid`. | `sp_dso_ingest_packet` accepts any code found in `OBIS_CODE`, and VEE takes the limits from the same row. The table already holds twelve codes (energy, reactive energy, voltage and current per phase). No page yet (SQL insert). |
| VEE rule parameters | The `Parameters` JSON of a `VEE_RULE` row (`CK_VEE_RULE_Parameters` requires valid JSON). Today the `Spike` rule reads `factor` and `window`, the `VoltageBand` rule reads `min` and `max`. | Changing a limit is an `UPDATE` of one row. No code change. |
| Apply a rule to a code | A row in `RULE_FOR (RuleID, ObisCode)`. | The VEE joins `RULE_FOR` to decide which active rules (`IsActive = 1`) apply to each code. Switching a rule off is `IsActive = 0`. |
| Supply scheme or prosumer class | A row in `SUPPLY_SCHEME` (today `Standard`, `Net Metering`, `Net Billing`). | Premises reference it by `SchemeID`. |
| Tariff type | A row in `TARIFF_TYPE`, by the Operator (`sp_operator_save_tariff_type`). | Contracts reference it by key. |
| Paid service type and its fee | A row in `SERVICE_TYPE`, by the Operator (`sp_operator_save_service_type`). | The history service is `ServiceTypeID = 1`, the fee is data. |
| Technician category | A row in `TECHNICIAN_CATEGORY`. | Referenced by key. |
| Event type | A new text value in `EVENT.EventType` (VARCHAR(30), no CHECK), with a severity of `Info`, `Warning` or `Critical`. | Decision B14 in [19](19-conventions.md) lists the agreed values. A new one is a new value used by a procedure. |
| Remote command type | A new text value in `REMOTE_COMMAND.CommandType` (no CHECK on the type; `Parameters` is free JSON). | Only `Load shed` is tied to a shed order (`CK_REMOTE_COMMAND_ShedOrder`). A new command also needs its approval and sending logic if it differs from the ones in decision B15. |
| New region (district, municipality, parish) | Rows in `DISTRICT`, `MUNICIPALITY`, `PARISH`. | Plain lookup hierarchy. |
| New transformer level | Rows in `GEOFENCE` and `TRANSFORMER` with a `ParentTransformerID` (`sp_tso_add_transformer`). | The tree has no fixed depth. Triggers keep it a tree with meters only at leaves. |

Rule types are the limit: the VEE procedure knows the types `Range`, `Spike`, `Gap`, `LinearEstimate` and `VoltageBand` by name. A new **parameter** or a new **code** for these types is a row. A completely new **type** of check needs a new branch in `sp_dso_run_vee` (a code change, but still no schema change).

## 3. Worked example: a new OBIS code with its VEE rules

Goal: the meters of a new model also report the reactive energy of quadrant 1, **5.8.0** (kvarh, cumulative). We want it stored, range checked, spike checked and gap estimated like active energy.

```sql
-- 1. The code and its valid range (for cumulative registers: energy of one 15-minute interval).
INSERT OBIS_CODE (ObisCode, Description, Unit, Kind, Phase, MinValid, MaxValid)
VALUES (N'5.8.0', N'Reactive energy, quadrant 1', N'kvarh', N'Cumulative register', NULL, 0, 50);

-- 2. Which existing rules apply to it:
--    1 = Range, 2 = Spike (factor 5, window 3), 3 = Gap, 4 = LinearEstimate
INSERT RULE_FOR (RuleID, ObisCode) VALUES (1, N'5.8.0'), (2, N'5.8.0'), (3, N'5.8.0'), (4, N'5.8.0');

-- 3. Optional: a stricter spike rule just for this code instead of rule 2.
INSERT VEE_RULE (RuleType, Parameters, IsActive) VALUES (N'Spike', N'{"factor": 3, "window": 5}', 1);
-- then link its new RuleID with RULE_FOR to 5.8.0 (and do not link rule 2 to it).
```

What happens next, with no change to any procedure:

1. A packet with `"obis": "5.8.0"` is no longer rejected as "unknown OBIS code" by `sp_dso_ingest_packet`. It is stored in `RAW_READING` as `Pending`.
2. `sp_dso_run_vee` loads the code's limits and its active rules from `RULE_FOR`, checks range and spike, estimates gaps, and writes `VALIDATED_READING` rows.

The steps follow directly from the joins in `sp_dso_ingest_packet` and `sp_dso_run_vee`; this exact example was not run as a test. A new protocol is the same kind of change: `INSERT COMM_TYPE (Name) VALUES (N'LoRaWAN')`, then meters of that type can be registered.

## 4. What would need a structural change

| Idea | Why it needs a change | What it would mean |
|---|---|---|
| **Free-drawn geofences (polygons)**, the professor's stated future work | `GEOFENCE` is a rectangle: `MinLat`, `MinLon`, `MaxLat`, `MaxLon` with `CK_GEOFENCE_Rectangle`. `sp_tso_locate` and the installation check use a bounding-box test. | Replace the four columns by a `geography` polygon (or a table of vertices), test containment with `STContains`, and add the map drawing in the page. The tree rule "child inside parent" needs a polygon test too. Planned, not started. |
| More than one role per username | The professor's rule is one username, one role. `USER_ACCOUNT.Role` is a single column with a CHECK, and the session stores one role. | A `USER_ROLE` table, a role switch in the session, and every assert procedure changed to look at the table. |
| A new role | The role list is a CHECK, each role has a folder of pages, an assert procedure and a menu entry. | Edit the CHECK, add the assert and the pages. |
| Partition `RAW_READING` by month for 400,000 meters | At 96 readings per meter per day per code, the table grows by tens of millions of rows a day at full scale. | Partition function and scheme on `IntervalStart`, aligned indexes, retention by switching out a partition instead of batch deletes (`sp_retention_purge`). The key `(MeterID, ObisCode, IntervalStart)` would need the partition column, which it already contains. Not built. |
| A scheduler instead of buttons | VEE, the current-state refresh and the retention purge start from a button on purpose (no job host on the student server). | Run the same procedures from SQL Server Agent or a cron job under a service login. The procedures are already safe to call repeatedly: single-run locks and `READPAST` exist (see [15](15-concurrency.md)). Only the trigger changes. |
| `SNAPSHOT` or `READ_COMMITTED_SNAPSHOT` | Needs a database setting we may not be allowed to change (open question to the professor). | `ALTER DATABASE ... SET READ_COMMITTED_SNAPSHOT ON`. The explicit hints stay correct, readers would stop waiting on writers. |
| Vehicle-to-Grid and micro-grids from the specification's introduction | Not in the required scope. A vehicle is a mobile storage that both imports and exports, a micro-grid is a group of premises that can run islanded. | Likely a new entity for storage assets and a way to group transformers into a micro-grid with its own balance. Not designed beyond this idea. |
| Real telemetry transport (MQTT or HTTP endpoint) | Today a DSO user pastes JSON on a page, the "meters" are simulated. | A small service that calls `sp_dso_ingest_packet` for each message. The procedure and its locking already assume many parallel callers. |

## 5. How to decide if a change is structural

A short test used by the team: if the change adds a value that existing code treats as "any row of this table", it is data. If existing code names the values (a CHECK list, an `IF @Role = ...`, a `RuleType = 'Spike'` branch), a code or schema change is needed, and the change must follow the schema-change process in [19](19-conventions.md), section 6.
