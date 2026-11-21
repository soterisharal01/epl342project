#!/usr/bin/env python3
"""Generate the final ER (Chen) and relational diagrams from sql/create.sql (task DOC-2, decision B13).

    python sql/tools/er_diagram.py            # parse create.sql, write .dot, render .svg and .png
    python sql/tools/er_diagram.py --no-render  # only the .dot files and the coverage table

Output goes to docs/img/er/. Rendering needs Graphviz: `dot` on the PATH, or Ubuntu in WSL
(`wsl -d Ubuntu -u root -- apt-get install -y graphviz`). The output is deterministic: the same
create.sql always gives byte-identical .dot files (no timestamps, no random layout).

How a table becomes a Chen shape (the rules are written out in docs/22-er-diagram.md):
  * all PK columns are foreign keys to two or more tables  -> M:N relationship (diamond)
    (HOLDING is forced to a relationship too: it keeps a start date as part of its key)
  * every column in the PK and exactly one FK              -> multivalued attribute (double oval)
  * PK holds an FK plus own column(s)                      -> weak entity (double rectangle),
                                                              FKs inside the PK = identifying relationships
  * anything else                                          -> entity (rectangle)
  * every other FK                                         -> 1:N relationship (diamond), named after the FK
"""
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SQL = os.path.join(ROOT, 'sql', 'create.sql')
OUT = os.path.join(ROOT, 'docs', 'img', 'er')

# A table that the rules cannot tell apart from a weak entity but that is a relationship with a date range.
FORCE_RELATIONSHIP = {'HOLDING'}

# Relationship names for foreign keys whose own name only repeats the table name.
REL_NAME = {
    'FK_USER_ACCOUNT_CREATES': 'CREATES',
    'FK_USER_ACCOUNT_APPROVES': 'APPROVES',
    'FK_RAW_READING_MEASURED': 'MEASURED_BY',
    'FK_RAW_READING_READ_CODE': 'READS',
    'FK_VALIDATED_READING_MEASURED': 'MEASURED_BY',
    'FK_VALIDATED_READING_READ_CODE': 'READS',
    'FK_READING_EDIT_METER': 'EDIT_OF_METER',
    'FK_READING_EDIT_CODE': 'EDIT_OF_CODE',
    'FK_METER_AGGREGATE_METER_AGG': 'METER_AGG',
    'FK_METER_AGGREGATE_METER_AGG_CODE': 'AGG_CODE',
    'FK_TRANSFORMER_AGGREGATE_TR_AGG': 'TR_AGG',
    'FK_TRANSFORMER_AGGREGATE_TR_AGG_CODE': 'AGG_CODE',
    'FK_TRANSFORMER_CURRENT_STATE_TR_STATE': 'TR_STATE',
    'FK_TRANSFORMER_CURRENT_STATE_STATE_CODE': 'STATE_CODE',
}

