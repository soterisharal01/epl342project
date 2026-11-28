# Phase B deliverables (built files)

Built on 2026-11-28 with `python sql/tools/make_zip.py` from `main` at 37b1665. Do not edit these files by hand:
change the sources or `docs/`, then run the script again and replace the three files here.

| File | What | Where it goes |
|---|---|---|
| `12.zip` | `sources/`, `sql/`, `data/`, `docx/` (13.7 MB, 137 files, no `config.php`) | Moodle, by 4/12 11:00 |
| `MDMS-Cy_User_Manual.docx` | user manual, ER diagram, data dictionary (104 pages) | printed, lab |
| `MDMS-Cy_Contention_Security_Extension.docx` | contention points, security, extension (26 pages) | printed, lab |

Draft: the manual screenshots are from 22/11. After `sharal01` is rebuilt, retake them with `docs/img/manual/shoot.py`
and rebuild these files.

`.gitignore` ignores `*.zip` and `build/`, so these files were added with `git add -f`.
