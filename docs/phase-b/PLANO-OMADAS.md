# Πλάνο Φάσης Β – Ομάδα 12 (MDMS-Cy)

> Ενημέρωση: 21/11/26. Παράδοση: **Παρασκευή 4/12/26, 12:00**, στο Moodle. Εμείς στοχεύουμε να υποβάλουμε **πριν τις 11:00**.
> Τρία αρχεία, με αυτή τη σειρά:
> 1. **Αυτό το πλάνο**: τι φτιάχνουμε, πώς είναι χωρισμένο, τι παραδίδουμε, αποφάσεις.
> 2. **[TASKS.md](TASKS.md)**: ο πίνακας εργασιών, δηλαδή ποιος κάνει τι αυτή τη στιγμή και ποιος κάνει review σε ποιον. **Ενημερώνεται από όλους.**
> 3. **[ODIGOS-SYNERGASIAS.md](ODIGOS-SYNERGASIAS.md)**: πώς δουλεύουμε (GitHub, reviews, βάσεις, Claude).

## 0. Με μια ματιά

| | |
|---|---|
| **Τι παραδίδουμε** | Το `12.zip` με τους φακέλους `sources/`, `sql/`, `data/` και `docx/`. Το `docx/` το φέρνουμε και τυπωμένο στο εργαστήριο. |
| **Τι μετρά** | Μόνο το τελικό σύστημα, που πρέπει να δουλεύει. Το UI πρέπει να δείχνει **τη δική μας βάση**, όχι κάτι άλλο. Το demo κρατά **30 λεπτά** ανά ομάδα και δείχνει βασικές λειτουργίες. Το UI ο καθηγητής το βλέπει και offline. |
| **Πού είμαστε** | Η Φάση Α υποβλήθηκε. Το **Βήμα 0** είναι έτοιμο: το νέο σχήμα με τις διορθώσεις του καθηγητή βρίσκεται στο `sql/create.sql` (56 πίνακες, 17/17 έλεγχοι OK σε SQL Server 2025). Τι άλλαξε και γιατί εξηγείται στο [sql/ALLAGES.md](../../sql/ALLAGES.md). |
| **Ποιος κάνει τι** | **Σωτήρης**: login, ρόλοι, Admin/Operator, Καταναλωτές (ΙΙΙ.1), ασφάλεια. **Δανάη**: Τεχνικοί και μετρητές (ΙΙΙ.2), Suppliers και Aggregators (ΙΙΙ.5), επέκταση, εγχειρίδιο. **Αντρέας**: DSO και VEE (ΙΙΙ.3), TSO (ΙΙΙ.4), ταυτοχρονία, τεστ απόδοσης. |
| **Κανόνας εκφώνησης** | «Όλα τα μέλη ασχολούνται με όλα τα στάδια». Γι' αυτό ο καθένας παίρνει ολόκληρη περιοχή, δηλαδή procedures, PHP, δεδομένα, ένα index και ένα κείμενο τεκμηρίωσης. Και ο καθένας πρέπει να μπορεί να εξηγήσει **όλο** το σύστημα στην εξέταση. |

---

## 1. Τι λέει η εκφώνηση ότι παραδίδουμε (ενότητα V.Α)

| Φάκελος στο zip | Τι μπαίνει | Από ποια αρχεία του repo |
|---|---|---|
| `sources/` | Όλος ο κώδικας PHP/HTML/CSS/JS της εφαρμογής | `sources/` |
| `sql/` | Όλα τα .sql: `create.sql`, `drop.sql`, procedures, `indexes.sql`, `select.sql` κ.λπ. | `sql/` |
| `data/` | Τα αρχεία δεδομένων (.dat), που πρέπει να μπορούν να γίνουν import στη βάση. Ένα μικρό σύνολο για έλεγχο κι ένα μεγάλο, με χιλιάδες γραμμές. | `data/` |
| `docx/` | (α) **Εγχειρίδιο χρήστη**: οδηγίες χρήσης, βασικές επιλογές σχεδίασης, επιπλέον λειτουργίες, δυσκολίες, τελικό ER, λεξικό δεδομένων, περιορισμοί και βελτιώσεις. (β) **Χωριστό έγγραφο** για: contention points, ασφάλεια, μελλοντική επέκταση. | `docs/phase-b/` (τα γράφουμε σε .md και στο τέλος γίνονται .docx/.pdf) |

Απαιτήσεις από την ενότητα IV που βαθμολογούνται:

- **Login**: κάθε χρήστης μπαίνει με username και κωδικό. Οι κωδικοί αποθηκεύονται μόνο ως hash.
- **Η λογική βρίσκεται στη βάση**: ερωτήματα, έλεγχοι και λειτουργίες γίνονται σε stored procedures. Το PHP μόνο τα καλεί.
- **Κάθε λειτουργία είναι μία ατομική ενέργεια**: ή γίνονται όλες οι αλλαγές ή καμία. Αυτό σημαίνει transaction με TRY/CATCH.
- **Ιχνηλασιμότητα**: κάθε κρίσιμη αλλαγή γράφεται στο `AUDIT_LOG` με αντικείμενο, χρήστη ή μηχανισμό, χρόνο, παλιά και νέα κατάσταση, και σχόλιο.
- **Συνθετικά δεδομένα**: ένα μικρό σύνολο κι ένα μεγάλο, με χιλιάδες γραμμές. Το μέγεθος βαθμολογείται.
- **3 indexes**: εξηγούμε ποια επιλέξαμε, γιατί και πώς. Δείχνουμε και **μία περίπτωση «πριν/μετά»** όπου ένα index ή ένα καλύτερο query μειώνει το κόστος.
- **Απόδοση**: κάτω από 2 δευτερόλεπτα για το 95% των συνηθισμένων OLTP ερωτημάτων, σε 10.000 αιτήσεις.
- **Ασφάλεια**: μη εξουσιοδοτημένη πρόσβαση και SQL injection.
- **Ταυτοχρονία**: transactions, isolation levels και ενδιάμεσοι πίνακες. Π.χ. νέες μετρήσεις φτάνουν ενώ τρέχει το VEE.
- **Επέκταση χωρίς αλλαγή δομής**: νέοι τύποι μετρητών, πρωτόκολλα, κλάσεις prosumer, νέοι κανόνες VEE.
- **Bonus +10%**: χάρτες Leaflet ή άλλη πρωτοτυπία.

**Εξέταση (ενότητα V.Γ):** σε ημερομηνία που θα ανακοινωθεί στο Moodle, **όλα τα μέλη** δείχνουν τη σχεδίαση και την υλοποίηση. Όποιος λείπει μηδενίζεται. Βαθμολογούνται: η ορθότητα του ER και του σχήματος, η ορθότητα λειτουργίας, η απόδοση και η ταυτοχρονία, η έκταση της υλοποίησης και η πρωτοτυπία.

**Τελικό ER:** στο εγχειρίδιο μπαίνει το **τελικό** ER, που πρέπει να ταιριάζει με το τελικό `create.sql`. Το φτιάχνουμε ξανά στο τέλος (εργασία E2), όταν δουλεύουν όλα.

---

## 2. Κοινοί κανόνες γραφής κώδικα (για όλους και για κάθε Claude)

### 2.1 Stored procedures