# Areas, used for the clusters and for the split pictures.
AREAS = [
    ('users', 'Users, premises and billing', [
        'SUPPLIER', 'AGGREGATOR', 'USER_ACCOUNT', 'CONSUMER_NOTIFICATION_CHANNEL', 'DISTRICT', 'MUNICIPALITY',
        'PARISH', 'SUPPLY_SCHEME', 'PREMISE', 'CONSUMPTION_THRESHOLD', 'HOLDING', 'PORTFOLIO', 'INCLUDES',
        'GDPR_REQUEST', 'AUDIT_LOG', 'BANK_ACCOUNT', 'ACCOUNT_FOR', 'TARIFF_TYPE', 'SUPPLY_CONTRACT', 'INVOICE',
        'PAYMENT', 'SERVICE_TYPE', 'SERVICE_PURCHASE', 'SERVICE_REQUEST']),
    ('meters', 'Meters and readings', [
        'METER_MODEL', 'COMM_TYPE', 'METER', 'METER_CONNECTED_PHASE', 'TELEMETRY_PACKET', 'OBIS_CODE', 'VEE_RULE',
        'VEE_RUN', 'RAW_READING', 'VALIDATED_READING', 'READING_EDIT', 'RULE_FOR', 'METER_AGGREGATE']),
    ('field', 'Field work and events', [
        'TECHNICIAN_CATEGORY', 'DOCUMENT', 'FIELD_TASK', 'ATTACHMENT', 'AVAILABILITY', 'TASK_NOTE', 'IN_CATEGORY',
        'AVAILABLE_IN', 'NOTIFIES', 'EVENT', 'LEADS_TO', 'METER_INSTALLATION']),
    ('grid', 'Grid and control', [
        'GEOFENCE', 'TRANSFORMER', 'TRANSFORMER_AGGREGATE', 'TRANSFORMER_CURRENT_STATE', 'LOAD_SHED_ORDER',
        'REMOTE_COMMAND', 'COMMAND_ATTEMPT']),
]
AREA_COLOR = {'users': '#e3eefb', 'meters': '#e6f4e1', 'field': '#fdf0d8', 'grid': '#f3e5f5'}
SKIP_ATTR = {'PasswordHash', 'CreatedAt', 'Photo', 'Notes'}  # never picked as an "important" attribute

TYPES = ('INT', 'BIGINT', 'SMALLINT', 'TINYINT', 'BIT', 'DATE', 'DATETIME2', 'DATETIME', 'TIME', 'DECIMAL',
         'NUMERIC', 'VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR', 'FLOAT', 'REAL', 'VARBINARY', 'UNIQUEIDENTIFIER',
         'MONEY')


# --------------------------------------------------------------------------------------------- parsing
class Table:
    def __init__(self, name):
        self.name = name
        self.cols = []        # [name, type, nullable]
        self.pk = []
        self.uniques = []     # [(constraint name, [cols], filtered?)]
        self.fks = []         # [dict(name, cols, parent, pcols, cascade)]
        self.checks = 0

    def col(self, name):
        return next(c for c in self.cols if c[0] == name)


def split_top(s):
    """split on commas that are not inside parentheses"""
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def collist(s):
    return [c.strip() for c in s.split(',')]


def parse(path):
    text = open(path, encoding='utf-8').read()
    text = re.sub(r'--[^\n]*', '', text)
    tables = {}
    for m in re.finditer(r'CREATE TABLE (\w+) \((.*?)\n\);', text, re.S):
        t = Table(m.group(1))
        tables[t.name] = t
        for item in split_top(m.group(2)):
            item = ' '.join(item.split())
            t.checks += len(re.findall(r'\bCHECK \(', item))
            c = re.match(r'CONSTRAINT (\w+) PRIMARY KEY \(([^)]*)\)', item)
            if c:
                t.pk = collist(c.group(2))
                continue
            c = re.match(r'CONSTRAINT (\w+) UNIQUE \(([^)]*)\)', item)
            if c:
                t.uniques.append((c.group(1), collist(c.group(2)), False))
                continue
            c = re.match(r'CONSTRAINT (\w+) FOREIGN KEY \(([^)]*)\) REFERENCES (\w+) \(([^)]*)\)(.*)', item)
            if c:
                t.fks.append(dict(name=c.group(1), cols=collist(c.group(2)), parent=c.group(3),
                                  pcols=collist(c.group(4)), cascade='ON DELETE CASCADE' in c.group(5)))
                continue
            if item.startswith('CONSTRAINT'):
                continue  # CHECK, handled by the count above
            c = re.match(r'(\w+) (\w+(?:\([\d, ]+\))?)(.*)', item)
            if not c or c.group(2).split('(')[0].upper() not in TYPES:
                raise SystemExit('cannot parse column in %s: %s' % (t.name, item))
            rest = c.group(3)
            if re.search(r'\b(PRIMARY KEY|REFERENCES)\b', rest) or re.search(r'\bUNIQUE\b', rest):
                raise SystemExit('inline key in %s: %s (extend the parser)' % (t.name, item))
            nullable = 'NOT NULL' not in rest
            t.cols.append([c.group(1), c.group(2).upper(), nullable])
    for t in tables.values():  # PK columns are never nullable
        for name in t.pk:
            t.col(name)[2] = False
    for m in re.finditer(r'CREATE UNIQUE INDEX (\w+) ON (\w+) \(([^)]*)\)\s*WHERE', text):
        tables[m.group(2)].uniques.append((m.group(1), collist(m.group(3)), True))
    return tables, text


