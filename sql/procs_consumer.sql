-- =====================================================================
-- procs_consumer.sql : ΙΙΙ.1 Καταναλωτές (περιοχή CON)
--   CON-1 υποστατικά + τραπεζικοί λογαριασμοί
--   CON-4 αιτήματα ελέγχου/βλάβης
--   CON-5 τιμολόγια, πληρωμές, εξόφληση
--   CON-3 όρια κατανάλωσης, κανάλια ειδοποίησης, συμβάντα ποιότητας
-- Τρέχει μετά το procs_common.sql. Λάθη: 51000-51999 (απόφαση Α4).
-- Κάθε procedure παίρνει πρώτο το @UserID και ελέγχει ότι είναι ενεργός Καταναλωτής.
-- Ο καταναλωτής βλέπει/αλλάζει ΜΟΝΟ τα δικά του (υποστατικά που κρατά, δικά του τιμολόγια).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: σταματά με λάθος αν ο χρήστης δεν είναι ενεργός Καταναλωτής.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_consumer_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'Consumer' AND AccountStatus = 'Active')
        THROW 51000, N'Δεν επιτρέπεται: μόνο για ενεργό Καταναλωτή.', 1;
END;
GO

-- Υποστατικά που ο χρήστης κρατά ΣΗΜΕΡΑ (το HOLDING δεν έχει λήξει).
-- Inline table-valued function: επιστρέφει μία γραμμή αν το κρατά, καμία αν όχι.
-- Χρήση:  IF NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID)) ...
-- Γιατί όχι scalar (RETURNS BIT): η T-SQL θέλει σχήμα μπροστά σε scalar function (dbo.f()),
-- αλλά στον server του Τμήματος κάθε χρήστης έχει δικό του σχήμα (π.χ. apieri01), όχι dbo.
-- Μια table-valued function καλείται χωρίς σχήμα. (CON-7)
DROP FUNCTION IF EXISTS fn_consumer_holds;   -- η παλιά scalar έκδοση δεν αλλάζει με ALTER σε table-valued
GO
CREATE FUNCTION fn_consumer_holds (@UserID INT, @PremiseID INT)
RETURNS TABLE
AS
RETURN (
    SELECT 1 AS Holds FROM HOLDING
    WHERE UserID = @UserID AND PremiseID = @PremiseID
      AND StartDate <= CAST(SYSUTCDATETIME() AS DATE)
      AND (EndDate IS NULL OR EndDate >= CAST(SYSUTCDATETIME() AS DATE))
);
GO

-- =====================================================================
-- CON-1. Υποστατικά (ΙΙΙ.1.1)
-- =====================================================================

-- Νέο υποστατικό: PREMISE + HOLDING μαζί (ή και τα δύο, ή κανένα).
CREATE OR ALTER PROCEDURE sp_consumer_add_premise
    @UserID INT, @Address NVARCHAR(200), @PostalCode CHAR(4),
    @Latitude DECIMAL(9,6), @Longitude DECIMAL(9,6), @UsageType VARCHAR(12),
    @ParishID INT, @SchemeID INT, @StartDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    IF @PostalCode IS NULL OR @PostalCode NOT LIKE '[0-9][0-9][0-9][0-9]'
        THROW 51001, N'Ο ταχυδρομικός κώδικας θέλει 4 ψηφία.', 1;
    IF @UsageType NOT IN ('Residential', 'Commercial', 'Industrial', 'Agricultural')
        THROW 51002, N'Μη έγκυρη χρήση υποστατικού.', 1;
    IF NOT EXISTS (SELECT 1 FROM PARISH WHERE ParishID = @ParishID)
        THROW 51003, N'Διαλέξτε ενορία από τη λίστα.', 1;
    IF NOT EXISTS (SELECT 1 FROM SUPPLY_SCHEME WHERE SchemeID = @SchemeID)
        THROW 51004, N'Διαλέξτε σχήμα προμήθειας από τη λίστα.', 1;
    IF @Latitude NOT BETWEEN 34.4 AND 35.8 OR @Longitude NOT BETWEEN 32.2 AND 34.7
        THROW 51005, N'Οι συντεταγμένες (WGS84) δεν είναι μέσα στην Κύπρο.', 1;
    SET @StartDate = ISNULL(@StartDate, CAST(SYSUTCDATETIME() AS DATE));
    BEGIN TRY
        BEGIN TRAN;
        INSERT PREMISE (Address, PostalCode, Latitude, Longitude, UsageType, ParishID, SchemeID)
        VALUES (@Address, @PostalCode, @Latitude, @Longitude, @UsageType, @ParishID, @SchemeID);
        DECLARE @pid INT = SCOPE_IDENTITY();
        INSERT HOLDING (UserID, PremiseID, StartDate) VALUES (@UserID, @pid, @StartDate);
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('PREMISE', @pid, 'Add premise', @Address, @UserID);
        COMMIT;
        SELECT @pid AS PremiseID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Τα υποστατικά μου (και παλιά, με ημερομηνία λήξης), με τον μετρητή που έχουν τώρα.
CREATE OR ALTER PROCEDURE sp_consumer_list_premises
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT p.PremiseID, p.Address, p.PostalCode,
           CASE p.UsageType WHEN 'Residential' THEN N'Οικιακό' WHEN 'Commercial' THEN N'Εμπορικό'
                            WHEN 'Industrial' THEN N'Βιομηχανικό' ELSE N'Γεωργικό' END AS Usage,
           d.Name AS District, m.Name AS Municipality, pa.Name AS Parish, s.Name AS Scheme,
           p.Latitude, p.Longitude, h.StartDate, h.EndDate,
           (SELECT TOP 1 me.SerialNumber FROM METER_INSTALLATION mi JOIN METER me ON me.MeterID = mi.MeterID
             WHERE mi.PremiseID = p.PremiseID AND mi.RemovedAt IS NULL AND mi.ConfirmationStatus = 'Confirmed'
             ORDER BY mi.InstalledAt DESC) AS Meter
    FROM HOLDING h
    JOIN PREMISE p ON p.PremiseID = h.PremiseID
    JOIN PARISH pa ON pa.ParishID = p.ParishID
    JOIN MUNICIPALITY m ON m.MunicipalityID = pa.MunicipalityID
    JOIN DISTRICT d ON d.DistrictID = m.DistrictID
    JOIN SUPPLY_SCHEME s ON s.SchemeID = p.SchemeID
    WHERE h.UserID = @UserID
    ORDER BY CASE WHEN h.EndDate IS NULL THEN 0 ELSE 1 END, p.PremiseID;
