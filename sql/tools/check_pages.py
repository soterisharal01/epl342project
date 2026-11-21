#!/usr/bin/env python3
"""check_pages.py : SEC-1, automatic security check of every PHP page in sources/.

    python sql/tools/check_pages.py            # checks sources/ ; exit code 1 if any FAIL
    python sql/tools/check_pages.py <dir>      # checks another copy of sources/

For every page it prints OK or FAIL for these rules (docs/16-security.md, section 7):
  R1 role pages (sources/<role>/*.php) call require_role() with the role of their folder
  R2 no SQL text and no direct sqlsrv_* call outside db.php (only call_proc with ? parameters)
  R3 every procedure whose first parameter is @UserID gets uid() (the session) as its first value,
     never a value from the request
  R4 every POST form prints csrf_field(), and a page that reads $_POST calls check_csrf()
  R5 request values ($_GET/$_POST/$_REQUEST) are never printed without h()
  R6 every <?= output goes through h() or a helper that escapes (print_table, select_options, ...)
It reads the procedure signatures from sql/procs_*.sql, so it needs no database.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'sources')

ROLE_DIRS = {'consumer': 'Consumer', 'technician': 'Technician', 'operator': 'Operator', 'admin': 'Admin',
             'dso': 'DSO', 'tso': 'TSO', 'supplier': 'Supplier', 'aggregator': 'Aggregator'}
# Helpers that escape their own output, or print fixed HTML.
SAFE_OUTPUT = ('h(', 'csrf_field(', 'select_options(', 'url(', 'money(', 'print_table(', 'json_encode(')
# R6 outputs reviewed by hand (SEC-1, 21/11): each prints only fixed text, an int, or values already wrapped in h().
REVIEWED = {
    ('admin/gdp_retention.php', "$asof ? ' (ως ' . h($asof)"): 'fixed text + h()',
    ('consumer/60_settings.php', "in_array('Email', $chosen, true) ? ' checked'"): 'fixed attribute',
    ('consumer/60_settings.php', "in_array('SMS', $chosen, true) ? ' checked'"): 'fixed attribute',
    ('operator/adm_10_catalogs.php', "$edit && $edit[0] === 'model' ?"): 'fixed text + h()',
    ('operator/adm_10_catalogs.php', "$edit && $edit[0] === 'service' ?"): 'fixed text + h()',
    ('operator/adm_10_catalogs.php', "$edit && $edit[0] === 'tariff' ?"): 'fixed text + h()',
    ('operator/adm_10_catalogs.php', "$p"): 'loop over the constants 1, 2, 3',
    ('register_technician.php', "in_array((string)$c['CategoryID'], $chosen, true) ? ' checked'"): 'fixed attribute',
    ('tso/30_aggregates.php', "(string)$t['TransformerID'] === $tid ? ' selected'"): 'fixed attribute',
    ('tso/50_map.php', "$data ?: '[]'"): 'json_encode with JSON_HEX_TAG|AMP|APOS|QUOT, safe inside <script>',
}
SKIP = {'db.php', 'auth.php', 'layout.php', 'config.php', 'config.example.php', '_template.php'}

# Procedures whose first parameter is @UserID.
user_first = set()
for f in glob.glob(os.path.join(ROOT, 'sql', 'procs_*.sql')):
    for m in re.finditer(r'CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+(\w+)\s*(@\w+)?', open(f, encoding='utf-8').read(), re.I):
        if m.group(2) and m.group(2).lower() == '@userid':
            user_first.add(m.group(1).lower())

SQL_TEXT = re.compile(r'\b(SELECT\s+[\w*].*\bFROM\b|INSERT\s+INTO\b|UPDATE\s+\w+\s+SET\b|DELETE\s+FROM\b|\bEXEC(UTE)?\s+sp_)', re.I)
fails = 0
pages = 0


def report(ok, rule, path, msg):
    global fails
    if not ok:
        fails += 1
        print(f'FAIL {rule} {path}: {msg}')


def strip_comments(code):
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    return re.sub(r'(?m)^\s*//.*$|(?<=[;{}])\s*//[^\n]*', '', code)


for path in sorted(glob.glob(os.path.join(SRC, '**', '*.php'), recursive=True)):
    name = os.path.basename(path)
    rel = os.path.relpath(path, SRC)
    if name in SKIP or rel.startswith('lib' + os.sep):
        continue
    pages += 1
    raw = open(path, encoding='utf-8').read()
    code = strip_comments(raw)
    folder = rel.split(os.sep)[0] if os.sep in rel else ''
    before = fails

    # R1
    if folder in ROLE_DIRS and not name.startswith('_'):
        m = re.search(r"require_role\(([^)]*)\)", code)
        report(m is not None and f"'{ROLE_DIRS[folder]}'" in m.group(1), 'R1', rel, 'no require_role for ' + ROLE_DIRS[folder])
    # R2
    report(re.search(r'\bsqlsrv_(query|prepare|execute)\b', code) is None, 'R2', rel, 'direct sqlsrv call')
    for s in re.findall(r"'[^'\n]*'|\"[^\"\n]*\"", code):
        if SQL_TEXT.search(s):
            report(False, 'R2', rel, 'SQL text ' + s[:60])
    # R3
    for m in re.finditer(r"call_proc\(\s*'(\w+)'\s*(?:,\s*\[\s*([^,\]\n]*))?", code):
        proc, first = m.group(1).lower(), (m.group(2) or '').strip()
        if proc in user_first:
            report(first == 'uid()', 'R3', rel, f'{m.group(1)} first value is "{first}", not uid()')
    # R4
    posts = len(re.findall(r'<form[^>]*method\s*=\s*["\']post["\']', code, re.I))
    tokens = len(re.findall(r'csrf_field\(\)', code))
    report(tokens >= posts, 'R4', rel, f'{posts} POST forms but {tokens} csrf_field()')
    if '$_POST' in code:
        report('check_csrf()' in code, 'R4', rel, 'reads $_POST without check_csrf()')
    # R5
    for m in re.finditer(r'(echo|print|<\?=)\s*([^;?]*\$_(GET|POST|REQUEST)[^;?]*)', code):
        report(m.group(2).lstrip().startswith(SAFE_OUTPUT), 'R5', rel, 'request value printed: ' + m.group(2)[:60])
    # R6
    for m in re.finditer(r'<\?=\s*(.*?)\s*\?>', code, re.S):
        expr = m.group(1)
        safe = expr.startswith(SAFE_OUTPUT) or re.fullmatch(r"[\w$\[\]'\"]*\s*(===?|!==?|>|<)\s*[^?]*\?\s*'[^'<>]*'\s*:\s*'[^'<>]*'", expr) \
            or re.fullmatch(r"\(?int\)?\s*\$\w+.*|\d+|str_repeat\('&nbsp;.*", expr)
        reviewed = any(rel.replace(os.sep, '/') == f and (expr == e or (len(e) > 3 and expr.startswith(e))) for f, e in REVIEWED)
        report(bool(safe) or reviewed, 'R6', rel, 'unescaped output <?= ' + expr[:60])
    if fails == before:
        print(f'OK   {rel}')

print(f'{pages} pages checked, {fails} FAIL')
sys.exit(1 if fails else 0)
