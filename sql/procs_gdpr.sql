-- =====================================================================
-- procs_gdpr.sql : ΙΙΙ.1.4 Δικαίωμα λήθης (περιοχή GDP, GDP-1)
-- Ροή: ο καταναλωτής υποβάλλει -> ο Operator εξετάζει / προεγκρίνει (ή απορρίπτει)
--      -> ο Admin αποφασίζει (εγκρίνει ή απορρίπτει) -> εφαρμογή (ανωνυμοποίηση).
-- Κάθε στάδιο γράφεται στο AUDIT_LOG (παλιά και νέα κατάσταση). Λάθη: 51400-51499.
-- Τρέχει μετά το procs_common.sql (αλφαβητικά μετά το procs_consumer.sql).
--
-- Κατάσταση (GDPR_REQUEST.Status):
--   Submitted -> Under review (προαιρετικό) -> Pre-approved -> Approved -> Applied
--   Submitted / Under review -> Rejected   (απόρριψη από Operator)
--   Pre-approved -> Rejected               (απόρριψη από Admin)
-- Επιλογές για τα CHECK του πίνακα:
--   * CK_GDPR_REQUEST_Stage: η Rejected θέλει PreApprovedAt. Όταν ο Operator απορρίπτει,
--     γράφουμε PreApprovedBy/PreApprovedAt ως «σφραγίδα εξέτασης» (ποιος και πότε εξέτασε).
--     Το Status = 'Rejected' (όχι Pre-approved) λέει ότι ήταν απόρριψη.
--   * Ο Admin αποφασίζει πάντα στη στήλη DecidedByAdmin (DecidedBy μένει NULL),
--     ώστε να ισχύει το CK_GDPR_REQUEST_OneFinal.
--   * Το σχόλιο του Operator/Admin δεν έχει στήλη: γράφεται στο AUDIT_LOG.ResultComment.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: ο χρήστης πρέπει να είναι ενεργός με τον ζητούμενο ρόλο.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_assert_role
    @UserID INT, @Role VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = @Role AND AccountStatus = 'Active')
    BEGIN
        IF @Role = 'Consumer' THROW 51400, N'Δεν επιτρέπεται: μόνο ενεργός Καταναλωτής μπορεί να υποβάλει αίτημα διαγραφής.', 1;
        IF @Role = 'Operator' THROW 51401, N'Δεν επιτρέπεται: μόνο ο Operator κάνει την προέγκριση.', 1;
        THROW 51402, N'Δεν επιτρέπεται: μόνο ο Admin αποφασίζει και εφαρμόζει.', 1;
    END
END;
GO

-- ---------------------------------------------------------------------
-- 1. Υποβολή αιτήματος. Επιστρέφει GdprRequestID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_submit
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Consumer';
    BEGIN TRY
        BEGIN TRAN;
        -- κλειδώνουμε τη γραμμή του χρήστη ώστε δύο ταυτόχρονες υποβολές να περάσουν η μία μετά την άλλη
        DECLARE @lock INT;
        SELECT @lock = UserID FROM USER_ACCOUNT WITH (UPDLOCK, HOLDLOCK) WHERE UserID = @UserID;
        IF EXISTS (SELECT 1 FROM GDPR_REQUEST
                   WHERE ConsumerID = @UserID AND Status IN ('Submitted', 'Under review', 'Pre-approved', 'Approved'))
            THROW 51403, N'Έχετε ήδη ανοιχτό αίτημα διαγραφής.', 1;
        INSERT GDPR_REQUEST (SubmittedAt, Status, ConsumerID)
        VALUES (CAST(SYSUTCDATETIME() AS DATETIME2(0)), 'Submitted', @UserID);
        DECLARE @id INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('GDPR_REQUEST', @id, 'Submit', NULL, 'Submitted', @UserID);
        COMMIT;
        SELECT @id AS GdprRequestID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- 2. Λίστα. Καταναλωτής: μόνο τα δικά του. Operator / Admin: όλα.
