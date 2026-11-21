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

**Size cap:** a student database on the department server is limited to 27 MB data and 20 MB log, so only about 15 MB is free for this set. The generator estimates the stored size (rows x bytes x 1.5 for indexes, now about 13 MB) and refuses to write above 15 MB.

## Regenerate

`python data/gen/large.py` from the repo root. Fixed seed, so the output is always identical. The script checks keys, FKs,
geofences, phases, counters and validated deltas before it writes. Never edit the `.dat` or `import.sql` by hand.

## What is in the large set

IDs from 100000 (usernames `lc_`/`lt_`, serials `LSN-`, NetworkIDs `LEAC-`, IBANs `CY99...`). New transformer subtrees only under
base 2 and 3 (4 mid-level, 40 leaves, geofences nested, base leaves 4, 5, 6 untouched). Every meter is Active on a leaf with a Done
`Installation` task and a Confirmed installation (ConfirmedBy 2). Readings: 80 meters (2 per leaf), 2026-11-01..07, 96 per day,
1.8.0 (+ 2.8.0 for 16 prosumers), all `Validated`, one VEE run (100000). Counters never decrease (2.8.0 is flat at night). Validated
`ValidatedAt` is the column default (load time) to save space. One packet per meter per day with a tiny JSON.

| Table | Rows | IDs |
|---|---|---|
| USER_ACCOUNT | 2030 | 100000-102029 |
| CONSUMER_NOTIFICATION_CHANNEL | 2600 | |
| IN_CATEGORY | 45 | |
| GEOFENCE | 44 | 100000-100043 |
| TRANSFORMER | 44 | 100000-100043 |
| PREMISE | 2200 | 100000-102199 |
| HOLDING | 2200 | |
| BANK_ACCOUNT | 1500 | 100000-101499 |
| ACCOUNT_FOR | 1500 | |
| SUPPLY_CONTRACT | 1500 | 100000-101499 |
| INVOICE | 4500 (Aug-Oct 2026) | 100000-104499 |
| PAYMENT | 3000 | 100000-102999 |
| PORTFOLIO | 5 | 100000-100004 |
| INCLUDES | 300 | |
| METER | 2000 | 100000-101999 |
| METER_CONNECTED_PHASE | 3000 | |
| SERVICE_REQUEST | 150 | 100000-100149 |
| FIELD_TASK | 2000 | 100000-101999 |
| METER_INSTALLATION | 2000 | 100000-101999 |
| DOCUMENT | 90 | 100000-100089 |
| VEE_RUN | 1 | 100000 |
| TELEMETRY_PACKET | 560 | 100000-100559 |
| RAW_READING | 64512 | |
| VALIDATED_READING | 64512 | |
| METER_AGGREGATE | 672 | |
| TRANSFORMER_AGGREGATE | 336 | |
