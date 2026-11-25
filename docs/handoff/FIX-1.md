# FIX-1: spec re-check fixes

Lock: free

## What was done
A line-by-line check of the Phase B spec against `main` (2d9c6be). Three real defects fixed, with tests:

1. **III.4.2 / B16, current state.** `sp_tso_refresh_current_state` stored only leaf rows and the upper levels were summed at read time,
   while the spec, decision B16 and the demo script say the intermediate table holds the whole hierarchy and ancestors are updated.
   Now the refresh stores a row for every node (sum of its leaves) in the same MERGE/transaction. `sp_tso_current_state` and
   `sp_tso_map_data` read each node's own row.
2. **III.3.2, aggregates only from finalized readings.** `sp_dso_build_aggregates_day` built "final" day rows even when the day still
   had `Pending` or `Suspect` raw readings. After the DSO edited the suspect value, the final total stayed wrong forever
   (reproduced: meter 1, 20/11: aggregate 3.6327 vs validated 5.6327). Now such meter/code series, their leaf transformer, and the
   automatic Month/Year wait; today/future days are refused (53305); the pending button counts only days where something was written.
3. **B18, new tenant.** `sp_consumer_readings`, `sp_consumer_history`, `sp_consumer_buy_history` did not check `HOLDING.StartDate`,
   so a new tenant could see (and buy) the previous holder's readings. Now everything starts at the holding start (51113 for buying).

## Second round (after the human's "yes")
4. **III.1.2:** consumer aggregates (`sp_consumer_history`) follow the same paid-month rule as the 15-minute readings.
5. **III.1.4:** `GDPR_REQUEST.RequestType` (`'Erasure'` default, `'Retention'`), schema change in `create.sql`. A `'Retention'` request
   keeps the account and only sets `RawRetentionMonths = 1`. `sp_gdpr_apply` runs the purge automatically after the commit
   (`sp_retention_purge_core`, shared with the Admin button). Consumer/operator/admin GDPR pages show the type.
6. **III.5.1:** supplier/aggregator aggregates count only rows whose whole period is inside the contract/portfolio dates.
Demo note: on 3-4/12 November is a past month, so the demo first buys November history (doc 24 updated).
Tests: 782 OK, 0 FAIL.

## Next step
Review and merge the PR (a member who did not author it). Then rebuild `sharal01` with the REL-1 runbook (docs/23-release.md),
because the deployed database has the old procedures.

## How to test
`bash sql/tools/test_local.sh` → `ALL OK` (773 OK lines). New lines: `B18 ...`, `day with an open Suspect reading ...`,
`today (day not over) -> 53305`, `refresh: every node ...`, `refresh: stored ancestor rows ...`.