# --------------------------------------------------------------------------------------------- Chen model
def classify(t):
    fkcols = {c for f in t.fks for c in f['cols']}
    parents = {f['parent'] for f in t.fks if set(f['cols']) <= set(t.pk)}
    if t.name in FORCE_RELATIONSHIP:
        return 'relationship'
    if len(t.cols) == len(t.pk) and len(t.fks) == 1 and len(t.pk) == 2:
        return 'multivalued'
    if t.pk and set(t.pk) <= fkcols and len(parents) >= 2:
        return 'relationship'
    if any(set(f['cols']) <= set(t.pk) for f in t.fks) and set(t.pk) - fkcols:
        return 'weak'
    return 'entity'


def fk_label(t, f):
    if f['name'] in REL_NAME:
        return REL_NAME[f['name']]
    rest = f['name'][len('FK_' + t.name + '_'):]
    return rest if rest else f['name']


def fk_unique(t, f):
    cols = set(f['cols'])
    return any(set(u[1]) == cols and not u[2] for u in t.uniques) or (set(t.pk) == cols)


def fk_total(t, f):
    return all(not t.col(c)[2] for c in f['cols'])


def pick_attrs(t, limit):
    fkcols = {c for f in t.fks for c in f['cols']}
    out = [c[0] for c in t.cols if c[0] not in t.pk and c[0] not in fkcols and c[0] not in SKIP_ATTR]
    return out[:limit]


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def q(s):
    return '"' + s.replace('"', '\\"') + '"'


