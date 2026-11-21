-- =====================================================================
-- test_admin.sql : έλεγχοι για το procs_admin.sql (ADM-2).
-- Πάνω στα κοινά δεδομένα: admin = UserID 1, operator = 2, consumer1 = 3,
-- supplier1 = 9 (SupplierID 1), aggregator1 = 10 (AggregatorID 1).
-- Δοκιμαστικοί χρήστες: test_adm_*. Οι βασικοί χρήστες δεν μένουν ποτέ σε αναστολή.
-- Κάθε γραμμή τυπώνει OK ή FAIL.
-- =====================================================================
SET NOCOUNT ON;

-- ---------- sp_admin_assert ----------
BEGIN TRY EXEC sp_admin_assert 1; PRINT 'OK   assert: active admin passes'; END TRY
BEGIN CATCH PRINT 'FAIL assert admin: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_assert 2; PRINT 'FAIL assert: operator passed'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   assert: operator -> 51500' ELSE PRINT 'FAIL assert operator: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_admin_create_user ----------
DECLARE @cu TABLE (UserID INT);
DECLARE @opid INT, @supid INT, @aggid INT, @dsoid INT, @tsoid INT;

INSERT @cu EXEC sp_admin_create_user 1, 'Operator', N'test_adm_op', 'hash-not-real', 'test_adm_op@example.com', '+35722000001', N'Δοκιμή', N'Χειριστής';
SELECT @opid = UserID FROM @cu; DELETE @cu;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @opid AND Role = 'Operator' AND CreatedBy = 1 AND AccountStatus = 'Active')
    PRINT 'OK   create Operator -> CreatedBy = admin' ELSE PRINT 'FAIL create Operator';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'USER_ACCOUNT' AND ObjectID = CAST(@opid AS VARCHAR(100)) AND Action = 'Create user' AND PerformedBy = 1)
    PRINT 'OK   create user -> AUDIT_LOG row' ELSE PRINT 'FAIL create user audit';

INSERT @cu EXEC sp_admin_create_user 1, 'DSO', N'test_adm_dso', 'hash-not-real', 'test_adm_dso@example.com', NULL, N'Δοκιμή', N'ΔΣΜ';
SELECT @dsoid = UserID FROM @cu; DELETE @cu;
INSERT @cu EXEC sp_admin_create_user 1, 'TSO', N'test_adm_tso', 'hash-not-real', 'test_adm_tso@example.com', NULL, N'Δοκιμή', N'ΔΣΜΗΚ';
SELECT @tsoid = UserID FROM @cu; DELETE @cu;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @dsoid AND Role = 'DSO' AND CreatedBy IS NULL AND SupplierID IS NULL AND AggregatorID IS NULL)
   AND EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @tsoid AND Role = 'TSO' AND CreatedBy IS NULL)
    PRINT 'OK   create DSO and TSO (no CreatedBy, no company)' ELSE PRINT 'FAIL create DSO/TSO';

INSERT @cu EXEC sp_admin_create_user 1, 'Supplier', N'test_adm_sup', 'hash-not-real', 'test_adm_sup@example.com', NULL, N'Δοκιμή', N'Προμηθευτής', 1, NULL;
SELECT @supid = UserID FROM @cu; DELETE @cu;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @supid AND Role = 'Supplier' AND SupplierID = 1 AND AggregatorID IS NULL)
    PRINT 'OK   create Supplier with SupplierID' ELSE PRINT 'FAIL create Supplier';

INSERT @cu EXEC sp_admin_create_user 1, 'Aggregator', N'test_adm_agg', 'hash-not-real', 'test_adm_agg@example.com', NULL, N'Δοκιμή', N'Αθροιστής', NULL, 1;
SELECT @aggid = UserID FROM @cu; DELETE @cu;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @aggid AND Role = 'Aggregator' AND AggregatorID = 1 AND SupplierID IS NULL)
    PRINT 'OK   create Aggregator with AggregatorID' ELSE PRINT 'FAIL create Aggregator';

