// shared look and behaviour of the MDMS-Cy pages (ER model and relational schema)
const TOK_LIGHT = `
  color-scheme: light;
  --bg: #f5f5f2; --surface: #ffffff; --surface-2: #f0f1ed; --text: #1a1f24; --muted: #5b6570; --faint: #8a939c; --border: #e0e2dd; --border-2: #cfd3cc;
  --accent: #0f766e; --accent-soft: #e1f2ef; --flash: #fff4c2;
  --spec-bg: #dff1ed; --spec-fg: #0d5e57; --lec-bg: #e7ebf0; --lec-fg: #394555; --dec-bg: #fcefd2; --dec-fg: #8a5200; --con-bg: #fde3df; --con-fg: #a2261a;
  --erd: #6d4fc2; --er-ink: #1c242d; --er-muted: #75808b; --er-ent: #e3f1ee; --er-rel: #fbeedb; --er-attr: #ffffff; --er-ext: #eff1f3; --er-isa: #ffffff; --er-card: #a33a0d;`;
const TOK_DARK = `
  color-scheme: dark;
  --bg: #111315; --surface: #181b1e; --surface-2: #1f2327; --text: #e5e8eb; --muted: #9ca5ae; --faint: #6f7882; --border: #2a2f34; --border-2: #3a4047;
  --accent: #5fd6c4; --accent-soft: #15302c; --flash: #3b3415;
  --spec-bg: #163a35; --spec-fg: #8ce3d5; --lec-bg: #29303a; --lec-fg: #c6cfd9; --dec-bg: #3a2d12; --dec-fg: #f3c56b; --con-bg: #3d1c1a; --con-fg: #fca5a0;
  --erd: #b7a2f2; --er-ink: #d8dee4; --er-muted: #87919b; --er-ent: #17332f; --er-rel: #3a2c16; --er-attr: #1c2024; --er-ext: #21262b; --er-isa: #1c2024; --er-card: #fdba74;`;

