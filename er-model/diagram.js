// Builds Chen (Elmasri-Navathe) ER diagrams per area as DOT, renders with Graphviz (WASM), and themes the SVG.
const C = { ink: '#010203', muted: '#040506', ent: '#0a0b0c', rel: '#0d0e0f', attr: '#101112', ext: '#131415', isa: '#161718', card: '#191a1b' };
const VARS = { [C.ink]: 'var(--er-ink)', [C.muted]: 'var(--er-muted)', [C.ent]: 'var(--er-ent)', [C.rel]: 'var(--er-rel)', [C.attr]: 'var(--er-attr)', [C.ext]: 'var(--er-ext)', [C.isa]: 'var(--er-isa)', [C.card]: 'var(--er-card)' };

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
// 'Name(PartA,PartB)' is a composite attribute; with '_' or '~' in front it is a composite key or partial key
const parseAttr = a => {
  const m = a.match(/^([^(]+)\((.+)\)$/);
  const base = m ? m[1] : a;
  const at = base.startsWith('_') ? { name: base.slice(1), key: true }
    : base.startsWith('~') ? { name: base.slice(1), partial: true }
    : base.startsWith('{') ? { name: base.slice(1, -1), multi: true }
    : base.startsWith('!') ? { name: base.slice(1), unique: true }
    : { name: base };
  if (m) at.parts = m[2].split(',').map(x => x.trim());
  return at;
};

// each specialization keeps one node id (isa_<area>_<n>) in its own area and in the whole-model view
const isaId = (i, k) => i.gid || `isa_${k}`;

function attrLabel(at) {
  if (at.key) return `<<U>${esc(at.name)}</U>>`;
  if (at.unique) return `<<O>${esc(at.name)}</O>>`;
  if (at.partial) return `<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="0" SIDES="B" STYLE="dotted" COLOR="${C.ink}"><TR><TD SIDES="B" STYLE="dotted">${esc(at.name)}</TD></TR></TABLE>>`;
  return `"${esc(at.name)}"`;
}

function buildDot(area, allEntities, full, pins, opt = {}) {
  const pin = id => pins && pins[id] ? `pos="${pins[id]}", pin=true,` : '';
  const home = new Set(area.entities.map(e => e.name));
  const used = new Set();
  area.rels.forEach(r => r.ends.forEach(x => used.add(x.e)));
  (area.isa || []).forEach(i => { used.add(i.sup); i.subs.forEach(s => used.add(s)); });
  const ext = [...used].filter(n => !home.has(n));
  const L = [];
  L.push('graph ER {');
  L.push(`graph [layout=neato, ${opt.gattr || 'overlap=prism, overlap_scaling=-4, sep="+14", mode=major'}, splines=true, bgcolor=transparent, pad=0.2, esep="+8", start=${opt.start || 7}];`);
  L.push(`node [fontname="Helvetica", fontsize=12, color="${C.ink}", fontcolor="${C.ink}", penwidth=1.1];`);
  L.push(`edge [color="${C.ink}", fontname="Helvetica", fontsize=12, fontcolor="${C.card}", penwidth=1.1, len=1.3];`);
  const ent = (name, isExt) => {
    const e = allEntities.get(name);
    const weak = e && e.weak;
    L.push(`"e_${name}" [${pin('e_' + name)} shape=box, style="${isExt ? 'filled,dashed' : 'filled'}", fillcolor="${isExt ? C.ext : C.ent}", ${isExt ? `fontcolor="${C.muted}", color="${C.muted}",` : ''} peripheries=${weak ? 2 : 1}, margin="0.14,0.08", fontname="Helvetica-Bold", label="${name}", href="#e-${name}", tooltip="${name}${isExt ? ' (ορίζεται σε άλλη περιοχή)' : ''}"];`);
  };
  area.entities.forEach(e => ent(e.name, false));
  ext.forEach(n => ent(n, true));
  // attributes
  let ai = 0;
  const showAttr = at => full || at.key || at.partial || at.unique;
  area.entities.forEach(e => {
    e.attrs.map(parseAttr).filter(showAttr).forEach(at => {
      const id = `a_${e.name}_${at.name}`;
      L.push(`"${id}" [${pin(id)} shape=ellipse, style=filled, fillcolor="${C.attr}", fontsize=11, margin="0.04,0.02", peripheries=${at.multi ? 2 : 1}, label=${attrLabel(at)}];`);
      L.push(`"e_${e.name}" -- "${id}" [len=${full ? 0.75 : 0.85}, weight=6];`);
      (at.parts || []).forEach(p => {
        L.push(`"${id}_${p}" [${pin(id + '_' + p)} shape=ellipse, style=filled, fillcolor="${C.attr}", fontsize=10.5, margin="0.04,0.02", label="${esc(p)}"];`);
        L.push(`"${id}" -- "${id}_${p}" [len=0.6];`);
      });
    });
  });
  // ISA
  (area.isa || []).forEach((i, k) => {
    const id = isaId(i, k);
    L.push(`"${id}" [${pin(id)} shape=circle, style=filled, fillcolor="${C.isa}", width=0.36, fixedsize=true, fontsize=13, fontname="Helvetica-Bold", label="${i.kind}", href="#${id.replace(/_/g, '-')}", tooltip="Εξειδίκευση του ${i.sup}"];`);
    L.push(`"e_${i.sup}" -- "${id}" [${i.total ? `color="${C.ink}:invis:${C.ink}",` : ''} ${i.attr ? `label="${i.attr}", fontsize=10, fontcolor="${C.ink}",` : ''} len=1.0];`);
    i.subs.forEach(s => L.push(`"${id}" -- "e_${s}" [label="⊂", fontsize=14, len=1.2];`));
  });
  // relationships
  area.rels.forEach(r => {
    const rid = `r_${r.name}`;
    L.push(`"${rid}" [${pin(rid)} shape=diamond, style=filled, fillcolor="${C.rel}", peripheries=${r.ident ? 2 : 1}, fontsize=10.5, margin="0.02,0.02", label="${r.name}", href="#r-${r.name}", tooltip="${r.name}"];`);
    const recursive = r.ends.length === 2 && r.ends[0].e === r.ends[1].e;
    r.ends.forEach((x, k) => {
      // role names go on a second, smaller line; recursive ends put their label next to the diamond corner so the two never collide
      const lab = x.role ? `<${esc(x.card)}<BR/><FONT POINT-SIZE="10">${esc(x.role)}</FONT>>` : `"${esc(x.card)}"`;
      const rp = (opt.recPorts && opt.recPorts[r.name]) || { tail: ['nw', 'ne'], head: ['w', 'e'] };
      const where = recursive ? `label=${lab}, tailport=${rp.tail[k]}, headport=${rp.head[k]},` : `label=${lab},`;
            const col = opt.cross && opt.cross(x.e, r.name) ? C.muted : C.ink; // whole-model view: lines between areas are drawn lighter
      L.push(`"e_${x.e}" -- "${rid}" [${where} ${x.total ? `color="${col}:invis:${col}", penwidth=1.0,` : `color="${col}",`} fontname="Helvetica-Bold", len=${full ? 1.7 : (opt.rlen || 1.3)}];`);
    });
    if (full) (r.attrs || []).forEach(a => {
      const id = `a_${r.name}_${a}`;
      L.push(`"${id}" [${pin(id)} shape=ellipse, style=filled, fillcolor="${C.attr}", fontsize=11, margin="0.04,0.02", label="${esc(a)}"];`);
      L.push(`"${rid}" -- "${id}" [len=0.8];`);
    });
  });
  // invisible pinned points that stretch the drawing (used for the area frames of the whole-model view)
  (opt.extra || []).forEach(n => L.push(`"${n.id}" [shape=point, style=invis, width=0.01, height=0.01, label="", pos="${(n.x / 72).toFixed(3)},${(n.y / 72).toFixed(3)}!", pin=true];`));
  L.push('}');
  return L.join('\n');
}

function themeSvg(svg, prefix) {
  svg = svg.replace(/^[\s\S]*?(<svg)/, '$1');
  svg = svg.replace(/<!--[\s\S]*?-->/g, '');
  const m = svg.match(/<svg[^>]*\swidth="([\d.]+)pt"[^>]*\sheight="([\d.]+)pt"/);
  const w = m ? Math.round(parseFloat(m[1]) * 4 / 3) : 800;
  const h = m ? Math.round(parseFloat(m[2]) * 4 / 3) : 600;
  svg = svg.replace(/(<svg[^>]*?)\swidth="[^"]*"/, '$1').replace(/(<svg[^>]*?)\sheight="[^"]*"/, '$1');
  svg = svg.replace('<svg', `<svg class="er-svg" data-w="${w}" role="img"`);
  // colours -> theme variables via inline style
  svg = svg.replace(/<(polygon|ellipse|path|polyline|text|rect)\b([^>]*?)(\/?)>/g, (all, tag, attrs, close) => {
    let style = [];
    attrs = attrs.replace(/\s(fill|stroke)="([^"]*)"/g, (a, prop, val) => {
      const v = VARS[val.toLowerCase()];
      if (v) { style.push(`${prop}:${v}`); return ''; }
      return a;
    });
    if (style.length) attrs += ` style="${style.join(';')}"`;
    return `<${tag}${attrs}${close}>`;
  });
  svg = svg.replace(/\sid="([^"]+)"/g, (a, id) => ` id="${prefix}-${id}"`);
  svg = svg.replace(/<title>[^<]*<\/title>/g, '');
  return { svg, w, h };
}

