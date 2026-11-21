-- =====================================================================
-- test_technician.sql : έλεγχοι για το procs_technician.sql (TEC-1).
-- Κοινά δεδομένα: tech1 = UserID 5 (Approved, κατηγορίες 1,2), tech2 = 6 (Pending),
-- consumer1 = 3. Κατηγορίες 1 και 2 υπάρχουν στο 00_base.sql.
-- Κάθε γραμμή τυπώνει OK ή FAIL. Νέοι χρήστες: test_tec_*.
-- =====================================================================
SET NOCOUNT ON;

-- ---------- sp_ref_list_tech_categories ----------
DECLARE @rc TABLE (CategoryID INT, Label NVARCHAR(100));
INSERT @rc EXEC sp_ref_list_tech_categories;
IF (SELECT COUNT(*) FROM @rc) >= 2 PRINT 'OK   list tech categories' ELSE PRINT 'FAIL list tech categories';

-- ---------- sp_tech_assert ----------
BEGIN TRY EXEC sp_tech_assert 5; PRINT 'OK   approved technician passes assert'; END TRY
BEGIN CATCH PRINT 'FAIL assert approved: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_assert 6; PRINT 'FAIL pending technician passed assert'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   pending technician -> 52000' ELSE PRINT 'FAIL assert pending: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_assert 3; PRINT 'FAIL consumer passed assert'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   consumer -> 52000' ELSE PRINT 'FAIL assert consumer: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_auth_register_technician ----------
DECLARE @r TABLE (UserID INT);
INSERT @r EXEC sp_auth_register_technician N'test_tec_new', '$2y$10$abcdefghijklmnopqrstuv', 'tec@test.cy', '99111111',
    N'Νέος', N'Τεχνικός', '1990-05-15', N'photos/test_tec_new.jpg', '1,2';
DECLARE @id INT = (SELECT UserID FROM @r);
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @id AND Role = 'Technician' AND ApprovalStatus = 'Pending'
           AND AccountStatus = 'Active' AND ApprovedBy IS NULL AND ApprovalDecidedAt IS NULL
           AND BirthDate = '1990-05-15' AND Photo = N'photos/test_tec_new.jpg')
    PRINT 'OK   register technician -> Pending' ELSE PRINT 'FAIL register technician';
IF (SELECT COUNT(*) FROM IN_CATEGORY WHERE UserID = @id) = 2 PRINT 'OK   register -> 2 categories' ELSE PRINT 'FAIL register categories';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'USER_ACCOUNT' AND ObjectID = CAST(@id AS VARCHAR(100)) AND Action = 'Register technician')
    PRINT 'OK   register -> audit row' ELSE PRINT 'FAIL register audit';
BEGIN TRY EXEC sp_tech_assert @id; PRINT 'FAIL new technician acts before approval'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   new technician blocked until approval -> 52000' ELSE PRINT 'FAIL new assert: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC sp_auth_register_technician N'ab', 'x', 'a@test.cy', NULL, N'A', N'B', '1990-01-01', N'p.jpg', '1'; PRINT 'FAIL short username accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52001 PRINT 'OK   short username -> 52001' ELSE PRINT 'FAIL short username: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_new', 'x', 'a@test.cy', NULL, N'A', N'B', '1990-01-01', N'p.jpg', '1'; PRINT 'FAIL duplicate username accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52002 PRINT 'OK   duplicate username -> 52002' ELSE PRINT 'FAIL duplicate username: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad1', 'x', 'not-an-email', NULL, N'A', N'B', '1990-01-01', N'p.jpg', '1'; PRINT 'FAIL bad email accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52003 PRINT 'OK   bad email -> 52003' ELSE PRINT 'FAIL bad email: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad2', 'x', 'a@test.cy', NULL, N'A', N'B', '2015-01-01', N'p.jpg', '1'; PRINT 'FAIL minor accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52004 PRINT 'OK   under 18 -> 52004' ELSE PRINT 'FAIL under 18: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad3', 'x', 'a@test.cy', NULL, N'A', N'B', '1990-01-01', N'  ', '1'; PRINT 'FAIL empty photo accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52005 PRINT 'OK   empty photo -> 52005' ELSE PRINT 'FAIL empty photo: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad4', 'x', 'a@test.cy', NULL, N'A', N'B', '1990-01-01', N'p.jpg', ''; PRINT 'FAIL no category accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52006 PRINT 'OK   no category -> 52006' ELSE PRINT 'FAIL no category: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad5', 'x', 'a@test.cy', NULL, N'A', N'B', '1990-01-01', N'p.jpg', '1,999'; PRINT 'FAIL unknown category accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52006 PRINT 'OK   unknown category -> 52006' ELSE PRINT 'FAIL unknown category: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_auth_register_technician N'test_tec_bad6', 'x', 'a@test.cy', 'abc', N'A', N'B', '1990-01-01', N'p.jpg', '1'; PRINT 'FAIL bad phone accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52007 PRINT 'OK   bad phone -> 52007' ELSE PRINT 'FAIL bad phone: ' + ERROR_MESSAGE(); END CATCH;
IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE Username LIKE N'test_tec_bad%' OR Username = N'ab')
    PRINT 'OK   refused registrations left no rows' ELSE PRINT 'FAIL refused registrations left rows';

-- ---------- sp_tech_list_categories ----------
DECLARE @lc TABLE (CategoryID INT, Label NVARCHAR(100));
INSERT @lc EXEC sp_tech_list_categories 5;
IF (SELECT COUNT(*) FROM @lc) = 2 PRINT 'OK   tech1 lists own 2 categories' ELSE PRINT 'FAIL list categories';
BEGIN TRY EXEC sp_tech_list_categories 6; PRINT 'FAIL pending technician listed categories'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   list categories by pending -> 52000' ELSE PRINT 'FAIL list pending: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tech_set_categories (tech1 αλλάζει και ξαναγυρίζει στο 1,2) ----------
EXEC sp_tech_set_categories 5, '2';
IF (SELECT COUNT(*) FROM IN_CATEGORY WHERE UserID = 5) = 1 AND EXISTS (SELECT 1 FROM IN_CATEGORY WHERE UserID = 5 AND CategoryID = 2)
    PRINT 'OK   set categories replaces list' ELSE PRINT 'FAIL set categories';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'USER_ACCOUNT' AND ObjectID = '5' AND Action = 'Set technician categories' AND OldState = '1,2' AND NewState = '2')
    PRINT 'OK   set categories -> audit with old/new' ELSE PRINT 'FAIL set categories audit';
BEGIN TRY EXEC sp_tech_set_categories 5, ''; PRINT 'FAIL empty category list accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52006 PRINT 'OK   empty list -> 52006' ELSE PRINT 'FAIL empty list: ' + ERROR_MESSAGE(); END CATCH;
IF EXISTS (SELECT 1 FROM IN_CATEGORY WHERE UserID = 5 AND CategoryID = 2) AND (SELECT COUNT(*) FROM IN_CATEGORY WHERE UserID = 5) = 1
    PRINT 'OK   refused set kept old categories' ELSE PRINT 'FAIL refused set changed data';
BEGIN TRY EXEC sp_tech_set_categories 6, '1'; PRINT 'FAIL pending technician set categories'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   set categories by pending -> 52000' ELSE PRINT 'FAIL set pending: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_tech_set_categories 5, '1,2';
IF (SELECT COUNT(*) FROM IN_CATEGORY WHERE UserID = 5) = 2 PRINT 'OK   tech1 categories restored' ELSE PRINT 'FAIL restore tech1 categories';
GO
