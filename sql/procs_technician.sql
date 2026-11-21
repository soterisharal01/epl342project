-- =====================================================================
-- procs_technician.sql : τεχνικοί πεδίου (περιοχή TEC, εργασία TEC-1 και επόμενες).
-- Λάθη (THROW): 52000-52499 (TEC). Τρέχει μετά το procs_common.sql.
-- TEC-1: εγγραφή τεχνικού (ΙΙΙ.2.1), κατηγορίες, έλεγχος ρόλου.
-- Κανόνας: η PHP καλεί μόνο αυτά τα procedures με ? παραμέτρους.
-- 52000 ρόλος | 52001 username | 52002 username υπάρχει | 52003 email | 52004 ηλικία
-- 52005 φωτογραφία | 52006 κατηγορίες | 52007 τηλέφωνο
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_tech_assert: ο χρήστης πρέπει να είναι ενεργός ΕΓΚΕΚΡΙΜΕΝΟΣ τεχνικός.
-- Ένας Pending/Rejected/Suspended τεχνικός δεν κάνει τίποτα (ΙΙΙ.2.1).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @UserID AND Role = 'Technician'
                     AND AccountStatus = 'Active' AND ApprovalStatus = 'Approved')
        THROW 52000, N'Δεν επιτρέπεται: μόνο για εγκεκριμένο ενεργό Τεχνικό.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- sp_ref_list_tech_categories: κατηγορίες για τη φόρμα εγγραφής (δημόσια λίστα).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ref_list_tech_categories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CategoryID, Name AS Label FROM TECHNICIAN_CATEGORY ORDER BY Name;
END;
GO

-- ---------------------------------------------------------------------
-- sp_auth_register_technician: self-registration τεχνικού (ΙΙΙ.2.1).
-- Role Technician, ApprovalStatus Pending (ο Operator εγκρίνει στο TEC-4).
-- AccountStatus Active, αλλά το login και το sp_tech_assert τον αποκλείουν
-- μέχρι την έγκριση. @CategoryIDs = λίστα 'CategoryID,CategoryID' (π.χ. '1,2').
-- @Photo = διαδρομή αρχείου φωτογραφίας. Επιστρέφει: UserID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_auth_register_technician
    @Username NVARCHAR(50), @PasswordHash VARCHAR(255), @Email VARCHAR(254),
    @Phone VARCHAR(20), @FirstName NVARCHAR(50), @LastName NVARCHAR(50),
    @BirthDate DATE, @Photo NVARCHAR(400), @CategoryIDs VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Username IS NULL OR LEN(@Username) < 3
        THROW 52001, N'Το username πρέπει να έχει τουλάχιστον 3 χαρακτήρες.', 1;
    IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE Username = @Username)
        THROW 52002, N'Το username υπάρχει ήδη. Διαλέξτε άλλο.', 1;
    IF @Email IS NULL OR @Email NOT LIKE '%_@_%._%'
        THROW 52003, N'Μη έγκυρο email.', 1;
    IF @Phone IS NOT NULL AND @Phone LIKE '%[^0-9+ ]%'
        THROW 52007, N'Το τηλέφωνο μπορεί να έχει μόνο ψηφία, + και κενά.', 1;
    IF @BirthDate IS NULL OR @BirthDate > DATEADD(YEAR, -18, CAST(SYSUTCDATETIME() AS DATE))
        THROW 52004, N'Ο τεχνικός πρέπει να είναι τουλάχιστον 18 ετών.', 1;
    IF @Photo IS NULL OR LTRIM(RTRIM(@Photo)) = N''
        THROW 52005, N'Η φωτογραφία είναι υποχρεωτική.', 1;

    -- Κατηγορίες: κάθε στοιχείο της λίστας πρέπει να είναι υπαρκτή κατηγορία, τουλάχιστον μία.
    DECLARE @cats TABLE (CategoryID INT NULL);
    INSERT @cats (CategoryID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@CategoryIDs, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF NOT EXISTS (SELECT 1 FROM @cats)
       OR EXISTS (SELECT 1 FROM @cats c
                  WHERE c.CategoryID IS NULL
                     OR NOT EXISTS (SELECT 1 FROM TECHNICIAN_CATEGORY t WHERE t.CategoryID = c.CategoryID))
        THROW 52006, N'Διαλέξτε τουλάχιστον μία έγκυρη κατηγορία.', 1;

    BEGIN TRY
        BEGIN TRAN;
        INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, Phone, FirstName, LastName,
                             AccountStatus, BirthDate, Photo, ApprovalStatus)
        VALUES (@Username, @PasswordHash, 'Technician', @Email, NULLIF(@Phone, ''), @FirstName, @LastName,
                'Active', @BirthDate, LTRIM(RTRIM(@Photo)), 'Pending');
        DECLARE @id INT = SCOPE_IDENTITY();
        INSERT IN_CATEGORY (UserID, CategoryID) SELECT @id, CategoryID FROM @cats;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('USER_ACCOUNT', @id, 'Register technician', 'Pending', @id);
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
-- sp_tech_list_categories: οι κατηγορίες του ίδιου του τεχνικού.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_categories
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert @UserID;
    SELECT t.CategoryID, t.Name AS Label
    FROM IN_CATEGORY ic
    JOIN TECHNICIAN_CATEGORY t ON t.CategoryID = ic.CategoryID
    WHERE ic.UserID = @UserID
    ORDER BY t.Name;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_set_categories: ο εγκεκριμένος τεχνικός αντικαθιστά τις κατηγορίες του
-- (τουλάχιστον μία). @CategoryIDs = 'CategoryID,CategoryID'.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_set_categories
    @UserID INT, @CategoryIDs VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    DECLARE @cats TABLE (CategoryID INT NULL);
    INSERT @cats (CategoryID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@CategoryIDs, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF NOT EXISTS (SELECT 1 FROM @cats)
       OR EXISTS (SELECT 1 FROM @cats c
                  WHERE c.CategoryID IS NULL
                     OR NOT EXISTS (SELECT 1 FROM TECHNICIAN_CATEGORY t WHERE t.CategoryID = c.CategoryID))
        THROW 52006, N'Διαλέξτε τουλάχιστον μία έγκυρη κατηγορία.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old NVARCHAR(400) =
            (SELECT STRING_AGG(CAST(CategoryID AS NVARCHAR(10)), ',') WITHIN GROUP (ORDER BY CategoryID)
             FROM IN_CATEGORY WHERE UserID = @UserID);
        DECLARE @new NVARCHAR(400) =
            (SELECT STRING_AGG(CAST(CategoryID AS NVARCHAR(10)), ',') WITHIN GROUP (ORDER BY CategoryID)
             FROM @cats);
        DELETE FROM IN_CATEGORY WHERE UserID = @UserID;
        INSERT IN_CATEGORY (UserID, CategoryID) SELECT @UserID, CategoryID FROM @cats;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('USER_ACCOUNT', @UserID, 'Set technician categories', @old, @new, @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
