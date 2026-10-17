// Builds the single-page artifact mdms-er.html from model.js, sources.js and the Graphviz diagrams.
const fs = require('fs');
const { instance } = require('@viz-js/viz');
const { areas, decisions, changes, recheck, third, fourth, conflicts, assumptions } = require('./model.js');
const sources = require('./sources.js');
const { themeSvg, layoutArea, layoutWhole, parseAttr } = require('./diagram.js');
const { CSS, JS } = require('./page.js');

// Greek page: explanations come from el.json (English text -> Greek), names stay English
const EL = fs.existsSync('./el.json') ? JSON.parse(fs.readFileSync('./el.json', 'utf8')) : {};
const untranslated = new Set();
const T = s => { if (!s) return s; if (EL[s]) return EL[s]; untranslated.add(s); return s; };
areas.forEach(a => {
  a.title = T(a.title); a.lead = T(a.lead);
  a.entities.forEach(e => { if (e.note) e.note = T(e.note); });
  a.rels.forEach(r => { if (r.note) r.note = T(r.note); });
});
[...decisions, ...conflicts].forEach(d => { d.title = T(d.title); d.text = T(d.text); });
[...changes, ...recheck, ...third, ...fourth, ...assumptions].forEach(c => { c.text = T(c.text); });
sources.forEach(x => { x.en = T(x.en); x.sec = T(x.sec); });

const SCHEMA_URL = process.env.SCHEMA_URL || '#';
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const srcById = new Map(sources.map(s => [s.id, s]));
const decById = new Map(decisions.map(d => [d.id, d]));
const conById = new Map(conflicts.map(c => [c.id, c]));
const anchorOf = id => id[0] === 'D' ? `dec-${id}` : id[0] === 'C' ? `con-${id}` : `src-${id}`;
const kindOf = id => ({ S: 'spec', L: 'lec', D: 'dec', C: 'con' })[id[0]];
const tipOf = id => {
  if (id[0] === 'D') return `Σχεδιαστική απόφαση: ${decById.get(id).title}`;
  if (id[0] === 'C') return `Αντίφαση ή ανοιχτό σημείο: ${conById.get(id).title}`;
  const s = srcById.get(id);
  return s.lecture ? s.sec : `Εκφώνηση ${s.sec}, σελίδα ${s.page}`;
};
const exists = id => srcById.has(id) || decById.has(id) || conById.has(id);

// back-references: citation id -> [{href, label}]
const backrefs = new Map();
const cite = (ids, from) => {
  if (!ids || !ids.length) return '';
  ids.forEach(id => {
    if (!exists(id)) throw new Error(`Unknown citation ${id} in ${from && from.label}`);
    if (!from) return;
    const list = backrefs.get(id) || [];
    if (!list.some(b => b.href === from.href)) list.push(from);
    backrefs.set(id, list);
  });
  return `<span class="cites">${ids.map(id => `<a class="chip ${kindOf(id)}" href="#${anchorOf(id)}" title="${esc(tipOf(id))}">${id}</a>`).join('')}</span>`;
};

const allEntities = new Map();
const homeArea = new Map();
areas.forEach(a => a.entities.forEach(e => { allEntities.set(e.name, e); homeArea.set(e.name, a); }));
const relsOf = new Map();
areas.forEach(a => a.rels.forEach(r => r.ends.forEach(x => {
  const l = relsOf.get(x.e) || [];
  if (!l.includes(r.name)) l.push(r.name);
  relsOf.set(x.e, l);
})));
const isaOf = new Map(); // subclass -> {sup, href}
const isaSup = new Map();
areas.forEach(a => (a.isa || []).forEach((i, k) => {
  i.subs.forEach(s => isaOf.set(s, { sup: i.sup, href: `#isa-${a.id}-${k}` }));
  isaSup.set(i.sup, { subs: i.subs, href: `#isa-${a.id}-${k}` });
}));
const nRels = areas.reduce((s, a) => s + a.rels.length, 0);
const nEnts = allEntities.size;
const nSpec = sources.filter(s => !s.lecture).length;
const nLec = sources.filter(s => s.lecture).length;

const entLink = n => `<a class="ent-link" href="#e-${n}">${n}</a>`;
const relLink = n => `<a class="rel-link" href="#r-${n}">${n}</a>`;

function attrHtml(a) {
  const at = parseAttr(a);
  if (at.parts) return `<span class="at ${at.key ? 'key' : at.partial ? 'partial' : ''}" title="Σύνθετο χαρακτηριστικό${at.key ? ', πρωτεύον κλειδί' : at.partial ? ', μερικό κλειδί' : ''}">${esc(at.name)}</span>(${at.parts.map(esc).join(', ')})`;
  if (at.key) return `<span class="at key" title="Πρωτεύον κλειδί (υπογραμμισμένο)">${esc(at.name)}</span>`;
  if (at.partial) return `<span class="at partial" title="Μερικό κλειδί ασθενούς οντότητας (διακεκομμένη υπογράμμιση)">${esc(at.name)}</span>`;
  if (at.unique) return `<span class="at cand" title="Εναλλακτικό κλειδί, μοναδικό (γραμμή από πάνω)">${esc(at.name)}</span>`;
  if (at.multi) return `<span class="at multi" title="Πλειότιμο χαρακτηριστικό (διπλή έλλειψη)">{${esc(at.name)}}</span>`;
  return `<span class="at">${esc(at.name)}</span>`;
}

const quant = (minOne, maxOne) => minOne ? (maxOne ? 'ακριβώς ένα' : 'ένα ή περισσότερα') : (maxOne ? 'το πολύ ένα' : 'κανένα ή περισσότερα');
const roleTxt = r => r ? ` <span class="role">ως ${esc(r)}</span>` : '';

