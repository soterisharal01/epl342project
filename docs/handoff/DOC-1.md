# Handoff: DOC-1 User manual

Lock: free

Branch: task/DOC-1-user-manual
Doc: docs/21-user-manual.md (deliverable list: docs/18-deliverables-and-timeline.md)
Status: in review (PR #35)

## Next step
After merge: (1) when DOC-2 is merged check that `docs/img/er/er-chen.png` and `relational.png` show in section 14;
(2) after the demo database is rebuilt, rerun `docs/img/manual/shoot.py` and commit the new PNGs; (3) convert to docx for `docx/`.

## Done so far
- Manual text complete for all 8 roles, including the TEC pages (3.4, 3.5, 4.5: meter install, Operator confirmation,
  remote commands with Operator approval, anti-tamper events). Every «quoted» label was checked against `sources/`.
- 50 screenshots in `docs/img/manual/<role>-<page>.png` (1280x900, each under 300 KB), embedded with captions.
  Script: `docs/img/manual/shoot.py` (Playwright; needs `MDMS_PASSWORD` env var with the demo password).
- Final ER and relational images linked in section 14 (produced by DOC-2); data dictionary linked.
- README menu has row 21.

## Blockers / open questions
- None found: no PHP error or warning on any of the pages screenshotted.
- The ER images come from DOC-2; the links show broken images until it is merged.

## How to test
Open `docs/21-user-manual.md` in a Markdown viewer; check images show and labels match the pages. To retake the
screenshots (WSL): `MDMS_PASSWORD=... python3 docs/img/manual/shoot.py http://localhost:8342`.
