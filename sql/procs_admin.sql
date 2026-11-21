-- =====================================================================
-- procs_admin.sql : Διαχειριστής (περιοχή ADM, ADM-2)
--   λογαριασμοί προσωπικού, αναστολή/ενεργοποίηση, αρχείο καταγραφής (AUDIT_LOG)
-- Τρέχει μετά το procs_common.sql. Λάθη: 51500-51999 (υπο-περιοχή ADM).
-- Κάθε procedure παίρνει πρώτο το @UserID και ελέγχει ότι είναι ενεργός Admin.
-- Ο κωδικός φτάνει ΜΟΝΟ ως hash (το password_hash() γίνεται στην PHP). Το hash δεν επιστρέφεται ποτέ.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: σταματά με λάθος αν ο χρήστης δεν είναι ενεργός Admin.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'Admin' AND AccountStatus = 'Active')
        THROW 51500, N'Δεν επιτρέπεται: μόνο για ενεργό Διαχειριστή.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- Δημιουργία λογαριασμού προσωπικού: Operator, DSO, TSO, Supplier, Aggregator.
-- Επιστρέφει το νέο UserID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_create_user
    @UserID INT, @Role VARCHAR(10), @Username NVARCHAR(50), @PasswordHash VARCHAR(255),
    @Email VARCHAR(254), @Phone VARCHAR(20), @FirstName NVARCHAR(50), @LastName NVARCHAR(50),
    @SupplierID INT = NULL, @AggregatorID INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_assert @UserID;
    IF @Role IS NULL OR @Role NOT IN ('Operator', 'DSO', 'TSO', 'Supplier', 'Aggregator')
        THROW 51501, N'Ο Διαχειριστής δημιουργεί μόνο Χειριστές, ΔΣΜ/ΔΣΜΗΚ (DSO, TSO), Προμηθευτές και Αθροιστές.', 1;
    SET @Username = LTRIM(RTRIM(@Username));
    IF @Username IS NULL OR @Username = N'' OR @PasswordHash IS NULL OR @PasswordHash = ''
       OR ISNULL(LTRIM(RTRIM(@FirstName)), N'') = N'' OR ISNULL(LTRIM(RTRIM(@LastName)), N'') = N''
        THROW 51502, N'Συμπληρώστε όνομα χρήστη, κωδικό, όνομα και επώνυμο.', 1;
    IF @Email IS NULL OR @Email NOT LIKE '%_@_%._%'
        THROW 51503, N'Μη έγκυρη διεύθυνση email.', 1;
    IF @Phone IS NOT NULL AND @Phone LIKE '%[^0-9+ ]%'
        THROW 51504, N'Το τηλέφωνο έχει μόνο ψηφία, + και κενά.', 1;
    IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE Username = @Username)
        THROW 51505, N'Το όνομα χρήστη υπάρχει ήδη. Διαλέξτε άλλο.', 1;
    IF @Role = 'Supplier' AND (@SupplierID IS NULL OR @AggregatorID IS NOT NULL
                               OR NOT EXISTS (SELECT 1 FROM SUPPLIER WHERE SupplierID = @SupplierID))
        THROW 51506, N'Ο λογαριασμός Προμηθευτή θέλει υπαρκτό Προμηθευτή (και όχι Αθροιστή).', 1;
    IF @Role = 'Aggregator' AND (@AggregatorID IS NULL OR @SupplierID IS NOT NULL
                                 OR NOT EXISTS (SELECT 1 FROM AGGREGATOR WHERE AggregatorID = @AggregatorID))
        THROW 51507, N'Ο λογαριασμός Αθροιστή θέλει υπαρκτό Αθροιστή (και όχι Προμηθευτή).', 1;
    IF @Role NOT IN ('Supplier', 'Aggregator') AND (@SupplierID IS NOT NULL OR @AggregatorID IS NOT NULL)
        THROW 51508, N'Αυτός ο ρόλος δεν συνδέεται με εταιρεία.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, Phone, FirstName, LastName, CreatedBy, SupplierID, AggregatorID)
        VALUES (@Username, @PasswordHash, @Role, @Email, @Phone, @FirstName, @LastName,
                CASE WHEN @Role = 'Operator' THEN @UserID END, @SupplierID, @AggregatorID);
        DECLARE @id INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('USER_ACCOUNT', @id, 'Create user', CONCAT(N'Role=', @Role, N', Username=', @Username), @UserID);
        COMMIT;
        SELECT @id AS UserID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)   -- ταυτόχρονη εισαγωγή του ίδιου username
            THROW 51505, N'Το όνομα χρήστη υπάρχει ήδη. Διαλέξτε άλλο.', 1;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Λίστα χρηστών (ποτέ το PasswordHash), προαιρετικό φίλτρο ρόλου.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_list_users
    @UserID INT, @Role VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_admin_assert @UserID;
    IF @Role IS NOT NULL AND @Role NOT IN ('Admin', 'Operator', 'Consumer', 'Technician', 'DSO', 'TSO', 'Supplier', 'Aggregator')
        THROW 51510, N'Άγνωστος ρόλος.', 1;
    SELECT u.UserID, u.Username, u.Role, u.Email, u.Phone, u.FirstName, u.LastName, u.AccountStatus, u.CreatedAt,
           u.SupplierID, u.AggregatorID, COALESCE(s.Name, a.Name) AS Company
    FROM USER_ACCOUNT u
    LEFT JOIN SUPPLIER s ON s.SupplierID = u.SupplierID
    LEFT JOIN AGGREGATOR a ON a.AggregatorID = u.AggregatorID
    WHERE @Role IS NULL OR u.Role = @Role
    ORDER BY u.Role, u.Username;
