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

-- =====================================================================
-- TEC-5: εργασίες πεδίου (ΙΙΙ.2.2). Λάθη 52100-52199.
-- 52100 ρόλος Operator | 52101 τύπος εργασίας | 52102 χρονοδιάγραμμα | 52103 τεχνικός μη εγκεκριμένος
-- 52104 αίτημα όχι Submitted | 52105 αίτημα δεν υπάρχει | 52106 υποστατικό ≠ αίτημα | 52107 χωρίς στόχο
-- 52108 Installation/Replacement θέλει υποστατικό | 52109 Installation με μετρητή | 52110 Replacement χωρίς μετρητή
-- 52111 υποστατικό/μετρητής δεν υπάρχει | 52112 εκτός διαθεσιμότητας | 52113 άγνωστος χρήστης ειδοποίησης
-- 52120 εργασία δεν υπάρχει / δεν είναι δική σας | 52121 αλλαγή τεχνικού μόνο σε Assigned
-- 52122 ακύρωση σε Done/Cancelled | 52123 αποδοχή μόνο από Assigned | 52124 εργασία Cancelled
-- 52125 είδος σημείωσης | 52126 κενό κείμενο/διαδρομή | 52127 ολοκλήρωση μόνο από Accepted
-- 52128 κενό αποτέλεσμα | 52129 κενός λόγος ακύρωσης | 52130 άκυρο φίλτρο Status
-- Συμφωνία X1: το TEC αλλάζει SERVICE_REQUEST.Status ΜΟΝΟ σε 'Assigned' (δημιουργία εργασίας)
-- και σε 'Resolved' (εργασία Done). Η ακύρωση εργασίας ΔΕΝ γυρίζει το αίτημα (X1).
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_operator_assert: ο χρήστης πρέπει να είναι ενεργός Operator (δεν υπήρχε άλλο).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @UserID AND Role = 'Operator' AND AccountStatus = 'Active')
        THROW 52100, N'Δεν επιτρέπεται: μόνο για ενεργό Operator.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- fn_task_slot_ok: inline table-valued function (όχι scalar, όχι dbo).
-- Επιστρέφει μία γραμμή αν ο τεχνικός μπορεί να πάρει το χρονικό παράθυρο:
--  * αν ΔΕΝ έχει δηλώσει καμία διαθεσιμότητα εκείνη την ημέρα, επιτρέπεται
--    (η δήλωση διαθεσιμότητας είναι προαιρετική), ή
--  * το παράθυρο ξεκινά και τελειώνει την ίδια μέρα και χωράει μέσα σε μία δηλωμένη ζώνη.
-- ---------------------------------------------------------------------
CREATE OR ALTER FUNCTION fn_task_slot_ok (@TechnicianID INT, @From DATETIME2(0), @To DATETIME2(0))
RETURNS TABLE
AS
RETURN (
    SELECT 1 AS Ok
    WHERE NOT EXISTS (SELECT 1 FROM AVAILABILITY a
                      WHERE a.UserID = @TechnicianID AND a.AvailDate = CAST(@From AS DATE))
       OR EXISTS (SELECT 1 FROM AVAILABILITY a
                  WHERE a.UserID = @TechnicianID AND a.AvailDate = CAST(@From AS DATE)
                    AND CAST(@To AS DATE) = CAST(@From AS DATE)
                    AND a.FromTime <= CAST(@From AS TIME(0)) AND a.ToTime >= CAST(@To AS TIME(0)))
);
GO

-- ---------------------------------------------------------------------
-- sp_task_assert_view: Operator (οποιαδήποτε εργασία) ή εγκεκριμένος τεχνικός (μόνο δική του).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_assert_view
    @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'Operator' AND AccountStatus = 'Active')
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @TaskID)
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        RETURN;
    END;
    EXEC sp_tech_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @TaskID AND TechnicianID = @UserID)
        THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_create: ο Operator δημιουργεί και αναθέτει εργασία. Επιστρέφει: TaskID.
