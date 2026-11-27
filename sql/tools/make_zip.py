#!/usr/bin/env python3
"""make_zip.py (REL-4): builds 12.zip for Moodle (spec section V.A, docs/18-deliverables-and-timeline.md).

    python sql/tools/make_zip.py                 # builds 12.zip in the repo root and build/docx/*.docx
    python sql/tools/make_zip.py --check-only    # only the safety scan and the manifest, no zip
    python sql/tools/make_zip.py --no-docx       # zip without the two Word documents (quick test)

12.zip holds four folders:
  sources/  the PHP app with Leaflet inside, WITHOUT config.php (config.example.php is the template)
  sql/      every .sql, tests/, perf/, tools/ (not sql/build/)
  data/     small set, large set (.dat) and the generators
  docx/     (a) user manual = docs/21 + 22 (ER) + 20 (data dictionary);
            (b) one separate document = docs/15 + 16 + 17 + 14 (contention, security, extension, indexes/10,000 test)
Docs 21 and 22 may not exist yet: missing files are skipped with a warning.

The build REFUSES (exit 2) when config.php, a .env/.key file, or a password-looking assignment would go into the zip.
Needs pandoc: `where pandoc`, or `python -m pip install pypandoc_binary` (pandoc then comes with the package).
"""
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_ZIP = os.path.join(ROOT, '12.zip')
BUILD_DOCX = os.path.join(ROOT, 'build', 'docx')
TOP = ('sources', 'sql', 'data')
SKIP_DIRS = {'.git', '__pycache__', 'node_modules', 'build', 'wt', '.vscode', '.idea', '.claude'}
SKIP_NAMES = {'config.php', 'p.txt', 'Thumbs.db', '.DS_Store'}
SKIP_EXT = {'.pyc', '.pyo', '.zip', '.log', '.tmp', '.bak', '.key', '.pem', '.pfx'}
TEXT_EXT = {'.php', '.sql', '.py', '.ps1', '.sh', '.md', '.js', '.css', '.json', '.txt', '.dat', '.html', '.xml',
            '.ini', '.cfg', '.yml', '.yaml', '.csv'}
# Password-looking assignment: password / pwd / secret followed by = or => or : and a quoted literal.
PW = re.compile(r"""(?i)\b(password|passwd|pwd|secret|api[_-]?key)\b['"]?\s*(=>|=|:)\s*['"]([^'"\n]{4,})['"]""")
PLACEHOLDER = re.compile(r'[^\x00-\x7f]|[<>?$]|getenv|your|change|example|placeholder|xxx|\*\*\*|\.\.\.', re.I)

MANUAL = [('docs/21-user-manual.md', 'User manual'), ('docs/22-er-diagram.md', 'Final ER diagram'),
          ('docs/20-data-dictionary.md', 'Data dictionary')]
SEPARATE = [('docs/15-concurrency.md', 'Chapter (a)'), ('docs/16-security.md', 'Chapter (b)'),
            ('docs/17-extensibility.md', 'Chapter (c)'), ('docs/14-indexes-and-performance.md', 'Chapter (c), part 2')]


def warn(msg):
    print('WARNING:', msg)


def candidate_files():
    """Tracked + untracked-but-not-ignored files under sources/ sql/ data/ (git), else a directory walk."""
    rels = None
    try:
        out = subprocess.run(['git', '-C', ROOT, 'ls-files', '-co', '--exclude-standard', '--'] + list(TOP),
                             capture_output=True, text=True, check=True).stdout
        rels = [line for line in out.splitlines() if line]
    except Exception:
        pass
    if rels is None:
        rels = []
        for top in TOP:
            for d, dirs, files in os.walk(os.path.join(ROOT, top)):
                dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
                rels += [os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, '/') for f in files]
    keep = []
    for r in sorted(set(rels)):
        parts = r.split('/')
        if any(p in SKIP_DIRS for p in parts[:-1]) or parts[-1] in SKIP_NAMES:
            continue
        if os.path.splitext(parts[-1])[1].lower() in SKIP_EXT or parts[-1].startswith('.env'):
            continue
        if os.path.isfile(os.path.join(ROOT, r)):
            keep.append(r)
    return keep


def safety_scan(entries):
    """entries: list of (arcname, path). Returns a list of problems (empty = safe)."""
    bad = []
    for arc, path in entries:
        name = arc.split('/')[-1]
        ext = os.path.splitext(name)[1].lower()
        if name == 'config.php' or name.startswith('.env') or ext in {'.key', '.pem', '.pfx'}:
            bad.append(f'{arc}: must never be in the zip')
            continue
        if ext not in TEXT_EXT or os.path.getsize(path) > 8_000_000:
            continue
        with open(path, encoding='utf-8', errors='replace') as f:
            for n, line in enumerate(f, 1):
                for m in PW.finditer(line):
                    if PLACEHOLDER.search(m.group(3)):
                        continue
                    bad.append(f'{arc}:{n}: looks like a password assignment ({m.group(1)} {m.group(2)} "..."). Remove it.')
    return bad


