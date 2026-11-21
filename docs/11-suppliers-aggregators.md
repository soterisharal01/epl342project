# 11. Suppliers and aggregators (III.5)

[← Back to the menu](../README.md) · Tasks: MKT-1 … MKT-4 in [tasks.md](tasks.md)

> **Status: plan only.**

## Requirements

- Suppliers and aggregators see **only** data of their own customers or portfolios, **never raw** readings. They see total import (`1.8.0`), export (`2.8.0`) and net, per period and per transformer/geofence.
- **Day-Ahead:** daily, validated data.
- **Intraday:** 15-minute **provisional** aggregates from the latest readings, **without** waiting for VEE.

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| MKT-1 ★ | `sp_supplier_aggregates(@UserID, @PeriodType, @From, @To)`: premises with an active `SUPPLY_CONTRACT` of the user's `SupplierID`. Sums `METER_AGGREGATE` grouped by `TransformerID`. Day-Ahead = `@PeriodType = 'Day'` | `METER_AGGREGATE`, `SUPPLY_CONTRACT`, `METER`, `TRANSFORMER` | `supplier/aggregates.php` |
| MKT-2 | `sp_aggregator_aggregates(…)`: premises in the `PORTFOLIO`/`INCLUDES` of the user's `AggregatorID`. `sp_aggregator_save_portfolio`, `sp_aggregator_add_premise` | `PORTFOLIO`, `INCLUDES`, `METER_AGGREGATE` | `aggregator/aggregates.php`, `aggregator/portfolio.php` |
| MKT-3 ★ | `sp_market_intraday(@UserID, @Date)`: sums `RAW_READING` per 15 minutes for their own premises, marked provisional | `RAW_READING` | `supplier/intraday.php` |
| MKT-4 | Pages for the tasks above | | |

Reads DSO results only through agreement X6 ([19-conventions.md](19-conventions.md)). Base data: `supplier1` works for
supplier 1, `aggregator1` for aggregator 1, and there is a portfolio with premises.