--    @Status = NULL σημαίνει όλες οι καταστάσεις.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_list
    @UserID INT, @Status VARCHAR(12) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role VARCHAR(10);
    SELECT @role = Role FROM USER_ACCOUNT WHERE UserID = @UserID AND AccountStatus = 'Active';
    IF @role IS NULL OR @role NOT IN ('Consumer', 'Operator', 'Admin')
        THROW 51404, N'Δεν επιτρέπεται: μόνο Καταναλωτής, Operator ή Admin βλέπουν αιτήματα διαγραφής.', 1;
    IF @Status IS NOT NULL AND @Status NOT IN ('Submitted', 'Under review', 'Pre-approved', 'Approved', 'Rejected', 'Applied')
        THROW 51405, N'Μη έγκυρη κατάσταση αιτήματος.', 1;
    SELECT g.GdprRequestID, g.SubmittedAt, g.Status, g.PreApprovedAt, g.DecidedAt, g.AppliedAt,
           g.ConsumerID, c.Username, c.FirstName, c.LastName,
           g.PreApprovedBy, pa.Username AS PreApprovedByUsername,
           COALESCE(g.DecidedByAdmin, g.DecidedBy) AS DecidedBy, de.Username AS DecidedByUsername
    FROM GDPR_REQUEST g
    JOIN USER_ACCOUNT c ON c.UserID = g.ConsumerID
    LEFT JOIN USER_ACCOUNT pa ON pa.UserID = g.PreApprovedBy
    LEFT JOIN USER_ACCOUNT de ON de.UserID = COALESCE(g.DecidedByAdmin, g.DecidedBy)
    WHERE (@role <> 'Consumer' OR g.ConsumerID = @UserID)
      AND (@Status IS NULL OR g.Status = @Status)
    ORDER BY g.SubmittedAt DESC, g.GdprRequestID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- 3a. Operator: ξεκινά την εξέταση (Submitted -> Under review).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_start_review
    @UserID INT, @GdprRequestID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Operator';
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(12);
        SELECT @old = Status FROM GDPR_REQUEST WITH (UPDLOCK, HOLDLOCK) WHERE GdprRequestID = @GdprRequestID;
        IF @old IS NULL THROW 51406, N'Το αίτημα δεν βρέθηκε.', 1;
        IF @old <> 'Submitted' THROW 51407, N'Η εξέταση ξεκινά μόνο από αίτημα σε κατάσταση Submitted.', 1;
        UPDATE GDPR_REQUEST SET Status = 'Under review' WHERE GdprRequestID = @GdprRequestID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('GDPR_REQUEST', @GdprRequestID, 'Start review', @old, 'Under review', @UserID);
        COMMIT;
        SELECT @GdprRequestID AS GdprRequestID, 'Under review' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- 3b. Operator: προέγκριση ή απόρριψη (από Submitted ή Under review).
