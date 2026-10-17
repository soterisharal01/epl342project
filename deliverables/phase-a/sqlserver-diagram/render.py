#!/usr/bin/env python3
"""Draws the tables of the live SQL Server database (catalog.json, read from sys.tables,
sys.columns and sys.foreign_keys) as one database diagram per ER area, in the style of an
SSMS database diagram: each table lists its columns with PK/FK marks, T-SQL type and NULL,
and each foreign key is a line from the child table to the referenced table
(crow's foot at the many side, bar at the one side)."""
import json, subprocess, sys, html, os

here = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1] if len(sys.argv) > 1 else here
cat = json.load(open(os.path.join(here, 'catalog.json')))
area_of = json.load(open(os.path.join(here, 'areas.json')))
titles = json.load(open(os.path.join(here, 'areatitles.json')))

tables = {t['table']: t for t in cat['tables']}
assert set(tables) == set(area_of), set(tables) ^ set(area_of)


def tsql_type(c):
    t = c['type']
    if t in ('nvarchar', 'nchar'):
        return f"{t}({'max' if c['len'] == -1 else c['len'] // 2})"
    if t in ('varchar', 'char', 'varbinary', 'binary'):
        return f"{t}({'max' if c['len'] == -1 else c['len']})"
    if t in ('decimal', 'numeric'):
        return f"{t}({c['prec']},{c['scale']})"
    if t in ('datetime2', 'time', 'datetimeoffset'):
        return f"{t}({c['scale']})"
    return t


def pk_cols(t):
    return [c['name'] for c in t['cols'] if c['pk']]


def table_label(t, outside=False):
    e = html.escape
    if outside:
        return (f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="6" COLOR="#9AA4B2" BGCOLOR="#F1F3F6">'
                f'<TR><TD><FONT COLOR="#5B6573">{e(t["table"])}</FONT></TD></TR></TABLE>>')
    rows = [f'<TR><TD COLSPAN="4" BGCOLOR="#C9DAF0" ALIGN="LEFT" CELLPADDING="5"><B>{e(t["table"])}</B></TD></TR>',
            '<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="#5B6573">Key</FONT></TD>'
            '<TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="#5B6573">Column Name</FONT></TD>'
            '<TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="#5B6573">Data Type</FONT></TD>'
            '<TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="#5B6573">Allow Nulls</FONT></TD></TR>']
    for c in t['cols']:
        key = ' '.join(k for k, on in (('PK', c['pk']), ('FK', c['fk'])) if on)
        name = e(c['name'])
        if c['pk']:
            name = f'<B>{name}</B>'
        typ = e(tsql_type(c)) + (' IDENTITY' if c['ident'] else '')
        keycell = f'<FONT COLOR="#8A5A00">{key}</FONT>' if key else ' '
        rows.append(f'<TR><TD ALIGN="LEFT">{keycell}</TD>'
                    f'<TD ALIGN="LEFT" PORT="{e(c["name"])}">{name}</TD>'
                    f'<TD ALIGN="LEFT"><FONT COLOR="#2B4C7E">{typ}</FONT></TD>'
                    f'<TD ALIGN="CENTER">{"&#9745;" if c["nullable"] else "&#9744;"}</TD></TR>')
    return ('<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3" COLOR="#5B7BA6" BGCOLOR="white">'
            + ''.join(rows) + '</TABLE>>')


def render(area, n):
    inside = [name for name, a in area_of.items() if a == area['id']]
    fks = [f for f in cat['fks'] if f['child'] in inside or f['parent'] in inside]
    outside = sorted({f['parent'] for f in fks if f['parent'] not in inside} |
                     {f['child'] for f in fks if f['child'] not in inside})
    lines = ['digraph G {', 'graph [rankdir=RL, nodesep=0.35, ranksep=0.9, pad=0.3, fontname="Arial", '
             f'labelloc=t, fontsize=20, label="{area["title"]}: tables in SQL Server 2025 (database mdms)", dpi=150];',
             'node [shape=plaintext, fontname="Arial", fontsize=11];',
             'edge [color="#4A5568", penwidth=1.2, dir=both];']
    for name in sorted(inside):
        lines.append(f'"{name}" [label={table_label(tables[name])}];')
    for name in outside:
        lines.append(f'"{name}" [label={table_label(tables[name], outside=True)}];')
    for f in fks:
        child, parent = tables[f['child']], f['parent']
        cols = [c['c'] for c in f['cols']]
        one_to_one = sorted(cols) == sorted(pk_cols(child))
        tail = f'"{f["child"]}"'
        lines.append(f'{tail} -> "{parent}" [arrowtail={"teetee" if one_to_one else "crowodot" if any(c["nullable"] for c in child["cols"] if c["name"] in cols) else "crowtee"}, '
                     f'arrowhead=teetee, tooltip="{f["name"]}"];')
    lines.append('}')
    dot = '\n'.join(lines)
    path = os.path.join(out, f'relational-diagram-{n}.png')
    open(os.path.join(here, f'area-{n}.dot'), 'w').write(dot)
    subprocess.run(['dot', '-Tpng', '-o', path], input=dot.encode(), check=True)
    return path, len(inside), len(outside), len(fks)


total = 0
for i, a in enumerate(titles, 1):
    p, k, o, f = render(a, i)
    total += k
    print(p, k, 'tables,', o, 'from other areas,', f, 'FK')
assert total == len(tables)