const CSS = `
:root{${TOK_LIGHT}
  --sans: 'IBM Plex Sans', system-ui, -apple-system, 'Segoe UI', Roboto, 'Noto Sans', sans-serif;
  --mono: 'IBM Plex Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  --navh: 52px;
}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){${TOK_DARK}}}
:root[data-theme="dark"]{${TOK_DARK}}
*,*::before,*::after{box-sizing:border-box}
[hidden]{display:none!important}
html{scroll-padding-top:calc(var(--navh) + 12px)}
body{margin:0;background:var(--bg);color:var(--text);font:400 16px/1.55 var(--sans);-webkit-text-size-adjust:100%}
a{color:var(--accent)}
code,.mono{font-family:var(--mono)}
h1,h2,h3,h4{line-height:1.2;margin:0}
.toc{position:sticky;top:0;z-index:20;background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border-bottom:1px solid var(--border)}
.toc-in{max-width:1480px;margin:0 auto;padding:0 16px;height:var(--navh);display:flex;align-items:center;gap:4px;overflow-x:auto;scrollbar-width:none}
.toc-in::-webkit-scrollbar{display:none}
.toc a{flex:none;color:var(--muted);text-decoration:none;font-size:14px;font-weight:500;padding:6px 10px;border-radius:6px}
.toc a:hover{color:var(--text);background:var(--surface-2)}
.toc a.brand{color:var(--text);font-weight:700;margin-right:8px;padding-left:0}
.shell{max-width:1480px;margin:0 auto;padding:0 16px;display:grid;grid-template-columns:minmax(0,1fr);gap:32px}
@media (min-width:1100px){.shell{grid-template-columns:minmax(0,1fr) 340px}}
.main{min-width:0;padding-bottom:96px}
.hero{padding:40px 0 8px}
.kicker{margin:0 0 8px;color:var(--accent);font-weight:600;font-size:13px;letter-spacing:.06em;text-transform:uppercase}
h1{font-size:clamp(30px,5vw,44px);font-weight:700;letter-spacing:-.02em}
.sub{max-width:62ch;color:var(--muted);font-size:18px;margin:12px 0 20px}
.stats{display:flex;flex-wrap:wrap;gap:10px;margin:0 0 20px;padding:0}
.stats div{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:10px 16px;min-width:110px}
.stats dt{font-size:24px;font-weight:700;font-variant-numeric:tabular-nums}
.stats dd{margin:0;color:var(--muted);font-size:13px}
.keybox{background:var(--surface);border:1px solid var(--border);border-left:3px solid var(--accent);border-radius:10px;padding:14px 18px;max-width:80ch}
.keybox p{margin:0 0 8px}.keybox p:last-child{margin:0}
.block,.area{padding-top:48px}
.block>h2,.area h2{font-size:26px;font-weight:700;letter-spacing:-.01em}
.lead{color:var(--muted);max-width:75ch;margin:8px 0 18px}
h3{font-size:15px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:var(--muted);margin:28px 0 6px}
.cnt{display:inline-block;margin-left:6px;font-size:12px;background:var(--surface-2);border:1px solid var(--border);border-radius:99px;padding:1px 8px;color:var(--muted);letter-spacing:0}
/* chips */
.cites{display:inline-flex;flex-wrap:wrap;gap:3px;vertical-align:1px}
.chip{display:inline-block;font:600 11px/1 var(--mono);padding:4px 5px 3px;border-radius:4px;text-decoration:none;white-space:nowrap}
.chip:hover,.chip:focus-visible{outline:2px solid currentColor;outline-offset:0}
.chip.spec,.refid.spec{background:var(--spec-bg);color:var(--spec-fg)}
.chip.lec,.refid.lec{background:var(--lec-bg);color:var(--lec-fg)}
.chip.dec,.refid.dec{background:var(--dec-bg);color:var(--dec-fg)}
.chip.con,.refid.con{background:var(--con-bg);color:var(--con-fg)}
/* changes */
.changes,.asm{margin:0;padding:0 0 0 22px;max-width:85ch}
.changes li,.asm li{margin:0 0 10px;padding-left:4px}
.changes li::marker,.asm li::marker{color:var(--faint);font-weight:600}
/* legend */
.legend{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}
.lg-item{margin:0;display:flex;flex-direction:column;gap:10px;background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 14px 12px}
.lg{flex:none;width:145px;height:66px;overflow:visible;align-self:center}
.lg .e{fill:var(--er-ent);stroke:var(--er-ink);stroke-width:1.2}
.lg .x{fill:var(--er-ext);stroke:var(--er-muted);stroke-width:1.2;stroke-dasharray:4 3}
.lg .r{fill:var(--er-rel);stroke:var(--er-ink);stroke-width:1.2}
.lg .a{fill:var(--er-attr);stroke:var(--er-ink);stroke-width:1.2}
.lg .l,.lg .u{stroke:var(--er-ink);stroke-width:1.2}
.lg .dot{stroke-dasharray:1.5 2.5}
.lg text{fill:var(--er-ink);font:12px Helvetica,Arial,sans-serif}
.lg text.b{font-weight:700}.lg text.s{font-size:10.5px}.lg text.m{fill:var(--er-muted)}
.lg text.c{fill:var(--er-card);font-weight:700;font-size:13px}
.lg-item figcaption{display:flex;flex-direction:column;gap:2px;font-size:13.5px;line-height:1.4}
.lg-item figcaption span{color:var(--muted)}
.lg-item .cites{margin-top:2px}
/* area cards */
.acards{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:10px}
.acard{display:grid;grid-template-columns:auto 1fr;gap:2px 10px;text-decoration:none;color:var(--text);background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:12px 14px}
.acard:hover{border-color:var(--accent)}
.ano{grid-row:span 3;display:grid;place-items:center;width:28px;height:28px;border-radius:7px;background:var(--accent-soft);color:var(--accent);font-weight:700;font-size:14px}
.ano.big{width:36px;height:36px;font-size:17px;border-radius:9px;flex:none}
.atitle{font-weight:600}
.ameta{font-size:13px;color:var(--muted)}
.anames{font:11px/1.5 var(--mono);color:var(--faint);overflow-wrap:anywhere}
.area-head{display:flex;gap:14px;align-items:flex-start}
.area-head .lead{margin-bottom:16px}
/* diagram */
.diagram{background:var(--surface);border:1px solid var(--border);border-radius:12px;overflow:hidden}
.dtools{display:flex;flex-wrap:wrap;gap:8px 12px;align-items:center;padding:10px 12px;border-bottom:1px solid var(--border);background:var(--surface-2)}
.seg{display:inline-flex;border:1px solid var(--border-2);border-radius:8px;overflow:hidden;background:var(--surface)}
.seg button{font:500 13px/1 var(--sans);color:var(--muted);background:transparent;border:0;padding:8px 12px;cursor:pointer;min-height:34px}
.seg button+button{border-left:1px solid var(--border-2)}
.seg button[aria-pressed="true"]{background:var(--accent);color:var(--surface)}
.seg button:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
.dhint{font-size:12.5px;color:var(--faint)}
.dscroll{overflow:auto;padding:12px;-webkit-overflow-scrolling:touch}
.diagram[data-size="zoom"] .dscroll{max-height:80vh;cursor:grab}
.dscroll{touch-action:pan-x pan-y}
.dscroll.grabbing{cursor:grabbing;user-select:none}
.seg.zoom button{min-width:36px;font-size:17px;padding:6px 10px}
.zl{display:inline-flex;align-items:center;justify-content:center;min-width:52px;padding:0 4px;font:500 12.5px/1 var(--sans);color:var(--muted);border-left:1px solid var(--border-2);border-right:1px solid var(--border-2);font-variant-numeric:tabular-nums}
.dv{display:none}
.diagram[data-view="keys"] .dv-keys,.diagram[data-view="full"] .dv-full{display:block}
.er-svg{display:block;margin:0 auto;height:auto}
.diagram[data-size="fit"] .er-svg{width:100%;max-width:var(--w)}
.diagram[data-size="zoom"] .er-svg{width:calc(var(--w) * var(--z, 1));max-width:none}
.er-svg text{font-family:Helvetica,Arial,sans-serif}
.er-svg a{cursor:pointer}
.er-svg a:hover polygon,.er-svg a:hover ellipse{stroke-width:2.2}
.er-svg a:focus{outline:none}
.er-svg a:focus-visible polygon{stroke:var(--accent);stroke-width:2.5}
/* items */
.howto{font-size:13.5px;color:var(--faint);margin:0 0 4px}
.items{border-bottom:1px solid var(--border)}
.item{display:grid;grid-template-columns:minmax(0,15rem) minmax(0,1fr);gap:6px 20px;padding:14px 6px;border-top:1px solid var(--border);border-radius:4px}
@media (max-width:700px){.item{grid-template-columns:minmax(0,1fr)}}
.item-l{display:flex;flex-direction:column;gap:6px;align-items:flex-start}
.nm{font:600 14.5px/1.3 var(--mono);overflow-wrap:anywhere}
.badges{display:flex;flex-wrap:wrap;gap:4px 6px;align-items:center;font-size:12.5px;color:var(--muted)}
.badge{display:inline-block;font:600 11px/1 var(--sans);padding:4px 6px;border-radius:4px;background:var(--surface-2);border:1px solid var(--border);color:var(--muted);text-transform:uppercase;letter-spacing:.04em}
.badge.ratio{font-family:var(--mono);font-size:12px;text-transform:none;letter-spacing:0;color:var(--er-card);background:var(--surface)}
.badge.weak,.badge.ident{border-color:var(--er-ink);box-shadow:inset 0 0 0 1.5px var(--surface),inset 0 0 0 2.5px var(--border-2)}
.owners a{font-family:var(--mono);font-size:12px}
.attrs{font:13.5px/1.7 var(--mono)}
.sep{color:var(--faint)}
.at.key{text-decoration:underline;text-underline-offset:3px;font-weight:600}
.at.partial{text-decoration:underline dotted;text-decoration-thickness:2px;text-underline-offset:3px;font-weight:600}
.at.cand{text-decoration:overline;font-weight:500}
.at.multi{color:var(--accent)}
.none{color:var(--faint);font-family:var(--sans);font-style:italic}
.note{margin:6px 0 0;color:var(--muted);font-size:14.5px;max-width:80ch}
.guide{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr));gap:14px;max-width:1000px}
.gcard{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 16px;font-size:14.5px}
.gcard.wide{grid-column:1/-1}
.gcard h3{margin:0 0 8px}
.gcard ul,.gcard ol{margin:0;padding-left:20px}.gcard li{margin:5px 0}
.gcard p{margin:6px 0 0}
.gtab td:first-child{white-space:normal;min-width:11em}
.gnote{color:var(--muted);font-size:13.5px}
.gquote{margin:8px 0 0;padding:10px 14px;border-left:3px solid var(--erd);background:var(--surface-2);border-radius:6px}
.gsrc{color:var(--muted);font-size:13px;margin-top:14px}
.erd{margin:12px 0 2px;padding:10px 14px 10px 12px;border:1px solid var(--border);border-left:3px solid var(--erd);border-radius:8px;background:var(--surface-2);font-size:14px;max-width:80ch}
.erd-h{margin:0 0 6px!important;font-weight:600;color:var(--text);display:flex;align-items:center;gap:8px}
.erd-tag{font:600 11px/1 var(--mono);padding:4px 6px 3px;border-radius:4px;background:var(--erd);color:var(--surface)}
.erd ol{margin:0;padding-left:20px}
.erd ol>li{margin:4px 0}
.erd-at{margin:4px 0 2px;padding-left:16px}
.erd-at li{margin:2px 0}
.erd-at code{font-size:13px}
.erd-why{color:var(--muted);font-size:13px}
.erd .mmv{font-family:var(--mono)}
.erd-note{margin:8px 0 0!important;color:var(--muted);font-size:13.5px}
.inrels{margin:6px 0 0;font-size:13.5px;color:var(--muted)}
.inrels a,.mean a,.end-e a,.mean-p a{font-family:var(--mono);font-size:13px}
.lbl{display:inline-block;font:600 11px/1 var(--sans);text-transform:uppercase;letter-spacing:.05em;color:var(--faint);margin-right:6px}
a.ent-link,a.rel-link{text-decoration:none;border-bottom:1px solid color-mix(in srgb,var(--accent) 40%,transparent)}
a.ent-link:hover,a.rel-link:hover{border-bottom-color:var(--accent)}
.ends{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px}
.end{display:grid;grid-template-columns:minmax(0,12rem) 2.2rem 5.6rem minmax(0,1fr);gap:4px 10px;align-items:baseline;font-size:14px}
@media (max-width:900px){.end{grid-template-columns:minmax(0,1fr) auto auto}.end .mean{grid-column:1/-1}}
.end-e{overflow-wrap:anywhere}
.role{font-size:12.5px;color:var(--muted)}
.card{font:700 14px/1 var(--mono);color:var(--er-card);text-align:center}
.part{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;color:var(--muted)}
.part .ln{display:inline-block;width:18px;border-top:1.5px solid var(--er-ink)}
.part.total .ln{height:5px;border-bottom:1.5px solid var(--er-ink)}
.part.total{color:var(--text);font-weight:600}
.mean{color:var(--muted);font-size:13.5px}
.mm{font:600 12px/1 var(--mono);color:var(--er-card);white-space:nowrap;margin-left:2px}
.keybox.erd{margin-top:12px;max-width:none}
.tscroll{overflow-x:auto;max-width:100%}
.fktab{border-collapse:collapse;margin:4px 0 6px;font-size:14px;width:100%}
.fktab th,.fktab td{text-align:left;padding:6px 10px;border-bottom:1px solid var(--border)}
.fktab th{font-size:12px;text-transform:uppercase;letter-spacing:.05em;color:var(--faint);font-weight:600}
.fktab code{color:var(--er-card);font-weight:600}
.mmtab{border-collapse:collapse;margin:4px 0 10px;font-size:14px;width:100%;max-width:640px}
.mmtab th,.mmtab td{text-align:left;padding:6px 10px;border-bottom:1px solid var(--border)}
.mmtab th{font-size:12px;text-transform:uppercase;letter-spacing:.05em;color:var(--faint);font-weight:600}
.mmtab code{color:var(--er-card);font-weight:600}
@media (max-width:640px){.mmtab td:nth-child(3),.mmtab th:nth-child(3){display:none}}
.mean-p{margin:0;font-size:14.5px;color:var(--muted);max-width:80ch}
/* refs */
.refs{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:10px}
.ref{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 16px}
.ref h4{font-size:15.5px;font-weight:600;display:flex;gap:8px;align-items:baseline}
.ref p{margin:8px 0 0;font-size:14.5px}
.ref p.basis,.ref p.usedby{font-size:13px;color:var(--muted)}
.refid{flex:none;font:600 12px/1 var(--mono);padding:4px 6px 3px;border-radius:4px}
.usedby a{font-size:12.5px}
/* sources */
.srcs{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:10px}
.src{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:12px 16px}
.srchead{display:flex;flex-wrap:wrap;gap:6px 10px;align-items:center;font-size:13.5px;color:var(--muted)}
.where{font-weight:600;color:var(--text)}
.badge.fig{text-transform:none;letter-spacing:0;font-weight:500}
blockquote{margin:10px 0 0;padding:2px 0 2px 14px;border-left:3px solid var(--border-2);font-size:15px;line-height:1.6}
.en{margin:8px 0 0;font-size:14px;color:var(--muted)}
.usedby{margin:8px 0 0;font-size:13px;color:var(--muted)}
/* target flash */
.flash{animation:flash 1.8s ease-out}
@keyframes flash{0%,35%{background:var(--flash)}100%{background:transparent}}
.src.flash,.ref.flash{animation-name:flash2}
@keyframes flash2{0%,35%{background:var(--flash)}100%{background:var(--surface)}}
/* side panel */
.side{display:none}
@media (min-width:1100px){
  .side{display:block;padding-top:40px}
  .side-in{position:sticky;top:calc(var(--navh) + 16px);max-height:calc(100vh - var(--navh) - 32px);overflow:auto;background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:0 0 12px}
}
.side-bar{position:sticky;top:0;display:flex;align-items:center;gap:8px;padding:10px 14px;background:var(--surface-2);border-bottom:1px solid var(--border);font:600 12px/1 var(--sans);text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}
.side-back{font:500 13px/1 var(--sans);text-transform:none;letter-spacing:0;color:var(--accent);background:none;border:1px solid var(--border-2);border-radius:6px;padding:5px 8px;cursor:pointer}
.side-body{padding:14px 16px 4px;font-size:14px}
.side-body .nm{font-size:16px}
.side-body .item-l{margin-bottom:10px}
.side-body .end{grid-template-columns:minmax(0,1fr) auto auto}
.side-body .end .mean{grid-column:1/-1;margin-bottom:4px}
.side-body h4{font-size:16px;font-weight:600;display:flex;gap:8px;align-items:baseline}
.side-body p{margin:8px 0 0}
.side-body .srchead{margin-bottom:2px}
.side-empty p{margin:0 0 8px;color:var(--muted)}
.side-empty b{color:var(--text)}
.side-go{display:block;margin:8px 16px 0;font-size:13.5px;font-weight:500}
.jump-back{position:fixed;left:50%;bottom:18px;transform:translateX(-50%);z-index:30;font:600 14px/1 var(--sans);color:var(--surface);background:var(--text);border:0;border-radius:99px;padding:12px 18px;box-shadow:0 6px 24px rgba(0,0,0,.25);cursor:pointer;white-space:nowrap}
@media (prefers-reduced-motion:reduce){.flash,.src.flash,.ref.flash{animation:none}html{scroll-behavior:auto}}
`;

