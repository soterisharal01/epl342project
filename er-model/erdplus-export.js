// Writes the whole plain-ER model (model.js) as one ERD+ file, mdms-er.erdplus.
// Layout (layout-grid.js): entities in the cells of a grid, each diamond halfway between its entities,
// attributes around their entity and off the relationship lines. ERDPLUS_LAYOUT=areas uses the area
// blocks of the ER page's whole-model drawing instead (the first version of the file).
// File format: the ERDPlus JSON format version 2 (shapes + connectors), taken from real .erdplus files:
//   Entity       { name, type: regular | weak, x, y, id, ... }
//   Attribute    { name, isDerived, isMultivalued, isOptional, isComposite, isUnique, x, y, id }
//                (isUnique on an attribute of a weak entity is the partial key, drawn with a dashed underline)
//   Relationship { name, isIdentifying, x, y, slots: [{ slotIndex, minimum, maximum, participation, cardinality, role, entityId }], id }
//   Label        { text, x, y, width, height, id }
//   Connector             attribute -> entity, relationship or composite attribute
//   RelationshipConnector entity -> relationship, with the slotIndex of that end
// A slot describes its own entity X: participation = mandatory when X takes part totally,
// cardinality = one when the other end's ratio label is 1. ERD+ prints it next to the other entity,
// which is the "(min,max) on the far side" rule of the ER page (build.js mmNext).
const fs = require('fs');
const path = require('path');
const { instance } = require('@viz-js/viz');
const { areas } = require('./model.js');
const { gridLayout } = require('./layout-grid.js');
const { parseAttr, layoutArea, layoutWhole } = require('./diagram.js');

const OUT = process.argv[2] || path.join(__dirname, 'mdms-er.erdplus');
const MARGIN = 80;
// the grid chosen from many trial runs (fewest lines over shapes and crossings, see layout-exp.js)
const GRID = { cols: 11, rows: 7, CX: 520, CY: 380, seed: 10, iters: 200000 };
// shape sizes as ERD+ draws them (px), used to put the centre of each shape where the layout wants it;
// ERD+ keeps entities and diamonds at one size and makes attributes wider for longer names
const ERD = { Entity: () => ({ w: 100, h: 45 }), Relationship: () => ({ w: 100, h: 50 }), Attribute: name => ({ w: Math.max(76, name.length * 6.5 + 30), h: 36 }) };

const allEntities = new Map(); areas.forEach(a => a.entities.forEach(e => allEntities.set(e.name, e)));
const entities = areas.flatMap(a => a.entities);
const rels = areas.flatMap(a => a.rels);

const slotOf = (x, other) => ({
  participation: x.total ? 'mandatory' : 'optional',
  cardinality: other.card === '1' ? 'one' : 'many'
});
// the pair ERD+ prints next to the line of end y (build.js mmNext): min from the other end x, max from y's ratio label
const mmNext = (x, y) => `(${x.total ? 1 : 0},${y.card === '1' ? 1 : 'M'})`;

function layout(viz) {
  if (process.env.ERDPLUS_LAYOUT === 'areas') {
    const per = {}; for (const a of areas) per[a.id] = layoutArea(viz, a, allEntities);
    layoutWhole(viz, areas, allEntities, per);
    return { pins: layoutWhole.pins.full, labels: {}, S: 1.5 };
  }
  const opt = process.env.ERDPLUS_GRID ? JSON.parse(process.env.ERDPLUS_GRID) : GRID;
  const r = gridLayout(viz, { ...opt, attrSize: ERD.Attribute });
  return { pins: r.pins, labels: r.labels, S: 1 };
}

