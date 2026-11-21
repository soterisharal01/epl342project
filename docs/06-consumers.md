# 06. Consumers (III.1)

[← Back to the menu](../README.md) · Tasks: CON-1 … CON-6 in [tasks.md](tasks.md)

> **Status: plan + what exists.** The detailed walk-through comes later.

## Requirements (spec III.1.1–1.3)

- A consumer links to one or more premises. Each premise has an ID, address, WGS84 coordinates, usage (Residential, Commercial, Industrial, Agricultural), district, municipality, parish and postal code. Bank accounts per consumer or per premise.
- The consumer sees the 15-minute series of **only their own** meters. Prosumers see import (`1.8.0`) and export (`2.8.0`) separately. The current month is free; older months need a purchased service and must still be within retention. History comes from `METER_AGGREGATE` (Day, Month, Year).
- Thresholds with email/SMS notification. Under- and over-voltage events.
- Check or fault requests, with status and history. Billing and payment history.

## What exists (`sql/procs_consumer.sql`, tests `sql/tests/test_consumer.sql` 26 + 29 checks)
## Spec checklist

The assignment PDF is not in the repo, so this list carries the spec for this area, sentence by sentence. A task is done only when every line it touches is covered; the PR copies the lines with ✓, and the reviewer checks them again. The list common to every task is in [19-conventions.md](19-conventions.md), section 8.

- [ ] 1.1 Self-registration **without** approval: personal details, contact details, login details.
- [ ] 1.1 A consumer has **many** premises (not 1:1). Each premise: unique Premise ID, address, WGS84, use (4 values), district, municipality, parish, postcode.
- [ ] 1.1 Bank accounts belong to the consumer and/or to a specific premise.
- [ ] 1.2 The consumer sees only **active** meters of **their own** premises, and only for the period they held the premise (B18).
- [ ] 1.2 Plain consumer: import. Prosumer (Net Billing / Net Metering): import **and** export **separately**, so the balance shows.
- [ ] 1.2 Notification of power-quality events (undervoltage, overvoltage) where voltage readings exist.
- [ ] 1.2 Consumption thresholds and notification channels (email, SMS). Sending itself is outside the database (B19).
- [ ] 1.2 Current month **free**. Earlier months only with a **paid** service, and **only** while the data still exists under retention.
- [ ] 1.2 Monitoring screens show VEE-checked 15-minute values. Historical screens use the day/month/year aggregates, with the **same** access rules.
- [ ] 1.3 Meter check or fault report for a premise/meter, with **status and history**, so it can be assigned to a technician (TEC-5) and followed to the end.
- [ ] 1.3 Billing and payment history. A payment links consumer, supplier, invoice and the MDMS-Cy service fee. No dynamic-pricing algorithm is needed.

## What exists (`sql/procs_consumer.sql`, tests `sql/tests/test_consumer.sql` 26/26 OK)

| Task | Procedures | Page |
|---|---|---|
| CON-1 | `sp_consumer_assert` (role check, `THROW 51000`), `fn_consumer_holds` (inline table-valued: one row if the user holds the premise today; used as `EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))`), `sp_consumer_add_premise` (PREMISE + HOLDING in one transaction), `sp_consumer_list_premises`, `sp_consumer_end_holding`, `sp_consumer_add_bank_account` (+ `ACCOUNT_FOR`), `sp_consumer_list_bank_accounts` | `consumer/10_premises.php`, `consumer/20_bank.php` |
| CON-4 | `sp_consumer_submit_request`, `sp_consumer_list_requests` (with the resulting field task), `sp_consumer_cancel_request`, `sp_consumer_list_meters` | `consumer/30_requests.php` |
| CON-5 | `sp_consumer_list_invoices`, `sp_consumer_list_payments`, `sp_consumer_pay_invoice` (UPDLOCK; full or partial) | `consumer/40_billing.php` |
| CON-2 | `fn_consumer_meters` (inline TVF: confirmed installations on premises held today, past meters included), `sp_consumer_readings(@UserID, @MeterID, @From, @To)` (15-minute rows `[From, To)`, max 31 days: IntervalStart, ImportKWh 1.8.0, ExportKWh 2.8.0, VoltageL1 32.7.0, Quality = worst; the current month is free, earlier months need a `SERVICE_PURCHASE` and must be within `RawRetentionMonths`), `sp_consumer_history(@UserID, @MeterID, @PeriodType, @From, @To)` (Day/Month/Year aggregates, import/export/net; free and unlimited in time), `sp_consumer_buy_history(@UserID, @PremiseID, @MonthFrom, @MonthTo)` (INVOICE + SERVICE_PURCHASE + AUDIT_LOG, amount = months × fee; refuses current/future months, months beyond retention, overlap with an earlier purchase of the premise, premises not held), `sp_consumer_list_purchases`. THROW 51100-51112 | `consumer/50_readings.php` |

## Planned

| Task | Procedures | Tables | Page |
|---|---|---|---|
| CON-3 | `sp_consumer_set_threshold`, `sp_consumer_set_channels`, `sp_consumer_quality_events` | `CONSUMPTION_THRESHOLD`, `CONSUMER_NOTIFICATION_CHANNEL`, `EVENT` | `consumer/70_settings.php` |
| CON-6 | Page for CON-3 (and the optional `consumer/60_history.php` chart) | | |

Reads DSO results only through agreement X6 ([19-conventions.md](19-conventions.md)).