-- @NotifyUserIDs = 'UserID,UserID' (προαιρετικό). Αν δοθεί @RequestID: το αίτημα πρέπει να είναι
-- 'Submitted', το υποστατικό του γίνεται υποστατικό της εργασίας, το αίτημα γίνεται 'Assigned' (X1)
-- και ο καταναλωτής που το υπέβαλε ειδοποιείται (NOTIFIES).
-- Διαθεσιμότητα: αν ο τεχνικός έχει δηλώσει ζώνες εκείνη την ημέρα, το παράθυρο πρέπει να χωράει
-- σε μία. Αν δεν έχει δηλώσει καμία, επιτρέπεται.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_create
    @UserID INT, @TaskType VARCHAR(17), @ScheduledFrom DATETIME2(0), @ScheduledTo DATETIME2(0),
    @TechnicianID INT, @PremiseID INT = NULL, @MeterID INT = NULL, @RequestID INT = NULL,
    @NotifyUserIDs VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @TaskType IS NULL OR @TaskType NOT IN ('Installation', 'Replacement', 'Technical check', 'Anti-tamper check')
        THROW 52101, N'Μη έγκυρος τύπος εργασίας.', 1;
    IF @ScheduledFrom IS NULL OR @ScheduledTo IS NULL OR @ScheduledTo <= @ScheduledFrom
        THROW 52102, N'Η λήξη του χρονοδιαγράμματος πρέπει να είναι μετά την έναρξη.', 1;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @TechnicianID AND Role = 'Technician'
                     AND AccountStatus = 'Active' AND ApprovalStatus = 'Approved')
        THROW 52103, N'Ο τεχνικός πρέπει να είναι ενεργός και εγκεκριμένος.', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_task_slot_ok(@TechnicianID, @ScheduledFrom, @ScheduledTo))
        THROW 52112, N'Ο τεχνικός δεν είναι διαθέσιμος στο χρονικό παράθυρο που δηλώνει για εκείνη την ημέρα.', 1;

    -- Λίστα ειδοποίησης: κάθε στοιχείο πρέπει να είναι υπαρκτός ενεργός χρήστης.
    DECLARE @notify TABLE (UserID INT NULL);
    INSERT @notify (UserID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@NotifyUserIDs, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF EXISTS (SELECT 1 FROM @notify n
               WHERE n.UserID IS NULL
                  OR NOT EXISTS (SELECT 1 FROM USER_ACCOUNT u WHERE u.UserID = n.UserID AND u.AccountStatus = 'Active'))
        THROW 52113, N'Η λίστα ειδοποίησης έχει άγνωστο ή ανενεργό χρήστη.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @reqUser INT = NULL, @reqPremise INT = NULL, @reqStatus VARCHAR(9) = NULL;
        IF @RequestID IS NOT NULL
        BEGIN
            -- UPDLOCK: δύο Operators δεν μπορούν να αναθέσουν το ίδιο αίτημα ταυτόχρονα.
            SELECT @reqUser = UserID, @reqPremise = PremiseID, @reqStatus = Status
            FROM SERVICE_REQUEST WITH (UPDLOCK) WHERE RequestID = @RequestID;
            IF @reqStatus IS NULL
                THROW 52105, N'Το αίτημα δεν υπάρχει.', 1;
            IF @reqStatus <> 'Submitted'
                THROW 52104, N'Το αίτημα δεν είναι σε κατάσταση Submitted.', 1;
            IF @PremiseID IS NOT NULL AND @PremiseID <> @reqPremise
                THROW 52106, N'Το υποστατικό δεν ταιριάζει με το υποστατικό του αιτήματος.', 1;
            SET @PremiseID = @reqPremise;
        END;

        IF @PremiseID IS NULL AND @MeterID IS NULL
            THROW 52107, N'Η εργασία χρειάζεται υποστατικό ή μετρητή.', 1;
        IF @TaskType IN ('Installation', 'Replacement') AND @PremiseID IS NULL
            THROW 52108, N'Η εγκατάσταση/αντικατάσταση χρειάζεται υποστατικό.', 1;
        IF @TaskType = 'Installation' AND @MeterID IS NOT NULL
            THROW 52109, N'Η εγκατάσταση δεν έχει υπάρχοντα μετρητή.', 1;
        IF @TaskType = 'Replacement' AND @MeterID IS NULL
            THROW 52110, N'Η αντικατάσταση χρειάζεται τον μετρητή που αντικαθίσταται.', 1;
        IF (@PremiseID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PREMISE WHERE PremiseID = @PremiseID))
           OR (@MeterID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM METER WHERE MeterID = @MeterID))
            THROW 52111, N'Το υποστατικό ή ο μετρητής δεν υπάρχει.', 1;

        INSERT FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, Status, TechnicianID, PremiseID, MeterID, RequestID)
        VALUES (@TaskType, @ScheduledFrom, @ScheduledTo, 'Assigned', @TechnicianID, @PremiseID, @MeterID, @RequestID);
        DECLARE @taskId INT = SCOPE_IDENTITY();

        INSERT NOTIFIES (TaskID, UserID)
        SELECT @taskId, UserID FROM (SELECT UserID FROM @notify UNION SELECT @reqUser WHERE @reqUser IS NOT NULL) x;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, ResultComment, PerformedBy)
        VALUES ('FIELD_TASK', CAST(@taskId AS VARCHAR(100)), 'Create task', 'Assigned',
                CONCAT(N'Τύπος: ', @TaskType, N', τεχνικός: ', @TechnicianID), @UserID);

        IF @RequestID IS NOT NULL
        BEGIN
            UPDATE SERVICE_REQUEST SET Status = 'Assigned' WHERE RequestID = @RequestID;   -- X1
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
            VALUES ('SERVICE_REQUEST', CAST(@RequestID AS VARCHAR(100)), 'Assign request', 'Submitted', 'Assigned',
                    CONCAT(N'Εργασία ', @taskId), @UserID);
        END;
        COMMIT;
        SELECT @taskId AS TaskID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_reassign: αλλαγή τεχνικού, μόνο όσο η εργασία είναι 'Assigned'.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_reassign
    @UserID INT, @TaskID INT, @TechnicianID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @TechnicianID AND Role = 'Technician'
                     AND AccountStatus = 'Active' AND ApprovalStatus = 'Approved')
        THROW 52103, N'Ο τεχνικός πρέπει να είναι ενεργός και εγκεκριμένος.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9), @oldTech INT, @from DATETIME2(0), @to DATETIME2(0);
        SELECT @status = Status, @oldTech = TechnicianID, @from = ScheduledFrom, @to = ScheduledTo
        FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID;
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει.', 1;
        IF @status <> 'Assigned'
            THROW 52121, N'Ο τεχνικός αλλάζει μόνο όσο η εργασία είναι Assigned.', 1;
        IF NOT EXISTS (SELECT 1 FROM fn_task_slot_ok(@TechnicianID, @from, @to))
            THROW 52112, N'Ο τεχνικός δεν είναι διαθέσιμος στο χρονικό παράθυρο που δηλώνει για εκείνη την ημέρα.', 1;
        UPDATE FIELD_TASK SET TechnicianID = @TechnicianID WHERE TaskID = @TaskID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('FIELD_TASK', CAST(@TaskID AS VARCHAR(100)), 'Reassign task',
                CONCAT(N'Τεχνικός ', @oldTech), CONCAT(N'Τεχνικός ', @TechnicianID), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_cancel: ακύρωση εργασίας (όχι Done, όχι ήδη Cancelled). Ο λόγος είναι υποχρεωτικός.
-- Το αίτημα δεν αλλάζει (X1 επιτρέπει μόνο Assigned/Resolved).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_cancel
    @UserID INT, @TaskID INT, @Reason NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @Reason IS NULL OR LTRIM(RTRIM(@Reason)) = N''
        THROW 52129, N'Ο λόγος ακύρωσης είναι υποχρεωτικός.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9) = (SELECT Status FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID);
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει.', 1;
        IF @status IN ('Done', 'Cancelled')
            THROW 52122, N'Δεν ακυρώνεται εργασία που είναι ήδη ολοκληρωμένη ή ακυρωμένη.', 1;
        UPDATE FIELD_TASK SET Status = 'Cancelled' WHERE TaskID = @TaskID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('FIELD_TASK', CAST(@TaskID AS VARCHAR(100)), 'Cancel task', @status, 'Cancelled',
                LTRIM(RTRIM(@Reason)), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_list: ο Operator βλέπει όλες τις εργασίες (προαιρετικό φίλτρο Status).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_list
    @UserID INT, @Status VARCHAR(9) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    IF @Status IS NOT NULL AND @Status NOT IN ('Assigned', 'Accepted', 'Done', 'Cancelled')
        THROW 52130, N'Μη έγκυρο φίλτρο κατάστασης.', 1;
    SELECT t.TaskID, t.TaskType, t.ScheduledFrom, t.ScheduledTo, t.Status, t.Result, t.CompletedAt,
           t.TechnicianID, u.Username AS TechnicianUsername,
           t.PremiseID, p.Address, t.MeterID, t.RequestID
    FROM FIELD_TASK t
    JOIN USER_ACCOUNT u ON u.UserID = t.TechnicianID
    LEFT JOIN PREMISE p ON p.PremiseID = t.PremiseID
    WHERE @Status IS NULL OR t.Status = @Status
    ORDER BY t.ScheduledFrom DESC, t.TaskID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_list_requests: αιτήματα Submitted που περιμένουν ανάθεση (για τη φόρμα του Operator).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_list_requests
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT r.RequestID, r.RequestType, r.Description, r.SubmittedAt, r.UserID, r.PremiseID, p.Address, r.MeterID
    FROM SERVICE_REQUEST r
    JOIN PREMISE p ON p.PremiseID = r.PremiseID
    WHERE r.Status = 'Submitted'
    ORDER BY r.SubmittedAt;
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_list_technicians: ενεργοί εγκεκριμένοι τεχνικοί, για επιλογή στη φόρμα ανάθεσης.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_list_technicians
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT UserID, Username, FirstName, LastName
    FROM USER_ACCOUNT
    WHERE Role = 'Technician' AND AccountStatus = 'Active' AND ApprovalStatus = 'Approved'
    ORDER BY Username;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_list_tasks: οι δικές μου εργασίες. Latitude/Longitude: ο μετρητής αν υπάρχει
-- (ακριβής θέση), αλλιώς το υποστατικό.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_tasks
    @UserID INT, @Status VARCHAR(9) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert @UserID;
    IF @Status IS NOT NULL AND @Status NOT IN ('Assigned', 'Accepted', 'Done', 'Cancelled')
        THROW 52130, N'Μη έγκυρο φίλτρο κατάστασης.', 1;
    SELECT t.TaskID, t.TaskType, t.ScheduledFrom, t.ScheduledTo, t.Status,
           t.PremiseID, p.Address,
           COALESCE(m.Latitude, p.Latitude) AS Latitude, COALESCE(m.Longitude, p.Longitude) AS Longitude,
           t.MeterID, m.SerialNumber, t.RequestID, r.Description AS RequestDescription
    FROM FIELD_TASK t
    LEFT JOIN PREMISE p ON p.PremiseID = t.PremiseID
    LEFT JOIN METER m ON m.MeterID = t.MeterID
    LEFT JOIN SERVICE_REQUEST r ON r.RequestID = t.RequestID
    WHERE t.TechnicianID = @UserID AND (@Status IS NULL OR t.Status = @Status)
    ORDER BY t.ScheduledFrom DESC, t.TaskID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_accept_task: δική μου εργασία, 'Assigned' -> 'Accepted'.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_accept_task
    @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9) =
            (SELECT Status FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID);
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @status <> 'Assigned'
            THROW 52123, N'Αποδοχή γίνεται μόνο σε εργασία Assigned.', 1;
        UPDATE FIELD_TASK SET Status = 'Accepted' WHERE TaskID = @TaskID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('FIELD_TASK', CAST(@TaskID AS VARCHAR(100)), 'Accept task', 'Assigned', 'Accepted', @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_add_note: σημείωση (Observation/Finding) σε δική μου εργασία που δεν είναι Cancelled.
-- Το NoteNo είναι ανά εργασία (PK TaskID+NoteNo). Αν δύο σημειώσεις γράφονται ταυτόχρονα, και οι δύο
-- θα διάβαζαν το ίδιο MAX και η δεύτερη θα έσκαγε στο PK. Γι' αυτό κλειδώνουμε πρώτα τη γραμμή της
-- εργασίας με UPDLOCK (δύο UPDLOCK δεν συνυπάρχουν: η δεύτερη περιμένει), και μετά διαβάζουμε το MAX
-- με UPDLOCK, HOLDLOCK. Έτσι οι εγγραφές της ίδιας εργασίας γίνονται σειριακά. Επιστρέφει: NoteNo.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_add_note
    @UserID INT, @TaskID INT, @NoteKind VARCHAR(11), @Text NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @NoteKind IS NULL OR @NoteKind NOT IN ('Observation', 'Finding')
        THROW 52125, N'Το είδος σημείωσης πρέπει να είναι Observation ή Finding.', 1;
    IF @Text IS NULL OR LTRIM(RTRIM(@Text)) = N''
        THROW 52126, N'Το κείμενο της σημείωσης είναι υποχρεωτικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9) =
            (SELECT Status FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID);
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @status = 'Cancelled'
            THROW 52124, N'Η εργασία έχει ακυρωθεί.', 1;
        DECLARE @no INT = (SELECT ISNULL(MAX(NoteNo), 0) + 1 FROM TASK_NOTE WITH (UPDLOCK, HOLDLOCK) WHERE TaskID = @TaskID);
        INSERT TASK_NOTE (TaskID, NoteNo, NoteKind, Text, WrittenBy)
        VALUES (@TaskID, @no, @NoteKind, LTRIM(RTRIM(@Text)), @UserID);
        COMMIT;
        SELECT @no AS NoteNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_add_attachment: αποδεικτικό (διαδρομή αρχείου) σε δική μου εργασία που δεν είναι Cancelled.
-- Επιστρέφει: AttachmentID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_add_attachment
    @UserID INT, @TaskID INT, @FilePath NVARCHAR(400), @Caption NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @FilePath IS NULL OR LTRIM(RTRIM(@FilePath)) = N''
        THROW 52126, N'Η διαδρομή του αρχείου είναι υποχρεωτική.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9) =
            (SELECT Status FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID);
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @status = 'Cancelled'
            THROW 52124, N'Η εργασία έχει ακυρωθεί.', 1;
        INSERT ATTACHMENT (FilePath, Caption, TaskID)
        VALUES (LTRIM(RTRIM(@FilePath)), NULLIF(LTRIM(RTRIM(@Caption)), N''), @TaskID);
        DECLARE @aid INT = SCOPE_IDENTITY();
        COMMIT;
        SELECT @aid AS AttachmentID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_complete_task: δική μου εργασία, 'Accepted' -> 'Done' με CompletedAt και Result.
-- Αν προήλθε από αίτημα, το αίτημα γίνεται 'Resolved' (X1).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_complete_task
    @UserID INT, @TaskID INT, @Result NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @Result IS NULL OR LTRIM(RTRIM(@Result)) = N''
        THROW 52128, N'Το αποτέλεσμα της εργασίας είναι υποχρεωτικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(9), @reqId INT;
        SELECT @status = Status, @reqId = RequestID
        FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID;
        IF @status IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @status <> 'Accepted'
            THROW 52127, N'Ολοκλήρωση γίνεται μόνο σε εργασία που έχετε αποδεχθεί (Accepted).', 1;
        UPDATE FIELD_TASK
        SET Status = 'Done', CompletedAt = SYSUTCDATETIME(), Result = LTRIM(RTRIM(@Result))
        WHERE TaskID = @TaskID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('FIELD_TASK', CAST(@TaskID AS VARCHAR(100)), 'Complete task', 'Accepted', 'Done',
                LTRIM(RTRIM(@Result)), @UserID);
        IF @reqId IS NOT NULL
        BEGIN
            DECLARE @reqOld VARCHAR(9) = (SELECT Status FROM SERVICE_REQUEST WITH (UPDLOCK) WHERE RequestID = @reqId);
            UPDATE SERVICE_REQUEST SET Status = 'Resolved' WHERE RequestID = @reqId;   -- X1
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
            VALUES ('SERVICE_REQUEST', CAST(@reqId AS VARCHAR(100)), 'Resolve request', @reqOld, 'Resolved',
                    CONCAT(N'Εργασία ', @TaskID), @UserID);
        END;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_task_get: η γραμμή της εργασίας (ένα result set). Operator: οποιαδήποτε· τεχνικός: μόνο δική του.
-- Οι σημειώσεις και τα συνημμένα έρχονται από sp_task_notes και sp_task_attachments.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_task_get
    @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_task_assert_view @UserID, @TaskID;
    SELECT t.TaskID, t.TaskType, t.ScheduledFrom, t.ScheduledTo, t.Status, t.Result, t.CreatedAt, t.CompletedAt,
           t.TechnicianID, u.Username AS TechnicianUsername,
           t.PremiseID, p.Address,
           COALESCE(m.Latitude, p.Latitude) AS Latitude, COALESCE(m.Longitude, p.Longitude) AS Longitude,
           t.MeterID, m.SerialNumber, t.RequestID, r.Description AS RequestDescription
    FROM FIELD_TASK t
    JOIN USER_ACCOUNT u ON u.UserID = t.TechnicianID
    LEFT JOIN PREMISE p ON p.PremiseID = t.PremiseID
    LEFT JOIN METER m ON m.MeterID = t.MeterID
    LEFT JOIN SERVICE_REQUEST r ON r.RequestID = t.RequestID
    WHERE t.TaskID = @TaskID;
END;
GO

CREATE OR ALTER PROCEDURE sp_task_notes
    @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_task_assert_view @UserID, @TaskID;
    SELECT n.NoteNo, n.NoteKind, n.Text, n.WrittenAt, n.WrittenBy, u.Username AS WrittenByUsername
    FROM TASK_NOTE n JOIN USER_ACCOUNT u ON u.UserID = n.WrittenBy
    WHERE n.TaskID = @TaskID
    ORDER BY n.NoteNo;
END;
GO

CREATE OR ALTER PROCEDURE sp_task_attachments
    @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_task_assert_view @UserID, @TaskID;
    SELECT AttachmentID, FilePath, Caption, UploadedAt
    FROM ATTACHMENT WHERE TaskID = @TaskID
    ORDER BY AttachmentID;
END;
GO

-- =====================================================================
-- TEC-2 / TEC-3 / TEC-4: έγγραφα τεχνικού, διαθεσιμότητα, έγκριση από τον Operator.
-- Λάθη (THROW) 52300-52499:
-- 52300 ρόλος/κατάσταση τεχνικού | 52301 τύπος εγγράφου | 52302 αριθμός εγγράφου
-- 52303 ημερομηνίες εγγράφου | 52304 αρχείο εγγράφου
-- 52310 ημερομηνία στο παρελθόν | 52311 ώρες | 52312 επικάλυψη | 52313 δήμοι
-- 52314 διαθεσιμότητα δεν βρέθηκε | 52315 εργασία μέσα στη ζώνη
-- 52320 τεχνικός δεν βρέθηκε | 52321 έγγραφο δεν βρέθηκε | 52322 έγγραφο ήδη ελεγμένο
-- 52324 απόφαση μόνο σε εκκρεμή τεχνικό | 52325 λείπουν αποδεκτά έγγραφα
-- 52326 απαιτείται σχόλιο | 52327 μη έγκυρη κατάσταση | 52328 μη επιτρεπτή μετάβαση
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_tech_assert_any: ενεργός Τεχνικός με οποιαδήποτε κατάσταση έγκρισης εκτός Rejected.
-- Για ό,τι πρέπει να κάνει ο τεχνικός ΠΡΙΝ εγκριθεί (π.χ. να ανεβάσει έγγραφα).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_assert_any
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @UserID AND Role = 'Technician' AND AccountStatus = 'Active'
                     AND ApprovalStatus IN ('Pending', 'Approved', 'Suspended'))
        THROW 52300, N'Δεν επιτρέπεται: μόνο για ενεργό Τεχνικό που δεν έχει απορριφθεί.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_add_document: ο τεχνικός καταθέτει έγγραφο (ID card, Installer licence,
-- Training certificate). ReviewStatus 'Pending'. Επιστρέφει: DocumentID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_add_document
    @UserID INT, @DocType VARCHAR(27), @DocNumber NVARCHAR(50), @IssueDate DATE,
    @ExpiryDate DATE = NULL, @FilePath NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert_any @UserID;
    IF @DocType IS NULL OR @DocType NOT IN ('ID card', 'Installer licence', 'Training certificate')
        THROW 52301, N'Μη έγκυρος τύπος εγγράφου τεχνικού (ID card, Installer licence, Training certificate).', 1;
    IF @DocNumber IS NULL OR LTRIM(RTRIM(@DocNumber)) = N''
        THROW 52302, N'Ο αριθμός εγγράφου είναι υποχρεωτικός.', 1;
    IF @IssueDate IS NULL OR @IssueDate > CAST(SYSUTCDATETIME() AS DATE)
       OR (@ExpiryDate IS NOT NULL AND @ExpiryDate <= @IssueDate)
        THROW 52303, N'Η έκδοση δεν μπορεί να είναι στο μέλλον και η λήξη πρέπει να είναι μετά την έκδοση.', 1;
    IF @FilePath IS NULL OR LTRIM(RTRIM(@FilePath)) = N''
        THROW 52304, N'Το αρχείο του εγγράφου είναι υποχρεωτικό.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT DOCUMENT (DocType, DocNumber, IssueDate, ExpiryDate, FilePath, ReviewStatus, TechnicianID)
        VALUES (@DocType, LTRIM(RTRIM(@DocNumber)), @IssueDate, @ExpiryDate, LTRIM(RTRIM(@FilePath)), 'Pending', @UserID);
        DECLARE @doc INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('DOCUMENT', CAST(@doc AS VARCHAR(100)), 'Add technician document', 'Pending', @UserID);
        COMMIT;
        SELECT @doc AS DocumentID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_list_documents: τα δικά μου έγγραφα (και η κρίση του Operator).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_documents
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert_any @UserID;
    SELECT DocumentID, DocType, DocNumber, IssueDate, ExpiryDate, FilePath,
           ReviewStatus, ReviewComment, ReviewedAt
    FROM DOCUMENT
    WHERE TechnicianID = @UserID
    ORDER BY DocType, DocumentID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_ref_list_municipalities: δήμοι για τη φόρμα διαθεσιμότητας.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ref_list_municipalities
