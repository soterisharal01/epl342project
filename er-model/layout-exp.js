// Experiment: score whole-model layouts for the ERD+ file (straight lines centre to centre, as ERD+ draws them).
const { instance } = require('@viz-js/viz');
const { areas } = require('./model.js');
const D = require('./diagram.js');
const { parseAttr, buildDot, placeAttrs, parsePositions, layoutArea, layoutWhole } = D;
const { segHitsBox, cross } = D.geom;
const allEntities = new Map(); areas.forEach(a => a.entities.forEach(e => allEntities.set(e.name, e)));
const whole = { id: 'all', entities: areas.flatMap(a => a.entities), rels: areas.flatMap(a => a.rels), isa: [] };

function edgesOf() {
  const E = [];
  whole.rels.forEach(r => r.ends.forEach(x => E.push(['e_' + x.e, 'r_' + r.name, 's'])));
  whole.entities.forEach(e => e.attrs.map(parseAttr).forEach(a => { const id = `a_${e.name}_${a.name}`; E.push(['e_' + e.name, id, 'a']); (a.parts || []).forEach(p => E.push([id, `${id}_${p}`, 'a'])); }));
  whole.rels.forEach(r => (r.attrs || []).forEach(a => E.push(['r_' + r.name, `a_${r.name}_${a}`, 'a'])));
  return E;
}
const EDGES = edgesOf();
function score(pins) {
  const ids = Object.keys(pins);
  let hits = 0, crossings = 0, sCross = 0, clash = 0, len = 0, sLen = 0, maxLen = 0;
  const shrink = id => id.startsWith('e_') ? pins[id] : { ...pins[id], w: pins[id].w * 0.7, h: pins[id].h * 0.7 };
  for (const [u, v, k] of EDGES) {
    const a = pins[u], b = pins[v]; const l = Math.hypot(a.x - b.x, a.y - b.y); len += l; if (k === 's') { sLen += l; maxLen = Math.max(maxLen, l); }
    for (const id of ids) if (id !== u && id !== v && segHitsBox(a, b, shrink(id))) hits++;
  }
  for (let i = 0; i < EDGES.length; i++) for (let j = i + 1; j < EDGES.length; j++) {
    const [a, b, k1] = EDGES[i], [c, d, k2] = EDGES[j];
    if (a === c || a === d || b === c || b === d) continue;
    if (cross(pins[a], pins[b], pins[c], pins[d])) { crossings++; if (k1 === 's' && k2 === 's') sCross++; }
  }
  for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
    const a = pins[ids[i]], b = pins[ids[j]];
    if (Math.abs(a.x - b.x) < (a.w + b.w) / 2 - 2 && Math.abs(a.y - b.y) < (a.h + b.h) / 2 - 2) clash++;
  }
  const xs = ids.map(id => pins[id].x), ys = ids.map(id => pins[id].y);
  const W = Math.max(...xs) - Math.min(...xs), H = Math.max(...ys) - Math.min(...ys);
  return { clash, hits, crossings, sCross, sLen: Math.round(sLen), maxLen: Math.round(maxLen), W: Math.round(W), H: Math.round(H), s: 1000 * clash + 300 * hits + 40 * crossings + sLen / 20 + W * H / 20000 };
}
module.exports = { score, whole, allEntities, EDGES };

if (require.main === module) instance().then(viz => {
  const per = {}; for (const a of areas) per[a.id] = layoutArea(viz, a, allEntities);
  layoutWhole(viz, areas, allEntities, per);
  console.log('current', JSON.stringify(score(layoutWhole.pins.full)));
  const struct = { ...whole, entities: whole.entities.map(e => ({ ...e, attrs: [] })), rels: whole.rels.map(r => ({ ...r, attrs: [] })) };
  const CONFIGS = [
    { gattr: 'overlap=prism, overlap_scaling=-4, sep="+14", mode=major', rlen: 1.3 },
    { gattr: 'overlap=prism, overlap_scaling=-2, sep="+10", mode=major', rlen: 1.0 },
    { gattr: 'overlap=prism, overlap_scaling=0, sep="+8", mode=major', rlen: 0.9 },
    { gattr: 'overlap=prism, overlap_scaling=-4, sep="+14", mode=KK', rlen: 1.3 },
    { gattr: 'overlap=prism, overlap_scaling=-4, sep="+14", model=subset', rlen: 1.3 },
  ];
  const res = [];
  for (const [ci, cfg] of CONFIGS.entries()) for (const start of [3, 7, 11, 19, 23, 31]) {
    let P;
    try { P = parsePositions(viz.renderString(buildDot(struct, allEntities, false, null, { ...cfg, start }), { format: 'dot' })); } catch (e) { console.log('fail', ci, start, e.message.slice(0, 80)); continue; }
    for (const S of [1.3, 1.5, 1.7, 1.9, 2.2]) {
      const placed = placeAttrs(whole, P, true, S);
      const sc = score(placed.pins);
      res.push({ ci, start, S, ...sc });
    }
  }
  res.sort((a, b) => a.s - b.s);
  res.slice(0, 12).forEach(r => console.log(JSON.stringify(r)));
});
