// checks that the drawn whole diagram (the DOT fed to graphviz) matches the model, end by end
const { instance } = require('@viz-js/viz');
const { areas } = require('./model.js');
const { layoutArea, layoutWhole } = require('./diagram.js');
const allEntities = new Map(); areas.forEach(a => a.entities.forEach(e => allEntities.set(e.name, { ...e, area: a.id })));
instance().then(viz => {
  const per = {}; for (const a of areas) per[a.id] = layoutArea(viz, a, allEntities);
  const dots = []; const orig = viz.renderString.bind(viz);
  viz.renderString = (dot, o) => { dots.push(dot); return orig(dot, o); };
  layoutWhole(viz, areas, allEntities, per);
  for (const [vi, dot] of dots.entries()) {
    let problems = 0, ends = 0;
    const edges = [...dot.matchAll(/"e_([A-Z_]+)" -- "r_([A-Z_]+)" \[([^\]]*)\]/g)].map(m => ({ e: m[1], r: m[2], a: m[3] }));
    for (const a of areas) for (const r of a.rels) {
      const mine = edges.filter(x => x.r === r.name);
      if (mine.length !== r.ends.length) { console.log('edge count', r.name, mine.length, r.ends.length); problems++; }
      r.ends.forEach((x, k) => {
        ends++;
        const cand = mine.filter(m => m.e === x.e);
        const ok = cand.some(m => { const lab = (m.a.match(/label=(<[^>]*?>|"[^"]*")/) || [])[1] || ''; const lc = lab.replace(/<BR\/>.*$/, '').replace(/^[<"]/, '').replace(/["]$/, ''); const dbl = /:invis:/.test(m.a); return lc === x.card && dbl === x.total; });
        if (!ok) { console.log('mismatch', r.name, x.e, x.card, x.total, cand.map(c => c.a.slice(0, 80))); problems++; }
      });
    }
    const isaEdges = [...dot.matchAll(/"(e_[A-Z_]+|isa_[a-z]+_\d+)" -- "(isa_[a-z]+_\d+|e_[A-Z_]+)" \[([^\]]*)\]/g)];
    areas.flatMap(a => a.isa || []).forEach((i, k) => {
      const up = isaEdges.find(m => m[1] === 'e_' + i.sup && m[2] === i.gid);
      if (!up || /:invis:/.test(up[3]) !== i.total || (i.attr && !up[3].includes(`label="${i.attr}"`))) { console.log('isa mismatch', i.sup); problems++; }
      i.subs.forEach(sub => { if (!isaEdges.some(m => m[1] === i.gid && m[2] === 'e_' + sub)) { console.log('isa sub missing', sub); problems++; } });
    });
    console.log('view', vi, 'rel ends checked', ends, 'problems', problems, 'isa edges', isaEdges.length, 'problems after isa', problems, 'entities drawn', new Set([...dot.matchAll(/^"e_([A-Z_]+)" \[/gm)].map(m => m[1])).size);
  }
});
