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

-- =====================================================================
-- ADM-3: κατάλογοι του Χειριστή (μοντέλα μετρητών, υπηρεσίες, τιμολόγια)
-- Λάθη: 51600-51699. Οι κατάλογοι είναι γραμμές, όχι σχήμα: νέος τύπος = νέα γραμμή (docs/17).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: σταματά με λάθος αν ο χρήστης δεν είναι ενεργός Χειριστής.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_admin_operator_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'Operator' AND AccountStatus = 'Active')
        THROW 51600, N'Δεν επιτρέπεται: μόνο για ενεργό Χειριστή.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- Μοντέλο μετρητή: νέο (@ModelID NULL) ή αλλαγή. Επιστρέφει το ModelID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_save_meter_model
    @UserID INT, @ModelID INT = NULL, @Manufacturer NVARCHAR(100), @ModelName NVARCHAR(100),
    @MeterType VARCHAR(30), @PhaseCount TINYINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_operator_assert @UserID;
    SET @Manufacturer = LTRIM(RTRIM(@Manufacturer));
    SET @ModelName = LTRIM(RTRIM(@ModelName));
    SET @MeterType = LTRIM(RTRIM(@MeterType));
    IF ISNULL(@Manufacturer, N'') = N'' OR ISNULL(@ModelName, N'') = N'' OR ISNULL(@MeterType, '') = ''
        THROW 51601, N'Συμπληρώστε κατασκευαστή, μοντέλο και τύπο μετρητή.', 1;
    IF @PhaseCount IS NULL OR @PhaseCount NOT BETWEEN 1 AND 3
        THROW 51602, N'Οι φάσεις είναι 1, 2 ή 3.', 1;
    IF EXISTS (SELECT 1 FROM METER_MODEL WHERE Manufacturer = @Manufacturer AND ModelName = @ModelName
               AND (@ModelID IS NULL OR ModelID <> @ModelID))
        THROW 51603, N'Υπάρχει ήδη μοντέλο με αυτόν τον κατασκευαστή και όνομα.', 1;
    IF @ModelID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM METER_MODEL WHERE ModelID = @ModelID)
        THROW 51604, N'Το μοντέλο μετρητή δεν βρέθηκε.', 1;
    BEGIN TRY
        BEGIN TRAN;
        IF @ModelID IS NULL
        BEGIN
            INSERT METER_MODEL (Manufacturer, ModelName, MeterType, PhaseCount)
            VALUES (@Manufacturer, @ModelName, @MeterType, @PhaseCount);
            SET @ModelID = SCOPE_IDENTITY();
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
            VALUES ('METER_MODEL', @ModelID, 'Create meter model',
                    CONCAT(@Manufacturer, N' / ', @ModelName, N' / ', @MeterType, N' / ', @PhaseCount, N' φάσεις'), @UserID);
        END
        ELSE
        BEGIN
            DECLARE @old NVARCHAR(400) = (SELECT CONCAT(Manufacturer, N' / ', ModelName, N' / ', MeterType, N' / ', PhaseCount, N' φάσεις')
                                          FROM METER_MODEL WITH (UPDLOCK) WHERE ModelID = @ModelID);
            UPDATE METER_MODEL SET Manufacturer = @Manufacturer, ModelName = @ModelName,
                                   MeterType = @MeterType, PhaseCount = @PhaseCount
            WHERE ModelID = @ModelID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
            VALUES ('METER_MODEL', @ModelID, 'Update meter model', @old,
                    CONCAT(@Manufacturer, N' / ', @ModelName, N' / ', @MeterType, N' / ', @PhaseCount, N' φάσεις'), @UserID);
        END
        COMMIT;
        SELECT @ModelID AS ModelID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51603, N'Υπάρχει ήδη μοντέλο με αυτόν τον κατασκευαστή και όνομα.', 1;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Τύπος υπηρεσίας: νέος (@ServiceTypeID NULL) ή αλλαγή. Επιστρέφει το ServiceTypeID.