END;
GO

-- Τέλος κατοχής (π.χ. μετακόμιση). Το υποστατικό και οι μετρήσεις του ΜΕΝΟΥΝ.
CREATE OR ALTER PROCEDURE sp_consumer_end_holding
    @UserID INT, @PremiseID INT, @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    SET @EndDate = ISNULL(@EndDate, CAST(SYSUTCDATETIME() AS DATE));
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))
        THROW 51006, N'Δεν κρατάτε αυτό το υποστατικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE HOLDING SET EndDate = @EndDate
        WHERE UserID = @UserID AND PremiseID = @PremiseID AND EndDate IS NULL AND StartDate <= @EndDate;
        IF @@ROWCOUNT = 0 THROW 51007, N'Η ημερομηνία λήξης είναι πριν την έναρξη.', 1;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('HOLDING', CONCAT(@UserID, '/', @PremiseID), 'End holding', CONVERT(VARCHAR(10), @EndDate, 23), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- CON-1. Τραπεζικοί λογαριασμοί (ΙΙΙ.1.1)
-- =====================================================================

-- Νέος λογαριασμός. Αν δοθεί @PremiseID, τον δένουμε και με το υποστατικό (ACCOUNT_FOR).
CREATE OR ALTER PROCEDURE sp_consumer_add_bank_account
    @UserID INT, @IBAN VARCHAR(50), @HolderName NVARCHAR(100), @PremiseID INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    SET @IBAN = UPPER(REPLACE(@IBAN, ' ', ''));
    IF @IBAN NOT LIKE '[A-Z][A-Z][0-9][0-9]%' OR @IBAN LIKE '%[^A-Z0-9]%' OR LEN(@IBAN) NOT BETWEEN 15 AND 34
        THROW 51010, N'Μη έγκυρο IBAN (π.χ. CY17 0020 0128 0000 0012 0052 7600).', 1;
    IF EXISTS (SELECT 1 FROM BANK_ACCOUNT WHERE IBAN = @IBAN)
        THROW 51011, N'Αυτό το IBAN είναι ήδη καταχωρημένο.', 1;
    IF @PremiseID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))
        THROW 51006, N'Δεν κρατάτε αυτό το υποστατικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT BANK_ACCOUNT (IBAN, HolderName, UserID) VALUES (@IBAN, @HolderName, @UserID);
        DECLARE @bid INT = SCOPE_IDENTITY();
        IF @PremiseID IS NOT NULL
            INSERT ACCOUNT_FOR (BankAccountID, PremiseID) VALUES (@bid, @PremiseID);
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('BANK_ACCOUNT', @bid, 'Add bank account', CONCAT('****', RIGHT(@IBAN, 4)), @UserID);
        COMMIT;
        SELECT @bid AS BankAccountID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Οι λογαριασμοί μου, με τα υποστατικά που εξυπηρετεί ο καθένας.
CREATE OR ALTER PROCEDURE sp_consumer_list_bank_accounts
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT b.BankAccountID, b.IBAN, b.HolderName,
           (SELECT STRING_AGG(p.Address, N'; ') FROM ACCOUNT_FOR af JOIN PREMISE p ON p.PremiseID = af.PremiseID
             WHERE af.BankAccountID = b.BankAccountID) AS Premises
    FROM BANK_ACCOUNT b
    WHERE b.UserID = @UserID
    ORDER BY b.BankAccountID;
END;
GO

-- =====================================================================
-- CON-4. Αιτήματα ελέγχου μετρητή / αναφορά βλάβης (ΙΙΙ.1.3)
-- =====================================================================

-- Οι μετρητές που είναι ΤΩΡΑ εγκατεστημένοι στα υποστατικά μου (για λίστες επιλογής).
CREATE OR ALTER PROCEDURE sp_consumer_list_meters
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT me.MeterID, me.SerialNumber, p.PremiseID, p.Address, me.Status
    FROM METER_INSTALLATION mi
    JOIN METER me ON me.MeterID = mi.MeterID
    JOIN PREMISE p ON p.PremiseID = mi.PremiseID
    WHERE mi.RemovedAt IS NULL AND mi.ConfirmationStatus = 'Confirmed'
      AND EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, p.PremiseID))
    ORDER BY p.PremiseID, me.MeterID;
END;
GO

CREATE OR ALTER PROCEDURE sp_consumer_submit_request
    @UserID INT, @PremiseID INT, @MeterID INT = NULL,
    @RequestType VARCHAR(12), @Description NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    IF @RequestType NOT IN ('Meter check', 'Fault report')
        THROW 51020, N'Διαλέξτε «Έλεγχος μετρητή» ή «Αναφορά βλάβης».', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))
        THROW 51006, N'Δεν κρατάτε αυτό το υποστατικό.', 1;
    IF @MeterID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM METER_INSTALLATION
            WHERE MeterID = @MeterID AND PremiseID = @PremiseID AND RemovedAt IS NULL)
        THROW 51021, N'Ο μετρητής δεν είναι εγκατεστημένος σε αυτό το υποστατικό.', 1;
    IF @Description IS NULL OR LEN(LTRIM(@Description)) < 5
        THROW 51022, N'Περιγράψτε το πρόβλημα (τουλάχιστον 5 χαρακτήρες).', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT SERVICE_REQUEST (RequestType, Description, UserID, PremiseID, MeterID)
        VALUES (@RequestType, @Description, @UserID, @PremiseID, @MeterID);
        DECLARE @rid INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('SERVICE_REQUEST', @rid, 'Submit request', 'Submitted', @UserID);
        COMMIT;
        SELECT @rid AS RequestID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Ιστορικό αιτημάτων, μαζί με την εργασία πεδίου που προέκυψε (περιοχή TEC, συμφωνία X1).