instance().then(viz => {
  const { pins, labels, S } = layout(viz);
  const all = Object.values(pins);
  const minX = Math.min(...all.map(p => p.x - p.w / 2)), maxY = Math.max(...all.map(p => p.y + p.h / 2));
  // top-left corner in ERD+ pixels (y grows downwards) of a shape of size sz centred on the pin
  const at = (pinId, sz) => {
    const p = pins[pinId] || labels[pinId];
    if (!p) throw new Error('no position for ' + pinId);
    const cx = (p.x - minX) * S + MARGIN, cy = (maxY - p.y) * S + MARGIN;
    return { x: Math.round(cx - sz.w / 2), y: Math.round(cy - sz.h / 2) };
  };

  let next = 1;
  const shapes = [], connectors = [], idOf = new Map();
  const add = (type, details, pinId) => {
    const id = next++;
    const sz = type === 'Label' ? { w: details.width, h: details.height } : ERD[type](details.name);
    shapes.push({ type, details: { ...details, ...at(pinId, sz), id } }); idOf.set(pinId, id); return id;
  };
  const attr = (name, flags, pinId) => add('Attribute', {
    name, isDerived: false, isMultivalued: !!flags.multi, isOptional: false, isComposite: !!flags.composite, isUnique: !!flags.unique
  }, pinId);

  // entities with their attributes, in model order (the key first, so ERD+ takes it as the primary key)
  for (const e of entities) {
    const eid = add('Entity', { name: e.name, type: e.weak ? 'weak' : 'regular', isDisjointed: true, isTotalSpecialization: true, isSubtype: false, supertypeEntityId: null }, 'e_' + e.name);
    for (const a of e.attrs.map(parseAttr)) {
      const pid = `a_${e.name}_${a.name}`;
      const aid = attr(a.name, { multi: a.multi, composite: !!a.parts, unique: a.key || a.partial || a.unique }, pid);
      connectors.push({ type: 'Connector', source: aid, destination: eid });
      for (const part of a.parts || []) {
        const sid = attr(part, {}, `${pid}_${part}`);
        connectors.push({ type: 'Connector', source: sid, destination: aid });
      }
    }
  }
  // relationships, their ends and their attributes
  for (const r of rels) {
    const [a, b] = r.ends;
    const slots = r.ends.map((x, i) => ({
      slotIndex: i, minimum: '', maximum: '', ...slotOf(x, i === 0 ? b : a), role: x.role || '', entityId: idOf.get('e_' + x.e)
    }));
    const rid = add('Relationship', { name: r.name, isIdentifying: !!r.ident, slots }, 'r_' + r.name);
    r.ends.forEach((x, i) => connectors.push({ type: 'RelationshipConnector', source: idOf.get('e_' + x.e), destination: rid, slotIndex: i }));
    for (const name of r.attrs || []) {
      const aid = attr(name, {}, `a_${r.name}_${name}`);
      connectors.push({ type: 'Connector', source: aid, destination: rid });
    }
  }
  // ERD+ prints no (min,max) on a recursive relationship: one Label per line, as the ER page says;
  // next to role y's line goes mmNext(x, y)
  for (const r of rels.filter(r => r.ends[0].e === r.ends[1].e)) {
    const [a, b] = r.ends;
    [[b, a], [a, b]].forEach(([y, x], k) => {
      const key = `${r.name}_${k}`;
      if (!labels[key]) { const d = pins['r_' + r.name]; labels[key] = { x: d.x + d.w / 2 + 80, y: d.y - k * 36, w: 120, h: 26 }; }
      add('Label', { text: `${y.role} ${mmNext(x, y)}`, width: 120, height: 26 }, key);
    });
  }

  const ids = new Set(shapes.map(s => s.details.id));
  const conns = connectors.map(c => {
    const { type, source, destination, slotIndex } = c;
    if (!ids.has(source) || !ids.has(destination)) throw new Error('dangling connector ' + JSON.stringify(c));
    return { type, details: type === 'RelationshipConnector' ? { slotIndex, id: next++ } : { id: next++ }, source, destination };
  });
  const xs = shapes.map(s => s.details.x), ys = shapes.map(s => s.details.y);
  const doc = { version: 2, www: 'erdplus.com', shapes, connectors: conns, width: Math.max(...xs) + 400, height: Math.max(...ys) + 300 };
  fs.writeFileSync(OUT, JSON.stringify(doc));
  const n = t => shapes.filter(s => s.type === t).length;
  console.log(`${path.basename(OUT)}: ${n('Entity')} entities, ${n('Relationship')} relationships, ${n('Attribute')} attributes, ${n('Label')} labels, ${conns.length} connectors, ${doc.width}x${doc.height}px`);
});