BEGIN TRY EXEC sp_admin_create_user 2, 'Operator', N'test_adm_x1', 'h', 'x1@example.com', NULL, N'Χ', N'Χ'; PRINT 'FAIL operator created a user'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   create user by non-admin -> 51500' ELSE PRINT 'FAIL create non-admin: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Admin', N'test_adm_x2', 'h', 'x2@example.com', NULL, N'Χ', N'Χ'; PRINT 'FAIL Admin role created'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51501 PRINT 'OK   create Admin role refused -> 51501' ELSE PRINT 'FAIL create Admin: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Consumer', N'test_adm_x3', 'h', 'x3@example.com', NULL, N'Χ', N'Χ'; PRINT 'FAIL Consumer role created'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51501 PRINT 'OK   create Consumer role refused -> 51501' ELSE PRINT 'FAIL create Consumer: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Technician', N'test_adm_x4', 'h', 'x4@example.com', NULL, N'Χ', N'Χ'; PRINT 'FAIL Technician role created'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51501 PRINT 'OK   create Technician role refused -> 51501' ELSE PRINT 'FAIL create Technician: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Operator', N'test_adm_op', 'h', 'dup@example.com', NULL, N'Χ', N'Χ'; PRINT 'FAIL duplicate username accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51505 PRINT 'OK   duplicate username -> 51505' ELSE PRINT 'FAIL duplicate: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Supplier', N'test_adm_x5', 'h', 'x5@example.com', NULL, N'Χ', N'Χ', NULL, NULL; PRINT 'FAIL Supplier without company'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51506 PRINT 'OK   Supplier without SupplierID -> 51506' ELSE PRINT 'FAIL supplier w/o company: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Supplier', N'test_adm_x6', 'h', 'x6@example.com', NULL, N'Χ', N'Χ', 99999, NULL; PRINT 'FAIL unknown SupplierID'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51506 PRINT 'OK   Supplier with unknown SupplierID -> 51506' ELSE PRINT 'FAIL unknown supplier: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Aggregator', N'test_adm_x7', 'h', 'x7@example.com', NULL, N'Χ', N'Χ', NULL, 99999; PRINT 'FAIL unknown AggregatorID'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51507 PRINT 'OK   Aggregator with unknown AggregatorID -> 51507' ELSE PRINT 'FAIL unknown aggregator: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'DSO', N'test_adm_x8', 'h', 'x8@example.com', NULL, N'Χ', N'Χ', 1, NULL; PRINT 'FAIL DSO with company'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51508 PRINT 'OK   DSO with company -> 51508' ELSE PRINT 'FAIL DSO company: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_create_user 1, 'Operator', N'test_adm_x9', 'h', 'not-an-email', NULL, N'Χ', N'Χ'; PRINT 'FAIL bad email accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51503 PRINT 'OK   bad email -> 51503' ELSE PRINT 'FAIL bad email: ' + ERROR_MESSAGE(); END CATCH;
IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE Username LIKE 'test[_]adm[_]x%')
    PRINT 'OK   refused creations left no rows' ELSE PRINT 'FAIL refused creation left a row';

-- ---------- sp_admin_list_users ----------
DECLARE @lu TABLE (UserID INT, Username NVARCHAR(50), Role VARCHAR(10), Email VARCHAR(254), Phone VARCHAR(20),
                   FirstName NVARCHAR(50), LastName NVARCHAR(50), AccountStatus VARCHAR(9), CreatedAt DATETIME2(0),
                   SupplierID INT, AggregatorID INT, Company NVARCHAR(100));
INSERT @lu EXEC sp_admin_list_users 1;
IF EXISTS (SELECT 1 FROM @lu WHERE Username = 'test_adm_op') AND EXISTS (SELECT 1 FROM @lu WHERE UserID = 3)
    PRINT 'OK   list users (no filter) -> all roles' ELSE PRINT 'FAIL list users';
DELETE @lu;
INSERT @lu EXEC sp_admin_list_users 1, 'Supplier';
IF (SELECT COUNT(*) FROM @lu) >= 2 AND NOT EXISTS (SELECT 1 FROM @lu WHERE Role <> 'Supplier')
   AND EXISTS (SELECT 1 FROM @lu WHERE Username = 'test_adm_sup' AND Company IS NOT NULL)
    PRINT 'OK   list users filtered by role, with company name' ELSE PRINT 'FAIL list users by role';
IF NOT EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id = OBJECT_ID('sp_admin_list_users') AND definition LIKE '%u.PasswordHash%')
    PRINT 'OK   list users never selects PasswordHash' ELSE PRINT 'FAIL list users exposes hash';
BEGIN TRY EXEC sp_admin_list_users 3; PRINT 'FAIL consumer listed users'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   list users by non-admin -> 51500' ELSE PRINT 'FAIL list non-admin: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_list_users 1, 'Boss'; PRINT 'FAIL unknown role filter'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51510 PRINT 'OK   unknown role filter -> 51510' ELSE PRINT 'FAIL role filter: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_admin_set_account_status ----------
EXEC sp_admin_set_account_status 1, @opid, 'Suspended';
IF (SELECT AccountStatus FROM USER_ACCOUNT WHERE UserID = @opid) = 'Suspended' PRINT 'OK   suspend user' ELSE PRINT 'FAIL suspend';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'USER_ACCOUNT' AND ObjectID = CAST(@opid AS VARCHAR(100))
           AND Action = 'Set account status' AND OldState = 'Active' AND NewState = 'Suspended' AND PerformedBy = 1)
    PRINT 'OK   suspend -> AUDIT_LOG with OldState/NewState' ELSE PRINT 'FAIL suspend audit';