--     Απόρριψη: Status = Rejected, PreApprovedBy/At = σφραγίδα εξέτασης (βλ. κεφαλίδα).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_preapprove
    @UserID INT, @GdprRequestID INT, @Approve BIT, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Operator';
    IF @Approve IS NULL THROW 51408, N'Διαλέξτε έγκριση ή απόρριψη.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(12);
        SELECT @old = Status FROM GDPR_REQUEST WITH (UPDLOCK, HOLDLOCK) WHERE GdprRequestID = @GdprRequestID;
        IF @old IS NULL THROW 51406, N'Το αίτημα δεν βρέθηκε.', 1;
        IF @old NOT IN ('Submitted', 'Under review')
            THROW 51409, N'Προέγκριση ή απόρριψη γίνεται μόνο σε αίτημα Submitted ή Under review.', 1;
        DECLARE @new VARCHAR(12) = CASE WHEN @Approve = 1 THEN 'Pre-approved' ELSE 'Rejected' END;
        DECLARE @now DATETIME2(0) = CAST(SYSUTCDATETIME() AS DATETIME2(0));
        UPDATE GDPR_REQUEST
        SET Status = @new, PreApprovedBy = @UserID,
            PreApprovedAt = CASE WHEN @now >= SubmittedAt THEN @now ELSE SubmittedAt END
        WHERE GdprRequestID = @GdprRequestID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('GDPR_REQUEST', @GdprRequestID, CASE WHEN @Approve = 1 THEN 'Pre-approve' ELSE 'Operator reject' END,
                @old, @new, @Comment, @UserID);
        COMMIT;
        SELECT @GdprRequestID AS GdprRequestID, @new AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- 4. Admin: τελική απόφαση (μόνο από Pre-approved). Στήλη DecidedByAdmin.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_decide
    @UserID INT, @GdprRequestID INT, @Approve BIT, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Admin';
    IF @Approve IS NULL THROW 51408, N'Διαλέξτε έγκριση ή απόρριψη.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(12);
        SELECT @old = Status FROM GDPR_REQUEST WITH (UPDLOCK, HOLDLOCK) WHERE GdprRequestID = @GdprRequestID;
        IF @old IS NULL THROW 51406, N'Το αίτημα δεν βρέθηκε.', 1;
        IF @old <> 'Pre-approved'
            THROW 51410, N'Ο Admin αποφασίζει μόνο για αίτημα που έχει προεγκριθεί από Operator.', 1;
        DECLARE @new VARCHAR(12) = CASE WHEN @Approve = 1 THEN 'Approved' ELSE 'Rejected' END;
        DECLARE @now DATETIME2(0) = CAST(SYSUTCDATETIME() AS DATETIME2(0));
        UPDATE GDPR_REQUEST
        SET Status = @new, DecidedByAdmin = @UserID, DecidedBy = NULL,
            DecidedAt = CASE WHEN @now >= PreApprovedAt THEN @now ELSE PreApprovedAt END
        WHERE GdprRequestID = @GdprRequestID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('GDPR_REQUEST', @GdprRequestID, CASE WHEN @Approve = 1 THEN 'Decide approve' ELSE 'Decide reject' END,
                @old, @new, @Comment, @UserID);
        COMMIT;
        SELECT @GdprRequestID AS GdprRequestID, @new AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- 5. Admin: εφαρμογή (μόνο από Approved). Ανωνυμοποίηση σε ΕΝΑ transaction.