AS
BEGIN
    SET NOCOUNT ON;
    SELECT m.MunicipalityID, m.Name + N' (' + d.Name + N')' AS Label
    FROM MUNICIPALITY m
    JOIN DISTRICT d ON d.DistrictID = m.DistrictID
    ORDER BY d.Name, m.Name;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_declare_availability: ημερήσια διαθεσιμότητα (ώρες + δήμοι). Εγκεκριμένος τεχνικός.
-- @MunicipalityIDs = 'ID,ID'. Όχι στο παρελθόν, ώρες From < To, χωρίς επικάλυψη την ίδια μέρα,
-- τουλάχιστον ένας δήμος και όλοι υπαρκτοί. AVAILABILITY + AVAILABLE_IN σε μία συναλλαγή.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_declare_availability
    @UserID INT, @AvailDate DATE, @FromTime TIME(0), @ToTime TIME(0), @MunicipalityIDs VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @AvailDate IS NULL OR @AvailDate < CAST(SYSUTCDATETIME() AS DATE)
        THROW 52310, N'Η διαθεσιμότητα δεν μπορεί να δηλωθεί για ημερομηνία στο παρελθόν.', 1;
    IF @FromTime IS NULL OR @ToTime IS NULL OR @ToTime <= @FromTime
        THROW 52311, N'Η ώρα λήξης πρέπει να είναι μετά την ώρα έναρξης.', 1;
    DECLARE @munis TABLE (MunicipalityID INT NULL);
    INSERT @munis (MunicipalityID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@MunicipalityIDs, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF NOT EXISTS (SELECT 1 FROM @munis)
       OR EXISTS (SELECT 1 FROM @munis x
                  WHERE x.MunicipalityID IS NULL
                     OR NOT EXISTS (SELECT 1 FROM MUNICIPALITY m WHERE m.MunicipalityID = x.MunicipalityID))
        THROW 52313, N'Διαλέξτε τουλάχιστον έναν έγκυρο δήμο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        -- Κλείδωμα των ζωνών της ημέρας ώστε δύο ταυτόχρονες δηλώσεις να μην επικαλυφθούν.
        IF EXISTS (SELECT 1 FROM AVAILABILITY WITH (UPDLOCK, HOLDLOCK)
                   WHERE UserID = @UserID AND AvailDate = @AvailDate
                     AND FromTime < @ToTime AND ToTime > @FromTime)
            THROW 52312, N'Η ζώνη επικαλύπτεται με άλλη δηλωμένη ζώνη της ίδιας ημέρας.', 1;
        INSERT AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (@UserID, @AvailDate, @FromTime, @ToTime);
        INSERT AVAILABLE_IN (UserID, AvailDate, FromTime, MunicipalityID)
        SELECT @UserID, @AvailDate, @FromTime, MunicipalityID FROM @munis;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_list_availability: οι δικές μου ζώνες, προαιρετικά από/έως ημερομηνία.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_availability
    @UserID INT, @From DATE = NULL, @To DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert @UserID;
    SELECT a.AvailDate, a.FromTime, a.ToTime,
           (SELECT STRING_AGG(m.Name, N', ') WITHIN GROUP (ORDER BY m.Name)
            FROM AVAILABLE_IN ai JOIN MUNICIPALITY m ON m.MunicipalityID = ai.MunicipalityID
            WHERE ai.UserID = a.UserID AND ai.AvailDate = a.AvailDate AND ai.FromTime = a.FromTime) AS Municipalities
    FROM AVAILABILITY a
    WHERE a.UserID = @UserID
      AND (@From IS NULL OR a.AvailDate >= @From)
      AND (@To IS NULL OR a.AvailDate <= @To)
    ORDER BY a.AvailDate, a.FromTime;
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_remove_availability: διαγραφή ζώνης (το PK είναι UserID+AvailDate+FromTime).
-- Απορρίπτεται αν μη ακυρωμένη εργασία του τεχνικού επικαλύπτει τη ζώνη.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_remove_availability
    @UserID INT, @AvailDate DATE, @FromTime TIME(0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @ToTime TIME(0) =
            (SELECT ToTime FROM AVAILABILITY WITH (UPDLOCK)
             WHERE UserID = @UserID AND AvailDate = @AvailDate AND FromTime = @FromTime);
        IF @ToTime IS NULL
            THROW 52314, N'Η ζώνη διαθεσιμότητας δεν βρέθηκε.', 1;
        DECLARE @slotFrom DATETIME2(0) = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME(0)), @FromTime), CAST(@AvailDate AS DATETIME2(0)));
        DECLARE @slotTo DATETIME2(0) = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME(0)), @ToTime), CAST(@AvailDate AS DATETIME2(0)));
        IF EXISTS (SELECT 1 FROM FIELD_TASK
                   WHERE TechnicianID = @UserID AND Status <> 'Cancelled'
                     AND ScheduledFrom < @slotTo AND ScheduledTo > @slotFrom)
            THROW 52315, N'Υπάρχει ενεργή εργασία μέσα στη ζώνη. Ακυρώστε ή αναθέστε την πρώτα.', 1;
        DELETE FROM AVAILABILITY WHERE UserID = @UserID AND AvailDate = @AvailDate AND FromTime = @FromTime;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_list_pending_technicians: τεχνικοί σε κατάσταση Pending, με κατηγορίες