// ---------- ERD+ steps (shown in each entity, relationship and specialization) ----------
// ERD+ prints next to entity Y the pair that describes each X on the other side: min = 1 when X takes part totally, max = Y's ratio label
const mmNext = (x, y) => ({ min: x.total ? 1 : 0, max: y.card === '1' ? 1 : 'M' });
const mmTxt = m => `(${m.min},${m.max})`;
const mmSet = m => `<b>${m.min ? 'Mandatory' : 'Optional'}</b> + <b>${m.max === 1 ? 'One' : 'Many'}</b>`;
const erdBox = (lis, extra = '') => `<div class="erd"><p class="erd-h"><span class="erd-tag">ERD+</span> Πώς το σχεδιάζετε</p><ol>${lis.map(l => `<li>${l}</li>`).join('')}</ol>${extra}</div>`;
// in an identifying relationship the weak end is the N side (1:N) or the total side (1:1); the other end is the owner
const weakEnd = r => { const [a, b] = r.ends; if (a.card !== b.card) return a.card === '1' ? b : a; return a.total ? a : b; };
const ownersOf = name => { const o = []; areas.forEach(a => a.rels.filter(r => r.ident && weakEnd(r).e === name).forEach(r => r.ends.filter(x => x.e !== name).forEach(x => o.push({ e: x.e, r: r.name })))); return o; };
function erdEntity(e) {
  const lis = [];
  const ats = e.attrs.map(parseAttr);
  if (isaOf.has(e.name)) {
    lis.push(`Μην το φτιάξετε με <b>Entity</b>: επιλέξτε το ${entLink(isaOf.get(e.name).sup)} (τύπος <b>Supertype</b>) και προσθέστε υποτύπο με όνομα <code>${e.name}</code>. Δείτε την <a href="${isaOf.get(e.name).href}">εξειδίκευση</a>.`);
    lis.push(`Δεν παίρνει κλειδί: κληρονομεί το κλειδί του ${entLink(isaOf.get(e.name).sup)}.`);
  } else {
    lis.push(`<b>Entity</b> → κλικ στον καμβά → όνομα <code>${e.name}</code>. Τύπος: <b>${e.weak ? 'Weak' : isaSup.has(e.name) ? 'Supertype' : 'Regular'}</b>${e.weak ? ' (διπλό ορθογώνιο)' : isaSup.has(e.name) ? ' (δείτε την <a href="' + isaSup.get(e.name).href + '">εξειδίκευση</a>)' : ''}.`);
  }
  if (ats.length) {
    const tick = at => at.parts ? `<b>Composite</b> + <b>${at.key ? 'Unique' : at.partial ? 'Partially Unique' : ''}</b>, με μέρη ${at.parts.map(p => `<code>${esc(p)}</code>`).join(' και ')} (προσθέστε τα ως υπο-χαρακτηριστικά)` : at.key ? '<b>Unique</b> (υπογράμμιση: πρωτεύον κλειδί)' : at.partial ? '<b>Partially Unique</b> (διακεκομμένη υπογράμμιση)' : at.unique ? '<b>Unique</b> (κι αυτό υπογραμμίζεται· είναι εναλλακτικό κλειδί)' : at.multi ? '<b>Multivalued</b> (διπλή έλλειψη)' : 'τίποτα';
    lis.push(`Χαρακτηριστικά (από το πλαίσιο του ${e.name}), και τι τσεκάρετε:<ul class="erd-at">${ats.map(at => `<li><code>${esc(at.name)}</code> <span>${tick(at)}</span></li>`).join('')}</ul>`);
  } else lis.push('Δεν έχει δικά του χαρακτηριστικά.');
  const keyAt = ats.find(a => a.key);
  ats.filter(a => a.unique && /ID$/.test(a.name)).forEach(a => lis.push(`Φτιάξτε το <code>${keyAt ? esc(keyAt.name) : 'κλειδί'}</code> πριν από το <code>${esc(a.name)}</code>: η μετατροπή του ERD+ σε σχεσιακό σχήμα παίρνει ως πρωτεύον κλειδί το πρώτο Unique χαρακτηριστικό που τελειώνει σε ID.`));
  if (e.weak) {
    const own = ownersOf(e.name);
    const pk = ats.filter(a => a.partial);
    lis.push(`Συνδέεται με ${own.length > 1 ? 'τις προσδιορίζουσες οντότητες' : 'την προσδιορίζουσα οντότητα'} ${own.map(o => `${entLink(o.e)} μέσω ${relLink(o.r)}`).join(' και ')}, ${own.length > 1 ? 'καθεμία με δικό της' : 'με'} <b>Identifying</b> ρόμβο.`);
    if (pk.length > 1) lis.push(`Το μερικό κλειδί έχει ${pk.length} μέρη. Τσεκάρετε <b>Partially Unique</b> σε καθένα. Αν δεν εμφανιστεί καθαρά, κάντε όπως στο EntryDateTime της Άσκησης 1: ένα χαρακτηριστικό <b>Composite</b> + <b>Partially Unique</b> με μέρη ${pk.map(a => `<code>${esc(a.name)}</code>`).join(', ')}.`);
    if (!pk.length) lis.push('Δεν έχει μερικό κλειδί: προσδιορίζεται μόνο από τις προσδιορίζουσες οντότητές του, οπότε δεν τσεκάρετε <b>Partially Unique</b> πουθενά.');
  }
  return erdBox(lis);
}
const fkTable = r => (r.ends.find(x => x.card !== '1') || r.ends[0]).e;
function erdRel(r) {
  const [a, b] = r.ends;
  const rec = a.e === b.e;
  const lis = [];
  lis.push(rec
    ? `<b>Connect</b> από το ${entLink(a.e)} πίσω στο ίδιο ${entLink(a.e)}, ώστε ένας ρόμβος να έχει δύο γραμμές προς το ίδιο ορθογώνιο. Όνομα ρόμβου <code>${r.name}</code>.`
    : `<b>Connect</b>: σύρετε από το ${entLink(a.e)} στο ${entLink(b.e)}. Όνομα ρόμβου <code>${r.name}</code>.`);
  const weakOwner = r.ident && r.ends.length === 2 && r.ends.every(x => allEntities.get(x.e) && allEntities.get(x.e).weak);
  if (weakOwner) { const ow = r.ends.find(x => x !== weakEnd(r)); const up = ownersOf(ow.e).map(o => relLink(o.r)).join(' και '); lis.push(`Η προσδιορίζουσα οντότητα ${entLink(ow.e)} είναι κι αυτή ασθενής. Σχεδιάστε πρώτα τις ${up}, ώστε η μετατροπή σε σχεσιακό σχήμα να δώσει ολόκληρο το κλειδί.`); }
  if (r.ident) lis.push(`Τσεκάρετε <b>Identifying</b> (διπλός ρόμβος). Το ${entLink(weakEnd(r).e)} πρέπει να είναι τύπου <b>Weak</b>.`);
  const sides = [[b, a], [a, b]].map(([y, x]) => {
    const m = mmNext(x, y);
    const who = rec ? `στη γραμμή του ρόλου <i>${esc(y.role)}</i>` : `στο ${entLink(y.e)}`;
    return `δίπλα ${who}: <b class="mmv">${mmTxt(m)}</b> → ${mmSet(m)} <span class="erd-why">(κάθε ${x.e}${rec ? ' ως ' + esc(x.role) : ''} → ${quant(m.min, m.max === 1)} ${y.e}${rec ? ' ως ' + esc(y.role) : ''})</span>`;
  });
  lis.push(`Πληθικότητες στις δύο πλευρές του ρόμβου:<ul class="erd-at">${sides.map(s => `<li>${s}</li>`).join('')}</ul>`);
  if (rec) lis.push(`Γράψτε τους ρόλους <i>${esc(a.role)}</i> και <i>${esc(b.role)}</i> στις δύο πλευρές. Το ERD+ δεν τυπώνει τα (min,max) σε αναδρομική συσχέτιση, οπότε προσθέστε τα με <b>Label</b> δίπλα στην άκρη κάθε γραμμής, όπως στο Refers της Άσκησης 1. Κάντε το στο τέλος, όταν η διάταξη δεν θα αλλάξει.`);
  if (r.attrs && r.attrs.length) lis.push(`Χαρακτηριστικά του ρόμβου (προσθέστε τα από το πλαίσιο του ρόμβου, όχι της οντότητας): ${r.attrs.map(x => `<code>${esc(x)}</code>`).join(', ')}.`);
  if (!rec) lis.push(`Έλεγχος: το ${mmTxt(mmNext(a, b))} πρέπει να φαίνεται δίπλα στο ${b.e}. Αν βγει ανάποδα, ανταλλάξτε τις τιμές των δύο πλευρών.`);
  if (r.fk) lis.push(`Αργότερα, στο σχεσιακό σχήμα: μετονομάστε τη στήλη που φέρνει αυτή η συσχέτιση στον πίνακα <code>${fkTable(r)}</code> σε <code>${r.fk}</code>. ${rec ? 'Το ERD+ την ονομάζει ' + r.name + '_' + 'GeofenceID, που διαβάζεται δύσκολα.' : 'Το ERD+ δίνει σε κάθε ξένο κλειδί το όνομα του κλειδιού που δείχνει, οπότε αλλιώς ο πίνακας θα είχε δύο στήλες UserID.'}`);
  return erdBox(lis);
}
function erdIsa(i) {
  const lis = [
    `Επιλέξτε το ${entLink(i.sup)} και ορίστε τύπο <b>Supertype</b>.`,
    `Επιλέξτε <b>${i.kind === 'o' ? 'Overlapping' : 'Disjointed'}</b> (${i.kind}). ${i.total ? 'Τσεκάρετε' : 'Αφήστε ατσέκαρτο το'} <b>Total Specialization</b> (${i.total ? 'ολική' : 'μερική'} εξειδίκευση).`,
    `Προσθέστε υποτύπο για καθένα από ${i.subs.map(entLink).join(', ')}, μετονομάστε τον και βάλτε μόνο τα δικά του χαρακτηριστικά, χωρίς κλειδί.`,
    `Έλεγχος: κύκλος με «${i.kind}» και σύμβολο ⊂ στη γραμμή κάθε υποκλάσης.`
  ];
  if (i.attr) lis.push(`Κρατήστε το <code>${i.attr}</code> ως απλό χαρακτηριστικό του ${entLink(i.sup)}. Αν το ERD+ δεν το γράφει στη γραμμή προς τον κύκλο, προσθέστε το με <b>Label</b> δίπλα της.`);
  return erdBox(lis, `<p class="erd-note">Αν το πλαίσιο δεν σας δίνει <b>Supertype</b>, σχεδιάστε για κάθε υποκλάση μια συσχέτιση 1:1 <code>IS_A</code> με (1,1) δίπλα στο ${i.sup} και (0,1) δίπλα στην υποκλάση, και γράψτε την εξειδίκευση στις παραδοχές.</p>`);
}

