// Builds mdms-schema.html (step 3: relational schema for SQL Server) in the style of the ER page.
// Needs: schema.js (mapping), tests.js + test-results.json + test-env.json (from ../runtests.sh), el.json (English -> Greek)
const fs = require('fs');
const { areas, decisions, conflicts } = require('./model.js');
const sources = require('./sources.js');
const { tables, order, ddl, dropDdl, FILTERED, RULES, SDEC } = require('./schema.js');
const { tests } = require('./tests.js');
const { parseAttr } = require('./diagram.js');
const { CSS, JS } = require('./page.js');

const ER_URL = process.env.ER_URL || 'https://claude.ai/artifact/8m249QKjvQKEdPWzo1HdbW';
const EL = JSON.parse(fs.readFileSync('./el.json', 'utf8'));
const untranslated = new Set();
const T = s => { if (!s) return s; if (EL[s]) return EL[s]; untranslated.add(s); return s; };
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// ---------- test results must all pass before the page may say so ----------
const results = JSON.parse(fs.readFileSync('test-results.json', 'utf8'));
const env = JSON.parse(fs.readFileSync('test-env.json', 'utf8'));
if (results.length !== tests.length) throw new Error(`test-results.json has ${results.length} results for ${tests.length} tests: run ../runtests.sh`);
results.forEach((r, i) => {
  if (r.expected !== tests[i].expect) throw new Error(`test ${i + 1} changed since it was run: run ../runtests.sh`);
  r.pass = r.expected === 'OK' ? r.got === 'OK' : r.got.includes(r.expected);
  if (!r.pass) throw new Error(`test ${i + 1} failed: ${r.got}`);
  r.hit = r.got === 'OK' ? null : (r.got.match(/\b(PK|UQ|UX|FK|CK)_[A-Za-z0-9_]+/) || [])[0];
});
if (fs.readFileSync('create.sql', 'utf8') !== ddl) throw new Error('create.sql is older than schema.js: run node schema.js and ../runtests.sh');
if (env.counts.tables !== tables.size || env.afterDrop !== 0 || env.afterRecreate !== tables.size) throw new Error('test-env.json does not match the schema');
const testSql = fs.readFileSync('test.sql', 'utf8');

// ---------- citations (same chips as the ER page; T1..T10 are schema conventions) ----------
const srcById = new Map(sources.map(s => [s.id, s]));
const decById = new Map(decisions.map(d => [d.id, d]));
const conById = new Map(conflicts.map(c => [c.id, c]));
const sdecById = new Map(SDEC.map(d => [d.id, d]));
const anchorOf = id => ({ D: `dec-${id}`, C: `con-${id}`, T: `sdec-${id}` })[id[0]] || `src-${id}`;
const kindOf = id => ({ S: 'spec', L: 'lec', D: 'dec', C: 'con', T: 'dec' })[id[0]];
const exists = id => srcById.has(id) || decById.has(id) || conById.has(id) || sdecById.has(id);
const tipOf = id => {
  if (id[0] === 'D') return `Σχεδιαστική απόφαση: ${T(decById.get(id).title)}`;
  if (id[0] === 'C') return `Αντίφαση ή ανοιχτό σημείο: ${T(conById.get(id).title)}`;
  if (id[0] === 'T') return `Σύμβαση σχήματος: ${T(sdecById.get(id).title)}`;
  const s = srcById.get(id);
  return s.lecture ? T(s.sec) : `Εκφώνηση ${T(s.sec)}, σελίδα ${s.page}`;
};
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

// ---------- model facts ----------
const ents = new Map(); const rels = new Map(); const areaOf = new Map(areas.map(a => [a.id, a]));
areas.forEach(a => { a.entities.forEach(e => ents.set(e.name, e)); a.rels.forEach(r => rels.set(r.name, r)); });
const all = [...tables.values()];
const nCols = all.reduce((s, t) => s + t.cols.length, 0);
const nFks = all.reduce((s, t) => s + t.fks.length, 0);
const nChecks = all.reduce((s, t) => s + t.checks.length + t.cols.filter(c => c.fixed || c.chk).length, 0);
const nUq = all.reduce((s, t) => s + t.uniques.length, 0);
const relsAll = [...rels.values()];
const one = r => r.ends.every(x => x.card === '1');
const mn = r => r.ends.every(x => x.card !== '1');
const ratio = r => one(r) ? '1:1' : mn(r) ? 'M:N' : '1:N';
const count = {
  entity: all.filter(t => t.kind === 'entity').length,
  weak: all.filter(t => t.kind === 'weak').length,
  roles: all.filter(t => t.kind === 'weak' && /^IS_/.test((t.from.owners || [])[0] && t.from.owners[0].rel)).length,
  ident: relsAll.filter(r => r.ident).length,
  r11: relsAll.filter(r => !r.ident && one(r)).length,
  r1n: relsAll.filter(r => !r.ident && !one(r) && !mn(r)).length,
  rmn: relsAll.filter(mn).length,
  multi: all.filter(t => t.kind === 'multi').length,
  comp: [...ents.values()].reduce((s, e) => s + e.attrs.map(parseAttr).filter(a => a.parts).length, 0)
};
if (count.entity + count.weak + count.rmn + count.multi !== tables.size) throw new Error('mapping counts do not add up');