module.exports = { buildDot, themeSvg, parseAttr };

// ---------- Two-pass layout: neato places entities + relationships, then attributes are fanned out around their entity ----------
function parsePositions(dotOut) {
  const pos = {};
  const re = /(?:^|\n)\s*"?([A-Za-z0-9_]+)"?\s*\[([^\]]*?)\]/g; let m;
  while ((m = re.exec(dotOut))) {
    if (/^(graph|node|edge)$/.test(m[1])) continue;
    const pm = m[2].match(/(?:^|[\s,])pos="([\d.\-]+),([\d.\-]+)"/);
    const wm = m[2].match(/(?:^|[\s,])width="?([\d.]+)/), hm = m[2].match(/(?:^|[\s,])height="?([\d.]+)/);
    if (pm) pos[m[1]] = { x: +pm[1], y: +pm[2], w: wm ? +wm[1] * 72 : 60, h: hm ? +hm[1] * 72 : 30 };
  }
  return pos;
}

// Straight-line approximations used to score a candidate layout.
const segHitsBox = (a, b, o) => {
  // Liang-Barsky clip of segment a-b against box o (shrunk a little)
  const x0 = o.x - o.w / 2 + 3, x1 = o.x + o.w / 2 - 3, y0 = o.y - o.h / 2 + 3, y1 = o.y + o.h / 2 - 3;
  let t0 = 0, t1 = 1; const dx = b.x - a.x, dy = b.y - a.y;
  for (const [pp, qq] of [[-dx, a.x - x0], [dx, x1 - a.x], [-dy, a.y - y0], [dy, y1 - a.y]]) {
    if (pp === 0) { if (qq < 0) return false; continue; }
    const t = qq / pp;
    if (pp < 0) { if (t > t1) return false; if (t > t0) t0 = t; } else { if (t < t0) return false; if (t < t1) t1 = t; }
  }
  return t0 < t1;
};
const cross = (a, b, c, d) => {
  const o = (p, q, r) => Math.sign((q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x));
  return o(a, b, c) * o(a, b, d) < 0 && o(c, d, a) * o(c, d, b) < 0;
};