function entityItem(e, area) {
  const from = { href: `#e-${e.name}`, label: e.name };
  const badges = [];
  if (e.weak) {
    const owners = ownersOf(e.name).map(o => o.e);
    badges.push(`<span class="badge weak">ασθενής</span>`);
    badges.push(`<span class="owners">${owners.length > 1 ? 'προσδιορίζουσες οντότητες' : 'προσδιορίζουσα οντότητα'}: ${owners.map(entLink).join(', ')}</span>`);
  }
  if (isaOf.has(e.name)) badges.push(`<span class="badge sub">υποκλάση</span><span class="owners">του ${entLink(isaOf.get(e.name).sup)}</span>`);
  if (isaSup.has(e.name)) badges.push(`<span class="badge sup">υπερκλάση</span>`);
  const attrs = e.attrs.length ? e.attrs.map(attrHtml).join('<span class="sep">, </span>') : '<span class="none">Χωρίς δικά του χαρακτηριστικά</span>';
  const rels = (relsOf.get(e.name) || []).map(relLink).join(', ');
  return `<article class="item ent" id="e-${e.name}">
  <div class="item-l"><code class="nm">${e.name}</code>${badges.length ? `<div class="badges">${badges.join(' ')}</div>` : ''}${cite(e.src, from)}</div>
  <div class="item-r">
    <div class="attrs">${attrs}</div>
    ${e.note ? `<p class="note">${esc(e.note)}</p>` : ''}
    ${rels ? `<p class="inrels"><span class="lbl">Συσχετίσεις</span> ${rels}</p>` : ''}
    ${erdEntity(e)}
  </div>
</article>`;
}

function relItem(r) {
  const from = { href: `#r-${r.name}`, label: r.name };
  const ratio = r.ends.map(x => x.card).join(':');
  const ends = r.ends.map((x, i) => {
    const o = r.ends[1 - i];
    const mm = `(${x.total ? 1 : 0},${o.card === '1' ? 1 : 'M'})`;
    const meaning = `κάθε ${entLink(x.e)}${roleTxt(x.role)} → ${quant(x.total, o.card === '1')} ${entLink(o.e)}${roleTxt(o.role)} <span class="mm" title="ERD+ (min,max): μπαίνει δίπλα στο ${esc(o.e)}">${mm}</span>`;
    return `<li class="end">
      <span class="end-e">${entLink(x.e)}${roleTxt(x.role)}</span>
      <span class="card" title="Ετικέτα πληθικότητας στη γραμμή αυτής της οντότητας">${x.card}</span>
      <span class="part ${x.total ? 'total' : 'partial'}" title="${x.total ? 'Ολική συμμετοχή: διπλή γραμμή. Κάθε ' + x.e + ' πρέπει να συμμετέχει.' : 'Μερική συμμετοχή: μονή γραμμή. Ένα ' + x.e + ' μπορεί να μη συμμετέχει.'}"><i class="ln"></i>${x.total ? 'ολική' : 'μερική'}</span>
      <span class="mean">${meaning}</span>
    </li>`;
  }).join('');
  return `<article class="item rel" id="r-${r.name}">
  <div class="item-l"><code class="nm">${r.name}</code><div class="badges"><span class="badge ratio" title="Λόγος πληθικότητας">${ratio}</span>${r.ident ? '<span class="badge ident">προσδιορίζουσα</span>' : ''}${r.ends[0].e === r.ends[1].e ? '<span class="badge rec">αναδρομική</span>' : ''}</div>${cite(r.src, from)}</div>
  <div class="item-r">
    <ul class="ends">${ends}</ul>
    ${r.attrs && r.attrs.length ? `<p class="inrels"><span class="lbl">Χαρακτηριστικά</span> ${r.attrs.map(a => `<span class="at">${esc(a)}</span>`).join(', ')}</p>` : ''}
    ${r.note ? `<p class="note">${esc(r.note)}</p>` : ''}
    ${erdRel(r)}
  </div>
</article>`;
}

function isaItem(i, area, k) {
  const id = `isa-${area.id}-${k}`;
  const from = { href: `#${id}`, label: `Εξειδίκευση του ${i.sup}` };
  return `<article class="item rel" id="${id}">
  <div class="item-l"><code class="nm">${i.sup} ⊃</code><div class="badges"><span class="badge ratio">${i.kind === 'o' ? 'o · επικαλυπτόμενη' : 'd · μη επικαλυπτόμενη'}</span><span class="badge rec">${i.total ? 'ολική' : 'μερική'}</span></div>${cite(i.src, from)}</div>
  <div class="item-r">
    <p class="mean-p">Εξειδίκευση του ${entLink(i.sup)} σε ${i.subs.map(entLink).join(', ')}. ${i.kind === 'o' ? 'Επικαλυπτόμενη (o): μια οντότητα μπορεί να ανήκει σε περισσότερες από μία υποκλάσεις.' : 'Μη επικαλυπτόμενη (d): μια οντότητα ανήκει το πολύ σε μία υποκλάση.'} ${i.total ? 'Ολική (διπλή γραμμή): κάθε οντότητα της υπερκλάσης ανήκει σε κάποια υποκλάση.' : `Μερική (μονή γραμμή): μια οντότητα μπορεί να μην ανήκει σε καμία υποκλάση${i.sup === 'USER_ACCOUNT' ? ', π.χ. ένας λογαριασμός προσωπικού του DSO' : ''}.`}${i.attr ? ` Ορίζεται από το χαρακτηριστικό <code>${i.attr}</code> της υπερκλάσης, που γράφεται στη γραμμή προς τον κύκλο: κάθε τιμή του αντιστοιχεί σε μία υποκλάση ${cite(['L13'], from)}.` : ''}</p>
    ${erdIsa(i)}
  </div>
</article>`;
}