const tLink = n => `<a class="ent-link" href="#t-${n}">${n}</a>`;
const kindBadge = t => ({ entity: 'οντότητα', weak: 'ασθενής οντότητα', mn: 'συσχέτιση M:N', multi: 'πλειότιμο χαρακτηριστικό' })[t.kind];
const HOW = { 'procedure': 'stored procedure', 'trigger': 'trigger', 'procedure + trigger': 'stored procedure + trigger' };

// ---------- one table ----------
function colCell(t, c) {
  const bits = [];
  if (c.pk) bits.push('<span class="k pk">PK</span>');
  const fk = t.fks.find(f => f.cols.includes(c.name));
  if (fk) bits.push(`<span class="k fk">FK</span> → ${tLink(fk.ref)}<span class="dim">.${fk.refCols[fk.cols.indexOf(c.name)]}</span>`);
  const uq = t.uniques.find(u => u.cols.length === 1 && u.cols[0] === c.name);
  if (uq) bits.push('<span class="k uq">UNIQUE</span>');
  if (c.id) bits.push('<span class="k">IDENTITY</span>');
  if (c.def) bits.push(`<span class="dim">DEFAULT</span> <code>${esc(c.def)}</code>`);
  if (c.fixed) bits.push(`<span class="dim">τιμές</span> ${c.fixed.map(v => `<code class="val">${esc(v)}</code>`).join(' ')}`);
  if (c.chk) bits.push(`<span class="dim">CHECK</span> <code>${esc(c.chk)}</code>`);
  return bits.join(' ');
}
function fkWhy(t, f) {
  const r = rels.get(f.rel);
  const kind = t.kind === 'mn' ? `M:N ${f.rel}` : t.kind === 'multi' ? 'πλειότιμο χαρακτηριστικό' : r ? `${ratio(r)} ${f.rel}${r.ident ? ', προσδιορίζουσα' : ''}` : f.rel;
  const nul = t.cols.find(c => c.name === f.cols[0]).nul;
  return `<li><code class="cn">${f.name}</code> <span class="mono">(${f.cols.join(', ')})</span> → ${tLink(f.ref)}<span class="dim"> (${f.refCols.join(', ')})</span>. Από ${kind}${t.kind === 'entity' || t.kind === 'weak' ? (nul ? '· NULL, γιατί η συμμετοχή είναι μερική' : '· NOT NULL, γιατί η συμμετοχή είναι ολική') : ''}${f.onDelete === 'CASCADE' ? '· <b>ON DELETE CASCADE</b>' : ''}.</li>`;
}
function tableItem(t) {
  const from = { href: `#t-${t.name}`, label: t.name };
  const src = t.kind === 'mn' ? rels.get(t.from.rel).src : ents.get(t.from.entity).src;
  const origin = t.kind === 'mn' ? `τη συσχέτιση <code>${t.from.rel}</code>` : t.kind === 'multi' ? `το χαρακτηριστικό <code>{${t.from.attr}}</code> του ${tLink(t.from.entity)}` : `την οντότητα <code>${t.from.entity}</code>`;
  const owners = t.from.owners ? `<span class="owners">ιδιοκτήτης: ${t.from.owners.map(o => `${tLink(o.owner)} <span class="dim">μέσω ${o.rel}</span>`).join(', ')}</span>` : '';
  const rows = t.cols.map(c => `<tr><td><code class="${c.pk ? 'pkc' : ''}">${c.name}</code></td><td><code class="ty">${esc(c.type)}</code></td><td class="nul">${c.nul ? 'NULL' : 'NOT NULL'}</td><td class="kc">${colCell(t, c)}</td></tr>`).join('');
  const cons = [];
  t.uniques.filter(u => u.cols.length > 1 || t.fks.some(f => f.cols.join() === u.cols.join())).forEach(u => cons.push(`<li><code class="cn">UQ_${t.name}_${u.cols.join('_')}</code> <span class="mono">UNIQUE (${u.cols.join(', ')})</span>. ${esc(T(u.why))} ${cite(u.src, from)}</li>`));
  FILTERED.filter(f => f.table === t.name).forEach(f => cons.push(`<li><code class="cn">${f.name}</code> <span class="mono">UNIQUE (${f.cols.join(', ')}) WHERE ${esc(f.where)}</span>. ${esc(T(f.why))} ${cite(f.src, from)}</li>`));
  t.checks.forEach(c => cons.push(`<li><code class="cn">${c.name}</code> ${esc(T(c.why))} ${cite(c.src, from)}<pre class="ck"><code>${esc(c.e.replace(/\n\s*/g, '\n'))}</code></pre></li>`));
  const fkl = t.fks.map(f => fkWhy(t, f)).join('');
  const ddlOne = ddl.split('\nGO\n').find(b => b.includes(`CREATE TABLE ${t.name} (`)).replace(/^\s*-- .*\n/, '').trim();
  return `<article class="item tbl" id="t-${t.name}">
  <div class="item-l"><code class="nm">${t.name}</code><div class="badges"><span class="badge${t.kind === 'weak' ? ' weak' : ''}">${kindBadge(t)}</span>${owners}</div>
    <span class="from">από ${origin}</span>${cite(src, from)}</div>
  <div class="item-r">
    <div class="tscroll"><table class="cols"><thead><tr><th>Στήλη</th><th>Τύπος</th><th>NULL</th><th>Κλειδιά και περιορισμοί</th></tr></thead><tbody>${rows}</tbody></table></div>
    ${fkl ? `<p class="sub-h">Ξένα κλειδιά</p><ul class="cons">${fkl}</ul>` : ''}
    ${cons.length ? `<p class="sub-h">Περιορισμοί γραμμής</p><ul class="cons">${cons.join('')}</ul>` : ''}
    <details class="ddl"><summary>CREATE TABLE</summary><pre><code>${esc(ddlOne)}</code></pre></details>
  </div>
</article>`;
}

