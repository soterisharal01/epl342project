-- =====================================================================
-- test_common.sql : έλεγχοι για τα procs_common.sql (login, εγγραφή, προφίλ).
-- ΠΡΟΤΥΠΟ για όλα τα tests: κάθε έλεγχος τυπώνει "OK ..." ή "FAIL ...".
-- Τρέχει πάνω στα κοινά δεδομένα (00_base.sql). Οι νέες γραμμές που φτιάχνει
-- έχουν username test_* (μένουν, γιατί το AUDIT_LOG τις δείχνει). Τρέχε τα tests
-- σε δοκιμαστική βάση (sql/tools/test_local.sh), όχι στη βάση του demo.
-- ΣΗΜ.: ΟΧΙ BEGIN TRAN γύρω από όλο το test: ένα THROW με XACT_ABORT ON
-- «χαλάει» το εξωτερικό transaction και σταματά τα επόμενα tests.
-- =====================================================================
SET NOCOUNT ON;

-- 1. Login: υπάρχων χρήστης επιστρέφει ρόλο, ανύπαρκτος 0 γραμμές
DECLARE @t TABLE (UserID INT, Username NVARCHAR(50), PasswordHash VARCHAR(255), Role VARCHAR(10),
                  AccountStatus VARCHAR(9), ApprovalStatus VARCHAR(9), FirstName NVARCHAR(50),
                  LastName NVARCHAR(50), SupplierID INT, AggregatorID INT);
INSERT @t EXEC sp_auth_get_login N'consumer1';
IF (SELECT Role FROM @t) = 'Consumer' PRINT 'OK   login consumer1 -> Consumer' ELSE PRINT 'FAIL login consumer1';
DELETE @t;
INSERT @t EXEC sp_auth_get_login N'tech2';
IF (SELECT ApprovalStatus FROM @t) = 'Pending' PRINT 'OK   tech2 is Pending' ELSE PRINT 'FAIL tech2 Pending';
DELETE @t;
INSERT @t EXEC sp_auth_get_login N'den_yparxei';
IF NOT EXISTS (SELECT 1 FROM @t) PRINT 'OK   unknown user -> 0 rows' ELSE PRINT 'FAIL unknown user';

-- 2. Εγγραφή καταναλωτή: Active, 36 μήνες, κανάλια, audit
DECLARE @r TABLE (UserID INT);
INSERT @r EXEC sp_auth_register_consumer N'test_new', '$2y$10$abcdefghijklmnopqrstuv', 'new@test.cy', '99000000', N'Νέος', N'Χρήστης', 'Email,SMS';
DECLARE @id INT = (SELECT UserID FROM @r);
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @id AND Role = 'Consumer' AND AccountStatus = 'Active' AND RawRetentionMonths = 36)
    PRINT 'OK   register -> Active Consumer, 36 months' ELSE PRINT 'FAIL register';
IF (SELECT COUNT(*) FROM CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @id) = 2
    PRINT 'OK   register -> 2 channels' ELSE PRINT 'FAIL register channels';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'USER_ACCOUNT' AND ObjectID = CAST(@id AS VARCHAR) AND Action = 'Register consumer')
    PRINT 'OK   register -> AUDIT_LOG' ELSE PRINT 'FAIL register audit';

-- 3. Λάθη: ίδιο username (50002), SMS χωρίς τηλέφωνο (50004)
BEGIN TRY
    EXEC sp_auth_register_consumer N'consumer1', 'x', 'a@b.cy', NULL, N'A', N'B', 'Email';
    PRINT 'FAIL duplicate username accepted';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50002 PRINT 'OK   duplicate username -> 50002' ELSE PRINT 'FAIL duplicate: ' + ERROR_MESSAGE();
END CATCH;
BEGIN TRY
    EXEC sp_auth_register_consumer N'test_sms', 'x', 'a@b.cy', NULL, N'A', N'B', 'SMS';
    PRINT 'FAIL SMS without phone accepted';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50004 PRINT 'OK   SMS without phone -> 50004' ELSE PRINT 'FAIL sms: ' + ERROR_MESSAGE();
END CATCH;

-- 4. Καταγραφή login (επιτυχία με PerformedBy, αποτυχία χωρίς)
EXEC sp_auth_log_login N'consumer1', 1, '10.0.0.1';
EXEC sp_auth_log_login N'kanenas', 0, '10.0.0.2';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE Action = 'Login' AND PerformedBy = 3)
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE Action = 'Login failed' AND ObjectID = 'kanenas' AND PerformedBy IS NULL)
    PRINT 'OK   login audit' ELSE PRINT 'FAIL login audit';

-- 5. Προφίλ: όχι PasswordHash, ο supplier βλέπει την εταιρεία του
DECLARE @p TABLE (Username NVARCHAR(50), Role VARCHAR(10), FirstName NVARCHAR(50), LastName NVARCHAR(50),
                  Email VARCHAR(254), Phone VARCHAR(20), AccountStatus VARCHAR(9), CreatedAt DATETIME2(0),
                  ApprovalStatus VARCHAR(9), Supplier NVARCHAR(200), Aggregator NVARCHAR(200), NotificationChannels NVARCHAR(50));
INSERT @p EXEC sp_user_get_profile 9;
IF (SELECT Supplier FROM @p) IS NOT NULL PRINT 'OK   profile supplier1 -> company' ELSE PRINT 'FAIL profile';

-- 6. Αλλαγή κωδικού (στον test χρήστη, όχι σε demo χρήστη)
EXEC sp_user_change_password @id, '$2y$10$newnewnewnewnewnewnewn';
IF (SELECT PasswordHash FROM USER_ACCOUNT WHERE UserID = @id) = '$2y$10$newnewnewnewnewnewnewn'
    PRINT 'OK   change password' ELSE PRINT 'FAIL change password';

PRINT 'test_common.sql: τέλος';