def chen_dot(tables, kinds, subset=None, extra_attrs=0, engine='neato', title=''):
    """subset: set of table names drawn in full; entities outside it that are linked to it appear as dashed ghosts."""
    ents = [n for n, k in kinds.items() if k in ('entity', 'weak')]
    inc = set(ents) if subset is None else set(subset)
    lines = ['graph ER {', '  layout=%s;' % engine, '  overlap=prism; overlap_scaling=-6; sep="+14"; splines=true;',
             '  node [fontname="Helvetica", fontsize=11]; edge [fontname="Helvetica", fontsize=11];']
    if title:
        lines.append('  labelloc=t; fontsize=20; fontname="Helvetica-Bold"; label=%s;' % q(title))
    nodes, edges, ghosts = [], [], set()

    def entity_node(n):
        if n in inc:
            return
        ghosts.add(n)

    def ent(n):
        entity_node(n)
        return 'e_' + n

    rels = []  # collected so that ghosts are decided before drawing
    for t in tables.values():
        k = kinds[t.name]
        if k in ('entity', 'weak'):
            for f in t.fks:
                ident = k == 'weak' and set(f['cols']) <= set(t.pk)
                if t.name in inc or f['parent'] in inc:
                    rels.append(('fk', t, f, ident))
        elif k == 'relationship':
            ends = sorted({f['parent'] for f in t.fks}, key=lambda x: x)
            if any(e in inc for e in ends):
                rels.append(('mn', t, None, False))
    for kind, t, f, ident in rels:
        if kind == 'fk':
            ent(t.name), ent(f['parent'])
        else:
            for ff in t.fks:
                ent(ff['parent'])
    shown = (inc & set(ents)) | ghosts
    ents_all = [n for n in ents if n in shown]

    # attributes
    for n in ents_all:
        t = tables[n]
        if n in ghosts:
            nodes.append('  e_%s [shape=box, style="dashed,filled", fillcolor="#f4f4f4", label=%s%s];' % (
                n, q(n), ', peripheries=2' if kinds[n] == 'weak' else ''))
            continue
        nodes.append('  e_%s [shape=box, style=filled, fillcolor="#dfe9f5", margin="0.18,0.10", penwidth=1.4, label=%s%s];' % (
            n, q(n), ', peripheries=2' if kinds[n] == 'weak' else ''))
        fkcols = {c for f in t.fks for c in f['cols']}
        keys = [c for c in t.pk if c not in fkcols]
        for c in keys:
            style = 'dashed,filled' if kinds[n] == 'weak' else 'filled'
            nodes.append('  a_%s_%s [shape=ellipse, style="%s", fillcolor=white, label=<<U>%s</U>>];' % (n, c, style, esc(c)))
            edges.append('  e_%s -- a_%s_%s;' % (n, n, c))
        for c in pick_attrs(t, extra_attrs):
            nodes.append('  a_%s_%s [shape=ellipse, style=filled, fillcolor=white, label=%s];' % (n, c, q(c)))
            edges.append('  e_%s -- a_%s_%s;' % (n, n, c))
        # multivalued attributes owned by this entity
        for mt in tables.values():
            if kinds[mt.name] == 'multivalued' and mt.fks[0]['parent'] == n:
                c = next(c[0] for c in mt.cols if c[0] not in mt.fks[0]['cols'])
                nodes.append('  a_%s_%s [shape=ellipse, peripheries=2, style=filled, fillcolor=white, label=%s];' % (n, c, q(c)))
                edges.append('  e_%s -- a_%s_%s;' % (n, n, c))
        if n == 'USER_ACCOUNT':  # the role is an attribute (plain ER, decision D32)
            nodes.append('  a_USER_ACCOUNT_Role [shape=ellipse, style=filled, fillcolor="#fff4c2", label=<Role<BR/><FONT POINT-SIZE="9">8 values</FONT>>];')
            edges.append('  e_USER_ACCOUNT -- a_USER_ACCOUNT_Role;')

    # relationships
    for kind, t, f, ident in rels:
        if kind == 'fk':
            rid = 'r_' + f['name']
            nodes.append('  %s [shape=diamond, style=filled, fillcolor="#fbeeb8"%s, label=%s, height=0.7, width=1.3];' % (
                rid, ', peripheries=2' if ident else '', q(fk_label(t, f).replace('_', ' '))))
            one = fk_unique(t, f)
            childcard = '1' if one else 'N'
            child_total = fk_total(t, f) or ident
            style = ', color="black:white:black"' if child_total else ''
            if f['parent'] == t.name:  # self reference: two roles
                edges.append('  e_%s -- %s [taillabel="1 (parent)", labeldistance=2.2];' % (f['parent'], rid))
                edges.append('  e_%s -- %s [taillabel="%s (child)", labeldistance=2.2%s];' % (t.name, rid, childcard, style))
            else:
                edges.append('  e_%s -- %s [taillabel="1", labeldistance=2];' % (f['parent'], rid))
                edges.append('  e_%s -- %s [taillabel="%s", labeldistance=2%s];' % (t.name, rid, childcard, style))
        else:
            rid = 'r_' + t.name
            nodes.append('  %s [shape=diamond, style=filled, fillcolor="#fbeeb8", label=%s, height=0.7, width=1.3];' % (
                rid, q(t.name.replace('_', ' '))))
            card = iter(['M', 'N', 'P', 'Q'])
            fkcols = {c for ff in t.fks for c in ff['cols']}
            for ff in t.fks:
                inpk = set(ff['cols']) <= set(t.pk)
                edges.append('  e_%s -- %s [taillabel="%s", labeldistance=2];' % (ff['parent'], rid, next(card) if inpk else '1'))
            for c in t.cols:
                if c[0] in fkcols or c[0] in SKIP_ATTR:
                    continue
                if c[0] in t.pk or extra_attrs or t.name in FORCE_RELATIONSHIP:
                    nodes.append('  a_%s_%s [shape=ellipse, style=filled, fillcolor=white, label=%s];' % (t.name, c[0], q(c[0])))
                    edges.append('  %s -- a_%s_%s;' % (rid, t.name, c[0]))
    return '\n'.join(lines + nodes + edges + ['}']) + '\n'