- Όνομα: `sp_<περιοχή>_<ρήμα>`, π.χ. `sp_consumer_list_invoices`, `sp_dso_run_vee`. Περιοχές: `auth`, `admin`, `operator`, `consumer`, `gdpr`, `tech`, `task`, `meter`, `supplier`, `aggregator`, `market`, `dso`, `vee`, `tso`.
- Η **πρώτη παράμετρος** είναι πάντα `@UserID` (ποιος κάνει την ενέργεια). Το procedure ελέγχει πρώτα ότι ο χρήστης έχει τον σωστό `Role` και ότι το `AccountStatus` είναι `'Active'`.
- Όταν το procedure γράφει σε πάνω από έναν πίνακα: `SET XACT_ABORT ON; BEGIN TRY BEGIN TRAN … COMMIT END TRY BEGIN CATCH ROLLBACK; THROW; END CATCH`.
- Κάθε αλλαγή κατάστασης γράφει μία γραμμή στο `AUDIT_LOG`.
- Τα procedures μπαίνουν σε αρχεία ανά περιοχή, ένα αρχείο για κάθε άτομο, για να μη συγκρούονται τα PR:
  `sql/procs_common.sql` (Σωτήρης), `sql/procs_consumer.sql` (Σωτήρης), `sql/procs_technician.sql` (Δανάη), `sql/procs_market.sql` (Δανάη), `sql/procs_dso.sql` (Αντρέας), `sql/procs_tso.sql` (Αντρέας).
  Κάθε αρχείο αρχίζει με `CREATE OR ALTER PROCEDURE`, ώστε να ξανατρέχει χωρίς drop.
- Κάθε procedure έχει τουλάχιστον μία κλήση δοκιμής στο `sql/tests/test_<περιοχή>.sql`. Η κλήση δείχνει μια περίπτωση που πετυχαίνει και μια που πρέπει να αποτύχει (λάθος ρόλος ή λάθος δεδομένα).

Πρότυπο:

```sql
CREATE OR ALTER PROCEDURE sp_consumer_pay_invoice
    @UserID INT, @InvoiceID INT, @BankAccountID INT, @Amount DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'Consumer' AND AccountStatus = 'Active')
        THROW 51000, N'Δεν επιτρέπεται: μόνο ενεργός Καταναλωτής.', 1;
    IF NOT EXISTS (SELECT 1 FROM INVOICE WHERE InvoiceID = @InvoiceID AND UserID = @UserID)
        THROW 51001, N'Το τιμολόγιο δεν είναι δικό σας.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(14) = (SELECT Status FROM INVOICE WITH (UPDLOCK) WHERE InvoiceID = @InvoiceID);
        INSERT PAYMENT (Amount, PaidAt, Reference, InvoiceID, BankAccountID)
        VALUES (@Amount, SYSUTCDATETIME(), CONVERT(NVARCHAR(50), NEWID()), @InvoiceID, @BankAccountID);
        UPDATE INVOICE
        SET Status = CASE WHEN (SELECT SUM(Amount) FROM PAYMENT WHERE InvoiceID = @InvoiceID) >= Amount
                          THEN 'Paid' ELSE 'Partially paid' END
        WHERE InvoiceID = @InvoiceID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        SELECT 'INVOICE', @InvoiceID, 'Payment', @old, Status, @UserID FROM INVOICE WHERE InvoiceID = @InvoiceID;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
```

> Πριν γράψεις ένα procedure, κοίτα στο `sql/create.sql` τα **ακριβή** ονόματα στηλών και τα CHECK, π.χ. ποιες τιμές δέχεται το `INVOICE.Status`. Δεν επινοούμε στήλες. Αν λείπει κάτι από το σχήμα, ακολουθούμε τη διαδικασία αλλαγής σχήματος του Οδηγού συνεργασίας.

### 2.2 PHP

- Ξεκινάμε από τον σκελετό του Lab 7 (`index.php` → `connect.php` → `q1–q3.php`), αλλά με μία μεγάλη αλλαγή: ο χρήστης γράφει το **username του MDMS-Cy**, όχι το SQL login. Τα στοιχεία σύνδεσης στη βάση μένουν στο `sources/config.php`, που **δεν μπαίνει ποτέ στο git**. Στο git μπαίνει μόνο το `config.example.php`.
- Μέσα στο PHP δεν γράφουμε SQL, μόνο κλήσεις `{CALL sp_…(?, ?)}` με παραμέτρους `?`. Αυτό κλείνει το SQL injection.
- Κάθε σελίδα ξεκινά με `require_role('Consumer')` ή τον ρόλο που της αντιστοιχεί, και ό,τι εμφανίζει περνά από `htmlspecialchars`.
- Οι κωδικοί φτιάχνονται με `password_hash()` και ελέγχονται με `password_verify()`.

Δομή:

```
sources/
  config.example.php   πρότυπο: serverName = "mssql.cs.ucy.ac.cy\\SQL2025", Database, Uid, PWD (το αληθινό config.php ΟΧΙ στο git)
  db.php               σύνδεση + call_proc($name, $params) + print_table($stmt) + λάθη
  auth.php             session, require_role(), current_user()
  index.php            φόρμα login + σύνδεσμοι εγγραφής (Καταναλωτής, Τεχνικός)
  login.php  logout.php  register_consumer.php  register_technician.php
  admin/ operator/ consumer/ technician/ supplier/ aggregator/ dso/ tso/
  css/style.css  images/ucy.jpg
```

Κλήση ενός procedure, όπως στο q3.php του lab:

```php
$stmt = sqlsrv_query($conn, "{CALL sp_consumer_list_invoices(?, ?)}", [$_SESSION['UserID'], $year]);
while ($row = sqlsrv_fetch_array($stmt, SQLSRV_FETCH_ASSOC)) { /* … */ }
```

### 2.3 Ρόλοι (τιμές του `USER_ACCOUNT.Role`)

| Role | Ποιος | Πώς δημιουργείται |
|---|---|---|
| `Admin` | Διαχειριστής Συστήματος (ΔΣ), root | Με το χέρι στη βάση (data) |
| `Operator` | Λειτουργός Συστήματος (ΛΣ) | Από Admin (`CreatedBy`) |
| `Consumer` | Καταναλωτής (ΚΧ) | Self-registration, χωρίς έγκριση |
| `Technician` | Τεχνικός Πεδίου (ΤΠ) | Self-registration, `ApprovalStatus = 'Pending'` μέχρι να εγκρίνει Operator |
| `DSO`, `TSO` | Λειτουργοί διανομής / δικτύου | Από Admin |
| `Supplier`, `Aggregator` | Χρήστες εταιρειών αγοράς | Από Admin, με `SupplierID` / `AggregatorID` |

Ένα username αντιστοιχεί σε **ακριβώς έναν ρόλο**. Αν το ίδιο άτομο έχει δύο ρόλους, π.χ. είναι τεχνικός και καταναλωτής, έχει δύο usernames. Αυτό το είπε ρητά ο καθηγητής.

## 2Α. Πώς είναι χωρισμένη η δουλειά ώστε να μην περιμένει ο ένας τον άλλον

Η ιδέα είναι απλή. **Πρώτα φτιάχνεται ένα κοινό θεμέλιο** (εργασίες F1–F4 στο [TASKS.md](TASKS.md), έως 22/11). Μετά **ο καθένας δουλεύει μόνος στην περιοχή του** και δεν χρειάζεται τίποτα από τους άλλους μέχρι την ενοποίηση στις 30/11.

**Το θεμέλιο (F1–F4)** περιλαμβάνει:
- **Σχήμα** (`sql/create.sql`), που είναι ίδιο για όλους.
- **Κοινά δεδομένα** (`data/small/00_base.sql`): ένας χρήστης για κάθε ρόλο, γεωγραφία, κωδικοί OBIS, δέντρο μετασχηματιστών, premises με καταναλωτές και συμβόλαια, **ενεργοί** μετρητές, 2 μέρες **validated** μετρήσεις, ημερήσια aggregates και λίγα raw.
  Με αυτά ο Σωτήρης δείχνει μετρήσεις καταναλωτή χωρίς να περιμένει το VEE του Αντρέα. Ο Αντρέας κάνει ingestion σε ενεργούς μετρητές χωρίς να περιμένει την εγκατάσταση της Δανάης. Η Δανάη δείχνει aggregates σε suppliers χωρίς να περιμένει τον Αντρέα.
