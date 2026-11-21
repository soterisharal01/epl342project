# Handoff: MKT-4 Supplier and aggregator pages

Lock: free

Branch: task/MKT-4-pages
Doc: docs/11-suppliers-aggregators.md
Status: finished (in review)

## Next step
Reviewer: run `sql/procs_market.sql` and `sql/tests/test_market.sql`, then open the pages as supplier1 / aggregator1. PHP was not run (no php on the worker machine).

## Done so far
- 2026-11-21: added `sp_aggregator_list_portfolios`, `sp_aggregator_list_portfolio_premises` (+4 OK/FAIL checks pairs in test_market.sql); pages supplier/10_dayahead, 20_intraday, aggregator/10_dayahead, 20_intraday, 30_portfolio, shared `supplier/_market_view.php`.

## Blockers / open questions
- Adding a premise needs its PremiseID typed by hand (no premise search procedure exists).

## How to test
Run procs_market.sql then test_market.sql in SSMS: every line starts with OK. Log in as supplier1 (Day-Ahead, Intraday) and aggregator1 (also Χαρτοφυλάκια).
