# 10. TSO: transformer tree (III.4)

[← Back to the menu](../README.md) · Tasks: TSO-1 … TSO-6 in [tasks.md](tasks.md)

> **Status: TSO-1 … TSO-4 written (in review, not yet run on a database). TSO-5 is a plan. TSO-6 (map) is written, in review.**

## Requirements (spec III.4 + the professor's changes)

- Transformers form a **tree**: one parent each, meters **only on leaves**. Every transformer has one rectangular geofence.
- From a meter's coordinates, find which geofence it falls in, and so its transformer.
- Current state per 15 minutes: SUM of `1.8.0` and `2.8.0` over VEE-verified readings, started by a button. Missing readings are ignored. Stored in an intermediate table.
- Aggregates are **stored only for leaves**. Higher levels are computed when asked (month → quarter).
- Remote load shedding on **every** meter below a transformer.

## What exists

### TSO-1: tree, geofences, locate (`sql/procs_tso.sql`, tests `sql/tests/test_tso.sql`, page `sources/tso/10_tree.php`)

| Procedure | What it does |
|---|---|
| `sp_tso_assert(@UserID)` | Helper. Refuses (53500) unless the user is an Active TSO. |
| `sp_tso_add_transformer(@UserID, @Name, @Latitude, @Longitude, @ParentTransformerID, @GeofenceName, @MinLat, @MinLon, @MaxLat, @MaxLon)` | Inserts `GEOFENCE` + `TRANSFORMER` in one transaction, writes `AUDIT_LOG`, returns `TransformerID, GeofenceID`. |
| `sp_tso_tree(@UserID, @RootID = NULL)` | Recursive CTE from the root (or a node). Columns: `TransformerID, Name, ParentTransformerID, Level` (root 0), `Path` (`T-ROOT … > … > node`), `IsLeaf, DirectMeters, TotalMeters` (whole subtree, all meter statuses), geofence id, name and bounds. Depth-first order. `TotalMeters` comes from a separate ancestor/descendant step, because a recursive CTE part cannot aggregate. |
| `sp_tso_locate(@UserID, @Latitude, @Longitude)` | The **leaf** transformer(s) whose geofence contains the point (bounds inclusive), smallest area first, with the ancestor `Path`. No leaf (for example outside Cyprus) returns 0 rows. Neighbouring leaves that share an edge both match; the first row is the best. |
| `sp_tso_check_meter_locations(@UserID)` | Every meter with its registered transformer and the leaf found from its coordinates. `Result` is `OK`, `Mismatch` or `NoGeofence`. |

Validation in `sp_tso_add_transformer` (checked before anything is written):

| THROW | Rule |
|---|---|
| 53500 | Not an Active TSO |
| 53501 | Transformer or geofence name empty |
| 53502 | Rectangle not valid (`MinLat < MaxLat`, `MinLon < MaxLon`, within the Earth) |
| 53503 | The transformer point is outside its own geofence |
| 53504 | The parent does not exist |
| 53505 | No parent given but a root already exists (exactly one root) |
| 53506 | The parent has meters (meters only on leaves; the trigger `TR_TRANSFORMER_Tree` would give 50001, this gives a clear Greek message first) |
| 53507 | The child geofence is not inside the parent geofence (**enforced**, not a warning) |
| 53508 | Invalid coordinates (also `sp_tso_locate`) |
| 53509 | `sp_tso_tree` was given a node that does not exist |

Design choices: a new transformer is always a leaf; its parent stops being a leaf. Test transformers `T-TEST-*` stay in the database
(under T-LIM, in an area without meters). The page `tso/10_tree.php` shows the indented tree, a locate form and an add form (CSRF, `call_proc` only).

### TSO-2: current state (`sql/procs_tso.sql`, page `sources/tso/20_state.php`)

| Procedure | What it does |
|---|---|
| `sp_tso_refresh_current_state(@UserID)` | Button, no scheduler. **Reference interval** = the latest `IntervalStart` that has a validated `1.8.0` or `2.8.0` reading (`MAX` over `VALIDATED_READING`); 53600 if there are none. For every **leaf** and both codes: `SUM(Value)` of its meters at that interval and the number of meters that contributed (`B2`: `Value` is 15-minute energy). Missing readings are ignored; meter status is not filtered, because a reading exists only if VEE accepted it. A leaf with no reading gets a row with `SumValue 0`, `MeterCount 0`. Then **every node** of the tree (leaves and all ancestors, B16) gets the sum of the leaves below it, at any depth (recursive CTE of ancestor/descendant pairs). One `MERGE` of all nodes into `TRANSFORMER_CURRENT_STATE` (rows of deleted nodes are removed), so a leaf and all its ancestors change together. One transaction, one `AUDIT_LOG` row. Returns `RefInterval, LeafCount, RowsAffected`. |
| `sp_tso_current_state(@UserID, @TransformerID = NULL)` | Every node (or the given node and its subtree), in tree order: `TransformerID, Name, Level, Path, RefInterval, ImportKWh` (1.8.0)`, ExportKWh` (2.8.0)`, NetKWh, MeterCount` (meters that contributed to 1.8.0). Read only: each node's own stored row of the intermediate table (the refresh already stored ancestors), no recomputation. A node added after the last refresh shows 0. Before any refresh the numbers are 0 and `RefInterval` is `NULL`. 53601 if the node does not exist. |

### TSO-3: aggregates at any level (`sql/procs_tso.sql`, page `sources/tso/30_aggregates.php`)

