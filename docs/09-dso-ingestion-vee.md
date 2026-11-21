# 09. DSO: ingestion and VEE (III.3)

[← Back to the menu](../README.md) · Tasks: DSO-1 … DSO-6 in [tasks.md](tasks.md)

> **Status: plan only.**

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

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| DSO-1 ★ | `sp_dso_ingest_packet(@NetworkID, @Timestamp, @NetworkType, @SignalDbm, @PayloadJson)`: `TELEMETRY_PACKET`, then `OPENJSON` → `RAW_READING` (`VeeStatus = 'Pending'`). Unknown meter or OBIS code → failed `IngestStatus` + `EVENT` | `TELEMETRY_PACKET`, `RAW_READING`, `OBIS_CODE`, `EVENT` | `dso/ingest.php` (JSON form for the demo) |
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