-- Η αλλαγή του Fee ΔΕΝ αλλάζει παλιές αγορές: κάθε SERVICE_PURCHASE κρατά δικό του Amount.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_save_service_type
    @UserID INT, @ServiceTypeID INT = NULL, @Name NVARCHAR(100), @Fee DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_operator_assert @UserID;
    SET @Name = LTRIM(RTRIM(@Name));
    IF ISNULL(@Name, N'') = N''
        THROW 51610, N'Συμπληρώστε το όνομα της υπηρεσίας.', 1;
    IF @Fee IS NULL OR @Fee < 0
        THROW 51611, N'Το τέλος δεν μπορεί να είναι αρνητικό.', 1;
    IF EXISTS (SELECT 1 FROM SERVICE_TYPE WHERE Name = @Name AND (@ServiceTypeID IS NULL OR ServiceTypeID <> @ServiceTypeID))
        THROW 51612, N'Υπάρχει ήδη υπηρεσία με αυτό το όνομα.', 1;
    IF @ServiceTypeID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SERVICE_TYPE WHERE ServiceTypeID = @ServiceTypeID)
        THROW 51613, N'Η υπηρεσία δεν βρέθηκε.', 1;
    BEGIN TRY
        BEGIN TRAN;
        IF @ServiceTypeID IS NULL
        BEGIN
            INSERT SERVICE_TYPE (Name, Fee) VALUES (@Name, @Fee);
            SET @ServiceTypeID = SCOPE_IDENTITY();
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
            VALUES ('SERVICE_TYPE', @ServiceTypeID, 'Create service type', CONCAT(@Name, N' / ', @Fee), @UserID);
        END
        ELSE
        BEGIN
            DECLARE @old NVARCHAR(400) = (SELECT CONCAT(Name, N' / ', Fee) FROM SERVICE_TYPE WITH (UPDLOCK)
                                          WHERE ServiceTypeID = @ServiceTypeID);
            UPDATE SERVICE_TYPE SET Name = @Name, Fee = @Fee WHERE ServiceTypeID = @ServiceTypeID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
            VALUES ('SERVICE_TYPE', @ServiceTypeID, 'Update service type', @old, CONCAT(@Name, N' / ', @Fee), @UserID);
        END
        COMMIT;
        SELECT @ServiceTypeID AS ServiceTypeID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51612, N'Υπάρχει ήδη υπηρεσία με αυτό το όνομα.', 1;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Τύπος τιμολογίου: νέος (@TariffTypeID NULL) ή μετονομασία. Επιστρέφει το TariffTypeID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_save_tariff_type
    @UserID INT, @TariffTypeID INT = NULL, @Name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_operator_assert @UserID;
    SET @Name = LTRIM(RTRIM(@Name));
    IF ISNULL(@Name, N'') = N''
        THROW 51620, N'Συμπληρώστε το όνομα του τιμολογίου.', 1;
    IF EXISTS (SELECT 1 FROM TARIFF_TYPE WHERE Name = @Name AND (@TariffTypeID IS NULL OR TariffTypeID <> @TariffTypeID))
        THROW 51621, N'Υπάρχει ήδη τιμολόγιο με αυτό το όνομα.', 1;
    IF @TariffTypeID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TARIFF_TYPE WHERE TariffTypeID = @TariffTypeID)
        THROW 51622, N'Το τιμολόγιο δεν βρέθηκε.', 1;
    BEGIN TRY
        BEGIN TRAN;
        IF @TariffTypeID IS NULL
        BEGIN
            INSERT TARIFF_TYPE (Name) VALUES (@Name);
            SET @TariffTypeID = SCOPE_IDENTITY();
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
            VALUES ('TARIFF_TYPE', @TariffTypeID, 'Create tariff type', @Name, @UserID);
        END
        ELSE
        BEGIN
            DECLARE @old NVARCHAR(400) = (SELECT Name FROM TARIFF_TYPE WITH (UPDLOCK) WHERE TariffTypeID = @TariffTypeID);
            UPDATE TARIFF_TYPE SET Name = @Name WHERE TariffTypeID = @TariffTypeID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
            VALUES ('TARIFF_TYPE', @TariffTypeID, 'Update tariff type', @old, @Name, @UserID);
        END
        COMMIT;
        SELECT @TariffTypeID AS TariffTypeID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51621, N'Υπάρχει ήδη τιμολόγιο με αυτό το όνομα.', 1;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Διαγραφή στοιχείου καταλόγου, μόνο αν δεν το χρησιμοποιεί καμία γραμμή.