CREATE OR ALTER PROCEDURE sp_consumer_list_requests
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT r.RequestID, r.SubmittedAt,
           CASE r.RequestType WHEN 'Meter check' THEN N'Έλεγχος μετρητή' ELSE N'Αναφορά βλάβης' END AS RequestType,
           p.Address, me.SerialNumber AS Meter, r.Description,
           CASE r.Status WHEN 'Submitted' THEN N'Υποβλήθηκε' WHEN 'Assigned' THEN N'Ανατέθηκε'
                         WHEN 'Resolved' THEN N'Επιλύθηκε' ELSE N'Ακυρώθηκε' END AS Status,
           t.ScheduledFrom AS VisitFrom, t.ScheduledTo AS VisitTo, t.Result
    FROM SERVICE_REQUEST r
    JOIN PREMISE p ON p.PremiseID = r.PremiseID
    LEFT JOIN METER me ON me.MeterID = r.MeterID
    OUTER APPLY (SELECT TOP 1 ft.ScheduledFrom, ft.ScheduledTo, ft.Result FROM FIELD_TASK ft
                 WHERE ft.RequestID = r.RequestID AND ft.Status <> 'Cancelled' ORDER BY ft.TaskID DESC) t
    WHERE r.UserID = @UserID
    ORDER BY r.SubmittedAt DESC, r.RequestID DESC;
END;
GO

-- Ακύρωση: μόνο όσο το αίτημα δεν έχει ανατεθεί.
CREATE OR ALTER PROCEDURE sp_consumer_cancel_request
    @UserID INT, @RequestID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE SERVICE_REQUEST WITH (UPDLOCK) SET Status = 'Cancelled'
        WHERE RequestID = @RequestID AND UserID = @UserID AND Status = 'Submitted';
        IF @@ROWCOUNT = 0
            THROW 51023, N'Ακυρώνεται μόνο δικό σας αίτημα που δεν έχει ακόμη ανατεθεί.', 1;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('SERVICE_REQUEST', @RequestID, 'Cancel request', 'Submitted', 'Cancelled', @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- CON-5. Τιμολόγια και πληρωμές (ΙΙΙ.1.3)
-- =====================================================================

CREATE OR ALTER PROCEDURE sp_consumer_list_invoices
    @UserID INT, @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT i.InvoiceID, i.IssueDate, i.PeriodFrom, i.PeriodTo, i.Amount,
           ISNULL(pay.Paid, 0) AS Paid,
           CASE WHEN i.Status = 'Cancelled' THEN 0 ELSE i.Amount - ISNULL(pay.Paid, 0) END AS Remaining,
           CASE i.Status WHEN 'Issued' THEN N'Εκδόθηκε' WHEN 'Partially paid' THEN N'Μερικώς πληρωμένο'
                         WHEN 'Paid' THEN N'Εξοφλήθηκε' ELSE N'Ακυρώθηκε' END AS Status,
           s.Name AS Supplier, p.Address
    FROM INVOICE i
    LEFT JOIN SUPPLY_CONTRACT c ON c.ContractID = i.ContractID
    LEFT JOIN SUPPLIER s ON s.SupplierID = c.SupplierID
    LEFT JOIN PREMISE p ON p.PremiseID = c.PremiseID
    OUTER APPLY (SELECT SUM(Amount) AS Paid FROM PAYMENT WHERE InvoiceID = i.InvoiceID) pay
    WHERE i.UserID = @UserID AND (@Year IS NULL OR YEAR(i.IssueDate) = @Year)
    ORDER BY i.IssueDate DESC, i.InvoiceID DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_consumer_list_payments
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT pm.PaymentID, pm.PaidAt, pm.Amount, pm.InvoiceID,
           CASE WHEN b.IBAN IS NULL THEN NULL ELSE CONCAT(LEFT(b.IBAN, 4), ' **** ', RIGHT(b.IBAN, 4)) END AS IBAN,
           pm.Reference
    FROM PAYMENT pm
    JOIN INVOICE i ON i.InvoiceID = pm.InvoiceID
    LEFT JOIN BANK_ACCOUNT b ON b.BankAccountID = pm.BankAccountID
    WHERE i.UserID = @UserID
    ORDER BY pm.PaidAt DESC, pm.PaymentID DESC;
END;
GO

-- Πληρωμή (ολική ή μερική). UPDLOCK: αν δύο πληρωμές του ίδιου τιμολογίου γίνουν
-- ταυτόχρονα, η δεύτερη περιμένει την πρώτη, και δεν πληρώνεται περισσότερο από το ποσό.
CREATE OR ALTER PROCEDURE sp_consumer_pay_invoice
    @UserID INT, @InvoiceID INT, @BankAccountID INT, @Amount DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    -- Ρητό isolation level (επιστρέφει αυτόματα στο προηγούμενο όταν τελειώσει η procedure): SERIALIZABLE,
    -- ώστε έλεγχος και εγγραφή να μη χωρίζονται από άλλη συναλλαγή. Τα UPDLOCK/HOLDLOCK μένουν (doc 15, §2).
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    EXEC sp_consumer_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM INVOICE WHERE InvoiceID = @InvoiceID AND UserID = @UserID)
        THROW 51030, N'Το τιμολόγιο δεν είναι δικό σας.', 1;
    IF NOT EXISTS (SELECT 1 FROM BANK_ACCOUNT WHERE BankAccountID = @BankAccountID AND UserID = @UserID)
        THROW 51031, N'Διαλέξτε έναν από τους δικούς σας λογαριασμούς.', 1;
    IF @Amount IS NULL OR @Amount <= 0
        THROW 51032, N'Το ποσό πρέπει να είναι θετικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(14), @total DECIMAL(12,2);
        SELECT @old = Status, @total = Amount FROM INVOICE WITH (UPDLOCK, HOLDLOCK) WHERE InvoiceID = @InvoiceID;
        IF @old IN ('Paid', 'Cancelled')
            THROW 51033, N'Το τιμολόγιο είναι ήδη εξοφλημένο ή ακυρωμένο.', 1;
        DECLARE @paid DECIMAL(12,2) = ISNULL((SELECT SUM(Amount) FROM PAYMENT WHERE InvoiceID = @InvoiceID), 0);
        IF @Amount > @total - @paid
            THROW 51034, N'Το ποσό είναι μεγαλύτερο από το υπόλοιπο του τιμολογίου.', 1;
        INSERT PAYMENT (Amount, PaidAt, Reference, InvoiceID, BankAccountID)
        VALUES (@Amount, SYSUTCDATETIME(), CONCAT('WEB-', @InvoiceID, '-', LEFT(CONVERT(VARCHAR(36), NEWID()), 8)), @InvoiceID, @BankAccountID);
        DECLARE @new VARCHAR(14) = CASE WHEN @paid + @Amount >= @total THEN 'Paid' ELSE 'Partially paid' END;
        UPDATE INVOICE SET Status = @new WHERE InvoiceID = @InvoiceID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('INVOICE', @InvoiceID, 'Payment', @old, @new, CONCAT(N'Ποσό ', @Amount), @UserID);
        COMMIT;
        SELECT @new AS NewStatus, @total - @paid - @Amount AS Remaining;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- CON-2. Μετρήσεις και ιστορικό (ΙΙΙ.1.2)   THROW 51100-51199
