-- test_security.sql : SEC-1, horizontal access. A user of an owner-scoped role (Consumer, Technician,
-- Aggregator) passes the id of ANOTHER user's object, as a forged form would. Each call must be refused
-- by the procedure and the object must stay unchanged. Base users: consumer1 = 3, consumer2 = 4,
-- operator = 2, admin = 1, tech1 = 5, aggregator1 = 10 (data/small/00_base.sql).
SET NOCOUNT ON;
PRINT '--- test_security (SEC-1)';
DECLARE @c1 INT = 3, @c2 INT = 4;

-- Objects of consumer1 to attack.
DECLARE @prem INT = (SELECT TOP 1 h.PremiseID FROM HOLDING h WHERE h.UserID = @c1 AND h.EndDate IS NULL ORDER BY h.PremiseID);
DECLARE @meter INT = (SELECT TOP 1 mi.MeterID FROM METER_INSTALLATION mi WHERE mi.PremiseID = @prem AND mi.RemovedAt IS NULL);
DECLARE @r TABLE (RequestID INT);
INSERT @r EXEC sp_consumer_submit_request @c1, @prem, NULL, 'Fault report', N'SEC-1 test';
DECLARE @req INT = (SELECT RequestID FROM @r);

DECLARE @th TABLE (ThresholdID INT);
INSERT @th EXEC sp_consumer_set_threshold @c1, @prem, 'Day', 99.5;
DECLARE @thr INT = (SELECT ThresholdID FROM @th);
DECLARE @from DATETIME2 = DATEADD(DAY, -1, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2)), @to DATETIME2 = CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2);

BEGIN TRY EXEC sp_consumer_end_holding @c2, @prem; PRINT 'FAIL consumer2 cannot end consumer1''s holding'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51006 PRINT 'OK   consumer2 cannot end consumer1''s holding -> 51006' ELSE PRINT 'FAIL consumer2 cannot end consumer1''s holding: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_cancel_request @c2, @req; PRINT 'FAIL consumer2 cannot cancel consumer1''s request'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51023 PRINT 'OK   consumer2 cannot cancel consumer1''s request -> 51023' ELSE PRINT 'FAIL consumer2 cannot cancel consumer1''s request: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_remove_threshold @c2, @thr; PRINT 'FAIL consumer2 cannot remove consumer1''s threshold'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51203 PRINT 'OK   consumer2 cannot remove consumer1''s threshold -> 51203' ELSE PRINT 'FAIL consumer2 cannot remove consumer1''s threshold: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_readings @c2, @meter, @from, @to; PRINT 'FAIL consumer2 cannot read consumer1''s meter'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51100 PRINT 'OK   consumer2 cannot read consumer1''s meter -> 51100' ELSE PRINT 'FAIL consumer2 cannot read consumer1''s meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_history @c2, @meter, 'Month', '2026-01-01', '2026-12-31'; PRINT 'FAIL consumer2 cannot read consumer1''s history'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51100 PRINT 'OK   consumer2 cannot read consumer1''s history -> 51100' ELSE PRINT 'FAIL consumer2 cannot read consumer1''s history: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_set_threshold @c2, @prem, 'Day', 1; PRINT 'FAIL consumer2 cannot set a threshold on consumer1''s premise'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51200 PRINT 'OK   consumer2 cannot set a threshold on consumer1''s premise -> 51200' ELSE PRINT 'FAIL consumer2 cannot set a threshold on consumer1''s premise: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_submit_request @c2, @prem, NULL, 'Fault report', N'forged'; PRINT 'FAIL consumer2 cannot file a request for consumer1''s premise'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51006 PRINT 'OK   consumer2 cannot file a request for consumer1''s premise -> 51006' ELSE PRINT 'FAIL consumer2 cannot file a request for consumer1''s premise: ' + ERROR_MESSAGE(); END CATCH;
IF EXISTS (SELECT 1 FROM HOLDING WHERE UserID = @c1 AND PremiseID = @prem AND EndDate IS NULL)
   AND EXISTS (SELECT 1 FROM SERVICE_REQUEST WHERE RequestID = @req AND Status <> 'Cancelled')
   AND EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE ThresholdID = @thr)
    PRINT 'OK   consumer1''s holding, request and threshold unchanged' ELSE PRINT 'FAIL consumer1''s objects changed';

