-- =====================================================================
-- procs_gdpr.sql : ΙΙΙ.1.4 Δικαίωμα λήθης (περιοχή GDP, GDP-1)
-- Ροή: ο καταναλωτής υποβάλλει -> ο Operator εξετάζει / προεγκρίνει (ή απορρίπτει)
--      -> ο Admin αποφασίζει (εγκρίνει ή απορρίπτει) -> εφαρμογή.
-- Δύο είδη αιτήματος (GDPR_REQUEST.RequestType), ίδια ροή εγκρίσεων:
--   'Erasure'   δικαίωμα στη λήθη: ανωνυμοποίηση, ο λογαριασμός κλείνει, διατήρηση ωμών 1 μήνα.
--   'Retention' ο λογαριασμός ΜΕΝΕΙ ενεργός, μόνο η διατήρηση των αναλυτικών μετρήσεων γίνεται 1 μήνας (spec III.1.4).
-- Και στα δύο, η εφαρμογή τρέχει ΑΥΤΟΜΑΤΑ αμέσως μετά την εκκαθάριση (sp_retention_purge_core): οι
-- παλαιότερες ωμές/επικυρωμένες μετρήσεις σβήνονται χωρίς να πατήσει κανείς το κουμπί διατήρησης.
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
    @UserID INT, @RequestType VARCHAR(9) = 'Erasure'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Consumer';
    SET @RequestType = ISNULL(@RequestType, 'Erasure');
    IF @RequestType NOT IN ('Erasure', 'Retention')
        THROW 51413, N'Μη έγκυρο είδος αιτήματος (διαγραφή ή μείωση διατήρησης).', 1;
    IF @RequestType = 'Retention' AND EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND RawRetentionMonths = 1)
        THROW 51414, N'Η διατήρηση των αναλυτικών μετρήσεών σας είναι ήδη 1 μήνας.', 1;
    BEGIN TRY
        BEGIN TRAN;
        -- κλειδώνουμε τη γραμμή του χρήστη ώστε δύο ταυτόχρονες υποβολές να περάσουν η μία μετά την άλλη
        DECLARE @lock INT;
        SELECT @lock = UserID FROM USER_ACCOUNT WITH (UPDLOCK, HOLDLOCK) WHERE UserID = @UserID;
        IF EXISTS (SELECT 1 FROM GDPR_REQUEST
                   WHERE ConsumerID = @UserID AND Status IN ('Submitted', 'Under review', 'Pre-approved', 'Approved'))
            THROW 51403, N'Έχετε ήδη ανοιχτό αίτημα διαγραφής.', 1;
        INSERT GDPR_REQUEST (SubmittedAt, Status, ConsumerID, RequestType)
        VALUES (CAST(SYSUTCDATETIME() AS DATETIME2(0)), 'Submitted', @UserID, @RequestType);
        DECLARE @id INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('GDPR_REQUEST', @id, 'Submit', NULL, 'Submitted', @RequestType, @UserID);
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
           COALESCE(g.DecidedByAdmin, g.DecidedBy) AS DecidedBy, de.Username AS DecidedByUsername,
           g.RequestType
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
--    RawRetentionMonths = 1: τις ωμές μετρήσεις > 1 μήνα τις σβήνει αμέσως η αυτόματη εκκαθάριση στο τέλος.
--    Αίτημα 'Retention': ΜΟΝΟ RawRetentionMonths = 1 + εκκαθάριση· ο λογαριασμός μένει ενεργός.
--    Το AUDIT_LOG παίρνει μόνο αριθμούς και IDs, ποτέ τα προσωπικά δεδομένα.
-- ---------------------------------------------------------------------
-- (Η sp_gdpr_apply ορίζεται στο τέλος του αρχείου, μετά τη sp_retention_purge_core που καλεί.)