# --------------------------------------------------------------------------------------------- relational model
def relational_dot(tables, subset=None, title=''):
    inc = set(tables) if subset is None else set(subset)
    area_of = {n: a[0] for a in AREAS for n in a[2]}
    ghosts = set()
    for t in tables.values():
        for f in t.fks:
            if t.name in inc and f['parent'] not in inc:
                ghosts.add(f['parent'])
            if f['parent'] in inc and t.name not in inc:
                ghosts.add(t.name)
    lines = ['digraph REL {', '  rankdir=LR; nodesep=0.25; ranksep=1.1; compound=true;',
             '  node [shape=plain, fontname="Helvetica", fontsize=10]; edge [color="#555555", arrowsize=0.7];']
    if title:
        lines.append('  labelloc=t; fontsize=22; fontname="Helvetica-Bold"; label=%s;' % q(title))
    nodes, edges = [], []

    def node(t, full):
        color = AREA_COLOR[area_of[t.name]]
        h = ['<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="2" BGCOLOR="white">',
             '<TR><TD COLSPAN="3" BGCOLOR="%s"><B>%s</B></TD></TR>' % (color, t.name)]
        if full:
            fkcols = {c for f in t.fks for c in f['cols']}
            uqcols = {c for u in t.uniques for c in u[1]}
            for name, typ, nullable in t.cols:
                tag = ','.join(x for x, on in (('PK', name in t.pk), ('FK', name in fkcols), ('UQ', name in uqcols)) if on)
                label = '<I>%s</I>' % esc(name) if nullable else esc(name)
                if name in t.pk:
                    label = '<B>%s</B>' % label
                h.append('<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="8" COLOR="#555555">%s</FONT></TD>'
                         '<TD ALIGN="LEFT" PORT="c_%s">%s</TD>'
                         '<TD ALIGN="LEFT"><FONT POINT-SIZE="8" COLOR="#555555">%s</FONT></TD></TR>' % (tag or '&nbsp;', name, label, esc(typ)))
        h.append('</TABLE>')
        return '    t_%s [label=<%s>];' % (t.name, ''.join(h))

    clusters = {}
    for n in tables:
        if n in inc or n in ghosts:
            clusters.setdefault(area_of[n], []).append(n)
    for key, label, _ in AREAS:
        if key not in clusters:
            continue
        lines.append('  subgraph cluster_%s { label=%s; style="rounded,dashed"; color="#999999"; fontname="Helvetica-Bold"; fontsize=16;' % (key, q(label)))
        for n in clusters[key]:
            lines.append(node(tables[n], n in inc))
        lines.append('  }')
    for t in tables.values():
        for f in t.fks:
            if t.name not in inc and f['parent'] not in inc:
                continue
            tail = 't_%s:c_%s' % (t.name, f['cols'][0]) if t.name in inc else 't_%s' % t.name
            head = 't_%s:c_%s' % (f['parent'], f['pcols'][0]) if f['parent'] in inc else 't_%s' % f['parent']
            edges.append('  %s -> %s [dir=both, arrowtail=crow, arrowhead=tee, tooltip=%s];' % (tail, head, q(f['name'])))
    return '\n'.join(lines + edges + ['}']) + '\n'


# --------------------------------------------------------------------------------------------- output
def which_dot():
    for d in os.environ.get('PATH', '').split(os.pathsep):
        for ext in ('', '.exe'):
            if os.path.isfile(os.path.join(d, 'dot' + ext)):
                return ['dot']
    return ['wsl', '-d', 'Ubuntu', '--', 'dot']


def wsl_path(p):
    p = os.path.abspath(p).replace('\\', '/')
    return '/mnt/%s%s' % (p[0].lower(), p[2:]) if re.match(r'^[A-Za-z]:', p) else p


