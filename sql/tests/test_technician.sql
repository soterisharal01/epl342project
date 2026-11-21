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

-- =====================================================================
-- TEC-5: εργασίες πεδίου. operator = 2, consumer1 = 3, tech1 = 5 (Approved), tech2 = 6 (Pending).
-- Χρησιμοποιεί το αίτημα 1 αν είναι ακόμη Submitted, αλλιώς φτιάχνει δικό του αίτημα.
-- Δεύτερος εγκεκριμένος τεχνικός test_tec_b: στο τέλος γίνεται Suspended ώστε να μην επηρεάζει άλλα tests.
-- Οι ώρες είναι το 2027-06-15 (ημέρα χωρίς δηλωμένη διαθεσιμότητα) και 2027-06-16 (με διαθεσιμότητα).
-- =====================================================================
SET NOCOUNT ON;

DECLARE @req INT = 1;
IF NOT EXISTS (SELECT 1 FROM SERVICE_REQUEST WHERE RequestID = 1 AND Status = 'Submitted')
BEGIN
    INSERT SERVICE_REQUEST (RequestType, Description, Status, UserID, PremiseID)
    VALUES ('Fault report', N'Αίτημα δοκιμής TEC-5', 'Submitted', 3, 1);
    SET @req = SCOPE_IDENTITY();
END;
DECLARE @reqUser INT = (SELECT UserID FROM SERVICE_REQUEST WHERE RequestID = @req);
DECLARE @reqPremise INT = (SELECT PremiseID FROM SERVICE_REQUEST WHERE RequestID = @req);

INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, Phone, FirstName, LastName, AccountStatus, BirthDate, Photo, ApprovalStatus, ApprovalDecidedAt, ApprovedBy)
VALUES (N'test_tec_b', '$2y$10$abcdefghijklmnopqrstuv', 'Technician', 'tecb@test.cy', NULL, N'Β', N'Τεχνικός', 'Active',
        '1991-01-01', N'photos/test_tec_b.jpg', 'Approved', '2026-11-01 08:00:00', 2);
DECLARE @techB INT = SCOPE_IDENTITY();

-- ---------- sp_operator_assert ----------
BEGIN TRY EXEC sp_operator_assert 2; PRINT 'OK   operator passes operator assert'; END TRY
BEGIN CATCH PRINT 'FAIL operator assert: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_operator_assert 3; PRINT 'FAIL consumer passed operator assert'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52100 PRINT 'OK   consumer -> 52100' ELSE PRINT 'FAIL operator assert consumer: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Πλήρης διαδρομή: αίτημα -> εργασία -> αποδοχή -> σημειώσεις -> συνημμένο -> ολοκλήρωση ----------
DECLARE @rt TABLE (TaskID INT);
INSERT @rt EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 11:00:00', 5, NULL, NULL, @req, NULL;
DECLARE @t1 INT = (SELECT TaskID FROM @rt);
IF @t1 IS NOT NULL AND EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @t1 AND Status = 'Assigned' AND TechnicianID = 5
                               AND PremiseID = @reqPremise AND RequestID = @req)
    PRINT 'OK   operator creates task from request (premise taken from request)' ELSE PRINT 'FAIL create task from request';
IF EXISTS (SELECT 1 FROM SERVICE_REQUEST WHERE RequestID = @req AND Status = 'Assigned')
    PRINT 'OK   request -> Assigned (X1)' ELSE PRINT 'FAIL request not Assigned';
IF EXISTS (SELECT 1 FROM NOTIFIES WHERE TaskID = @t1 AND UserID = @reqUser)
    PRINT 'OK   requesting consumer notified' ELSE PRINT 'FAIL consumer not notified';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'FIELD_TASK' AND ObjectID = CAST(@t1 AS VARCHAR(100)) AND Action = 'Create task')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'SERVICE_REQUEST' AND ObjectID = CAST(@req AS VARCHAR(100)) AND Action = 'Assign request' AND NewState = 'Assigned')
    PRINT 'OK   create -> audit rows (task and request)' ELSE PRINT 'FAIL create audit';