-- =====================================================================
-- GDP-2: Διατήρηση δεδομένων (ΙΙΙ.1.4). THROW 51450-51499.
--   51450 η ημερομηνία αναφοράς είναι πάνω από 1 χρόνο στο μέλλον (προστασία από λάθος που σβήνει τα πάντα)
--   51451 τρέχει ήδη άλλη εκκαθάριση
-- (και 51402 όταν ο χρήστης δεν είναι Admin, από το sp_gdpr_assert_role)
--
-- ΚΑΝΟΝΑΣ: ωμές και επικυρωμένες μετρήσεις (RAW_READING, VALIDATED_READING) κρατιούνται
-- RawRetentionMonths μήνες (36, ή 1 μετά από εφαρμοσμένο αίτημα GDPR) του καταναλωτή που
-- ΚΡΑΤΟΥΣΕ το υποστατικό ΤΗΝ ΩΡΑ ΤΗΣ ΜΕΤΡΗΣΗΣ:
--   μετρητής --METER_INSTALLATION(InstalledAt..RemovedAt)--> υποστατικό --HOLDING(StartDate..EndDate)--> καταναλωτής.
--   * Το παράθυρο κατοχής/εγκατάστασης δίνεται από τη fn_retention_cutoff (τμήματα χρόνου ανά μετρητή).
--   * Μέτρηση που δεν πέφτει σε κανένα τμήμα (υποστατικό χωρίς κάτοχο εκείνη την ώρα, ή πριν την
--     εγκατάσταση) -> εφεδρικά 36 μήνες.
--   * Αν δύο τμήματα επικαλύπτονται (δεν θα έπρεπε), κερδίζει ο μεγαλύτερος χρόνος διατήρησης (συντηρητικά).
--   * Οι εγκαταστάσεις με ConfirmationStatus = 'Rejected' δεν μετράνε.
--   Διαγράφονται και οι γραμμές READING_EDIT των ίδιων μετρήσεων: κρατούν OldValue/NewValue, δηλαδή τις
--   ίδιες τιμές που σβήνουμε, άρα θα έμεναν ως «διαρροή» των δεδομένων. Τα METER_AGGREGATE,
--   TRANSFORMER_AGGREGATE και τα δεδομένα μετασχηματιστών ΔΕΝ πειράζονται (μένουν για πάντα).
-- =====================================================================

-- Τμήματα χρόνου ανά μετρητή: ποιος καταναλωτής κρατούσε το υποστατικό και πόσους μήνες κρατιούνται οι μετρήσεις.
-- Inline TVF (όχι scalar). SegFrom <= χρόνος < SegTo.
CREATE OR ALTER FUNCTION fn_retention_cutoff (@AsOf DATETIME2(0))
RETURNS TABLE
AS RETURN
(
    SELECT i.MeterID, s.SegFrom, s.SegTo, h.UserID,
           u.RawRetentionMonths AS RetentionMonths,
           DATEADD(MONTH, -u.RawRetentionMonths, @AsOf) AS Cutoff
    FROM METER_INSTALLATION i
    JOIN HOLDING h ON h.PremiseID = i.PremiseID
    JOIN USER_ACCOUNT u ON u.UserID = h.UserID
    CROSS APPLY (SELECT GREATEST(i.InstalledAt, CAST(h.StartDate AS DATETIME2(0))) AS SegFrom,
                        LEAST(COALESCE(i.RemovedAt, CAST('9999-12-31' AS DATETIME2(0))),
                              CASE WHEN h.EndDate IS NULL THEN CAST('9999-12-31' AS DATETIME2(0))
                                   ELSE DATEADD(DAY, 1, CAST(h.EndDate AS DATETIME2(0))) END) AS SegTo) s
    WHERE i.ConfirmationStatus <> 'Rejected' AND u.RawRetentionMonths IS NOT NULL AND s.SegFrom < s.SegTo
);
GO