// ---------- notation legend ----------
const LG = (svg, title, text, ids) => `<figure class="lg-item"><svg viewBox="0 0 132 60" class="lg" aria-hidden="true">${svg}</svg><figcaption><b>${title}</b><span>${text}</span>${cite(ids, { href: '#notation', label: 'Σημειογραφία' })}</figcaption></figure>`;
const TX = (x, y, s, cls = '') => `<text x="${x}" y="${y}" class="${cls}" text-anchor="middle">${s}</text>`;
const legend = [
  LG(`<rect x="22" y="16" width="88" height="28" class="e"/>${TX(66, 34, 'ENTITY', 'b')}`, 'Οντότητα', 'Ορθογώνιο με το όνομα.', ['L4']),
  LG(`<rect x="18" y="12" width="96" height="36" class="e"/><rect x="23" y="17" width="86" height="26" class="e"/>${TX(66, 34, 'WEAK', 'b')}`, 'Ασθενής οντότητα', 'Διπλό ορθογώνιο. Δεν έχει δικό της κλειδί και προσδιορίζεται μέσω της προσδιορίζουσας οντότητας.', ['L2', 'L5']),
  LG(`<rect x="22" y="16" width="88" height="28" class="x"/>${TX(66, 34, 'OTHER', 'b m')}`, 'Οντότητα άλλης περιοχής', 'Διακεκομμένη και γκρι. Πατήστε την για να πάτε στην περιοχή που την ορίζει.', []),
  LG(`<polygon points="66,6 112,30 66,54 20,30" class="r"/>${TX(66, 34, 'REL', 's')}`, 'Συσχέτιση', 'Ρόμβος με το όνομα.', ['L5']),
  LG(`<polygon points="66,3 118,30 66,57 14,30" class="r"/><polygon points="66,10 105,30 66,50 27,30" class="r"/>${TX(66, 34, 'OWNS', 's')}`, 'Προσδιορίζουσα συσχέτιση', 'Διπλός ρόμβος. Συνδέει μια ασθενή οντότητα με την προσδιορίζουσα οντότητά της, πάντα 1:1 ή 1:N.', ['L2', 'L5']),
  LG(`<ellipse cx="66" cy="30" rx="46" ry="17" class="a"/>${TX(66, 34, 'Attribute')}`, 'Χαρακτηριστικό', 'Έλλειψη ενωμένη με την οντότητά της.', ['L4']),
  LG(`<ellipse cx="66" cy="30" rx="46" ry="17" class="a"/>${TX(66, 34, 'UserID')}<line x1="45" y1="37" x2="87" y2="37" class="u"/>`, 'Πρωτεύον κλειδί', 'Υπογραμμισμένο όνομα.', ['L4']),
  LG(`<ellipse cx="66" cy="30" rx="46" ry="17" class="a"/>${TX(66, 36, 'Email')}<line x1="49" y1="24" x2="83" y2="24" class="u"/>`, 'Εναλλακτικό κλειδί', 'Γραμμή πάνω από το όνομα: μοναδικό, αλλά όχι το πρωτεύον κλειδί.', ['L4']),
  LG(`<ellipse cx="66" cy="30" rx="46" ry="17" class="a"/>${TX(66, 34, 'NoteNo')}<line x1="45" y1="38" x2="87" y2="38" class="u dot"/>`, 'Μερικό κλειδί', 'Διακεκομμένη υπογράμμιση. Μαζί με το κλειδί της προσδιορίζουσας οντότητας προσδιορίζει την ασθενή οντότητα.', ['L2', 'L4']),
  LG(`<ellipse cx="66" cy="30" rx="50" ry="21" class="a"/><ellipse cx="66" cy="30" rx="44" ry="15" class="a"/>${TX(66, 34, '{Channel}')}`, 'Πλειότιμο χαρακτηριστικό', 'Διπλή έλλειψη. Στους πίνακες γράφεται {Name}.', ['L4']),
  LG(`<rect x="4" y="18" width="34" height="24" class="e"/><line x1="38" y1="30" x2="88" y2="30" class="l"/><polygon points="108,16 128,30 108,44 88,30" class="r"/>${TX(60, 24, '1', 'c')}`, 'Μερική συμμετοχή', 'Μονή γραμμή. Η ετικέτα (1, N ή M) λέει πόσες οντότητες αυτού του τύπου σχετίζονται με μία οντότητα της άλλης πλευράς.', ['L1', 'L5']),
  LG(`<rect x="4" y="18" width="34" height="24" class="e"/><line x1="38" y1="27.5" x2="89" y2="27.5" class="l"/><line x1="38" y1="32.5" x2="89" y2="32.5" class="l"/><polygon points="108,16 128,30 108,44 88,30" class="r"/>${TX(60, 22, 'N', 'c')}`, 'Ολική συμμετοχή', 'Διπλή γραμμή. Κάθε οντότητα αυτού του τύπου πρέπει να συμμετέχει.', ['L1', 'L5']),
].join('');

// ---------- page ----------
const toolbar = hint => `<div class="dtools">
      <div class="seg" role="group" aria-label="Χαρακτηριστικά που φαίνονται"><button type="button" data-set-view="keys" aria-pressed="true">Μόνο κλειδιά</button><button type="button" data-set-view="full" aria-pressed="false">Όλα τα χαρακτηριστικά</button></div>
      <div class="seg zoom" role="group" aria-label="Μεγέθυνση"><button type="button" data-zoom="out" aria-label="Σμίκρυνση">−</button><span class="zl" aria-live="polite">Fit</span><button type="button" data-zoom="in" aria-label="Μεγέθυνση">+</button></div>
      <div class="seg" role="group" aria-label="Μέγεθος διαγράμματος"><button type="button" data-set-size="fit" aria-pressed="true">Όλο</button><button type="button" data-set-size="actual" aria-pressed="false">100%</button></div>
      <span class="dhint">${hint}</span>
    </div>`;

