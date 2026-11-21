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
CREATE OR ALTER FUNCTION fn_consumer_holds (@UserID INT, @PremiseID INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (
        SELECT 1 FROM HOLDING
        WHERE UserID = @UserID AND PremiseID = @PremiseID
          AND StartDate <= CAST(SYSUTCDATETIME() AS DATE)
          AND (EndDate IS NULL OR EndDate >= CAST(SYSUTCDATETIME() AS DATE))
    ) THEN 1 ELSE 0 END;
END;
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
    IF dbo.fn_consumer_holds(@UserID, @PremiseID) = 0
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
    IF @PremiseID IS NOT NULL AND dbo.fn_consumer_holds(@UserID, @PremiseID) = 0
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
      AND dbo.fn_consumer_holds(@UserID, p.PremiseID) = 1
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
    IF dbo.fn_consumer_holds(@UserID, @PremiseID) = 0
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