function neighboursOf(area) {
  const neighbours = {};
  const link = (a, b) => { (neighbours[a] = neighbours[a] || []).push(b); (neighbours[b] = neighbours[b] || []).push(a); };
  area.rels.forEach(r => r.ends.forEach(x => link('e_' + x.e, 'r_' + r.name)));
  (area.isa || []).forEach((i, k) => { link('e_' + i.sup, isaId(i, k)); i.subs.forEach(s => link('e_' + s, isaId(i, k))); });
  return neighbours;
}

// pass 2: fan attributes out into the free arcs around their owner (P = structure positions, scaled by S)
// opt (ERD+ file only): size(name) for attribute boxes, avoid = segments [a, b] that attributes must not sit on
function placeAttrs(area, P, full, S, opt = {}) {
    const aSize = opt.size || (name => ({ w: name.length * 6.3 + 26, h: 25 }));
    const onLine = b => (opt.avoid || []).some(([p, q]) => segHitsBox(p, q, b));
    const neighbours = neighboursOf(area);
    const pins = {}; const boxes = [];
    for (const [id, p] of Object.entries(P)) pins[id] = { x: p.x * S, y: p.y * S, w: p.w, h: p.h };
    // a recursive diamond needs room for two labelled lines between it and its entity
    area.rels.filter(r => r.ends[0].e === r.ends[1].e).forEach(r => {
      const d = pins['r_' + r.name], e = pins['e_' + r.ends[0].e];
      const dx = d.x - e.x, dy = d.y - e.y, dist = Math.hypot(dx, dy) || 1;
      const need = Math.abs(dx) / dist * (e.w / 2 + d.w / 2) + Math.abs(dy) / dist * (e.h / 2 + d.h / 2) + 80;
      if (dist < need) { d.x = e.x + dx / dist * need; d.y = e.y + dy / dist * need; }
    });
    for (const [id, p] of Object.entries(pins)) boxes.push({ id, ...p });
    // keep attributes off the role labels of a recursive relationship (they sit halfway along its two lines)
    area.rels.filter(r => r.ends[0].e === r.ends[1].e).forEach(r => {
      const d = pins['r_' + r.name], e = pins['e_' + r.ends[0].e];
      const dx = d.x - e.x, dy = d.y - e.y;
      const segs = Math.abs(dx) > Math.abs(dy)
        ? [[e.x + Math.sign(dx) * e.w / 2, e.y + e.h / 2, d.x, d.y + d.h / 2], [e.x + Math.sign(dx) * e.w / 2, e.y - e.h / 2, d.x, d.y - d.h / 2]]
        : [[e.x - e.w / 2, e.y + Math.sign(dy) * e.h / 2, d.x - d.w / 2, d.y], [e.x + e.w / 2, e.y + Math.sign(dy) * e.h / 2, d.x + d.w / 2, d.y]];
      segs.forEach(([x1, y1, x2, y2], k) => boxes.push({ id: `l_${r.name}_${k}`, x: (x1 + x2) / 2, y: (y1 + y2) / 2, w: 120, h: 40 }));
    });
    const overlaps = (b) => boxes.some(o => o.id !== b.id && Math.abs(o.x - b.x) < (o.w + b.w) / 2 + 6 && Math.abs(o.y - b.y) < (o.h + b.h) / 2 + 4);
    const edges = [];
    area.rels.forEach(r => r.ends.forEach(x => edges.push(['e_' + x.e, 'r_' + r.name])));
    (area.isa || []).forEach((i, k) => { edges.push(['e_' + i.sup, isaId(i, k)]); i.subs.forEach(s => edges.push([isaId(i, k), 'e_' + s])); });
    const place = (ownerId, list) => {
      if (!list.length) return;
      const c = pins[ownerId];
      const nb = (neighbours[ownerId] || []).filter(n => pins[n]).map(n => Math.atan2(pins[n].y - c.y, pins[n].x - c.x)).sort((a, b) => a - b);
      let arcs = [];
      if (!nb.length) arcs = [{ a: 0, len: 2 * Math.PI, full: true }];
      else nb.forEach((a, i) => { const b = i + 1 < nb.length ? nb[i + 1] : nb[0] + 2 * Math.PI; arcs.push({ a, len: b - a }); });
      const margin = 0.42;
      const usable = arcs.map(r => ({ ...r, use: r.full ? r.len : Math.max(0, r.len - 2 * margin) }));
      const total = usable.reduce((s, r) => s + r.use, 0) || 1;
      const share = usable.map(r => ({ ...r, n: Math.floor(list.length * r.use / total), rem: (list.length * r.use / total) % 1 }));
      let left = list.length - share.reduce((s, r) => s + r.n, 0);
      [...share].sort((a, b) => b.rem - a.rem).forEach(r => { if (left > 0) { r.n++; left--; } });
      const angles = [];
      share.forEach(r => { for (let i = 0; i < r.n; i++) angles.push(r.full ? r.a + (i + 0.5) * r.len / r.n : r.a + margin + (i + 0.5) * r.use / r.n); });
      list.forEach((at, i) => {
        const id = at.id; const { w, h } = aSize(at.name);
        const t = angles[i];
        const rx = Math.abs(Math.cos(t)) * (c.w / 2 + w / 2) + Math.abs(Math.sin(t)) * (c.h / 2 + h / 2);
        let r = rx + 16 + (list.length > 5 && i % 2 ? 26 : 0);
        // nearest free spot: grow the radius, and at each radius try small turns either way;
        // a spot is free when the ellipse overlaps nothing and its line to the owner crosses no other shape
        const lineFree = (b) => !boxes.some(o => o.id !== ownerId && segHitsBox(c, b, o.id.startsWith('e_') ? o : { ...o, w: o.w * 0.7, h: o.h * 0.7 }));
        let b = null, first = null;
        search: for (let k = 0; k < 30; k++) {
          for (const dt of [0, 0.12, -0.12, 0.24, -0.24, 0.36, -0.36]) {
            const cand = { id, x: c.x + Math.cos(t + dt) * r, y: c.y + Math.sin(t + dt) * r, w, h };
            if (overlaps(cand)) continue;
            if (!first) first = cand;
            if (lineFree(cand) && !onLine(cand)) { b = cand; break search; }
          }
          r += 8;
        }
        b = b || first || { id, x: c.x + Math.cos(t) * r, y: c.y + Math.sin(t) * r, w, h };
        pins[id] = b; boxes.push(b); edges.push([ownerId, id]);
      });
    };
    area.entities.forEach(e => {
      const list = e.attrs.map(parseAttr).filter(at => full || at.key || at.partial || at.unique).map(at => ({ ...at, id: `a_${e.name}_${at.name}` }));
      place('e_' + e.name, list);
      // parts of a composite attribute sit just beyond it, on the side away from the entity
      list.filter(at => at.parts).forEach(at => {
        const c = pins[at.id], o = pins['e_' + e.name];
        const t0 = Math.atan2(c.y - o.y, c.x - o.x);
        at.parts.forEach((name, i) => {
          const id = `${at.id}_${name}`, { w, h } = aSize(name);
          const base = t0 + (i - (at.parts.length - 1) / 2) * 1.1;
          let b = null, first = null;
          search: for (let r = 0; r < 240; r += 8) for (const dt of [0, 0.2, -0.2, 0.4, -0.4, 0.6, -0.6]) {
            const t = base + dt;
            const d = Math.abs(Math.cos(t)) * (c.w / 2 + w / 2) + Math.abs(Math.sin(t)) * (c.h / 2 + h / 2) + 8 + r;
            const cand = { id, x: c.x + Math.cos(t) * d, y: c.y + Math.sin(t) * d, w, h };
            if (overlaps(cand)) continue;
            if (!first) first = cand;
            if (!boxes.some(q => q.id !== at.id && segHitsBox(c, cand, q.id.startsWith('e_') ? q : { ...q, w: q.w * 0.7, h: q.h * 0.7 })) && !onLine(cand)) { b = cand; break search; }
          }
          b = b || first || { id, x: c.x + Math.cos(base) * 60, y: c.y + Math.sin(base) * 60, w, h };
          pins[id] = b; boxes.push(b); edges.push([at.id, id]);
        });
      });
    });
    if (full) area.rels.forEach(r => place('r_' + r.name, (r.attrs || []).map(a => ({ name: a, id: `a_${r.name}_${a}` }))));
    return { pins, edges };
}

