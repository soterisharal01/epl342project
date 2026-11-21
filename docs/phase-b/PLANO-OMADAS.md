# Πλάνο Φάσης Β – Ομάδα 12 (MDMS-Cy)

> Ενημέρωση: 21/11/26 (έλεγχος γραμμή προς γραμμή με την εκφώνηση και τη συνάντηση της 20/11). Παράδοση: **Παρασκευή 4/12/26, 12:00**, στο Moodle. Εμείς στοχεύουμε να υποβάλουμε **πριν τις 11:00**.
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
| **Κανόνας εκφώνησης (V)** | Η εκφώνηση **δεν δέχεται** χωρισμό της δουλειάς σε «σχεδίαση» και «υλοποίηση» ή σε «SQL» και «PHP»: όλα τα μέλη ασχολούνται με **όλα τα στάδια** και συμβάλλουν **ισομερώς**. Γι' αυτό ο καθένας παίρνει ολόκληρη περιοχή, δηλαδή procedures, PHP, δεδομένα, ένα index και ένα κείμενο τεκμηρίωσης, κάνει review σε ξένη περιοχή και στην πρόβα εξηγεί μία ξένη περιοχή. Στην εξέταση παρουσιάζουν **όλοι**, και όποιος λείπει παίρνει μηδέν. Ο καθένας πρέπει να μπορεί να εξηγήσει **όλο** το σύστημα. |
| **Η εκφώνηση δεν είναι στο repo** | Το `project.pdf` δεν ανεβαίνει (το repo είναι public). Γι' αυτό η **ενότητα 3** αυτού του πλάνου μεταφέρει **κάθε** απαίτηση της εκφώνησης, πρόταση προς πρόταση, στη γραμμή της «Απαιτήσεις εκφώνησης». Μια εργασία τελειώνει μόνο όταν καλύπτει **όλες** τις απαιτήσεις της. |

---

## 1. Τι λέει η εκφώνηση ότι παραδίδουμε (ενότητα V.Α)

| Φάκελος στο zip | Τι μπαίνει | Από ποια αρχεία του repo |
|---|---|---|
| `sources/` | Όλος ο κώδικας PHP/HTML/CSS/JS της εφαρμογής **και οι βιβλιοθήκες που χρειάζεται** (π.χ. το Leaflet αντιγραμμένο στο `sources/js/`, όχι μόνο από CDN), ώστε το zip να δουλεύει μόνο του | `sources/` |
| `sql/` | Όλα τα .sql (DDL, DML, procedures). Η εκφώνηση ζητά **αναγνωριστικά ονόματα** και δίνει ως παράδειγμα `create.sql`, `drop.sql`, **`import.sql`**, **`select.sql`**, `indexes.sql`. Τα έχουμε όλα: `import.sql` = φόρτωση του μεγάλου συνόλου (E7), `select.sql` = τα βασικά ερωτήματα κάθε ρόλου και τα analytics (E7), και επιπλέον `procs_*.sql` και `tests/` | `sql/` |
| `data/` | Τα αρχεία δεδομένων **.dat** (αρχεία κειμένου), που πρέπει να μπορούν να γίνουν import στη βάση. Ένα μικρό σύνολο για έλεγχο κι ένα μεγάλο, με χιλιάδες γραμμές. Πώς γίνεται το import: απόφαση Α8 | `data/` |
| `docx/` | (1) **Εγχειρίδιο χρήστη** (.docx ή .pdf): οδηγίες χρήσης, βασικές επιλογές σχεδίασης της βάσης, επιπλέον λειτουργίες, δυσκολίες, **τελικό ER**, **λεξικό δεδομένων**, περιορισμοί και δυνατότητες βελτίωσης. (2) **Ένα χωριστό έγγραφο** με τρία κεφάλαια: (a) σημεία συνωστισμού (contention) και πώς τα αντιμετωπίσαμε, (b) ασφάλεια, (c) μελλοντική επέκταση. Εκεί μπαίνουν και τα 3 indexes, η περίπτωση «πριν/μετά» και το τεστ απόδοσης (E8). Στο εργαστήριο παραδίδεται **τυπωμένο μόνο** το `docx/` | `docs/phase-b/` (τα γράφουμε σε .md και στο τέλος γίνονται .docx/.pdf) |

Απαιτήσεις από την ενότητα IV που βαθμολογούνται:

- **Login**: κάθε χρήστης μπαίνει με username και κωδικό. Οι κωδικοί αποθηκεύονται μόνο ως hash.
- **Η λογική βρίσκεται στη βάση**: ερωτήματα, έλεγχοι και λειτουργίες γίνονται σε stored procedures. Το PHP μόνο τα καλεί.
- **Κάθε λειτουργία είναι μία ατομική ενέργεια**: ή γίνονται όλες οι αλλαγές ή καμία. Αυτό σημαίνει transaction με TRY/CATCH.
- **Ιχνηλασιμότητα**: κάθε κρίσιμη αλλαγή γράφεται στο `AUDIT_LOG` με αντικείμενο, χρήστη ή μηχανισμό, χρόνο, παλιά και νέα κατάσταση, και σχόλιο.
- **Συνθετικά δεδομένα**: ένα μικρό σύνολο κι ένα μεγάλο, με χιλιάδες γραμμές. Το μέγεθος βαθμολογείται.
- **3 indexes**: εξηγούμε ποια επιλέξαμε, γιατί και πώς. Δείχνουμε και **μία περίπτωση «πριν/μετά»** όπου ένα index ή ένα καλύτερο query μειώνει το κόστος.
- **Απόδοση**: κάτω από 2 δευτερόλεπτα για το 95% των συνηθισμένων OLTP ερωτημάτων, σε 10.000 αιτήσεις.
- **Ασφάλεια**: μη εξουσιοδοτημένη πρόσβαση και SQL injection, και **τεκμηρίωση** του πώς τα εφαρμόσαμε.
- **Συνωστισμός (contention)**: εντοπίζουμε τα σημεία που μπορεί να γίνουν bottleneck σε συνεχή και έντονη χρήση και γράφουμε πώς τα αντιμετωπίζει η υλοποίηση.
- **Ταυτοχρονία**: transactions, isolation levels και ενδιάμεσοι πίνακες. Δύο περιπτώσεις που λέει η εκφώνηση: (1) νέες μετρήσεις φτάνουν ενώ τρέχει το VEE ή ο υπολογισμός aggregates, (2) δύο χρήστες ενημερώνουν την ίδια εγγραφή.
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
  `sql/procs_common.sql` (Σωτήρης), `sql/procs_consumer.sql` (Σωτήρης), `sql/procs_admin.sql` (Σωτήρης: Admin, Operator κατάλογοι, GDPR, retention), `sql/procs_technician.sql` (Δανάη), `sql/procs_market.sql` (Δανάη), `sql/procs_dso.sql` (Αντρέας), `sql/procs_tso.sql` (Αντρέας).
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

- Ο σκελετός (`sources/`) βασίστηκε στο Lab 7 (`index.php` → `connect.php` → `q1–q3.php`), με μία μεγάλη αλλαγή: ο χρήστης γράφει το **username του MDMS-Cy**, όχι το SQL login. Τα στοιχεία σύνδεσης στη βάση μένουν στο `sources/config.php`, που **δεν μπαίνει ποτέ στο git**. Στο git μπαίνει μόνο το `config.example.php`.
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

Κλήση ενός procedure: **πάντα** μέσω `call_proc` του `db.php` (μέσα του κάνει `{CALL sp_x(?, ?)}` όπως το q3.php του lab). Ποτέ `sqlsrv_query` απευθείας σε σελίδα:

