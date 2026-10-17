// Builds the Phase A deliverable (spec V.A: ER diagram, relational schema, assumptions <= 1/2 page)
// as deliverables/phase-a/phase-a.docx. Rename it to <team-number>.docx before uploading to Moodle.
// The ER figure is deliverables/phase-a/er-diagram.png or er-diagram-1.png, -2.png ... (ERD+ export or screenshots),
// the tables relational-diagram.png or relational-diagram-1.png ... (mdms-relational.erdplus in ERD+);
// until that file exists the script uses mdms-er-card.png (the same .erdplus file drawn with the (min,max)
// labels by erdplus-preview.js --card and svg-to-png.js) and marks the figure as temporary.
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, ImageRun, HeadingLevel, AlignmentType, PageOrientation,
  LevelFormat, Footer, PageNumber,
} = require('docx');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'deliverables', 'phase-a');
const OUT = path.join(OUT_DIR, 'phase-a.docx');
const PREVIEW = path.join(__dirname, 'mdms-er-card.png');
const TEAM = process.env.TEAM || '<team-number>';
const MEMBERS = (process.env.MEMBERS || '<Ονοματεπώνυμο 1 (ID)>|<Ονοματεπώνυμο 2 (ID)>|<Ονοματεπώνυμο 3 (ID)>').split('|');

// ERD+ screenshots: er-diagram.png, or er-diagram-1.png, er-diagram-2.png, ... (one landscape page each);
// relational-diagram*.png the same for the tables (mdms-relational.erdplus opened in ERD+)
const shots = prefix => fs.existsSync(OUT_DIR) ? fs.readdirSync(OUT_DIR).filter(f => new RegExp(`^${prefix}(-\\d+)?\\.png$`).test(f))
  .sort((a, b) => (+(a.match(/-(\d+)\./) || [0, 0])[1]) - (+(b.match(/-(\d+)\./) || [0, 0])[1])).map(f => path.join(OUT_DIR, f)) : [];
const erShots = shots('er-diagram'), relShots = shots('relational-diagram');
const finalFigure = erShots.length > 0;
// PNG width/height live in the IHDR chunk
const png = f => { const d = fs.readFileSync(f); return { d, w: d.readUInt32BE(16), h: d.readUInt32BE(20) }; };

// Assumptions: DECISIONS.md "Assumptions" in Greek, kept within half a page.
const ASSUMPTIONS = [
  'Κάθε πρόσωπο έχει έναν λογαριασμό (USER_ACCOUNT) και μπορεί να έχει πολλούς ρόλους· κάθε λογαριασμός έχει τουλάχιστον έναν ρόλο (ελέγχεται με procedure/trigger στη Φάση Β). Οι ρόλοι είναι weak entities του USER_ACCOUNT με κλειδί το UserID.',
  'Ένα υποστατικό αλλάζει καταναλωτές με τον χρόνο· κάθε περίοδος κατοχής (HOLDING) είναι ξεχωριστή γραμμή με StartDate και EndDate (κενό όσο είναι ανοιχτή).',
  'Οι μετρήσεις ανήκουν στον μετρητή. Το ιστορικό ενός υποστατικού είναι η ένωση των μετρητών που εγκαταστάθηκαν εκεί.',
  'Κάθε μετρητής εξυπηρετείται από ακριβώς έναν μετασχηματιστή χαμηλής τάσης, και κάθε geofence επιπέδου 1 καλύπτει ακριβώς έναν μετασχηματιστή. Τα geofences είναι ορθογώνια σε δέντρο και τα ορθογώνια επιπέδου 1 δεν επικαλύπτονται.',
  'Η χρονοσφραγίδα κάθε πακέτου τοποθετείται στο 15λεπτο διάστημά της. Μια μέτρηση κρατά την τιμή που ελήφθη και την τιμή ανά διάστημα που χρησιμοποιούν οι επόμενες λειτουργίες.',
  'Μετά το VEE η τιμή και η κατάσταση μιας μέτρησης δεν αλλάζουν. Η μόνη διαγραφή είναι η εκκαθάριση των μετρήσεων καταναλωτών και των πακέτων τους (36 μήνες, ή 1 μήνας μετά από εγκεκριμένο αίτημα GDPR). Τα συγκεντρωτικά των μετασχηματιστών δεν διαγράφονται ποτέ.',
  'Ένα εγκεκριμένο αίτημα GDPR μειώνει τη διατήρηση των ακατέργαστων δεδομένων σε 1 μήνα· ο λογαριασμός, τα τιμολόγια, οι πληρωμές και τα συγκεντρωτικά διατηρούνται.',
  'Οι προμηθευτές βλέπουν μόνο υποστατικά με τα οποία έχουν σύμβαση προμήθειας, οι aggregators μόνο υποστατικά των χαρτοφυλακίων τους, και οι δύο μόνο συγκεντρωτικά δεδομένα.',
  'Η δυναμική τιμολόγηση, οι προβλέψεις, οι τεχνικές απώλειες και η πραγματική αποστολή email/SMS είναι εκτός της βάσης δεδομένων.',
  'Κανόνες που αφορούν πολλές γραμμές ή πίνακες (π.χ. μη επικάλυψη περιόδων, αμετάβλητες τελικές μετρήσεις) δεν εκφράζονται με CHECK και υλοποιούνται με triggers/stored procedures στη Φάση Β.',
  'Στο διάγραμμα ERD+ κάθε υπογραμμισμένο γνώρισμα εκτός από το ID της οντότητας είναι εναλλακτικό κλειδί (UNIQUE), επειδή το ERD+ δεν έχει άλλη σημειογραφία.',
];

