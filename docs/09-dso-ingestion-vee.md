# 09. DSO: ingestion and VEE (III.3)

[← Back to the menu](../README.md) · Tasks: DSO-1 … DSO-6 in [tasks.md](tasks.md)

> **Status: partly written.** DSO-1 (ingestion) exists. DSO-2 … DSO-6 are still plans.

## Requirements

- A telemetry packet (JSON, spec appendix) is matched to an **active** meter by its network ID. Its readings go into the right 15-minute slot. Anything that does not match is recorded as a failure or event, **never lost silently**.
- At least the appendix OBIS codes: `1.8.0`, `1.8.1`, `1.8.2`, `2.8.0`, `3.8.0`, `4.8.0`, `32.7.0`, `52.7.0`, `72.7.0`, `31.7.0`, `51.7.0`, `71.7.0`. A packet may carry any subset. A new code = a new row, no schema change.
- **Validation:** supported code, `MinValid`/`MaxValid` range, spikes (25.4 after 1.8, 2.0, 1.9), gaps. **Estimation:** linear interpolation (2.0 and 2.2 → 2.1). **Editing:** a controlled fix keeping the old value, new value and origin.
- After VEE readings are **immutable**, and aggregates come **only** from them.
- Analytics: sags and swells (`32.7.0`, `52.7.0`, `72.7.0`), phase imbalance (`31/51/71.7.0`), suspected theft.

Example packet:

```json
{ "Meter_Network_ID": "EAC-NIC-74921", "Transmission_Timestamp": "2026-10-30T12:00:00Z",
  "Cell_Signal_Strength_dBm": -92, "Network_Type": "NB-IoT",
  "Telemetry_Payload": [ {"obis": "1.8.0", "value": 14250.3200, "unit": "kWh"},
                         {"obis": "32.7.0", "value": 228.40, "unit": "V"} ] }
```

## What exists

| Task | File | What it does |
|---|---|---|
| DSO-1 | `sql/procs_dso.sql` | `sp_dso_assert(@UserID)`: `THROW 53000` unless the user is an Active DSO. |
| DSO-1 | `sql/procs_dso.sql` | `sp_dso_ingest_packet(@UserID, @PayloadJson)`: one transaction. Always stores the packet first (`RawPayload` = the JSON), then returns one row `PacketID, IngestStatus, ReadingsStored, ErrorMessage`. Writes an `AUDIT_LOG` row. |
| DSO-1 | `sql/procs_dso.sql` | `sp_dso_list_packets(@UserID, @Top = 50, @Status = NULL)`: newest packets with status, meter serial, number of readings. Errors 53001 (`@Top`), 53002 (status). |
| DSO-1 | `sql/procs_dso.sql` | `sp_dso_list_raw(@UserID, @MeterID, @From, @To)`: raw readings of one meter, both ends inclusive (UTC). Errors 53003 (no such meter), 53004 (bad period). |
| DSO-1 | `sql/tests/test_dso.sql` | 39 `OK`/`FAIL` checks: roles, success, 10:07:30 -> 10:00 slot, duplicate, unknown OBIS, malformed, unknown meter, inactive meter, lists. Run once per clean database (it writes 2026-11-21 rows). |
| DSO-1 | `sources/dso/10_ingest.php` | Demo page: JSON textarea (appendix example), result row, 20 latest packets. |

**Ingest status rules** (the packet is always kept; `THROW` only for the wrong role):

| IngestStatus | When | `MeterID` | EVENT |
|---|---|---|---|
| `Malformed` | not JSON (or NULL), no `Meter_Network_ID`, no valid `Transmission_Timestamp`, or no `Telemetry_Payload` array | NULL (the meter if it was already known) | `Malformed packet` |
| `Unknown meter` | network ID matches no meter | NULL | `Unmatched packet` (with `PacketID`) |
| `Meter not active` | `METER.Status <> 'Active'` (agreement X2); no readings | set | `Packet from inactive meter` |
| `Accepted` | every reading stored | set | none |
| `Partially accepted` | some or all readings skipped: unknown OBIS code, value not a number, repeated code in the packet, or the (meter, code, slot) already exists. Reasons in `ErrorMessage`. An empty payload `[]` or a packet with 0 usable readings also gets this status with `ReadingsStored = 0` (the check constraint needs a meter and a message) | set | `Packet partly rejected` |

- Slot = `Transmission_Timestamp` (any offset, converted to UTC) rounded **down** to :00/:15/:30/:45. Stored with `VeeStatus = 'Pending'` and the `PacketID`.
- Not every packet needs every code: each code is its own row.
- Concurrency: duplicates are looked up with `UPDLOCK, HOLDLOCK` (key-range lock) inside the transaction, so two identical packets at the same time cannot both insert; the second waits, then sees the row and reports a duplicate. The primary key is the safety net: on any unexpected error the transaction is rolled back and the packet is still recorded as `Malformed`.
- Other `THROW`s of the area: DSO sub-range is 53000-53499; DSO-2 onwards continue from 53005.

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| DSO-1 ★ | Done, see "What exists" | | |
| DSO-2 ★ | `sp_dso_run_vee(@UserID, @From, @To)`: `VEE_RUN` → for each Pending row check the rules (`VEE_RULE`, `RULE_FOR`) → estimates in `READING_EDIT` → **INSERT** `VALIDATED_READING` (Validated, Estimated or Edited) → raw becomes Validated, or Suspect if it needs a person | `RAW_READING`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `READING_EDIT`, `VALIDATED_READING` | `dso/vee.php` |
| DSO-3 | `sp_dso_list_suspect`, `sp_dso_edit_reading` (Manual edit) | same | `dso/vee.php` |
| DSO-4 ★ | `sp_dso_build_aggregates(@UserID, @Day)`: `METER_AGGREGATE` (Day, plus Month/Year when the period closes) and `TRANSFORMER_AGGREGATE` on leaves | `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE` | `dso/aggregates.php` |
| DSO-5 | `sp_dso_detect_events(@UserID, @From, @To)` → `EVENT`. One or two simple rules are enough | `VALIDATED_READING`, `EVENT` | `dso/events.php` |
| DSO-6 | Pages for the tasks above | | |

## Base data ready for this area

- VEE rules 1–5: Range, Spike (`factor` 5, `window` 3), Gap, LinearEstimate, VoltageBand (207–253 V), with `RULE_FOR` mapping.
- Readings: 18–19/11/2026 validated; 20/11/2026 00:00–05:45 raw and **Pending**, waiting for VEE.
- An unmatched packet from `EAC-XXX-9999` with its `Unmatched packet` event.
- Value meaning: decision B2 in [19-conventions.md](19-conventions.md). Raw `1.8.0` is the counter; validated is energy per 15 minutes.