--    ΔΙΑΓΡΑΦΟΝΤΑΙ/ΑΝΩΝΥΜΟΠΟΙΟΥΝΤΑΙ: στοιχεία USER_ACCOUNT, κανάλια ειδοποίησης,
--      όρια κατανάλωσης (απενεργοποίηση), τραπεζικοί λογαριασμοί + ACCOUNT_FOR.
--    ΜΕΝΟΥΝ: INVOICE, PAYMENT (με BankAccountID = NULL), HOLDING, SUPPLY_CONTRACT, μετρήσεις/aggregates.
--    RawRetentionMonths = 1: τις ωμές μετρήσεις > 1 μήνα τις σβήνει αργότερα η εργασία διατήρησης (GDP-2).
--    Το AUDIT_LOG παίρνει μόνο αριθμούς και IDs, ποτέ τα προσωπικά δεδομένα.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_apply
    @UserID INT, @GdprRequestID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Admin';
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(12), @cid INT;
        SELECT @old = Status, @cid = ConsumerID FROM GDPR_REQUEST WITH (UPDLOCK, HOLDLOCK) WHERE GdprRequestID = @GdprRequestID;
        IF @old IS NULL THROW 51406, N'Το αίτημα δεν βρέθηκε.', 1;
        IF @old <> 'Approved' THROW 51411, N'Εφαρμογή γίνεται μόνο σε αίτημα που έχει εγκριθεί από τον Admin.', 1;
        IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WITH (UPDLOCK) WHERE UserID = @cid AND Role = 'Consumer')
            THROW 51412, N'Ο χρήστης του αιτήματος δεν είναι Καταναλωτής.', 1;

        DECLARE @anon NVARCHAR(50) = CONCAT(N'deleted_', @cid);
        UPDATE USER_ACCOUNT
        SET Username = @anon, FirstName = N'Διαγραμμένος', LastName = N'Διαγραμμένος',
            Email = CONCAT('deleted', @cid, '@anon.invalid'), Phone = NULL,
            PasswordHash = CONCAT('!ERASED!', CONVERT(VARCHAR(36), NEWID())),   -- δεν είναι έγκυρο hash: κανείς δεν μπαίνει
            AccountStatus = 'Suspended', RawRetentionMonths = 1
        WHERE UserID = @cid;

        DECLARE @nChan INT, @nThr INT, @nPay INT, @nAf INT, @nBank INT;
        DELETE CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @cid;
        SET @nChan = @@ROWCOUNT;
        UPDATE CONSUMPTION_THRESHOLD SET IsActive = 0 WHERE UserID = @cid AND IsActive = 1;
        SET @nThr = @@ROWCOUNT;

        DECLARE @ba TABLE (BankAccountID INT PRIMARY KEY);
        INSERT @ba SELECT BankAccountID FROM BANK_ACCOUNT WHERE UserID = @cid;
        UPDATE PAYMENT SET BankAccountID = NULL WHERE BankAccountID IN (SELECT BankAccountID FROM @ba);
        SET @nPay = @@ROWCOUNT;
        DELETE ACCOUNT_FOR WHERE BankAccountID IN (SELECT BankAccountID FROM @ba);
        SET @nAf = @@ROWCOUNT;
        DELETE BANK_ACCOUNT WHERE BankAccountID IN (SELECT BankAccountID FROM @ba);
        SET @nBank = @@ROWCOUNT;

        DECLARE @now DATETIME2(0) = CAST(SYSUTCDATETIME() AS DATETIME2(0));
        UPDATE GDPR_REQUEST
        SET Status = 'Applied', AppliedAt = CASE WHEN @now >= DecidedAt THEN @now ELSE DecidedAt END
        WHERE GdprRequestID = @GdprRequestID;

        DECLARE @nInv INT = (SELECT COUNT(*) FROM INVOICE WHERE UserID = @cid);
        DECLARE @nPaid INT = (SELECT COUNT(*) FROM PAYMENT p JOIN INVOICE i ON i.InvoiceID = p.InvoiceID WHERE i.UserID = @cid);
        DECLARE @nHold INT = (SELECT COUNT(*) FROM HOLDING WHERE UserID = @cid);

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('GDPR_REQUEST', @GdprRequestID, 'Apply', @old, 'Applied',
                CONCAT(N'Ανωνυμοποίηση χρήστη ', @cid, N': κανάλια ', @nChan, N', όρια ', @nThr,
                       N', πληρωμές χωρίς λογαριασμό ', @nPay, N', τραπ. λογαριασμοί ', @nBank,
                       N'; διατηρούνται τιμολόγια ', @nInv, N', πληρωμές ', @nPaid, N', κατοχές ', @nHold), @UserID);
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('USER_ACCOUNT', @cid, 'GDPR anonymise', NULL, 'Suspended', N'RawRetentionMonths 36 -> 1', @UserID);
        COMMIT;

        SELECT @GdprRequestID AS GdprRequestID, @cid AS ConsumerID, @anon AS AnonymisedUsername,
               @nChan AS ChannelsDeleted, @nThr AS ThresholdsDeactivated, @nPay AS PaymentsDetached,
               @nAf AS AccountForDeleted, @nBank AS BankAccountsDeleted,
               @nInv AS InvoicesKept, @nPaid AS PaymentsKept, @nHold AS HoldingsKept,
               CAST(1 AS TINYINT) AS RawRetentionMonths;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