// ---------- page ----------
const roleTables = all.filter(t => t.kind === 'weak' && (t.from.owners || []).some(o => /^IS_/.test(o.rel)));
if (roleTables.length !== 7) throw new Error('expected 7 role tables');
const P = id => ({ href: `#${id}`, label: ({ eer: 'ER ή EER', mapping: 'Κανόνες μετατροπής', sql: 'Αρχεία SQL', tests: 'Έλεγχος', rules: 'Φάση Β', top: 'Επικεφαλίδα' })[id] });

const nav = `<nav class="toc" aria-label="Ενότητες"><div class="toc-in">
  <a class="brand" href="#top">MDMS-Cy σχήμα</a>
  <a href="#eer">ER ή EER</a><a href="#mapping">Μετατροπή</a><a href="#conventions">Συμβάσεις</a><a href="#tables">Πίνακες</a><a href="#rules">Φάση Β</a><a href="#tests">Έλεγχος</a><a href="#sql">Αρχεία SQL</a><a href="#decisions">Αποφάσεις</a><a href="#sources">Πηγές</a>
</div></nav>`;

const [ver, cu, edition] = env.version.split('|');
const nPass = results.filter(r => r.pass).length;
const hero = `<header class="hero" id="top">
  <p class="kicker">Εργασία ΕΠΛ342 · Φάση Α · βήμα 3 · <a href="${ER_URL}" target="_blank" rel="noopener">βήμα 2: μοντέλο ER ↗</a></p>
  <h1>Σχεσιακό σχήμα του MDMS-Cy</h1>
  <p class="sub">Το μοντέλο ER του βήματος 2, σε απλό ER χωρίς EER, μεταφρασμένο σε πίνακες για Microsoft SQL Server με τύπους T-SQL, πρωτεύοντα και ξένα κλειδιά, NOT NULL, UNIQUE και CHECK. Το σχήμα τρέχει σε SQL Server 2025 και κάθε περιορισμός δοκιμάστηκε.</p>
  <dl class="stats"><div><dt>${tables.size}</dt><dd>πίνακες</dd></div><div><dt>${nCols}</dt><dd>στήλες</dd></div><div><dt>${nFks}</dt><dd>ξένα κλειδιά</dd></div><div><dt>${nChecks}</dt><dd>περιορισμοί CHECK</dd></div><div><dt>${nUq + FILTERED.length}</dt><dd>UNIQUE</dd></div><div><dt>${nPass}/${results.length}</dt><dd>δοκιμές πέρασαν</dd></div></dl>
  <div class="keybox">
    <p><b>Για το έγγραφο της Φάσης Α.</b> Η εκφώνηση ζητά το σχεσιακό σχήμα σε ANSI ή T-SQL, με τύπους, πρωτεύοντα και ξένα κλειδιά και περιορισμούς ${cite(['S77', 'S61'], P('top'))}. Το <a href="#sql">create.sql</a> είναι ακριβώς αυτό, σε T-SQL. Οι πίνακες πιο κάτω εξηγούν κάθε στήλη και κάθε περιορισμό, ώστε να γράψετε τις εξηγήσεις και τις παραδοχές.</p>
    <p>Οι ετικέτες είναι σύνδεσμοι, όπως στη σελίδα του μοντέλου: ${cite(['S78'])} απόσπασμα της εκφώνησης, ${cite(['L16'])} υλικό του μαθήματος, ${cite(['D2'])} σχεδιαστική απόφαση του μοντέλου και ${cite(['T3'])} σύμβαση αυτού του σχήματος.</p>
  </div>
</header>`;