-- Διαβάζει ΜΟΝΟ VALIDATED_READING / METER_AGGREGATE (συμφωνία X6) και γράφει μόνο
-- στο SERVICE_PURCHASE / INVOICE / AUDIT_LOG (αγορά ιστορικού).
-- Απόφαση B2: Value = ενέργεια 15λέπτου για αθροιστικούς κωδικούς (1.8.0, 2.8.0),
-- μετρούμενη τιμή για στιγμιαίους (32.7.0).
-- Κανόνες: ο τρέχων μήνας είναι δωρεάν· παλιότεροι μήνες θέλουν αγορασμένη υπηρεσία
-- (SERVICE_PURCHASE) ΚΑΙ να είναι μέσα στο RawRetentionMonths (μετρώντας από τον τρέχοντα μήνα).
-- Τα ημερήσια/μηνιαία/ετήσια αθροίσματα (METER_AGGREGATE) μένουν για πάντα, αλλά ΙΔΙΟΙ κανόνες πρόσβασης
-- (spec III.1.2: τα aggregates «δεν μεταβάλλουν τους κανόνες πρόσβασης»): ο τρέχων μήνας δωρεάν, κάθε
-- προηγούμενος μήνας μόνο με αγορά ιστορικού για το υποστατικό. Η ίδια αγορά ανοίγει και τα 15λεπτα και τα αθροίσματα.
-- Λάθη: 51100 ξένος μετρητής, 51101 ξένο υποστατικό, 51102 μη έγκυρο διάστημα,
--   51103 εκτός περιόδου εγκατάστασης, 51104 διάστημα > 31 ημέρες, 51105 μήνας χωρίς αγορά,
--   51106 μήνας εκτός διατήρησης, 51107 μη έγκυρη περίοδος, 51108 τρέχων/μελλοντικός μήνας στην αγορά,
--   51109 μη έγκυροι μήνες, 51110 επικάλυψη αγοράς, 51111 αγορά εκτός διατήρησης, 51112 δεν υπάρχει υπηρεσία,
--   51113 αγορά για μήνες πριν αρχίσετε να κρατάτε το υποστατικό.
-- Απόφαση B18: ο καταναλωτής βλέπει ΜΟΝΟ την περίοδο που κρατά το υποστατικό (HOLDING.StartDate και μετά).
-- Ένας νέος ένοικος δεν βλέπει τις μετρήσεις/αθροίσματα του προηγούμενου, ούτε αγοράζει ιστορικό του.
-- =====================================================================

-- Μετρητές που ο χρήστης μπορεί να δει: επιβεβαιωμένες εγκαταστάσεις σε υποστατικά που κρατά ΣΗΜΕΡΑ,
-- μαζί με τις παλιές (αντικατεστημένος μετρητής: το ιστορικό του μένει ορατό).
CREATE OR ALTER FUNCTION fn_consumer_meters (@UserID INT)
RETURNS TABLE
AS
RETURN (
    SELECT mi.MeterID, mi.PremiseID, mi.InstalledAt, mi.RemovedAt
    FROM METER_INSTALLATION mi
    WHERE mi.ConfirmationStatus = 'Confirmed'
      AND EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, mi.PremiseID))
);
GO

