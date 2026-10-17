// Reads an .erdplus file back, rebuilds the ER model from its shapes and connectors alone, and compares it
// with model.js: every entity, attribute (with its flags and parts), relationship, end, ratio, participation,
// role and relationship attribute. Exits with 1 on any difference.
const fs = require('fs');
const path = require('path');
const { areas } = require('./model.js');
const { parseAttr } = require('./diagram.js');

const FILE = process.argv.slice(2).find(a => !a.startsWith('--')) || path.join(__dirname, 'mdms-er.erdplus');
const doc = JSON.parse(fs.readFileSync(FILE, 'utf8').replace(/^﻿/, ''));
const errs = [];
const bad = m => errs.push(m);

if (doc.version !== 2 || doc.www !== 'erdplus.com') bad('header is not version 2 / erdplus.com');
const byId = new Map();
for (const s of doc.shapes) { if (byId.has(s.details.id)) bad('duplicate shape id ' + s.details.id); byId.set(s.details.id, s); }
const connIds = new Set();
for (const c of doc.connectors) {
  if (byId.has(c.details.id) || connIds.has(c.details.id)) bad('duplicate id ' + c.details.id); connIds.add(c.details.id);
  if (!byId.has(c.source) || !byId.has(c.destination)) bad('connector to a missing shape ' + JSON.stringify(c));
}
const of = t => doc.shapes.filter(s => s.type === t);
const name = id => byId.get(id).details.name;

// ---- rebuild the model from the file ----
const attrConns = doc.connectors.filter(c => c.type === 'Connector');
const relConns = doc.connectors.filter(c => c.type === 'RelationshipConnector');
const outOf = new Map(); // attribute id -> its single owner
for (const c of attrConns) {
  if (byId.get(c.source).type !== 'Attribute') bad('Connector source is not an attribute: ' + c.details.id);
  if (outOf.has(c.source)) bad('attribute connected twice: ' + name(c.source));
  outOf.set(c.source, c.destination);
}
of('Attribute').forEach(a => { if (!outOf.has(a.details.id)) bad('attribute with no owner: ' + a.details.name); });
const attrsOf = owner => attrConns.filter(c => c.destination === owner).map(c => byId.get(c.source));

const flagStr = (d, ownerWeak, parts) => {
  // what an ERD+ reader sees: underline (Unique) on a regular entity, dashed underline (Unique) on a weak one
  const u = d.isUnique ? (ownerWeak ? '~' : '_') : '';
  const base = d.isMultivalued ? `{${d.name}}` : u + d.name;
  return parts.length ? `${base}(${parts.join(',')})` : base;
};
const fileEnt = new Map();
for (const e of of('Entity')) {
  const d = e.details;
  if (fileEnt.has(d.name)) bad('duplicate entity ' + d.name);
  const weak = d.type === 'weak';
  if (!['weak', 'regular'].includes(d.type)) bad(`entity ${d.name} has type ${d.type}`);
  const attrs = attrsOf(d.id).map(a => {
    const parts = attrsOf(a.details.id);
    if (parts.length && !a.details.isComposite) bad(`${d.name}.${a.details.name} has parts but is not Composite`);
    if (!parts.length && a.details.isComposite) bad(`${d.name}.${a.details.name} is Composite with no parts`);
    parts.forEach(p => { const q = p.details; if (q.isUnique || q.isMultivalued || q.isComposite || q.isDerived || q.isOptional) bad(`part ${q.name} has flags`); if (attrsOf(q.id).length) bad(`part ${q.name} has parts`); });
    if (a.details.isDerived || a.details.isOptional) bad(`${d.name}.${a.details.name} is Derived or Optional`);
    return { s: flagStr(a.details, weak, parts.map(p => p.details.name)), id: a.details.id };
  });
  fileEnt.set(d.name, { weak, attrs, id: d.id });
}
const fileRel = new Map();
for (const r of of('Relationship')) {
  const d = r.details;
  if (fileRel.has(d.name)) bad('duplicate relationship ' + d.name);
  const conns = relConns.filter(c => c.destination === d.id);
  if (conns.length !== d.slots.length) bad(`${d.name}: ${conns.length} lines for ${d.slots.length} slots`);
  d.slots.forEach((sl, i) => {
    if (sl.slotIndex !== i) bad(`${d.name}: slot ${i} has slotIndex ${sl.slotIndex}`);
    const c = conns.filter(c => c.details.slotIndex === i);
    if (c.length !== 1 || c[0].source !== sl.entityId) bad(`${d.name}: slot ${i} line does not match its entity`);
    if (!['mandatory', 'optional'].includes(sl.participation) || !['one', 'many'].includes(sl.cardinality)) bad(`${d.name}: slot ${i} is ${sl.participation}/${sl.cardinality}`);
    if (sl.minimum !== '' || sl.maximum !== '') bad(`${d.name}: slot ${i} has exact min/max`);
  });
  fileRel.set(d.name, { ident: d.isIdentifying, slots: d.slots, attrs: attrsOf(d.id).map(a => a.details.name) });
}