- **Σκελετός PHP** (`sources/`): login, έλεγχος ρόλου, σύνδεση στη βάση, και **αυτόματο μενού**. Κάθε αρχείο στον φάκελο ενός ρόλου, π.χ. `sources/technician/tasks.php`, που ξεκινά με `<?php // MENU: Εργασίες` εμφανίζεται μόνο του στο μενού. Έτσι **κανείς δεν αλλάζει κοινό αρχείο** για να προσθέσει σελίδα.

**Κανόνας 1: κάθε πίνακας έχει έναν «ιδιοκτήτη» που γράφει σε αυτόν.** Οι άλλοι μόνο διαβάζουν (SELECT) με τα δικά τους procedures.

| Ιδιοκτήτης | Γράφει (INSERT/UPDATE/DELETE) σε |
|---|---|
| **Σωτήρης** | `USER_ACCOUNT` (όλοι οι ρόλοι **εκτός** Technician), `CONSUMER_NOTIFICATION_CHANNEL`, `PREMISE`, `HOLDING`, `BANK_ACCOUNT`, `ACCOUNT_FOR`, `CONSUMPTION_THRESHOLD`, `SUPPLY_CONTRACT`, `INVOICE`, `PAYMENT`, `SERVICE_TYPE`, `SERVICE_PURCHASE`, `SERVICE_REQUEST`, `TARIFF_TYPE`, `METER_MODEL`, `SUPPLIER`, `AGGREGATOR`, `GDPR_REQUEST` |
| **Δανάη** | `USER_ACCOUNT` (**μόνο** γραμμές με Role = Technician: εγγραφή και έγκριση), `TECHNICIAN_CATEGORY`, `IN_CATEGORY`, `DOCUMENT`, `AVAILABILITY`, `AVAILABLE_IN`, `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES`, `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `COMM_TYPE`, `REMOTE_COMMAND`, `COMMAND_ATTEMPT`, `LEADS_TO`, `PORTFOLIO`, `INCLUDES` |
| **Αντρέας** | `TELEMETRY_PACKET`, `RAW_READING`, `VALIDATED_READING`, `READING_EDIT`, `OBIS_CODE`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE`, `TRANSFORMER_CURRENT_STATE`, `EVENT`, `TRANSFORMER`, `GEOFENCE`, `LOAD_SHED_ORDER` |
| **Όλοι** | `AUDIT_LOG`, μόνο INSERT |
| **Μόνο τα κοινά δεδομένα** | `DISTRICT`, `MUNICIPALITY`, `PARISH`, `SUPPLY_SCHEME` |

**Κανόνας 2: οι λίγες εξαιρέσεις είναι γραμμένες εδώ και δεν αλλάζουν χωρίς συμφωνία («συμφωνίες» μεταξύ περιοχών):**

| # | Ποιος | Τι κάνει σε πίνακα άλλου | Ακριβώς πώς |
|---|---|---|---|
| Σ1 | Δανάη (D5) | Όταν φτιάχνει εργασία από αίτημα καταναλωτή | `UPDATE SERVICE_REQUEST SET Status = 'Assigned'` και, όταν η εργασία γίνει Done, `'Resolved'`. Τίποτε άλλο. |
| Σ2 | Αντρέας (A1) | Δέχεται μετρήσεις **μόνο** από μετρητή με `METER.Status = 'Active'` | Μόνο διαβάζει. Ενεργοί μετρητές υπάρχουν ήδη στα κοινά δεδομένα. |
| Σ3 | Αντρέας (A9) | Το load shedding φτιάχνει εντολές | `INSERT REMOTE_COMMAND (CommandType = 'Disconnect', Status = 'Sent', ShedOrderID = …)`. Οι σελίδες της Δανάης τις δείχνουν όπως όλες τις εντολές. |
| Σ4 | Αντρέας (A1, A5) → Δανάη (D9) | Συμβάν που οδηγεί σε εργασία | Ο Αντρέας γράφει `EVENT`. Η Δανάη διαβάζει `EVENT` με `Status = 'Open'` και γράφει `FIELD_TASK` + `LEADS_TO`. Μετά κάνει `UPDATE EVENT SET Status = 'In progress'`, και αυτή είναι η μόνη αλλαγή της στο `EVENT`. |
| Σ5 | Σωτήρης (S10) | Διαγραφή παλιών μετρήσεων (retention/GDPR) | `EXEC sp_set_session_context N'mdms_purge', 1;` και μετά `DELETE` στα `RAW_READING` και `VALIDATED_READING`. Ποτέ UPDATE. |
| Σ6 | Σωτήρης (S5) / Δανάη (D10–D12) | Διαβάζουν μετρήσεις και aggregates του Αντρέα | Μόνο SELECT στα `VALIDATED_READING`, `METER_AGGREGATE`, `RAW_READING` (μόνο για Intraday). Η σημασία κάθε στήλης ορίζεται στην ενότητα 2Β, απόφαση Α2. |

**Κανόνας 3: δικά σου αρχεία, δικά σου IDs.** Ο καθένας έχει δικό του αρχείο procedures, δοκιμών και μικρών δεδομένων (`data/small/10_soteris.sql`, `20_danai.sql`, `30_andreas.sql`). Αυτά βασίζονται **μόνο** στο `00_base.sql`, ποτέ στο αρχείο άλλου. Για τις γραμμές που προσθέτει ο καθένας στα δεδομένα του, χρησιμοποιεί IDs στο δικό του εύρος: **Σωτήρης 1000–1999, Δανάη 2000–2999, Αντρέας 3000–3999**, με `SET IDENTITY_INSERT`. Έτσι δεν συγκρούονται ποτέ.

## 2Β. Αποφάσεις που κλείνουν τις ασάφειες

Αυτές ισχύουν για όλους. Αν κάποιος θέλει να αλλάξει μία, το λέει στο group και, αν συμφωνήσουν όλοι, την αλλάζει εδώ και γράφει μία γραμμή στο «Ιστορικό αλλαγών» του [TASKS.md](TASKS.md).