-- Το ίδιο αίτημα δεν ανατίθεται δεύτερη φορά.
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 12:00:00', '2027-06-15 13:00:00', 5, NULL, NULL, @req, NULL; PRINT 'FAIL request assigned twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52104 PRINT 'OK   request not Submitted -> 52104' ELSE PRINT 'FAIL assigned twice: ' + ERROR_MESSAGE(); END CATCH;

-- tech1 τη βλέπει με γεωγραφικές συντεταγμένες.
DECLARE @lt TABLE (TaskID INT, TaskType VARCHAR(17), ScheduledFrom DATETIME2(0), ScheduledTo DATETIME2(0), Status VARCHAR(9),
                   PremiseID INT, Address NVARCHAR(200), Latitude DECIMAL(9,6), Longitude DECIMAL(9,6),
                   MeterID INT, SerialNumber VARCHAR(40), RequestID INT, RequestDescription NVARCHAR(1000));
INSERT @lt EXEC sp_tech_list_tasks 5, 'Assigned';
IF EXISTS (SELECT 1 FROM @lt l JOIN PREMISE p ON p.PremiseID = l.PremiseID
           WHERE l.TaskID = @t1 AND l.Latitude = p.Latitude AND l.Longitude = p.Longitude AND l.RequestDescription IS NOT NULL)
    PRINT 'OK   tech1 lists the task with latitude/longitude and request description' ELSE PRINT 'FAIL tech list tasks';
BEGIN TRY EXEC sp_tech_list_tasks 6; PRINT 'FAIL pending technician listed tasks'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52000 PRINT 'OK   pending technician list tasks -> 52000' ELSE PRINT 'FAIL list pending: ' + ERROR_MESSAGE(); END CATCH;

-- Ολοκλήρωση πριν την αποδοχή, και αποδοχή από άλλον τεχνικό.
BEGIN TRY EXEC sp_tech_complete_task 5, @t1, N'Πολύ νωρίς'; PRINT 'FAIL completed before accepting'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52127 PRINT 'OK   complete before accept -> 52127' ELSE PRINT 'FAIL complete before accept: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_accept_task @techB, @t1; PRINT 'FAIL other technician accepted the task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   other technician accepts -> 52120' ELSE PRINT 'FAIL other accepts: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 3, 'Technical check', '2027-06-15 14:00:00', '2027-06-15 15:00:00', 5, 1; PRINT 'FAIL consumer created a task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52100 PRINT 'OK   consumer creates task -> 52100' ELSE PRINT 'FAIL consumer create: ' + ERROR_MESSAGE(); END CATCH;

-- Αποδοχή.
EXEC sp_tech_accept_task 5, @t1;
IF EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @t1 AND Status = 'Accepted') PRINT 'OK   accept -> Accepted' ELSE PRINT 'FAIL accept';
BEGIN TRY EXEC sp_tech_accept_task 5, @t1; PRINT 'FAIL accepted twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52123 PRINT 'OK   accept twice -> 52123' ELSE PRINT 'FAIL accept twice: ' + ERROR_MESSAGE(); END CATCH;

-- Δύο σημειώσεις: NoteNo 1 και 2.
DECLARE @n1 TABLE (NoteNo INT);
DECLARE @n2 TABLE (NoteNo INT);
INSERT @n1 EXEC sp_tech_add_note 5, @t1, 'Observation', N'Ο μετρητής είναι σε ντουλάπι.';
INSERT @n2 EXEC sp_tech_add_note 5, @t1, 'Finding', N'Σπασμένη σφράγιση.';
IF (SELECT NoteNo FROM @n1) = 1 AND (SELECT NoteNo FROM @n2) = 2
   AND (SELECT COUNT(*) FROM TASK_NOTE WHERE TaskID = @t1 AND WrittenBy = 5) = 2
    PRINT 'OK   two notes numbered 1 and 2' ELSE PRINT 'FAIL note numbering';
BEGIN TRY EXEC sp_tech_add_note 5, @t1, 'Opinion', N'x'; PRINT 'FAIL bad note kind accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52125 PRINT 'OK   bad note kind -> 52125' ELSE PRINT 'FAIL note kind: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_add_note @techB, @t1, 'Observation', N'ξένη εργασία'; PRINT 'FAIL note on foreign task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   note on someone else''s task -> 52120' ELSE PRINT 'FAIL foreign note: ' + ERROR_MESSAGE(); END CATCH;