-- και πλήθος εγγράφων ανά κατάσταση ελέγχου.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_list_pending_technicians
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT u.UserID AS TechnicianID, u.Username, u.FirstName, u.LastName, u.Email, u.Phone, u.BirthDate, u.Photo,
           (SELECT STRING_AGG(t.Name, N', ') WITHIN GROUP (ORDER BY t.Name)
            FROM IN_CATEGORY ic JOIN TECHNICIAN_CATEGORY t ON t.CategoryID = ic.CategoryID
            WHERE ic.UserID = u.UserID) AS Categories,
           (SELECT COUNT(*) FROM DOCUMENT d WHERE d.TechnicianID = u.UserID AND d.ReviewStatus = 'Pending') AS DocsPending,
           (SELECT COUNT(*) FROM DOCUMENT d WHERE d.TechnicianID = u.UserID AND d.ReviewStatus = 'Accepted') AS DocsAccepted,
           (SELECT COUNT(*) FROM DOCUMENT d WHERE d.TechnicianID = u.UserID AND d.ReviewStatus = 'Rejected') AS DocsRejected
    FROM USER_ACCOUNT u
    WHERE u.Role = 'Technician' AND u.ApprovalStatus = 'Pending'
    ORDER BY u.UserID;
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_list_technician_documents: τα έγγραφα ενός τεχνικού (οποιαδήποτε κατάσταση).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_list_technician_documents
    @UserID INT, @TechnicianID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @TechnicianID AND Role = 'Technician')
        THROW 52320, N'Ο τεχνικός δεν βρέθηκε.', 1;
    SELECT d.DocumentID, d.DocType, d.DocNumber, d.IssueDate, d.ExpiryDate, d.FilePath,
           d.ReviewStatus, d.ReviewComment, d.ReviewedAt, r.Username AS ReviewedByUsername
    FROM DOCUMENT d
    LEFT JOIN USER_ACCOUNT r ON r.UserID = d.ReviewedBy
    WHERE d.TechnicianID = @TechnicianID
    ORDER BY d.DocType, d.DocumentID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_review_document: αποδοχή/απόρριψη εγγράφου τεχνικού (μόνο όσο είναι Pending).