-- ---------------------------------------------------------------------
-- Προεπισκόπηση (μόνο ανάγνωση): ανά μετρητή και ανά χρόνο διατήρησης, πόσες γραμμές θα σβηστούν.
-- Μετρητές χωρίς τίποτα προς διαγραφή εμφανίζονται με 0 και τους μήνες που ισχύουν στο @AsOf.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_retention_preview
    @UserID INT, @AsOf DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Admin';
    DECLARE @asof0 DATETIME2(0) = CAST(COALESCE(@AsOf, SYSUTCDATETIME()) AS DATETIME2(0));
    IF @asof0 > DATEADD(YEAR, 1, SYSUTCDATETIME())
        THROW 51450, N'Η ημερομηνία αναφοράς δεν μπορεί να είναι πάνω από έναν χρόνο στο μέλλον.', 1;
    BEGIN TRY
        DECLARE @seg TABLE (MeterID INT NOT NULL, SegFrom DATETIME2(0) NOT NULL, SegTo DATETIME2(0) NOT NULL,
                            UserID INT NOT NULL, RetentionMonths TINYINT NOT NULL, Cutoff DATETIME2(0) NOT NULL,
                            INDEX ix_seg (MeterID, SegFrom));
        INSERT @seg SELECT MeterID, SegFrom, SegTo, UserID, RetentionMonths, Cutoff FROM fn_retention_cutoff(@asof0);
        DECLARE @minCutoff DATETIME2(0) = DATEADD(MONTH, -1, @asof0);   -- ο μικρότερος δυνατός χρόνος διατήρησης

        WITH k AS (
            SELECT r.MeterID, r.IntervalStart, CAST(1 AS INT) AS Raw, CAST(0 AS INT) AS Val, CAST(0 AS INT) AS Ed
            FROM RAW_READING r WHERE r.IntervalStart < @minCutoff
            UNION ALL
            SELECT v.MeterID, v.IntervalStart, 0, 1, 0 FROM VALIDATED_READING v WHERE v.IntervalStart < @minCutoff
            UNION ALL
            SELECT e.MeterID, e.IntervalStart, 0, 0, 1 FROM READING_EDIT e WHERE e.IntervalStart < @minCutoff
        ), m AS (
            SELECT k.MeterID, k.Raw, k.Val, k.Ed, k.IntervalStart,
                   COALESCE((SELECT MAX(sg.RetentionMonths) FROM @seg sg
                             WHERE sg.MeterID = k.MeterID AND k.IntervalStart >= sg.SegFrom AND k.IntervalStart < sg.SegTo), 36) AS Months
            FROM k
        ), del AS (
            SELECT MeterID, Months, SUM(Raw) AS RawToDelete, SUM(Val) AS ValidatedToDelete, SUM(Ed) AS EditsToDelete
            FROM m
            WHERE IntervalStart < DATEADD(MONTH, -Months, @asof0)
            GROUP BY MeterID, Months
        )
        SELECT mt.MeterID, mt.SerialNumber, d.Months AS RetentionMonths, DATEADD(MONTH, -d.Months, @asof0) AS Cutoff,
               d.RawToDelete, d.ValidatedToDelete, d.EditsToDelete, @asof0 AS AsOf
        FROM del d JOIN METER mt ON mt.MeterID = d.MeterID
        UNION ALL
        SELECT mt.MeterID, mt.SerialNumber, cur.Months, DATEADD(MONTH, -cur.Months, @asof0), 0, 0, 0, @asof0
        FROM METER mt
        CROSS APPLY (SELECT COALESCE((SELECT MAX(sg.RetentionMonths) FROM @seg sg
                                      WHERE sg.MeterID = mt.MeterID AND @asof0 >= sg.SegFrom AND @asof0 < sg.SegTo), 36) AS Months) cur
        WHERE NOT EXISTS (SELECT 1 FROM del d WHERE d.MeterID = mt.MeterID)
        ORDER BY MeterID, RetentionMonths;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Εκκαθάριση. Αρχή X5: sp_set_session_context N'mdms_purge', 1 -> DELETE (ποτέ UPDATE) -> επαναφορά στο 0.