-- Συνημμένο.
DECLARE @at TABLE (AttachmentID INT);
INSERT @at EXEC sp_tech_add_attachment 5, @t1, N'uploads/task_test.jpg', N'Φωτογραφία σφράγισης';
IF (SELECT COUNT(*) FROM ATTACHMENT WHERE TaskID = @t1 AND FilePath = N'uploads/task_test.jpg') = 1 AND (SELECT AttachmentID FROM @at) IS NOT NULL
    PRINT 'OK   attachment saved' ELSE PRINT 'FAIL attachment';
BEGIN TRY EXEC sp_tech_add_attachment 5, @t1, N'  '; PRINT 'FAIL empty attachment path accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52126 PRINT 'OK   empty attachment path -> 52126' ELSE PRINT 'FAIL attachment path: ' + ERROR_MESSAGE(); END CATCH;

-- sp_task_get / notes / attachments.
DECLARE @g TABLE (TaskID INT, TaskType VARCHAR(17), ScheduledFrom DATETIME2(0), ScheduledTo DATETIME2(0), Status VARCHAR(9),
                  Result NVARCHAR(1000), CreatedAt DATETIME2(0), CompletedAt DATETIME2(0), TechnicianID INT, TechnicianUsername NVARCHAR(50),
                  PremiseID INT, Address NVARCHAR(200), Latitude DECIMAL(9,6), Longitude DECIMAL(9,6),
                  MeterID INT, SerialNumber VARCHAR(40), RequestID INT, RequestDescription NVARCHAR(1000));
INSERT @g EXEC sp_task_get 2, @t1;
IF (SELECT COUNT(*) FROM @g WHERE TaskID = @t1 AND TechnicianUsername = N'tech1') = 1 PRINT 'OK   operator reads task' ELSE PRINT 'FAIL operator get task';
DELETE FROM @g;
INSERT @g EXEC sp_task_get 5, @t1;
IF (SELECT COUNT(*) FROM @g) = 1 PRINT 'OK   technician reads own task' ELSE PRINT 'FAIL tech get own task';
BEGIN TRY EXEC sp_task_get @techB, @t1; PRINT 'FAIL technician read foreign task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician reads foreign task -> 52120' ELSE PRINT 'FAIL foreign get: ' + ERROR_MESSAGE(); END CATCH;
DECLARE @gn TABLE (NoteNo SMALLINT, NoteKind VARCHAR(11), Text NVARCHAR(2000), WrittenAt DATETIME2(0), WrittenBy INT, WrittenByUsername NVARCHAR(50));
INSERT @gn EXEC sp_task_notes 2, @t1;
IF (SELECT COUNT(*) FROM @gn) = 2 PRINT 'OK   sp_task_notes returns 2 notes' ELSE PRINT 'FAIL sp_task_notes';
DECLARE @ga TABLE (AttachmentID INT, FilePath NVARCHAR(400), Caption NVARCHAR(200), UploadedAt DATETIME2(0));
INSERT @ga EXEC sp_task_attachments 2, @t1;
IF (SELECT COUNT(*) FROM @ga) = 1 PRINT 'OK   sp_task_attachments returns 1' ELSE PRINT 'FAIL sp_task_attachments';

-- Ολοκλήρωση.
BEGIN TRY EXEC sp_tech_complete_task 5, @t1, N'  '; PRINT 'FAIL empty result accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52128 PRINT 'OK   empty result -> 52128' ELSE PRINT 'FAIL empty result: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_tech_complete_task 5, @t1, N'Αντικαταστάθηκε η σφράγιση, ο μετρητής λειτουργεί.';
IF EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @t1 AND Status = 'Done' AND CompletedAt IS NOT NULL AND Result IS NOT NULL)
    PRINT 'OK   complete -> Done with CompletedAt and Result' ELSE PRINT 'FAIL complete';