-- Η απόρριψη θέλει σχόλιο. Καταγράφεται στο AUDIT_LOG (Pending -> Accepted/Rejected).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_review_document
    @UserID INT, @DocumentID INT, @Accept BIT, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @Accept IS NULL
        THROW 52327, N'Δώστε απόφαση: αποδοχή ή απόρριψη.', 1;
    IF @Accept = 0 AND (@Comment IS NULL OR LTRIM(RTRIM(@Comment)) = N'')
        THROW 52326, N'Η απόρριψη απαιτεί σχόλιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @status VARCHAR(8) =
            (SELECT ReviewStatus FROM DOCUMENT WITH (UPDLOCK)
             WHERE DocumentID = @DocumentID AND TechnicianID IS NOT NULL);
        IF @status IS NULL
            THROW 52321, N'Το έγγραφο τεχνικού δεν βρέθηκε.', 1;
        IF @status <> 'Pending'
            THROW 52322, N'Το έγγραφο έχει ήδη ελεγχθεί.', 1;
        DECLARE @new VARCHAR(8) = CASE WHEN @Accept = 1 THEN 'Accepted' ELSE 'Rejected' END;
        UPDATE DOCUMENT
        SET ReviewStatus = @new, ReviewComment = NULLIF(LTRIM(RTRIM(@Comment)), N''),
            ReviewedBy = @UserID, ReviewedAt = SYSUTCDATETIME()
        WHERE DocumentID = @DocumentID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('DOCUMENT', CAST(@DocumentID AS VARCHAR(100)), 'Review technician document', @status, @new,
                NULLIF(LTRIM(RTRIM(@Comment)), N''), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_decide_technician: έγκριση ή απόρριψη τεχνικού που είναι Pending.
-- ΚΑΝΟΝΑΣ ΕΓΚΡΙΣΗΣ: χρειάζεται τουλάχιστον ένα Accepted, μη ληγμένο (ExpiryDate NULL ή > σήμερα UTC)
-- έγγραφο ΚΑΘΕ ΕΝΟΣ από τους 3 τύπους (ID card, Installer licence, Training certificate).
-- Η απόρριψη επιτρέπεται όσο είναι Pending και θέλει σχόλιο.
-- Γράφει ApprovalStatus, ApprovedBy, ApprovalDecidedAt και AUDIT_LOG (παλιό/νέο + σχόλιο).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_decide_technician
    @UserID INT, @TechnicianID INT, @Approve BIT, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @Approve IS NULL
        THROW 52327, N'Δώστε απόφαση: έγκριση ή απόρριψη.', 1;
    IF @Approve = 0 AND (@Comment IS NULL OR LTRIM(RTRIM(@Comment)) = N'')
        THROW 52326, N'Η απόρριψη απαιτεί σχόλιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(9) =
            (SELECT ApprovalStatus FROM USER_ACCOUNT WITH (UPDLOCK)
             WHERE UserID = @TechnicianID AND Role = 'Technician');
        IF @old IS NULL
            THROW 52320, N'Ο τεχνικός δεν βρέθηκε.', 1;
        IF @old <> 'Pending'
            THROW 52324, N'Απόφαση λαμβάνεται μόνο για τεχνικό σε εκκρεμότητα (Pending).', 1;
        IF @Approve = 1
        BEGIN
            DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);
            DECLARE @types INT =
                (SELECT COUNT(DISTINCT DocType) FROM DOCUMENT WITH (UPDLOCK)
                 WHERE TechnicianID = @TechnicianID AND ReviewStatus = 'Accepted'
                   AND DocType IN ('ID card', 'Installer licence', 'Training certificate')
                   AND (ExpiryDate IS NULL OR ExpiryDate > @today));
            IF @types < 3
                THROW 52325, N'Η έγκριση απαιτεί αποδεκτό, μη ληγμένο έγγραφο για καθέναν από τους 3 τύπους (ID card, Installer licence, Training certificate).', 1;
        END;
        DECLARE @new VARCHAR(9) = CASE WHEN @Approve = 1 THEN 'Approved' ELSE 'Rejected' END;
        UPDATE USER_ACCOUNT
        SET ApprovalStatus = @new, ApprovedBy = @UserID, ApprovalDecidedAt = SYSUTCDATETIME()
        WHERE UserID = @TechnicianID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('USER_ACCOUNT', CAST(@TechnicianID AS VARCHAR(100)),
                CASE WHEN @Approve = 1 THEN 'Approve technician' ELSE 'Reject technician' END,
                @old, @new, NULLIF(LTRIM(RTRIM(@Comment)), N''), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_set_technician_status: Approved <-> Suspended. Η αναστολή θέλει σχόλιο.
-- Pending/Rejected αλλάζουν μόνο με sp_operator_decide_technician.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_set_technician_status
    @UserID INT, @TechnicianID INT, @Status VARCHAR(9), @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @Status IS NULL OR @Status NOT IN ('Approved', 'Suspended')
        THROW 52327, N'Η νέα κατάσταση πρέπει να είναι Approved ή Suspended.', 1;
    IF @Status = 'Suspended' AND (@Comment IS NULL OR LTRIM(RTRIM(@Comment)) = N'')
        THROW 52326, N'Η αναστολή απαιτεί σχόλιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @old VARCHAR(9) =
            (SELECT ApprovalStatus FROM USER_ACCOUNT WITH (UPDLOCK)
             WHERE UserID = @TechnicianID AND Role = 'Technician');
        IF @old IS NULL
            THROW 52320, N'Ο τεχνικός δεν βρέθηκε.', 1;
        IF @old NOT IN ('Approved', 'Suspended') OR @old = @Status
            THROW 52328, N'Η μετάβαση επιτρέπεται μόνο από Approved σε Suspended ή αντίστροφα.', 1;
        UPDATE USER_ACCOUNT
        SET ApprovalStatus = @Status, ApprovedBy = @UserID, ApprovalDecidedAt = SYSUTCDATETIME()
        WHERE UserID = @TechnicianID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('USER_ACCOUNT', CAST(@TechnicianID AS VARCHAR(100)), 'Set technician status',
                @old, @Status, NULLIF(LTRIM(RTRIM(@Comment)), N''), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- TEC-6: εγκατάσταση / αντικατάσταση μετρητή (ΙΙΙ.2.3). Λάθη 52131-52199.
-- 52131 εργασία όχι Accepted | 52132 τύπος εργασίας | 52133 η εργασία έχει ήδη εγκατάσταση
-- 52134 serial/network ID υπάρχει | 52135 φάσεις | 52136 κανένα φύλλο μετασχηματιστή (X7)
-- 52137 άκυρα στοιχεία μετρητή | 52138 μοντέλο/επικοινωνία δεν υπάρχει | 52139 τύπος εγγράφου μετρητή
-- 52140 ο μετρητής δεν είναι δική σας εγκατάσταση | 52141 η εγκατάσταση δεν είναι Pending
-- (επαναχρησιμοποιούνται: 52302-52304 έγγραφο, 52126 κενό κείμενο, 52120 εργασία δεν είναι δική σας)
-- Συμφωνία X7: ο μετασχηματιστής του μετρητή = το ΦΥΛΛΟ που περιέχει τις συντεταγμένες του.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_tech_install_meter: δική μου Accepted εργασία Installation/Replacement.
-- Μία συναλλαγή: METER (Pending confirmation, TransformerID από συντεταγμένες),
-- METER_CONNECTED_PHASE, METER_INSTALLATION (Pending). Replacement: κλείνει την ανοιχτή
-- εγκατάσταση του παλιού μετρητή (RemovedAt) και τον κάνει Retired. Οι μετρήσεις του
-- παλιού μετρητή ΔΕΝ πειράζονται. @Phases = 'L1' ή 'L1,L2,L3'.
-- Επιστρέφει: MeterID, InstallationID, TransformerID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_install_meter
    @UserID INT, @TaskID INT, @SerialNumber VARCHAR(40), @NetworkID VARCHAR(40), @Firmware VARCHAR(30),
    @MaxLoadAmps DECIMAL(6,1), @Latitude DECIMAL(9,6), @Longitude DECIMAL(9,6),
    @ModelID INT, @CommTypeID INT, @Phases VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    SET @SerialNumber = LTRIM(RTRIM(@SerialNumber));
    SET @NetworkID = LTRIM(RTRIM(@NetworkID));
    SET @Firmware = LTRIM(RTRIM(@Firmware));
    IF ISNULL(@SerialNumber, '') = '' OR ISNULL(@NetworkID, '') = '' OR ISNULL(@Firmware, '') = ''
       OR @MaxLoadAmps IS NULL OR @MaxLoadAmps <= 0
       OR @Latitude IS NULL OR @Longitude IS NULL OR @Latitude NOT BETWEEN -90 AND 90 OR @Longitude NOT BETWEEN -180 AND 180
        THROW 52137, N'Συμπληρώστε serial, network ID, firmware, Amps (> 0) και έγκυρες συντεταγμένες.', 1;
    DECLARE @phCount TINYINT = (SELECT PhaseCount FROM METER_MODEL WHERE ModelID = @ModelID);
    IF @phCount IS NULL OR NOT EXISTS (SELECT 1 FROM COMM_TYPE WHERE CommTypeID = @CommTypeID)
        THROW 52138, N'Το μοντέλο ή ο τύπος επικοινωνίας δεν υπάρχει.', 1;
    DECLARE @ph TABLE (Ph VARCHAR(20));
    INSERT @ph (Ph)
    SELECT DISTINCT UPPER(LTRIM(RTRIM(value))) FROM STRING_SPLIT(ISNULL(@Phases, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF EXISTS (SELECT 1 FROM @ph WHERE Ph NOT IN ('L1', 'L2', 'L3')) OR (SELECT COUNT(*) FROM @ph) <> @phCount
        THROW 52135, N'Οι φάσεις (L1, L2, L3) πρέπει να είναι τόσες όσες το μοντέλο του μετρητή.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @type VARCHAR(17), @status VARCHAR(9), @premise INT, @oldMeter INT;
        SELECT @type = TaskType, @status = Status, @premise = PremiseID, @oldMeter = MeterID
        FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID;
        IF @type IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @type NOT IN ('Installation', 'Replacement')
            THROW 52132, N'Η εργασία δεν είναι εγκατάσταση ή αντικατάσταση.', 1;
        IF @status <> 'Accepted'
            THROW 52131, N'Η εργασία πρέπει πρώτα να γίνει αποδεκτή (Accepted).', 1;
        IF EXISTS (SELECT 1 FROM METER_INSTALLATION WHERE TaskID = @TaskID)
            THROW 52133, N'Η εργασία έχει ήδη καταγράψει εγκατάσταση.', 1;
        IF EXISTS (SELECT 1 FROM METER WITH (UPDLOCK, HOLDLOCK) WHERE SerialNumber = @SerialNumber OR NetworkID = @NetworkID)
            THROW 52134, N'Το serial ή το network ID υπάρχει ήδη σε άλλον μετρητή.', 1;

        -- X7: φύλλο μετασχηματιστή από τις συντεταγμένες (ο μικρότερος γεωφράκτης πρώτος, όπως το sp_tso_locate).
        DECLARE @tr INT;
        SELECT TOP 1 @tr = t.TransformerID
        FROM TRANSFORMER t JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
        WHERE @Latitude BETWEEN g.MinLat AND g.MaxLat AND @Longitude BETWEEN g.MinLon AND g.MaxLon
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID)
        ORDER BY (g.MaxLat - g.MinLat) * (g.MaxLon - g.MinLon), t.TransformerID;
        IF @tr IS NULL
            THROW 52136, N'Οι συντεταγμένες δεν ανήκουν σε κανέναν μετασχηματιστή-φύλλο.', 1;

        DECLARE @now DATETIME2(0) = SYSUTCDATETIME();
        INSERT METER (SerialNumber, NetworkID, Firmware, MaxLoadAmps, Latitude, Longitude, Status, ModelID, CommTypeID, TransformerID)
        VALUES (@SerialNumber, @NetworkID, @Firmware, @MaxLoadAmps, @Latitude, @Longitude, 'Pending confirmation', @ModelID, @CommTypeID, @tr);
        DECLARE @mid INT = SCOPE_IDENTITY();
        INSERT METER_CONNECTED_PHASE (MeterID, ConnectedPhase) SELECT @mid, Ph FROM @ph;

        IF @type = 'Replacement'
        BEGIN
            -- Κλείνει η ανοιχτή εγκατάσταση του παλιού μετρητή, ο μετρητής γίνεται Retired. Μετρήσεις: αμετάβλητες.
            UPDATE METER_INSTALLATION SET RemovedAt = CASE WHEN InstalledAt < @now THEN @now ELSE DATEADD(SECOND, 1, InstalledAt) END
            WHERE MeterID = @oldMeter AND RemovedAt IS NULL;
            DECLARE @oldStatus VARCHAR(20) = (SELECT Status FROM METER WITH (UPDLOCK) WHERE MeterID = @oldMeter);
            UPDATE METER SET Status = 'Retired' WHERE MeterID = @oldMeter;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('METER', @oldMeter, 'Retire meter', @oldStatus, 'Retired', @UserID,
                    CONCAT(N'Αντικαταστάθηκε από τον μετρητή ', @mid, N' (εργασία ', @TaskID, N')'));
        END;

        INSERT METER_INSTALLATION (InstalledAt, ConfirmationStatus, MeterID, PremiseID, TaskID)
        VALUES (@now, 'Pending', @mid, @premise, @TaskID);
        DECLARE @iid INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
        VALUES ('METER_INSTALLATION', @iid, 'Install meter', 'Pending', @UserID,
                CONCAT(N'Μετρητής ', @mid, N' (', @SerialNumber, N') σε υποστατικό ', @premise, N', μετασχηματιστής ', @tr));
        COMMIT;
        SELECT @mid AS MeterID, @iid AS InstallationID, @tr AS TransformerID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_add_meter_document: έγγραφο εξοπλισμού του μετρητή που εγκατέστησα
-- (Calibration certificate, CE and protocol declaration, Encryption certificate),
-- όσο η εγκατάσταση είναι Pending. ReviewStatus 'Pending'. Επιστρέφει: DocumentID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_add_meter_document
    @UserID INT, @MeterID INT, @DocType VARCHAR(27), @DocNumber NVARCHAR(50),
    @IssueDate DATE, @ExpiryDate DATE = NULL, @FilePath NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @DocType IS NULL OR @DocType NOT IN ('Calibration certificate', 'CE and protocol declaration', 'Encryption certificate')
        THROW 52139, N'Τύπος εγγράφου μετρητή: Calibration certificate, CE and protocol declaration ή Encryption certificate.', 1;
    IF @DocNumber IS NULL OR LTRIM(RTRIM(@DocNumber)) = N''
        THROW 52302, N'Ο κωδικός του εγγράφου είναι υποχρεωτικός.', 1;
    IF @IssueDate IS NULL OR (@ExpiryDate IS NOT NULL AND @ExpiryDate <= @IssueDate)
        THROW 52303, N'Η ημερομηνία έκδοσης είναι υποχρεωτική και η λήξη πρέπει να είναι μετά την έκδοση.', 1;
    IF @FilePath IS NULL OR LTRIM(RTRIM(@FilePath)) = N''
        THROW 52304, N'Η διαδρομή του αρχείου είναι υποχρεωτική.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @iid INT, @cs VARCHAR(9);
        SELECT TOP 1 @iid = mi.InstallationID, @cs = mi.ConfirmationStatus
        FROM METER_INSTALLATION mi WITH (UPDLOCK) JOIN FIELD_TASK t ON t.TaskID = mi.TaskID
        WHERE mi.MeterID = @MeterID AND t.TechnicianID = @UserID
        ORDER BY mi.InstalledAt DESC, mi.InstallationID DESC;
        IF @iid IS NULL
            THROW 52140, N'Ο μετρητής δεν είναι δική σας εγκατάσταση.', 1;
        IF @cs <> 'Pending'
            THROW 52141, N'Η εγκατάσταση έχει ήδη κριθεί από τον Operator.', 1;
        INSERT DOCUMENT (DocType, DocNumber, IssueDate, ExpiryDate, FilePath, ReviewStatus, MeterID)
        VALUES (@DocType, LTRIM(RTRIM(@DocNumber)), @IssueDate, @ExpiryDate, LTRIM(RTRIM(@FilePath)), 'Pending', @MeterID);
        DECLARE @did INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
        VALUES ('DOCUMENT', @did, 'Add meter document', 'Pending', @UserID, CONCAT(@DocType, N' για μετρητή ', @MeterID));
        COMMIT;
        SELECT @did AS DocumentID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_list_installs: οι εγκαταστάσεις μου (μετρητής, κατάσταση επιβεβαίωσης, πόσοι από τους 3 τύπους εγγράφων υπάρχουν).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_installs
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert @UserID;
    SELECT mi.InstallationID, mi.TaskID, mi.MeterID, m.SerialNumber, m.Status AS MeterStatus, mi.PremiseID,
           mi.InstalledAt, mi.ConfirmationStatus, mi.ConfirmComment,
           (SELECT COUNT(DISTINCT d.DocType) FROM DOCUMENT d WHERE d.MeterID = mi.MeterID AND d.ReviewStatus <> 'Rejected') AS DocTypesPresent
    FROM METER_INSTALLATION mi
    JOIN FIELD_TASK t ON t.TaskID = mi.TaskID
    JOIN METER m ON m.MeterID = mi.MeterID
    WHERE t.TechnicianID = @UserID
    ORDER BY mi.InstalledAt DESC, mi.InstallationID DESC;
END;
GO

-- =====================================================================
-- TEC-7: ο Operator επιβεβαιώνει τον μετρητή (ΙΙΙ.2.3). Λάθη 52330-52339.
-- 52330 εγκατάσταση δεν υπάρχει | 52331 δεν είναι Pending | 52332 λείπουν έγγραφα
-- 52333 η απόρριψη θέλει σχόλιο | 52334 άκυρη απόφαση
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_operator_list_pending_meters: εγκαταστάσεις σε αναμονή επιβεβαίωσης.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_list_pending_meters
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT mi.InstallationID, mi.MeterID, m.SerialNumber, m.NetworkID, m.Firmware, m.MaxLoadAmps,
           m.Latitude, m.Longitude, m.TransformerID, mi.PremiseID, p.Address,
           t.TaskType, t.TechnicianID, u.Username AS TechnicianUsername, mi.InstalledAt,
           (SELECT COUNT(DISTINCT d.DocType) FROM DOCUMENT d
             WHERE d.MeterID = mi.MeterID AND d.ReviewStatus <> 'Rejected'
               AND (d.ExpiryDate IS NULL OR d.ExpiryDate > CAST(SYSUTCDATETIME() AS DATE))) AS DocTypesPresent,
           (SELECT COUNT(*) FROM ATTACHMENT a WHERE a.TaskID = mi.TaskID) AS Photos
    FROM METER_INSTALLATION mi
    JOIN METER m ON m.MeterID = mi.MeterID
    JOIN PREMISE p ON p.PremiseID = mi.PremiseID
    JOIN FIELD_TASK t ON t.TaskID = mi.TaskID
    JOIN USER_ACCOUNT u ON u.UserID = t.TechnicianID
    WHERE mi.ConfirmationStatus = 'Pending'
    ORDER BY mi.InstalledAt, mi.InstallationID;
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_list_meter_documents: τα έγγραφα εξοπλισμού ενός μετρητή.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_list_meter_documents
    @UserID INT, @MeterID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT DocumentID, DocType, DocNumber, IssueDate, ExpiryDate, FilePath, ReviewStatus, ReviewComment, ReviewedAt
    FROM DOCUMENT WHERE MeterID = @MeterID ORDER BY DocType, DocumentID;
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_confirm_meter: ο Operator κρίνει μια Pending εγκατάσταση.
-- Έγκριση: απαιτούνται και οι 3 τύποι εγγράφων (όχι Rejected, όχι ληγμένα). Τότε
-- ConfirmationStatus 'Confirmed', τα Pending έγγραφα γίνονται Accepted και ο μετρητής 'Active'.
-- Απόρριψη (σχόλιο υποχρεωτικό): 'Rejected', ο μετρητής μένει 'Pending confirmation' (ΔΕΝ γίνεται Active).
-- AUDIT_LOG για κάθε αλλαγή.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_confirm_meter
    @UserID INT, @InstallationID INT, @Approve BIT, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @Approve IS NULL
        THROW 52334, N'Δώστε απόφαση: έγκριση ή απόρριψη.', 1;
    SET @Comment = NULLIF(LTRIM(RTRIM(@Comment)), N'');
    IF @Approve = 0 AND @Comment IS NULL
        THROW 52333, N'Η απόρριψη θέλει σχόλιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @mid INT, @cs VARCHAR(9);
        SELECT @mid = MeterID, @cs = ConfirmationStatus
        FROM METER_INSTALLATION WITH (UPDLOCK) WHERE InstallationID = @InstallationID;
        IF @mid IS NULL
            THROW 52330, N'Η εγκατάσταση δεν υπάρχει.', 1;
        IF @cs <> 'Pending'
            THROW 52331, N'Η εγκατάσταση έχει ήδη κριθεί.', 1;
        DECLARE @now DATETIME2(0) = SYSUTCDATETIME();
        IF @Approve = 1
        BEGIN
            IF (SELECT COUNT(DISTINCT DocType) FROM DOCUMENT WITH (UPDLOCK)
                WHERE MeterID = @mid AND ReviewStatus <> 'Rejected'
                  AND DocType IN ('Calibration certificate', 'CE and protocol declaration', 'Encryption certificate')
                  AND (ExpiryDate IS NULL OR ExpiryDate > CAST(@now AS DATE))) < 3
                THROW 52332, N'Λείπουν έγγραφα: χρειάζονται πιστοποιητικό βαθμονόμησης, δήλωση CE και πρωτοκόλλου, πιστοποιητικό κρυπτογράφησης (έγκυρα).', 1;
            UPDATE DOCUMENT SET ReviewStatus = 'Accepted', ReviewedBy = @UserID, ReviewedAt = @now
            WHERE MeterID = @mid AND ReviewStatus = 'Pending' AND (ExpiryDate IS NULL OR ExpiryDate > CAST(@now AS DATE));
            UPDATE METER_INSTALLATION SET ConfirmationStatus = 'Confirmed', ConfirmedBy = @UserID, ConfirmedAt = @now, ConfirmComment = @Comment
            WHERE InstallationID = @InstallationID;
            DECLARE @oldMs VARCHAR(20) = (SELECT Status FROM METER WITH (UPDLOCK) WHERE MeterID = @mid);
            UPDATE METER SET Status = 'Active' WHERE MeterID = @mid;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('METER_INSTALLATION', @InstallationID, 'Confirm meter', 'Pending', 'Confirmed', @UserID, @Comment);
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('METER', @mid, 'Activate meter', @oldMs, 'Active', @UserID, @Comment);
        END
        ELSE
        BEGIN
            UPDATE METER_INSTALLATION SET ConfirmationStatus = 'Rejected', ConfirmedBy = @UserID, ConfirmedAt = @now, ConfirmComment = @Comment
            WHERE InstallationID = @InstallationID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('METER_INSTALLATION', @InstallationID, 'Reject meter', 'Pending', 'Rejected', @UserID, @Comment);
        END;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- =====================================================================
-- TEC-8: εντολές εξ αποστάσεως (ΙΙΙ.2.4, απόφαση B15). Λάθη 52340-52359.
-- 52340 είδος εντολής | 52341 κανένα Accepted έργο για τον μετρητή | 52342 μετρητής δεν υπάρχει/Retired
-- 52343 Parameters όχι JSON | 52344 εντολή δεν υπάρχει | 52345 όχι Awaiting approval
-- 52346 η απόρριψη θέλει σχόλιο | 52347 είδος αποτελέσματος | 52348 η εντολή δεν είναι Sent
-- 52349 ρόλος/εντολή δεν είναι δική σας
-- Ροή: τεχνικός ζητά -> 'Awaiting approval' -> Operator εγκρίνει -> 'Sent' -> προσπάθειες
-- (Timeout/NAK/ACK) -> 'Acknowledged' στο πρώτο ACK ή 'Failed' μετά από 3 αποτυχίες.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_tech_request_command: ο τεχνικός ζητά εντολή ΜΟΝΟ για μετρητή όπου έχει Accepted εργασία
-- (στον μετρητή ή στο υποστατικό όπου είναι εγκατεστημένος). Είδη: Disconnect, Reconnect,
-- Firmware upgrade ('Load shed' είναι μόνο του TSO, X3). Επιστρέφει: CommandID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_request_command
    @UserID INT, @MeterID INT, @CommandType VARCHAR(30), @Parameters NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    IF @CommandType IS NULL OR @CommandType NOT IN ('Disconnect', 'Reconnect', 'Firmware upgrade')
        THROW 52340, N'Είδος εντολής: Disconnect, Reconnect ή Firmware upgrade.', 1;
    SET @Parameters = NULLIF(LTRIM(RTRIM(@Parameters)), N'');
    IF @Parameters IS NOT NULL AND ISJSON(@Parameters) <> 1
        THROW 52343, N'Οι παράμετροι πρέπει να είναι έγκυρο JSON (π.χ. {"version":"2.1"}).', 1;
    IF NOT EXISTS (SELECT 1 FROM METER WHERE MeterID = @MeterID AND Status <> 'Retired')
        THROW 52342, N'Ο μετρητής δεν υπάρχει ή έχει αποσυρθεί.', 1;
    IF NOT EXISTS (SELECT 1 FROM FIELD_TASK t
                   WHERE t.TechnicianID = @UserID AND t.Status = 'Accepted'
                     AND (t.MeterID = @MeterID
                          OR t.PremiseID IN (SELECT mi.PremiseID FROM METER_INSTALLATION mi
                                             WHERE mi.MeterID = @MeterID AND mi.RemovedAt IS NULL)))
        THROW 52341, N'Δεν έχετε αποδεκτή εργασία για αυτόν τον μετρητή.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT REMOTE_COMMAND (CommandType, Parameters, Status, MeterID, RequestedBy)
        VALUES (@CommandType, @Parameters, 'Awaiting approval', @MeterID, @UserID);
        DECLARE @cid INT = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
        VALUES ('REMOTE_COMMAND', @cid, 'Request command', 'Awaiting approval', @UserID,
                CONCAT(@CommandType, N' για μετρητή ', @MeterID));
        COMMIT;
        SELECT @cid AS CommandID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_tech_list_command_targets: οι μετρητές για τους οποίους μπορώ να ζητήσω εντολή.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_list_command_targets
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tech_assert @UserID;
    SELECT m.MeterID, m.SerialNumber, m.Status
    FROM METER m
    WHERE m.Status <> 'Retired'
      AND EXISTS (SELECT 1 FROM FIELD_TASK t
                  WHERE t.TechnicianID = @UserID AND t.Status = 'Accepted'
                    AND (t.MeterID = m.MeterID
                         OR t.PremiseID IN (SELECT mi.PremiseID FROM METER_INSTALLATION mi
                                            WHERE mi.MeterID = m.MeterID AND mi.RemovedAt IS NULL)))
    ORDER BY m.MeterID;
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_approve_command: 'Awaiting approval' -> 'Sent' (ApprovedBy) ή, με @Approve = 0
-- και σχόλιο, -> 'Cancelled'. AUDIT_LOG.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_approve_command
    @UserID INT, @CommandID INT, @Approve BIT = 1, @Comment NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    SET @Comment = NULLIF(LTRIM(RTRIM(@Comment)), N'');
    IF ISNULL(@Approve, 1) = 0 AND @Comment IS NULL
        THROW 52346, N'Η απόρριψη της εντολής θέλει σχόλιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @st VARCHAR(17) = (SELECT Status FROM REMOTE_COMMAND WITH (UPDLOCK) WHERE CommandID = @CommandID);
        IF @st IS NULL
            THROW 52344, N'Η εντολή δεν υπάρχει.', 1;
        IF @st <> 'Awaiting approval'
            THROW 52345, N'Η εντολή δεν περιμένει έγκριση.', 1;
        IF ISNULL(@Approve, 1) = 1
        BEGIN
            UPDATE REMOTE_COMMAND SET Status = 'Sent', ApprovedBy = @UserID WHERE CommandID = @CommandID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('REMOTE_COMMAND', @CommandID, 'Approve command', @st, 'Sent', @UserID, @Comment);
        END
        ELSE
        BEGIN
            UPDATE REMOTE_COMMAND SET Status = 'Cancelled' WHERE CommandID = @CommandID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('REMOTE_COMMAND', @CommandID, 'Reject command', @st, 'Cancelled', @UserID, @Comment);
        END;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_command_record_attempt: καταγράφει μια προσπάθεια (προσομοίωση συσκευής) για εντολή 'Sent'.
-- Operator ή ο τεχνικός που τη ζήτησε. AttemptNo = επόμενος, υπολογίζεται κάτω από UPDLOCK στη γραμμή
-- της εντολής. ACK -> 'Acknowledged'. NAK/Timeout -> μένει 'Sent', μετά την 3η αποτυχία -> 'Failed'.
-- Επιστρέφει: AttemptNo, Status.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_command_record_attempt
    @UserID INT, @CommandID INT, @Outcome VARCHAR(7)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @role VARCHAR(12) = (SELECT Role FROM USER_ACCOUNT WHERE UserID = @UserID AND AccountStatus = 'Active');
    IF @role = 'Technician'
        EXEC sp_tech_assert @UserID;
    ELSE IF @role = 'Operator'
        EXEC sp_operator_assert @UserID;
    ELSE
        THROW 52349, N'Δεν επιτρέπεται: μόνο Operator ή ο τεχνικός που ζήτησε την εντολή.', 1;
    IF @Outcome IS NULL OR @Outcome NOT IN ('Timeout', 'NAK', 'ACK')
        THROW 52347, N'Αποτέλεσμα προσπάθειας: Timeout, NAK ή ACK.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @st VARCHAR(17), @req INT;
        SELECT @st = Status, @req = RequestedBy FROM REMOTE_COMMAND WITH (UPDLOCK) WHERE CommandID = @CommandID;
        IF @st IS NULL
            THROW 52344, N'Η εντολή δεν υπάρχει.', 1;
        IF @role = 'Technician' AND @req <> @UserID
            THROW 52349, N'Η εντολή δεν είναι δική σας.', 1;
        IF @st <> 'Sent'
            THROW 52348, N'Η εντολή δεν είναι σε κατάσταση Sent.', 1;
        DECLARE @no SMALLINT = ISNULL((SELECT MAX(AttemptNo) FROM COMMAND_ATTEMPT WHERE CommandID = @CommandID), 0) + 1;
        DECLARE @at DATETIME2(3) = SYSUTCDATETIME();
        INSERT COMMAND_ATTEMPT (CommandID, AttemptNo, AttemptAt, RespondedAt, Outcome)
        VALUES (@CommandID, @no, @at, CASE WHEN @Outcome = 'Timeout' THEN NULL ELSE @at END, @Outcome);
        DECLARE @new VARCHAR(17) = @st;
        IF @Outcome = 'ACK'
            SET @new = 'Acknowledged';
        ELSE IF (SELECT COUNT(*) FROM COMMAND_ATTEMPT WHERE CommandID = @CommandID AND Outcome IN ('Timeout', 'NAK')) >= 3
            SET @new = 'Failed';
        IF @new <> @st
        BEGIN
            UPDATE REMOTE_COMMAND SET Status = @new WHERE CommandID = @CommandID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
            VALUES ('REMOTE_COMMAND', @CommandID, 'Command result', @st, @new, @UserID,
                    CONCAT(N'Προσπάθεια ', @no, N': ', @Outcome));
        END;
        COMMIT;
        SELECT @no AS AttemptNo, @new AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_command_list: Operator βλέπει όλες τις εντολές, ο τεχνικός μόνο όσες ζήτησε.
-- Προαιρετικό φίλτρο μετρητή. Με πλήθος προσπαθειών και τελευταίο αποτέλεσμα.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_command_list
    @UserID INT, @MeterID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role VARCHAR(12) = (SELECT Role FROM USER_ACCOUNT WHERE UserID = @UserID AND AccountStatus = 'Active');
    IF @role = 'Technician'
        EXEC sp_tech_assert @UserID;
    ELSE IF @role = 'Operator'
        EXEC sp_operator_assert @UserID;
    ELSE
        THROW 52349, N'Δεν επιτρέπεται: μόνο Operator ή Τεχνικός.', 1;
    SELECT c.CommandID, c.CommandType, c.Parameters, c.RequestedAt, c.Status, c.MeterID, m.SerialNumber,
           u.Username AS RequestedByUsername, c.ApprovedBy,
           (SELECT COUNT(*) FROM COMMAND_ATTEMPT a WHERE a.CommandID = c.CommandID) AS Attempts,
           la.Outcome AS LastOutcome
    FROM REMOTE_COMMAND c
    JOIN METER m ON m.MeterID = c.MeterID
    JOIN USER_ACCOUNT u ON u.UserID = c.RequestedBy
    OUTER APPLY (SELECT TOP 1 a.Outcome FROM COMMAND_ATTEMPT a WHERE a.CommandID = c.CommandID ORDER BY a.AttemptNo DESC) la
    WHERE (@MeterID IS NULL OR c.MeterID = @MeterID)
      AND (@role = 'Operator' OR c.RequestedBy = @UserID)
    ORDER BY c.RequestedAt DESC, c.CommandID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_command_list_attempts: οι προσπάθειες μιας εντολής (ίδιος κανόνας πρόσβασης με το sp_command_list).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_command_list_attempts
    @UserID INT, @CommandID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role VARCHAR(12) = (SELECT Role FROM USER_ACCOUNT WHERE UserID = @UserID AND AccountStatus = 'Active');
    IF @role = 'Technician'
        EXEC sp_tech_assert @UserID;
    ELSE IF @role = 'Operator'
        EXEC sp_operator_assert @UserID;
    ELSE
        THROW 52349, N'Δεν επιτρέπεται: μόνο Operator ή Τεχνικός.', 1;
    SELECT a.AttemptNo, a.AttemptAt, a.RespondedAt, a.Outcome
    FROM COMMAND_ATTEMPT a JOIN REMOTE_COMMAND c ON c.CommandID = a.CommandID
    WHERE a.CommandID = @CommandID AND (@role = 'Operator' OR c.RequestedBy = @UserID)
    ORDER BY a.AttemptNo;
END;
GO

-- =====================================================================
-- TEC-9: έλεγχοι anti-tamper, συμβάν -> εργασία (ΙΙΙ.2.4, X4, X8). Λάθη 52360-52379.
-- 52360 η εργασία δεν είναι Anti-tamper check | 52361 η εργασία δεν είναι Accepted
-- 52362 συμβάν δεν υπάρχει | 52363 συμβάν όχι Open | 52364 συμβάν χωρίς μετρητή
-- (επαναχρησιμοποιούνται: 52126 κενά ευρήματα, 52113 άγνωστος χρήστης ειδοποίησης,
--  52103 τεχνικός μη εγκεκριμένος, 52102 χρονοδιάγραμμα, 52112 εκτός διαθεσιμότητας)
-- B14: το είδος συμβάντος είναι 'Tamper finding' (όχι 'Tamper').
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_tech_record_tamper_check: δική μου Accepted εργασία 'Anti-tamper check'.
-- TASK_NOTE 'Finding' (NoteNo κάτω από UPDLOCK στην εργασία), NOTIFIES για τη λίστα
-- @NotifyUserIDs ('3,4'), και αν @Critical = 1 νέο EVENT 'Tamper finding' (Critical, Open, X8).
-- Επιστρέφει: NoteNo, EventID (NULL αν δεν είναι critical).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tech_record_tamper_check
    @UserID INT, @TaskID INT, @Findings NVARCHAR(2000), @Critical BIT, @NotifyUserIDs VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tech_assert @UserID;
    SET @Findings = LTRIM(RTRIM(@Findings));
    IF ISNULL(@Findings, N'') = N''
        THROW 52126, N'Τα ευρήματα είναι υποχρεωτικά.', 1;
    DECLARE @n TABLE (UserID INT NULL);
    INSERT @n (UserID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT) FROM STRING_SPLIT(ISNULL(@NotifyUserIDs, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    IF EXISTS (SELECT 1 FROM @n n WHERE n.UserID IS NULL
               OR NOT EXISTS (SELECT 1 FROM USER_ACCOUNT u WHERE u.UserID = n.UserID AND u.AccountStatus = 'Active'))
        THROW 52113, N'Κάποιος χρήστης ειδοποίησης δεν υπάρχει ή δεν είναι ενεργός.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @type VARCHAR(17), @status VARCHAR(9), @premise INT, @meter INT;
        SELECT @type = TaskType, @status = Status, @premise = PremiseID, @meter = MeterID
        FROM FIELD_TASK WITH (UPDLOCK) WHERE TaskID = @TaskID AND TechnicianID = @UserID;
        IF @type IS NULL
            THROW 52120, N'Η εργασία δεν υπάρχει ή δεν είναι δική σας.', 1;
        IF @type <> 'Anti-tamper check'
            THROW 52360, N'Η εργασία δεν είναι έλεγχος anti-tamper.', 1;
        IF @status <> 'Accepted'
            THROW 52361, N'Η εργασία πρέπει να είναι αποδεκτή (Accepted).', 1;
        IF @meter IS NULL
            SELECT TOP 1 @meter = MeterID FROM METER_INSTALLATION
            WHERE PremiseID = @premise AND RemovedAt IS NULL ORDER BY InstalledAt DESC;
        DECLARE @no SMALLINT = ISNULL((SELECT MAX(NoteNo) FROM TASK_NOTE WHERE TaskID = @TaskID), 0) + 1;
        INSERT TASK_NOTE (TaskID, NoteNo, NoteKind, Text, WrittenBy) VALUES (@TaskID, @no, 'Finding', @Findings, @UserID);
        INSERT NOTIFIES (TaskID, UserID)
        SELECT @TaskID, n.UserID FROM @n n
        WHERE NOT EXISTS (SELECT 1 FROM NOTIFIES x WHERE x.TaskID = @TaskID AND x.UserID = n.UserID);
        DECLARE @eid BIGINT = NULL;
        IF ISNULL(@Critical, 0) = 1
        BEGIN
            INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID, TaskID)
            VALUES ('Tamper finding', 'Critical', LEFT(@Findings, 1000), SYSUTCDATETIME(), 'Open', @meter, @TaskID);
            SET @eid = SCOPE_IDENTITY();
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
            VALUES ('EVENT', @eid, 'Tamper finding', 'Open', @UserID, CONCAT(N'Κρίσιμο εύρημα στην εργασία ', @TaskID));
        END;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
        VALUES ('FIELD_TASK', @TaskID, 'Tamper check', @status, @UserID,
                CONCAT(N'Σημείωση ', @no, CASE WHEN ISNULL(@Critical, 0) = 1 THEN N', κρίσιμο' ELSE N', μη κρίσιμο' END));
        COMMIT;
        SELECT @no AS NoteNo, @eid AS EventID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_operator_list_open_events: συμβάντα με Status 'Open' (X4), νεότερα πρώτα.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_operator_list_open_events
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_operator_assert @UserID;
    SELECT TOP (500) e.EventID, e.EventType, e.Severity, e.Description, e.OccurredAt, e.MeterID, m.SerialNumber, e.TaskID AS SourceTaskID
    FROM EVENT e LEFT JOIN METER m ON m.MeterID = e.MeterID
    WHERE e.Status = 'Open'
    ORDER BY e.OccurredAt DESC, e.EventID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- sp_event_create_task (X4): Operator, συμβάν 'Open' με μετρητή -> FIELD_TASK 'Anti-tamper check'
-- (μετρητής του συμβάντος + υποστατικό της ανοιχτής εγκατάστασής του) + LEADS_TO, και το
-- συμβάν γίνεται 'In progress' (η μόνη αλλαγή του TEC στο EVENT). Επιστρέφει: TaskID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_event_create_task
    @UserID INT, @EventID BIGINT, @TechnicianID INT, @ScheduledFrom DATETIME2(0), @ScheduledTo DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_operator_assert @UserID;
    IF @ScheduledFrom IS NULL OR @ScheduledTo IS NULL OR @ScheduledTo <= @ScheduledFrom
        THROW 52102, N'Το χρονικό παράθυρο είναι άκυρο (η λήξη πρέπει να είναι μετά την έναρξη).', 1;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @TechnicianID AND Role = 'Technician'
                   AND AccountStatus = 'Active' AND ApprovalStatus = 'Approved')
        THROW 52103, N'Ο τεχνικός πρέπει να είναι ενεργός και εγκεκριμένος.', 1;
    IF NOT EXISTS (SELECT 1 FROM fn_task_slot_ok(@TechnicianID, @ScheduledFrom, @ScheduledTo))
        THROW 52112, N'Το χρονικό παράθυρο είναι εκτός της δηλωμένης διαθεσιμότητας του τεχνικού.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @st VARCHAR(11), @meter INT, @found BIT = 0;
        SELECT @st = Status, @meter = MeterID, @found = 1 FROM EVENT WITH (UPDLOCK) WHERE EventID = @EventID;
        IF @found = 0
            THROW 52362, N'Το συμβάν δεν υπάρχει.', 1;
        IF @st <> 'Open'
            THROW 52363, N'Το συμβάν δεν είναι Open.', 1;
        IF @meter IS NULL
            THROW 52364, N'Το συμβάν δεν έχει μετρητή: δεν μπορεί να δημιουργηθεί εργασία πεδίου.', 1;
        DECLARE @premise INT =
            (SELECT TOP 1 PremiseID FROM METER_INSTALLATION WHERE MeterID = @meter AND RemovedAt IS NULL ORDER BY InstalledAt DESC);
        INSERT FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, Status, TechnicianID, PremiseID, MeterID)
        VALUES ('Anti-tamper check', @ScheduledFrom, @ScheduledTo, 'Assigned', @TechnicianID, @premise, @meter);
        DECLARE @tid INT = SCOPE_IDENTITY();
        INSERT LEADS_TO (EventID, TaskID) VALUES (@EventID, @tid);
        UPDATE EVENT SET Status = 'In progress' WHERE EventID = @EventID;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy, ResultComment)
        VALUES ('EVENT', @EventID, 'Create task from event', @st, 'In progress', @UserID, CONCAT(N'Εργασία ', @tid));
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy, ResultComment)
        VALUES ('FIELD_TASK', @tid, 'Create task', 'Assigned', @UserID, CONCAT(N'Anti-tamper check από συμβάν ', @EventID));
        COMMIT;
        SELECT @tid AS TaskID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- sp_ref_list_comm_types: δημόσια λίστα τύπων επικοινωνίας για τη φόρμα εγκατάστασης (TEC-10).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ref_list_comm_types
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CommTypeID, Name AS Label FROM COMM_TYPE ORDER BY Name;
END;
GO