-- Παρτίδες των 5000 γραμμών: μικρά transactions = σύντομα κλειδώματα (οι μετρήσεις συνεχίζουν να
-- εισάγονται) και το log δεν φουσκώνει. ΜΙΑ transaction ανά παρτίδα (όχι για όλη την εκκαθάριση):
-- ο κανόνας είναι μονότονος (ό,τι σβήστηκε θα έπρεπε να σβηστεί έτσι κι αλλιώς), άρα αν διακοπεί στη
-- μέση δεν χάνεται συνέπεια, απλώς ξανατρέχει. Το κόστος: χωρίς ατομικότητα για ολόκληρη τη δουλειά.
-- Σειρά: READING_EDIT, VALIDATED_READING, RAW_READING. Ένα session lock εμποδίζει δύο ταυτόχρονες εκκαθαρίσεις.
-- Επιστρέφει RawDeleted, ValidatedDeleted, EditsDeleted, AsOf.
-- ---------------------------------------------------------------------
-- Ο πυρήνας (χωρίς result set, αποτελέσματα σε OUTPUT) ώστε να τον καλεί και η sp_gdpr_apply αυτόματα.
CREATE OR ALTER PROCEDURE sp_retention_purge_core
    @UserID INT, @AsOf DATETIME2 = NULL,
    @nRawOut INT OUTPUT, @nValOut INT OUTPUT, @nEdOut INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Admin';
    DECLARE @asof0 DATETIME2(0) = CAST(COALESCE(@AsOf, SYSUTCDATETIME()) AS DATETIME2(0));
    IF @asof0 > DATEADD(YEAR, 1, SYSUTCDATETIME())
        THROW 51450, N'Η ημερομηνία αναφοράς δεν μπορεί να είναι πάνω από έναν χρόνο στο μέλλον.', 1;
    DECLARE @haveLock BIT = 0;
    BEGIN TRY
        DECLARE @lk INT;
        EXEC @lk = sp_getapplock @Resource = N'mdms_retention_purge', @LockMode = N'Exclusive',
                                 @LockOwner = N'Session', @LockTimeout = 0;
        IF @lk < 0 THROW 51451, N'Τρέχει ήδη άλλη εκκαθάριση δεδομένων.', 1;
        SET @haveLock = 1;

        DECLARE @seg TABLE (MeterID INT NOT NULL, SegFrom DATETIME2(0) NOT NULL, SegTo DATETIME2(0) NOT NULL,
                            RetentionMonths TINYINT NOT NULL, INDEX ix_seg (MeterID, SegFrom));
        INSERT @seg SELECT MeterID, SegFrom, SegTo, RetentionMonths FROM fn_retention_cutoff(@asof0);
        DECLARE @minCutoff DATETIME2(0) = DATEADD(MONTH, -1, @asof0);
        DECLARE @batch INT = 5000, @n INT, @nRaw INT = 0, @nVal INT = 0, @nEd INT = 0;

        EXEC sp_set_session_context N'mdms_purge', 1;

        WHILE 1 = 1   -- READING_EDIT
        BEGIN
            BEGIN TRAN;
            DELETE TOP (@batch) e FROM READING_EDIT e
            WHERE e.IntervalStart < @minCutoff
              AND e.IntervalStart < DATEADD(MONTH, -COALESCE((SELECT MAX(sg.RetentionMonths) FROM @seg sg
                    WHERE sg.MeterID = e.MeterID AND e.IntervalStart >= sg.SegFrom AND e.IntervalStart < sg.SegTo), 36), @asof0);
            SET @n = @@ROWCOUNT;
            COMMIT;
            SET @nEd += @n;
            IF @n = 0 BREAK;
        END
        WHILE 1 = 1   -- VALIDATED_READING (το trigger το επιτρέπει μόνο με το flag)
        BEGIN
            BEGIN TRAN;
            DELETE TOP (@batch) v FROM VALIDATED_READING v
            WHERE v.IntervalStart < @minCutoff
              AND v.IntervalStart < DATEADD(MONTH, -COALESCE((SELECT MAX(sg.RetentionMonths) FROM @seg sg
                    WHERE sg.MeterID = v.MeterID AND v.IntervalStart >= sg.SegFrom AND v.IntervalStart < sg.SegTo), 36), @asof0);
            SET @n = @@ROWCOUNT;
            COMMIT;
            SET @nVal += @n;
            IF @n = 0 BREAK;
        END
        WHILE 1 = 1   -- RAW_READING
        BEGIN
            BEGIN TRAN;
            DELETE TOP (@batch) r FROM RAW_READING r
            WHERE r.IntervalStart < @minCutoff
              AND r.IntervalStart < DATEADD(MONTH, -COALESCE((SELECT MAX(sg.RetentionMonths) FROM @seg sg
                    WHERE sg.MeterID = r.MeterID AND r.IntervalStart >= sg.SegFrom AND r.IntervalStart < sg.SegTo), 36), @asof0);
            SET @n = @@ROWCOUNT;
            COMMIT;
            SET @nRaw += @n;
            IF @n = 0 BREAK;
        END

        EXEC sp_set_session_context N'mdms_purge', 0;

        BEGIN TRAN;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, ResultComment, PerformedBy)
        VALUES ('RETENTION', CONVERT(VARCHAR(19), @asof0, 120), 'Retention purge',
                CONCAT(N'Εκκαθάριση ως ', CONVERT(VARCHAR(19), @asof0, 120), N' UTC: ωμές ', @nRaw,
                       N', επικυρωμένες ', @nVal, N', διορθώσεις ', @nEd), @UserID);
        COMMIT;

        EXEC sp_releaseapplock @Resource = N'mdms_retention_purge', @LockOwner = N'Session';
        SET @haveLock = 0;
        SELECT @nRawOut = @nRaw, @nValOut = @nVal, @nEdOut = @nEd;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC sp_set_session_context N'mdms_purge', 0;
        IF @haveLock = 1 EXEC sp_releaseapplock @Resource = N'mdms_retention_purge', @LockOwner = N'Session';
        THROW;
    END CATCH
