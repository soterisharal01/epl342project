// Simulates ERD+ "Convert to Relational Schema" column naming (logic read from the ERD+ converter) to find clashing column names.
const { areas } = require('./model.js');
const ents = {}, rels = [], isas = [];
for (const a of areas) { for (const e of a.entities) ents[e.name] = e; rels.push(...a.rels); isas.push(...(a.isa || [])); }
const tables = {}; const hist = {};
const parse = s => { const m = s.match(/^([_~!]?)\{?([A-Za-z0-9]+)(?:\(([^)]*)\))?\}?$/); return { mark: m[1], name: m[2], parts: m[3] ? m[3].split(',') : null, multi: s.includes('{') }; };
for (const [n, e] of Object.entries(ents)) {
  const cols = [];
  for (const a of e.attrs) { const p = parse(a); if (p.multi) continue; if (p.parts) p.parts.forEach(x => cols.push({ name: x, pk: p.mark === '~' })); else cols.push({ name: p.name, pk: p.mark === '_' || p.mark === '~' }); }
  // ERD+ PK = first Unique ending in ID; our '_' is that one
  tables[n] = { cols };
}
const connect = (pkT, fkT, rel, pk) => {
  const k = pkT + '>' + fkT; hist[k] = (hist[k] || 0) + 1;
  let names = tables[pkT].cols.filter(c => c.pk).map(c => c.name);
  if (hist[k] > 1) names = names.map(x => rel + x);
  names.forEach(x => tables[fkT].cols.push({ name: x, pk, fk: pkT, rel }));
};
for (const i of isas) for (const s of i.subs) connect(i.sup, s, 'isa', true);
const one = r => r.ends.length === 2 && r.ends[0].e !== r.ends[1].e;
const ordered = [...rels.filter(r => one(r) && r.ident), ...rels.filter(r => one(r) && !r.ident)];
for (const r of ordered) {
  const [a, b] = r.ends; const ca = a.card === '1', cb = b.card === '1';
  if (ca && cb) { const fkSide = b.total ? b : a.total ? a : b; const pkSide = fkSide === a ? b : a; connect(pkSide.e, fkSide.e, r.name, !!r.ident); }
  else if (ca && !cb) connect(a.e, b.e, r.name, !!r.ident);
  else if (!ca && cb) connect(b.e, a.e, r.name, !!r.ident);
  else { tables[r.name] = { cols: [] }; connect(a.e, r.name, r.name, true); connect(b.e, r.name, r.name, true); }
}
for (const r of rels.filter(r => !one(r))) {
  const k = r.ends[0].e; const names = tables[k].cols.filter(c => c.pk).map(c => r.name + '_' + c.name);
  names.forEach(x => tables[k].cols.push({ name: x, fk: k, rel: r.name }));
}
let n = 0;
for (const [t, { cols }] of Object.entries(tables)) {
  const cnt = {}; cols.forEach(c => cnt[c.name] = (cnt[c.name] || 0) + 1);
  const d = Object.keys(cnt).filter(x => cnt[x] > 1);
  if (d.length) { n++; console.log(t + ':', cols.filter(c => d.includes(c.name) || /^[A-Z_]+[A-Z][a-z]/.test(c.name) && c.rel).map(c => `${c.name}${c.fk ? ' <- ' + c.rel + ' (' + c.fk + ')' : ' (own)'}`).join(' | ')); }
}
// also show auto-prefixed names
for (const [t, { cols }] of Object.entries(tables)) cols.filter(c => c.rel && c.rel !== 'isa' && c.name.startsWith(c.rel)).forEach(c => console.log('prefixed', t, c.name));
console.log('tables with clashes:', n);