const eer = `<section id="eer" class="block"><h2>ER ή EER: τι ζητείται και τι αλλάζει</h2>
  <div class="answer">
    <p class="ans-h">Η εκφώνηση ζητά απλό Chen ER.</p>
    <p>Η Φάση Α είναι «Εννοιολογική Σχεδίαση με Χρήση του Διαγράμματος Chen ER» και το παραδοτέο είναι «Διάγραμμα Οντοτήτων Συσχετίσεων (ER)» ${cite(['S76', 'S61'], P('eer'))}. Η λέξη EER δεν εμφανίζεται πουθενά. Η Άσκηση 1 το είχε πει ρητά: «το απλούστερο δυνατό εννοιολογικό μοντέλο (ER) – όχι EER» ${cite(['L14'], P('eer'))}. Το EER δεν απαγορεύεται ρητά, και το ERD+ σχεδιάζει και EER ${cite(['L9'], P('eer'))}, αλλά το απλό ER είναι η ασφαλής επιλογή. Γι' αυτό το μοντέλο έγινε απλό ER ${cite(['D32'], P('eer'))}.</p>
    <p>Στο σχήμα η διαφορά είναι μικρή. Η διαφάνεια 6-39 λέει ότι κάθε EER γράφεται σε ER, με κάποια απώλεια νοήματος που τη χειρίζεται το πρόγραμμα της βάσης ${cite(['L15'], P('eer'))}. Εδώ χάνεται ένας μόνο κανόνας, και πάει στη Φάση Β.</p>
  </div>
  <div class="tscroll"><table class="fktab cmp"><thead><tr><th></th><th>Με EER (πριν)</th><th>Με απλό ER (τώρα)</th><th>Πίνακες</th></tr></thead><tbody>
    <tr><th>Ρόλοι χρηστών</th><td>Εξειδίκευση του USER_ACCOUNT (o, ολική) σε 7 υποκλάσεις</td><td>7 ασθενείς οντότητες, η καθεμία με Identifying 1:1 από το USER_ACCOUNT ${cite(['D2'], P('eer'))}</td><td><b>Ίδιοι.</b> ${roleTables.map(t => tLink(t.name)).join(', ')} έχουν κλειδί το <code>UserID</code>, που είναι και ξένο κλειδί στο ${tLink('USER_ACCOUNT')}. Αυτό δίνει και η επιλογή 8A του Elmasri για εξειδίκευση ${cite(['L16'], P('eer'))}.</td></tr>
    <tr><th>Προμηθευτές και aggregators</th><td>MARKET_PARTICIPANT (d, ολική) σε SUPPLIER και AGGREGATOR</td><td>Δύο οντότητες, με WORKS_FOR_SUPPLIER και WORKS_FOR_AGGREGATOR ${cite(['D30'], P('eer'))}</td><td><b>Ίδιοι με την επιλογή 8B</b> (μόνο πίνακες υποκλάσεων, που επιτρέπεται για ξένη και ολική εξειδίκευση): ${tLink('SUPPLIER')}, ${tLink('AGGREGATOR')}, και το ${tLink('MARKET_USER')} με δύο ξένα κλειδιά και CHECK «ακριβώς ένα».</td></tr>
    <tr><th>Τι χάνεται</th><td>Η ολική εξειδίκευση λέει ότι κάθε λογαριασμός έχει ρόλο</td><td>Το διάγραμμα δεν το δείχνει</td><td>Ένα CHECK δεν το εκφράζει. Γίνεται <a href="#rule-1">stored procedure και trigger</a> στη Φάση Β.</td></tr>
  </tbody></table></div>
</section>`;

const mapRows = [
  ['Κανονική οντότητα', 'Πίνακας με τα απλά χαρακτηριστικά της. Πρωτεύον κλειδί το κλειδί της· τα εναλλακτικά κλειδιά γίνονται UNIQUE.', count.entity + ' πίνακες', 'METER'],
  ['Ασθενής οντότητα', 'Πίνακας με κλειδί το κλειδί του ιδιοκτήτη μαζί με το μερικό κλειδί, και ξένο κλειδί στον ιδιοκτήτη. Οι 7 ρόλοι δεν έχουν μερικό κλειδί, άρα κλειδί τους είναι μόνο το UserID.', `${count.weak} πίνακες (${count.roles} ρόλοι)`, 'READING'],
  ['Προσδιορίζουσα συσχέτιση', 'Δεν δίνει δικό της πίνακα ή στήλη: είναι το ξένο κλειδί της ασθενούς οντότητας, μέρος του κλειδιού της.', count.ident + ' συσχετίσεις', 'READING_EDIT'],
  ['Συσχέτιση 1:1', 'Ξένο κλειδί UNIQUE στον πίνακα της πλευράς με ολική συμμετοχή, NOT NULL.', count.r11 + ' συσχετίσεις', 'METER_INSTALLATION'],
  ['Συσχέτιση 1:N', 'Ξένο κλειδί στον πίνακα της πλευράς N, NOT NULL όταν αυτή η πλευρά συμμετέχει ολικά.', count.r1n + ' συσχετίσεις', 'PREMISE'],
  ['Συσχέτιση M:N', 'Δικός της πίνακας με κλειδί τα δύο ξένα κλειδιά, και τα χαρακτηριστικά της συσχέτισης.', count.rmn + ' πίνακες', 'INCLUDES'],
  ['Πλειότιμο χαρακτηριστικό', 'Δικός του πίνακας με κλειδί το κλειδί της οντότητας μαζί με την τιμή.', count.multi + ' πίνακες', 'METER_CONNECTED_PHASE'],
  ['Σύνθετο χαρακτηριστικό', 'Μόνο τα μέρη του γίνονται στήλες.', count.comp + ' χαρακτηριστικά', 'AVAILABILITY']
];
const mapping = `<section id="mapping" class="block"><h2>Από το ER στους πίνακες</h2>
  <p class="lead">Ο αλγόριθμος μετατροπής του βιβλίου του μαθήματος (Elmasri-Navathe, κεφάλαιο 9), βήμα προς βήμα ${cite(['L16', 'T1'], P('mapping'))}. Το σχήμα παράγεται από τα ίδια δεδομένα με τα διαγράμματα του βήματος 2, οπότε τα δύο δεν μπορούν να διαφέρουν. ${count.entity} + ${count.weak} + ${count.rmn} + ${count.multi} = ${tables.size} πίνακες.</p>
  <div class="tscroll"><table class="fktab maptab"><thead><tr><th>Στο ER</th><th>Στο σχεσιακό σχήμα</th><th>Πόσα</th><th>Παράδειγμα</th></tr></thead><tbody>
    ${mapRows.map(r => `<tr><td><b>${r[0]}</b></td><td>${r[1]}</td><td class="num">${r[2]}</td><td>${tLink(r[3])}</td></tr>`).join('')}
  </tbody></table></div>
</section>`;

