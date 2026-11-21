# 10. TSO: transformer tree (III.4)

[← Back to the menu](../README.md) · Tasks: TSO-1 … TSO-6 in [tasks.md](tasks.md)

> **Status: plan only.**

## Requirements (spec III.4 + the professor's changes)

- Transformers form a **tree**: one parent each, meters **only on leaves**. Every transformer has one rectangular geofence.
- From a meter's coordinates, find which geofence it falls in, and so its transformer.
- Current state per 15 minutes: SUM of `1.8.0` and `2.8.0` over VEE-verified readings, started by a button. Missing readings are ignored. Stored in an intermediate table.
- Aggregates are **stored only for leaves**. Higher levels are computed when asked (month → quarter).
- Remote load shedding on **every** meter below a transformer.

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| TSO-1 ★ | `sp_tso_add_transformer` (GEOFENCE + TRANSFORMER), `sp_tso_tree` (recursive CTE with levels), `sp_tso_locate(@Lat, @Lon)`: the leaf geofence with `MinLat ≤ lat ≤ MaxLat` and so on | `TRANSFORMER`, `GEOFENCE` | `tso/tree.php` |
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