-- @Catalog: 'MeterModel' (METER), 'ServiceType' (SERVICE_PURCHASE), 'TariffType' (SUPPLY_CONTRACT).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_delete_catalog_item
    @UserID INT, @Catalog VARCHAR(20), @ID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_admin_operator_assert @UserID;
    IF @Catalog IS NULL OR @Catalog NOT IN ('MeterModel', 'ServiceType', 'TariffType')
        THROW 51630, N'Άγνωστος κατάλογος. Επιτρέπονται: MeterModel, ServiceType, TariffType.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old NVARCHAR(400);
        IF @Catalog = 'MeterModel'
        BEGIN
            SELECT @old = CONCAT(Manufacturer, N' / ', ModelName, N' / ', MeterType, N' / ', PhaseCount, N' φάσεις')
            FROM METER_MODEL WITH (UPDLOCK) WHERE ModelID = @ID;
            IF @old IS NULL THROW 51631, N'Το στοιχείο του καταλόγου δεν βρέθηκε.', 1;
            IF EXISTS (SELECT 1 FROM METER WITH (HOLDLOCK) WHERE ModelID = @ID)
                THROW 51632, N'Το μοντέλο χρησιμοποιείται από μετρητές και δεν διαγράφεται.', 1;
            DELETE FROM METER_MODEL WHERE ModelID = @ID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, PerformedBy)
            VALUES ('METER_MODEL', @ID, 'Delete meter model', @old, @UserID);
        END
        ELSE IF @Catalog = 'ServiceType'
        BEGIN
            SELECT @old = CONCAT(Name, N' / ', Fee) FROM SERVICE_TYPE WITH (UPDLOCK) WHERE ServiceTypeID = @ID;
            IF @old IS NULL THROW 51631, N'Το στοιχείο του καταλόγου δεν βρέθηκε.', 1;
            IF EXISTS (SELECT 1 FROM SERVICE_PURCHASE WITH (HOLDLOCK) WHERE ServiceTypeID = @ID)
                THROW 51632, N'Η υπηρεσία έχει αγορές και δεν διαγράφεται.', 1;
            DELETE FROM SERVICE_TYPE WHERE ServiceTypeID = @ID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, PerformedBy)
            VALUES ('SERVICE_TYPE', @ID, 'Delete service type', @old, @UserID);
        END
        ELSE
        BEGIN
            SELECT @old = Name FROM TARIFF_TYPE WITH (UPDLOCK) WHERE TariffTypeID = @ID;
            IF @old IS NULL THROW 51631, N'Το στοιχείο του καταλόγου δεν βρέθηκε.', 1;
            IF EXISTS (SELECT 1 FROM SUPPLY_CONTRACT WITH (HOLDLOCK) WHERE TariffTypeID = @ID)
                THROW 51632, N'Το τιμολόγιο χρησιμοποιείται από συμβόλαια και δεν διαγράφεται.', 1;
            DELETE FROM TARIFF_TYPE WHERE TariffTypeID = @ID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, PerformedBy)
            VALUES ('TARIFF_TYPE', @ID, 'Delete tariff type', @old, @UserID);
        END
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Δημόσιες λίστες για drop-down (χωρίς @UserID, όπως το sp_ref_list_parishes).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ref_list_meter_models
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ModelID, Manufacturer, ModelName, MeterType, PhaseCount,
           CONCAT(Manufacturer, N' ', ModelName, N' (', MeterType, N', ', PhaseCount, N' φ.)') AS Label
    FROM METER_MODEL ORDER BY Manufacturer, ModelName;
END;
GO

CREATE OR ALTER PROCEDURE sp_ref_list_service_types
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ServiceTypeID, Name, Fee, CONCAT(Name, N' (', Fee, N' €)') AS Label
    FROM SERVICE_TYPE ORDER BY Name;
END;
GO

CREATE OR ALTER PROCEDURE sp_ref_list_tariff_types
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TariffTypeID, Name, Name AS Label FROM TARIFF_TYPE ORDER BY Name;
END;
GO