```php
$rows = call_proc('sp_consumer_list_invoices', [uid(), $year]);   // false = λάθος, δες last_error()
print_table($rows, ['InvoiceID' => '#', 'Amount' => 'Ποσό €']);
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
| Σ3 | Αντρέας (A9) | Το load shedding φτιάχνει εντολές | `INSERT REMOTE_COMMAND (CommandType = 'Load shed', Status = 'Sent', ShedOrderID = …, RequestedBy = <TSO>)`. **Προσοχή**: το CHECK `CK_REMOTE_COMMAND_ShedOrder` δέχεται `ShedOrderID` **μόνο** με `CommandType = 'Load shed'`, οπότε το `'Disconnect'` εδώ αποτυγχάνει. Οι σελίδες της Δανάης τις δείχνουν όπως όλες τις εντολές, και οι προσπάθειες/ACK γράφονται με το procedure της D8. Το `LOAD_SHED_ORDER.Status` το ενημερώνει ο Αντρέας (A9) διαβάζοντας τις καταστάσεις των εντολών. |
| Σ4 | Αντρέας (A1, A5) → Δανάη (D9) | Συμβάν που οδηγεί σε εργασία | Ο Αντρέας γράφει `EVENT`. Η Δανάη διαβάζει `EVENT` με `Status = 'Open'` και γράφει `FIELD_TASK` + `LEADS_TO`. Μετά κάνει `UPDATE EVENT SET Status = 'In progress'`, και αυτή είναι η μόνη αλλαγή της στο `EVENT`. |
| Σ5 | Σωτήρης (S10) | Διαγραφή παλιών μετρήσεων (retention/GDPR) | `EXEC sp_set_session_context N'mdms_purge', 1;` και μετά `DELETE` στα `RAW_READING` και `VALIDATED_READING`. Ποτέ UPDATE. |
| Σ6 | Σωτήρης (S5, S6) / Δανάη (D10–D12) | Διαβάζουν μετρήσεις, aggregates και συμβάντα του Αντρέα | Μόνο SELECT στα `VALIDATED_READING`, `METER_AGGREGATE`, `EVENT`, `RAW_READING` (μόνο για Intraday). Η σημασία κάθε στήλης ορίζεται στην ενότητα 2Β, αποφάσεις Α2 και Α14. |
| Σ7 | Δανάη (D6) | Στην εγκατάσταση μετρητή χρειάζεται `METER.TransformerID` | Βρίσκει το geofence-**φύλλο** που περιέχει τις συντεταγμένες (`MinLat ≤ Lat ≤ MaxLat` και `MinLon ≤ Lon ≤ MaxLon`, μετασχηματιστής χωρίς παιδιά) με **δικό της** SELECT στα `GEOFENCE`/`TRANSFORMER`, με τον ίδιο κανόνα που θα έχει το `sp_tso_locate` του Αντρέα (A6). Αν δεν βρεθεί κανένα: THROW. Δεν περιμένει τον κώδικα του Αντρέα. |
| Σ8 | Δανάη (D9) | Ένας έλεγχος anti-tamper βρίσκει πρόβλημα | `INSERT EVENT (EventType = 'Tamper finding', TaskID = <ο έλεγχος>, MeterID = …, Status = 'Open')`. Είναι η μόνη εγγραφή της στο `EVENT` εκτός από το Σ4. |

**Κανόνας 3: δικά σου αρχεία, δικά σου IDs.** Ο καθένας έχει δικό του αρχείο procedures, δοκιμών και μικρών δεδομένων (`data/small/10_soteris.sql`, `20_danai.sql`, `30_andreas.sql`). Αυτά βασίζονται **μόνο** στο `00_base.sql`, ποτέ στο αρχείο άλλου. Για τις γραμμές που προσθέτει ο καθένας στα δεδομένα του, χρησιμοποιεί IDs στο δικό του εύρος: **Σωτήρης 1000–1999, Δανάη 2000–2999, Αντρέας 3000–3999**, με `SET IDENTITY_INSERT`. Έτσι δεν συγκρούονται ποτέ.

**Κανόνας 4: ο χωρισμός είναι προεπιλογή, όχι δέσμευση.** Οι περιοχές S/D/A είναι ένας δίκαιος, υποθετικός χωρισμός της δουλειάς. Όποιος τελειώσει ή θέλει να συνεχίσει, παίρνει οποιαδήποτε **ελεύθερη (○)** εργασία άλλης περιοχής, αφού πρώτα τη δηλώσει στο `TASKS.md` (βήμα 7 εκεί). Ο κώδικάς της πάει σε **νέο** αρχείο με το ID της (π.χ. `sql/procs_tso_A6.sql`), οπότε οι περιοχές μένουν χωρισμένες στον κώδικα, και τα δικαιώματα εγγραφής του Κανόνα 1 ακολουθούν την εργασία.

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
| Α8 | Δεδομένα (.dat) | Τα scripts του `data/gen/` γράφουν το **μεγάλο** σύνολο ως ένα `data/large/<ΠΙΝΑΚΑΣ>.dat` ανά πίνακα (κείμενο, CSV, UTF-8, πρώτη γραμμή τα ονόματα στηλών). Από τα `.dat` ένα script φτιάχνει το **`sql/import.sql`** με INSERT σε ομάδες έως 1.000 γραμμών (όριο του `VALUES`). Import σημαίνει να τρέξεις το `sql/import.sql` στο SSMS, γιατί το `BULK INSERT` στον server του Τμήματος δεν βλέπει αρχεία του υπολογιστή μας. Το μεγάλο σύνολο φορτώνεται **πάνω** στο `00_base.sql`, με IDs: Σωτήρης 100000–199999, Δανάη 200000–299999, Αντρέας 300000–399999. Γράφεται έτσι και στο εγχειρίδιο. |
| Α9 | Σειρά εκτέλεσης | `drop.sql` → `create.sql` → `procs_common.sql` → τα υπόλοιπα `procs_*.sql` → `indexes.sql` → `data/small/00_base.sql` → `data/small/10–30_*.sql` και, για το μεγάλο σύνολο, `sql/import.sql`. |
| Α10 | Αλλαγή σχήματος | Μόνο όπως περιγράφει ο Οδηγός, ενότητα 5. Μετά τις 27/11 γίνεται μόνο αν δεν βγαίνει κάτι ★. |
| Α11 | Merge | Ο Σωτήρης, μετά από ✓ του reviewer. Αν περάσουν 24 ώρες χωρίς review, ο Σωτήρης ελέγχει μόνος του. Το Claude του Σωτήρη κάνει merge μόνο όταν ο Σωτήρης του το ζητήσει ρητά. |
| Α12 | Code freeze | Τετάρτη 2/12 το βράδυ. Μετά γίνονται μόνο διορθώσεις λαθών. |
| Α13 | Τελικό ER | Το ER **ξαναγίνεται στο τέλος** (εργασία E2, 2/12), από το τελικό `create.sql`. Μέχρι τότε η αλήθεια βρίσκεται στο `create.sql` και στο `sql/ALLAGES.md`. |
| Α14 | Τύποι συμβάντων (`EVENT.EventType`) | Η στήλη δεν έχει CHECK, οπότε όλοι γράφουμε **ακριβώς** αυτές τις τιμές: `'Unmatched packet'` (άγνωστο NetworkID), `'Meter not active'`, `'Malformed packet'`, `'Communication problem'` (π.χ. σήμα κάτω από −110 dBm ή άλλος τύπος δικτύου από το `COMM_TYPE` του μετρητή), `'Undervoltage'`, `'Overvoltage'`, `'Phase unbalance'`, `'Suspected theft'`, `'Suspect reading'` (spike από το VEE), `'Tamper finding'` (από έλεγχο πεδίου, Σ8). `Severity`: `'Info'`, `'Warning'`, `'Critical'`. Νέος τύπος = νέα τιμή εδώ, χωρίς αλλαγή σχήματος. |
| Α15 | Απομακρυσμένες εντολές | `REMOTE_COMMAND.CommandType`: `'Disconnect'`, `'Reconnect'`, `'Firmware upgrade'`, `'Load shed'` (μόνο από TSO, Σ3). Ροή: ο Τεχνικός ζητά εντολή **μόνο** για μετρητή όπου έχει εργασία `Accepted` → `'Awaiting approval'` → ο Operator εγκρίνει (`ApprovedBy`) → `'Sent'` → μία ή περισσότερες γραμμές `COMMAND_ATTEMPT` (`'Timeout'`, `'NAK'`, `'ACK'`) → `'Acknowledged'` με το πρώτο ACK, ή `'Failed'` μετά από 3 αποτυχίες. Κάθε αλλαγή κατάστασης γράφει `AUDIT_LOG`. |
| Α16 | Τρέχουσα κατάσταση δικτύου | Το `TRANSFORMER_CURRENT_STATE` κρατά γραμμή για **κάθε** μετασχηματιστή του δέντρου (φύλλα **και** όλους τους προγόνους), γιατί η εκφώνηση (ΙΙΙ.4.2) θέλει την εικόνα για όλη την ιεραρχία και ενημέρωση των ancestors. Κάθε μετασχηματιστής έχει ακριβώς ένα geofence (`UQ_TRANSFORMER_GeofenceID`), άρα «ανά Geofence» = «ανά μετασχηματιστή». Όλες οι γραμμές ενός refresh έχουν το **ίδιο** `RefInterval` (κοινός χρονισμός): το πιο πρόσφατο 15λεπτο που έχει validated 1.8.0. Μόνο 1.8.0 και 2.8.0 (το CHECK το επιβάλλει). Μετρητές χωρίς τιμή σε αυτό το 15λεπτο απλώς δεν μετρούν (`MeterCount`). Τα **ιστορικά** aggregates των μετασχηματιστών αποθηκεύονται **μόνο για τα φύλλα** (καθηγητής, trigger `TR_TRANSFORMER_AGGREGATE_Leaf`). |
| Α17 | Τι σβήνει η διατήρηση και το GDPR | Για μετρητές **καταναλωτών**: `RAW_READING`, `VALIDATED_READING` (με το Σ5) και τα `TELEMETRY_PACKET` τους που δεν έχουν πια raw και δεν τα δείχνει κάποιο `EVENT` (λόγω FK), όταν είναι παλαιότερα από `RawRetentionMonths` (36, ή 1 μετά από εγκεκριμένο GDPR). **Μένουν πάντα**: `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE`, `TRANSFORMER_CURRENT_STATE`, τιμολόγια, πληρωμές, `AUDIT_LOG`. Στο GDPR σβήνονται ή ανωνυμοποιούνται τα προσωπικά στοιχεία (όνομα, email, τηλέφωνο, IBAN), αλλά όχι η λογιστική πληροφορία των πληρωμών. |
| Α18 | Ποιες μετρήσεις βλέπει ένας καταναλωτής | Μόνο μετρητών εγκατεστημένων σε **δικό του** υποστατικό και **μόνο για το διάστημα που το κατείχε** (τομή `HOLDING.StartDate–EndDate` με `METER_INSTALLATION.InstalledAt–RemovedAt`). Έτσι ο νέος ένοικος δεν βλέπει τις μετρήσεις του παλιού, και μετά από αντικατάσταση μετρητή η παλιά χρονοσειρά του υποστατικού φαίνεται ακόμη. |
| Α19 | Αποστολή email/SMS | Η αποστολή είναι εκτός βάσης (υπόθεση Φάσης Α). Η βάση κρατά τα κανάλια (`CONSUMER_NOTIFICATION_CHANNEL`) και ένα procedure βρίσκει τι πρέπει να σταλεί (όρια που ξεπεράστηκαν, συμβάντα ποιότητας), και η σελίδα το δείχνει ως ειδοποίηση. Γράφεται στους περιορισμούς του εγχειριδίου. |

---

## 3. Η δουλειά ανά περιοχή: τι ακριβώς φτιάχνουμε

Για κάθε λειτουργία της εκφώνησης δίνονται τα procedures που χρειάζονται, οι πίνακες και η σελίδα PHP. Ο κωδικός της εργασίας (S…, D…, A…) είναι ίδιος με τον κωδικό στο [TASKS.md](TASKS.md). Τα ονόματα των procedures είναι προτάσεις, και οι παράμετροι μπορούν να αλλάξουν. Τα ονόματα σελίδων είναι ενδεικτικά: στην πράξη έχουν αριθμό μπροστά για τη σειρά στο μενού (π.χ. `consumer/10_premises.php`). Με ★ σημειώνεται ό,τι **πρέπει** να φαίνεται στο demo.

Κάτω από κάθε πίνακα υπάρχει η λίστα **«Απαιτήσεις εκφώνησης»**: η εκφώνηση της περιοχής, πρόταση προς πρόταση, σε απλά λόγια. Το Claude που κάνει μια εργασία την ελέγχει **πριν** βάλει 👀, και ο reviewer την ξαναελέγχει.

### 3.0 Απαιτήσεις που ισχύουν σε **κάθε** εργασία (Κοινές αρχές ΙΙΙ και ενότητα IV)

- [ ] Κάθε προστατευμένη λειτουργία γίνεται μόνο μετά από login. Κάθε procedure ελέγχει ρόλο **και** `AccountStatus = 'Active'` (και ο Τεχνικός `ApprovalStatus = 'Approved'`).
- [ ] Κάθε λειτουργία με περισσότερες από μία μεταβολές είναι **μία ατομική ενέργεια**: όλα ή τίποτα (`XACT_ABORT` + `TRY/TRAN/CATCH ROLLBACK`).
- [ ] Κάθε **κρίσιμη αλλαγή κατάστασης** (έγκριση, απόρριψη, απομακρυσμένη εντολή, αλλαγή τεχνικών στοιχείων, αίτημα GDPR, αποτέλεσμα VEE, σημαντικό συμβάν τηλεμετρίας) γράφει `AUDIT_LOG` με: αντικείμενο (`ObjectType`, `ObjectID`), ποιος (`PerformedBy`) **ή** ποιος μηχανισμός (`ActorMechanism`, π.χ. `'VEE'`), χρόνο, παλιά και νέα κατάσταση, αποτέλεσμα/σχόλιο (`ResultComment`).
- [ ] Η λογική είναι στη βάση. Η PHP μόνο καλεί procedures με `call_proc`, και η σελίδα δείχνει **μόνο** τη δική μας βάση.
- [ ] Ελέγχεις τις τιμές των CHECK του `create.sql` (π.χ. `INVOICE.Status`) και τις αποφάσεις Α1–Α19. Δεν επινοείς στήλες ή τιμές.
- [ ] Κάθε procedure έχει δοκιμή `OK/FAIL` (μία επιτυχία, μία αποτυχία) και τα δεδομένα δοκιμής βασίζονται μόνο στο `00_base.sql`.

### 3.Α Κοινά: login, Admin, Operator (Σωτήρης)

| Λειτουργία | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| ★ Login | `sp_auth_get_login(@Username)`: επιστρέφει UserID, PasswordHash, Role, AccountStatus, ApprovalStatus. Το PHP κάνει `password_verify` και στέλνει τον χρήστη στο μενού του ρόλου του. Ένας τεχνικός που είναι ακόμη Pending βλέπει μόνο το μήνυμα «περιμένει έγκριση». | `USER_ACCOUNT` | `index.php`, `login.php` |
| ★ Εγγραφή καταναλωτή | `sp_auth_register_consumer(@Username, @PasswordHash, @Email, @Phone, @FirstName, @LastName)`, με `RawRetentionMonths = 36` | `USER_ACCOUNT`, `CONSUMER_NOTIFICATION_CHANNEL` | `register_consumer.php` |
| Δημιουργία χρηστών από Admin | `sp_admin_create_user(@UserID, @Role, …)` για Operator, DSO, TSO, Supplier και Aggregator (με `SupplierID`/`AggregatorID`). **Προσοχή**: το CHECK `CK_USER_ACCOUNT_Operator` δέχεται `CreatedBy` **μόνο** για Operator. Για τους άλλους ρόλους το «ποιος τον δημιούργησε» γράφεται στο `AUDIT_LOG`. | `USER_ACCOUNT`, `SUPPLIER`, `AGGREGATOR` | `admin/users.php` |
| Αναστολή / ενεργοποίηση χρήστη | `sp_admin_set_account_status` | `USER_ACCOUNT`, `AUDIT_LOG` | `admin/users.php` |
| Κατάλογοι του Operator | `sp_operator_save_meter_model`, `sp_operator_save_service_type`, `sp_operator_save_tariff_type` | `METER_MODEL`, `SERVICE_TYPE`, `TARIFF_TYPE` | `operator/catalogs.php` |
| Προβολή log | `sp_admin_audit_log(@UserID, @ObjectType, @From, @To)` | `AUDIT_LOG` | `admin/log.php` |

**Απαιτήσεις εκφώνησης (Κοινές αρχές):**
- [ ] Κάθε φυσικό πρόσωπο έχει **μοναδικό** λογαριασμό. Ένα username = ένας ρόλος (καθηγητής).
- [ ] Οι κωδικοί αποθηκεύονται **μόνο** σε μη αναστρέψιμη μορφή (hash), ώστε να μη φαίνονται ούτε σε όποιον βλέπει απευθείας τους πίνακες.
- [ ] Ο Admin (ΔΣ) είναι ο root ρόλος και μπαίνει με το χέρι στη βάση (στο `00_base.sql`).
- [ ] Τους Operators (ΛΣ) τους δημιουργεί **Admin**.
- [ ] Ο Operator: ελέγχει εγγραφές Τεχνικών, τεχνικά έγγραφα και μετρητές (D4, D7), ορίζει **μοντέλα μετρητών**, **τύπους υπηρεσιών** και **τύπους τιμολογίων** (S3), και **καταγράφει το αποτέλεσμα** κάθε ελέγχου του (σχόλιο + `AUDIT_LOG`).
- [ ] Ο Admin βλέπει το log με φίλτρα (αντικείμενο, χρήστης, διάστημα).

### 3.Β ΙΙΙ.1 Καταναλωτές και υποστατικά (Σωτήρης)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 1.1 ★ Ο καταναλωτής συνδέεται με 1 ή περισσότερα υποστατικά. Κάθε υποστατικό έχει Premise ID, διεύθυνση, WGS84, χρήση (Οικιακό, Εμπορικό, Βιομηχανικό, Γεωργικό), Επαρχία, Δήμο, Ενορία και ΤΚ | `sp_consumer_add_premise` (PREMISE + HOLDING σε ένα transaction), `sp_consumer_list_premises`, `sp_consumer_end_holding` | `PREMISE`, `HOLDING`, `PARISH`, `MUNICIPALITY`, `DISTRICT` | `consumer/premises.php` |
| 1.1 Τραπεζικοί λογαριασμοί | `sp_consumer_add_bank_account` (και `ACCOUNT_FOR` όταν ο λογαριασμός αφορά υποστατικό) | `BANK_ACCOUNT`, `ACCOUNT_FOR` | `consumer/bank.php` |
| 1.2 ★ 15λεπτες χρονοσειρές των **ενεργών** μετρητών **μόνο των δικών του** υποστατικών (Α18). Απλή κατανάλωση: μόνο εισαγωγή (1.8.0). Prosumer (`SUPPLY_SCHEME` Net Metering ή Net Billing): εισαγωγή (1.8.0) **και** εξαγωγή (2.8.0) **χωριστά**, και το ισοζύγιο | `sp_consumer_readings(@UserID, @MeterID, @From, @To)`: ο **τρέχων μήνας είναι δωρεάν**. Για προηγούμενους μήνες χρειάζεται `SERVICE_PURCHASE` που να καλύπτει τον μήνα, και τα δεδομένα πρέπει να είναι ακόμη μέσα στο `RawRetentionMonths`. Για ιστορικό χρησιμοποιείται ο `METER_AGGREGATE` (Day, Month, Year). Η στήλη `Quality` δείχνει αν η τιμή είναι εκτιμημένη. | `VALIDATED_READING`, `METER_AGGREGATE`, `METER_INSTALLATION`, `HOLDING`, `SERVICE_PURCHASE` | `consumer/readings.php` (πίνακας, και γράφημα αν προλάβουμε) |
| 1.2 Αγορά πρόσβασης σε ιστορικό | `sp_consumer_buy_history(@UserID, @PremiseID, @MonthFrom, @MonthTo)`: σε **ένα** transaction `INVOICE` (τέλος υπηρεσίας MDMS-Cy, `ContractID = NULL`) + `SERVICE_PURCHASE` με τη χρέωση του `SERVICE_TYPE`. Δεν πουλά μήνες που έχουν ήδη σβηστεί λόγω retention | `SERVICE_PURCHASE`, `SERVICE_TYPE`, `INVOICE` | `consumer/history.php` |
| 1.2 Thresholds και ειδοποιήσεις (email/SMS), συμβάντα υπότασης/υπέρτασης | `sp_consumer_set_threshold`, `sp_consumer_set_channels`, `sp_consumer_alerts` (όρια που ξεπεράστηκαν, από τα aggregates, Α19), `sp_consumer_quality_events` (`EVENT` με `'Undervoltage'`/`'Overvoltage'` των μετρητών του, Α14, Α18) | `CONSUMPTION_THRESHOLD`, `CONSUMER_NOTIFICATION_CHANNEL`, `EVENT` | `consumer/settings.php` |
| 1.3 ★ Αίτημα ελέγχου ή βλάβης, με κατάσταση και ιστορικό | `sp_consumer_submit_request`, `sp_consumer_list_requests` (μαζί με το `FIELD_TASK` που προέκυψε) | `SERVICE_REQUEST`, `FIELD_TASK`, `AUDIT_LOG` | `consumer/requests.php` |
| 1.3 ★ Ιστορικό χρεώσεων και πληρωμών | `sp_consumer_list_invoices`, `sp_consumer_list_payments`, `sp_consumer_pay_invoice`. Κάθε τιμολόγιο δείχνει αν είναι **προμήθειας** (προμηθευτής, μέσω `SUPPLY_CONTRACT`) ή **τέλος υπηρεσίας MDMS-Cy** (μέσω `SERVICE_PURCHASE`) | `INVOICE`, `PAYMENT`, `SUPPLY_CONTRACT`, `SUPPLIER`, `SERVICE_PURCHASE` | `consumer/billing.php` |
| 1.4 ★ GDPR, δικαίωμα στη λήθη. Η ροή έχει **5 στάδια**, με τις τιμές του `GDPR_REQUEST.Status`: υποβολή (`'Submitted'`) → εξέταση από Operator (`'Under review'`) → προέγκριση (`'Pre-approved'`) → τελική απόφαση από Admin (`'Approved'` ή `'Rejected'`) → εφαρμογή (`'Applied'`). Κάθε στάδιο γράφει στο log ημερομηνία, ενέργεια και χρήστη | `sp_gdpr_submit`, `sp_gdpr_start_review` (Operator), `sp_gdpr_preapprove` (Operator), `sp_gdpr_decide` (Admin, `DecidedByAdmin`), `sp_gdpr_apply`. Η εφαρμογή, σε ένα transaction: σβήνει ή ανωνυμοποιεί τα προσωπικά στοιχεία που επιτρέπεται (Α17), **κρατά** τιμολόγια, πληρωμές και aggregates, βάζει `RawRetentionMonths = 1` και **σβήνει αμέσως** τις μετρήσεις που είναι παλαιότερες από 1 μήνα. Απόρριψη (`'Rejected'`) γίνεται μόνο **μετά** την προέγκριση, γιατί έτσι το θέλει το `CK_GDPR_REQUEST_Stage`. | `GDPR_REQUEST`, `USER_ACCOUNT`, `BANK_ACCOUNT`, `RAW_READING`, `VALIDATED_READING`, `AUDIT_LOG` | `consumer/gdpr.php`, `operator/gdpr.php`, `admin/gdpr.php` |
| 1.4 Διατήρηση δεδομένων: raw για 3 χρόνια ή 1 μήνα μετά από GDPR. Τα aggregates μένουν. Οι μετρήσεις μετασχηματιστών μένουν για πάντα | `sp_retention_purge(@UserID, @AsOf)`. Κάνει `sp_set_session_context N'mdms_purge', 1` και σβήνει παλιές γραμμές από `RAW_READING` και `VALIDATED_READING` (και πακέτα, Α17) **μόνο** για μετρητές καταναλωτών, ανάλογα με το `RawRetentionMonths` του καθενός | `RAW_READING`, `VALIDATED_READING`, `TELEMETRY_PACKET` | κουμπί στο `admin/` |

**Απαιτήσεις εκφώνησης (ΙΙΙ.1):**
- [ ] 1.1 Self-registration **χωρίς** προέγκριση. Καταχωρούνται προσωπικά στοιχεία, στοιχεία επικοινωνίας και στοιχεία σύνδεσης.
- [ ] 1.1 Ένας καταναλωτής έχει **πολλά** υποστατικά (όχι 1:1). Κάθε υποστατικό: μοναδικό Premise ID, διεύθυνση, WGS84, χρήση (4 τιμές), Επαρχία, Δήμος, Ενορία, ΤΚ.
- [ ] 1.1 Οι τραπεζικοί λογαριασμοί συνδέονται με τον καταναλωτή ή/και με συγκεκριμένο υποστατικό.
- [ ] 1.2 Βλέπει μόνο **ενεργούς** μετρητές των **δικών του** υποστατικών (Α18).
- [ ] 1.2 Απλή κατανάλωση: εισαγωγή. Prosumer (Net Billing/Net Metering): εισαγωγή **και** εξαγωγή **διακριτά**, για να φαίνεται το ισοζύγιο.
- [ ] 1.2 Ενημέρωση για συμβάντα ποιότητας (υπόταση, υπέρταση) όπου υπάρχουν μετρήσεις τάσης.
- [ ] 1.2 Ορίζει όρια (thresholds) κατανάλωσης και κανάλια ειδοποίησης (email, SMS).
- [ ] 1.2 Τρέχων μήνας **δωρεάν**. Προηγούμενοι μήνες μόνο με **πληρωμένη** υπηρεσία, και **μόνο** όσο τα δεδομένα υπάρχουν ακόμη λόγω retention.
- [ ] 1.2 Οι οθόνες παρακολούθησης δείχνουν τα 15λεπτα που πέρασαν από VEE. Οι ιστορικές/συγκεντρωτικές χρησιμοποιούν τα ημερήσια, μηνιαία, ετήσια aggregates, με τους **ίδιους** κανόνες πρόσβασης.
- [ ] 1.3 Αίτημα ελέγχου μετρητή ή αναφορά βλάβης για υποστατικό/μετρητή, με **κατάσταση και ιστορικό**, ώστε να ανατεθεί σε Τεχνικό (D5) και να παρακολουθείται ως το τέλος.
- [ ] 1.3 Ιστορικό χρεώσεων και πληρωμών. Η πληρωμή κρατά τη σύνδεση καταναλωτή, προμηθευτή, τιμολογίου και τέλους υπηρεσίας MDMS-Cy. Αλγόριθμος δυναμικής τιμολόγησης **δεν** χρειάζεται.
- [ ] 1.4 Το GDPR **δεν** είναι άμεση διαγραφή: υποβολή → εξέταση → προέγκριση → τελική έγκριση, με log σε κάθε στάδιο. Μετά την έγκριση σβήνονται **μόνιμα** μόνο τα προσωπικά δεδομένα που επιτρέπεται. Η λογιστική πληροφορία των πληρωμών μένει.
- [ ] 1.4 Raw 15λεπτα: 3 χρόνια. Μετά σβήνονται, τα aggregates μένουν. Με εγκεκριμένο GDPR: 1 μήνας, και τα παλαιότερα σβήνονται **αυτόματα**. Δεν αφορά μετρήσεις/aggregates μετασχηματιστών, που μένουν για πάντα.
- [ ] 1.4 Για στατιστικά προτιμώνται τα aggregates, και τα λεπτομερή δεδομένα τα βλέπουν μόνο όσοι δικαιούνται.

### 3.Γ ΙΙΙ.2 Τεχνικοί πεδίου και μετρητές (Δανάη)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 2.1 ★ Self-registration τεχνικού: δεν κάνει τίποτα πριν εγκριθεί από Operator. Γράφεται σε τουλάχιστον 1 κατηγορία και δίνει **ενεργό** email, ημερομηνία γέννησης και φωτογραφία | `sp_auth_register_technician` (`ApprovalStatus = 'Pending'`, `BirthDate`, `Photo` υποχρεωτικά από το CHECK), `sp_tech_set_categories` (τουλάχιστον 1) | `USER_ACCOUNT`, `IN_CATEGORY`, `TECHNICIAN_CATEGORY` | `register_technician.php` |
| 2.1 Έγγραφα: Ταυτότητα, Άδεια Εγκαταστάτη, Πιστοποιητικό Τεχνικής Κατάρτισης (`DocType`: `'ID card'`, `'Installer licence'`, `'Training certificate'`), το καθένα με αριθμό, έκδοση, λήξη όπου υπάρχει και αρχείο/φωτογραφία | `sp_tech_add_document`, `sp_tech_list_documents` | `DOCUMENT` | `technician/documents.php` |
| 2.1 Ημερήσια διαθεσιμότητα, χρονική (ώρες) και γεωγραφική (δήμοι) | `sp_tech_declare_availability` (AVAILABILITY + AVAILABLE_IN σε ένα transaction) | `AVAILABILITY`, `AVAILABLE_IN`, `MUNICIPALITY` | `technician/availability.php` |
| 2.1 ★ Έγκριση ή απόρριψη τεχνικού από Operator, με καταγραφή | `sp_operator_list_pending_technicians`, `sp_operator_review_document` (`ReviewStatus` + `ReviewComment`), `sp_operator_decide_technician`: εγκρίνει **μόνο** αν και τα 3 έγγραφα είναι `'Accepted'` και δεν έχουν λήξει. Κάθε αλλαγή του `ApprovalStatus` (και `'Suspended'`) γράφει `AUDIT_LOG` | `USER_ACCOUNT`, `DOCUMENT`, `AUDIT_LOG` | `operator/technicians.php` |
| 2.2 ★ Εργασίες πεδίου (εγκατάσταση, αντικατάσταση, τεχνικός έλεγχος, anti-tamper): ανάθεση, αποδοχή, θέση μετρητή, σημειώσεις, ευρήματα, τεκμήρια | `sp_task_create` (και από `SERVICE_REQUEST`, Σ1), `sp_task_assign` (ελέγχει Approved, κατηγορία που ταιριάζει στον τύπο εργασίας, διαθεσιμότητα την ημέρα και στον δήμο του υποστατικού), `sp_tech_list_tasks` (με lat/lon του μετρητή ή, πριν την εγκατάσταση, του υποστατικού), `sp_tech_accept_task`, `sp_tech_add_note` (`NoteKind`: `'Observation'`/`'Finding'`), `sp_tech_add_attachment`, `sp_tech_complete_task` (`Result` υποχρεωτικό) | `FIELD_TASK`, `TASK_NOTE`, `ATTACHMENT`, `NOTIFIES` | `technician/tasks.php`, `operator/tasks.php` |
| 2.3 ★ Εγκατάσταση μετρητή σε Premise: σειριακός, τύπος (Single-Phase/Three-Phase από `METER_MODEL`), firmware, τύπος επικοινωνίας, φάσεις σύνδεσης (όσες λέει το `PhaseCount`), Amps, φωτογραφίες και τα 3 έγγραφα εξοπλισμού | `sp_tech_install_meter`. Σε ένα transaction γράφει METER (`Status = 'Pending confirmation'`, `TransformerID` από τις συντεταγμένες, Σ7), METER_INSTALLATION και METER_CONNECTED_PHASE. Σε αντικατάσταση κλείνει την παλιά εγκατάσταση (`RemovedAt`), ο παλιός μετρητής γίνεται `'Retired'`, και **δεν σβήνει** τίποτα από τις μετρήσεις του. Έπειτα `sp_tech_add_meter_document` (`'Calibration certificate'`, `'CE and protocol declaration'`, `'Encryption certificate'`) και φωτογραφίες ως `ATTACHMENT` της εργασίας | `METER`, `METER_INSTALLATION`, `METER_CONNECTED_PHASE`, `DOCUMENT`, `ATTACHMENT` | `technician/install.php` |
| 2.3 ★ Ο Operator ελέγχει τα έγγραφα του μετρητή, γράφει το αποτέλεσμα και τον επιβεβαιώνει. **Μόνο** τότε γίνεται `Active` για ingestion | `sp_operator_confirm_meter(@UserID, @InstallationID, @Approve, @Comment)`: επιβεβαιώνει μόνο αν τα 3 έγγραφα είναι `'Accepted'` | `METER_INSTALLATION`, `METER`, `DOCUMENT`, `AUDIT_LOG` | `operator/meters.php` |
| 2.4 Απομακρυσμένες εντολές (διακοπή, επανενεργοποίηση, firmware) με προσπάθειες μέχρι ACK (Α15) | `sp_tech_request_command`, `sp_operator_approve_command`, `sp_command_record_attempt` (προσομοίωση Timeout/NAK/ACK) | `REMOTE_COMMAND`, `COMMAND_ATTEMPT`, `AUDIT_LOG` | `technician/commands.php`, `operator/commands.php` |
| 2.4 Περιοδικοί έλεγχοι ασφάλειας και anti-tamper: υπεύθυνος, ημερομηνία, σχόλια/ευρήματα, **ποιοι πρέπει να ενημερωθούν**. Συμβάν → νέα εργασία | `sp_task_create` με `TaskType = 'Anti-tamper check'` και λίστα χρηστών στο `NOTIFIES`, `sp_tech_report_tamper` (Σ8), `sp_event_create_task` (Σ4: `FIELD_TASK` + `LEADS_TO`) | `FIELD_TASK`, `TASK_NOTE`, `NOTIFIES`, `EVENT`, `LEADS_TO` | `operator/events.php` |

**Απαιτήσεις εκφώνησης (ΙΙΙ.2):**
- [ ] 2.1 Ο Τεχνικός εγγράφεται μόνος του, αλλά **δεν εκτελεί τίποτα** πριν τον εγκρίνει Operator (και το login και κάθε procedure το ελέγχουν).
- [ ] 2.1 Τουλάχιστον **μία** κατηγορία ανάλογα με την ειδικότητα. Δηλώνει **ημερήσια** χρονική και γεωγραφική διαθεσιμότητα.
- [ ] 2.1 Ενεργό email, ημερομηνία γέννησης, φωτογραφία, και τα 3 έγγραφα (Ταυτότητα, Άδεια Εγκαταστάτη, Πιστοποιητικό Τεχνικής Κατάρτισης) με αριθμό, ημερομηνία έκδοσης, λήξη όπου υπάρχει, αρχείο.
- [ ] 2.1 Έγκριση, απόρριψη και **κάθε** αλλαγή κατάστασης του τεχνικού καταγράφονται.
- [ ] 2.2 Τύποι εργασίας: εγκατάσταση, αντικατάσταση, τεχνικός έλεγχος, anti-tamper. Κάθε εργασία: υποστατικό ή/και μετρητής, τεχνικός, τύπος, προγραμματισμός, κατάσταση, αποτέλεσμα.
- [ ] 2.2 Ο Τεχνικός **αποδέχεται** την εργασία και **βλέπει τη θέση** του μετρητή. Παρατηρήσεις, ευρήματα, τεκμήρια = ιστορικό της εργασίας.
- [ ] 2.3 Αντιστοίχιση φυσικού μετρητή με Premise ID και τεχνικά στοιχεία: σειριακός, τύπος, firmware, επικοινωνία, φάσεις, Amps, φωτογραφίες, και τα 3 έγγραφα εξοπλισμού (Βαθμονόμηση, CE & Πρωτοκόλλου, Κρυπτογράφηση Τηλεμετρίας) με κωδικό, ημερομηνίες, αρχείο.
- [ ] 2.3 Νέος ή αντικατεστημένος μετρητής **δεν** είναι αυτόματα διαθέσιμος. Ο Operator ελέγχει, γράφει αποτέλεσμα, επιβεβαιώνει, και **μόνο τότε** `Active`.
- [ ] 2.3 Η αντικατάσταση **δεν** καταστρέφει τις παλιές χρονοσειρές του υποστατικού.
- [ ] 2.4 Εντολή = **εγγραφή** εντολής, όχι αλλαγή πεδίου: αιτών/εκτελών, στόχος, χρόνος, κατάσταση, **διαδοχικές προσπάθειες** μέχρι ACK. Μόνο όπου ο ρόλος και η ροή το επιτρέπουν (Α15).
- [ ] 2.4 Έλεγχοι ασφάλειας/anti-tamper: υπεύθυνος, ημερομηνία, σχόλια/ευρήματα, πρόσωπα προς ενημέρωση. Κρίσιμα συμβάντα συνδέονται με το Event Log και μπορούν να γίνουν **νέα εργασία**.

### 3.Δ ΙΙΙ.5 Suppliers και Aggregators (Δανάη)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 5.1 ★ Βλέπουν **μόνο** δεδομένα των δικών τους πελατών ή χαρτοφυλακίων, ποτέ raw. Βλέπουν σύνολο εισαγωγής (1.8.0), εξαγωγής (2.8.0) και καθαρή διαφορά, ανά περίοδο και μετασχηματιστή/geofence (σε οποιοδήποτε επίπεδο του δέντρου) | `sp_supplier_aggregates(@UserID, @PeriodType, @From, @To, @TransformerID = NULL)`: premises με `SUPPLY_CONTRACT` του `SupplierID` του χρήστη που ισχύει **μέσα στην περίοδο**. `sp_aggregator_aggregates(…)`: premises μέσα στο `PORTFOLIO`/`INCLUDES` του `AggregatorID`, για τις ημερομηνίες του `INCLUDES`. Και τα δύο αθροίζουν `METER_AGGREGATE` ομαδοποιημένα ανά `TransformerID`/geofence, και ανεβαίνουν στο δέντρο με CTE όταν δοθεί ανώτερος μετασχηματιστής | `METER_AGGREGATE`, `SUPPLY_CONTRACT`, `PORTFOLIO`, `INCLUDES`, `METER`, `METER_INSTALLATION`, `TRANSFORMER`, `GEOFENCE` | `supplier/aggregates.php`, `aggregator/aggregates.php` |
| 5.1 Διαχείριση χαρτοφυλακίου | `sp_aggregator_save_portfolio`, `sp_aggregator_add_premise` | `PORTFOLIO`, `INCLUDES` | `aggregator/portfolio.php` |
| 5.2 ★ Day-Ahead: ημερήσια, επικυρωμένα δεδομένα | Το `sp_supplier_aggregates` με `@PeriodType = 'Day'` | `METER_AGGREGATE` (Day) | ίδια σελίδα |
| 5.2 ★ Intraday: 15λεπτα **provisional** aggregates από τις πιο πρόσφατες μετρήσεις, **χωρίς** να περιμένουμε το VEE | `sp_market_intraday(@UserID, @Date)`: από `RAW_READING` των δικών τους premises. Για 1.8.0/2.8.0 το raw είναι **σωρευτικός μετρητής** (Α2), οπότε πρώτα βγαίνει η ενέργεια του 15λεπτου ανά μετρητή (διαφορά από το προηγούμενο, `LAG`) και **μετά** το SUM ανά 15λεπτο και μετασχηματιστή. Επιστρέφει **μόνο αθροίσματα**, ποτέ γραμμές ανά μετρητή, και σημειώνει ότι είναι provisional | `RAW_READING` | `supplier/intraday.php`, `aggregator/intraday.php` |

**Απαιτήσεις εκφώνησης (ΙΙΙ.5):**
- [ ] 5.1 Πρόσβαση **αποκλειστικά** στα δεδομένα των πελατών/χαρτοφυλακίων τους, μέσω κλήσεων στη βάση με έλεγχο ταυτότητας και δικαιωμάτων (τα procedures μας = τα «APIs»).
- [ ] 5.1 **Καμία** ανεξέλεγκτη πρόσβαση σε raw δεδομένα.
- [ ] 5.1 Συγκεντρωτικά από **επικυρωμένες** μετρήσεις, ανά χρονική περίοδο και Geofence, με συνολική εισαγωγή, συνολική εξαγωγή και καθαρή διαφορά.
- [ ] 5.2 Αλγόριθμοι πρόβλεψης/balancing **δεν** χρειάζονται, μόνο τα δεδομένα.
- [ ] 5.2 Day-Ahead: ημερήσια μορφή, από αποθηκευμένα επικυρωμένα δεδομένα.
- [ ] 5.2 Intraday: 15λεπτα provisional από τις πιο πρόσφατες μετρήσεις, **πριν** το VEE.

### 3.Ε ΙΙΙ.3 DSO: ingestion, VEE, aggregates, analytics (Αντρέας)

| Εκφώνηση | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 3.1 ★ Ένα πακέτο τηλεμετρίας (JSON όπως στο Παράρτημα) αντιστοιχίζεται σε **ενεργό** μετρητή μέσω NetworkID. Οι μετρήσεις μπαίνουν στο σωστό 15λεπτο. Ό,τι δεν ταιριάζει γράφεται ως αποτυχία ή συμβάν, και **ποτέ δεν χάνεται σιωπηλά** | `sp_dso_ingest_packet(@NetworkID, @Timestamp, @NetworkType, @SignalDbm, @PayloadJson)`: **πρώτα** γράφει πάντα το `TELEMETRY_PACKET` (με `RawPayload`), μετά `OPENJSON` → RAW_READING (`VeeStatus = 'Pending'`), με `IntervalStart` = το timestamp στρογγυλεμένο κάτω στο 15λεπτο. Ελέγχει ότι η μονάδα (`unit`) ταιριάζει με το `OBIS_CODE.Unit`. Άγνωστος μετρητής → `'Unknown meter'` + `EVENT 'Unmatched packet'`. Μη ενεργός → `'Meter not active'`. Κακό JSON → `'Malformed'`. Άγνωστο OBIS, λάθος μονάδα ή διπλή μέτρηση → `'Partially accepted'` με `ErrorMessage`. Κακό σήμα/λάθος τύπος δικτύου → `EVENT 'Communication problem'` (Α14) | `TELEMETRY_PACKET`, `RAW_READING`, `OBIS_CODE`, `EVENT` | `dso/ingest.php` (φόρμα με JSON για το demo, προσυμπληρωμένη με το πακέτο του Παραρτήματος) |
| 3.1 Όλοι οι 12 OBIS του Παραρτήματος (1.8.0, 1.8.1, 1.8.2, 2.8.0, 3.8.0, 4.8.0, 32.7.0, 52.7.0, 72.7.0, 31.7.0, 51.7.0, 71.7.0), με μεταβλητό σύνολο ανά πακέτο | Οι γραμμές του `OBIS_CODE` (ήδη στο `00_base.sql`). Ένας νέος κωδικός = νέα γραμμή, χωρίς αλλαγή δομής | `OBIS_CODE` | — |
| 3.2 ★ VEE. **Validation**: συντακτικά/επιχειρησιακά αποδεκτή, υποστηριζόμενο OBIS, όρια `MinValid`/`MaxValid`, spike (π.χ. 25,4 μετά από 1,8, 2,0, 1,9), κενά (π.χ. λείπει το 10:30 ανάμεσα σε 10:15 και 10:45). **Estimation**: γραμμική παρεμβολή από την προηγούμενη και την επόμενη τιμή (2,0 και 2,2 → 2,1), αποθήκευση ως `'Estimated'`. Για τους σωρευτικούς η παρεμβολή γίνεται στον σωρευτικό μετρητή, ώστε το άθροισμα της ημέρας να μένει σωστό. **Editing**: ελεγχόμενη διόρθωση με αρχική τιμή, νέα τιμή και προέλευση | `sp_dso_run_vee(@UserID, @From, @To)`: VEE_RUN → για κάθε Pending: έλεγχος κανόνων (`VEE_RULE`, `RULE_FOR`) → εκτιμήσεις στο `READING_EDIT` (`'Automatic estimate'` + `RuleID`) → **INSERT** στο `VALIDATED_READING` (`Quality`: Validated, Estimated ή Edited) → το raw γίνεται Validated, ή Suspect αν θέλει χειροκίνητο έλεγχο (+ `EVENT 'Suspect reading'`). `sp_dso_list_suspect`, `sp_dso_edit_reading` (`'Manual edit'` ή `'Manual estimate'`, με `EditedBy` και `Reason`). `AUDIT_LOG` με `ActorMechanism = 'VEE'` και τα μετρητικά του run | `RAW_READING`, `VEE_RULE`, `RULE_FOR`, `VEE_RUN`, `READING_EDIT`, `VALIDATED_READING`, `AUDIT_LOG` | `dso/vee.php` |
| 3.2 ★ Μετά το VEE οι μετρήσεις είναι **αμετάβλητες**. Η **ολοκλήρωση** του VEE ξεκινά τον υπολογισμό των aggregates, που υπολογίζονται **μόνο** από αυτές και είναι κι αυτά οριστικά | `sp_dso_build_aggregates(@UserID, @Day)`, που το καλεί και το `sp_dso_run_vee` στο τέλος: `METER_AGGREGATE` (Day, και Month/Year όταν κλείνει η περίοδος) και `TRANSFORMER_AGGREGATE` **μόνο στα φύλλα**. Γράφει μόνο με INSERT, μία φορά, για ημέρα που δεν έχει πια Pending/Suspect μετρήσεις, και δεν ξαναϋπολογίζει ό,τι υπάρχει. Το trigger ήδη απορρίπτει UPDATE στο validated | `METER_AGGREGATE`, `TRANSFORMER_AGGREGATE` | `dso/aggregates.php` |
| ΙΙ.Γ ★ Analytics: (1) βυθίσεις και υπερτάσεις τάσης (32.7.0, 52.7.0, 72.7.0 εκτός 207–253 V, κανόνας `VoltageBand`), (2) **υπολογισμός τεχνικών απωλειών**, (3) ανισορροπία φάσεων (31/51/71.7.0), (4) ύποπτη ρευματοκλοπή | `sp_dso_detect_events(@UserID, @From, @To)` → `EVENT` (`'Undervoltage'`, `'Overvoltage'`, `'Phase unbalance'`, `'Suspected theft'`, π.χ. ρεύμα στις φάσεις αλλά σχεδόν μηδενική 1.8.0). `sp_dso_technical_losses(@UserID, @From, @To, @LossPercent, @NoLoadKWhPerDay)`: ανά μετασχηματιστή-φύλλο, εκτιμώμενες απώλειες = σταθερές απώλειες κενού + ποσοστό της ενέργειας που πέρασε (από `TRANSFORMER_AGGREGATE`). Υπολογίζεται με ερώτημα και δεν αποθηκεύεται (υπόθεση Φάσης Α). Ερώτηση στον καθηγητή, ενότητα 7 | `VALIDATED_READING`, `TRANSFORMER_AGGREGATE`, `EVENT` | `dso/events.php`, `dso/losses.php` |

**Απαιτήσεις εκφώνησης (ΙΙΙ.3 και ΙΙ.Γ):**
- [ ] 3.1 Το πακέτο έχει αναγνωριστικό δικτύου, χρονική σήμανση, πληροφορία επικοινωνίας (σήμα, τύπος δικτύου) και ζεύγη OBIS/value/unit. Αποθηκεύεται και η πληροφορία επικοινωνίας.
- [ ] 3.1 **Πρώτα** αντιστοίχιση σε υπαρκτό **και** ενεργό/επιβεβαιωμένο μετρητή, **μετά** αποθήκευση με σωστό 15λεπτο, μονάδα και κωδικό.
- [ ] 3.1 Πακέτα που δεν αντιστοιχίζονται ή έχουν πρόβλημα επικοινωνίας καταγράφονται ως αποτυχίες/συμβάντα, **όχι** σιωπηλή απώλεια.
- [ ] 3.1 Τουλάχιστον οι 12 OBIS του Παραρτήματος. Κάθε πακέτο έχει **μεταβλητό** σύνολο κωδικών. Νέος κωδικός χωρίς ανασχεδιασμό.
- [ ] 3.2 Validation: σύνταξη, υποστηριζόμενο OBIS, όρια, κενά και ασυνέπειες στη χρονοσειρά. Estimation για ό,τι λείπει ή δεν χρησιμοποιείται αυτούσιο. Editing με αρχική τιμή, νέα τιμή, προέλευση.
- [ ] 3.2 Το αποτέλεσμα ξεχωρίζει τουλάχιστον validated/estimated και κρατά ποια τιμή χρησιμοποιείται μετά.
- [ ] 3.2 Τα δύο παραδείγματα της εκφώνησης δουλεύουν στο demo: spike 25,4 → ύποπτη, κενό 10:30 → εκτίμηση 2,1 με κατάσταση estimated.
- [ ] 3.2 Μετά το VEE: **immutable**. Η ολοκλήρωση του VEE ενεργοποιεί τα aggregates (ημερήσια, μηνιαία, ετήσια), που είναι κι αυτά οριστικά και δεν ξαναϋπολογίζονται.
- [ ] ΙΙ.Γ Analytics: βυθίσεις/υπερτάσεις, **τεχνικές απώλειες**, ανισορροπία φάσεων, ύποπτη ρευματοκλοπή.

### 3.ΣΤ ΙΙΙ.4 TSO: δέντρο μετασχηματιστών, κατάσταση, load shedding (Αντρέας)

| Εκφώνηση και καθηγητής | Procedures | Πίνακες | Σελίδα |
|---|---|---|---|
| 4.1 ★ Οι μετασχηματιστές είναι **δέντρο**: ένας γονέας, μετρητές **μόνο στα φύλλα** (triggers `TR_TRANSFORMER_Tree`, `TR_METER_LeafTransformer`). Κάθε μετασχηματιστής έχει ένα geofence (ορθογώνιο WGS84), και η ιεραρχία των geofences ακολουθεί αυτή των μετασχηματιστών, σε αυθαίρετο βάθος (παραδοχή του καθηγητή) | `sp_tso_add_transformer` (GEOFENCE + TRANSFORMER σε ένα transaction), `sp_tso_tree` (αναδρομικό CTE με επίπεδα L1…Ln) | `TRANSFORMER`, `GEOFENCE` | `tso/tree.php` |
| 4.1 ★ Από τις συντεταγμένες ενός μετρητή βρίσκουμε σε ποιο geofence ανήκει, και άρα τον μετασχηματιστή | `sp_tso_locate(@Lat, @Lon)`: geofence-φύλλο με `MinLat ≤ lat ≤ MaxLat` κ.λπ. (ίδιος κανόνας με το Σ7) | `GEOFENCE`, `TRANSFORMER` | ίδια |
| 4.2 ★ Τρέχουσα κατάσταση ανά 15λεπτο για **όλη** την ιεραρχία (Α16): SUM των 1.8.0 και 2.8.0 από VEE-verified μετρήσεις. Ο υπολογισμός ξεκινά με κουμπί από εξουσιοδοτημένο χρήστη. Όσες μετρήσεις λείπουν αγνοούνται | `sp_tso_refresh_current_state(@UserID)`: για το κοινό `RefInterval`, `MERGE` στο `TRANSFORMER_CURRENT_STATE` για τα φύλλα (SUM των μετρητών τους) **και** για όλους τους προγόνους (SUM των φύλλων από κάτω τους, CTE), σε ένα transaction. `sp_tso_current_state(@UserID, @TransformerID)`: διαβάζει από τον ενδιάμεσο πίνακα χωρίς επανυπολογισμό | `TRANSFORMER_CURRENT_STATE`, `VALIDATED_READING` | `tso/state.php` |
| Καθηγητής ★: τα **ιστορικά** aggregates **αποθηκεύονται μόνο για φύλλα** (μηνιαία ή πιο λεπτά), και τα πάνω επίπεδα υπολογίζονται όταν ζητηθούν. Μήνας → τρίμηνο. Τα aggregates είναι στους μετασχηματιστές, όχι στα geofences | `sp_tso_aggregates(@UserID, @TransformerID, @PeriodType, @From, @To)`: CTE πάνω στο δέντρο, με `GROUP BY` τρίμηνο όταν ζητηθεί | `TRANSFORMER_AGGREGATE` | `tso/aggregates.php` |
| ΙΙ.Δ ★ Remote load shedding σε **όλους** τους μετρητές κάτω από έναν μετασχηματιστή (αντί για Ripple Control) | `sp_tso_load_shed(@UserID, @TransformerID, @Reason)`: LOAD_SHED_ORDER και ένα REMOTE_COMMAND `'Load shed'` για κάθε **ενεργό** μετρητή των φύλλων από κάτω (Σ3), όλα σε **ένα transaction**. `sp_tso_shed_status` ενημερώνει το `LOAD_SHED_ORDER.Status` από τις εντολές | `LOAD_SHED_ORDER`, `REMOTE_COMMAND` | `tso/shed.php` |
| Bonus: χάρτης Leaflet με μετασχηματιστές, geofences και μετρητές (Leaflet αντιγραμμένο στο `sources/js/`) | `sp_tso_map_data` | — | `tso/map.php` |

**Απαιτήσεις εκφώνησης (ΙΙΙ.4 και ΙΙ.Δ):**
- [ ] 4.1 Κάθε μετρητής έχει WGS84 και ανήκει σε **έναν** μετασχηματιστή χαμηλής τάσης. Κάθε μετασχηματιστής έχει **ένα** geofence (εδώ ορθογώνιο).
- [ ] 4.1 Από τις συντεταγμένες ενός μετρητή βρίσκουμε το geofence και άρα τον μετασχηματιστή.
- [ ] 4.1 Ιεραρχία αυθαίρετου βάθους (L1 … Ln).
- [ ] 4.2 Εικόνα **VEE-verified**, ανά 15 λεπτά, για **όλη** την ιεραρχία. Τα L1 μετρούν τους μετρητές τους, τα ανώτερα **όλους** τους μετρητές από κάτω, σε οποιοδήποτε βάθος.
- [ ] 4.2 SUM ανά geofence, 15λεπτο και OBIS, **μόνο** για 1.8.0 και 2.8.0.
- [ ] 4.2 Αποθήκευση σε **ενδιάμεσο** πίνακα με τουλάχιστον geofence (εδώ μετασχηματιστή, Α16), **κοινό** 15λεπτο αναφοράς, OBIS, SUM. Χειροκίνητη ενεργοποίηση αρκεί. Ελλιπείς μετρήσεις απλώς αγνοούνται.
- [ ] 4.2 Όταν μια μέτρηση αλλάζει ένα L1, μπορούμε να ενημερώσουμε το ίδιο **και όλους τους προγόνους**.
- [ ] 4.2 Οι οριστικές 15λεπτες μετρήσεις και τα ιστορικά aggregates μένουν immutable. Ο ενδιάμεσος πίνακας δίνει τη νέα εικόνα χωρίς επανυπολογισμό από τα raw.
- [ ] ΙΙ.Δ Απομακρυσμένη αποσύνδεση φορτίου σε **όλους** τους μετρητές ενός μετασχηματιστή.

---

## 4. Κοινά κομμάτια (δεδομένα, απόδοση, τεκμηρίωση)

| Κομμάτι | Τι ακριβώς | Ποιος | Αρχεία |
|---|---|---|---|
| **Μικρά δεδομένα** | Ένας χρήστης demo **ανά ρόλο**, με γνωστό κωδικό δοκιμής που γράφεται στο εγχειρίδιο. Δέντρο 3 επιπέδων με 4–6 μετασχηματιστές, 10–20 premises και μετρητές, 2 μέρες μετρήσεις, που να περιέχουν ένα κενό και ένα spike για να φανεί το VEE. Το hash του κωδικού το φτιάχνει το PHP: `php -r "echo password_hash('…', PASSWORD_DEFAULT);"` | Ο καθένας για τους πίνακές του, και ο Σωτήρης τα ενώνει | `data/small/*.sql` |
| **Μεγάλα δεδομένα** | Χιλιάδες γραμμές: π.χ. 2.000 premises και μετρητές, 30 μέρες × 96 15λεπτα × 2 OBIS ≈ 11 εκατ. είναι πολλά, οπότε στοχεύουμε **~200.000–500.000 μετρήσεις**. Τα scripts Python βγάζουν αρχεία `.dat` και από αυτά το `sql/import.sql` (Α8). Ο μεγάλος όγκος βαθμολογείται | Αντρέας (μετρήσεις, πακέτα), Δανάη (τεχνικοί, εργασίες, έγγραφα, αγορά), Σωτήρης (χρήστες, premises, συμβόλαια, τιμολόγια). Το `sql/import.sql` το ενώνει η E7 | `data/gen/*.py`, `data/large/*.dat`, `sql/import.sql` |
| **3 indexes + «πριν/μετά»** | (1) `RAW_READING (VeeStatus) WHERE VeeStatus = 'Pending'`, για το VEE. (2) `FIELD_TASK (TechnicianID, Status)`. (3) `INVOICE (UserID, IssueDate)`. Η περίπτωση «πριν/μετά» δείχνει το (1) ή ένα ερώτημα μετρήσεων με `SET STATISTICS IO, TIME ON` και execution plan, με screenshot | Ο καθένας το δικό του, Αντρέας το «πριν/μετά» | `sql/indexes.sql` |
| **Τεστ απόδοσης** | 10.000 κλήσεις ενός μείγματος OLTP procedures (login, readings καταναλωτή, λίστα εργασιών, ingest). Μετράμε χρόνους και δείχνουμε ότι το 95% είναι κάτω από 2 s | Αντρέας | `tests/perf.php` ή `tests/perf.py` και ο πίνακας αποτελεσμάτων στο doc |
| **Ασφάλεια (κεφ. b του χωριστού εγγράφου)** | Hash κωδικών (δεν φαίνονται ούτε σε όποιον διαβάζει τους πίνακες), login και session, έλεγχος ρόλου σε PHP **και** σε procedure, παράμετροι `?` (SQL injection), `htmlspecialchars` (XSS), CSRF, κανένας κωδικός στο repo, ελάχιστα δικαιώματα (`GRANT EXECUTE` μόνο σε procedures), suppliers/aggregators χωρίς raw, GDPR. Για κάθε σημείο: **πού** στον κώδικα εφαρμόζεται | Σωτήρης (S14) | `docs/phase-b/asfaleia.md` |
| **Contention και ταυτοχρονία (κεφ. a)** | Οι **δύο** περιπτώσεις της εκφώνησης: (1) ingestion ενώ τρέχει το VEE ή τα aggregates: το VEE διαβάζει μόνο Pending γραμμές με `UPDLOCK, READPAST`, ένα δεύτερο VEE μπλοκάρεται με `sp_getapplock`, και τα RAW → VALIDATED και CURRENT_STATE λειτουργούν ως ενδιάμεσοι πίνακες. (2) Δύο χρήστες στην ίδια εγγραφή: διπλή πληρωμή του ίδιου τιμολογίου (`UPDLOCK, HOLDLOCK` στο `sp_consumer_pay_invoice`), δύο Operators που εγκρίνουν τον ίδιο τεχνικό ή μετρητή, δύο αναθέσεις της ίδιας εργασίας. Isolation levels που διαλέξαμε και γιατί. Hot spots: `AUDIT_LOG`, IDENTITY, `TRANSFORMER_CURRENT_STATE`. Μαζί τα 3 indexes, το «πριν/μετά» και το τεστ απόδοσης | Αντρέας (A14) | `docs/phase-b/taftoxronia.md` |
| **Επέκταση (κεφ. c)** | Χωρίς αλλαγή δομής, μόνο νέες γραμμές: νέος τύπος μετρητή → `METER_MODEL`, νέο πρωτόκολλο → `COMM_TYPE`, νέος OBIS → `OBIS_CODE`, νέος κανόνας VEE → `VEE_RULE` + `RULE_FOR`, νέα κλάση prosumer → `SUPPLY_SCHEME`, νέος τύπος συμβάντος → τιμή στο `EVENT.EventType` (Α14), νέα υπηρεσία → `SERVICE_TYPE`. Και οι μελλοντικές υπηρεσίες της εκφώνησης (δυναμικές διατιμήσεις, Vehicle-to-Grid, micro-grids): πώς θα έμπαιναν. Geofences σχεδιασμένα ελεύθερα στον χάρτη = future work, όπως είπε ο καθηγητής | Δανάη (D16) | `docs/phase-b/epektasi.md` |
| **Ένα χωριστό έγγραφο (a, b, c)** | Η εκφώνηση ζητά **ένα** χωριστό έγγραφο, εκτός από το εγχειρίδιο, με τα τρία κεφάλαια. Τα τρία .md ενώνονται σε ένα `.docx`/`.pdf` | Αντρέας (E8) | `docx/12-tekmiriosi.docx` |
| **Εγχειρίδιο χρήστη** | Οδηγίες ανά ρόλο με screenshots (και οι χρήστες demo), βασικές επιλογές σχεδίασης (και οι 4 αλλαγές του καθηγητή), **επιπλέον λειτουργίες** που κάναμε, υποθέσεις, δυσκολίες, τελικό ER (E2), λεξικό δεδομένων (E3), περιορισμοί και δυνατότητες βελτίωσης, πώς στήνεται η βάση (σειρά Α9) και πίνακας συμβολής των μελών | Δανάη (κορμός) + ο καθένας τη δική του ενότητα | `docs/phase-b/egxeiridio.md` |
| **Ενημερωμένο ER** | Το ER της Φάσης Α με τις 4 αλλαγές: ένας `USER_ACCOUNT` με Role, `RAW_READING`/`VALIDATED_READING`, αναδρομική σχέση `TRANSFORMER`, aggregates στους μετασχηματιστές | Σωτήρης + Claude | `docs/phase-b/er-teliko.png` |
| **`select.sql`** | Τα βασικά ερωτήματα, για να τα τρέξει ο εξεταστής στο SSMS: ένα `EXEC` για κάθε κύρια λειτουργία κάθε ρόλου, και τα analytics (aggregates ανά επίπεδο δέντρου, απώλειες, συμβάντα). Ο καθένας δίνει τα δικά του | Σωτήρης ενώνει (E7) | `sql/select.sql` |
| **Τελικό zip** | Από καθαρή βάση: drop → create → procs → indexes → data χωρίς λάθος. Μετά φτιάχνεται το `12.zip` | Σωτήρης | — |

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
| **Τετ 2/12** | Doc ασφάλειας + **νέο ER και λεξικό δεδομένων (E2, E3, με το Claude)** + `select.sql`/`import.sql` (E7) | Εγχειρίδιο + doc επέκτασης | Doc ταυτοχρονίας + ένα χωριστό έγγραφο a/b/c (E8) (+ Leaflet αν προλαβαίνει) | **Code freeze το βράδυ**: μετά μόνο διορθώσεις |
| **Πέμ 3/12** | `12.zip`, εκτύπωση του `docx/` | Διαβάζει όλα τα docs | Δοκιμή από καθαρή βάση | **Πρόβα demo 30'**: ο καθένας δείχνει την περιοχή του, και ρωτάμε ο ένας τον άλλον |
| **Παρ 4/12** | Υποβολή **πριν τις 11:00** | — | — | Προθεσμία 12:00 |

### Σενάριο demo (30')

Η εκφώνηση θέλει την επίδειξη **από όλα τα μέλη**. Ο καθένας παρουσιάζει τα βήματα της περιοχής του και απαντά σε ερωτήσεις για περιοχή άλλου, ώστε να φαίνεται ότι όλοι ξέρουν όλο το σύστημα.

1. (Σωτήρης) Login ως Καταναλωτής → υποστατικά → μετρήσεις τρέχοντος μήνα, εισαγωγή/εξαγωγή χωριστά για prosumer → αίτημα βλάβης → τιμολόγια και πληρωμή → αίτημα GDPR.
2. (Δανάη) Login ως Operator → έλεγχος εγγράφων και έγκριση τεχνικού → εργασία από το αίτημα → ανάθεση.
3. (Δανάη) Login ως Τεχνικός → αποδοχή → εγκατάσταση μετρητή με τα 3 έγγραφα → ο Operator τον επιβεβαιώνει → γίνεται Active → εντολή διακοπής με προσπάθειες μέχρι ACK.
4. (Αντρέας) Login ως DSO → ingest του πακέτου JSON του Παραρτήματος και ενός πακέτου από άγνωστο μετρητή (γίνεται συμβάν) → VEE: spike 25,4 ύποπτο και κενό 10:30 εκτιμημένο → διόρθωση ύποπτης τιμής → aggregates → συμβάντα τάσης/ανισορροπίας και τεχνικές απώλειες.
5. (Αντρέας) Login ως TSO → δέντρο με άθροισμα ανά επίπεδο και ανά τρίμηνο → εντοπισμός μετασχηματιστή από συντεταγμένες → refresh τρέχουσας κατάστασης → load shedding (και χάρτης, αν υπάρχει).
6. (Δανάη) Login ως Supplier/Aggregator → Day-Ahead (ημερήσια) και Intraday (provisional), μόνο για τους δικούς τους πελάτες.
7. (Σωτήρης) Operator → εξέταση και προέγκριση GDPR → Admin → τελική έγκριση και εφαρμογή → τι σβήστηκε και τι κρατήθηκε → log.
8. (όλοι, 3') Το ER, ένα index με το «πριν/μετά», και πώς απαντήσαμε στην ταυτοχρονία.

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
- Να κάνει merge στο `main`. Το merge το κάνει ο Σωτήρης (ή το Claude του, μόνο όταν ο Σωτήρης το ζητήσει).
- Να διαβάσει την εκφώνηση. Δεν είναι στο repo, οπότε το Claude δουλεύει από την ενότητα 3 αυτού του πλάνου, που τη μεταφέρει όλη. Αν βρει κάτι που δεν καλύπτεται εκεί, σου ζητά το `project.pdf`.

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

Μέχρι να απαντήσει, ισχύει η προεπιλογή που γράφεται σε κάθε ερώτηση, ώστε να μην περιμένει κανείς.

1. **Τεχνικές απώλειες (ΙΙ.Γ)**: δεν έχουμε μέτρηση στην είσοδο του μετασχηματιστή. Αρκεί εκτίμηση (σταθερές απώλειες κενού + ποσοστό της ενέργειας που πέρασε από τον μετασχηματιστή), ή θέλετε να μοντελοποιήσουμε μετρητή στην είσοδό του; *Προεπιλογή: εκτίμηση με παραμέτρους (A5).*
2. **GDPR και διατήρηση**: είναι **ένα** αίτημα το «δικαίωμα στη λήθη» και η μείωση της διατήρησης στον 1 μήνα, και μετά την εφαρμογή μένει ο λογαριασμός με ανωνυμοποιημένα στοιχεία; *Προεπιλογή: ένα αίτημα, ο λογαριασμός μένει ανωνυμοποιημένος, τιμολόγια/πληρωμές/aggregates μένουν (Α17).*
3. **Τι σβήνει η διατήρηση**: οι «πρωτογενείς 15λεπτες μετρήσεις» που σβήνονται μετά από 3 χρόνια είναι μόνο οι raw ή και οι επικυρωμένες 15λεπτες του καταναλωτή; *Προεπιλογή: και οι δύο, μένουν μόνο τα aggregates (Α17).*
4. **Τρέχουσα κατάσταση (ΙΙΙ.4.2)**: για το ιστορικό είπατε aggregates μόνο στα φύλλα. Για τον ενδιάμεσο πίνακα τρέχουσας κατάστασης κρατάμε γραμμή για όλη την ιεραρχία (όπως λέει η εκφώνηση, με ενημέρωση των ancestors). Είναι σωστό; *Προεπιλογή: ναι (Α16).*
5. **Δεδομένα .dat**: αρκεί τα `.dat` να είναι CSV και το import να γίνεται με το `sql/import.sql` (INSERT), αφού το `BULK INSERT` στον server του Τμήματος δεν βλέπει τα δικά μας αρχεία; *Προεπιλογή: ναι (Α8).*
6. **Isolation**: μπορούμε να κάνουμε `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON` στη βάση μας στον server του Τμήματος; *Προεπιλογή: όχι, μένουμε σε `READ COMMITTED` με hints (`UPDLOCK`, `READPAST`) και `sp_getapplock`.*
7. **Intraday**: αρκεί να υπολογίζονται on-demand από τα raw, χωρίς αποθήκευση; *Προεπιλογή: ναι (D12).*
8. **Εξέταση**: πότε είναι η ημερομηνία της εξέτασης και πότε βγαίνει ο αναλυτικός οδηγός βαθμολόγησης (ενότητα VI);

---

## 8. Λίστα ελέγχου πριν την υποβολή (3/12)

- [ ] Σε **καθαρή** βάση τρέχουν χωρίς λάθος, με αυτή τη σειρά: `drop.sql` → `create.sql` → `procs_*.sql` → `indexes.sql` → `data/small/*.sql` → `sql/import.sql`.
- [ ] Το `sql/` έχει τα αρχεία με τα ονόματα της εκφώνησης: `create.sql`, `drop.sql`, `import.sql`, `select.sql`, `indexes.sql` (E7). Το `data/` έχει τα `.dat`.
- [ ] Κάθε γραμμή «Απαιτήσεις εκφώνησης» της ενότητας 3 είναι τσεκαρισμένη.
- [ ] Το `sources/` δουλεύει μόνο του από το zip (βιβλιοθήκες όπως το Leaflet μέσα, όχι μόνο από CDN), χωρίς `config.php`.
- [ ] Κάθε ρόλος έχει χρήστη demo και όλες τις ★ λειτουργίες του δουλεύουν από το UI.
- [ ] Raw → VEE → validated → aggregates φαίνεται στο UI του DSO, με spike και εκτίμηση κενού.
- [ ] Δέντρο μετασχηματιστών με άθροισμα ανά επίπεδο και load shedding φαίνονται στο UI του TSO.
- [ ] Η GDPR ροή πάει από άκρη σε άκρη και τα τιμολόγια κρατιούνται.
- [ ] Χιλιάδες γραμμές στο `data/`, 3 indexes στο `indexes.sql`, μία περίπτωση «πριν/μετά» με screenshot.
- [ ] Αποτελέσματα του τεστ 10.000 αιτήσεων (95% < 2 s) στο doc ταυτοχρονίας/απόδοσης.
- [ ] `docx/`: εγχειρίδιο (οδηγίες, επιλογές σχεδίασης, επιπλέον λειτουργίες, δυσκολίες, τελικό ER, λεξικό δεδομένων, περιορισμοί/βελτιώσεις) και **ένα** χωριστό έγγραφο με (a) contention, (b) ασφάλεια, (c) επέκταση (E8).
- [ ] Κανένας κωδικός μέσα στο zip ή στο repo (`config.php` εκτός).
- [ ] `12.zip` με `sources/ sql/ data/ docx/` στο Moodle, και τυπωμένο το `docx/`.
- [ ] Ο καθένας έχει διαβάσει όλες τις περιοχές και μπορεί να εξηγήσει π.χ. το `create.sql` ενός πίνακα, το VEE και τη GDPR ροή.
