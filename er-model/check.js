const fs=require('fs');const src=require('./sources.js');
const raw=fs.readFileSync('../p.txt','utf8');
// drop page footers
const txt=raw.replace(/ΕΠΛ342: Βάσεις Δεδομένων – Τμήμα Πληροφορικής – Παν\. Κύπρου - https:\/\/www\.cs\.ucy\.ac\.cy\/courses\/EPL342 ©\s*\d+ από 15/g,'');
const norm=s=>s.replace(/\s+/g,'');
const T=norm(txt);
// page lookup
const pages=raw.split(/\d+ από 15/);
for(const s of src){ if(s.fig||s.lecture) continue;
  const parts = s.id==='S62' ? s.el.split(', ') : s.el.split(' … ');
  for (const p of parts){ const n=norm(p); const i=T.indexOf(n);
    if(i<0){console.log('MISSING',s.id, p.slice(0,60)); continue;}
    // which page
    let pg=-1; for(let k=0;k<pages.length;k++){ if(norm(pages[k]).includes(n.slice(0,25))){pg=k+1;break;} }
    if(pg!==s.page) console.log('PAGE',s.id,'claimed',s.page,'found',pg);
  }
}
console.log('done');