-- Σειρά 15λέπτου ενός μετρητή: [@From, @To) (το @To δεν περιλαμβάνεται), το πολύ 31 ημέρες.
-- Μία γραμμή ανά διάστημα: εισαγωγή (1.8.0), εξαγωγή (2.8.0, NULL αν δεν υπάρχει), τάση L1 (32.7.0, NULL αν δεν υπάρχει).
-- Quality = η χειρότερη των ενεργειακών τιμών: Estimated > Edited > Validated.
CREATE OR ALTER PROCEDURE sp_consumer_readings
    @UserID INT, @MeterID INT, @From DATETIME2, @To DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    IF @From IS NULL OR @To IS NULL OR @From >= @To
        THROW 51102, N'Μη έγκυρο διάστημα: η αρχή πρέπει να είναι πριν το τέλος.', 1;
    IF DATEDIFF(DAY, @From, @To) > 31
        THROW 51104, N'Το διάστημα μπορεί να είναι το πολύ 31 ημέρες.', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_meters(@UserID) WHERE MeterID = @MeterID)
        THROW 51100, N'Ο μετρητής δεν ανήκει σε υποστατικό σας.', 1;
    DECLARE @prem INT;
    SELECT TOP 1 @prem = PremiseID FROM fn_consumer_meters(@UserID)
    WHERE MeterID = @MeterID AND InstalledAt <= @From AND (RemovedAt IS NULL OR RemovedAt >= @To)
    ORDER BY InstalledAt DESC;
    IF @prem IS NULL
        THROW 51103, N'Το διάστημα δεν βρίσκεται μέσα στην περίοδο εγκατάστασης του μετρητή.', 1;

    -- B18: τίποτα πριν από την ημέρα που ο χρήστης άρχισε να κρατά το υποστατικό (το διάστημα κόβεται εκεί).
    DECLARE @hs DATE = (SELECT MIN(StartDate) FROM HOLDING
                        WHERE UserID = @UserID AND PremiseID = @prem
                          AND StartDate <= CAST(SYSUTCDATETIME() AS DATE)
                          AND (EndDate IS NULL OR EndDate >= CAST(SYSUTCDATETIME() AS DATE)));
    IF @hs IS NOT NULL AND @From < CAST(@hs AS DATETIME2) SET @From = CAST(@hs AS DATETIME2);
    IF @From >= @To
    BEGIN
        SELECT CAST(NULL AS DATETIME2(0)) AS IntervalStart, CAST(NULL AS DECIMAL(15,4)) AS ImportKWh,
               CAST(NULL AS DECIMAL(15,4)) AS ExportKWh, CAST(NULL AS DECIMAL(15,4)) AS VoltageL1,
               CAST(NULL AS VARCHAR(9)) AS Quality
        WHERE 1 = 0;
        RETURN;
    END;

    DECLARE @cur DATE = DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1);
    DECLARE @ret INT = (SELECT RawRetentionMonths FROM USER_ACCOUNT WHERE UserID = @UserID);
    DECLARE @cutoff DATE = DATEADD(MONTH, -@ret, @cur);
    DECLARE @lastInst DATETIME2 = DATEADD(MICROSECOND, -1, @To);
    DECLARE @m1 DATE = DATEFROMPARTS(YEAR(@From), MONTH(@From), 1);
    DECLARE @m2 DATE = DATEFROMPARTS(YEAR(@lastInst), MONTH(@lastInst), 1);
    DECLARE @bad DATE, @msg NVARCHAR(400);

    -- Μήνας πιο παλιός από τη διατήρηση: δεν αγοράζεται, δεν υπάρχει πια.
    SELECT TOP 1 @bad = x.m FROM (SELECT DATEADD(MONTH, [value], @m1) AS m
                                  FROM GENERATE_SERIES(0, DATEDIFF(MONTH, @m1, @m2))) x
    WHERE x.m < @cutoff ORDER BY x.m;
    IF @bad IS NOT NULL
        BEGIN SET @msg = CONCAT(N'Ο μήνας ', CONVERT(NVARCHAR(7), @bad, 23), N' είναι εκτός της περιόδου διατήρησης (', @ret, N' μήνες)· τα αναλυτικά δεδομένα του δεν υπάρχουν πια.'); THROW 51106, @msg, 1; END;

    SELECT TOP 1 @bad = x.m FROM (SELECT DATEADD(MONTH, [value], @m1) AS m
                                  FROM GENERATE_SERIES(0, DATEDIFF(MONTH, @m1, @m2))) x
    WHERE x.m < @cur
      AND NOT EXISTS (SELECT 1 FROM SERVICE_PURCHASE sp
                      WHERE sp.PremiseID = @prem AND sp.ServiceTypeID = 1
                        AND sp.MonthFrom <= x.m AND sp.MonthTo >= x.m)
    ORDER BY x.m;
    IF @bad IS NOT NULL
        BEGIN SET @msg = CONCAT(N'Για τον μήνα ', CONVERT(NVARCHAR(7), @bad, 23), N' πρέπει να αγοράσετε πρόσβαση στο ιστορικό (υπηρεσία ανά μήνα).'); THROW 51105, @msg, 1; END;

    SELECT vr.IntervalStart,
           MAX(CASE WHEN vr.ObisCode = '1.8.0'  THEN vr.Value END) AS ImportKWh,
           MAX(CASE WHEN vr.ObisCode = '2.8.0'  THEN vr.Value END) AS ExportKWh,
           MAX(CASE WHEN vr.ObisCode = '32.7.0' THEN vr.Value END) AS VoltageL1,
           CASE MAX(CASE WHEN vr.ObisCode IN ('1.8.0', '2.8.0')
                         THEN CASE vr.Quality WHEN 'Estimated' THEN 3 WHEN 'Edited' THEN 2 ELSE 1 END END)
                WHEN 3 THEN 'Estimated' WHEN 2 THEN 'Edited' ELSE 'Validated' END AS Quality
    FROM VALIDATED_READING vr
    WHERE vr.MeterID = @MeterID AND vr.ObisCode IN ('1.8.0', '2.8.0', '32.7.0')
      AND vr.IntervalStart >= @From AND vr.IntervalStart < @To
    GROUP BY vr.IntervalStart
    ORDER BY vr.IntervalStart;
END;
GO

-- Ιστορικό από τα αθροίσματα (METER_AGGREGATE): @PeriodType 'Day' | 'Month' | 'Year', @From..@To περιλαμβάνονται.
-- Ίδιοι κανόνες πρόσβασης με τα 15λεπτα: μια γραμμή εμφανίζεται μόνο αν ΚΑΘΕ παρελθοντικός μήνας που καλύπτει
-- (ημέρα -> ο μήνας της, μήνας -> ο ίδιος, έτος -> οι 12 μήνες του) είναι αγορασμένος για το υποστατικό.
-- Ο τρέχων μήνας είναι δωρεάν. Χωρίς όριο διατήρησης (τα αθροίσματα μένουν), αλλά η αγορά γίνεται μόνο εντός διατήρησης.
CREATE OR ALTER PROCEDURE sp_consumer_history
    @UserID INT, @MeterID INT, @PeriodType VARCHAR(5), @From DATE, @To DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Year')
        THROW 51107, N'Διαλέξτε περίοδο: Ημέρα, Μήνας ή Έτος.', 1;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 51102, N'Μη έγκυρο διάστημα: η αρχή πρέπει να είναι πριν το τέλος.', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_meters(@UserID) WHERE MeterID = @MeterID)
        THROW 51100, N'Ο μετρητής δεν ανήκει σε υποστατικό σας.', 1;
    -- B18: μόνο περίοδοι που αρχίζουν από την ημέρα που ο χρήστης κρατά το υποστατικό και μετά
    -- (ένας μήνας/χρόνος που άρχισε πριν δεν δείχνεται, γιατί περιέχει δεδομένα του προηγούμενου κατόχου).
    DECLARE @hs DATE = (SELECT MIN(h.StartDate)
                        FROM HOLDING h JOIN fn_consumer_meters(@UserID) cm ON cm.PremiseID = h.PremiseID AND cm.MeterID = @MeterID
                        WHERE h.UserID = @UserID AND h.StartDate <= CAST(SYSUTCDATETIME() AS DATE)
                          AND (h.EndDate IS NULL OR h.EndDate >= CAST(SYSUTCDATETIME() AS DATE)));
    IF @hs IS NOT NULL AND @From < @hs SET @From = @hs;
    DECLARE @curM DATE = DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1);
    DECLARE @span INT = CASE @PeriodType WHEN 'Year' THEN 11 ELSE 0 END;
    DECLARE @prems TABLE (PremiseID INT PRIMARY KEY);
    INSERT @prems SELECT DISTINCT PremiseID FROM fn_consumer_meters(@UserID) WHERE MeterID = @MeterID;
    SELECT a.PeriodStart,
           ISNULL(SUM(CASE WHEN a.ObisCode = '1.8.0' THEN a.SumValue END), 0) AS ImportKWh,
           ISNULL(SUM(CASE WHEN a.ObisCode = '2.8.0' THEN a.SumValue END), 0) AS ExportKWh,
           ISNULL(SUM(CASE WHEN a.ObisCode = '1.8.0' THEN a.SumValue END), 0)
             - ISNULL(SUM(CASE WHEN a.ObisCode = '2.8.0' THEN a.SumValue END), 0) AS NetKWh,
           SUM(a.EstimatedCount) AS EstimatedCount
    FROM METER_AGGREGATE a
    WHERE a.MeterID = @MeterID AND a.PeriodType = @PeriodType AND a.ObisCode IN ('1.8.0', '2.8.0')
      AND a.PeriodStart >= @From AND a.PeriodStart <= @To
      AND NOT EXISTS (   -- ένας παρελθοντικός μήνας της περιόδου χωρίς αγορά -> η γραμμή κρύβεται
          SELECT 1 FROM GENERATE_SERIES(0, @span) g
          CROSS APPLY (SELECT DATEADD(MONTH, g.[value], DATEFROMPARTS(YEAR(a.PeriodStart), MONTH(a.PeriodStart), 1)) AS m) x
          WHERE x.m < @curM
            AND NOT EXISTS (SELECT 1 FROM SERVICE_PURCHASE sp JOIN @prems p ON p.PremiseID = sp.PremiseID
                            WHERE sp.ServiceTypeID = 1 AND sp.MonthFrom <= x.m AND sp.MonthTo >= x.m))
    GROUP BY a.PeriodStart
    ORDER BY a.PeriodStart;
