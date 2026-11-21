# Handoff: GDP-1 GDPR flow

Lock: free

Branch: task/GDP-1-gdpr-flow
Doc: docs/07-gdpr-and-retention.md
Status: finished (in review)

## Next step
The coordinator builds and runs the tests (`python sql/tools/build_all.py --tests`, then `run_sql.ps1 -File sql/build/ALL.sql`)
and sends back any FAIL. Then GDP-2 (retention purge) and GDP-3 (PHP pages) can start.

## Done so far
- Written, not yet run against a database: `sql/procs_gdpr.sql` (sp_gdpr_submit, sp_gdpr_list, sp_gdpr_start_review,
  sp_gdpr_preapprove, sp_gdpr_decide, sp_gdpr_apply, helper sp_gdpr_assert_role; THROW 51400-51412),
  `sql/tests/test_gdpr.sql` (47 OK checks: full flow on test_gdp_a, Operator rejection on test_gdp_b, Admin rejection on test_gdp_c, role and order refusals),
  `docs/07-gdpr-and-retention.md` ("What exists"), tasks.md row set to review.

## Blockers / open questions
- Older AUDIT_LOG rows ("Add bank account" stores the last 4 IBAN digits) are not scrubbed on apply.

## How to test
`python sql/tools/build_all.py --tests`, then run `sql/build/ALL.sql` on a test database. Every GDP line must start with `OK`; no `FAIL`.
Needs a fresh database (the test usernames test_gdp_* and the test IBAN are fixed). Never applies GDPR to consumer1/consumer2.