| # | Θέμα | Απόφαση |
|---|---|---|
| Α1 | Χρόνος | Όλοι οι χρόνοι αποθηκεύονται σε **UTC** (`SYSUTCDATETIME()`). Οι μετρήσεις έχουν `IntervalStart` στο 15λεπτο: :00, :15, :30, :45. |
| Α2 | Τιμές μετρήσεων | `RAW_READING.ReceivedValue` = ό,τι έστειλε ο μετρητής, που για το 1.8.0 είναι ο **μετρητής από την εγκατάσταση**. `VALIDATED_READING.Value` = η **ενέργεια του 15λεπτου** (διαφορά από το προηγούμενο 15λεπτο) για τους σωρευτικούς κωδικούς (`OBIS_CODE.Kind = 'Cumulative register'`), και η **μετρημένη τιμή** για τους στιγμιαίους (τάση, ένταση). Τα aggregates και η τρέχουσα κατάσταση αθροίζουν το `Value` και μόνο για σωρευτικούς κωδικούς. Αυτό είναι η απόφαση D12 της Φάσης Α. |
| Α3 | Κωδικοί χρηστών | `password_hash()` στο PHP, `password_verify()` στο login. Η βάση αποθηκεύει μόνο το hash. Όλοι οι χρήστες demo έχουν τον ίδιο κωδικό δοκιμής, γραμμένο στο σχόλιο του `data/small/00_base.sql`. Δεν είναι πραγματικός κωδικός κανενός. |
| Α4 | Αριθμοί λαθών (`THROW`) | Σωτήρης **51000–51999**, Δανάη **52000–52999**, Αντρέας **53000–53999**, κοινά **50000–50999**. Τα μηνύματα είναι στα ελληνικά, με `N'…'`. |
| Α5 | Γλώσσα | Το UI είναι στα ελληνικά. Ονόματα πινάκων, στηλών και procedures στα αγγλικά. Τα αρχεία είναι UTF-8. |
| Α6 | Πού τρέχει η εφαρμογή | Ο καθένας στο `~/public_html/mdms/` του λογαριασμού του, με τη δική του βάση. Το τελικό στο `~sharal01/mdms/` με τη βάση `sharal01`. Server: `mssql.cs.ucy.ac.cy\SQL2025`. |
| Α7 | Κωδικός βάσης | Μόνο στο `sources/config.php`, που **δεν μπαίνει στο git**. Στο git μπαίνει το `config.example.php`. |
| Α8 | Δεδομένα (.dat) | Τα scripts του `data/gen/` βγάζουν για κάθε πίνακα ένα `.dat` (CSV, UTF-8) **και** ένα `.sql` με τα ίδια INSERT. Import σημαίνει να τρέξεις το `.sql` στο SSMS, γιατί το `BULK INSERT` στον server του Τμήματος δεν βλέπει αρχεία του υπολογιστή μας. Γράφεται έτσι και στο εγχειρίδιο. |
| Α9 | Σειρά εκτέλεσης | `drop.sql` → `create.sql` → `procs_common.sql` → τα υπόλοιπα `procs_*.sql` → `indexes.sql` → `data/small/00_base.sql` → `data/small/10–30_*.sql` (ή `data/import.sql` για τα μεγάλα). |
| Α10 | Αλλαγή σχήματος | Μόνο όπως περιγράφει ο Οδηγός, ενότητα 5. Μετά τις 27/11 γίνεται μόνο αν δεν βγαίνει κάτι ★. |
| Α11 | Merge | Μόνο ο Σωτήρης, και μόνο μετά από ✓ του reviewer. Αν περάσουν 24 ώρες χωρίς review, ο Σωτήρης ελέγχει μόνος του. |
| Α12 | Code freeze | Τετάρτη 2/12 το βράδυ. Μετά γίνονται μόνο διορθώσεις λαθών. |
| Α13 | Τελικό ER | Το ER **ξαναγίνεται στο τέλος** (εργασία E2, 2/12), από το τελικό `create.sql`. Μέχρι τότε η αλήθεια βρίσκεται στο `create.sql` και στο `sql/ALLAGES.md`. |

---

## 3. Η δουλειά ανά περιοχή: τι ακριβώς φτιάχνουμε

Για κάθε λειτουργία της εκφώνησης δίνονται τα procedures που χρειάζονται, οι πίνακες και η σελίδα PHP. Ο κωδικός της εργασίας (S…, D…, A…) είναι ίδιος με τον κωδικό στο [TASKS.md](TASKS.md). Τα ονόματα των procedures είναι προτάσεις, και οι παράμετροι μπορούν να αλλάξουν. Με ★ σημειώνεται ό,τι **πρέπει** να φαίνεται στο demo.

### 3.Α Κοινά: login, Admin, Operator (Σωτήρης)

| Λειτουργία | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| ★ Login | `sp_auth_get_login(@Username)`: επιστρέφει UserID, PasswordHash, Role, AccountStatus, ApprovalStatus. Το PHP κάνει `password_verify` και στέλνει τον χρήστη στο μενού του ρόλου του. Ένας τεχνικός που είναι ακόμη Pending βλέπει μόνο το μήνυμα «περιμένει έγκριση». | `USER_ACCOUNT` | `index.php`, `login.php` |
| ★ Εγγραφή καταναλωτή | `sp_auth_register_consumer(@Username, @PasswordHash, @Email, @Phone, @FirstName, @LastName)`, με `RawRetentionMonths = 36` | `USER_ACCOUNT`, `CONSUMER_NOTIFICATION_CHANNEL` | `register_consumer.php` |
| Δημιουργία χρηστών από Admin | `sp_admin_create_user(@UserID, @Role, …)` για Operator, DSO, TSO, Supplier και Aggregator | `USER_ACCOUNT`, `SUPPLIER`, `AGGREGATOR` | `admin/users.php` |
| Αναστολή / ενεργοποίηση χρήστη | `sp_admin_set_account_status` | `USER_ACCOUNT`, `AUDIT_LOG` | `admin/users.php` |
| Κατάλογοι του Operator | `sp_operator_save_meter_model`, `sp_operator_save_service_type`, `sp_operator_save_tariff_type` | `METER_MODEL`, `SERVICE_TYPE`, `TARIFF_TYPE` | `operator/catalogs.php` |
| Προβολή log | `sp_admin_audit_log(@UserID, @ObjectType, @From, @To)` | `AUDIT_LOG` | `admin/log.php` |

### 3.Β ΙΙΙ.1 Καταναλωτές και υποστατικά (Σωτήρης)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 1.1 ★ Ο καταναλωτής συνδέεται με 1 ή περισσότερα υποστατικά. Κάθε υποστατικό έχει Premise ID, διεύθυνση, WGS84, χρήση (Οικιακό, Εμπορικό, Βιομηχανικό, Γεωργικό), Επαρχία, Δήμο, Ενορία και ΤΚ | `sp_consumer_add_premise` (PREMISE + HOLDING σε ένα transaction), `sp_consumer_list_premises`, `sp_consumer_end_holding` | `PREMISE`, `HOLDING`, `PARISH`, `MUNICIPALITY`, `DISTRICT` | `consumer/premises.php` |
| 1.1 Τραπεζικοί λογαριασμοί | `sp_consumer_add_bank_account` (και `ACCOUNT_FOR` όταν ο λογαριασμός αφορά υποστατικό) | `BANK_ACCOUNT`, `ACCOUNT_FOR` | `consumer/bank.php` |
| 1.2 ★ 15λεπτες χρονοσειρές των μετρητών **μόνο των δικών του** υποστατικών. Εισαγωγή (1.8.0) και εξαγωγή (2.8.0) χωριστά για prosumers | `sp_consumer_readings(@UserID, @MeterID, @From, @To)`: ο **τρέχων μήνας είναι δωρεάν**. Για προηγούμενους μήνες χρειάζεται `SERVICE_PURCHASE` που να καλύπτει τον μήνα, και τα δεδομένα πρέπει να είναι ακόμη μέσα στο `RawRetentionMonths`. Για ιστορικό χρησιμοποιείται ο `METER_AGGREGATE` (Day, Month, Year). | `VALIDATED_READING`, `METER_AGGREGATE`, `METER_INSTALLATION`, `HOLDING`, `SERVICE_PURCHASE` | `consumer/readings.php` (πίνακας, και γράφημα αν προλάβουμε) |
| 1.2 Αγορά πρόσβασης σε ιστορικό | `sp_consumer_buy_history(@UserID, @PremiseID, @MonthFrom, @MonthTo)` (SERVICE_PURCHASE + χρέωση) | `SERVICE_PURCHASE`, `SERVICE_TYPE`, `INVOICE` | `consumer/history.php` |
| 1.2 Thresholds και ειδοποιήσεις (email/SMS), συμβάντα υπότασης/υπέρτασης | `sp_consumer_set_threshold`, `sp_consumer_set_channels`, `sp_consumer_quality_events` | `CONSUMPTION_THRESHOLD`, `CONSUMER_NOTIFICATION_CHANNEL`, `EVENT` | `consumer/settings.php` |
| 1.3 ★ Αίτημα ελέγχου ή βλάβης, με κατάσταση και ιστορικό | `sp_consumer_submit_request`, `sp_consumer_list_requests` (μαζί με το `FIELD_TASK` που προέκυψε) | `SERVICE_REQUEST`, `FIELD_TASK`, `AUDIT_LOG` | `consumer/requests.php` |
| 1.3 ★ Ιστορικό χρεώσεων και πληρωμών | `sp_consumer_list_invoices`, `sp_consumer_list_payments`, `sp_consumer_pay_invoice` | `INVOICE`, `PAYMENT`, `SUPPLY_CONTRACT`, `SUPPLIER` | `consumer/billing.php` |
| 1.4 ★ GDPR, δικαίωμα στη λήθη. Η ροή είναι υποβολή → εξέταση/προέγκριση από Operator → τελική απόφαση από Admin → εφαρμογή, και κάθε στάδιο γράφεται στο log | `sp_gdpr_submit`, `sp_gdpr_preapprove` (Operator), `sp_gdpr_decide` (Admin), `sp_gdpr_apply`. Η εφαρμογή σβήνει ή ανωνυμοποιεί τα προσωπικά στοιχεία που επιτρέπεται να φύγουν, αλλά **κρατά** τιμολόγια και πληρωμές. Επίσης βάζει `RawRetentionMonths = 1`. | `GDPR_REQUEST`, `USER_ACCOUNT`, `BANK_ACCOUNT`, `AUDIT_LOG` | `consumer/gdpr.php`, `operator/gdpr.php`, `admin/gdpr.php` |
| 1.4 Διατήρηση δεδομένων: raw για 3 χρόνια ή 1 μήνα μετά από GDPR. Τα aggregates μένουν. Οι μετρήσεις μετασχηματιστών μένουν για πάντα | `sp_retention_purge(@UserID, @AsOf)`. Κάνει `sp_set_session_context N'mdms_purge', 1` και σβήνει παλιές γραμμές από `RAW_READING` και `VALIDATED_READING` | `RAW_READING`, `VALIDATED_READING` | κουμπί στο `admin/` |

