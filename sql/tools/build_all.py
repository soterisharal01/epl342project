#!/usr/bin/env python3
"""
build_all.py : ενώνει ΟΛΑ τα .sql με τη σωστή σειρά (απόφαση Α9) σε ΕΝΑ αρχείο,
για να το ανοίξεις στο SSMS και να πατήσεις Execute μία φορά.

    python3 sql/tools/build_all.py            -> sql/build/ALL.sql   (χωρίς drop)
    python3 sql/tools/build_all.py --drop     -> με το drop.sql στην αρχή (ΣΒΗΝΕΙ ΤΑ ΠΑΝΤΑ)
    python3 sql/tools/build_all.py --tests    -> και τα sql/tests/*.sql στο τέλος

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


def ordered_files(drop, tests):
    files = []
    if drop:
        files.append(p('sql', 'drop.sql'))
    files.append(p('sql', 'create.sql'))
    files.append(p('sql', 'procs_common.sql'))
    files += sorted(f for f in glob.glob(p('sql', 'procs_*.sql')) if not f.endswith('procs_common.sql'))
    files.append(p('sql', 'indexes.sql'))
    files += sorted(glob.glob(p('data', 'small', '[0-9][0-9]_*.sql')))
    if tests:
        files += sorted(glob.glob(p('sql', 'tests', '*.sql')))
    return [f for f in files if os.path.isfile(f)]


def main():
    drop = '--drop' in sys.argv
    tests = '--tests' in sys.argv
    out = p('sql', 'build', 'ALL.sql')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    files = ordered_files(drop, tests)
    with open(out, 'w', encoding='utf-8', newline='\n') as o:
        o.write('-- Παράχθηκε από sql/tools/build_all.py. ΜΗΝ το διορθώνεις με το χέρι.\n')
        o.write('-- Αρχεία: ' + ', '.join(os.path.relpath(f, ROOT) for f in files) + '\n')
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