const FONT = 'Calibri';
const p = (text, opts = {}) => new Paragraph({ spacing: { after: 80 }, ...opts, children: [new TextRun({ text, font: FONT, size: 21, ...(opts.run || {}) })] });
const h1 = text => new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 120, after: 120 }, children: [new TextRun({ text, font: FONT })] });

const footer = new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [
  new TextRun({ text: `ΕΠΛ342 Φάση Α · Ομάδα ${TEAM} · `, font: FONT, size: 16 }),
  new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 16 }),
] })] });

const A4 = { width: 11906, height: 16838 };
const margin = { top: 1000, bottom: 1000, left: 1000, right: 1000 };

// 1. Cover and contents
const cover = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 2400, after: 200 }, children: [new TextRun({ text: 'ΕΠΛ342 Βάσεις Δεδομένων', font: FONT, size: 28 })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [new TextRun({ text: 'MDMS-Cy: Φάση Α, Σχεδίαση Βάσης', font: FONT, size: 40, bold: true })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 }, children: [new TextRun({ text: `Ομάδα ${TEAM}`, font: FONT, size: 28 })] }),
  ...MEMBERS.map(m => new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [new TextRun({ text: m, font: FONT, size: 24 })] })),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200, after: 80 }, children: [new TextRun({ text: 'Περιεχόμενα', font: FONT, size: 24, bold: true })] }),
  ...['1. Διάγραμμα Οντοτήτων Συσχετίσεων (Chen ER, ERD+)', '2. Παραδοχές', ...(relShots.length ? ['3. Σχεσιακό σχήμα: πίνακες στο ERD+', '4. Σχεσιακό σχήμα σε T-SQL'] : ['3. Σχεσιακό σχήμα (T-SQL)'])].map(t => p(t, { alignment: AlignmentType.CENTER })),
];

// 2. ER diagram on a landscape page, scaled to the printable area
const landW = A4.height - 1200, landH = A4.width - 2600; // DXA
const figure = f => { const { d, w, h } = png(f); const k = Math.min(landW / 15 / w, landH / 15 / h); // DXA -> px at 96 dpi = /15
  return new Paragraph({ alignment: AlignmentType.CENTER, children: [new ImageRun({ type: 'png', data: d, transformation: { width: Math.round(w * k), height: Math.round(h * k) } })] }); };
const pageBreak = () => new Paragraph({ pageBreakBefore: true, children: [] });
const erSection = [
  h1('1. Διάγραμμα Οντοτήτων Συσχετίσεων (Chen ER)'),
  ...(finalFigure ? erShots : [PREVIEW]).flatMap((f, i) => i ? [pageBreak(), figure(f)] : [figure(f)]),
  p(finalFigure
    ? 'Ενιαίο διάγραμμα Chen ER σχεδιασμένο στο ERD+: 53 οντότητες (16 weak), 92 συσχετίσεις. Το ERD+ γράφει το (min,max) κάθε οντότητας στην απέναντι άκρη της γραμμής.'
    : 'ΠΡΟΣΩΡΙΝΗ ΕΙΚΟΝΑ: το αρχείο ERD+ (mdms-er.erdplus) σχεδιασμένο από δικό μας script, με τα (min,max) όπως τα τοποθετεί το ERD+ (στην απέναντι άκρη). Αντικαθίσταται από την εικόνα που εξάγει το ίδιο το ERD+ (Download image) ως deliverables/phase-a/er-diagram.png.',
    { alignment: AlignmentType.CENTER, run: { size: 18, italics: true, color: finalFigure ? '000000' : 'C00000' } }),
];

