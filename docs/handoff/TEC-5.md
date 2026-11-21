# Handoff: TEC-5 Field tasks

Lock: free

Branch: task/TEC-5-field-tasks
Doc: docs/08-technicians-and-meters.md
Status: finished (in review)

## Next step
Coordinator runs the full build + tests and checks that all TEC-5 lines print OK.

## Done so far
- Procedures appended to sql/procs_technician.sql (THROW 52100-52130), tests appended to sql/tests/test_technician.sql (53 OK checks), pages technician/20_tasks.php and operator/tec_20_tasks.php, doc 08 updated.
- Design: availability is optional (no declared slots that day = allowed); note numbers computed under UPDLOCK on the task row; sp_operator_assert added (none existed); sp_task_get returns the task row, notes/attachments come from sp_task_notes / sp_task_attachments.

## Blockers / open questions
- Cancelling a task does not revert its request (agreement X1 allows only Assigned/Resolved), so the request stays Assigned.

## How to test
python sql/tools/build_all.py --tests, then run sql/build/ALL.sql. Every TEC-5 line must start with OK.