IF EXISTS (SELECT 1 FROM SERVICE_REQUEST WHERE RequestID = @req AND Status = 'Resolved') PRINT 'OK   request -> Resolved (X1)' ELSE PRINT 'FAIL request not Resolved';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'FIELD_TASK' AND ObjectID = CAST(@t1 AS VARCHAR(100)) AND Action = 'Complete task' AND NewState = 'Done' AND PerformedBy = 5)
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'SERVICE_REQUEST' AND ObjectID = CAST(@req AS VARCHAR(100)) AND Action = 'Resolve request' AND NewState = 'Resolved')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'FIELD_TASK' AND ObjectID = CAST(@t1 AS VARCHAR(100)) AND Action = 'Accept task')
    PRINT 'OK   accept/complete -> audit rows' ELSE PRINT 'FAIL complete audit';
BEGIN TRY EXEC sp_task_cancel 2, @t1, N'Λάθος'; PRINT 'FAIL cancelled a Done task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52122 PRINT 'OK   cancel Done task -> 52122' ELSE PRINT 'FAIL cancel done: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Αρνήσεις στη δημιουργία ----------
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 6, 1; PRINT 'FAIL Pending technician assigned'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52103 PRINT 'OK   Pending technician as assignee -> 52103' ELSE PRINT 'FAIL pending assignee: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Installation', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1, 1; PRINT 'FAIL Installation with a meter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52109 PRINT 'OK   Installation with MeterID -> 52109' ELSE PRINT 'FAIL installation meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Replacement', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1, NULL; PRINT 'FAIL Replacement without meter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52110 PRINT 'OK   Replacement without meter -> 52110' ELSE PRINT 'FAIL replacement meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, NULL, NULL; PRINT 'FAIL task without target accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52107 PRINT 'OK   no premise and no meter -> 52107' ELSE PRINT 'FAIL no target: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 11:00:00', '2027-06-15 10:00:00', 5, 1; PRINT 'FAIL end before start accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52102 PRINT 'OK   end before start -> 52102' ELSE PRINT 'FAIL schedule: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Roof check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1; PRINT 'FAIL bad type accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52101 PRINT 'OK   bad task type -> 52101' ELSE PRINT 'FAIL bad type: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1, NULL, 99999; PRINT 'FAIL unknown request accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52105 PRINT 'OK   unknown request -> 52105' ELSE PRINT 'FAIL unknown request: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 99999; PRINT 'FAIL unknown premise accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52111 PRINT 'OK   unknown premise -> 52111' ELSE PRINT 'FAIL unknown premise: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1, NULL, NULL, '3,99999'; PRINT 'FAIL unknown notify user accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52113 PRINT 'OK   unknown notify user -> 52113' ELSE PRINT 'FAIL notify user: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 09:00:00', '2027-06-15 10:00:00', 5, 1, NULL, NULL, '3,2,3'; PRINT 'OK   notify list with duplicates accepted'; END TRY
BEGIN CATCH PRINT 'FAIL notify list: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM NOTIFIES n JOIN FIELD_TASK t ON t.TaskID = n.TaskID
    WHERE t.TechnicianID = 5 AND t.ScheduledFrom = '2027-06-15 09:00:00' AND t.RequestID IS NULL AND n.UserID IN (2, 3)) = 2
    PRINT 'OK   NOTIFIES rows for the listed users' ELSE PRINT 'FAIL NOTIFIES rows';
IF NOT EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskType = 'Roof check' OR (TechnicianID = 6)) PRINT 'OK   refused creations left no rows' ELSE PRINT 'FAIL refused creations left rows';

-- ---------- Διαθεσιμότητα (2027-06-16): ζώνη 08:00-12:00 ----------
INSERT AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (5, '2027-06-16', '08:00', '12:00');
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-16 14:00:00', '2027-06-16 15:00:00', 5, 1; PRINT 'FAIL task outside availability accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52112 PRINT 'OK   outside declared availability -> 52112' ELSE PRINT 'FAIL outside availability: ' + ERROR_MESSAGE(); END CATCH;
DECLARE @ra TABLE (TaskID INT);
INSERT @ra EXEC sp_task_create 2, 'Technical check', '2027-06-16 09:00:00', '2027-06-16 10:00:00', 5, 1;
DECLARE @t3 INT = (SELECT TaskID FROM @ra);
IF @t3 IS NOT NULL PRINT 'OK   inside declared availability accepted' ELSE PRINT 'FAIL inside availability';