// 3. Assumptions
const assumptions = [
  h1('2. Παραδοχές'),
  ...ASSUMPTIONS.map(t => new Paragraph({ numbering: { reference: 'bullets', level: 0 }, spacing: { after: 40 }, children: [new TextRun({ text: t, font: FONT, size: 19 })] })),
];

// 3b. Relational schema as tables in ERD+ (only when the screenshots exist)
const relSection = relShots.length ? [
  h1('3. Σχεσιακό σχήμα: πίνακες στο ERD+'),
  ...relShots.flatMap((f, i) => i ? [pageBreak(), figure(f)] : [figure(f)]),
  p('Οι 62 πίνακες στο ERD+ (mdms-relational.erdplus): πρωτεύοντα κλειδιά υπογραμμισμένα, ξένα κλειδιά με βέλος προς τον πίνακα που αναφέρουν. Ο ορισμός με όλους τους περιορισμούς ακολουθεί σε T-SQL.', { alignment: AlignmentType.CENTER, run: { size: 18, italics: true } }),
] : [];

// 4. Schema: create.sql verbatim, monospace
const sql = fs.readFileSync(path.join(__dirname, 'create.sql'), 'utf8').replace(/\r/g, '').split('\n');
while (sql.length && sql[sql.length - 1] === '') sql.pop();
const schema = [
  h1(relShots.length ? '4. Σχεσιακό σχήμα σε T-SQL' : '3. Σχεσιακό σχήμα (T-SQL)'),
  p('Το σχήμα προκύπτει από το διάγραμμα ER με την αντιστοίχιση του βιβλίου (Elmasri & Navathe, κεφ. 9): 62 πίνακες με τύπους δεδομένων T-SQL, πρωτεύοντα και ξένα κλειδιά (101), περιορισμούς CHECK (108), UNIQUE (18 και 3 φιλτραρισμένοι) και DEFAULT. Κάθε περιορισμός έχει όνομα της μορφής PK_, FK_ΠΙΝΑΚΑΣ_ΣΥΣΧΕΤΙΣΗ, UQ_, CK_, DF_. Το σχήμα δοκιμάστηκε σε Microsoft SQL Server 2025 με 74 ελέγχους περιορισμών.', { run: { size: 19 } }),
  ...sql.map(line => new Paragraph({ spacing: { after: 0, line: 220 }, children: [new TextRun({ text: line === '' ? ' ' : line, font: 'Consolas', size: 14 })] })),
];

const doc = new Document({
  creator: `Ομάδα ${TEAM}`,
  title: 'ΕΠΛ342 Φάση Α',
  styles: { paragraphStyles: [{ id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 28, bold: true, font: FONT, color: '1F3864' } }] },
  numbering: { config: [{ reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 240 } } } }] }] },
  sections: [
    { properties: { page: { size: A4, margin } }, children: cover },
    { properties: { page: { size: { ...A4, orientation: PageOrientation.LANDSCAPE }, margin: { top: 600, bottom: 600, left: 600, right: 600 } } }, footers: { default: footer }, children: erSection },
    { properties: { page: { size: A4, margin } }, footers: { default: footer }, children: [...assumptions] },
    ...(relSection.length ? [{ properties: { page: { size: { ...A4, orientation: PageOrientation.LANDSCAPE }, margin: { top: 600, bottom: 600, left: 600, right: 600 } } }, footers: { default: footer }, children: relSection }] : []),
    { properties: { page: { size: A4, margin: { ...margin, left: 800, right: 800 } } }, footers: { default: footer }, children: schema },
  ],
});

fs.mkdirSync(OUT_DIR, { recursive: true });
Packer.toBuffer(doc).then(buf => { fs.writeFileSync(OUT, buf); console.log(`wrote ${path.relative(ROOT, OUT)} (ER figure: ${finalFigure ? erShots.length + ' ERD+ image(s)' : 'TEMPORARY render of the .erdplus file'}, tables: ${relShots.length} ERD+ image(s))`); });
