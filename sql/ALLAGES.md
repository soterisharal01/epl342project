# Βήμα 0 της Φάσης Β: αλλαγές σχήματος

Αυτές είναι οι αλλαγές από τη συνάντηση με τον καθηγητή στις 20/11/26. Από εδώ και πέρα, το σχήμα της Φάσης Β είναι το `sql/create.sql`.
Το `er-model/create.sql` μένει όπως ήταν, ως το σχήμα που υποβλήθηκε στη Φάση Α. Το `sql/create.sql` βγήκε από αυτό με το
`sql/tools/step0-from-phase-a.py`. Από τώρα και πέρα όμως το διορθώνουμε με το χέρι.

Αποτέλεσμα: **56 πίνακες** (62 − 7 πίνακες ρόλων − READING + RAW_READING + VALIDATED_READING), 96 FK, 106 CHECK και 4 triggers.

## 1. Χρήστες: ένα username = ένας ρόλος
- Στο `USER_ACCOUNT` προστέθηκε η στήλη `Role` με τιμές Admin, Operator, Consumer, Technician, DSO, TSO, Supplier ή Aggregator.
- Φεύγουν 7 πίνακες ρόλων: `CONSUMER`, `SYSTEM_ADMIN`, `SYSTEM_OPERATOR`, `FIELD_TECHNICIAN`, `MARKET_USER`, `TSO_OPERATOR` και `DSO_OPERATOR`.
  Τα λίγα δικά τους πεδία έγιναν nullable στήλες του `USER_ACCOUNT`: `RawRetentionMonths`, `CreatedBy`, `BirthDate`, `Photo`,
  `ApprovalStatus`, `ApprovalDecidedAt`, `ApprovedBy`, `SupplierID` και `AggregatorID`. Κάθε ρόλος έχει δικό του CHECK, που λέει ποια από αυτά τα πεδία υποχρεωτικά έχουν τιμή και ποια μένουν NULL.
- Οι `SUPPLIER` και `AGGREGATOR` μένουν, γιατί είναι εταιρείες και όχι ρόλοι.
- Όλα τα FK που έδειχναν σε πίνακα ρόλου δείχνουν τώρα στο `USER_ACCOUNT(UserID)`. Το αν ο χρήστης έχει τον σωστό ρόλο
  το ελέγχει το stored procedure.
- Έφυγε το `UNIQUE (Email)`, γιατί το ίδιο άτομο μπορεί να έχει 2 usernames, π.χ. ένα ως τεχνικός και ένα ως καταναλωτής.

## 2. Μετρήσεις: raw → VEE → validated
- Ο πίνακας `READING` χωρίζεται σε δύο. Ο `RAW_READING` κρατά ό,τι ήρθε από τα πακέτα, με `VeeStatus` Pending, Validated ή Suspect.
  Ο `VALIDATED_READING` κρατά ό,τι έβγαλε το VEE, με `Quality` Validated, Estimated ή Edited και με `RunID`.
- Οι γραμμές του `VALIDATED_READING` δεν αλλάζουν ποτέ. Αυτό το εξασφαλίζει το trigger `TR_VALIDATED_READING_Immutable`, που απορρίπτει
  κάθε UPDATE. Και το DELETE απορρίπτεται, εκτός αν το κάνει η διαδικασία διατήρησης (3 χρόνια ή αίτημα GDPR), που πρώτα τρέχει
  `EXEC sp_set_session_context N'mdms_purge', 1`.
- Το `READING_EDIT` γράφει τις διορθώσεις και τις εκτιμήσεις που κάνει το VEE πριν από την επικύρωση. Δείχνει πλέον σε `METER` και `OBIS_CODE`,
  επειδή μια εκτίμηση για κενό δεν έχει raw γραμμή.
- Τα `METER_AGGREGATE` υπολογίζονται μόνο από το `VALIDATED_READING`.

## 3. Μετασχηματιστές: αυστηρό δέντρο
- Στον `TRANSFORMER` προστέθηκε η στήλη `ParentTransformerID`, ένα FK προς τον ίδιο πίνακα. Κάθε μετασχηματιστής έχει έναν γονέα, και η ρίζα έχει NULL.
- Το trigger `TR_TRANSFORMER_Tree` ελέγχει δύο πράγματα: ότι ο γονέας δεν έχει μετρητές και ότι δεν δημιουργείται κύκλος.
  Το `TR_METER_LeafTransformer` ελέγχει ότι μετρητής μπαίνει μόνο σε φύλλο.
- Το `GEOFENCE` έχασε τις στήλες `ParentGeofenceID` και `Level`. Παραμένει 1:1 με μετασχηματιστή, και την ιεραρχία του την παίρνει από το δέντρο
  των μετασχηματιστών. Αυτό είναι υπόθεση. Τα geofences που σχεδιάζονται ελεύθερα στον χάρτη είναι μελλοντική επέκταση.

## 4. Aggregates στους μετασχηματιστές
- Ο `GEOFENCE_AGGREGATE` αντικαθίσταται από τον `TRANSFORMER_AGGREGATE`, μόνο για φύλλα (το ελέγχει το trigger `TR_TRANSFORMER_AGGREGATE_Leaf`).
  Έχει `PeriodType` = Day, Month ή Year, όπως και ο `METER_AGGREGATE`. Ο καθηγητής είπε να κρατάμε τη μικρότερη περίοδο που χρειαζόμαστε,
  γιατί από τη μικρή βγαίνει η μεγάλη και όχι το αντίθετο: από τους μήνες βγαίνει το τρίμηνο. Η ημέρα χρειάζεται για τα Day-Ahead δεδομένα
  των Suppliers/Aggregators (ΙΙΙ.5.2), ο μήνας και το έτος για τις αναφορές.
  *(Διόρθωση 21/11: στην πρώτη έκδοση ο πίνακας ήταν μόνο μηνιαίος.)*
- Ο `GEOFENCE_CURRENT_STATE` αντικαθίσταται από τον `TRANSFORMER_CURRENT_STATE`, πάλι για φύλλα.
- Τα πάνω επίπεδα δεν αποθηκεύονται. Υπολογίζονται όταν ζητηθούν, με αναδρομικό CTE πάνω στο δέντρο. Παράδειγμα υπάρχει στο `test-step0.sql`, έλεγχος 4c.

## Πώς το τρέχω στη βάση μου (π.χ. sharal01)
1. Στο SSMS: τρέξε `sql/drop.sql`. Σβήνει τους πίνακες του MDMS, και παλιούς και νέους, ενώ αφήνει τους πίνακες των labs.
2. Τρέξε `sql/create.sql`. Πρέπει να δεις 56 νέους πίνακες.
3. Για έλεγχο: τρέξε το `sql/test-step0.sql`. Πρέπει να βγάλει 17 γραμμές OK. Μετά ξανατρέξε `drop.sql` και `create.sql`, ώστε η βάση να μείνει άδεια.

Δοκιμασμένο σε SQL Server 2025 (RTM-CU11): το create τρέχει, το drop αφήνει 0 πίνακες και ξανατρέχει, το drop πάνω στο παλιό σχήμα
της Φάσης Α δουλεύει, και το test βγάζει 17/17 OK (ξανά 21/11 μετά την προσθήκη του `PeriodType`).