const conventions = `<section id="conventions" class="block"><h2>Συμβάσεις του σχήματος</h2>
  <p class="lead">Επιλογές που το ER δεν ορίζει: τύποι, ονόματα, τι γίνεται σε διαγραφή, τι μένει για τη Φάση Β. Η καθεμία λέει σε τι στηρίζεται.</p>
  <div class="refs">${SDEC.map(d => `<article class="ref" id="sdec-${d.id}"><h4><span class="refid dec">${d.id}</span>${esc(T(d.title))}</h4><p>${esc(T(d.text))}</p><p class="basis"><span class="lbl">Βάση</span> ${cite(d.src, { href: `#sdec-${d.id}`, label: d.id })}</p>__USED_${d.id}__</article>`).join('')}</div>
</section>`;

const byArea = areas.map(a => ({ a, list: order.filter(t => t.area === a.id) })).filter(x => x.list.length);
if (byArea.reduce((s, x) => s + x.list.length, 0) !== tables.size) throw new Error('a table has no area');
const relNotation = t => `<li><a href="#t-${t.name}" class="rn"><b>${t.name}</b>(${t.cols.map(c => { const fk = t.fks.some(f => f.cols.includes(c.name)); const n = fk ? `<i>${c.name}</i>` : c.name; return c.pk ? `<u>${n}</u>` : n; }).join(', ')})</a></li>`;
const tablesSec = `<section id="tables" class="block"><h2>Πίνακες</h2>
  <p class="lead">Οι πίνακες με τη σειρά του create.sql, ώστε κάθε ξένο κλειδί να δείχνει σε πίνακα που υπάρχει ήδη, ομαδοποιημένοι στις περιοχές του μοντέλου. Πατήστε ένα όνομα πίνακα για να ανοίξει στο πλάι.</p>
  <h3 id="glance">Με μια ματιά</h3>
  <p class="howto">Σημειογραφία του βιβλίου: <u>υπογράμμιση</u> για το πρωτεύον κλειδί, <i>πλάγια</i> για ξένο κλειδί.</p>
  <div class="glance">${byArea.map(({ a, list }) => `<div class="gl-area"><p class="gl-h">${esc(T(a.title))}</p><ul>${list.map(relNotation).join('')}</ul></div>`).join('')}</div>
  ${byArea.map(({ a, list }, i) => `<div class="tarea" id="ta-${a.id}"><div class="area-head"><span class="ano big">${areas.indexOf(a) + 1}</span><div><h2>${esc(T(a.title))}</h2><p class="lead">${list.length} πίνακες</p></div></div><div class="items">${list.map(tableItem).join('')}</div></div>`).join('')}
</section>`;

const rulesSec = `<section id="rules" class="block"><h2>Κανόνες για τη Φάση Β</h2>
  <p class="lead">Ένα CHECK στον SQL Server βλέπει μόνο τη δική του γραμμή ${cite(['T9'], P('rules'))}. Οι κανόνες που διαβάζουν άλλες γραμμές ή άλλους πίνακες γίνονται triggers ή stored procedures στη Φάση Β, που η εκφώνηση θέλει έτσι κι αλλιώς μέσα στη βάση ${cite(['S78'], P('rules'))}. Μπαίνουν και στις παραδοχές του εγγράφου, ως περιορισμοί που το σχήμα δεν επιβάλλει ακόμη.</p>
  <ol class="rules">${RULES.map((r, i) => `<li id="rule-${i + 1}"><span class="badge how">${HOW[r.how] || r.how}</span> <span class="rarea">${esc(T(areaOf.get(r.area).title))}</span><p>${esc(T(r.text))} ${cite(r.src, { href: `#rule-${i + 1}`, label: `Κανόνας ${i + 1}` })}</p></li>`).join('')}</ol>
</section>`;

