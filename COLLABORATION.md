# Συνεργασία: ομάδα και δύο Claude

Σε αυτό το repo δουλεύουν τα μέλη της ομάδας και δύο Claude: το **Claude του project** (γράφει και τρέχει τον κώδικα) και το **Claude ελέγχου** (ελέγχει ό,τι ανεβαίνει). Το μόνο κοινό κανάλι είναι το GitHub, οπότε όλα γράφονται εδώ: commits, Pull Requests και σχόλια σε PR.

**Claude: διάβασε πρώτα το `README.md`, μετά αυτό το αρχείο, και κοίτα τον πίνακα «Εργασίες» πριν ξεκινήσεις.**

## Πριν από κάθε βήμα

```bash
git fetch --all
git log --all --oneline -15        # τι έκανε ο καθένας
```

Μετά κοιτάς τα ανοιχτά PR και τα σχόλιά τους στο GitHub. Δεν ξεκινάς κάτι που ήδη έχει πάρει κάποιος άλλος στον πίνακα.

## Κανόνες

1. **Κανείς δεν κάνει push απευθείας στο `main`.** Κάθε αλλαγή γίνεται σε δικό της branch και μπαίνει με Pull Request.
   - Claude του project: `claude/...`
   - Claude ελέγχου: `review/...`
   - Μέλη της ομάδας: `<όνομα>/...`
2. **Κάθε PR το ελέγχει ο άλλος Claude** (ή ένα μέλος) πριν γίνει merge. Το merge το κάνει ο Soteris.
3. **Ο έλεγχος γράφεται ως σχόλιο στο PR**, πάνω στη γραμμή όπου γίνεται. Κάθε σχόλιο λέει τι είναι λάθος, γιατί (παραπομπή στην εκφώνηση S1-S79, στις διαλέξεις L1-L16 ή σε απόφαση D1-D32), και τι προτείνει. Ο συντάκτης του PR απαντά σε κάθε σχόλιο: το διορθώνει με νέο commit ή εξηγεί γιατί όχι.
4. **Αλλαγές στο μοντέλο γίνονται μόνο στο `er-model/model.js`** (ή στο `schema.js` για τύπους και CHECK). Μετά ξαναπαράγονται όλα:
   ```bash
   cd er-model && npm install
   node schema.js                               # create.sql, drop.sql
   node tests.js                                # test.sql
   node build.js && node build-schema.js        # σελίδες HTML του ER και του σχήματος
   node erdplus-export.js && node erdplus-check.js   # αρχείο ERD+ και έλεγχος (errors: [])
   node erdplus-preview.js --card && node svg-to-png.js mdms-er-card.svg mdms-er-card.png 2   # προσωρινή εικόνα του ER με (min,max)
   node phase-a-doc.js                          # έγγραφο Φάσης Α
   ```
   Αρχεία που παράγονται από scripts δεν διορθώνονται με το χέρι. Το `DECISIONS.md` ενημερώνεται με το χέρι όταν αλλάζει μια απόφαση.
5. **Μηνύματα commit:** στα αγγλικά, στην προστακτική, με την περιοχή μπροστά, π.χ. `schema: make HOLDING.EndDate nullable`. Αν το commit απαντά σε σχόλιο ελέγχου, γράφει και ποιο.
6. **Όταν παίρνεις μια εργασία**, βάζεις το όνομά σου στον πίνακα στο ίδιο PR. Όταν τελειώνει, την σημειώνεις ✓.

## Εργασίες Φάσης Α (παράδοση 19/10/26 12:00, επιβεβαίωση ημέρας στο Moodle)

| # | Εργασία | Ποιος | Κατάσταση |
|---|---|---|---|
| A1 | Μοντέλο ER (`model.js`), 53 οντότητες, 92 συσχετίσεις | Claude του project | ✓ |
| A2 | Αρχείο ERD+ (`er-model/mdms-er.erdplus`) | Claude του project | ✓ |
| A3 | Σχεσιακό σχήμα (`create.sql`), 74 έλεγχοι σε SQL Server 2025 | Claude του project | ✓ |
| A4 | Έγγραφο Φάσης Α (`deliverables/phase-a/phase-a.docx`, από το `er-model/phase-a-doc.js`) | Claude του project | ✓ πρώτο σχέδιο |
| A5 | Έλεγχος ER σε σχέση με την εκφώνηση (κάθε απαίτηση S1-S79 καλύπτεται, σωστές cardinalities, weak entities) | Claude ελέγχου | ○ |
| A6 | Έλεγχος σχήματος (τύποι, PK/FK, CHECK, αντιστοίχιση ER → πίνακες) και των παραδοχών (≤ 1/2 σελίδα) | Claude ελέγχου | ○ |
| A7 | Εικόνα του διαγράμματος από το ERD+: Import `mdms-er.erdplus` στο erdplus.com, έλεγχος ότι φαίνεται καθαρά, Download image, αποθήκευση ως `deliverables/phase-a/er-diagram.png` | Soteris | ○ |
| A8 | Αριθμός ομάδας και ονόματα μελών στο έγγραφο: `TEAM=<αρ.> MEMBERS="Όνομα 1 (ID)\|Όνομα 2 (ID)\|Όνομα 3 (ID)" node phase-a-doc.js` | Soteris | ○ |
| A9 | Διορθώσεις από τα σχόλια των A5/A6, ξαναπαραγωγή όλων των αρχείων | Claude του project | ○ |
| A10 | Τελικό: μετονομασία σε `<team-number>.docx` (ή .pdf) και ανέβασμα στο Moodle | Soteris | ○ |

Το A7 το κάνει άνθρωπος, γιατί κανένα Claude δεν φτάνει στο erdplus.com. Μέχρι να υπάρξει το `er-diagram.png`, το έγγραφο έχει το ίδιο αρχείο ERD+ σχεδιασμένο από δικό μας script (`er-model/mdms-er-card.png`, με τα (min,max)), με κόκκινη σημείωση «προσωρινή».