def prepare_markdown(parts, title):
    """Joins the doc files that exist into one Markdown text. Links between docs become plain text."""
    head = f'---\ntitle: "{title}"\nsubtitle: "EPL342 Team 12 - MDMS-Cy"\n---\n\n'
    chunks, used = [], []
    for rel, label in parts:
        p = os.path.join(ROOT, rel)
        if not os.path.isfile(p):
            warn(f'{rel} ({label}) does not exist yet: skipped')
            continue
        text = open(p, encoding='utf-8').read()
        text = re.sub(r'(?m)^\[(?:←|<-)[^\n]*\n', '', text)                       # "Back to the menu" line
        text = re.sub(r'(?m)^> \*\*Status[^\n]*\n(?:>[^\n]*\n)*', '', text)              # internal status note (all its lines)
        text = re.sub(r'\[([^\]]+)\]\((?!https?://|#)[^)]*\.md[^)]*\)', r'\1', text)    # links to other .md files

        def fix_img(m, p=p, rel=rel):
            src = m.group(2)
            if re.match(r'https?://|data:', src):
                return m.group(0)
            full = os.path.normpath(os.path.join(os.path.dirname(p), src))
            if not os.path.isfile(full):
                warn(f'{rel}: image {src} not found (it will be missing in the docx)')
                return m.group(0)
            return f'![{m.group(1)}]({full.replace(os.sep, "/")})'

        text = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)\)', fix_img, text)
        chunks.append(text.strip() + '\n')
        used.append(rel)
    return head + '\n\n'.join(chunks), used


def to_docx(parts, title, outname):
    md, used = prepare_markdown(parts, title)
    if not used:
        warn(f'{outname}: no source documents exist, not built')
        return None
    fmt = 'markdown+pipe_tables+yaml_metadata_block-raw_tex'
    args = ['--toc', '--toc-depth=2', '--standalone',
            '--resource-path=' + os.pathsep.join([ROOT, os.path.join(ROOT, 'docs')])]
    os.makedirs(BUILD_DOCX, exist_ok=True)
    out = os.path.join(BUILD_DOCX, outname)
    try:
        import pypandoc
        pypandoc.convert_text(md, 'docx', format=fmt, outputfile=out, extra_args=args)
    except ImportError:
        try:
            subprocess.run(['pandoc', '-f', fmt, '-o', out] + args, input=md.encode('utf-8'), check=True)
        except (OSError, subprocess.CalledProcessError):
            sys.exit('No pandoc found: run  python -m pip install pypandoc_binary')
    print(f'built {os.path.relpath(out, ROOT)} from: ' + ', '.join(used))
    return out


def main():
    check_only = '--check-only' in sys.argv
    entries = [(r, os.path.join(ROOT, r)) for r in candidate_files()]
    if not any(a.startswith('sources/') for a, _ in entries):
        sys.exit('sources/ is empty: run this from a full checkout')
    if not os.path.isfile(os.path.join(ROOT, 'sources', 'config.example.php')):
        sys.exit('sources/config.example.php (the config template) is missing')
    if not any(a.startswith('sources/lib/leaflet/') and a.endswith('leaflet.js') for a, _ in entries):
        warn('Leaflet is not bundled under sources/lib/leaflet/: the map would need a CDN')

    if not check_only and '--no-docx' not in sys.argv:
        for parts, title, name in ((MANUAL, 'MDMS-Cy User Manual', 'MDMS-Cy_User_Manual.docx'),
                                   (SEPARATE, 'MDMS-Cy: Contention, Security and Extension',
                                    'MDMS-Cy_Contention_Security_Extension.docx')):
            f = to_docx(parts, title, name)
            if f:
                entries.append(('docx/' + name, f))

    problems = safety_scan(entries)
    if problems:
        print('REFUSING TO BUILD: found', len(problems), 'problem(s):')
        for p in problems:
            print('  ', p)
        sys.exit(2)

    counts = {}
    for a, p in entries:
        c = counts.setdefault(a.split('/')[0], [0, 0])
        c[0] += 1
        c[1] += os.path.getsize(p)
    print('\nManifest (files, size before compression):')
    for top in ('sources', 'sql', 'data', 'docx'):
        n, s = counts.get(top, [0, 0])
        print(f'  {top + "/":9} {n:5} files  {s / 1024 / 1024:7.2f} MB' + ('   <- EMPTY' if n == 0 else ''))
    print('  config.php in zip: no | config template: sources/config.example.php')
    if check_only:
        print('safety scan passed (check-only, no zip written)')
        return
    if 'docx' not in counts:
        warn('docx/ is empty. Do not upload this zip.')
    with zipfile.ZipFile(OUT_ZIP, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for a, p in entries:
            z.write(p, a)
    with zipfile.ZipFile(OUT_ZIP) as z:
        assert z.testzip() is None, 'zip is corrupt'
        names = z.namelist()
        assert not any(n.endswith('config.php') for n in names), 'config.php got in'
        tops = sorted({n.split('/')[0] for n in names})
    print(f'\nwrote {os.path.relpath(OUT_ZIP, ROOT)}  {os.path.getsize(OUT_ZIP) / 1024 / 1024:.2f} MB, '
          f'{len(names)} files, top folders: {", ".join(tops)}')
    print('Next: open the zip, look inside, print docx/, upload to Moodle before 11:00.')


if __name__ == '__main__':
    main()
