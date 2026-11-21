-- =====================================================================
-- procs_consumer.sql : ΙΙΙ.1 Καταναλωτές (περιοχή CON)
--   CON-1 υποστατικά + τραπεζικοί λογαριασμοί
--   CON-4 αιτήματα ελέγχου/βλάβης
--   CON-5 τιμολόγια, πληρωμές, εξόφληση
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
-- Τα ημερήσια/μηνιαία/ετήσια αθροίσματα (METER_AGGREGATE) μένουν για πάντα και είναι δωρεάν:
-- η αγορά αφορά μόνο τη σειρά των 15 λεπτών.
-- Λάθη: 51100 ξένος μετρητής, 51101 ξένο υποστατικό, 51102 μη έγκυρο διάστημα,
--   51103 εκτός περιόδου εγκατάστασης, 51104 διάστημα > 31 ημέρες, 51105 μήνας χωρίς αγορά,
--   51106 μήνας εκτός διατήρησης, 51107 μη έγκυρη περίοδος, 51108 τρέχων/μελλοντικός μήνας στην αγορά,
--   51109 μη έγκυροι μήνες, 51110 επικάλυψη αγοράς, 51111 αγορά εκτός διατήρησης, 51112 δεν υπάρχει υπηρεσία.
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
-- Δωρεάν και χωρίς όριο διατήρησης (τα αθροίσματα μένουν για πάντα).
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
    SELECT a.PeriodStart,
           ISNULL(SUM(CASE WHEN a.ObisCode = '1.8.0' THEN a.SumValue END), 0) AS ImportKWh,
           ISNULL(SUM(CASE WHEN a.ObisCode = '2.8.0' THEN a.SumValue END), 0) AS ExportKWh,
           ISNULL(SUM(CASE WHEN a.ObisCode = '1.8.0' THEN a.SumValue END), 0)
             - ISNULL(SUM(CASE WHEN a.ObisCode = '2.8.0' THEN a.SumValue END), 0) AS NetKWh,
           SUM(a.EstimatedCount) AS EstimatedCount
    FROM METER_AGGREGATE a
    WHERE a.MeterID = @MeterID AND a.PeriodType = @PeriodType AND a.ObisCode IN ('1.8.0', '2.8.0')
      AND a.PeriodStart >= @From AND a.PeriodStart <= @To
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