const expTxt = e => e === 'OK' ? '<span class="pill ok">περνά</span>' : e === 'REFERENCE constraint' ? '<span class="pill no">απορρίπτεται</span> <span class="dim">από ξένο κλειδί (NO ACTION)</span>' : `<span class="pill no">απορρίπτεται</span> <code class="cn">${e}</code>`;
const gotTxt = r => r.got === 'OK' ? '✓ πέρασε' : `✓ σταμάτησε στο <code class="cn">${r.hit}</code>`;
const testsSec = `<section id="tests" class="block"><h2>Έλεγχος σε SQL Server 2025</h2>
  <p class="lead">Το σχήμα έτρεξε σε Microsoft SQL Server 2025 (${esc(edition)}, έκδοση ${esc(ver)}, ${esc(cu)}) στις ${env.date.split('-').reverse().join('/')}, σε κενή βάση.</p>
  <ul class="checks">
    <li><b>create.sql</b> έτρεξε χωρίς λάθος: ${env.counts.tables} πίνακες, ${env.counts.columns} στήλες, ${env.counts['primary keys']} πρωτεύοντα κλειδιά, ${env.counts['foreign keys']} ξένα κλειδιά, ${env.counts.checks} CHECK, ${env.counts['unique constraints']} UNIQUE και ${env.counts['filtered unique indexes']} φιλτραρισμένοι δείκτες UNIQUE, ${env.counts.defaults} DEFAULT. Ίδια νούμερα με το σχήμα αυτής της σελίδας.</li>
    <li><b>drop.sql</b> έσβησε όλους τους πίνακες (έμειναν ${env.afterDrop}), και το create.sql ξανάτρεξε μετά (${env.afterRecreate} πίνακες).</li>
    <li><b>${results.length} δοκιμές</b> πάνω σε δείγμα δεδομένων: όσες έπρεπε να περάσουν πέρασαν, και κάθε λάθος εισαγωγή σταμάτησε στον περιορισμό που την αφορά. Κάθε δοκιμή τρέχει σε δική της συναλλαγή που αναιρείται, οπότε δεν επηρεάζει την επόμενη.</li>
  </ul>
  <div class="tscroll"><table class="fktab ttab"><thead><tr><th>#</th><th>Δοκιμή</th><th>Περιμένουμε</th><th>Αποτέλεσμα</th></tr></thead><tbody>
    ${tests.map((t, i) => `<tr><td class="num">${i + 1}</td><td>${esc(t.el)}<details class="tsql"><summary>SQL</summary><pre><code>${esc(t.sql.replace(/;\s+/g, ';\n'))}</code></pre></details></td><td>${expTxt(t.expect)}</td><td class="res">${gotTxt(results[i])}</td></tr>`).join('')}
  </tbody></table></div>
</section>`;

const sqlBlock = (id, name, text, note) => `<div class="sqlfile"><div class="sqlbar"><code class="fname">${name}</code><span class="dim">${text.split('\n').length} γραμμές</span><button type="button" class="copy" data-copy="${id}">Αντιγραφή</button></div>
  <p class="sqlnote">${note}</p>
  <details class="ddl big"><summary>Δείτε όλο το αρχείο</summary><pre><code id="${id}">${esc(text)}</code></pre></details></div>`;
const sqlSec = `<section id="sql" class="block"><h2>Αρχεία SQL</h2>
  <p class="lead">Ανοίξτε ένα αρχείο στο SSMS ή στο Azure Data Studio και τρέξτε το σε κενή βάση. Στο sqlcmd δώστε <code>-I</code>, γιατί οι φιλτραρισμένοι δείκτες UNIQUE θέλουν <code>QUOTED_IDENTIFIER ON</code> ${cite(['T9'], P('sql'))}.</p>
  ${sqlBlock('f-create', 'create.sql', ddl, 'Δημιουργεί τους ' + tables.size + ' πίνακες με όλους τους περιορισμούς. Αυτό είναι το σχεσιακό σχήμα για το έγγραφο.')}
  ${sqlBlock('f-drop', 'drop.sql', dropDdl, 'Σβήνει όλους τους πίνακες με την αντίστροφη σειρά, ώστε να ξανατρέξετε το create.sql.')}
  ${sqlBlock('f-test', 'test.sql', testSql, 'Το δείγμα δεδομένων και οι ' + tests.length + ' δοκιμές του ελέγχου. Τρέχει μετά το create.sql και τυπώνει τα αποτελέσματα ως JSON.')}
</section>`;

let body = [hero, eer, mapping, conventions, tablesSec, rulesSec, testsSec, sqlSec].join('\n');

// decisions cited on this page, and the decisions and sources they cite in turn
const usedBy = id => { const l = backrefs.get(id) || []; return l.length ? `<p class="usedby"><span class="lbl">Αναφέρεται από</span> ${l.map(b => `<a href="${b.href}">${esc(b.label)}</a>`).join(', ')}</p>` : ''; };
const shownDec = new Set();
for (let grew = true; grew;) {
  grew = false;
  for (const id of [...backrefs.keys()].filter(x => /^[DC]/.test(x))) if (!shownDec.has(id)) {
    shownDec.add(id); grew = true;
    const d = decById.get(id) || conById.get(id);
    cite(d.src, { href: `#${anchorOf(id)}`, label: id });
  }
}
const decList = [...decisions, ...conflicts].filter(d => shownDec.has(d.id));
const decSec = `<section id="decisions" class="block"><h2>Αποφάσεις του μοντέλου που χρησιμοποιεί το σχήμα</h2>
  <p class="lead">Οι σχεδιαστικές αποφάσεις του βήματος 2 στις οποίες στηρίζεται αυτή η σελίδα. Όλες είναι και στη <a href="${ER_URL}" target="_blank" rel="noopener">σελίδα του μοντέλου</a>.</p>
  <div class="refs">${decList.map(d => `<article class="ref" id="${anchorOf(d.id)}"><h4><span class="refid ${kindOf(d.id)}">${d.id}</span>${esc(T(d.title))}</h4><p>${esc(T(d.text))}</p><p class="basis"><span class="lbl">Βάση</span> ${cite(d.src)}</p>__USED_${d.id}__</article>`).join('')}</div>
</section>`;
const srcItem = s => `<li class="src" id="src-${s.id}">
  <div class="srchead"><span class="refid ${s.lecture ? 'lec' : 'spec'}">${s.id}</span><span class="where">${esc(T(s.sec))}${s.page ? ` · σελίδα ${s.page}` : ''}</span>${s.fig ? '<span class="badge fig">από σχήμα</span>' : ''}</div>
  <blockquote lang="el">${esc(s.el)}</blockquote>
  ${s.en ? `<p class="en"><span class="lbl">Τι λέει</span> ${esc(T(s.en))}</p>` : ''}
  ${usedBy(s.id)}
</li>`;
const shownSrc = sources.filter(s => backrefs.has(s.id));
const srcSec = `<section id="sources" class="block"><h2>Πηγές</h2>
  <p class="lead">Τα αποσπάσματα που χρησιμοποιεί αυτή η σελίδα, από το project.pdf και τις διαφάνειες του ΕΠΛ342, ελεγμένα λέξη προς λέξη όπως στη σελίδα του μοντέλου.</p>
  <h3>Εκφώνηση</h3><ol class="srcs">${shownSrc.filter(s => !s.lecture).map(srcItem).join('')}</ol>
  <h3>Υλικό μαθήματος</h3><ol class="srcs">${shownSrc.filter(s => s.lecture).map(srcItem).join('')}</ol>
</section>`;
body += '\n' + decSec + '\n' + srcSec;
[...SDEC, ...decList].forEach(d => { body = body.replace(`__USED_${d.id}__`, usedBy(d.id)); });
if (/__USED_/.test(body)) throw new Error('unfilled back-reference');
const unknownLinks = [...body.matchAll(/href="#([^"]+)"/g)].map(m => m[1]).filter(id => !body.includes(`id="${id}"`));
if (unknownLinks.length) throw new Error('links to missing ids: ' + [...new Set(unknownLinks)].join(' '));