END;
GO

-- Αγορά πρόσβασης στο ιστορικό 15λέπτου για ένα υποστατικό, για μήνες @MonthFrom..@MonthTo (οποιαδήποτε
-- ημέρα του μήνα· κανονικοποιείται στην 1η). Μόνο παρελθοντικοί μήνες (ο τρέχων είναι δωρεάν),
-- μέσα στη διατήρηση, και χωρίς επικάλυψη με προηγούμενη αγορά του ίδιου υποστατικού.
-- Τιμολόγιο + αγορά + AUDIT_LOG σε μία συναλλαγή.
CREATE OR ALTER PROCEDURE sp_consumer_buy_history
    @UserID INT, @PremiseID INT, @MonthFrom DATE, @MonthTo DATE
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    -- Ρητό isolation level (επιστρέφει αυτόματα στο προηγούμενο όταν τελειώσει η procedure): SERIALIZABLE,
    -- ώστε έλεγχος και εγγραφή να μη χωρίζονται από άλλη συναλλαγή. Τα UPDLOCK/HOLDLOCK μένουν (doc 15, §2).
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    EXEC sp_consumer_assert @UserID;
    IF @MonthFrom IS NULL OR @MonthTo IS NULL
        THROW 51109, N'Δώστε μήνα έναρξης και λήξης.', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))
        THROW 51101, N'Δεν κρατάτε αυτό το υποστατικό.', 1;
    SET @MonthFrom = DATEFROMPARTS(YEAR(@MonthFrom), MONTH(@MonthFrom), 1);
    SET @MonthTo = DATEFROMPARTS(YEAR(@MonthTo), MONTH(@MonthTo), 1);
    IF @MonthFrom > @MonthTo
        THROW 51109, N'Ο μήνας έναρξης είναι μετά τον μήνα λήξης.', 1;
    DECLARE @cur DATE = DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1);
    DECLARE @ret INT = (SELECT RawRetentionMonths FROM USER_ACCOUNT WHERE UserID = @UserID);
    DECLARE @msg NVARCHAR(400);
    IF @MonthTo >= @cur
        THROW 51108, N'Αγοράζονται μόνο προηγούμενοι μήνες· ο τρέχων μήνας είναι δωρεάν και οι μελλοντικοί δεν υπάρχουν.', 1;
    IF @MonthFrom < DATEADD(MONTH, -@ret, @cur)
        BEGIN SET @msg = CONCAT(N'Ο μήνας ', CONVERT(NVARCHAR(7), @MonthFrom, 23), N' είναι εκτός της περιόδου διατήρησης (', @ret, N' μήνες).'); THROW 51111, @msg, 1; END;
    DECLARE @hs DATE = (SELECT MIN(StartDate) FROM HOLDING
                        WHERE UserID = @UserID AND PremiseID = @PremiseID
                          AND StartDate <= CAST(SYSUTCDATETIME() AS DATE)
                          AND (EndDate IS NULL OR EndDate >= CAST(SYSUTCDATETIME() AS DATE)));
    IF @MonthFrom < DATEFROMPARTS(YEAR(@hs), MONTH(@hs), 1)
        BEGIN SET @msg = CONCAT(N'Κρατάτε το υποστατικό από ', CONVERT(NVARCHAR(10), @hs, 23), N'· δεν αγοράζεται ιστορικό προηγούμενου κατόχου.'); THROW 51113, @msg, 1; END;
    DECLARE @fee DECIMAL(10,2) = (SELECT Fee FROM SERVICE_TYPE WHERE ServiceTypeID = 1);
    IF @fee IS NULL
        THROW 51112, N'Η υπηρεσία ιστορικού δεν είναι διαθέσιμη.', 1;
    DECLARE @months INT = DATEDIFF(MONTH, @MonthFrom, @MonthTo) + 1;
    DECLARE @amount DECIMAL(10,2) = @months * @fee;
    BEGIN TRY
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM SERVICE_PURCHASE WITH (UPDLOCK, HOLDLOCK)
                   WHERE PremiseID = @PremiseID AND ServiceTypeID = 1
                     AND MonthFrom <= @MonthTo AND MonthTo >= @MonthFrom)
            THROW 51110, N'Έχετε ήδη αγοράσει ένα ή περισσότερους από αυτούς τους μήνες για το υποστατικό.', 1;
        DECLARE @contract INT = (SELECT TOP 1 ContractID FROM SUPPLY_CONTRACT
                                 WHERE PremiseID = @PremiseID AND UserID = @UserID AND EndDate IS NULL
                                 ORDER BY StartDate DESC);
        INSERT INVOICE (IssueDate, PeriodFrom, PeriodTo, Amount, Status, UserID, ContractID)
        VALUES (CAST(SYSUTCDATETIME() AS DATE), @MonthFrom, EOMONTH(@MonthTo), @amount, 'Issued', @UserID, @contract);
        DECLARE @inv INT = SCOPE_IDENTITY();
        INSERT SERVICE_PURCHASE (MonthFrom, MonthTo, Amount, ServiceTypeID, PremiseID, InvoiceID)
        VALUES (@MonthFrom, @MonthTo, @amount, 1, @PremiseID, @inv);
        DECLARE @pur INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, ResultComment, PerformedBy)
        VALUES ('SERVICE_PURCHASE', @pur, 'Buy history',
                CONCAT(CONVERT(VARCHAR(7), @MonthFrom, 23), '..', CONVERT(VARCHAR(7), @MonthTo, 23)),
                CONCAT(N'Υποστατικό ', @PremiseID, N', τιμολόγιο ', @inv, N', ποσό ', @amount), @UserID);
        COMMIT;
        SELECT @pur AS PurchaseID, @inv AS InvoiceID, @amount AS Amount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Οι αγορές ιστορικού μου, με διεύθυνση και κατάσταση τιμολογίου.
