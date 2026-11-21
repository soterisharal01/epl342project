# 10. TSO: transformer tree (III.4)

[← Back to the menu](../README.md) · Tasks: TSO-1 … TSO-6 in [tasks.md](tasks.md)

> **Status: TSO-1 written (in review, not yet run on a database). TSO-2 … TSO-6 are plans.**

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

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
|---|---|---|---|
| TSO-2 ★ | `sp_tso_refresh_current_state(@UserID)`: `MERGE` into `TRANSFORMER_CURRENT_STATE` for leaves. `sp_tso_current_state(@TransformerID)`: for a non-leaf, sums the leaves below with a CTE | `TRANSFORMER_CURRENT_STATE`, `VALIDATED_READING` | `tso/state.php` |
| TSO-3 ★ | `sp_tso_aggregates(@UserID, @TransformerID, @PeriodType, @From, @To)`: CTE over the tree, `GROUP BY` quarter when asked | `TRANSFORMER_AGGREGATE` | `tso/aggregates.php` |
| TSO-4 ★ | `sp_tso_load_shed(@UserID, @TransformerID, @Reason)`: `LOAD_SHED_ORDER` and one `REMOTE_COMMAND` per meter on the leaves below, all in **one transaction** (agreement X3: `CommandType = 'Load shed'`) | `LOAD_SHED_ORDER`, `REMOTE_COMMAND` | `tso/shed.php` |
| TSO-5 | Pages for the tasks above | | |
| TSO-6 | Bonus: Leaflet map of transformers, geofences and meters, `sp_tso_map_data` | | `tso/map.php` |

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