const SCHEMA_CSS = `
:root{--ok-fg:#166534;--ok-bg:#dcfce7;--no-fg:#9a3412;--no-bg:#ffedd5;--code-bg:#f3f4f0}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--ok-fg:#86efac;--ok-bg:#14532d;--no-fg:#fdba74;--no-bg:#4a2310;--code-bg:#161b20}}
:root[data-theme="dark"]{--ok-fg:#86efac;--ok-bg:#14532d;--no-fg:#fdba74;--no-bg:#4a2310;--code-bg:#161b20}
.toc{top:env(safe-area-inset-top,0px)}
h1,h2{text-wrap:balance}
.answer{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:16px 18px;max-width:80ch;margin:12px 0 16px}
.answer p{margin:0 0 10px}.answer p:last-child{margin:0}
.ans-h{font-size:19px;font-weight:700}
.cmp th[scope],.cmp tbody th{font-size:14px;text-transform:none;letter-spacing:0;color:var(--text);vertical-align:top;min-width:9em}
.cmp td{vertical-align:top;min-width:13em}
.maptab td{vertical-align:top}.maptab td:nth-child(2){min-width:18em}
.num{font-variant-numeric:tabular-nums;white-space:nowrap}
.glance{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,380px),1fr));gap:10px 18px;margin:0 0 8px}
.gl-area{min-width:0}
.gl-h{margin:10px 0 4px;font-weight:600;font-size:14px}
.glance ul{list-style:none;margin:0;padding:0}
.glance li{margin:0 0 3px}
.rn{font:12.5px/1.5 var(--mono);color:var(--muted);text-decoration:none;overflow-wrap:anywhere}
.rn b{color:var(--text);font-weight:600}.rn:hover b{color:var(--accent)}
.rn u{text-underline-offset:2px;color:var(--text)}
.tarea{padding-top:28px}
.tarea .area-head h2{font-size:21px}
.tarea .area-head .lead{margin:2px 0 6px}
.item.tbl{grid-template-columns:minmax(0,14rem) minmax(0,1fr)}
@media (max-width:700px){.item.tbl{grid-template-columns:minmax(0,1fr)}}
.from{font-size:13px;color:var(--muted)}
.from code{font-size:12.5px}
.cols{border-collapse:collapse;width:100%;font-size:13.5px}
.cols th,.cols td{text-align:left;padding:5px 8px;border-bottom:1px solid var(--border);vertical-align:top}
.cols th{font-size:11.5px;text-transform:uppercase;letter-spacing:.05em;color:var(--faint);font-weight:600}
.cols td:first-child code{font-weight:500}
.cols code.pkc{text-decoration:underline;text-underline-offset:3px;font-weight:700}
.ty{color:var(--er-card);white-space:nowrap}
.nul{font:12px var(--mono);color:var(--muted);white-space:nowrap}
.kc{min-width:14em;line-height:1.7}
.kc code{font-size:12.5px;overflow-wrap:anywhere}
.k{display:inline-block;font:600 10.5px/1 var(--mono);padding:3px 5px;border-radius:4px;border:1px solid var(--border-2);color:var(--muted);vertical-align:1px}
.k.pk{background:var(--accent);border-color:var(--accent);color:var(--surface)}
.k.fk{background:var(--accent-soft);border-color:var(--accent-soft);color:var(--accent)}
.k.uq{color:var(--text)}
.val{background:var(--surface-2);border-radius:3px;padding:0 3px}
.dim{color:var(--faint);font-size:12.5px}
.sub-h{margin:12px 0 4px;font:600 11.5px/1 var(--sans);text-transform:uppercase;letter-spacing:.05em;color:var(--faint)}
.cons{margin:0;padding-left:18px;font-size:14px;max-width:85ch}
.cons li{margin:0 0 6px}
.cn{font-size:12.5px;font-weight:600;color:var(--text)}
.mono{font:12.5px var(--mono);color:var(--muted)}
pre{margin:6px 0 0;background:var(--code-bg);border:1px solid var(--border);border-radius:8px;padding:10px 12px;overflow:auto;font:12.5px/1.55 var(--mono);color:var(--text);tab-size:4}
pre.ck{margin:4px 0 2px;padding:6px 10px;white-space:pre-wrap;overflow-wrap:anywhere}
pre code{font:inherit}
.ddl{margin:10px 0 2px}
.ddl summary,.tsql summary{cursor:pointer;font:500 13px/1.4 var(--sans);color:var(--accent);width:max-content;max-width:100%}
.ddl summary:focus-visible,.tsql summary:focus-visible{outline:2px solid var(--accent);outline-offset:2px;border-radius:3px}
.ddl.big pre{max-height:70vh}
.tsql{margin-top:4px}.tsql summary{font-size:12px}
.tsql pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}
.rules{margin:0;padding:0 0 0 26px;max-width:85ch}
.rules li{margin:0 0 12px;padding-left:4px}
.rules li::marker{color:var(--faint);font-weight:600}
.rules p{margin:4px 0 0}
.badge.how{text-transform:none;letter-spacing:0;font-family:var(--mono);font-weight:500;color:var(--text)}
.rarea{font-size:12.5px;color:var(--muted)}
.checks{margin:0 0 16px;padding-left:20px;max-width:85ch}
.checks li{margin:0 0 6px}
.ttab td{vertical-align:top}.ttab td:nth-child(2){min-width:16em}
.pill{display:inline-block;font:600 11.5px/1 var(--sans);padding:4px 7px;border-radius:99px;white-space:nowrap}
.pill.ok{background:var(--ok-bg);color:var(--ok-fg)}
.pill.no{background:var(--no-bg);color:var(--no-fg)}
.res{color:var(--ok-fg);font-size:13px;white-space:nowrap}
.res code{color:var(--ok-fg)}
.sqlfile{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:12px 16px;margin:0 0 12px;max-width:1000px}
.sqlbar{display:flex;flex-wrap:wrap;align-items:center;gap:8px 14px}
.fname{font-weight:700;font-size:15px}
.copy{margin-left:auto;font:500 13px/1 var(--sans);color:var(--surface);background:var(--accent);border:0;border-radius:7px;padding:9px 14px;cursor:pointer;min-height:34px}
.copy:focus-visible{outline:2px solid var(--text);outline-offset:2px}
.sqlnote{margin:6px 0 0;color:var(--muted);font-size:14px}
.side-body .item.tbl{display:block}
.side-body .cols{font-size:12.5px}
.side-body .kc{min-width:10em}
`;
const SCHEMA_JS = `(function(){
  document.addEventListener('click', function(e){
    var b = e.target.closest && e.target.closest('[data-copy]'); if (!b) return;
    var code = document.getElementById(b.getAttribute('data-copy'));
    function say(t){ b.textContent = t; setTimeout(function(){ b.textContent = 'Αντιγραφή'; }, 2200); }
    function select(){
      var d = code.closest('details'); if (d) d.open = true;
      var r = document.createRange(); r.selectNodeContents(code);
      var s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
      say('Επιλέχθηκε, πατήστε Ctrl+C');
    }
    try { navigator.clipboard.writeText(code.textContent).then(function(){ say('Αντιγράφηκε'); }, select); } catch (err) { select(); }
  });
})();`;