CREATE OR ALTER PROCEDURE sp_consumer_list_purchases
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT sp.PurchaseID, sp.PurchasedAt, p.Address, sp.MonthFrom, sp.MonthTo, sp.Amount, sp.InvoiceID,
           CASE i.Status WHEN 'Issued' THEN N'Εκδόθηκε' WHEN 'Partially paid' THEN N'Μερικώς πληρωμένο'
                         WHEN 'Paid' THEN N'Εξοφλήθηκε' ELSE N'Ακυρώθηκε' END AS InvoiceStatus
    FROM SERVICE_PURCHASE sp
    JOIN INVOICE i ON i.InvoiceID = sp.InvoiceID
    JOIN PREMISE p ON p.PremiseID = sp.PremiseID
    WHERE i.UserID = @UserID
    ORDER BY sp.PurchasedAt DESC, sp.PurchaseID DESC;
END;
GO

-- =====================================================================
-- CON-3. Όρια κατανάλωσης, κανάλια ειδοποίησης, συμβάντα ποιότητας (ΙΙΙ.1.2)
--   Λάθη 51200-51299:
--   51200 υποστατικό που δεν κρατάτε, 51201 μη έγκυρη περίοδος, 51202 όριο <= 0, 51203 όριο που δεν είναι δικό σας,
--   51204 υπάρχει ήδη ενεργό όριο για το ίδιο υποστατικό και περίοδο, 51205 το όριο έχει ήδη αφαιρεθεί,
--   51206 μη έγκυρα κανάλια, 51207 το SMS θέλει τηλέφωνο, 51208 μη έγκυρο διάστημα.
-- Η αποστολή email/SMS γίνεται ΕΞΩ από τη βάση (απόφαση B19): η βάση υπολογίζει μόνο αν το όριο ξεπεράστηκε.
-- Διαβάζουμε μόνο VALIDATED_READING και EVENT (X6).
-- =====================================================================

-- Δημιουργία/αλλαγή ορίου. Ένα ΕΝΕΡΓΟ όριο ανά υποστατικό + περίοδο (Day/Month):
--  * χωρίς @ThresholdID: αν υπάρχει ήδη ενεργό για αυτό το ζεύγος, ενημερώνεται (όχι διπλό)· αλλιώς δημιουργείται.
--  * με @ThresholdID: αλλάζει το δικό σας όριο (και το ενεργοποιεί ξανά αν είχε αφαιρεθεί)·
--    51204 αν άλλο ενεργό όριο έχει ήδη το ίδιο υποστατικό + περίοδο.
CREATE OR ALTER PROCEDURE sp_consumer_set_threshold
    @UserID INT, @PremiseID INT, @PeriodType VARCHAR(5), @LimitKWh DECIMAL(12,3), @ThresholdID INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, @PremiseID))
        THROW 51200, N'Το υποστατικό δεν είναι δικό σας.', 1;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month')
        THROW 51201, N'Διαλέξτε περίοδο ορίου: Ημέρα ή Μήνας.', 1;
    IF @LimitKWh IS NULL OR @LimitKWh <= 0
        THROW 51202, N'Το όριο πρέπει να είναι μεγαλύτερο από 0 kWh.', 1;
    IF @ThresholdID IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE ThresholdID = @ThresholdID AND UserID = @UserID)
        THROW 51203, N'Το όριο δεν είναι δικό σας.', 1;
    IF @ThresholdID IS NOT NULL
       AND EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD
                   WHERE UserID = @UserID AND PremiseID = @PremiseID AND PeriodType = @PeriodType
                     AND IsActive = 1 AND ThresholdID <> @ThresholdID)
        THROW 51204, N'Υπάρχει ήδη ενεργό όριο για αυτό το υποστατικό και την ίδια περίοδο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old NVARCHAR(400) = NULL, @act VARCHAR(50);
        IF @ThresholdID IS NULL
            SELECT @ThresholdID = ThresholdID FROM CONSUMPTION_THRESHOLD WITH (UPDLOCK)
            WHERE UserID = @UserID AND PremiseID = @PremiseID AND PeriodType = @PeriodType AND IsActive = 1;
        IF @ThresholdID IS NULL
        BEGIN
            INSERT CONSUMPTION_THRESHOLD (LimitKWh, PeriodType, IsActive, UserID, PremiseID)
            VALUES (@LimitKWh, @PeriodType, 1, @UserID, @PremiseID);
            SET @ThresholdID = SCOPE_IDENTITY();
            SET @act = 'Create threshold';
        END
        ELSE
        BEGIN
            SELECT @old = CONCAT(PeriodType, N' ', LimitKWh, N' kWh, premise ', PremiseID, N', active ', IsActive)
            FROM CONSUMPTION_THRESHOLD WITH (UPDLOCK) WHERE ThresholdID = @ThresholdID;
            UPDATE CONSUMPTION_THRESHOLD
            SET LimitKWh = @LimitKWh, PeriodType = @PeriodType, PremiseID = @PremiseID, IsActive = 1
            WHERE ThresholdID = @ThresholdID;
            SET @act = 'Update threshold';
        END
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('CONSUMPTION_THRESHOLD', CAST(@ThresholdID AS VARCHAR(100)), @act, @old,
                CONCAT(@PeriodType, N' ', @LimitKWh, N' kWh, premise ', @PremiseID, N', active 1'), @UserID);
        COMMIT;
        SELECT @ThresholdID AS ThresholdID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Αφαίρεση ορίου (IsActive = 0, η γραμμή μένει για το ιστορικό).
