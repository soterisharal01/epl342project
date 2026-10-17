// Writes mdms-relational.erdplus: the relational schema of create.sql as an ERD+ relational diagram
// (the "new" ERD+ format, diagramType 2, opened with Menu > Restore > Upload or Import in erdplus.com).
// Format as in tobiager/Erdus src/types.ts: tables are nodes with columns; every foreign key is one
// edge from the child table (source) to the referenced table (target) listing the child's FK columns,
// which ERD+ joins to the target's primary key. Every FK in schema.js references the full PK (checked).
// Layout: each table sits in the column of its entity (or relationship diamond) in mdms-er.erdplus,
// stacked top to bottom in the order of the ER diagram, so the picture keeps the ER diagram's areas.
const fs = require('fs');
const path = require('path');
const { tables, order } = require('./schema.js');

const er = JSON.parse(fs.readFileSync(path.join(__dirname, 'mdms-er.erdplus'), 'utf8'));
const erPos = new Map(er.shapes.filter(s => s.type === 'Entity' || s.type === 'Relationship').map(s => [s.details.name, s.details]));

const W = 260, GAPX = 90, GAPY = 60, CELL = 520; // CELL: column width of the ER grid (layout-grid.js)
const height = n => Math.max(76, 38 + 18 * n);
const anchor = t => erPos.get(t.from.entity) || erPos.get(t.from.rel) || erPos.get(t.name);

const cols = new Map();
for (const t of order) {
  const a = anchor(t);
  if (!a) throw new Error(`no ER position for ${t.name}`);
  const c = Math.round(a.x / CELL);
  if (!cols.has(c)) cols.set(c, []);
  cols.get(c).push({ t, y: a.y + (t.from.attr ? 1 : 0) }); // a multivalued table goes just below its entity
}

const nodes = [], edges = [], colId = new Map();
let tid = 0;
for (const [c, list] of [...cols.entries()].sort((a, b) => a[0] - b[0])) {
  list.sort((a, b) => a.y - b.y);
  let y = 0;
  for (const { t } of list) {
    const id = `t-${++tid}`;
    const columns = t.cols.map((col, i) => {
      const cid = `c-${tid}-${i + 1}`;
      colId.set(`${t.name}.${col.name}`, cid);
      const unique = t.uniques.some(u => u.cols.length === 1 && u.cols[0] === col.name);
      return { id: cid, name: col.name, type: col.type, position: i, isPrimaryKey: !!col.pk, isOptional: !!col.nul, isUnique: unique };
    });
    nodes.push({
      id, type: 'Table', position: { x: c * (W + GAPX), y },
      data: { label: t.name, isConnectable: true, columns, numberOfGroups: 0, isSelected: false },
      measured: { width: W, height: height(columns.length) }, selected: false, dragging: false,
    });
    t._node = id;
    y += height(columns.length) + GAPY;
  }
}

for (const t of order) for (const f of t.fks) {
  const gid = `g-${f.name}`;
  edges.push({
    id: `${t._node}->${tables.get(f.ref)._node}_${gid}`, type: 'Relational',
    source: t._node, target: tables.get(f.ref)._node, targetHandle: `foreign-key-handle-${gid}`,
    markerStart: { type: 'arrow' },
    data: { foreignKeyProps: { foreignKeyGroupId: gid, sourceTableId: t._node,
      columns: f.cols.map(n => ({ id: colId.get(`${t.name}.${n}`), name: n, type: t.cols.find(c => c.name === n).type })) } },
  });
}

const doc = {
  diagramType: 2,
  data: { nodes, edges, viewport: { x: 0, y: 0, zoom: 0.3 } },
  name: 'MDMS-Cy relational schema', folder: { name: 'Diagrams', folderType: 1, depth: 0, id: 1 }, id: 1,
  updatedAtTimestamp: 1792195200000,
};
fs.writeFileSync(path.join(__dirname, 'mdms-relational.erdplus'), JSON.stringify(doc));
console.log(JSON.stringify({ tables: nodes.length, columns: nodes.reduce((s, n) => s + n.data.columns.length, 0), fks: edges.length,
  width: Math.max(...nodes.map(n => n.position.x)) + W, height: Math.max(...nodes.map(n => n.position.y + n.measured.height)) }));