def render(dotfile, fmt, extra=()):
    cmd = which_dot()
    conv = wsl_path if cmd[0] == 'wsl' else (lambda x: x)
    out = dotfile[:-4] + '.' + fmt
    subprocess.run(cmd + ['-T' + fmt, *extra, '-o', conv(out), conv(dotfile)], check=True)


def main():
    do_render = '--no-render' not in sys.argv
    tables, text = parse(SQL)
    kinds = {n: classify(t) for n, t in tables.items()}
    in_areas = [n for a in AREAS for n in a[2]]
    missing = [n for n in tables if n not in in_areas]
    unknown = [n for n in in_areas if n not in tables]
    if missing or unknown or len(in_areas) != len(set(in_areas)):
        raise SystemExit('AREAS out of date: missing %s, unknown %s' % (missing, unknown))
    nfk = sum(len(t.fks) for t in tables.values())
    nck = sum(t.checks for t in tables.values())
    print('parsed %d tables, %d foreign keys, %d checks' % (len(tables), nfk, nck))

    os.makedirs(OUT, exist_ok=True)
    jobs = [('relational', relational_dot(tables, title='MDMS-Cy relational diagram (all %d tables)' % len(tables)), ['-Gdpi=90'])]
    for key, label, names in AREAS:
        jobs.append(('relational-' + key, relational_dot(tables, set(names), title='Relational diagram: ' + label), ['-Gdpi=115']))
    jobs.append(('er-chen', chen_dot(tables, kinds, None, 0, 'neato', 'MDMS-Cy ER diagram (Chen), overview with key attributes'), ['-Gdpi=90']))
    for key, label, names in AREAS:
        jobs.append(('er-chen-' + key, chen_dot(tables, kinds, set(names), 4, 'neato', 'ER diagram (Chen): ' + label), ['-Gdpi=115']))
    digest = hashlib.sha256()
    for name, dot, extra in jobs:
        path = os.path.join(OUT, name + '.dot')
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(dot)
        digest.update(dot.encode())
        if do_render:
            render(path, 'svg')
            render(path, 'png', extra)
        print('wrote', name)
    print('dot sources sha256:', digest.hexdigest())

    # coverage: every table must be found in the relational dot and somewhere in the Chen dots
    chen_text = ''.join(open(os.path.join(OUT, n + '.dot'), encoding='utf-8').read() for n, _, _ in jobs if n.startswith('er-chen'))
    rel_text = open(os.path.join(OUT, 'relational.dot'), encoding='utf-8').read()
    rows = ['| Table | Chen shape | In relational | In Chen |', '|---|---|---|---|']
    bad = 0
    for n, t in tables.items():
        k = kinds[n]
        if k in ('entity', 'weak'):
            found = ' e_%s [' % n in chen_text
            shape = 'weak entity' if k == 'weak' else 'entity'
        elif k == 'relationship':
            found = ' r_%s [' % n in chen_text
            shape = 'M:N relationship'
        else:
            col = next(c[0] for c in t.cols if c[0] not in t.fks[0]['cols'])
            found = ' a_%s_%s [' % (t.fks[0]['parent'], col) in chen_text
            shape = 'multivalued attribute of ' + t.fks[0]['parent']
        inrel = ' t_%s [' % n in rel_text
        bad += (not found) + (not inrel)
        rows.append('| `%s` | %s | %s | %s |' % (n, shape, 'yes' if inrel else 'NO', 'yes' if found else 'NO'))
    with open(os.path.join(OUT, 'coverage.md'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(rows) + '\n')
    counts = {}
    for k in kinds.values():
        counts[k] = counts.get(k, 0) + 1
    print('shapes:', counts, '| coverage problems:', bad)
    print('FK relationships drawn as 1:N diamonds:',
          sum(len(t.fks) for t in tables.values() if kinds[t.name] in ('entity', 'weak')))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
