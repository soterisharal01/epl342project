# 09. DSO: ingestion and VEE (III.3)

[← Back to the menu](../README.md) · Tasks: DSO-1 … DSO-6 in [tasks.md](tasks.md)

> **Status: partly written.** DSO-1 (ingestion), DSO-2 (VEE) and DSO-3 (suspect list, manual edit) exist. DSO-4 … DSO-6 are still plans.

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
| DSO-2 | `sql/procs_dso.sql` | `sp_dso_run_vee(@UserID, @From, @To)`: VEE over the Pending raw rows with `IntervalStart` in `[@From, @To)` (UTC). Returns `RunID, Validated, Estimated, Suspect, Events`. Errors 53100 (period), 53101 (another VEE is running). |
| DSO-3 | `sql/procs_dso.sql` | `sp_dso_list_suspect(@UserID, @MeterID = NULL)`: Suspect raw rows with previous/next neighbours and a reason. Error 53110. `sp_dso_edit_reading(@UserID, @MeterID, @ObisCode, @IntervalStart, @NewValue, @Reason)`: manual fix of one Suspect row, errors 53120-53124. `sp_dso_list_runs(@UserID)`: runs with counts. |
| DSO-2/3 | `sql/tests/test_dso.sql` | VEE over the base data, the 22/11 scenario (spike 25.4 suspect, gap 10:30 estimated 2.1), edit, immutability, roles. |
| DSO-2/3 | `sources/dso/20_vee.php` | Run form, runs list, suspect list with an edit form per row. |
| DSO-4 | `sql/procs_dso.sql` | `sp_dso_build_aggregates(@UserID, @Day, @ForceMonth = 0, @ForceYear = 0)`: from `VALIDATED_READING` of that UTC day (only cumulative `1.8.0`/`2.8.0`) **inserts** `METER_AGGREGATE` Day rows (`SumValue`, `ReadingCount`, `EstimatedCount`) and `TRANSFORMER_AGGREGATE` Day rows for **leaf** transformers (`MeterCount`). On the last day of a month also Month rows (from the Day rows), on 31/12 also Year rows; `@ForceMonth`/`@ForceYear` build them earlier. Rows that exist are skipped: aggregates are **final**, never updated or recomputed, so a second call writes 0. **Only finalized data:** a meter/code that still has a `Pending` or `Suspect` raw reading in that day gets no row yet, and neither does its leaf transformer (or the automatic Month/Year); a later call (for example the pending button) builds them after VEE or the manual edit, so an edit can never leave a wrong final total. Today (UTC) or a future day is refused (53305): it is not over. One transaction, one `AUDIT_LOG` row (with how many series were skipped). Returns `Day, MeterRows, TransformerRows, MonthRows, YearRows`. Errors 53300, 53305. |
| DSO-4 | `sql/procs_dso.sql` | `sp_dso_build_aggregates_pending(@UserID, @From = NULL, @UpTo = NULL)`: builds every day before `@UpTo` (default today UTC) that has validated cumulative readings without a Day aggregate, oldest first, in one transaction. Then it **closes** every month/year that ended before `@UpTo` and still lacks a Month/Year row for some meter (FIX-2: a Suspect reading edited after the month's last day was built, or a last day with no readings), by running the helper for that last day (31/12 for the year). `sp_dso_run_vee` is **not** changed: the DSO runs this after VEE. Error 53301. Internal helper `sp_dso_build_aggregates_day` does the work (no own transaction). |
| DSO-4 | `sql/procs_dso.sql` | `sp_dso_list_aggregates(@UserID, @MeterID = NULL, @PeriodType = 'Day', @From, @To)` and `sp_dso_list_transformer_aggregates(@UserID, @TransformerID = NULL, @PeriodType = 'Day', @From, @To)`. Errors 53302-53304. |
| DSO-5 | `sql/procs_dso.sql` | `sp_dso_detect_events(@UserID, @From, @To)` (max 31 days) writes `EVENT` rows from validated data and returns the new count per type (`Undervoltage, Overvoltage, PhaseUnbalance, SuspectedTheft, Total`). Never duplicates: no event if one exists for the same meter, type and `OccurredAt` (so the voltage events VEE already wrote are not repeated). Errors 53310, 53311. |
| DSO-5 | `sql/procs_dso.sql` | `sp_dso_list_events(@UserID, @Status = NULL, @Type = NULL)` (newest 500; error 53320). `sp_dso_losses_report(@UserID, @From, @To)`: per leaf and day, transformer aggregate vs the sum of its meters' aggregates (error 53312). |
| DSO-4/5 | `sql/tests/test_dso.sql` | 46 more `OK`/`FAIL` checks: roles, day build equals validated sums, finality, leaf-only, force month/year, pending, lists, the 23/11 analytics scenario (under/over-voltage, phase unbalance, suspected theft), no duplicates on rerun, losses report. |
| DSO-6 | `sources/dso/30_aggregates.php`, `40_events.php` | Aggregates page (build a day with force options, build all pending, lists of meter and transformer aggregates by period type). Events page (detect for a period, filtered event list, losses report). With `10_ingest.php` and `20_vee.php` the DSO menu follows the flow ingest, VEE, aggregates, events. |

**Analytics rules** (constants at the top of `sp_dso_detect_events`, all on validated data in `[@From, @To)`):

- **Undervoltage / Overvoltage**: `32.7.0`/`52.7.0`/`72.7.0` outside the active `VoltageBand` rule (207-253 V default). One event per meter and interval (the most extreme phase).
- **Phase unbalance**: all three currents `31/51/71.7.0` present, the largest at least 1 A, and (max - min) / max above **25%**.
- **Suspected theft**: at least **8** consecutive 15-minute `1.8.0` energies of at most 0.01 kWh for a meter while the **other meters of the same transformer** average at least 0.05 kWh over the same span. One Critical event at the start of the run. Edge runs cut by the requested period may be missed. It is a hint for a field check.
- **Technical losses**: not an event. The schema has no independent reading at a transformer (even `TRANSFORMER_CURRENT_STATE` is derived from the meters), so `sp_dso_losses_report` compares the leaf aggregate with its meters' aggregates and exposes data mismatches (difference, meters with data vs active). With a measured transformer reading the same comparison gives real losses.

**How VEE decides** (comments in `sp_dso_run_vee` say the same):

- Value (decision B2): cumulative codes = counter minus the previous raw counter; instantaneous = as sent. Each series (meter + code) is processed in time order.
- Rules come from `RULE_FOR` and only if `VEE_RULE.IsActive`: **Range** (`MinValid`/`MaxValid`), **Spike** (value > `factor` x average of the previous `window` good values, defaults 5 and 3, with a floor of 10% of `MaxValid` so quiet periods near 0 do not flag every rise), **Gap + LinearEstimate**, **VoltageBand** (stays valid, writes `Undervoltage`/`Overvoltage` EVENT). A negative counter difference is always Suspect.
- **Suspect**: raw `VeeStatus = 'Suspect'`, no `VALIDATED_READING`, one `Suspect reading` EVENT with the reason. `sp_dso_list_suspect` recomputes the reason from the data (no column to store it).
- **Gap estimation**: 1 to 4 missing intervals between two good values. The energies form a straight line `e_i = e0 + i*s` whose sum equals the counter difference D: `s = 2*(D - (g+1)*e0) / ((g+1)*(g+2))`. The missing intervals become `Estimated` rows (each with a `READING_EDIT`, `Automatic estimate`, rule LinearEstimate, `OldValue` NULL) and the next real value is adjusted to `e0 + (g+1)*s`. Example: e0 = 2.0, D = 4.3, g = 1 gives 2.1 and 2.2.
- **First reading rule**: no previous counter, or a gap longer than 4 intervals: the raw row becomes `Validated` as a **baseline** (no energy can be derived, no `VALIDATED_READING`). The count is in the `AUDIT_LOG` comment.
- A late raw row whose interval already has a validated value is closed as `Validated` without touching the immutable value.
- Concurrency: `sp_getapplock` (one VEE at a time, no waiting), Pending rows read `WITH (UPDLOCK, READPAST)` so ingestion carries on during a run; everything in one transaction.
- **Manual edit**: only Suspect rows. Inserts `READING_EDIT` (`Manual edit`, next `EditNo` under `UPDLOCK`), a `VALIDATED_READING` with `Quality = 'Edited'`, sets raw to `Validated`, closes the `Suspect reading` EVENT, writes `AUDIT_LOG`. `@NewValue` is the corrected **energy** (cumulative) and must be inside the code's `MinValid`/`MaxValid`.

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
- Other `THROW`s of the area: DSO sub-range is 53000-53499; DSO-2/3 use 53100-53124 (list in the header of the DSO-2 section of `procs_dso.sql`).

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| DSO-1 ★ | Done, see "What exists" | | |
| DSO-2 ★ | Done, see "What exists". Plan was: `sp_dso_run_vee(@UserID, @From, @To)`: `VEE_RUN` → for each Pending row check the rules (`VEE_RULE`, `RULE_FOR`) → estimates in `READING_EDIT` → **INSERT** `VALIDATED_READING` (Validated, Estimated or Edited) → raw becomes Validated, or Suspect if it needs a person | `RAW_READING`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `READING_EDIT`, `VALIDATED_READING` | `dso/vee.php` |
| DSO-3 | Done, see "What exists" | | |
| DSO-4 ★ | Done, see "What exists". Plan was: `sp_dso_build_aggregates(@UserID, @Day)`: `METER_AGGREGATE` (Day, plus Month/Year when the period closes) and `TRANSFORMER_AGGREGATE` on leaves | `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE` | `dso/aggregates.php` |
| DSO-5 | `sp_dso_detect_events(@UserID, @From, @To)` → `EVENT`. One or two simple rules are enough | `VALIDATED_READING`, `EVENT` | `dso/events.php` |
| DSO-6 | Pages for the tasks above | | |

## Base data ready for this area

- VEE rules 1–5: Range, Spike (`factor` 5, `window` 3), Gap, LinearEstimate, VoltageBand (207–253 V), with `RULE_FOR` mapping.
- Readings: 18–19/11/2026 validated; 20/11/2026 00:00–05:45 raw and **Pending**, waiting for VEE.
- An unmatched packet from `EAC-XXX-9999` with its `Unmatched packet` event.
- Value meaning: decision B2 in [19-conventions.md](19-conventions.md). Raw `1.8.0` is the counter; validated is energy per 15 minutes.

## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 3.1 The packet has a network ID, timestamp, communication info (signal, network type) and OBIS/value/unit pairs. The communication info is stored too.
- [ ] 3.1 **First** match to an existing **and** active/confirmed meter, **then** store with the right 15-minute slot, unit and code.
- [ ] 3.1 Packets that do not match or have a communication problem are recorded as failures/events (B14), **never** lost silently.
- [ ] 3.1 At least the 12 appendix OBIS codes. Each packet carries a **variable** set of codes. A new code without redesign.
- [x] 3.2 Validation: syntax, supported OBIS, limits, gaps and inconsistencies in the series. Estimation for what is missing or unusable. Editing with original value, new value, origin.
- [x] 3.2 The result distinguishes at least validated/estimated and keeps which value is used afterwards.
- [x] 3.2 The two spec examples work in the demo: spike 25.4 → suspect; gap at 10:30 → estimate 2.1 with status estimated.
- [x] 3.2 After VEE: **immutable**. Finishing VEE triggers the aggregates (day, month, year), which are also final and never recomputed.
- [x] II.C Analytics: sags/swells, **technical losses**, phase imbalance, suspected theft (event types in B14).

### FIX-2: unit check on ingestion
`sp_dso_ingest_packet` reads each item's `unit` and refuses the item (reason `λάθος μονάδα …`, packet `Partially accepted`) when it differs from `OBIS_CODE.Unit`, case-insensitively (`kvarh` = `kVARh`). An item without a unit takes the code's unit. Before, a `1.8.0` sent in `Wh` would have been stored 1000 times too large. Test: `FIX-2 wrong unit …` in `sql/tests/test_dso.sql`.