function layoutArea(viz, area, allEntities) {
  (area.isa || []).forEach((i, k) => { i.gid = i.gid || `isa_${area.id}_${k}`; });
  const structArea = { ...area, entities: area.entities.map(e => ({ ...e, attrs: [] })), rels: area.rels.map(r => ({ ...r, attrs: [] })) };

  const placeAll = (P, full, S) => placeAttrs(area, P, full, S);

  const score = ({ pins, edges }) => {
    let hits = 0, crossings = 0;
    const ids = Object.keys(pins);
    for (const [u, v] of edges) {
      const a = pins[u], b = pins[v];
      for (const id of ids) { if (id === u || id === v) continue; const o = pins[id]; const sh = id.startsWith('e_') ? o : { ...o, w: o.w * 0.7, h: o.h * 0.7 }; if (segHitsBox(a, b, sh)) hits++; }
    }
    for (let i = 0; i < edges.length; i++) for (let j = i + 1; j < edges.length; j++) {
      const [a, b] = edges[i], [c, d] = edges[j];
      if (a === c || a === d || b === c || b === d) continue;
      if (cross(pins[a], pins[b], pins[c], pins[d])) crossings++;
    }
    // shapes drawn on top of each other (two diamonds, a label box) are worse than any crossing
    let clash = 0;
    for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
      const a = pins[ids[i]], b = pins[ids[j]];
      if (Math.abs(a.x - b.x) < (a.w + b.w) / 2 - 2 && Math.abs(a.y - b.y) < (a.h + b.h) / 2 - 2) clash++;
    }
    const xs = ids.map(id => pins[id].x), ys = ids.map(id => pins[id].y);
    const w = Math.max(...xs) - Math.min(...xs) + 150, h = Math.max(...ys) - Math.min(...ys) + 60;
    return { s: 1000 * clash + 400 * hits + 60 * crossings + (w * h) / 10000 + Math.max(0, w - 1000) / 2, hits, crossings, clash, w: Math.round(w), h: Math.round(h) };
  };

  const CONFIGS = [
    { gattr: 'overlap=prism, overlap_scaling=-4, sep="+14", mode=major', rlen: 1.3, S: [1.25], SF: [1.6, 1.75, 2.0] },
    { gattr: 'overlap=prism, overlap_scaling=-2, sep="+8", mode=major', rlen: 1.0, S: [1.0, 1.15], SF: [1.35, 1.55, 1.8] },
    { gattr: 'overlap=prism, overlap_scaling=0, sep="+8", mode=major', rlen: 0.9, S: [1.0, 1.15], SF: [1.35, 1.55, 1.8] }
  ];
  const STARTS = [7, 3, 11, 19, 23];
  const best = { keys: null, full: null };
  for (const cfg of CONFIGS) for (const start of STARTS) {
    const P = parsePositions(viz.renderString(buildDot(structArea, allEntities, false, null, { ...cfg, start }), { format: 'dot' }));
    for (const [view, scales] of [['keys', cfg.S], ['full', cfg.SF]]) for (const S of scales) {
      const placed = placeAll(P, view === 'full', S);
      const sc = score(placed);
      if (!best[view] || sc.s < best[view].sc.s) best[view] = { sc, placed, cfg, start };
    }
  }
  if (process.env.ER_DEBUG) console.error(area.id, 'keys', JSON.stringify(best.keys.sc), 'full', JSON.stringify(best.full.sc));
  const out = {};
  for (const view of ['keys', 'full']) out[view] = renderPinned(viz, area, allEntities, view === 'full', best[view].placed.pins, { ...best[view].cfg, start: best[view].start });
  out.pins = { keys: best.keys.placed.pins, full: best.full.placed.pins };
  return out;
}

