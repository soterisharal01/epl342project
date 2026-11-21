# 03. Workflow

[← Back to the menu](../README.md)

## The idea

- Nobody owns work. The work is split into **tasks** ([tasks.md](tasks.md)), grouped by **area** (consumers, DSO,
  TSO and so on). Any member can do any task.
- The repo remembers where we are, so nobody has to:

| Question | Where the answer lives |
|---|---|
| What is done? | `✓` rows in [tasks.md](tasks.md) and the git history of `main` |
| What is in progress, and how far along? | Remote branches `task/<ID>-…`, each with its note `docs/handoff/<ID>.md` |
| What should happen next on a task? | The **Next step** line in that task's handoff note |
| Where did the last session stop, and what comes next overall? | [next-session.md](next-session.md) (the newest copy on any branch) |
| How does a component work? | Its doc in this folder (see the [menu](../README.md)) |
| How must code be written? | [19-conventions.md](19-conventions.md) |

## For a human: a working session

1. Connect the CS VPN if you will touch the database ([02-environment-setup.md](02-environment-setup.md)).
2. Open Claude Code in your clone of the repo and type **`start`**.
3. The AI syncs, reads the docs and history, and tells you which task it is resuming or claiming. Steer it if you want a different task ("start DSO-2").
4. Run in SSMS, on your own database, whatever it asks you to test. Paste back the result.
5. Need to pause briefly? Type **`stop`**: the AI writes the task's handoff note and pushes, so anyone can continue.
6. Ending the session? Type **`finish`**: the AI does everything `stop` does, then brings **every Markdown file** up to date
   (component docs, task board, README status, overview) and writes [next-session.md](next-session.md), the note the next
   `start` reads first.
7. When it reports a finished task, it opens the PR (or gives you the link). Tell the group.

The exact steps the AI follows are in [CLAUDE.md](../CLAUDE.md).

## Task life cycle

```
○ free ──claim: push task/<ID>-slug + handoff note──> in progress (branch exists)
        ──finished: tasks.md row 👀 on the branch, PR opened──> in review
        ──approved by another member, merged──> ✓ on main
   ⛔ blocked: written in the handoff note's Blockers, told to the group
```

- **Taken tasks are marked in [claims.md](claims.md) on `main`**, one row each, pushed straight to `main` the moment a task is taken.
  After a minute the session re-reads the file; if two members took the same task, the earliest row wins and the other picks
  another one. The task's PR removes the row. (In progress is also visible as the pushed branch.)
- One task, one branch, one PR. Branch name: `task/<ID>-<slug>`, for example `task/TSO-1-tree`.
- The handoff note has a **Lock** line. `active since <time>` means a session is working on it now; leave it alone
  unless it is more than 12 hours old. `free` means anyone may resume.

## Reviews

- Every PR is reviewed and merged by **a member who did not author it**, within 24 hours.
- How to review (15–30 min):
  1. Read **Files changed** on GitHub.
  2. On your own database run `create.sql` (if it changed), the PR's `procs_*.sql`, then its `sql/tests/test_*.sql`. No errors, every line `OK`.
  3. Check the list:
     - [ ] Does what the spec and the component doc say.
     - [ ] Checks the role, uses a transaction when writing to 2+ tables, writes `AUDIT_LOG`.
     - [ ] Writes only to tables of its area, or through an agreement X1–X6 ([19-conventions.md](19-conventions.md)).
     - [ ] PHP calls only `call_proc` with `?`, prints only through `h()` / `print_table`.
     - [ ] No password or secret in the diff.
     - [ ] The handoff note, the `tasks.md` row and the component doc are updated.
  4. Approve, or request changes with a comment on the line saying what is wrong and why.
- With the AI: type "review PR #N following docs/03-workflow.md". It comments on the PR and gives you a two-line verdict.

## Daily rhythm

- Push every evening, even half-done work, with a clear Next step.
- Post three lines in the group chat: done, next, stuck on.
- Stuck for more than half a day: say so. We cut extras, never ★ demo features.
