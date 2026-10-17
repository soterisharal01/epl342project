# Διαγράμματα πινάκων από τον SQL Server

Τα `relational-diagram-1.png` … `-9.png` (ένα ανά περιοχή του ER) σχεδιάζονται από τη ζωντανή βάση, όχι από το ERD+.

1. Τρέχει το `er-model/create.sql` σε SQL Server 2025 (βάση `mdms`: 62 πίνακες, 101 FK).
2. Το `catalog.sql` διαβάζει από τα `sys.tables`, `sys.columns` και `sys.foreign_keys` πίνακες, στήλες, τύπους, NULL, PK και FK, και γράφει το `catalog.json`.
3. Το `render.py` (χρειάζεται Graphviz `dot`) ζωγραφίζει κάθε περιοχή σαν database diagram του SSMS: Key / Column Name / Data Type / Allow Nulls. Γραμμή = FK, με crow's foot στη μεριά «πολλά» και διπλή γραμμή στη μεριά «ένα». Οι γκρι πίνακες ανήκουν σε άλλη περιοχή.
   `python3 render.py ..` (από αυτόν τον φάκελο: γράφει τις εικόνες στο `deliverables/phase-a/`), μετά `node er-model/phase-a-doc.js`.

Τα `areas.json` και `areatitles.json` βγαίνουν από τα `schema.js` και `model.js`.