function renderPinned(viz, area, allEntities, full, pins, opt) {
  const pinStr = {};
  for (const [id, p] of Object.entries(pins)) pinStr[id] = `${(p.x / 72).toFixed(3)},${(p.y / 72).toFixed(3)}!`;
  // recursive relationships: attach the two lines to opposite corners facing away from the entity's side
  const recPorts = {};
  area.rels.filter(r => r.ends[0].e === r.ends[1].e).forEach(r => {
    const d = pins['r_' + r.name], e = pins['e_' + r.ends[0].e];
    const dx = d.x - e.x, dy = d.y - e.y; // graphviz y axis points up
    recPorts[r.name] = Math.abs(dx) > Math.abs(dy)
      ? { tail: dx < 0 ? ['nw', 'sw'] : ['ne', 'se'], head: ['n', 's'] }
      : { tail: dy > 0 ? ['nw', 'ne'] : ['sw', 'se'], head: ['w', 'e'] };
  });
  return viz.renderString(buildDot(area, allEntities, full, pinStr, { ...opt, recPorts }), { format: 'svg' });
}

// One diagram for the whole model: each area keeps its own layout as a block (without the dashed copies of
// entities from other areas), blocks go on a 3x3 grid chosen so that areas sharing relationships sit close.
function layoutWhole(viz, areas, allEntities, perArea) {
  const homeOf = new Map(); areas.forEach(a => a.entities.forEach(e => homeOf.set(e.name, a.id)));
  const ids = areas.map(a => a.id);
  const w = {}; ids.forEach(x => ids.forEach(y => { w[x + '|' + y] = 0; }));
  areas.forEach(a => a.rels.forEach(r => r.ends.forEach(x => { const h = homeOf.get(x.e); if (h !== a.id) { w[a.id + '|' + h]++; w[h + '|' + a.id]++; } })));
  // best assignment of areas to grid cells (brute force over permutations)
  const cells = [...Array(9).keys()].map(i => ({ r: Math.floor(i / 3), c: i % 3 }));
  let bestPerm = null, bestCost = Infinity;
  const perm = [...ids.keys()];
  const cost = p => { let s = 0; for (let i = 0; i < 9; i++) for (let j = i + 1; j < 9; j++) { const k = w[ids[i] + '|' + ids[j]]; if (k) { const a = cells[p[i]], b = cells[p[j]]; s += k * Math.hypot(a.r - b.r, a.c - b.c); } } return s; };
  const permute = (k) => { if (k === 9) { const c = cost(perm); if (c < bestCost) { bestCost = c; bestPerm = [...perm]; } return; } for (let i = k; i < 9; i++) { [perm[k], perm[i]] = [perm[i], perm[k]]; permute(k + 1); [perm[k], perm[i]] = [perm[i], perm[k]]; } };
  permute(0);
  const whole = { id: 'all', entities: areas.flatMap(a => a.entities), rels: areas.flatMap(a => a.rels), isa: areas.flatMap(a => a.isa || []) };
  const make = (view) => {
    const blocks = areas.map((a, i) => {
      const home = new Set(a.entities.map(e => 'e_' + e.name));
      // areas that many other areas connect to get more room, so the incoming lines do not run over their shapes
      const incoming = areas.reduce((n, o) => n + (o.id === a.id ? 0 : w[a.id + '|' + o.id]), 0);
      const k = 1 + Math.min(0.7, incoming / 40);
      const pins = Object.fromEntries(Object.entries(perArea[a.id].pins[view]).filter(([id]) => !id.startsWith('e_') || home.has(id)).map(([id, p]) => [id, { ...p, x: p.x * k, y: p.y * k }]));
      const xs = Object.values(pins), x0 = Math.min(...xs.map(p => p.x - p.w / 2)), x1 = Math.max(...xs.map(p => p.x + p.w / 2)), y0 = Math.min(...xs.map(p => p.y - p.h / 2)), y1 = Math.max(...xs.map(p => p.y + p.h / 2));
      return { a, cell: cells[bestPerm[i]], pins, x0, x1, y0, y1, w: x1 - x0, h: y1 - y0 };
    });
    const GAP = 150, PADB = 36, TITLE = 40;
    const colW = [0, 1, 2].map(c => Math.max(...blocks.filter(b => b.cell.c === c).map(b => b.w)) + 2 * PADB);
    const rowH = [0, 1, 2].map(r => Math.max(...blocks.filter(b => b.cell.r === r).map(b => b.h)) + 2 * PADB + TITLE);
    const pins = {}; const frames = [];
    blocks.forEach(b => {
      const cx = colW.slice(0, b.cell.c).reduce((s, v) => s + v + GAP, 0) + colW[b.cell.c] / 2;
      const top = -rowH.slice(0, b.cell.r).reduce((s, v) => s + v + GAP, 0); // y up: rows go downwards
      const cy = top - TITLE - rowH[b.cell.r] / 2 + TITLE / 2;
      const dx = cx - (b.x0 + b.x1) / 2, dy = cy - (b.y0 + b.y1) / 2;
      for (const [id, p] of Object.entries(b.pins)) pins[id] = { ...p, x: p.x + dx, y: p.y + dy };
      frames.push({ title: b.a.title, no: areas.indexOf(b.a) + 1, x0: b.x0 + dx - PADB, x1: b.x1 + dx + PADB, y0: b.y0 + dy - PADB, y1: b.y1 + dy + PADB + TITLE });
    });

    // attributes are placed again for the whole drawing, so they avoid the lines coming in from other areas
    const struct = Object.fromEntries(Object.entries(pins).filter(([id]) => !id.startsWith('a_')));
    Object.assign(pins, Object.fromEntries(Object.entries(placeAttrs(whole, struct, view === 'full', 1).pins).filter(([id]) => id.startsWith('a_'))));
    // frames follow the final positions of each area's shapes
    frames.length = 0;
    areas.forEach((a, n) => {
      const own = new Set([...a.entities.map(e => 'e_' + e.name), ...a.rels.map(r => 'r_' + r.name), ...(a.isa || []).map((i, k) => isaId(i, k)),
        ...a.entities.flatMap(e => e.attrs.flatMap(x => { const at = parseAttr(x); const id = `a_${e.name}_${at.name}`; return [id, ...(at.parts || []).map(p => `${id}_${p}`)]; })), ...a.rels.flatMap(r => (r.attrs || []).map(x => `a_${r.name}_${x}`))]);
      const mine = Object.entries(pins).filter(([id]) => own.has(id)).map(([, p]) => p);
      frames.push({ title: a.title, no: n + 1,
        x0: Math.min(...mine.map(p => p.x - p.w / 2)) - PADB, x1: Math.max(...mine.map(p => p.x + p.w / 2)) + PADB,
        y0: Math.min(...mine.map(p => p.y - p.h / 2)) - PADB, y1: Math.max(...mine.map(p => p.y + p.h / 2)) + PADB + TITLE });
    });
    const relArea = new Map(); areas.forEach(a => a.rels.forEach(r => relArea.set(r.name, a.id)));
    layoutWhole.pins = layoutWhole.pins || {}; layoutWhole.pins[view] = pins; // final positions, read by the ERD+ file export
    let svg = renderPinned(viz, whole, allEntities, view === 'full', pins, { gattr: 'overlap=true', start: 7, cross: (e, r) => homeOf.get(e) !== relArea.get(r),
      extra: frames.flatMap(f => [{ id: `fr${f.no}a`, x: f.x0, y: f.y0 }, { id: `fr${f.no}b`, x: f.x1, y: f.y1 }]) });
    // draw the area frames behind everything: find the svg offset from one known entity
    const m = svg.match(/<title>e_PREMISE<\/title>\s*(?:<g[^>]*>\s*<a[^>]*>\s*)?<polygon[^>]*points="([^"]+)"/);
    const pts = m[1].trim().split(/\s+/).map(t => t.split(',').map(Number));
    const sx = (Math.min(...pts.map(q => q[0])) + Math.max(...pts.map(q => q[0]))) / 2, sy = (Math.min(...pts.map(q => q[1])) + Math.max(...pts.map(q => q[1]))) / 2;
    const ox = sx - pins.e_PREMISE.x, oy = sy + pins.e_PREMISE.y;
    const rects = frames.map(f => `<rect x="${(f.x0 + ox).toFixed(1)}" y="${(-f.y1 + oy).toFixed(1)}" width="${(f.x1 - f.x0).toFixed(1)}" height="${(f.y1 - f.y0).toFixed(1)}" rx="14" fill="${C.ext}" fill-opacity="0.35" stroke="${C.muted}" stroke-dasharray="8 6"/>` +
      `<text x="${(f.x0 + ox + 18).toFixed(1)}" y="${(-f.y1 + oy + 32).toFixed(1)}" font-family="Helvetica,Arial,sans-serif" font-weight="700" font-size="22" fill="${C.muted}">${f.no}. ${f.title.replace(/&/g, '&amp;')}</text>`).join('');
    svg = svg.replace(/(<g id="graph0" class="graph"[^>]*>\s*(?:<title>[^<]*<\/title>\s*)?(?:<polygon[^>]*\/>)?)/, `$1${rects}`);
    return svg;
  };
  return { keys: make('keys'), full: make('full') };
}

module.exports.layoutWhole = layoutWhole;
module.exports.layoutArea = layoutArea;
// used by the ERD+ file export to lay out the whole model in one piece
module.exports.placeAttrs = placeAttrs;
module.exports.parsePositions = parsePositions;
module.exports.geom = { segHitsBox, cross };