function build(diagrams, whole) {
  const nav = `<nav class="toc" aria-label="Ενότητες"><div class="toc-in">
    <a class="brand" href="#top">MDMS-Cy ER</a>
    <a href="#changes">Αλλαγές</a><a href="#notation">Σημειογραφία</a><a href="#whole">Ενιαίο διάγραμμα</a><a href="#erdplus">Οδηγός ERD+</a><a href="#areas">Περιοχές</a><a href="#decisions">Αποφάσεις</a><a href="#conflicts">Αντιφάσεις</a><a href="#assumptions">Παραδοχές</a><a href="#sources">Πηγές</a>
  </div></nav>`;

  const wk = whole.keys.svg.replace('<svg', `<svg style="--w:${whole.keys.w}px" aria-label="Ολόκληρο το μοντέλο: διάγραμμα ER, μόνο κλειδιά"`);
  const wf = whole.full.svg.replace('<svg', `<svg style="--w:${whole.full.w}px" aria-label="Ολόκληρο το μοντέλο: διάγραμμα ER, όλα τα χαρακτηριστικά"`);
  const W = { href: '#whole', label: 'Ενιαίο διάγραμμα' };
  const recs = areas.flatMap(a => a.rels).filter(r => r.ends[0].e === r.ends[1].e);
  const fkRels = areas.flatMap(a => a.rels).filter(r => r.fk).sort((x, y) => fkTable(x).localeCompare(fkTable(y)));
  const recNames = recs.map(r => relLink(r.name)).join(' και ');
  const wholeSection = `<section id="whole" class="block"><h2>Όλο το μοντέλο σε ένα διάγραμμα</h2>
  <p class="lead">Η εκφώνηση ζητά ένα διάγραμμα ER ${cite(['S61', 'S65'], W)}, και το μάθημα σχεδιάζει ένα ολοκληρωμένο μοντέλο ως ένα διάγραμμα ${cite(['L6'], W)}. Αυτό είναι το διάγραμμα που θα ξανασχεδιάσετε στο ERD+ για την παράδοση. Κάθε περιοχή κρατά τη διάταξη της δικής της ενότητας πιο κάτω, σε πλαίσιο με αριθμό. Οι γκρι γραμμές είναι συσχετίσεις μεταξύ περιοχών.</p>
  <div class="diagram" data-view="keys" data-size="fit">
    ${toolbar('Μεγέθυνση με − και +, Ctrl + ροδέλα ή δύο δάχτυλα. Σύρετε τον κενό χώρο για να μετακινηθείτε. Πατήστε ένα σχήμα για λεπτομέρειες και οδηγίες ERD+.')}
    <div class="dscroll"><div class="dv dv-keys">${wk}</div><div class="dv dv-full">${wf}</div></div>
  </div>
  <div class="keybox erd">
    <p><b>Μεταφορά στο ERD+.</b> Το ERD+ δείχνει κάθε (min,max) στην απέναντι πλευρά της συσχέτισης ${cite(['L8'], W)}. Κάθε γραμμή συσχέτισης στις περιοχές τελειώνει ήδη με αυτό: «κάθε X → ακριβώς ένα Y (1,1)» σημαίνει ότι το (1,1) μπαίνει δίπλα στο Y.</p>
    <table class="mmtab"><thead><tr><th>Η γραμμή λέει</th><th>(min,max)</th><th>Στο διάγραμμα Chen</th></tr></thead><tbody>
      <tr><td>ακριβώς ένα</td><td><code>(1,1)</code></td><td>ολική συμμετοχή (διπλή γραμμή) του X και 1 στη γραμμή του Y</td></tr>
      <tr><td>το πολύ ένα</td><td><code>(0,1)</code></td><td>μερική συμμετοχή (μονή γραμμή) του X και 1 στη γραμμή του Y</td></tr>
      <tr><td>ένα ή περισσότερα</td><td><code>(1,M)</code></td><td>ολική συμμετοχή του X και N ή M στη γραμμή του Y</td></tr>
      <tr><td>κανένα ή περισσότερα</td><td><code>(0,M)</code></td><td>μερική συμμετοχή του X και N ή M στη γραμμή του Y</td></tr>
    </tbody></table>
    <p>Το ERD+ δεν δείχνει πληθικότητα σε αναδρομική συσχέτιση, οπότε την προσθέτετε με το χέρι ${recs.length > 1 ? 'στις' : 'στην'} ${recNames} ${cite(['L8'], W)}. Τα αγγλικά ονόματα επιτρέπονται ${cite(['L7'], W)}. Βήμα προς βήμα: <a href="#erdplus">Οδηγός ERD+</a>.</p>
  </div>
</section>`;

  const G = { href: '#erdplus', label: 'Οδηγός ERD+' };
  const roleRels = areas.flatMap(a => a.rels).filter(r => /^IS_/.test(r.name));
  const erdSection = `<section id="erdplus" class="block"><h2>Οδηγός ERD+</h2>
  <p class="lead">Πώς μεταφέρετε το ενιαίο διάγραμμα στο ERD+, το εργαλείο του εργαστηρίου ${cite(['L9'], G)}. Κάθε οντότητα, συσχέτιση και εξειδίκευση σε αυτή τη σελίδα έχει δικό της πλαίσιο <span class="erd-tag">ERD+</span> με τα ακριβή βήματα: πατήστε το σχήμα στο διάγραμμα και τα βλέπετε στο πλάι.</p>
  <div class="guide">
    <article class="gcard"><h3>Πριν ξεκινήσετε</h3>
      <ul>
        <li>Χρησιμοποιήστε τον τρέχοντα editor του <a href="https://erdplus.com" target="_blank" rel="noopener">erdplus.com</a>, τον ίδιο της Άσκησης 1. Η γραμμή εργαλείων του έχει <b>Entity</b>, <b>Label</b>, <b>Delete</b>, <b>Undo</b>, <b>Redo</b>, <b>Connect</b>, <b>Save</b>, <b>Restore</b>, <b>Download image</b>, <b>Help</b>. Αγνοήστε οδηγούς με κουμπιά RELATIONSHIP ή «Edit Exact Constraints»: είναι ο παλιός editor.</li>
        <li>Οι επιλογές που αναφέρονται (Weak, Unique, Partially Unique, Multivalued, Composite, Identifying, Mandatory/Optional, One/Many) προέρχονται από την τεκμηρίωση και τα αρχεία του ERD+ και ταιριάζουν με τα διαγράμματα της Άσκησης 1, αλλά το ζωντανό πλαίσιο δεν το είδαμε. Αν κάποια λέγεται λίγο αλλιώς, διαλέξτε την αντίστοιχη.</li>
        <li><b>Δοκιμή 2 λεπτών:</b> φτιάξτε δύο οντότητες και μια συσχέτιση, βάλτε σε μία πλευρά Min 5 και Max 10 και δείτε δίπλα σε ποιο ορθογώνιο εμφανίζεται το (5,10). Έτσι ξέρετε ποια πλευρά του πλαισίου αντιστοιχεί σε ποια οντότητα.</li>
        <li>Το μοντέλο είναι απλό ER, χωρίς EER ${cite(['D32'], G)}: δεν χρειάζεστε κύκλο εξειδίκευσης ούτε τύπο Supertype.</li>
      </ul></article>
    <article class="gcard"><h3>Σειρά εργασίας</h3>
      <ol>
        <li>Οντότητες και χαρακτηριστικά, περιοχή προς περιοχή, με τη διάταξη του ενιαίου διαγράμματος.</li>
        <li>Οι 7 ρόλοι: κάθε ρόλος είναι οντότητα τύπου <b>Weak</b> με <b>Identifying</b> ρόμβο 1:1 από το ${entLink('USER_ACCOUNT')} (${roleRels.map(r => relLink(r.name)).join(', ')}) ${cite(['D2'], G)}. Σχεδιάστε τους πριν από τις άλλες συσχετίσεις των ρόλων.</li>
        <li>Οι υπόλοιπες ασθενείς οντότητες (Weak) και οι Identifying ρόμβοι τους.</li>
        <li>Οι υπόλοιπες συσχετίσεις με τα (min,max) τους.</li>
        <li>Στο τέλος, τα Label με τα (min,max) ${recs.length > 1 ? 'των αναδρομικών' : 'της αναδρομικής'} ${recNames} ${cite(['L8'], G)}.</li>
        <li><b>Save</b> συχνά. Στο τέλος <b>Download image</b> σε φωτεινό θέμα, και το PNG μπαίνει στο Word. Δεν υπάρχει εξαγωγή σε PDF.</li>
      </ol></article>
    <article class="gcard wide"><h3>Από τη σελίδα στο ERD+</h3>
      <table class="mmtab gtab"><thead><tr><th>Στη σελίδα (Chen)</th><th>Στο ERD+</th></tr></thead><tbody>
        <tr><td>Οντότητα</td><td><b>Entity</b>, τύπος <b>Regular</b></td></tr>
        <tr><td>Ασθενής οντότητα (διπλό ορθογώνιο)</td><td>τύπος <b>Weak</b></td></tr>
        <tr><td>Πρωτεύον κλειδί (υπογράμμιση)</td><td><b>Unique</b></td></tr>
        <tr><td>Εναλλακτικό κλειδί (γραμμή από πάνω)</td><td><b>Unique</b>. Υπογραμμίζεται κι αυτό, όπως κάθε κλειδί στο Elmasri. Το πρωτεύον είναι αυτό που τελειώνει σε ID.</td></tr>
        <tr><td>Μερικό κλειδί (διακεκομμένη υπογράμμιση)</td><td><b>Partially Unique</b> (μόνο σε οντότητα τύπου Weak)</td></tr>
        <tr><td>Πλειότιμο χαρακτηριστικό (διπλή έλλειψη)</td><td><b>Multivalued</b></td></tr>
        <tr><td>Σύνθετο μερικό κλειδί, π.χ. Period (PeriodType, PeriodStart)</td><td>Ένα χαρακτηριστικό με <b>Composite</b> + <b>Partially Unique</b>, και τα μέρη του ως υπο-χαρακτηριστικά ${cite(['L11'], G)}</td></tr>
        <tr><td>Συσχέτιση (ρόμβος)</td><td><b>Connect</b> από τη μία οντότητα στην άλλη, και όνομα στον ρόμβο</td></tr>
        <tr><td>Προσδιορίζουσα συσχέτιση (διπλός ρόμβος)</td><td><b>Identifying</b></td></tr>
        <tr><td>Ετικέτες 1, N, M και διπλές γραμμές</td><td>Ένα (min,max) σε κάθε πλευρά ${cite(['L10'], G)}. Δίπλα στο X: <b>max</b> = η ετικέτα του X (το N και το M γίνονται M), <b>min</b> = 1 αν η <i>άλλη</i> οντότητα έχει διπλή γραμμή, αλλιώς 0.</td></tr>
        <tr><td>Ολική συμμετοχή (διπλή γραμμή)</td><td>Δεν σχεδιάζεται. Φαίνεται ως min = 1 στο (min,max) της απέναντι πλευράς.</td></tr>
        <tr><td>Αναδρομική συσχέτιση</td><td>Ρόλοι στις δύο γραμμές, και τα (min,max) με <b>Label</b> ${cite(['L8'], G)}</td></tr>
        <tr><td>Ρόλος χρήστη, π.χ. CONSUMER (ασθενής οντότητα με προσδιορίζουσα 1:1)</td><td>Entity τύπου <b>Weak</b>, χωρίς Partially Unique, και <b>Connect</b> από το USER_ACCOUNT με <b>Identifying</b>: (0,1) δίπλα στον ρόλο, (1,1) δίπλα στο USER_ACCOUNT ${cite(['D2'], G)}</td></tr>
      </tbody></table>
      <p class="gnote">Παράδειγμα: ${entLink('PREMISE')} (N, διπλή γραμμή) – ${relLink('LOCATED_IN')} – ${entLink('PARISH')} (1) δίνει (1,1) δίπλα στο PARISH και (0,M) δίπλα στο PREMISE.</p></article>
    <article class="gcard wide"><h3>Σημείωση για την αρχή του εγγράφου</h3>
      <p>Όπως στην Άσκηση 1 ${cite(['L8'], G)}, γράψτε στην αρχή:</p>
      <blockquote class="gquote">Σημαντικό: Το διάγραμμα Οντοτήτων-Συσχετίσεων σχεδιάστηκε στο ERD+, όπου οι πληθικότητες (min,max) κάθε συσχέτισης εμφανίζονται στην απέναντι πλευρά. Δηλαδή κάθε PREMISE βρίσκεται σε ακριβώς 1 PARISH (1,1), ενώ κάθε PARISH έχει από 0 έως πολλά PREMISE (0,M). ${recs.length > 1 ? 'Στις αναδρομικές συσχετίσεις' : 'Στην αναδρομική συσχέτιση'} ${recs.map(r => r.name).join(' και ')} τα (min,max) προστέθηκαν χειροκίνητα, καθώς το ERD+ δεν τα εμφανίζει.</blockquote></article>
    <article class="gcard"><h3>Τι δεν φαίνεται στο διάγραμμα</h3>
      <p>Γράψτε τα στις παραδοχές, κάτω από «Περιορισμοί που δεν απεικονίζονται στο διάγραμμα», όπως στην Άσκηση 1: ότι κάθε λογαριασμός έχει τουλάχιστον έναν ρόλο ${cite(['D2'], G)}, τους ελέγχους «ακριβώς ένα» ή «τουλάχιστον ένα από τα δύο» ${cite(['D8', 'D9', 'D22', 'D23', 'D30'], G)}, τον έλεγχο «το πολύ ένα» για την τελική έγκριση ${cite(['D17'], G)}, τους κανόνες για το Origin του ${entLink('READING_EDIT')}, τις διαδρομές που πρέπει να συμφωνούν ${cite(['D14', 'D24', 'D25', 'D26'], G)}, πότε γράφεται ένα aggregate ${cite(['D13'], G)} και τον κανόνα διατήρησης ${cite(['D19'], G)}.</p></article>
    <article class="gcard wide"><h3>Αργότερα: σχεσιακό σχήμα</h3>
      <p>Το ERD+ μετατρέπει το διάγραμμα σε σχεσιακό σχήμα (Convert to Relational Schema) και βγάζει SQL ${cite(['L9'], G)}. Παίρνει ως πρωτεύον κλειδί το <i>πρώτο</i> Unique χαρακτηριστικό που τελειώνει σε ID, γι' αυτό τα κλειδιά εδώ λέγονται …ID. Η σειρά μετράει: στο ${entLink('METER')} φτιάξτε το MeterID πριν από το NetworkID, και σχεδιάστε τις ${relLink('MEASURED')} και ${relLink('READ_CODE')} πριν από τη ${relLink('HAS_EDIT')}, αλλιώς το ${entLink('READING_EDIT')} δεν παίρνει όλο το κλειδί του READING. Χαρακτηριστικά συσχέτισης αντιγράφει μόνο από M:N συσχετίσεις ${cite(['D31'], G)}. Οι τύποι δεδομένων και οι περιορισμοί CHECK θέλουν διόρθωση με το χέρι· το πλήρες σχήμα για SQL Server ${cite(['S78'], G)}, με τύπους και περιορισμούς, είναι στη σελίδα του <a href="${SCHEMA_URL}" target="_blank" rel="noopener">βήματος 3</a>. Οι δείκτες (indexes) για την απόδοση ${cite(['S79'], G)} έρχονται στο βήμα 6.</p>
      <p>Κάθε ξένο κλειδί παίρνει το όνομα του κλειδιού που δείχνει, οπότε όπου ένας πίνακας δείχνει σε δύο χρήστες βγαίνουν δύο στήλες <code>UserID</code>. Μετά τη μετατροπή μετονομάστε αυτές τις στήλες (τη στήλη της ${relLink('PARENT_OF')} μόνο για να διαβάζεται πιο εύκολα):</p>
      <div class="tscroll"><table class="fktab"><thead><tr><th>Πίνακας</th><th>Στήλη από τη συσχέτιση</th><th>Νέο όνομα</th></tr></thead><tbody>${fkRels.map(r => `<tr><td><code>${fkTable(r)}</code></td><td>${relLink(r.name)}</td><td><code>${r.fk}</code></td></tr>`).join('')}</tbody></table></div></article>
  </div>
  <p class="gsrc">Πηγές για το ERD+: <a href="https://erdplus.com" target="_blank" rel="noopener">erdplus.com</a> · <a href="https://www.fer.unizg.hr/_download/repository/ERDplus_-_instructions%5B1%5D.pdf" target="_blank" rel="noopener">οδηγίες ERDPlus (FER, παλιός editor)</a> · τα διαγράμματα της δικής σας Άσκησης 1, που δείχνουν πώς τα σχεδιάζει ο τρέχων editor.</p>
</section>`;

  const changesHtml = changes.map((c, i) => `<li id="chg-${i + 1}">${esc(c.text)} ${cite(c.src, { href: `#chg-${i + 1}`, label: `Αλλαγή ${i + 1}` })}</li>`).join('');
  const recheckHtml = recheck.map((c, i) => `<li id="rchk-${i + 1}">${esc(c.text)} ${cite(c.src, { href: `#rchk-${i + 1}`, label: `Δεύτερος έλεγχος ${i + 1}` })}</li>`).join('');
  const fourthHtml = fourth.map((c, i) => `<li id="frth-${i + 1}">${esc(c.text)} ${cite(c.src, { href: `#frth-${i + 1}`, label: `Απλό ER ${i + 1}` })}</li>`).join('');
  const thirdHtml = third.map((c, i) => `<li id="thrd-${i + 1}">${esc(c.text)} ${cite(c.src, { href: `#thrd-${i + 1}`, label: `Τρίτος έλεγχος ${i + 1}` })}</li>`).join('');

  const areaCards = areas.map((a, i) => `<a class="acard" href="#area-${a.id}"><span class="ano">${i + 1}</span><span class="atitle">${esc(a.title)}</span><span class="ameta">${a.entities.length} οντότητες · ${a.rels.length + (a.isa || []).length} συσχετίσεις</span><span class="anames">${a.entities.map(e => e.name).join(' · ')}</span></a>`).join('');

  const areaSections = areas.map((a, i) => {
    const d = diagrams[a.id];
    const svgKeys = d.keys.svg.replace('<svg', `<svg style="--w:${d.keys.w}px" aria-label="${esc(a.title)}: διάγραμμα ER, μόνο κλειδιά"`);
    const svgFull = d.full.svg.replace('<svg', `<svg style="--w:${d.full.w}px" aria-label="${esc(a.title)}: διάγραμμα ER, όλα τα χαρακτηριστικά"`);
    const ents = a.entities.map(e => entityItem(e, a)).join('');
    const rels = (a.isa || []).map((x, k) => isaItem(x, a, k)).join('') + a.rels.map(relItem).join('');
    return `<section class="area" id="area-${a.id}">
  <div class="area-head"><span class="ano big">${i + 1}</span><div><h2>${esc(a.title)}</h2><p class="lead">${esc(a.lead)} ${cite(a.leadSrc, { href: `#area-${a.id}`, label: `${a.title} (εισαγωγή)` })}</p></div></div>
  <div class="diagram" data-view="keys" data-size="fit">
    ${toolbar('Πατήστε ένα ορθογώνιο ή ρόμβο για λεπτομέρειες, πηγές και οδηγίες ERD+')}
    <div class="dscroll"><div class="dv dv-keys">${svgKeys}</div><div class="dv dv-full">${svgFull}</div></div>
  </div>
  <h3>Οντότητες <span class="cnt">${a.entities.length}</span></h3>
  <div class="items">${ents}</div>
  <h3>Συσχετίσεις <span class="cnt">${a.rels.length + (a.isa || []).length}</span></h3>
  <p class="howto">Κάθε γραμμή δείχνει: την οντότητα, την ετικέτα στη γραμμή της στο διάγραμμα, τη συμμετοχή της και τι σημαίνουν.</p>
  <div class="items">${rels}</div>
</section>`;
  }).join('');

  const usedBy = id => {
    const l = backrefs.get(id) || [];
    return l.length ? `<p class="usedby"><span class="lbl">Αναφέρεται από</span> ${l.map(b => `<a href="${b.href}">${esc(b.label)}</a>`).join(', ')}</p>` : '';
  };

  const decHtml = decisions.map(d => `<article class="ref" id="dec-${d.id}"><h4><span class="refid dec">${d.id}</span>${esc(d.title)}</h4><p>${esc(d.text)}</p><p class="basis"><span class="lbl">Βάση</span> ${cite(d.src, { href: `#dec-${d.id}`, label: d.id })}</p>__USED_${d.id}__</article>`).join('');
  const conHtml = conflicts.map(c => `<article class="ref" id="con-${c.id}"><h4><span class="refid con">${c.id}</span>${esc(c.title)}</h4><p>${esc(c.text)}</p><p class="basis"><span class="lbl">Βάση</span> ${cite(c.src, { href: `#con-${c.id}`, label: c.id })}</p>__USED_${c.id}__</article>`).join('');
  const asmHtml = assumptions.map((s, i) => `<li id="asm-${i + 1}">${esc(s.text)} ${cite(s.src, { href: `#asm-${i + 1}`, label: `Παραδοχή ${i + 1}` })}</li>`).join('');

  const header = `<header class="hero" id="top">
  <p class="kicker">Εργασία ΕΠΛ342 · Φάση Α · βήμα 2 · <a href="${SCHEMA_URL}" target="_blank" rel="noopener">βήμα 3: σχεσιακό σχήμα ↗</a></p>
  <h1>Μοντέλο ER του MDMS-Cy</h1>
  <p class="sub">Το διορθωμένο μοντέλο οντοτήτων-συσχετίσεων για την εκφώνηση του MDMS-Cy, σε απλή σημειογραφία Chen ER, χωρίς EER, όπως στη διάλεξη 5. Κάθε οντότητα, συσχέτιση και πληθικότητα παραπέμπει στο απόσπασμα από το οποίο προκύπτει.</p>
  <dl class="stats"><div><dt>${nEnts}</dt><dd>οντότητες</dd></div><div><dt>${nRels}</dt><dd>συσχετίσεις</dd></div><div><dt>${areas.length}</dt><dd>περιοχές</dd></div><div><dt>${nSpec}</dt><dd>αποσπάσματα εκφώνησης</dd></div></dl>
  <div class="keybox">
    <p><b>Πώς διαβάζονται οι παραπομπές.</b> Οι μικρές ετικέτες είναι σύνδεσμοι. Το ${cite(['S16'])} είναι απόσπασμα της εκφώνησης (project.pdf), το ${cite(['L2'])} διαφάνεια διάλεξης, το ${cite(['D4'])} δική μας σχεδιαστική απόφαση εκεί που η εκφώνηση δεν αποφασίζει, και το ${cite(['C2'])} σημείο όπου η εκφώνηση είναι ασαφής ή αντιφάσκει. Σε μεγάλη οθόνη η πηγή ανοίγει στο πλαϊνό πλαίσιο· στο κινητό μεταφέρεστε στη λίστα στο τέλος, με κουμπί επιστροφής.</p>
    <p>Κάθε ελληνικό απόσπασμα ελέγχθηκε λέξη προς λέξη με το PDF. Η Φάση Α παραδίδεται την Παρασκευή 19/10/26 στις 12:00 σύμφωνα με το εξώφυλλο, αλλά η ημερομηνία αυτή είναι Δευτέρα ${cite(['S1', 'C1'], { href: '#top', label: 'Επικεφαλίδα' })}.</p>
  </div>
</header>`;

  const main = `${header}
<section id="changes" class="block"><h2>Τι άλλαξε από το πρώτο προσχέδιο</h2>
  <h3 id="plain-er">Νέο: απλό ER χωρίς EER</h3>
  <p class="lead">Η εκφώνηση ζητά διάγραμμα Chen ER ${cite(['S76', 'S61'], { href: '#plain-er', label: 'Απλό ER' })} και δεν αναφέρει EER· η Άσκηση 1 το είχε πει ρητά: «ER – όχι EER» ${cite(['L14'], { href: '#plain-er', label: 'Απλό ER' })}. Γι' αυτό οι δύο εξειδικεύσεις έγιναν απλό ER, με τον τρόπο της διαφάνειας 6-39 ${cite(['L15'], { href: '#plain-er', label: 'Απλό ER' })}. Οι πίνακες για τους ρόλους μένουν ίδιοι.</p>
  <ol class="changes">${fourthHtml}</ol>
  <h3 id="first-draft">Πρώτο προσχέδιο</h3>
  <p class="lead">Διορθώνουν ισχυρισμούς της <a href="https://claude.ai/code/artifact/cbceac31-1342-43b8-b6a8-fa994cbdb6cd" target="_blank" rel="noopener">λίστας οντοτήτων του βήματος 1</a> που ξεπερνούσαν ή αντέβαιναν την εκφώνηση.</p>
  <ol class="changes">${changesHtml}</ol>
  <h3 id="recheck">Δεύτερος έλεγχος</h3>
  <p class="lead">Μια ανεξάρτητη ανάγνωση της εκφώνησης, περιοχή προς περιοχή, βρήκε μία αντίφαση μέσα στο μοντέλο και αρκετές αδύναμες επιλογές. Όλες έχουν διορθωθεί στα διαγράμματα αυτής της σελίδας.</p>
  <ol class="changes">${recheckHtml}</ol>
  <h3 id="third">Τρίτος έλεγχος</h3>
  <p class="lead">Μια πιο προσεκτική ανάγνωση έψαξε ό,τι μπορεί να ξέφυγε και κάθε κανόνα του μαθήματος. Κάθε πιθανό πρόβλημα το έλεγξαν τρεις ανεξάρτητοι έλεγχοι πάνω στην εκφώνηση και στο μοντέλο, και κρατήθηκαν μόνο όσα επιβεβαιώθηκαν. Στο τέλος, ένας έλεγχος πληρότητας βρήκε ${third.length - 10} ακόμη σημεία, τα τελευταία της λίστας, που ελέγχθηκαν κι αυτά πάνω στην εκφώνηση. Όλα έχουν διορθωθεί σε αυτή τη σελίδα. Όπου η λίστα λέει «υποκλάση», ισχύει πλέον η <a href="#plain-er">αλλαγή σε απλό ER</a>.</p>
  <ol class="changes">${thirdHtml}</ol>
</section>
<section id="notation" class="block"><h2>Σημειογραφία</h2>
  <p class="lead">Chen ER όπως στο βιβλίο Elmasri-Navathe και στις διαφάνειες του ΕΠΛ342. Τα διαγράμματα χρησιμοποιούν ακριβώς αυτά τα σχήματα.</p>
  <div class="legend">${legend}</div>
</section>
${wholeSection}
${erdSection}
<section id="areas" class="block"><h2>Περιοχές</h2>
  <p class="lead">Το ίδιο μοντέλο, χωρισμένο σε ${areas.length} περιοχές ώστε κάθε κομμάτι να διαβάζεται και να ξανασχεδιάζεται χωριστά. Κάθε οντότητα σχεδιάζεται πλήρως στη δική της περιοχή και ως διακεκομμένο ορθογώνιο όπου τη χρησιμοποιεί άλλη περιοχή.</p>
  <div class="acards">${areaCards}</div>
</section>
${areaSections}
<section id="decisions" class="block"><h2>Σχεδιαστικές αποφάσεις</h2>
  <p class="lead">Επιλογές που η εκφώνηση αφήνει ανοιχτές. Η καθεμία λέει σε τι στηρίζεται, ώστε να την αλλάξετε αν το εργαστήριο περιμένει κάτι άλλο.</p>
  <div class="refs">${decHtml}</div>
</section>
<section id="conflicts" class="block"><h2>Αντιφάσεις και ανοιχτά σημεία</h2>
  <p class="lead">Σημεία όπου η εκφώνηση είναι ασαφής ή αντιφάσκει. Αξίζει να ρωτήσετε στο εργαστήριο.</p>
  <div class="refs">${conHtml}</div>
</section>
<section id="assumptions" class="block"><h2>Προσχέδιο παραδοχών για την αναφορά της Φάσης Α</h2>
  <p class="lead">Η αναφορά επιτρέπει το πολύ μισή σελίδα παραδοχών ${cite(['S61'], { href: '#assumptions', label: 'Παραδοχές' })}. Αυτό είναι ένα προσχέδιο που χωράει.</p>
  <ol class="asm">${asmHtml}</ol>
</section>
__SOURCES__`;

  const srcItem = s => `<li class="src" id="src-${s.id}">
  <div class="srchead"><span class="refid ${s.lecture ? 'lec' : 'spec'}">${s.id}</span><span class="where">${esc(s.sec)}${s.page ? ` · σελίδα ${s.page}` : ''}</span>${s.fig ? '<span class="badge fig">από σχήμα</span>' : ''}</div>
  <blockquote lang="el">${esc(s.el)}</blockquote>
  ${s.en ? `<p class="en"><span class="lbl">Τι λέει</span> ${esc(s.en)}</p>` : ''}
  ${usedBy(s.id)}
</li>`;
  const sourcesHtml = `<section id="sources" class="block"><h2>Πηγές</h2>
  <p class="lead">Τα αποσπάσματα της εκφώνησης είναι από το project.pdf (15 σελίδες)· οι αριθμοί σελίδων είναι του PDF. Τα αποσπάσματα διαλέξεων είναι από τις διαφάνειες του ΕΠΛ342. Το «…» σημαίνει ότι παραλείπεται κείμενο ανάμεσα σε δύο μέρη ενός αποσπάσματος.</p>
  <h3>Εκφώνηση</h3><ol class="srcs">${sources.filter(s => !s.lecture).map(srcItem).join('')}</ol>
  <h3>Υλικό μαθήματος</h3><ol class="srcs">${sources.filter(s => s.lecture).map(srcItem).join('')}</ol>
</section>`;

  let body = main.replace('__SOURCES__', sourcesHtml);
  [...decisions, ...conflicts].forEach(d => { body = body.replace(`__USED_${d.id}__`, usedBy(d.id)); });

  return `<title>Μοντέλο ER MDMS-Cy</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
<style>${CSS}</style>
${nav}
<div class="shell">
  <main class="main">${body}</main>
  <aside class="side" aria-label="Λεπτομέρειες" aria-live="polite">
    <div class="side-in">
      <div class="side-bar"><button type="button" class="side-back" hidden>← Πίσω</button><span class="side-kind">Λεπτομέρειες</span></div>
      <div class="side-body"><div class="side-empty"><p><b>Πατήστε μια ετικέτα ή ένα σχήμα.</b></p><p>Οι παραπομπές (${cite(['S9'])} ${cite(['L1'])} ${cite(['D1'])} ${cite(['C2'])}), τα ονόματα οντοτήτων και συσχετίσεων, και τα ορθογώνια και οι ρόμβοι των διαγραμμάτων ανοίγουν εδώ μαζί με τις οδηγίες ERD+, χωρίς να χάνετε τη θέση σας.</p></div></div>
      <a class="side-go" href="#top" hidden>Δείτε το στη σελίδα ↓</a>
    </div>
  </aside>
</div>
<button type="button" class="jump-back" hidden>← Πίσω</button>
<script>${JS}</script>`;
}

instance().then(viz => {
  const diagrams = {}, per = {};
  for (const a of areas) {
    const r = layoutArea(viz, a, allEntities);
    per[a.id] = r;
    diagrams[a.id] = { keys: themeSvg(r.keys, `${a.id}-k`), full: themeSvg(r.full, `${a.id}-f`) };
  }
  const whole = layoutWhole(viz, areas, allEntities, per);
  const html = build(diagrams, { keys: themeSvg(whole.keys, 'all-k'), full: themeSvg(whole.full, 'all-f') });
  fs.writeFileSync('mdms-er.html', html);
  const unused = sources.filter(s => !backrefs.has(s.id)).map(s => s.id);
  fs.writeFileSync('untranslated.json', JSON.stringify([...untranslated], null, 1));
  console.log('written', (html.length / 1024).toFixed(0) + 'KB', 'entities', nEnts, 'rels', nRels, 'uncited sources:', unused.join(' ') || 'none', 'untranslated:', untranslated.size);
});