-- ---------- Αλλαγή τεχνικού και ακύρωση ----------
BEGIN TRY EXEC sp_task_reassign 5, @t3, @techB; PRINT 'FAIL technician reassigned a task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52100 PRINT 'OK   technician reassigns -> 52100' ELSE PRINT 'FAIL tech reassign: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_task_reassign 2, @t3, @techB;
IF EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @t3 AND TechnicianID = @techB AND Status = 'Assigned')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'FIELD_TASK' AND ObjectID = CAST(@t3 AS VARCHAR(100)) AND Action = 'Reassign task')
    PRINT 'OK   reassign Assigned task + audit' ELSE PRINT 'FAIL reassign';
BEGIN TRY EXEC sp_task_reassign 2, @t3, 6; PRINT 'FAIL reassigned to Pending technician'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52103 PRINT 'OK   reassign to Pending technician -> 52103' ELSE PRINT 'FAIL reassign pending: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_reassign 2, @t1, @techB; PRINT 'FAIL reassigned a Done task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52121 PRINT 'OK   reassign Done task -> 52121' ELSE PRINT 'FAIL reassign done: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @lo TABLE (TaskID INT, TaskType VARCHAR(17), ScheduledFrom DATETIME2(0), ScheduledTo DATETIME2(0), Status VARCHAR(9),
                   Result NVARCHAR(1000), CompletedAt DATETIME2(0), TechnicianID INT, TechnicianUsername NVARCHAR(50),
                   PremiseID INT, Address NVARCHAR(200), MeterID INT, RequestID INT);
INSERT @lo EXEC sp_task_list 2, 'Assigned';
IF EXISTS (SELECT 1 FROM @lo WHERE TaskID = @t3 AND TechnicianUsername = N'test_tec_b') AND NOT EXISTS (SELECT 1 FROM @lo WHERE Status <> 'Assigned')
    PRINT 'OK   operator lists tasks with status filter' ELSE PRINT 'FAIL sp_task_list';
BEGIN TRY EXEC sp_task_list 5; PRINT 'FAIL technician used operator list'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52100 PRINT 'OK   technician sp_task_list -> 52100' ELSE PRINT 'FAIL tech sp_task_list: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_cancel 2, @t3, N'  '; PRINT 'FAIL cancel without reason'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52129 PRINT 'OK   cancel without reason -> 52129' ELSE PRINT 'FAIL cancel reason: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_task_cancel 2, @t3, N'Δοκιμή ακύρωσης';
IF EXISTS (SELECT 1 FROM FIELD_TASK WHERE TaskID = @t3 AND Status = 'Cancelled')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'FIELD_TASK' AND ObjectID = CAST(@t3 AS VARCHAR(100)) AND Action = 'Cancel task' AND NewState = 'Cancelled')
    PRINT 'OK   cancel Assigned task + audit' ELSE PRINT 'FAIL cancel';
BEGIN TRY EXEC sp_tech_add_note @techB, @t3, 'Observation', N'σε ακυρωμένη'; PRINT 'FAIL note on cancelled task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52124 PRINT 'OK   note on cancelled task -> 52124' ELSE PRINT 'FAIL note cancelled: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Καθαρισμός: ο test_tec_b δεν μένει εγκεκριμένος, η διαθεσιμότητα του tech1 φεύγει ----------
DELETE FROM AVAILABILITY WHERE UserID = 5 AND AvailDate = '2027-06-16';
UPDATE USER_ACCOUNT SET ApprovalStatus = 'Suspended' WHERE UserID = @techB;
BEGIN TRY EXEC sp_task_create 2, 'Technical check', '2027-06-15 17:00:00', '2027-06-15 18:00:00', @techB, 1; PRINT 'FAIL suspended technician assigned'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52103 PRINT 'OK   Suspended technician as assignee -> 52103' ELSE PRINT 'FAIL suspended assignee: ' + ERROR_MESSAGE(); END CATCH;
GO
