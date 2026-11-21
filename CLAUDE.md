# Instructions for every AI session in this repo (EPL342 Team 12, MDMS-Cy)

Claude Code reads this file automatically. **No work belongs to one person.** Any team member can open a
session, type **`start`**, and the AI picks up where the team last stopped. All state lives in the repo:
the docs, the task board, the per-task handoff notes and git history. Nothing lives in anyone's head or chat.

Write docs in English. UI text and `THROW` messages are in Greek (decision B5 in
[docs/19-conventions.md](docs/19-conventions.md)). Explain what you built to the human in plain words: every
member must be able to explain every part at the exam.

## 1. When the human types `start` (or "continue", "resume")

Do all of this before writing any code. Do not ask the human what to do unless step 5 finds nothing.

1. **Sync:** `git fetch --all --prune`, `git checkout main`, `git pull`.
2. **Read**, in this order:
   [README.md](README.md) → [docs/03-workflow.md](docs/03-workflow.md) → [docs/19-conventions.md](docs/19-conventions.md)
   → [docs/tasks.md](docs/tasks.md).
3. **Recent history:** `git log --oneline -30 main`, then the open task branches with their last commit:
   `git for-each-ref --sort=-committerdate refs/remotes/origin/task --format="%(refname:short) | %(committerdate:relative) | %(subject)"`
4. **Handoff notes:** for each open task branch, read its note without checking it out:
   `git show origin/task/<branch>:docs/handoff/<TASK-ID>.md`.
5. **Pick the work**, first match wins:
   1. The human named a task → that task.
   2. An open task branch whose handoff says `Lock: free`, or whose lock is older than 12 hours → **resume it**:
      `git checkout <branch>` and continue from its **Next step**.
   3. The first `○` task in [docs/tasks.md](docs/tasks.md), in table order, whose **Needs** are all `✓` and that has **no**
      `origin/task/<ID>-*` branch → **claim it** (section 2).
   4. Nothing fits → say so and list the options.
6. **Load context for that task:** its component doc (the **Doc** column of the task board), the exact
   tables and columns in [sql/create.sql](sql/create.sql) (never from memory), and the existing code it touches.
7. **Tell the human in 3–6 lines:** which task, where it stood, what you will do now. Then do it.

## 2. Claiming a new task

1. `git checkout -b task/<ID>-<short-slug> main`, for example `task/DSO-1-ingest`.
2. Create `docs/handoff/<ID>.md` from [docs/handoff/TEMPLATE.md](docs/handoff/TEMPLATE.md) and set `Lock: active since <UTC time>`.
3. Commit (`<ID>: claim`) and **push at once** (`git push -u origin <branch>`). The pushed branch *is* the claim;
   other sessions see it in step 1.3.

## 3. While working

- Commit small and push often. A half-done branch with a clear handoff note is fine; unpushed work is not.
- Follow [docs/19-conventions.md](docs/19-conventions.md): `sp_<area>_<verb>`, `@UserID` first with a role check,
  `SET XACT_ABORT ON` + TRY/CATCH transaction, an `AUDIT_LOG` row per state change, `THROW` numbers of the area,
  PHP only via `call_proc` with `?`, `require_role`, `csrf_field`/`check_csrf`, `h()`.
- Write only to the tables your task's area owns (conventions, section 3), or through the cross-area agreements X1–X6.
- **Never change** `sql/create.sql` or `data/small/00_base.sql` on your own. Follow the schema-change process
  (conventions, section 6) and tell the human.
- Every new procedure gets tests in `sql/tests/test_<area>.sql` that print `OK …` or `FAIL …`: one call that
  succeeds and one that must be refused.
- Update the task's component doc with what now exists (procedures, pages, how to use it). Docs are part of the task.

## 4. Testing

- If Docker is available: `bash sql/tools/test_local.sh` must end with `ALL OK`.
- If not (for example on Windows without Docker): run `python sql/tools/build_all.py --tests`, then ask the human
  to run `sql/build/ALL.sql` in SSMS on **their own** database and paste the `OK`/`FAIL` lines.
- PHP: `php -l <file>` where PHP exists; otherwise the human checks the page on their department web space.

## 5. When the human types `stop` (or the task is done, or the session is ending)

1. Update `docs/handoff/<ID>.md`: what was done, the exact **Next step**, blockers, how to test.
   Set `Lock: free`.
2. If the task is finished: set its row in `docs/tasks.md` to `👀` **on the branch**, and fill in its component doc.
3. Commit and push.
4. If finished: open a PR to `main` titled `<ID>: <task name>`. Use `gh pr create` if `gh` exists; otherwise give the
   human the compare link `https://github.com/soterisharal01/epl342project/compare/<branch>?expand=1`.
5. Explain to the human in 3–5 plain sentences what you built, so they can present it.

## 6. Hard rules

- **Never** push to `main`, force-push, or merge, unless the human explicitly asks for that specific PR.
  A PR is merged by a member who did not author it, after approving it.
- **Never** ask for, type or commit passwords. The database password lives only in `sources/config.php`
  (git-ignored) or in SSMS, typed by the human.
- **Never** run anything destructive (`drop.sql`, `DELETE`) on a department database without an explicit "yes".
  Test databases are the human's own.
- Do not claim in documents that something was produced by a tool when it was written by an AI, or the reverse.
- The assignment PDF is not in the repo because the repo is public. Ask the human for it if needed.