const JS = `(function(){
  var wide = matchMedia('(min-width: 1100px)');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)');
  var side = document.querySelector('.side');
  var body = side.querySelector('.side-body');
  var kind = side.querySelector('.side-kind');
  var back = side.querySelector('.side-back');
  var go = side.querySelector('.side-go');
  var jb = document.querySelector('.jump-back');
  var KIND = {src:'Πηγή', dec:'Σχεδιαστική απόφαση', con:'Αντίφαση ή ανοιχτό σημείο', e:'Οντότητα', r:'Συσχέτιση', isa:'Εξειδίκευση', t:'Πίνακας', sdec:'Σύμβαση σχήματος'};
  document.documentElement.lang = 'el';
  var hist = [], cur = null, stack = [];
  function prefix(id){ return id.split('-')[0]; }
  function show(id, push){
    var t = document.getElementById(id); if (!t) return;
    if (push && cur) hist.push(cur); else if (!push) hist = [];
    cur = id;
    kind.textContent = KIND[prefix(id)] || 'Λεπτομέρειες';
    body.innerHTML = t.innerHTML;
    side.querySelector('.side-in').scrollTop = 0;
    back.hidden = !hist.length;
    go.hidden = false; go.setAttribute('href', '#' + id);
  }
  back.addEventListener('click', function(){ if (!hist.length) return; var id = hist.pop(); cur = null; show(id, true); });
  function flash(t){ t.classList.remove('flash'); void t.offsetWidth; t.classList.add('flash'); }
  function jump(id, remember){
    var t = document.getElementById(id); if (!t) return;
    if (remember){ stack.push(window.scrollY); jb.hidden = false; }
    t.scrollIntoView({behavior: reduce.matches ? 'auto' : 'smooth', block: 'start'});
    if (/^(src|dec|con|e|r|isa|chg|asm|frth|t|sdec|rule)-/.test(id)) flash(t);
  }
  jb.addEventListener('click', function(){
    if (!stack.length){ jb.hidden = true; return; }
    window.scrollTo({top: stack.pop(), behavior: reduce.matches ? 'auto' : 'smooth'});
    jb.hidden = !stack.length;
  });
  document.addEventListener('click', function(e){
    var a = e.target.closest && e.target.closest('a'); if (!a) return;
    var href = a.getAttribute('href') || a.getAttribute('xlink:href') || a.getAttributeNS('http://www.w3.org/1999/xlink', 'href');
    if (!href || href.charAt(0) !== '#' || href.length < 2) return;
    var id = decodeURIComponent(href.slice(1));
    if (!document.getElementById(id)) return;
    e.preventDefault();
    var detail = /^(src|dec|con|e|r|isa|t|sdec)-/.test(id);
    if (a.classList.contains('side-go')) { jump(id, true); return; }
    if (wide.matches && detail) { show(id, !!a.closest('.side')); return; }
    jump(id, detail);
  });
  // zoom: Fit shows the whole drawing; otherwise the drawing is drawn at z times its natural size inside a scroll box
  document.querySelectorAll('.diagram').forEach(function(d){
    var sc = d.querySelector('.dscroll'), zl = d.querySelector('.zl'), z = null;
    var presets = d.querySelectorAll('[data-set-size]');
    function svg(){ return d.querySelector(d.getAttribute('data-view') === 'full' ? '.dv-full svg' : '.dv-keys svg'); }
    function natW(){ var s = svg(); return parseFloat(s.style.getPropertyValue('--w')) || s.getBoundingClientRect().width; }
    function fitScale(){ return Math.min(1, (sc.clientWidth - 24) / natW()); }
    function cur(){ return z === null ? svg().getBoundingClientRect().width / natW() : z; }
    function label(){
      zl.textContent = Math.round(cur() * 100) + '%';
      presets.forEach(function(b){ var k = b.getAttribute('data-set-size'); b.setAttribute('aria-pressed', String(k === 'fit' ? z === null : z === 1)); });
    }
    function setZoom(nz, cx, cy){
      var s = svg(), r = s.getBoundingClientRect(), box = sc.getBoundingClientRect();
      if (cx === undefined){ cx = box.left + box.width / 2; cy = box.top + Math.min(box.height, window.innerHeight - box.top) / 2; }
      var fx = (cx - r.left) / r.width, fy = (cy - r.top) / r.height;
      if (nz !== null){ nz = Math.min(3, nz); if (nz <= fitScale() * 1.001) nz = null; }
      z = nz;
      d.setAttribute('data-size', z === null ? 'fit' : 'zoom');
      if (z !== null) d.style.setProperty('--z', String(z));
      var r2 = s.getBoundingClientRect();
      if (z !== null){ sc.scrollLeft += r2.left + fx * r2.width - cx; sc.scrollTop += r2.top + fy * r2.height - cy; }
      label();
    }
    d.addEventListener('click', function(e){
      var b = e.target.closest('button'); if (!b) return;
      var v = b.getAttribute('data-set-view'), s = b.getAttribute('data-set-size'), zz = b.getAttribute('data-zoom');
      if (v){ d.setAttribute('data-view', v); b.parentNode.querySelectorAll('button').forEach(function(x){ x.setAttribute('aria-pressed', String(x === b)); }); label(); }
      if (s) setZoom(s === 'fit' ? null : 1);
      if (zz) setZoom(cur() * (zz === 'in' ? 1.25 : 0.8));
    });
    // Ctrl or Cmd + wheel (and trackpad pinch, which arrives the same way) zooms around the pointer
    sc.addEventListener('wheel', function(e){
      if (!(e.ctrlKey || e.metaKey)) return;
      e.preventDefault();
      setZoom(cur() * Math.exp(-Math.max(-60, Math.min(60, e.deltaY)) * 0.004), e.clientX, e.clientY);
    }, {passive: false});
    // two-finger pinch on touch screens
    var pinch = null;
    function tdist(t){ return Math.hypot(t[0].clientX - t[1].clientX, t[0].clientY - t[1].clientY); }
    sc.addEventListener('touchstart', function(e){ if (e.touches.length === 2) pinch = { d: tdist(e.touches), z: cur() }; }, {passive: true});
    sc.addEventListener('touchmove', function(e){
      if (!pinch || e.touches.length !== 2) return;
      e.preventDefault();
      setZoom(pinch.z * tdist(e.touches) / pinch.d, (e.touches[0].clientX + e.touches[1].clientX) / 2, (e.touches[0].clientY + e.touches[1].clientY) / 2);
    }, {passive: false});
    sc.addEventListener('touchend', function(e){ if (e.touches.length < 2) pinch = null; });
    // drag the empty space to move around a zoomed drawing; shapes stay clickable
    var drag = null;
    sc.addEventListener('mousedown', function(e){
      if (e.button !== 0 || z === null || e.target.closest('a')) return;
      drag = { x: e.clientX, y: e.clientY, l: sc.scrollLeft, t: sc.scrollTop };
      sc.classList.add('grabbing'); e.preventDefault();
    });
    window.addEventListener('mousemove', function(e){ if (drag){ sc.scrollLeft = drag.l - (e.clientX - drag.x); sc.scrollTop = drag.t - (e.clientY - drag.y); } });
    window.addEventListener('mouseup', function(){ if (drag){ drag = null; sc.classList.remove('grabbing'); } });
    window.addEventListener('resize', function(){ if (z === null) label(); });
    label();
  });
})();`;


module.exports = { TOK_LIGHT, TOK_DARK, CSS, JS };
