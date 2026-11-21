# Handoff: TEC-2 + TEC-3 + TEC-4

Lock: free
<!-- Lock was "active since 2026-11-21 17:13 UTC" while the worker session ran; released at the last commit. -->

Branch: task/TEC-2-docs-approval
Doc: docs/08-technicians-and-meters.md
Status: finished (in review) — SQL, tests and PHP written; the coordinator still has to run the tests

## Next step
Run `python sql/tools/build_all.py --tests`, load `sql/build/ALL.sql` and check the output has no `FAIL` line.
Then open the PR (copy the Spec checklist lines 2.1 with ✓).

## Done so far
- 2026-11-21: all procedures for TEC-2/3/4 appended to `sql/procs_technician.sql` (THROW 52300-52328), tests appended to `sql/tests/test_technician.sql`, pages `technician/10_documents.php`, `technician/30_availability.php`, `operator/tec_10_technicians.php`, docs updated.

## Blockers / open questions
- Tests were not run (no database access for the worker); PHP not linted (no `php` on the machine).
- `sp_ref_list_municipalities` is defined here because none existed. If another lane adds the same name, both are `CREATE OR ALTER`, so the last one loaded wins.

## How to test
`python sql/tools/build_all.py --tests`, run `sql/build/ALL.sql`. Expect only `OK` lines (61 new ones, users `test_tec2_a`, `test_tec2_b`; tech1 availability on 2027-07-01 is cleaned up; tech1 and tech2 are never changed).