END;
GO

-- ---------------------------------------------------------------------
-- Αναστολή / ενεργοποίηση λογαριασμού. Ο Διαχειριστής δεν αναστέλλει τον εαυτό του.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_set_account_status
    @UserID INT, @TargetUserID INT, @Status VARCHAR(9)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_assert @UserID;
    IF @Status IS NULL OR @Status NOT IN ('Active', 'Suspended')
        THROW 51520, N'Η κατάσταση είναι Active ή Suspended.', 1;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @TargetUserID)
        THROW 51521, N'Ο χρήστης δεν βρέθηκε.', 1;
    IF @TargetUserID = @UserID AND @Status = 'Suspended'
        THROW 51522, N'Δεν μπορείτε να αναστείλετε τον ίδιο σας τον λογαριασμό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(9) = (SELECT AccountStatus FROM USER_ACCOUNT WITH (UPDLOCK) WHERE UserID = @TargetUserID);
        IF @old = @Status
            THROW 51523, N'Ο λογαριασμός έχει ήδη αυτή την κατάσταση.', 1;
        UPDATE USER_ACCOUNT SET AccountStatus = @Status WHERE UserID = @TargetUserID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('USER_ACCOUNT', @TargetUserID, 'Set account status', @old, @Status, @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Αρχείο καταγραφής: νεότερα πρώτα, μέχρι 500 γραμμές. Η μέρα @To περιλαμβάνεται ολόκληρη.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_audit_log
    @UserID INT, @ObjectType VARCHAR(30) = NULL, @From DATE = NULL, @To DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_admin_assert @UserID;
    IF @From IS NOT NULL AND @To IS NOT NULL AND @From > @To
        THROW 51530, N'Η ημερομηνία «από» είναι μετά την «έως».', 1;
    SELECT TOP (500) l.LogID, l.LoggedAt, l.ObjectType, l.ObjectID, l.Action, l.OldState, l.NewState,
           l.ResultComment, l.PerformedBy, p.Username AS PerformedByUsername, l.ActorMechanism
    FROM AUDIT_LOG l
    LEFT JOIN USER_ACCOUNT p ON p.UserID = l.PerformedBy
    WHERE (@ObjectType IS NULL OR l.ObjectType = @ObjectType)
      AND (@From IS NULL OR l.LoggedAt >= @From)
      AND (@To IS NULL OR l.LoggedAt < DATEADD(DAY, 1, CAST(@To AS DATETIME2(3))))
    ORDER BY l.LoggedAt DESC, l.LogID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- Εταιρείες (προμηθευτές + αθροιστές) για λίστες επιλογής.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_list_companies
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_admin_assert @UserID;
    SELECT 'Supplier' AS CompanyType, SupplierID AS CompanyID, Name FROM SUPPLIER
    UNION ALL
    SELECT 'Aggregator', AggregatorID, Name FROM AGGREGATOR
    ORDER BY CompanyType, Name;
END;
GO
