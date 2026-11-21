# 11. Suppliers and aggregators (III.5)

[← Back to the menu](../README.md) · Tasks: MKT-1 … MKT-4 in [tasks.md](tasks.md)

> **Status: MKT-1, MKT-2 and MKT-3 written (SQL + tests, in review). MKT-4 (PHP pages) planned.**

## Requirements

- Suppliers and aggregators see **only** data of their own customers or portfolios, **never raw** readings. They see total import (`1.8.0`), export (`2.8.0`) and net, per period and per transformer/geofence.
- **Day-Ahead:** daily, validated data.
- **Intraday:** 15-minute **provisional** aggregates from the latest readings, **without** waiting for VEE.

## What exists (`sql/procs_market.sql`, tests in `sql/tests/test_market.sql`, THROW 52500-52999)

| Object | What it does |
|---|---|
| `sp_market_assert(@UserID)` | Returns nothing; `THROW 52500` unless the user is an Active Supplier (with `SupplierID`) or Aggregator (with `AggregatorID`). |
| `fn_market_premises(@UserID, @From, @To)` | Inline table-valued function: `PremiseID`, `MeterID` of the user's own customers in the period. Supplier: premises with a `SUPPLY_CONTRACT` of their `SupplierID` overlapping the period. Aggregator: premises in `INCLUDES` of a `PORTFOLIO` of their `AggregatorID` overlapping the period. Meter = installation with `ConfirmationStatus = 'Confirmed'`, installed before the period end and not removed before its start. Other roles or suspended users get no rows. |
| `sp_supplier_aggregates(@UserID, @PeriodType, @From, @To)` | MKT-1. Works for Supplier and Aggregator. Sums `METER_AGGREGATE` (`Day` = Day-Ahead, `Month`, `Year`; `PeriodStart` in range) per `PeriodStart` and transformer: `TransformerID, TransformerName, GeofenceName, ImportKWh (1.8.0), ExportKWh (2.8.0), NetKWh (import - export), MeterCount, EstimatedCount`. Validated data only: `METER_AGGREGATE` is built by the DSO only from `VALIDATED_READING`. Errors 52501 (bad period type), 52502 (bad dates). |
| `sp_supplier_totals(...)` | Same arguments and rules; one total row per period over all transformers (`PeriodStart, ImportKWh, ExportKWh, NetKWh, MeterCount, EstimatedCount`). |
| `sp_market_intraday(@UserID, @Date)` | MKT-3. 15-minute **provisional** sums for one day from `RAW_READING` (any `VeeStatus`, no waiting for VEE): `IntervalStart, TransformerID, TransformerName, GeofenceName, ImportKWh, ExportKWh, NetKWh, MeterCount, Provisional` (always 1). Error 52503 (no date). |
| `sp_aggregator_save_portfolio(@UserID, @PortfolioID, @Name)` | MKT-2. Creates (`@PortfolioID` NULL) or renames a portfolio of the user's aggregator; returns `PortfolioID`. Errors 52510-52512. |
| `sp_aggregator_add_premise(@UserID, @PortfolioID, @PremiseID, @StartDate)` | MKT-2. Adds a premise to an own portfolio (re-opens a removed one). Errors 52512-52514. |
| `sp_aggregator_remove_premise(@UserID, @PortfolioID, @PremiseID)` | MKT-2. Closes the `INCLUDES` row (`EndDate` = today UTC); history stays. Error 52515. |

All three MKT-2 writers use a transaction and write one `AUDIT_LOG` row.

**Only sums, never raw rows.** No procedure returns a row per meter. Both sums are grouped by period/interval and transformer.

**Intraday delta method (decision B2).** Raw `1.8.0`/`2.8.0` are cumulative counters, so the energy of a 15-minute interval is
`value(T) - value(T - 15 min)` of the same meter and code (`LAG` per `MeterID, ObisCode` ordered by `IntervalStart`), booked on the later
`IntervalStart`. The reading just before the day (23:45 of the previous day) is read so interval 00:00 has a delta. An interval is
**skipped** when the previous reading is missing or not exactly 15 minutes earlier (transmission gap) or when the delta is negative
(counter reset or meter swap). A meter without a `2.8.0` reading contributes 0 export. Values are provisional: they may change after VEE.

Test data: supplier1 (UserID 9, supplier 1) owns premises 1, 2, 4 (meters 1, 2, 4); meter 3 belongs to supplier 2.
aggregator1 (UserID 10) has portfolio 1 with premises 3 and 4 (meters 3, 4).

## Planned (PHP pages: MKT-4)
## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 5.1 Access **only** to the data of their own customers/portfolios, through database calls with identity and permission checks (our procedures are the "APIs").
- [ ] 5.1 **No** uncontrolled access to raw data.
- [ ] 5.1 Aggregates from **validated** readings, per period and geofence, with total import, total export and net difference.
- [ ] 5.2 Forecasting/balancing algorithms are **not** needed, only the data.
- [ ] 5.2 Day-Ahead: daily form, from stored validated data.
- [ ] 5.2 Intraday: 15-minute **provisional** values from the latest readings, **before** VEE (counter differences, B2).

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| MKT-1 ★ | `sp_supplier_aggregates(@UserID, @PeriodType, @From, @To)`: premises with an active `SUPPLY_CONTRACT` of the user's `SupplierID`. Sums `METER_AGGREGATE` grouped by `TransformerID`. Day-Ahead = `@PeriodType = 'Day'` | `METER_AGGREGATE`, `SUPPLY_CONTRACT`, `METER`, `TRANSFORMER` | `supplier/aggregates.php` |
| MKT-2 | `sp_aggregator_aggregates(…)`: premises in the `PORTFOLIO`/`INCLUDES` of the user's `AggregatorID`. `sp_aggregator_save_portfolio`, `sp_aggregator_add_premise` | `PORTFOLIO`, `INCLUDES`, `METER_AGGREGATE` | `aggregator/aggregates.php`, `aggregator/portfolio.php` |
| MKT-3 ★ | `sp_market_intraday(@UserID, @Date)`: sums `RAW_READING` per 15 minutes for their own premises, marked provisional | `RAW_READING` | `supplier/intraday.php` |
| MKT-4 | Pages for the tasks above | | |

Reads DSO results only through agreement X6 ([19-conventions.md](19-conventions.md)). Base data: `supplier1` works for
supplier 1, `aggregator1` for aggregator 1, and there is a portfolio with premises.