CREATE OR ALTER PROCEDURE sp_consumer_remove_threshold
    @UserID INT, @ThresholdID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE ThresholdID = @ThresholdID AND UserID = @UserID)
        THROW 51203, N'Το όριο δεν είναι δικό σας.', 1;
    IF EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE ThresholdID = @ThresholdID AND IsActive = 0)
        THROW 51205, N'Το όριο έχει ήδη αφαιρεθεί.', 1;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE CONSUMPTION_THRESHOLD SET IsActive = 0 WHERE ThresholdID = @ThresholdID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('CONSUMPTION_THRESHOLD', CAST(@ThresholdID AS VARCHAR(100)), 'Remove threshold', N'active 1', N'active 0', @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Τα ενεργά όρια μου με τρέχουσα κατανάλωση της περιόδου (σήμερα / τρέχων μήνας, UTC):
-- άθροισμα των επικυρωμένων 1.8.0 όλων των μετρητών του υποστατικού. Exceeded = 1 όταν CurrentKWh > LimitKWh.
-- Η ειδοποίηση υπολογίζεται εδώ κατά την ανάγνωση· η αποστολή email/SMS γίνεται εκτός βάσης.
CREATE OR ALTER PROCEDURE sp_consumer_list_thresholds
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    DECLARE @today DATETIME2(0) = CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0));
    DECLARE @tomorrow DATETIME2(0) = DATEADD(DAY, 1, @today);
    DECLARE @monthStart DATETIME2(0) = DATEADD(DAY, 1 - DAY(@today), @today);
    DECLARE @nextMonth DATETIME2(0) = DATEADD(MONTH, 1, @monthStart);
    SELECT t.ThresholdID, t.PremiseID, p.Address, t.PeriodType, t.LimitKWh,
           ISNULL(c.KWh, 0) AS CurrentKWh,
           CAST(CASE WHEN ISNULL(c.KWh, 0) > t.LimitKWh THEN 1 ELSE 0 END AS BIT) AS Exceeded
    FROM CONSUMPTION_THRESHOLD t
    JOIN PREMISE p ON p.PremiseID = t.PremiseID
    OUTER APPLY (
        SELECT SUM(vr.Value) AS KWh
        FROM VALIDATED_READING vr
        WHERE vr.ObisCode = '1.8.0'
          AND vr.MeterID IN (SELECT mi.MeterID FROM METER_INSTALLATION mi
                             WHERE mi.PremiseID = t.PremiseID AND mi.ConfirmationStatus = 'Confirmed')
          AND vr.IntervalStart >= CASE WHEN t.PeriodType = 'Day' THEN @today ELSE @monthStart END
          AND vr.IntervalStart <  CASE WHEN t.PeriodType = 'Day' THEN @tomorrow ELSE @nextMonth END
    ) c
    WHERE t.UserID = @UserID AND t.IsActive = 1
      AND EXISTS (SELECT 1 FROM fn_consumer_holds(@UserID, t.PremiseID))
    ORDER BY t.PremiseID, t.PeriodType;
END;
GO

-- Κανάλια ειδοποίησης: 'Email', 'SMS' ή 'Email,SMS' (τουλάχιστον ένα). Το SMS θέλει τηλέφωνο στο προφίλ.
-- Αντικαθιστά το σύνολο των καναλιών.
CREATE OR ALTER PROCEDURE sp_consumer_set_channels
    @UserID INT, @Channels VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_consumer_assert @UserID;
    DECLARE @want TABLE (Channel VARCHAR(5) PRIMARY KEY);
    INSERT @want (Channel)
    SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(ISNULL(@Channels, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF NOT EXISTS (SELECT 1 FROM @want) OR EXISTS (SELECT 1 FROM @want WHERE Channel NOT IN ('Email', 'SMS'))
        THROW 51206, N'Διαλέξτε κανάλια: Email, SMS ή και τα δύο.', 1;
    IF EXISTS (SELECT 1 FROM @want WHERE Channel = 'SMS')
       AND NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Phone IS NOT NULL AND LTRIM(RTRIM(Phone)) <> '')
        THROW 51207, N'Για ειδοποιήσεις SMS χρειάζεται τηλέφωνο στο προφίλ σας.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old NVARCHAR(400) = (SELECT STRING_AGG(NotificationChannel, ',') WITHIN GROUP (ORDER BY NotificationChannel)
                                      FROM CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @UserID);
        DECLARE @new NVARCHAR(400) = (SELECT STRING_AGG(Channel, ',') WITHIN GROUP (ORDER BY Channel) FROM @want);
        DELETE FROM CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @UserID;
        INSERT CONSUMER_NOTIFICATION_CHANNEL (UserID, NotificationChannel) SELECT @UserID, Channel FROM @want;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('CONSUMER_NOTIFICATION_CHANNEL', CAST(@UserID AS VARCHAR(100)), 'Set channels', @old, @new, @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Τα κανάλια μου (βοηθητικό για τη σελίδα): μία γραμμή ανά κανάλι.
CREATE OR ALTER PROCEDURE sp_consumer_list_channels
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    SELECT NotificationChannel FROM CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @UserID ORDER BY NotificationChannel;
END;
GO

-- Συμβάντα (EVENT) στους μετρητές μου, νεότερα πρώτα. Διάστημα [@From, @To) προαιρετικό (UTC).
-- Δείχνει μόνο μετρητές των υποστατικών που κρατώ (fn_consumer_meters).
CREATE OR ALTER PROCEDURE sp_consumer_quality_events
    @UserID INT, @From DATETIME2 = NULL, @To DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_consumer_assert @UserID;
    IF @From IS NOT NULL AND @To IS NOT NULL AND @From >= @To
        THROW 51208, N'Μη έγκυρο διάστημα: η αρχή πρέπει να είναι πριν το τέλος.', 1;
    SELECT e.EventID, e.EventType, e.Severity, e.Description, e.OccurredAt, e.Status,
           e.MeterID, me.SerialNumber, p.PremiseID, p.Address
    FROM EVENT e
    JOIN METER me ON me.MeterID = e.MeterID
    JOIN PREMISE p ON p.PremiseID = (SELECT MIN(f.PremiseID) FROM fn_consumer_meters(@UserID) f WHERE f.MeterID = e.MeterID)
    WHERE (@From IS NULL OR e.OccurredAt >= @From)
      AND (@To IS NULL OR e.OccurredAt < @To)
    ORDER BY e.OccurredAt DESC, e.EventID DESC;
END;
GO