-- Technician: a second approved technician tries tech1's task (base task 1 belongs to tech1 = 5).
DECLARE @hash VARCHAR(255) = (SELECT PasswordHash FROM USER_ACCOUNT WHERE UserID = 5);
DECLARE @nt TABLE (UserID INT);
INSERT @nt EXEC sp_auth_register_technician 'sec1_tech', @hash, 'sec1_tech@example.cy', '99001001', N'Τεστ', N'Ασφάλεια', '1990-01-01', N'photos/sec1.jpg', '1';
DECLARE @t2 INT = (SELECT UserID FROM @nt);
-- Test setup only: approval through sp_operator_decide_technician needs 3 reviewed documents (tested in
-- test_technician.sql); here we only need an approved second technician, so we set the state directly.
UPDATE USER_ACCOUNT SET ApprovalStatus = 'Approved', ApprovedBy = 2, ApprovalDecidedAt = SYSUTCDATETIME() WHERE UserID = @t2;
DECLARE @task INT = (SELECT MIN(TaskID) FROM FIELD_TASK WHERE TechnicianID = 5);
DECLARE @notes INT = (SELECT COUNT(*) FROM TASK_NOTE WHERE TaskID = @task);
BEGIN TRY EXEC sp_task_get @t2, @task; PRINT 'FAIL technician cannot open another technician''s task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician cannot open another technician''s task -> 52120' ELSE PRINT 'FAIL technician cannot open another technician''s task: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_notes @t2, @task; PRINT 'FAIL technician cannot read another technician''s notes'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician cannot read another technician''s notes -> 52120' ELSE PRINT 'FAIL technician cannot read another technician''s notes: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_add_note @t2, @task, 'Observation', N'forged'; PRINT 'FAIL technician cannot add a note to another technician''s task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician cannot add a note to another technician''s task -> 52120' ELSE PRINT 'FAIL technician cannot add a note to another technician''s task: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_accept_task @t2, @task; PRINT 'FAIL technician cannot accept another technician''s task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician cannot accept another technician''s task -> 52120' ELSE PRINT 'FAIL technician cannot accept another technician''s task: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tech_complete_task @t2, @task, N'forged'; PRINT 'FAIL technician cannot complete another technician''s task'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52120 PRINT 'OK   technician cannot complete another technician''s task -> 52120' ELSE PRINT 'FAIL technician cannot complete another technician''s task: ' + ERROR_MESSAGE(); END CATCH;

IF (SELECT COUNT(*) FROM TASK_NOTE WHERE TaskID = @task) = @notes
   AND (SELECT TechnicianID FROM FIELD_TASK WHERE TaskID = @task) = 5
    PRINT 'OK   tech1''s task unchanged' ELSE PRINT 'FAIL tech1''s task changed';

-- Aggregator: a user of a second aggregator company tries aggregator1's portfolio 1.
INSERT AGGREGATOR (Name) VALUES (N'SEC-1 Δεύτερος Aggregator');
DECLARE @ag2 INT = SCOPE_IDENTITY();
DECLARE @na TABLE (UserID INT);
INSERT @na EXEC sp_admin_create_user 1, 'Aggregator', 'sec1_aggr', @hash, 'sec1_aggr@example.cy', NULL, N'Τεστ', N'Aggregator', NULL, @ag2;
DECLARE @a2 INT = (SELECT UserID FROM @na);
DECLARE @pf INT = 1, @pprem INT = (SELECT TOP 1 PremiseID FROM PREMISE WHERE PremiseID NOT IN (SELECT PremiseID FROM INCLUDES WHERE PortfolioID = 1));
DECLARE @inc INT = (SELECT COUNT(*) FROM INCLUDES WHERE PortfolioID = @pf);
BEGIN TRY EXEC sp_aggregator_list_portfolio_premises @a2, @pf; PRINT 'FAIL aggregator cannot list another company''s portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52512 PRINT 'OK   aggregator cannot list another company''s portfolio -> 52512' ELSE PRINT 'FAIL aggregator cannot list another company''s portfolio: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_save_portfolio @a2, @pf, N'forged'; PRINT 'FAIL aggregator cannot rename another company''s portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52512 PRINT 'OK   aggregator cannot rename another company''s portfolio -> 52512' ELSE PRINT 'FAIL aggregator cannot rename another company''s portfolio: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_add_premise @a2, @pf, @pprem; PRINT 'FAIL aggregator cannot add a premise to another company''s portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52512 PRINT 'OK   aggregator cannot add a premise to another company''s portfolio -> 52512' ELSE PRINT 'FAIL aggregator cannot add a premise to another company''s portfolio: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM INCLUDES WHERE PortfolioID = @pf) = @inc AND (SELECT Name FROM PORTFOLIO WHERE PortfolioID = @pf) <> N'forged'
    PRINT 'OK   aggregator1''s portfolio unchanged' ELSE PRINT 'FAIL aggregator1''s portfolio changed';
