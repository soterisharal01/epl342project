# Data sets

| Folder | Content |
|---|---|
| `data/small/00_base.sql` | Base data (IDs 1-999), made by `data/gen/base.py`. |
| `data/large/NN_TABLE.dat` | Large synthetic set, one CSV per table (UTF-8, header row, empty field = NULL, times UTC). Number `NN` is the load (FK) order. |
| `sql/import.sql` | The same rows as multi-row `INSERT`s (max 1000 rows each, `GO` every ~2000 rows, each batch commits on its own). This is the loader. |

## Run order (clean database)

`drop.sql` -> `create.sql` -> `procs_*.sql` -> `indexes.sql` -> `data/small/00_base.sql` -> `sql/import.sql`
(the large set needs the base data: suppliers, catalogs, OBIS codes, transformers 2 and 3, user 2). Run in SSMS.
Not one transaction: after an error, rebuild the database and run again.

**Size cap:** a student database on the department server is limited to 27 MB data and 20 MB log, and system objects already use 16.5 MB, so the large set must stay under about 7 MB. The generator estimates the stored size (measured bytes per row x 1.2, now 6.8 MB) and refuses to write above 7 MB.

## Regenerate

`python data/gen/large.py` from the repo root. Fixed seed, so the output is always identical. The script checks keys, FKs,
geofences, phases, counters and validated deltas before it writes. Never edit the `.dat` or `import.sql` by hand.

## What is in the large set

IDs from 100000 (usernames `lc_`/`lt_`, serials `LSN-`, NetworkIDs `LEAC-`, IBANs `CY99...`). New transformer subtrees only under
base 2 and 3 (4 mid-level, 40 leaves, geofences nested, base leaves 4, 5, 6 untouched). Every meter is Active on a leaf with a Done
`Installation` task and a Confirmed installation (ConfirmedBy 2). Readings: 40 meters (1 per leaf), 2026-11-01..07, 96 per day,
1.8.0 (+ 2.8.0 for 6 prosumers), all `Validated`, one VEE run (100000). Counters never decrease (2.8.0 is flat at night). Validated
`ValidatedAt` is the column default (load time) to save space. One packet per meter per day with a tiny JSON.

| Table | Rows | IDs |
|---|---|---|
| USER_ACCOUNT | 1025 | 100000-101024 |
| CONSUMER_NOTIFICATION_CHANNEL | 1300 | |
| IN_CATEGORY | 38 | |
| GEOFENCE | 44 | 100000-100043 |
| TRANSFORMER | 44 | 100000-100043 |
| PREMISE | 1100 | 100000-101099 |
| HOLDING | 1100 | |
| BANK_ACCOUNT | 800 | 100000-100799 |
| ACCOUNT_FOR | 800 | |
| SUPPLY_CONTRACT | 800 | 100000-100799 |
| INVOICE | 2400 (Aug-Oct 2026) | 100000-102399 |
| PAYMENT | 1600 | 100000-101599 |
| PORTFOLIO | 5 | 100000-100004 |
| INCLUDES | 149 | |
| METER | 1000 | 100000-100999 |
| METER_CONNECTED_PHASE | 1500 | |
| SERVICE_REQUEST | 80 | 100000-100079 |
| FIELD_TASK | 1000 | 100000-100999 |
| METER_INSTALLATION | 1000 | 100000-100999 |
| DOCUMENT | 75 | 100000-100074 |
| VEE_RUN | 1 | 100000 |
| TELEMETRY_PACKET | 280 | 100000-100279 |
| RAW_READING | 30912 | |
| VALIDATED_READING | 30912 | |
| METER_AGGREGATE | 322 | |
| TRANSFORMER_AGGREGATE | 322 | |