BEGIN TRY EXEC sp_admin_set_account_status 1, @opid, 'Suspended'; PRINT 'FAIL suspended twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51523 PRINT 'OK   same status again -> 51523' ELSE PRINT 'FAIL same status: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_admin_set_account_status 1, @opid, 'Active';
IF (SELECT AccountStatus FROM USER_ACCOUNT WHERE UserID = @opid) = 'Active' PRINT 'OK   reactivate user' ELSE PRINT 'FAIL reactivate';
BEGIN TRY EXEC sp_admin_set_account_status 1, 1, 'Suspended'; PRINT 'FAIL admin suspended himself'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51522 PRINT 'OK   admin cannot suspend himself -> 51522' ELSE PRINT 'FAIL self-suspend: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT AccountStatus FROM USER_ACCOUNT WHERE UserID = 1) = 'Active' PRINT 'OK   admin still Active' ELSE PRINT 'FAIL admin not Active';
BEGIN TRY EXEC sp_admin_set_account_status 1, @opid, 'Banned'; PRINT 'FAIL bad status accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51520 PRINT 'OK   bad status -> 51520' ELSE PRINT 'FAIL bad status: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_set_account_status 1, 999999, 'Suspended'; PRINT 'FAIL unknown user accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51521 PRINT 'OK   unknown target -> 51521' ELSE PRINT 'FAIL unknown target: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_set_account_status 2, @opid, 'Suspended'; PRINT 'FAIL operator suspended a user'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   set status by non-admin -> 51500' ELSE PRINT 'FAIL status non-admin: ' + ERROR_MESSAGE(); END CATCH;

EXEC sp_admin_set_account_status 1, @dsoid, 'Suspended';
EXEC sp_admin_set_account_status 1, @dsoid, 'Active';
IF (SELECT AccountStatus FROM USER_ACCOUNT WHERE UserID = @dsoid) = 'Active' PRINT 'OK   suspend and reactivate cycle on DSO test user' ELSE PRINT 'FAIL DSO cycle';

-- ---------- sp_admin_audit_log ----------
DECLARE @al TABLE (LogID BIGINT, LoggedAt DATETIME2(3), ObjectType VARCHAR(30), ObjectID VARCHAR(100), Action VARCHAR(50),
                   OldState NVARCHAR(400), NewState NVARCHAR(400), ResultComment NVARCHAR(1000), PerformedBy INT,
                   PerformedByUsername NVARCHAR(50), ActorMechanism NVARCHAR(100));
INSERT @al EXEC sp_admin_audit_log 1;
IF EXISTS (SELECT 1 FROM @al) AND (SELECT COUNT(*) FROM @al) <= 500
    PRINT 'OK   audit log returns rows (max 500)' ELSE PRINT 'FAIL audit log';
IF (SELECT TOP 1 LogID FROM @al ORDER BY LogID DESC) = (SELECT TOP 1 LogID FROM @al ORDER BY LoggedAt DESC, LogID DESC)
    PRINT 'OK   audit log newest first' ELSE PRINT 'FAIL audit order';
IF EXISTS (SELECT 1 FROM @al WHERE Action = 'Create user' AND PerformedByUsername = 'admin' AND NewState LIKE N'%test_adm_op%')
    PRINT 'OK   audit log shows performer username' ELSE PRINT 'FAIL audit performer';
DELETE @al;
INSERT @al EXEC sp_admin_audit_log 1, 'USER_ACCOUNT', '2000-01-01', '2999-12-31';
IF EXISTS (SELECT 1 FROM @al) AND NOT EXISTS (SELECT 1 FROM @al WHERE ObjectType <> 'USER_ACCOUNT')
    PRINT 'OK   audit log filtered by ObjectType and dates' ELSE PRINT 'FAIL audit filter';
DELETE @al;
INSERT @al EXEC sp_admin_audit_log 1, NULL, '2000-01-01', '2000-01-02';
IF NOT EXISTS (SELECT 1 FROM @al) PRINT 'OK   audit log date range with no rows -> empty' ELSE PRINT 'FAIL audit empty range';
BEGIN TRY EXEC sp_admin_audit_log 1, NULL, '2026-12-31', '2026-01-01'; PRINT 'FAIL reversed dates accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51530 PRINT 'OK   reversed dates -> 51530' ELSE PRINT 'FAIL reversed dates: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_admin_audit_log 2; PRINT 'FAIL operator read the log'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   audit log by non-admin -> 51500' ELSE PRINT 'FAIL log non-admin: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_admin_list_companies ----------
DECLARE @lc TABLE (CompanyType VARCHAR(10), CompanyID INT, Name NVARCHAR(100));
INSERT @lc EXEC sp_admin_list_companies 1;
IF EXISTS (SELECT 1 FROM @lc WHERE CompanyType = 'Supplier' AND CompanyID = 1) AND EXISTS (SELECT 1 FROM @lc WHERE CompanyType = 'Aggregator' AND CompanyID = 1)
   AND (SELECT COUNT(*) FROM @lc) = (SELECT COUNT(*) FROM SUPPLIER) + (SELECT COUNT(*) FROM AGGREGATOR)
    PRINT 'OK   list companies -> suppliers + aggregators' ELSE PRINT 'FAIL list companies';
BEGIN TRY EXEC sp_admin_list_companies 9; PRINT 'FAIL supplier listed companies'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51500 PRINT 'OK   list companies by non-admin -> 51500' ELSE PRINT 'FAIL companies non-admin: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- βασικοί χρήστες ανέγγιχτοι ----------
IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID BETWEEN 1 AND 10 AND AccountStatus <> 'Active')
    PRINT 'OK   base demo users all still Active' ELSE PRINT 'FAIL a base demo user is suspended';