// ---- compare with model.js ----
const entities = areas.flatMap(a => a.entities), rels = areas.flatMap(a => a.rels);
const want = a => { const at = parseAttr(a); const base = at.multi ? `{${at.name}}` : (at.key ? '_' : at.partial ? '~' : at.unique ? '_' : '') + at.name; return at.parts ? `${base}(${at.parts.join(',')})` : base; };
for (const e of entities) {
  const f = fileEnt.get(e.name);
  if (!f) { bad('missing entity ' + e.name); continue; }
  if (f.weak !== !!e.weak) bad(`${e.name}: weak ${f.weak}, model ${!!e.weak}`);
  const w = e.attrs.map(want), g = f.attrs.map(a => a.s);
  if (JSON.stringify(w) !== JSON.stringify(g)) bad(`${e.name} attributes\n  model ${w.join(' ')}\n  file  ${g.join(' ')}`);
  // ERD+ makes the first Unique attribute ending in ID the primary key (the first Unique one when none ends in ID)
  const key = e.attrs.map(parseAttr).find(a => a.key);
  if (!e.weak) { const u = f.attrs.map(a => byId.get(a.id).details).filter(d => d.isUnique); const first = u.find(d => /ID$/.test(d.name)) || u[0]; if (!first || first.name !== key.name) bad(`${e.name}: ERD+ would take ${first && first.name} as key, model key ${key.name}`); }
}
for (const n of fileEnt.keys()) if (!entities.some(e => e.name === n)) bad('extra entity ' + n);
const printed = []; // what ERD+ prints next to each entity, for the report
for (const r of rels) {
  const f = fileRel.get(r.name);
  if (!f) { bad('missing relationship ' + r.name); continue; }
  if (f.ident !== !!r.ident) bad(`${r.name}: identifying ${f.ident}, model ${!!r.ident}`);
  if (f.slots.length !== r.ends.length) { bad(`${r.name}: ${f.slots.length} ends`); continue; }
  r.ends.forEach((x, i) => {
    const sl = f.slots[i], other = r.ends[1 - i];
    if (name(sl.entityId) !== x.e) bad(`${r.name} end ${i}: ${name(sl.entityId)}, model ${x.e}`);
    if ((sl.participation === 'mandatory') !== x.total) bad(`${r.name} ${x.e}: participation ${sl.participation}, model total=${x.total}`);
    if ((sl.cardinality === 'one') !== (other.card === '1')) bad(`${r.name} ${x.e}: cardinality ${sl.cardinality}, other end ratio ${other.card}`);
    if ((sl.role || '') !== (x.role || '')) bad(`${r.name} ${x.e}: role ${sl.role}, model ${x.role}`);
  });
  // ERD+ prints slot i next to the other end: (1 if mandatory else 0, 1 if one else M)
  const pair = sl => `(${sl.participation === 'mandatory' ? 1 : 0},${sl.cardinality === 'one' ? 1 : 'M'})`;
  printed.push(`${r.name}: ${r.ends[1].e}${r.ends[1].role ? '[' + r.ends[1].role + ']' : ''} ${pair(f.slots[0])} | ${r.ends[0].e}${r.ends[0].role ? '[' + r.ends[0].role + ']' : ''} ${pair(f.slots[1])}`);
  if (JSON.stringify(f.attrs) !== JSON.stringify(r.attrs || [])) bad(`${r.name} attributes ${f.attrs} vs ${r.attrs || []}`);
}
for (const n of fileRel.keys()) if (!rels.some(r => r.name === n)) bad('extra relationship ' + n);