### 3.Γ ΙΙΙ.2 Τεχνικοί πεδίου και μετρητές (Δανάη)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 2.1 ★ Self-registration τεχνικού: δεν κάνει τίποτα πριν εγκριθεί από Operator. Γράφεται σε τουλάχιστον 1 κατηγορία και δίνει email, ημερομηνία γέννησης και φωτογραφία | `sp_auth_register_technician` (σε συνεργασία με Σωτήρη), `sp_tech_set_categories` | `USER_ACCOUNT`, `IN_CATEGORY`, `TECHNICIAN_CATEGORY` | `register_technician.php` |
| 2.1 Έγγραφα: Ταυτότητα, Άδεια Εγκαταστάτη, Πιστοποιητικό Κατάρτισης, το καθένα με αριθμό, έκδοση, λήξη και αρχείο | `sp_tech_add_document`, `sp_tech_list_documents` | `DOCUMENT` | `technician/documents.php` |
| 2.1 Ημερήσια διαθεσιμότητα, χρονική και γεωγραφική | `sp_tech_declare_availability` (AVAILABILITY + AVAILABLE_IN) | `AVAILABILITY`, `AVAILABLE_IN`, `MUNICIPALITY` | `technician/availability.php` |
| 2.1 ★ Έγκριση ή απόρριψη τεχνικού από Operator, με καταγραφή | `sp_operator_list_pending_technicians`, `sp_operator_review_document`, `sp_operator_decide_technician` | `USER_ACCOUNT`, `DOCUMENT`, `AUDIT_LOG` | `operator/technicians.php` |
| 2.2 ★ Εργασίες πεδίου (εγκατάσταση, αντικατάσταση, έλεγχος, anti-tamper): ανάθεση, αποδοχή, θέση μετρητή, σημειώσεις, ευρήματα, τεκμήρια | `sp_task_create` (και από `SERVICE_REQUEST`), `sp_task_assign` (ελέγχει Approved, κατηγορία, διαθεσιμότητα), `sp_tech_list_tasks` (με lat/lon), `sp_tech_accept_task`, `sp_tech_add_note`, `sp_tech_add_attachment`, `sp_tech_complete_task` | `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES` | `technician/tasks.php`, `operator/tasks.php` |
| 2.3 ★ Εγκατάσταση μετρητή σε Premise: σειριακός, τύπος, firmware, επικοινωνία, φάσεις, Amps, φωτογραφίες και 3 έγγραφα εξοπλισμού | `sp_tech_install_meter`. Σε ένα transaction γράφει METER (`Status = 'Pending confirmation'`), METER_INSTALLATION και METER_CONNECTED_PHASE. Σε αντικατάσταση κλείνει την παλιά εγκατάσταση και **δεν σβήνει** τις μετρήσεις της. Έπειτα `sp_tech_add_meter_document`. | `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `DOCUMENT` | `technician/install.php` |
| 2.3 ★ Ο Operator επιβεβαιώνει τον μετρητή, και μόνο τότε γίνεται `Active` για ingestion | `sp_operator_confirm_meter(@UserID, @InstallationID, @Approve, @Comment)` | `METER_INSTALLATION`, `METER`, `AUDIT_LOG` | `operator/meters.php` |
| 2.4 Απομακρυσμένες εντολές (διακοπή, επανασύνδεση, firmware) με προσπάθειες μέχρι ACK | `sp_tech_request_command`, `sp_command_record_attempt` (προσομοίωση ACK) | `REMOTE_COMMAND`, `COMMAND_ATTEMPT` | `technician/commands.php` |
| 2.4 Έλεγχοι ασφάλειας και anti-tamper, ποιοι ενημερώνονται, συμβάν → νέα εργασία | `sp_task_create` με τύπο anti-tamper, `sp_event_create_task` | `FIELD_TASK`, `NOTIFIES`, `EVENT`, `LEADS_TO` | `operator/events.php` |

### 3.Δ ΙΙΙ.5 Suppliers και Aggregators (Δανάη)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 5.1 ★ Βλέπουν **μόνο** δεδομένα των δικών τους πελατών ή χαρτοφυλακίων, ποτέ raw. Βλέπουν σύνολο εισαγωγής (1.8.0), εξαγωγής (2.8.0) και καθαρή διαφορά, ανά περίοδο και μετασχηματιστή/geofence | `sp_supplier_aggregates(@UserID, @PeriodType, @From, @To)`: premises με ενεργό `SUPPLY_CONTRACT` του `SupplierID` του χρήστη. `sp_aggregator_aggregates(…)`: premises μέσα στο `PORTFOLIO`/`INCLUDES` του `AggregatorID`. Και τα δύο αθροίζουν `METER_AGGREGATE` ομαδοποιημένα ανά `TransformerID`. | `METER_AGGREGATE`, `SUPPLY_CONTRACT`, `PORTFOLIO`, `INCLUDES`, `METER`, `TRANSFORMER` | `supplier/aggregates.php`, `aggregator/aggregates.php` |
| 5.1 Διαχείριση χαρτοφυλακίου | `sp_aggregator_save_portfolio`, `sp_aggregator_add_premise` | `PORTFOLIO`, `INCLUDES` | `aggregator/portfolio.php` |
| 5.2 ★ Day-Ahead: ημερήσια, επικυρωμένα δεδομένα | Το `sp_supplier_aggregates` με `@PeriodType = 'Day'` | `METER_AGGREGATE` (Day) | ίδια σελίδα |
| 5.2 ★ Intraday: 15λεπτα **provisional** aggregates από τις πιο πρόσφατες μετρήσεις, **χωρίς** να περιμένουμε το VEE | `sp_market_intraday(@UserID, @Date)`: αθροίζει `RAW_READING` ανά 15λεπτο για τα δικά τους premises και σημειώνει ότι τα στοιχεία είναι provisional | `RAW_READING` | `supplier/intraday.php` |

### 3.Ε ΙΙΙ.3 DSO: ingestion, VEE, aggregates (Αντρέας)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 3.1 ★ Ένα πακέτο τηλεμετρίας (JSON όπως στο Παράρτημα) αντιστοιχίζεται σε **ενεργό** μετρητή μέσω NetworkID. Οι μετρήσεις μπαίνουν στο σωστό 15λεπτο. Ό,τι δεν ταιριάζει γράφεται ως αποτυχία ή συμβάν, και **ποτέ δεν χάνεται σιωπηλά** | `sp_dso_ingest_packet(@NetworkID, @Timestamp, @NetworkType, @SignalDbm, @PayloadJson)`: TELEMETRY_PACKET, και `OPENJSON` → RAW_READING (`VeeStatus = 'Pending'`). Άγνωστος μετρητής ή OBIS → `IngestStatus` αποτυχίας + `EVENT` | `TELEMETRY_PACKET`, `RAW_READING`, `OBIS_CODE`, `EVENT` | `dso/ingest.php` (φόρμα με JSON για το demo) |
| 3.1 Όλοι οι OBIS του Παραρτήματος, με μεταβλητό σύνολο ανά πακέτο | Οι γραμμές του `OBIS_CODE` στο data. Ένας νέος κωδικός = νέα γραμμή, χωρίς αλλαγή δομής | `OBIS_CODE` | — |
| 3.2 ★ VEE. **Validation**: υποστηριζόμενο OBIS, όρια `MinValid`/`MaxValid`, spike (π.χ. 25,4 μετά από 1,8, 2,0, 1,9), κενά. **Estimation**: γραμμική παρεμβολή (2,0 και 2,2 → 2,1). **Editing**: ελεγχόμενη διόρθωση με παλιά τιμή, νέα τιμή και προέλευση | `sp_dso_run_vee(@UserID, @From, @To)`: VEE_RUN → για κάθε Pending: έλεγχος κανόνων (`VEE_RULE`, `RULE_FOR`) → εκτιμήσεις στο `READING_EDIT` → **INSERT** στο `VALIDATED_READING` (Validated, Estimated ή Edited) → το raw γίνεται Validated, ή Suspect αν θέλει χειροκίνητο έλεγχο. `sp_dso_list_suspect`, `sp_dso_edit_reading` (Manual edit) | `RAW_READING`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `READING_EDIT`, `VALIDATED_READING` | `dso/vee.php` |
| 3.2 ★ Μετά το VEE οι μετρήσεις είναι **αμετάβλητες**, και τα aggregates υπολογίζονται **μόνο** από αυτές | `sp_dso_build_aggregates(@UserID, @Day)`: `METER_AGGREGATE` (Day, και Month/Year όταν κλείνει η περίοδος) και `TRANSFORMER_AGGREGATE` στα φύλλα. Το trigger ήδη απορρίπτει UPDATE στο validated | `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE` | `dso/aggregates.php` |
| Γ. Analytics: βυθίσεις και υπερτάσεις (32.7.0, 52.7.0, 72.7.0), ανισορροπία φάσεων (31/51/71.7.0), ύποπτη ρευματοκλοπή | `sp_dso_detect_events(@UserID, @From, @To)` → `EVENT`. Αρκούν 1 ή 2 απλοί κανόνες | `VALIDATED_READING`, `EVENT` | `dso/events.php` |

### 3.ΣΤ ΙΙΙ.4 TSO: δέντρο μετασχηματιστών, κατάσταση, load shedding (Αντρέας)

| Εκφώνηση και καθηγητής | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 4.1 ★ Οι μετασχηματιστές είναι **δέντρο**: ένας γονέας, μετρητές **μόνο στα φύλλα**. Κάθε μετασχηματιστής έχει ένα geofence (ορθογώνιο) | `sp_tso_add_transformer` (GEOFENCE + TRANSFORMER), `sp_tso_tree` (αναδρομικό CTE με επίπεδα) | `TRANSFORMER`, `GEOFENCE` | `tso/tree.php` |
| 4.1 Από τις συντεταγμένες ενός μετρητή βρίσκουμε σε ποιο geofence ανήκει, και άρα τον μετασχηματιστή | `sp_tso_locate(@Lat, @Lon)`: geofence-φύλλο με `MinLat ≤ lat ≤ MaxLat` κ.λπ. | `GEOFENCE`, `TRANSFORMER` | ίδια |
| 4.2 ★ Τρέχουσα κατάσταση ανά 15λεπτο: SUM των 1.8.0 και 2.8.0 από VEE-verified μετρήσεις. Για το project ο υπολογισμός ξεκινά με κουμπί. Όσες μετρήσεις λείπουν αγνοούνται | `sp_tso_refresh_current_state(@UserID)`: `MERGE` στο `TRANSFORMER_CURRENT_STATE` για τα φύλλα. `sp_tso_current_state(@TransformerID)`: για έναν μη-φύλλο αθροίζει τα φύλλα από κάτω του με CTE | `TRANSFORMER_CURRENT_STATE`, `VALIDATED_READING` | `tso/state.php` |
| Καθηγητής ★: aggregates **αποθηκεύονται μόνο για φύλλα**, και τα πάνω επίπεδα υπολογίζονται όταν ζητηθούν. Μήνας → τρίμηνο | `sp_tso_aggregates(@UserID, @TransformerID, @PeriodType, @From, @To)`: CTE πάνω στο δέντρο, με `GROUP BY` τρίμηνο όταν ζητηθεί | `TRANSFORMER_AGGREGATE` | `tso/aggregates.php` |
| Δ. Remote load shedding σε **όλους** τους μετρητές κάτω από έναν μετασχηματιστή | `sp_tso_load_shed(@UserID, @TransformerID, @Reason)`: LOAD_SHED_ORDER και ένα REMOTE_COMMAND για κάθε μετρητή των φύλλων από κάτω, όλα σε **ένα transaction** | `LOAD_SHED_ORDER`, `REMOTE_COMMAND` | `tso/shed.php` |
| Bonus: χάρτης Leaflet με μετασχηματιστές, geofences και μετρητές | `sp_tso_map_data` | — | `tso/map.php` |

---

## 4. Κοινά κομμάτια (δεδομένα, απόδοση, τεκμηρίωση)

| Κομμάτι | Τι ακριβώς | Ποιος | Αρχεία |
|---|---|---|---|
| **Μικρά δεδομένα** | Ένας χρήστης demo **ανά ρόλο**, με γνωστό κωδικό δοκιμής που γράφεται στο εγχειρίδιο. Δέντρο 3 επιπέδων με 4–6 μετασχηματιστές, 10–20 premises και μετρητές, 2 μέρες μετρήσεις, που να περιέχουν ένα κενό και ένα spike για να φανεί το VEE. Το hash του κωδικού το φτιάχνει το PHP: `php -r "echo password_hash('…', PASSWORD_DEFAULT);"` | Ο καθένας για τους πίνακές του, και ο Σωτήρης τα ενώνει | `data/small/*.sql` |
| **Μεγάλα δεδομένα** | Χιλιάδες γραμμές: π.χ. 2.000 premises και μετρητές, 30 μέρες × 96 15λεπτα × 2 OBIS ≈ 11 εκατ. είναι πολλά, οπότε στοχεύουμε **~200.000–500.000 μετρήσεις**. Ένα script Python βγάζει αρχεία `.dat` (CSV) και `import.sql` | Αντρέας (μετρήσεις), Δανάη (τεχνικοί, εργασίες, αγορά), Σωτήρης (χρήστες, premises, τιμολόγια) | `data/gen/*.py`, `data/large/*.dat`, `data/import.sql` |
| **3 indexes + «πριν/μετά»** | (1) `RAW_READING (VeeStatus) WHERE VeeStatus = 'Pending'`, για το VEE. (2) `FIELD_TASK (TechnicianID, Status)`. (3) `INVOICE (UserID, IssueDate)`. Η περίπτωση «πριν/μετά» δείχνει το (1) ή ένα ερώτημα μετρήσεων με `SET STATISTICS IO, TIME ON` και execution plan, με screenshot | Ο καθένας το δικό του, Αντρέας το «πριν/μετά» | `sql/indexes.sql` |
| **Τεστ απόδοσης** | 10.000 κλήσεις ενός μείγματος OLTP procedures (login, readings καταναλωτή, λίστα εργασιών, ingest). Μετράμε χρόνους και δείχνουμε ότι το 95% είναι κάτω από 2 s | Αντρέας | `tests/perf.php` ή `tests/perf.py` και ο πίνακας αποτελεσμάτων στο doc |
| **Ασφάλεια (doc)** | Hash κωδικών, login και session, έλεγχος ρόλου σε PHP **και** σε procedure, παράμετροι `?` (SQL injection), `htmlspecialchars` (XSS), κανένας κωδικός στο repo, ελάχιστα δικαιώματα (`GRANT EXECUTE` μόνο σε procedures), GDPR | Σωτήρης | `docs/phase-b/asfaleia.md` |
| **Ταυτοχρονία / contention (doc)** | Ingestion ενώ τρέχει το VEE: το VEE διαβάζει μόνο Pending γραμμές με `UPDLOCK, READPAST`, και ένα δεύτερο VEE μπλοκάρεται με `sp_getapplock`. Τα ενδιάμεσα στάδια RAW → VALIDATED και CURRENT_STATE λειτουργούν ως ενδιάμεσοι πίνακες. Transactions και isolation levels. Hot spots: `AUDIT_LOG` και IDENTITY | Αντρέας | `docs/phase-b/taftoxronia.md` |
| **Επέκταση (doc)** | Νέος τύπος μετρητή → γραμμή στο `METER_MODEL`. Νέο πρωτόκολλο → `COMM_TYPE`. Νέος OBIS → `OBIS_CODE`. Νέος κανόνας VEE → `VEE_RULE`. Νέα κλάση prosumer → `SUPPLY_SCHEME`. Geofences σχεδιασμένα ελεύθερα στον χάρτη = future work, όπως είπε ο καθηγητής | Δανάη | `docs/phase-b/epektasi.md` |
| **Εγχειρίδιο χρήστη** | Οδηγίες ανά ρόλο με screenshots, βασικές επιλογές σχεδίασης (και οι 4 αλλαγές του καθηγητή), τελικό ER (ενημερωμένο), λεξικό δεδομένων, υποθέσεις, δυσκολίες, περιορισμοί και βελτιώσεις | Δανάη (κορμός) + ο καθένας τη δική του ενότητα | `docs/phase-b/egxeiridio.md` |
| **Ενημερωμένο ER** | Το ER της Φάσης Α με τις 4 αλλαγές: ένας `USER_ACCOUNT` με Role, `RAW_READING`/`VALIDATED_READING`, αναδρομική σχέση `TRANSFORMER`, aggregates στους μετασχηματιστές | Σωτήρης + Claude | `docs/phase-b/er-teliko.png` |
| **Τελικό zip** | Από καθαρή βάση: drop → create → procs → indexes → import χωρίς λάθος. Μετά φτιάχνεται το `12.zip` | Σωτήρης | — |

---

## 5. Ημερολόγιο (21/11 – 4/12)

Ο κανόνας είναι απλός: **κάθε βράδυ push ό,τι έγινε, έστω και μισό**. Αν κάποιος κολλήσει πάνω από μισή μέρα, το γράφει στο group και κόβουμε από τα έξτρα, ποτέ από τα ★.

| Ημέρα | Σωτήρης | Δανάη | Αντρέας | Μαζί |
|---|---|---|---|---|
| **Σάβ 21/11** | Θεμέλιο F2–F3 (κοινά δεδομένα, σκελετός PHP) με το Claude. drop + create στο `sharal01` | Στήσιμο: GitHub, SSMS, VPN, τρέχει drop + create στη δική της βάση | Το ίδιο | **Κλήση 30'**: διαβάζουμε αυτό το πλάνο και αλλάζουμε ό,τι θέλουμε |
| **Κυρ 22/11** | Σκελετός PHP (`config`, `db`, `auth`, login, μενού ανά ρόλο) + `sp_auth_*` | Λίστα procedures ΙΙΙ.2 και ΙΙΙ.5 στο PR (όνομα, παράμετροι, τι επιστρέφει) | Λίστα procedures ΙΙΙ.3 και ΙΙΙ.4 στο PR | Merge του σκελετού, ώστε όλοι να έχουν login |
| **Δευ 23/11** | Μικρά δεδομένα: ένας χρήστης ανά ρόλο, premises | Μικρά δεδομένα: τεχνικοί, κατηγορίες, μοντέλα μετρητών | Μικρά δεδομένα: δέντρο 3 επιπέδων, OBIS, 2 μέρες μετρήσεις | `data/small/` τρέχει σε καθαρή βάση |
| **Τρί 24 – Πέμ 26/11** | Procedures ΙΙΙ.1 (premises, readings, requests, billing) | Procedures ΙΙΙ.2 (έγκριση τεχνικού, εργασίες, εγκατάσταση, επιβεβαίωση) | Procedures ingestion → VEE → validated | Κάθε procedure έχει EXEC δοκιμής στο `sql/tests/` |
| **Παρ 27/11** | GDPR ροή + Admin/Operator | Procedures ΙΙΙ.5 (supplier, aggregator, intraday) | Aggregates (μετρητής, φύλλα) + TSO (CTE, current state, load shed) | — |
| **Σάβ 28 – Κυρ 29/11** | Σελίδες PHP: Καταναλωτής, Admin, Operator | Σελίδες PHP: Τεχνικός, Operator (τεχνικοί/μετρητές), Supplier, Aggregator | Σελίδες PHP: DSO, TSO | **Ορόσημο**: κάθε ρόλος κάνει login και βλέπει τις ★ οθόνες του |
| **Δευ 30/11** | **Ενοποίηση** σε μία βάση (`sharal01`) και στο `public_html` | Μεγάλα δεδομένα για τους πίνακές της | Μεγάλα δεδομένα: μετρήσεις | `import.sql` τρέχει χωρίς λάθη |
| **Τρί 1/12** | Index τιμολογίων + έλεγχος SQL injection σε όλες τις σελίδες | Index εργασιών | Index μετρήσεων, τεστ 10.000 αιτήσεων, «πριν/μετά» | `sql/indexes.sql` |
| **Τετ 2/12** | Doc ασφάλειας + **νέο ER και λεξικό δεδομένων (E2, E3, με το Claude)** | Εγχειρίδιο + doc επέκτασης | Doc ταυτοχρονίας (+ Leaflet αν προλαβαίνει) | **Code freeze το βράδυ**: μετά μόνο διορθώσεις |
| **Πέμ 3/12** | `12.zip`, εκτύπωση του `docx/` | Διαβάζει όλα τα docs | Δοκιμή από καθαρή βάση | **Πρόβα demo 30'**: ο καθένας δείχνει την περιοχή του, και ρωτάμε ο ένας τον άλλον |
| **Παρ 4/12** | Υποβολή **πριν τις 11:00** | — | — | Προθεσμία 12:00 |

### Σενάριο demo (30')

1. Login ως Καταναλωτής → υποστατικά → μετρήσεις τρέχοντος μήνα (εισαγωγή/εξαγωγή) → αίτημα βλάβης → τιμολόγια → αίτημα GDPR.
2. Login ως Operator → έγκριση τεχνικού → εργασία από το αίτημα → ανάθεση.
3. Login ως Τεχνικός → αποδοχή → εγκατάσταση μετρητή → ο Operator τον επιβεβαιώνει → γίνεται Active.
4. Login ως DSO → ingest ενός πακέτου JSON → VEE (φαίνεται το spike και η εκτίμηση του κενού) → validated → aggregates.
5. Login ως TSO → δέντρο με άθροισμα ανά επίπεδο → τρέχουσα κατάσταση → load shedding (και χάρτης, αν υπάρχει).
6. Login ως Supplier/Aggregator → Day-Ahead (ημερήσια) και Intraday (provisional).
7. Admin → τελική έγκριση GDPR → τι σβήστηκε και τι κρατήθηκε → log.

---

## 6. Τι χρειάζεται το Claude του καθενός

Ο καθένας δουλεύει **μέσα από το δικό του Claude**. Δεν χρειάζεται να διαβάσει κανείς αυτά τα έγγραφα: τα διαβάζει το Claude. Ο άνθρωπος χρειάζεται μόνο να ξέρει, σε γενικές γραμμές, ποια περιοχή είναι δική του (ενότητα 3) και να μπορεί να εξηγήσει στην εξέταση τι κάνει ο κώδικάς του. Αυτό του το εξηγεί το Claude του.

Τι κάνεις **μία φορά**:

1. Ανοίγεις το **Claude Code** (στο web, claude.ai/code, ή στον υπολογιστή), συνδέεις το GitHub σου και διαλέγεις το repo `soterisharal01/epl342project`. Ο Σωτήρης πρέπει πρώτα να σε έχει βάλει collaborator.
2. Του επικολλάς το μήνυμα πιο κάτω. Το Claude Code διαβάζει μόνο του το [`CLAUDE.md`](../../CLAUDE.md) στη ρίζα, που έχει όλους τους κανόνες, και από εκεί βρίσκει τα υπόλοιπα.
3. Αν σου ζητήσει την εκφώνηση, του ανεβάζεις το `project.pdf` από το Moodle (δεν είναι στο repo, γιατί είναι public).

Τι **δεν** μπορεί να κάνει το Claude, και το κάνεις εσύ:

- Να μπει στο VPN ή στον server του Τμήματος. Τα scripts τα τρέχεις εσύ στο SSMS, ή του επιτρέπεις να χειρίζεται το SSMS στην οθόνη σου.
- Να γράψει κωδικούς. Τον κωδικό σου τον γράφεις **μόνο εσύ**, στο παράθυρο που τον ζητά, ποτέ στο chat.
- Να κάνει merge στο `main`. Το merge το κάνει ο Σωτήρης.

Το Claude Code στο web έχει δικό του SQL Server 2025 (Docker): με `bash sql/tools/test_local.sh` στήνει όλη τη βάση από την αρχή και τρέχει τα tests. Το κάνει πριν από κάθε PR.

### Έτοιμο μήνυμα για να ξεκινήσεις το Claude σου (αντιγραφή-επικόλληση)

Δανάη:

> Είμαι η Δανάη (GitHub drobbi01), Ομάδα 12, ΕΠΛ342, MDMS-Cy Φάση Β. Ακολούθησε το `CLAUDE.md` του repo. Οι εργασίες μου είναι οι γραμμές D… στο `docs/phase-b/TASKS.md`. Πάρε την πρώτη ελεύθερη (○) με τη σειρά, κάνε την όπως λέει το `CLAUDE.md` (branch, Draft PR, tests, ενημέρωση TASKS.md) και στο τέλος εξήγησέ μου απλά τι έφτιαξες, ώστε να μπορώ να το παρουσιάσω.

Αντρέας:

> Είμαι ο Αντρέας (GitHub andreas1612), Ομάδα 12, ΕΠΛ342, MDMS-Cy Φάση Β. Ακολούθησε το `CLAUDE.md` του repo. Οι εργασίες μου είναι οι γραμμές A… στο `docs/phase-b/TASKS.md`. Πάρε την πρώτη ελεύθερη (○) με τη σειρά, κάνε την όπως λέει το `CLAUDE.md` (branch, Draft PR, tests, ενημέρωση TASKS.md) και στο τέλος εξήγησέ μου απλά τι έφτιαξες, ώστε να μπορώ να το παρουσιάσω.

Για review:

> Κάνε review στο PR #<αριθμός> όπως λέει το `CLAUDE.md` (λίστα ελέγχου στον Οδηγό, ενότητα 3Β). Γράψε τα σχόλια στο PR και πες μου με δύο προτάσεις αν είναι εντάξει.

---

## 7. Ανοιχτά θέματα / ερωτήσεις προς τον καθηγητή (ένα email, μαζεμένα)

1. Μπορούμε να κάνουμε `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON` στη βάση μας στον server του Τμήματος, ή να χρησιμοποιήσουμε `SNAPSHOT` isolation; Αυτό επηρεάζει την ταυτοχρονία.
2. Αρκεί για τα «δεδομένα .dat που γίνονται import» ένα script `import.sql` με INSERT; Το `BULK INSERT` στον server του Τμήματος δεν βλέπει αρχεία από τον δικό μας υπολογιστή.
3. Τα Intraday provisional aggregates: αρκεί να υπολογίζονται on-demand από τα raw, ή πρέπει να αποθηκεύονται;
4. Η επιβεβαίωση ότι η ημέρα αρκεί ως η μικρότερη αποθηκευμένη περίοδος για τα aggregates των μετασχηματιστών. Από αυτήν βγαίνουν μήνας και τρίμηνο.

---

## 8. Λίστα ελέγχου πριν την υποβολή (3/12)

- [ ] Σε **καθαρή** βάση τρέχουν χωρίς λάθος, με αυτή τη σειρά: `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → `data/import.sql`.
- [ ] Κάθε ρόλος έχει χρήστη demo και όλες τις ★ λειτουργίες του δουλεύουν από το UI.
- [ ] Raw → VEE → validated → aggregates φαίνεται στο UI του DSO, με spike και εκτίμηση κενού.
- [ ] Δέντρο μετασχηματιστών με άθροισμα ανά επίπεδο και load shedding φαίνονται στο UI του TSO.
- [ ] Η GDPR ροή πάει από άκρη σε άκρη και τα τιμολόγια κρατιούνται.
- [ ] Χιλιάδες γραμμές στο `data/`, 3 indexes στο `indexes.sql`, μία περίπτωση «πριν/μετά» με screenshot.
- [ ] Αποτελέσματα του τεστ 10.000 αιτήσεων (95% < 2 s) στο doc ταυτοχρονίας/απόδοσης.
- [ ] `docx/`: εγχειρίδιο (με τελικό ER, λεξικό δεδομένων, υποθέσεις) και χωριστό doc για contention, ασφάλεια και επέκταση.
- [ ] Κανένας κωδικός μέσα στο zip ή στο repo (`config.php` εκτός).
- [ ] `12.zip` με `sources/ sql/ data/ docx/` στο Moodle, και τυπωμένο το `docx/`.
- [ ] Ο καθένας έχει διαβάσει όλες τις περιοχές και μπορεί να εξηγήσει π.χ. το `create.sql` ενός πίνακα, το VEE και τη GDPR ροή.