END;
GO

-- Το κουμπί «Εκκαθάριση» του Admin: ο πυρήνας + μία γραμμή αποτελέσματος.
CREATE OR ALTER PROCEDURE sp_retention_purge
    @UserID INT, @AsOf DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @r INT, @v INT, @e INT;
    EXEC sp_retention_purge_core @UserID, @AsOf, @r OUTPUT, @v OUTPUT, @e OUTPUT;
    SELECT @r AS RawDeleted, @v AS ValidatedDeleted, @e AS EditsDeleted,
           CAST(COALESCE(@AsOf, SYSUTCDATETIME()) AS DATETIME2(0)) AS AsOf;
END;
GO

-- ---------------------------------------------------------------------
-- 5. Admin: εφαρμογή (περιγραφή πιο πάνω, στο «5.»).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_gdpr_apply
    @UserID INT, @GdprRequestID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_gdpr_assert_role @UserID, 'Admin';
    DECLARE @old VARCHAR(12), @cid INT, @type VARCHAR(9), @anon NVARCHAR(50) = NULL;
    DECLARE @nChan INT = 0, @nThr INT = 0, @nPay INT = 0, @nAf INT = 0, @nBank INT = 0;
    DECLARE @nInv INT, @nPaid INT, @nHold INT, @oldRet TINYINT;
    BEGIN TRY
        BEGIN TRAN;
        SELECT @old = Status, @cid = ConsumerID, @type = RequestType
        FROM GDPR_REQUEST WITH (UPDLOCK, HOLDLOCK) WHERE GdprRequestID = @GdprRequestID;
        IF @old IS NULL THROW 51406, N'Το αίτημα δεν βρέθηκε.', 1;
        IF @old <> 'Approved' THROW 51411, N'Εφαρμογή γίνεται μόνο σε αίτημα που έχει εγκριθεί από τον Admin.', 1;
        IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WITH (UPDLOCK) WHERE UserID = @cid AND Role = 'Consumer')
            THROW 51412, N'Ο χρήστης του αιτήματος δεν είναι Καταναλωτής.', 1;
        SELECT @oldRet = RawRetentionMonths FROM USER_ACCOUNT WHERE UserID = @cid;

        IF @type = 'Erasure'
        BEGIN
            SET @anon = CONCAT(N'deleted_', @cid);
            UPDATE USER_ACCOUNT
            SET Username = @anon, FirstName = N'Διαγραμμένος', LastName = N'Διαγραμμένος',
                Email = CONCAT('deleted', @cid, '@anon.invalid'), Phone = NULL,
                PasswordHash = CONCAT('!ERASED!', CONVERT(VARCHAR(36), NEWID())),   -- δεν είναι έγκυρο hash: κανείς δεν μπαίνει
                AccountStatus = 'Suspended', RawRetentionMonths = 1
            WHERE UserID = @cid;

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
        END
        ELSE   -- 'Retention': μόνο η διατήρηση γίνεται 1 μήνας, ο λογαριασμός μένει ενεργός
            UPDATE USER_ACCOUNT SET RawRetentionMonths = 1 WHERE UserID = @cid;

        DECLARE @now DATETIME2(0) = CAST(SYSUTCDATETIME() AS DATETIME2(0));
        UPDATE GDPR_REQUEST
        SET Status = 'Applied', AppliedAt = CASE WHEN @now >= DecidedAt THEN @now ELSE DecidedAt END
        WHERE GdprRequestID = @GdprRequestID;

        SET @nInv = (SELECT COUNT(*) FROM INVOICE WHERE UserID = @cid);
        SET @nPaid = (SELECT COUNT(*) FROM PAYMENT p JOIN INVOICE i ON i.InvoiceID = p.InvoiceID WHERE i.UserID = @cid);
        SET @nHold = (SELECT COUNT(*) FROM HOLDING WHERE UserID = @cid);

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('GDPR_REQUEST', @GdprRequestID, 'Apply', @old, 'Applied',
                CASE WHEN @type = 'Erasure'
                     THEN CONCAT(N'Ανωνυμοποίηση χρήστη ', @cid, N': κανάλια ', @nChan, N', όρια ', @nThr,
                                 N', πληρωμές χωρίς λογαριασμό ', @nPay, N', τραπ. λογαριασμοί ', @nBank,
                                 N'; διατηρούνται τιμολόγια ', @nInv, N', πληρωμές ', @nPaid, N', κατοχές ', @nHold)
                     ELSE CONCAT(N'Μείωση διατήρησης χρήστη ', @cid, N' σε 1 μήνα· ο λογαριασμός μένει ενεργός') END, @UserID);
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('USER_ACCOUNT', @cid, CASE WHEN @type = 'Erasure' THEN 'GDPR anonymise' ELSE 'GDPR retention' END,
                NULL, CASE WHEN @type = 'Erasure' THEN 'Suspended' ELSE 'Active' END,
                CONCAT(N'RawRetentionMonths ', @oldRet, N' -> 1'), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    -- Αυτόματη εκκαθάριση ΜΕΤΑ το COMMIT (έχει δικές της μικρές συναλλαγές ανά παρτίδα). Αν δεν τρέξει
    -- (π.χ. τρέχει ήδη άλλη εκκαθάριση, 51451), η εφαρμογή ισχύει ήδη και τα σβήνει το επόμενο τρέξιμο.
    DECLARE @pRaw INT = NULL, @pVal INT = NULL, @pEd INT = NULL;
    BEGIN TRY
        EXEC sp_retention_purge_core @UserID, NULL, @pRaw OUTPUT, @pVal OUTPUT, @pEd OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT @pRaw = NULL, @pVal = NULL, @pEd = NULL;
    END CATCH

    SELECT @GdprRequestID AS GdprRequestID, @cid AS ConsumerID, @anon AS AnonymisedUsername,
           @nChan AS ChannelsDeleted, @nThr AS ThresholdsDeactivated, @nPay AS PaymentsDetached,
           @nAf AS AccountForDeleted, @nBank AS BankAccountsDeleted,
           @nInv AS InvoicesKept, @nPaid AS PaymentsKept, @nHold AS HoldingsKept,
           CAST(1 AS TINYINT) AS RawRetentionMonths, @type AS RequestType,
           @pRaw AS RawPurged, @pVal AS ValidatedPurged;
END;
GO