// the same pairs as the ER page tells the reader to put next to each entity (build.js mmNext)
const mmNext = (x, y) => `(${x.total ? 1 : 0},${y.card === '1' ? 1 : 'M'})`;
const page = rels.map(r => { const [a, b] = r.ends; return `${r.name}: ${b.e}${b.role ? '[' + b.role + ']' : ''} ${mmNext(a, b)} | ${a.e}${a.role ? '[' + a.role + ']' : ''} ${mmNext(b, a)}`; });
if (JSON.stringify(page) !== JSON.stringify(printed)) bad('printed (min,max) differ from the ER page');

// a weak entity takes part (1,1) in the identifying relationship that identifies it (its own slot: mandatory, one),
// and every weak entity is identified by at least one; a weak entity may also be the owner in another identifying relationship
const own = sl => `(${sl.participation === 'mandatory' ? 1 : 0},${sl.cardinality === 'one' ? 1 : 'M'})`;
const weakIds = new Set(of('Entity').filter(e => e.details.type === 'weak').map(e => e.details.id));
const identified = new Set();
for (const r of of('Relationship').filter(r => r.details.isIdentifying)) {
  const deps = r.details.slots.filter(sl => weakIds.has(sl.entityId) && own(sl) === '(1,1)');
  if (!deps.length) bad(`${r.details.name}: identifying, but no weak entity takes part (1,1)`);
  deps.forEach(sl => identified.add(sl.entityId));
}
for (const id of weakIds) if (!identified.has(id)) bad(`weak ${name(id)}: no identifying relationship where it takes part (1,1)`);

// labels: only the (min,max) of recursive relationships
const recs = rels.filter(r => r.ends[0].e === r.ends[1].e);
const labels = of('Label').map(l => l.details.text).sort();
const wantLabels = recs.flatMap(r => { const [a, b] = r.ends; return [`${b.role} ${mmNext(a, b)}`, `${a.role} ${mmNext(b, a)}`]; }).sort();
if (JSON.stringify(labels) !== JSON.stringify(wantLabels)) bad(`labels ${labels} vs ${wantLabels}`);

// shapes on top of each other (sizes as the export assumes)
const boxes = doc.shapes.map(s => ({ n: s.details.name || s.details.text, x: s.details.x, y: s.details.y }));
const near = []; for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) if (Math.abs(boxes[i].x - boxes[j].x) < 4 && Math.abs(boxes[i].y - boxes[j].y) < 4) near.push(boxes[i].n + '/' + boxes[j].n);
if (near.length) bad('shapes at the same spot: ' + near.join(', '));

const attrCount = entities.reduce((s, e) => s + e.attrs.map(parseAttr).reduce((t, a) => t + 1 + (a.parts || []).length, 0), 0) + rels.reduce((s, r) => s + (r.attrs || []).length, 0);
const report = {
  file: path.basename(FILE), bytes: fs.statSync(FILE).size,
  entities: [of('Entity').length, entities.length], weak: [of('Entity').filter(e => e.details.type === 'weak').length, entities.filter(e => e.weak).length],
  relationships: [of('Relationship').length, rels.length], identifying: [of('Relationship').filter(r => r.details.isIdentifying).length, rels.filter(r => r.ident).length],
  attributeShapes: [of('Attribute').length, attrCount], labels: of('Label').length, connectors: doc.connectors.length,
  errors: errs
};
console.log(JSON.stringify(report, null, 1));
if (process.argv.includes('--pairs')) console.log(printed.join('\n'));
process.exit(errs.length ? 1 : 0);
