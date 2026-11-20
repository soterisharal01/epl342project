-- =====================================================================
-- procs_common.sql : κοινά procedures (login, εγγραφή καταναλωτή, προφίλ)
-- Ιδιοκτήτης: Σωτήρης (F3). Τα χρησιμοποιούν ΟΛΟΙ οι ρόλοι.
-- Τρέχει μετά το create.sql και πριν από τα procs_<περιοχή>.sql (απόφαση Α9).
-- Λάθη (THROW): 50000-50999 = κοινά (απόφαση Α4).
-- Κανόνας: η PHP δεν γράφει SQL, καλεί μόνο αυτά τα procedures με ? παραμέτρους.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_auth_get_login: δίνει στην PHP ό,τι χρειάζεται για να ελέγξει τον κωδικό.
-- Ο κωδικός ΔΕΝ ελέγχεται εδώ: η βάση κρατά μόνο το hash (password_hash),
-- και η PHP κάνει password_verify. Αν δεν υπάρχει ο χρήστης, επιστρέφει 0 γραμμές.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_auth_get_login
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserID, Username, PasswordHash, Role, AccountStatus, ApprovalStatus,
           FirstName, LastName, SupplierID, AggregatorID
    FROM USER_ACCOUNT
    WHERE Username = @Username;
END;
GO

-- ---------------------------------------------------------------------
-- sp_auth_log_login: κάθε προσπάθεια σύνδεσης (επιτυχής ή όχι) γράφεται στο AUDIT_LOG.
-- Χρήσιμο για την ασφάλεια (κεφάλαιο ασφάλειας στο docx).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_auth_log_login
    @Username NVARCHAR(50), @Success BIT, @ClientIP VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @uid INT = (SELECT UserID FROM USER_ACCOUNT WHERE Username = @Username);
    INSERT AUDIT_LOG (ObjectType, ObjectID, Action, ActorMechanism, ResultComment, PerformedBy)
    VALUES ('USER_ACCOUNT', LEFT(@Username, 100),
            CASE WHEN @Success = 1 THEN 'Login' ELSE 'Login failed' END,
            N'Web login', N'IP ' + ISNULL(@ClientIP, N'?'),
            CASE WHEN @Success = 1 THEN @uid END);
END;
GO

-- ---------------------------------------------------------------------
-- sp_auth_register_consumer: self-registration καταναλωτή (ΙΙΙ.1.1).
-- Χωρίς έγκριση: ο λογαριασμός είναι αμέσως Active.
-- RawRetentionMonths = 36 (raw μετρήσεις κρατιούνται 3 χρόνια, ΙΙΙ.1.4).
-- @PasswordHash = password_hash() της PHP. Ποτέ ο ίδιος ο κωδικός.
-- @Channels = 'Email', 'SMS' ή 'Email,SMS' (κανάλια ειδοποιήσεων).
-- Επιστρέφει: UserID του νέου χρήστη.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_auth_register_consumer
    @Username NVARCHAR(50), @PasswordHash VARCHAR(255), @Email VARCHAR(254),
    @Phone VARCHAR(20), @FirstName NVARCHAR(50), @LastName NVARCHAR(50),
    @Channels VARCHAR(20) = 'Email'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Username IS NULL OR LEN(@Username) < 3
        THROW 50001, N'Το username πρέπει να έχει τουλάχιστον 3 χαρακτήρες.', 1;
    IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE Username = @Username)
        THROW 50002, N'Το username υπάρχει ήδη. Διαλέξτε άλλο.', 1;
    IF @Email IS NULL OR @Email NOT LIKE '%_@_%._%'
        THROW 50003, N'Μη έγκυρο email.', 1;
    IF @Channels LIKE '%SMS%' AND (@Phone IS NULL OR @Phone = '')
        THROW 50004, N'Για ειδοποιήσεις με SMS χρειάζεται τηλέφωνο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, Phone, FirstName, LastName, RawRetentionMonths)
        VALUES (@Username, @PasswordHash, 'Consumer', @Email, NULLIF(@Phone, ''), @FirstName, @LastName, 36);
        DECLARE @id INT = SCOPE_IDENTITY();
        INSERT CONSUMER_NOTIFICATION_CHANNEL (UserID, NotificationChannel)
        SELECT @id, LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Channels, ',')
        WHERE LTRIM(RTRIM(value)) IN ('Email', 'SMS');
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('USER_ACCOUNT', @id, 'Register consumer', 'Active', @id);
        COMMIT;
        SELECT @id AS UserID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_user_get_profile: τα στοιχεία του ίδιου του χρήστη (κάθε ρόλος).
-- Ποτέ το PasswordHash.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_user_get_profile
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.Username, u.Role, u.FirstName, u.LastName, u.Email, u.Phone,
           u.AccountStatus, u.CreatedAt, u.ApprovalStatus,
           s.Name AS Supplier, a.Name AS Aggregator,
           (SELECT STRING_AGG(NotificationChannel, ', ') FROM CONSUMER_NOTIFICATION_CHANNEL c
             WHERE c.UserID = u.UserID) AS NotificationChannels
    FROM USER_ACCOUNT u
    LEFT JOIN SUPPLIER s ON s.SupplierID = u.SupplierID
    LEFT JOIN AGGREGATOR a ON a.AggregatorID = u.AggregatorID
    WHERE u.UserID = @UserID;
END;
GO

-- ---------------------------------------------------------------------
-- sp_user_change_password: αλλαγή κωδικού από τον ίδιο τον χρήστη.
-- Η PHP έχει ήδη ελέγξει τον παλιό κωδικό με password_verify.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_user_change_password
    @UserID INT, @NewPasswordHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND AccountStatus = 'Active')
        THROW 50010, N'Ο λογαριασμός δεν είναι ενεργός.', 1;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE USER_ACCOUNT SET PasswordHash = @NewPasswordHash WHERE UserID = @UserID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, PerformedBy)
        VALUES ('USER_ACCOUNT', @UserID, 'Change password', @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Λίστες επιλογής (για τα <select> των φορμών). Μόνο ανάγνωση, για κάθε ρόλο.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ref_list_parishes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pa.ParishID, CONCAT(d.Name, N' / ', m.Name, N' / ', pa.Name) AS Label
    FROM PARISH pa
    JOIN MUNICIPALITY m ON m.MunicipalityID = pa.MunicipalityID
    JOIN DISTRICT d ON d.DistrictID = m.DistrictID
    ORDER BY d.Name, m.Name, pa.Name;
END;
GO

CREATE OR ALTER PROCEDURE sp_ref_list_schemes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SchemeID, Name AS Label FROM SUPPLY_SCHEME ORDER BY Name;
END;
GO