const html = `<title>Σχεσιακό σχήμα MDMS-Cy</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
<style>${CSS}${SCHEMA_CSS}</style>
${nav}
<div class="shell">
  <main class="main">${body}</main>
  <aside class="side" aria-label="Λεπτομέρειες" aria-live="polite">
    <div class="side-in">
      <div class="side-bar"><button type="button" class="side-back" hidden>← Πίσω</button><span class="side-kind">Λεπτομέρειες</span></div>
      <div class="side-body"><div class="side-empty"><p><b>Πατήστε ένα όνομα πίνακα ή μια ετικέτα.</b></p><p>Οι πίνακες (${tLink('METER')}), οι πηγές (${cite(['S77'])}), οι αποφάσεις (${cite(['D2'])}) και οι συμβάσεις (${cite(['T8'])}) ανοίγουν εδώ, χωρίς να χάνετε τη θέση σας.</p></div></div>
      <a class="side-go" href="#top" hidden>Δείτε το στη σελίδα ↓</a>
    </div>
  </aside>
</div>
<button type="button" class="jump-back" hidden>← Πίσω</button>
<script>${JS}</script>
<script>${SCHEMA_JS}</script>`;

fs.writeFileSync('mdms-schema.html', html);
fs.writeFileSync('untranslated-schema.json', JSON.stringify([...untranslated], null, 1));
console.log('written', (html.length / 1024).toFixed(0) + 'KB', 'tables', tables.size, 'tests', results.length, 'decisions shown', decList.length, 'sources shown', shownSrc.length, 'untranslated', untranslated.size);
