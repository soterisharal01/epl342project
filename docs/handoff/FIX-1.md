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

## Next step
Review and merge the PR (a member who did not author it). Then rebuild `sharal01` with the REL-1 runbook (docs/23-release.md),
because the deployed database has the old procedures.

## How to test
`bash sql/tools/test_local.sh` → `ALL OK` (773 OK lines). New lines: `B18 ...`, `day with an open Suspect reading ...`,
`today (day not over) -> 53305`, `refresh: every node ...`, `refresh: stored ancestor rows ...`.