| Procedure | What it does |
|---|---|
| `sp_tso_aggregates(@UserID, @TransformerID, @PeriodType, @From, @To)` | Reads the stored `TRANSFORMER_AGGREGATE` rows of the **leaves** under the node (recursive CTE) and sums them per period for `1.8.0` and `2.8.0`. Returns `PeriodStart, ImportKWh, ExportKWh, NetKWh, LeafCount` (leaves with data in that period). **Never writes** to the table (DSO-4 does). |

Roll-up choice: `Day` returns the stored Day rows in `[@From, @To]`. `Month`, `Quarter`, `Year` use the **month per leaf and code** as the base: a stored `Month` row if there is one, otherwise the sum of that month's `Day` rows (so nothing is counted twice). The month then goes into its quarter (`DATEFROMPARTS(YEAR, (DATEPART(QUARTER)-1)*3+1, 1)`) or year. Stored `Year` rows are not used. For these three types the range is widened to **whole periods** (the start of the period of `@From` to the end of the period of `@To`). Errors: 53610 bad period type, 53611 `@From > @To`, 53612 unknown transformer.

### TSO-4: load shedding (`sql/procs_tso.sql`, page `sources/tso/40_shed.php`)

| Procedure | What it does |
|---|---|
| `sp_tso_load_shed(@UserID, @TransformerID, @Reason)` | One transaction: `LOAD_SHED_ORDER` (`Status 'Issued'`, `OrderedBy`) + one `REMOTE_COMMAND` per **Active** meter on every leaf under the node (`CommandType 'Load shed'`, `Status 'Sent'`, `ShedOrderID`, `RequestedBy`, `Parameters = {"shedOrderID": n}`; agreement X3) + `AUDIT_LOG`. `Pending confirmation` and `Retired` meters are skipped. Refused (nothing written) with 53620 empty reason, 53621 unknown transformer, 53622 no Active meter below. Returns `ShedOrderID, CommandCount`. |
| `sp_tso_list_shed_orders(@UserID)` | Orders, newest first: reason, status, transformer name, who ordered, and command counts (total and per status). |

Tests for TSO-2/3/4 are appended to `sql/tests/test_tso.sql` (role checks, refresh against a direct `SUM`, root = sum of leaves, Day/Quarter/Month/Year,
load shed on transformer 2 gives 3 commands for meters 1, 2, 4, refusals leave nothing behind). They create real shed orders and commands in the test database.

THROW numbers used by the area so far: 53500–53509 (TSO-1), 53600–53601 (TSO-2), 53610–53612 (TSO-3), 53620–53622 (TSO-4).

### TSO-6: map (bonus, `sql/procs_tso.sql`, page `sources/tso/50_map.php`)

| Procedure | What it does |
|---|---|
| `sp_tso_map_data(@UserID)` | Read only, **one** result set (`call_proc` reads only the first). Column `Kind` is `'Transformer'` (id, name, lat, lon, parent, level, leaf flag, geofence MinLat/MinLon/MaxLat/MaxLon, import/export kWh = `1.8.0`/`2.8.0` summed from `TRANSFORMER_CURRENT_STATE` over the subtree) or `'Meter'` (id, serial, lat, lon, status, transformer id). Columns that do not fit the kind are NULL. Allowed for an active TSO, DSO or Operator (they see the same network, nothing changes); otherwise 53800. |

How the map works: the page `50_map.php` (TSO only) calls the procedure, puts the rows into a script as JSON (`json_encode` with `JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT`),
and Leaflet draws: geofence rectangles (leaves filled, higher levels dashed), a marker per transformer (popup: name, level, import/export), a circle per meter coloured by status
(green Active, orange Pending confirmation, grey Retired), and a layer control to switch the three layers. Popups are built with text nodes, never `innerHTML`. The view fits the network.
Leaflet 1.9.4 is vendored in `sources/lib/leaflet/` so the UI works from the zip offline. The OpenStreetMap background tiles need the internet; offline the vector layers still show on a blank background.
Tests (`test_tso.sql`, prefix `@m6_`): Consumer refused with 53800, transformers 1-6 present with geofence/level/leaf, meters 1-5 with coordinates, Operator allowed.
THROW numbers: 53800 (TSO-6).

## Planned

| Task | What | Page |
|---|---|---|
| TSO-5 | Review of the pages above | |

## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 4.1 Every meter has WGS84 coordinates and belongs to **one** low-voltage transformer. Every transformer has **one** geofence (here a rectangle).
- [ ] 4.1 From a meter's coordinates we find the geofence and so the transformer.
- [ ] 4.1 Hierarchy of any depth (L1 … Ln).
- [ ] 4.2 **VEE-verified** picture, per 15 minutes, for the **whole** hierarchy. L1 nodes count their own meters; higher nodes count **all** meters below them, at any depth.
- [ ] 4.2 SUM per geofence, 15-minute slot and OBIS, **only** for `1.8.0` and `2.8.0`.
- [ ] 4.2 Stored in an **intermediate** table with at least geofence (here transformer, B16), a **common** reference slot, OBIS, SUM. Manual trigger is enough. Missing readings are simply ignored.
- [ ] 4.2 When a reading changes an L1, we can update it **and all its ancestors**.
- [ ] 4.2 Final 15-minute readings and historical aggregates stay immutable. The intermediate table gives the new picture without recomputing from raw.
- [ ] II.D Remote load disconnection on **all** meters of a transformer.

## Base data tree

```
1 T-ROOT Κύπρος
├── 2 T-NIC Λευκωσία
│   ├── 4 T-NIC-AGL   meters 1, 4
│   └── 5 T-NIC-AGA   meter 2
└── 3 T-LIM Λεμεσός
    └── 6 T-LIM-CEN   meters 3, 5 (5 is Pending confirmation)
```
