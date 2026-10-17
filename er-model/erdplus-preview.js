// Draws an .erdplus file as an SVG the way ERD+ places it (x, y = top-left corner), with estimated
// ERD+ shape sizes, and counts shapes that would overlap. Used to check the export before importing it.
const fs = require('fs');
const path = require('path');
const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const FILE = args[0] || path.join(__dirname, 'mdms-er.erdplus');
const OUT = args[1] || FILE.replace(/\.erdplus$/, process.argv.includes('--card') ? '-card.svg' : '-preview.svg');
const doc = JSON.parse(fs.readFileSync(FILE, 'utf8'));
const CH = 7.5; // px per character at the ERD+ font size (estimate)
// anchor: the size the export assumed when it turned centres into top-left corners (erdplus-export.js ERD)
const anchor = s => {
  const d = s.details, n = (d.name || '').length;
  if (s.type === 'Entity') return { w: 100, h: 45 };
  if (s.type === 'Relationship') return { w: 100, h: 50 };
  if (s.type === 'Attribute') return { w: Math.max(76, n * 6.5 + 30), h: 36 };
  return { w: d.width, h: d.height };
};
// drawn: at least the anchor size, wider when the name needs it (long names overflow ERD+'s fixed boxes)
const size = s => {
  const d = s.details, n = (d.name || '').length, a = anchor(s);
  if (s.type === 'Entity') return { w: Math.max(a.w, n * CH + 20), h: a.h };
  if (s.type === 'Relationship') return { w: Math.max(a.w, n * CH + 40), h: a.h + 10 };
  if (s.type === 'Attribute') return { w: Math.max(a.w, n * CH + 24), h: a.h };
  return a;
};
const box = new Map(doc.shapes.map(s => { const a = anchor(s), z = size(s); const cx = s.details.x + a.w / 2, cy = s.details.y + a.h / 2; return [s.details.id, { s, ...z, x: cx - z.w / 2, y: cy - z.h / 2, cx, cy }]; }));
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const parts = [];
for (const c of doc.connectors) {
  const a = box.get(c.source), b = box.get(c.destination);
  parts.push(`<line x1="${a.cx}" y1="${a.cy}" x2="${b.cx}" y2="${b.cy}" stroke="#555" stroke-width="1.2"/>`);
}
const weakOwners = new Set(doc.shapes.filter(s => s.type === 'Entity' && s.details.type === 'weak').map(s => s.details.id));
const attrOwner = new Map(doc.connectors.filter(c => c.type === 'Connector').map(c => [c.source, c.destination]));
for (const b of box.values()) {
  const d = b.s.details;
  if (b.s.type === 'Entity') {
    parts.push(`<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#e8f0ff" stroke="#000"/>`);
    if (d.type === 'weak') parts.push(`<rect x="${b.x + 4}" y="${b.y + 4}" width="${b.w - 8}" height="${b.h - 8}" fill="none" stroke="#000"/>`);
  } else if (b.s.type === 'Relationship') {
    const p = `${b.cx},${b.y} ${b.x + b.w},${b.cy} ${b.cx},${b.y + b.h} ${b.x},${b.cy}`;
    parts.push(`<polygon points="${p}" fill="#fff4e0" stroke="#000"/>`);
    if (d.isIdentifying) parts.push(`<polygon points="${b.cx},${b.y + 6} ${b.x + b.w - 10},${b.cy} ${b.cx},${b.y + b.h - 6} ${b.x + 10},${b.cy}" fill="none" stroke="#000"/>`);
  } else if (b.s.type === 'Attribute') {
    parts.push(`<ellipse cx="${b.cx}" cy="${b.cy}" rx="${b.w / 2}" ry="${b.h / 2}" fill="#f4fff0" stroke="#000"/>`);
    if (d.isMultivalued) parts.push(`<ellipse cx="${b.cx}" cy="${b.cy}" rx="${b.w / 2 - 4}" ry="${b.h / 2 - 4}" fill="none" stroke="#000"/>`);
  } else {
    parts.push(`<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="#fffbd0" stroke="#999" stroke-dasharray="3 2"/>`);
  }
  const t = d.name || d.text;
  const deco = b.s.type === 'Attribute' && d.isUnique ? (weakOwners.has(attrOwner.get(d.id)) ? ' text-decoration="underline" style="text-decoration-style:dashed"' : ' text-decoration="underline"') : '';
  // names wider than their shape are squeezed to fit (Arial 13px is about 8px per capital letter)
  const fit = b.s.type !== 'Label' && String(t).length * 8 > b.w - 10 ? ` textLength="${b.w - 10}" lengthAdjust="spacingAndGlyphs"` : '';
  parts.push(`<text x="${b.cx}" y="${b.cy + 5}" font-family="Arial" font-size="13" text-anchor="middle"${deco}${fit}>${esc(t)}</text>`);
}
// --card: also print each entity's (min,max) the way ERD+ does, next to the OTHER entity of the relationship
if (process.argv.includes('--card')) {
  for (const r of doc.shapes.filter(s => s.type === 'Relationship')) {
    const sl = r.details.slots;
    if (sl[0].entityId === sl[1].entityId) continue; // recursive: ERD+ shows nothing, the diagram has Labels
    for (const x of sl) {
      const other = sl.find(o => o !== x), rel = box.get(r.details.id), ent = box.get(other.entityId);
      const t = `(${x.participation === 'mandatory' ? 1 : 0},${x.cardinality === 'one' ? 1 : 'N'})`;
      const k = 0.72, lx = rel.cx + (ent.cx - rel.cx) * k, ly = rel.cy + (ent.cy - rel.cy) * k;
      parts.push(`<rect x="${lx - 19}" y="${ly - 9}" width="38" height="15" fill="#fff" opacity="0.85"/><text x="${lx}" y="${ly + 3}" font-family="Arial" font-size="11" font-weight="bold" fill="#a00000" text-anchor="middle">${t}</text>`);
    }
  }
}
// overlaps between estimated shapes
const L = [...box.values()]; const hits = [];
for (let i = 0; i < L.length; i++) for (let j = i + 1; j < L.length; j++) {
  const a = L[i], b = L[j];
  const ov = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x), oh = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
  // ellipses and diamonds fill about 70% of their box
  const k = (a.s.type === 'Entity' || a.s.type === 'Label') && (b.s.type === 'Entity' || b.s.type === 'Label') ? 0 : 0.3 * Math.min(a.w, b.w);
  if (ov > k && oh > 0.3 * Math.min(a.h, b.h)) hits.push(`${a.s.details.name || a.s.details.text} / ${b.s.details.name || b.s.details.text}`);
}
fs.writeFileSync(OUT, `<svg xmlns="http://www.w3.org/2000/svg" width="${doc.width}" height="${doc.height}" viewBox="0 0 ${doc.width} ${doc.height}"><rect width="100%" height="100%" fill="#fff"/>${parts.join('')}</svg>`);
console.log(JSON.stringify({ out: path.basename(OUT), overlaps: hits.length, sample: hits.slice(0, 40) }, null, 1));
