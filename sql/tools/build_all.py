#!/usr/bin/env python3
"""
build_all.py : ενώνει ΟΛΑ τα .sql με τη σωστή σειρά (απόφαση Α9) σε ΕΝΑ αρχείο,
για να το ανοίξεις στο SSMS και να πατήσεις Execute μία φορά.

    python3 sql/tools/build_all.py            -> sql/build/ALL.sql   (χωρίς drop)
    python3 sql/tools/build_all.py --drop     -> με το drop.sql στην αρχή (ΣΒΗΝΕΙ ΤΑ ΠΑΝΤΑ)
    python3 sql/tools/build_all.py --tests    -> και τα sql/tests/*.sql στο τέλος
    python3 sql/tools/build_all.py --release [--drop]  -> REL-1: create, procs, indexes, 00_base, import.sql (no tests)

Σειρά: [drop] -> create -> procs_common -> procs_* (αλφαβητικά) -> indexes
       -> data/small/00_base -> data/small/10_*, 20_*, 30_* -> [tests]
Ό,τι αρχείο δεν υπάρχει ακόμη, απλώς παραλείπεται.
Το sql/build/ δεν μπαίνει στο git (παράγεται).
"""
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def p(*parts):
    return os.path.join(ROOT, *parts)


def ordered_files(drop, tests, release=False):
    files = []
    if drop:
        files.append(p('sql', 'drop.sql'))
    files.append(p('sql', 'create.sql'))
    files.append(p('sql', 'procs_common.sql'))
    files += sorted(f for f in glob.glob(p('sql', 'procs_*.sql')) if not f.endswith('procs_common.sql'))
    files.append(p('sql', 'indexes.sql'))
    if release:
        # Demo database (27 MB cap): base data + the large set, no extra small files, no tests.
        files.append(p('data', 'small', '00_base.sql'))
        files.append(p('sql', 'import.sql'))
        return [f for f in files if os.path.isfile(f)]
    files += sorted(glob.glob(p('data', 'small', '[0-9][0-9]_*.sql')))
    if tests:
        files += sorted(glob.glob(p('sql', 'tests', '*.sql')))
    return [f for f in files if os.path.isfile(f)]


def main():
    drop = '--drop' in sys.argv
    tests = '--tests' in sys.argv
    release = '--release' in sys.argv
    if release and tests:
        sys.exit('--release and --tests cannot be combined (the demo database must stay small).')
    out = p('sql', 'build', 'ALL.sql')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    files = ordered_files(drop, tests, release)
    with open(out, 'w', encoding='utf-8', newline='\n') as o:
        o.write('-- Παράχθηκε από sql/tools/build_all.py. ΜΗΝ το διορθώνεις με το χέρι.\n')
        o.write('-- Αρχεία: ' + ', '.join(os.path.relpath(f, ROOT) for f in files) + '\n')
        # Ασφάλεια: αν κατά λάθος είσαι στη master (ή άλλη βάση συστήματος), δεν τρέχει τίποτα.
        o.write("IF DB_NAME() IN ('master', 'tempdb', 'model', 'msdb')\n"
                "BEGIN RAISERROR(N'Λάθος βάση: διάλεξε τη δική σου βάση (το username σου στο Τμήμα) πάνω αριστερά στο SSMS.', 16, 1); SET NOEXEC ON; END;\nGO\n")
        # Query Store fills the 27 MB student-database cap with plans from repeated test runs: keep it off.
        o.write("IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state_desc <> 'OFF') ALTER DATABASE CURRENT SET QUERY_STORE = OFF;\nGO\n")
        for f in files:
            rel = os.path.relpath(f, ROOT).replace(os.sep, '/')
            o.write(f"\nPRINT N'=== {rel} ===';\nGO\n")
            with open(f, encoding='utf-8-sig') as i:
                o.write(i.read().rstrip() + '\nGO\n')
    print('wrote', os.path.relpath(out, ROOT))
    for f in files:
        print('  ', os.path.relpath(f, ROOT))


if __name__ == '__main__':
    main()
