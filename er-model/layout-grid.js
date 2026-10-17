// Grid layout of the whole model for the ERD+ file: entities sit in the cells of a grid, every diamond sits
// halfway between its two entities, and the attributes fan out around their entity (diagram.js placeAttrs).
// The cell of each entity is chosen by simulated annealing: short relationship lines, few lines over other
// entities, few crossings. Coordinates are Graphviz points with y up, like the other layouts.
const { areas } = require('./model.js');
const { buildDot, placeAttrs, parsePositions, geom } = require('./diagram.js');

const entities = areas.flatMap(a => a.entities), rels = areas.flatMap(a => a.rels);

// deterministic random numbers, so the same model always gives the same file
const rng = seed => () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

function gridLayout(viz, opt = {}) {
  const { cols = 10, rows = 7, CX = 470, CY = 330, seed = 1, iters = 400000, wLen = 1, wHit = 8, wCross = 4 } = opt;
  const whole = { id: 'all', entities, rels, isa: [] };
  const struct = { ...whole, entities: entities.map(e => ({ ...e, attrs: [] })), rels: rels.map(r => ({ ...r, attrs: [] })) };
  // shape sizes, and a starting arrangement, from one neato run of the structure
  const P0 = parsePositions(viz.renderString(buildDot(struct, new Map(entities.map(e => [e.name, e])), false, null,
    { gattr: 'overlap=prism, overlap_scaling=-4, sep="+14", model=subset', rlen: 1.3, start: 9 }), { format: 'dot' }));
  const names = entities.map(e => e.name), idx = new Map(names.map((n, i) => [n, i]));
  const N = names.length, CELLS = cols * rows;
  const edges = rels.filter(r => r.ends[0].e !== r.ends[1].e).map(r => [idx.get(r.ends[0].e), idx.get(r.ends[1].e)]);
  const inc = names.map(() => []); edges.forEach(([a, b], k) => { inc[a].push(k); inc[b].push(k); });
  const ar = CY / CX; // cell units: x in columns, y in rows scaled to the column width

  // start: neato positions scaled onto the grid, highest degree first, nearest free cell
  const xs = names.map(n => P0['e_' + n].x), ys = names.map(n => P0['e_' + n].y);
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const cellOf = new Array(N), who = new Array(CELLS).fill(-1);
  [...names.keys()].sort((a, b) => inc[b].length - inc[a].length).forEach(i => {
    const gx = (xs[i] - x0) / (x1 - x0) * (cols - 1), gy = (y1 - ys[i]) / (y1 - y0) * (rows - 1);
    let best = -1, bd = Infinity;
    for (let c = 0; c < CELLS; c++) if (who[c] < 0) { const d = (c % cols - gx) ** 2 + (Math.floor(c / cols) - gy) ** 2; if (d < bd) { bd = d; best = c; } }
    cellOf[i] = best; who[best] = i;
  });
  const pt = c => ({ x: c % cols, y: Math.floor(c / cols) * ar });

  // cost of one edge against the current arrangement: its length, entities it runs over, lines it crosses
  const hitR = 0.28 * ar;
  const runsOver = (a, b, p) => { // distance from p to segment a-b, only strictly inside the segment
    const dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy; const t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / L2;
    if (t <= 0.02 || t >= 0.98) return false;
    return Math.hypot(a.x + t * dx - p.x, a.y + t * dy - p.y) < hitR;
  };
  const crosses = (a, b, c, d) => geom.cross(a, b, c, d);
  const edgeCost = (k, skipCrossWith) => {
    const [u, v] = edges[k]; const a = pt(cellOf[u]), b = pt(cellOf[v]);
    const L = Math.hypot(a.x - b.x, a.y - b.y);
    let c = wLen * L * L;
    for (let i = 0; i < N; i++) if (i !== u && i !== v && runsOver(a, b, pt(cellOf[i]))) c += wHit;
    for (let j = 0; j < edges.length; j++) {
      if (j === k || (skipCrossWith && skipCrossWith.has(j) && j < k)) continue;
      const [p, q] = edges[j]; if (p === u || p === v || q === u || q === v) continue;
      if (crosses(a, b, pt(cellOf[p]), pt(cellOf[q]))) c += wCross;
    }
    return c;
  };
  // edges whose cost changes when entities in `moved` change cell: their own edges, plus every edge that may run over them
  const affected = (moved) => { const s = new Set(); moved.forEach(i => inc[i].forEach(k => s.add(k))); return s; };
  const localCost = (moved) => {
    const A = affected(moved); let c = 0;
    A.forEach(k => { c += edgeCost(k, A); });
    // other edges running over the moved entities
    for (let k = 0; k < edges.length; k++) if (!A.has(k)) { const [u, v] = edges[k]; const a = pt(cellOf[u]), b = pt(cellOf[v]); moved.forEach(i => { if (runsOver(a, b, pt(cellOf[i]))) c += wHit; }); }
    return c;
  };
  const total = () => { let c = 0; const all = new Set(edges.keys()); all.forEach(k => { c += edgeCost(k, all); }); return c; };

  const rand = rng(seed);
  let T = 3.0; const T1 = 0.02, cool = Math.pow(T1 / T, 1 / iters);
  let cur = total();
  for (let it = 0; it < iters; it++, T *= cool) {
    const i = Math.floor(rand() * N), c = Math.floor(rand() * CELLS);
    const j = who[c]; if (j === i) continue;
    const moved = j >= 0 ? [i, j] : [i];
    const before = localCost(moved);
    const ci = cellOf[i];
    cellOf[i] = c; who[c] = i; if (j >= 0) { cellOf[j] = ci; who[ci] = j; } else who[ci] = -1;
    const after = localCost(moved);
    const d = after - before;
    if (d <= 0 || rand() < Math.exp(-d / T)) cur += d;
    else { cellOf[i] = ci; who[ci] = i; if (j >= 0) { cellOf[j] = c; who[c] = j; } else who[c] = -1; }
  }

  // drop empty rows and columns
  const usedC = [...new Set(cellOf.map(c => c % cols))].sort((a, b) => a - b), usedR = [...new Set(cellOf.map(c => Math.floor(c / cols)))].sort((a, b) => a - b);
  const pins = {};
  names.forEach((n, i) => { const p = P0['e_' + n]; pins['e_' + n] = { x: usedC.indexOf(cellOf[i] % cols) * CX, y: -usedR.indexOf(Math.floor(cellOf[i] / cols)) * CY, w: p.w, h: p.h }; });

  // diamonds: halfway between the two entities, side by side when two relationships join the same pair
  const box = (p, m = 10) => ({ x0: p.x - p.w / 2 - m, x1: p.x + p.w / 2 + m, y0: p.y - p.h / 2 - m, y1: p.y + p.h / 2 + m });
  const hit = (p, q) => { const a = box(p), b = box(q, 0); return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1; };
  const placed = Object.values(pins).slice();
  const free = p => !placed.some(q => hit(p, q));
  const pairN = {}, pairK = {};
  rels.forEach(r => { const k = r.ends.map(x => x.e).sort().join('|'); pairN[k] = (pairN[k] || 0) + 1; });
  rels.forEach(r => {
    const p = P0['r_' + r.name]; const [a, b] = r.ends.map(x => pins['e_' + x.e]);
    let cand;
    if (a === b) {
      // recursive: next to the entity, on the side with the fewest lines
      const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ dx, dy, n: rels.filter(o => o !== r && o.ends.some(x => x.e === r.ends[0].e)).map(o => o.ends.find(x => x.e !== r.ends[0].e)).filter(Boolean).filter(x => { const q = pins['e_' + x.e]; return Math.sign(q.x - a.x) === dx || Math.sign(q.y - a.y) === dy; }).length }));
      dirs.sort((u, v) => u.n - v.n);
      cand = dirs.map(d => ({ x: a.x + d.dx * 0.5 * CX, y: a.y + d.dy * 0.5 * CY, w: p.w, h: p.h }));
    } else {
      const k = r.ends.map(x => x.e).sort().join('|'); const n = pairN[k]; const i = pairK[k] = (pairK[k] || 0); pairK[k]++;
      const dx = b.x - a.x, dy = b.y - a.y, L = Math.hypot(dx, dy); const nx = -dy / L, ny = dx / L;
      const off = (i - (n - 1) / 2) * 80;
      const mid = { x: (a.x + b.x) / 2 + nx * off, y: (a.y + b.y) / 2 + ny * off };
      // nearest free spot: slide along the line first, then sideways
      cand = [];
      for (let s = 0; s <= 0.4; s += 0.05) for (const sg of s ? [1, -1] : [1]) for (let o = 0; o <= 160; o += 20) for (const so of o ? [1, -1] : [1])
        cand.push({ x: mid.x + sg * s * dx + so * o * nx, y: mid.y + sg * s * dy + so * o * ny, w: p.w, h: p.h, cost: s * L + o * 1.5 });
      cand.sort((u, v) => u.cost - v.cost);
    }
    const c = cand.find(free) || cand[0];
    pins['r_' + r.name] = { x: c.x, y: c.y, w: p.w, h: p.h }; placed.push(pins['r_' + r.name]);
  });
  // move each diamond, near its spot, to where its lines run over the fewest shapes and the fewest lines run over it
  const relEnds = r => r.ends.map(x => pins['e_' + x.e]);
  const shapesOn = (a, b, skip) => Object.entries(pins).filter(([id, q]) => !skip.has(id) && geom.segHitsBox(a, b, id.startsWith('e_') ? q : { ...q, w: q.w * 0.7, h: q.h * 0.7 })).length;
  for (let pass = 0; pass < 2; pass++) rels.forEach(r => {
    const id = 'r_' + r.name, d0 = pins[id]; const [a, b] = relEnds(r);
    if (a === b) return;
    const skip = new Set([id, ...r.ends.map(x => 'e_' + x.e)]);
    const others = rels.filter(o => o !== r && o.ends[0].e !== o.ends[1].e);
    const cost = d => {
      let c = 0;
      for (const e of [a, b]) c += 60 * shapesOn(e, d, skip);
      for (const o of others) for (const x of o.ends) if (geom.segHitsBox(pins['e_' + x.e], pins['r_' + o.name], { ...d, w: d.w * 0.8, h: d.h * 0.8 })) c += 60;
      return c + Math.hypot(d.x - d0.x, d.y - d0.y) / 4;
    };
    const dx = b.x - a.x, dy = b.y - a.y, L = Math.hypot(dx, dy); const nx = -dy / L, ny = dx / L;
    let best = d0, bc = cost(d0);
    const rest = Object.entries(pins).filter(([k]) => k !== id).map(([, q]) => q);
    for (let s = -0.3; s <= 0.3001; s += 0.075) for (let o = -120; o <= 120; o += 30) {
      const d = { x: d0.x + s * dx + o * nx, y: d0.y + s * dy + o * ny, w: d0.w, h: d0.h };
      if (rest.some(q => hit(d, q))) continue;
      const c = cost(d); if (c < bc - 1e-9) { bc = c; best = d; }
    }
    pins[id] = best;
  });
  // attributes stay off every relationship line; sizes as ERD+ draws them
  const avoid = rels.flatMap(r => r.ends.map(x => [pins['e_' + x.e], pins['r_' + r.name]]));
  const out = placeAttrs(whole, pins, true, 1, { size: opt.attrSize, avoid }).pins;
  // recursive relationships: two (min,max) labels next to the diamond, on free ground
  const labels = {};
  rels.filter(r => r.ends[0].e === r.ends[1].e).forEach(r => {
    const d = out['r_' + r.name], LW = 120, LH = 26;
    const freeL = q => !Object.values(out).some(o => Math.abs(o.x - q.x) < (o.w + q.w) / 2 + 8 && Math.abs(o.y - q.y) < (o.h + q.h) / 2 + 6) && !avoid.some(([p, q2]) => geom.segHitsBox(p, q2, q));
    for (let k = 0; k < 2; k++) {
      let got = null;
      for (let rad = d.w / 2 + LW / 2 + 6; rad < 400 && !got; rad += 12) for (const t of [0, Math.PI, -Math.PI / 2, Math.PI / 2, Math.PI / 4, -Math.PI / 4, 3 * Math.PI / 4, -3 * Math.PI / 4]) {
        const q = { x: d.x + Math.cos(t) * rad, y: d.y + Math.sin(t) * rad * 0.5, w: LW, h: LH };
        if (freeL(q)) { got = q; break; }
      }
      got = got || { x: d.x + d.w, y: d.y - k * 36, w: LW, h: LH };
      labels[`${r.name}_${k}`] = got; out[`l_${r.name}_${k}`] = got;
    }
  });
  Object.keys(out).filter(k => k.startsWith('l_')).forEach(k => { if (!labels[k.slice(2)]) delete out[k]; });
  return { pins: out, labels, cost: cur, grid: { cols: usedC.length, rows: usedR.length } };
}

module.exports = { gridLayout };
