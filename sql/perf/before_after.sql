-- =====================================================================
-- before_after.sql : PRF-3. Το "πριν/μετά" των ευρετηρίων. Τρέχει στη βάση με το ΜΕΓΑΛΟ σύνολο δεδομένων
-- (~64.000 μετρήσεις, 2.000 υποστατικά, 4.500 τιμολόγια), μετά το sql/indexes.sql.
-- Ξανατρέχεται όσες φορές θέλεις. Στο τέλος ΤΑ ΕΥΡΕΤΗΡΙΑ ΥΠΑΡΧΟΥΝ ΞΑΝΑ. Καμία μόνιμη αλλαγή δεδομένων
-- (οι δοκιμαστικές αλλαγές γίνονται μέσα σε συναλλαγή με ROLLBACK).
--
-- Οδηγίες SSMS: Query > Include Actual Execution Plan (Ctrl+M) ΠΡΙΝ το τρέξιμο. Τρέξε το αρχείο μία φορά.
-- Καρτέλα Messages: "Table 'INVOICE'. Scan count ..., logical reads N" = το νούμερο για τον πίνακα.
-- Καρτέλα Execution plan: screenshot του πλάνου ΠΡΙΝ (Scan) και ΜΕΤΑ (Seek) για κάθε περίπτωση.
-- Τα SET SHOWPLAN_TEXT batches δίνουν το εκτιμώμενο πλάνο ως κείμενο (το query δεν εκτελείται).
-- =====================================================================
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- ΠΕΡΙΠΤΩΣΗ A: τιμολόγια καταναλωτή (sp_consumer_list_invoices), ευρετήριο IX_INVOICE_User_IssueDate
-- =====================================================================
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_INVOICE_User_IssueDate' AND object_id = OBJECT_ID('INVOICE'))
    DROP INDEX IX_INVOICE_User_IssueDate ON INVOICE;
GO
DECLARE @u INT = (SELECT TOP 1 UserID FROM INVOICE GROUP BY UserID ORDER BY COUNT(*) DESC, UserID);
DECLARE @mine INT = (SELECT COUNT(*) FROM INVOICE WHERE UserID = @u), @all INT = (SELECT COUNT(*) FROM INVOICE);
PRINT N'=== A1: ΠΡΙΝ (χωρίς ευρετήριο). UserID = ' + CAST(@u AS VARCHAR(10)) + N', τιμολόγια του = '
      + CAST(@mine AS VARCHAR(10)) + N' από ' + CAST(@all AS VARCHAR(10));
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;   -- ψυχρή cache: δίκαιη σύγκριση
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT i.InvoiceID, i.IssueDate, i.PeriodFrom, i.PeriodTo, i.Amount, i.Status, i.ContractID
INTO #a1
FROM INVOICE i WHERE i.UserID = @u ORDER BY i.IssueDate DESC, i.InvoiceID DESC;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
DROP TABLE #a1;
GO

CREATE NONCLUSTERED INDEX IX_INVOICE_User_IssueDate
    ON INVOICE (UserID, IssueDate DESC)
    INCLUDE (Amount, Status, PeriodFrom, PeriodTo, ContractID);
GO
DECLARE @u INT = (SELECT TOP 1 UserID FROM INVOICE GROUP BY UserID ORDER BY COUNT(*) DESC, UserID);
PRINT N'=== A2: ΜΕΤΑ (με ευρετήριο). UserID = ' + CAST(@u AS VARCHAR(10));
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT i.InvoiceID, i.IssueDate, i.PeriodFrom, i.PeriodTo, i.Amount, i.Status, i.ContractID
INTO #a2
FROM INVOICE i WHERE i.UserID = @u ORDER BY i.IssueDate DESC, i.InvoiceID DESC;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
DROP TABLE #a2;
GO

-- Εκτιμώμενο πλάνο ως κείμενο. Άλλαξε το @u αν ο UserID 3 έχει λίγα τιμολόγια.
-- ΜΕΤΑ (το ευρετήριο υπάρχει τώρα):
SET SHOWPLAN_TEXT ON;
GO
DECLARE @u INT = 3;
SELECT i.InvoiceID, i.IssueDate, i.PeriodFrom, i.PeriodTo, i.Amount, i.Status, i.ContractID
FROM INVOICE i WHERE i.UserID = @u ORDER BY i.IssueDate DESC, i.InvoiceID DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO
-- ΠΡΙΝ (hint στο PK = όπως χωρίς το ευρετήριο):
SET SHOWPLAN_TEXT ON;
GO
DECLARE @u INT = 3;
SELECT i.InvoiceID, i.IssueDate, i.PeriodFrom, i.PeriodTo, i.Amount, i.Status, i.ContractID
FROM INVOICE i WITH (INDEX(PK_INVOICE)) WHERE i.UserID = @u ORDER BY i.IssueDate DESC, i.InvoiceID DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO

-- =====================================================================
-- ΠΕΡΙΠΤΩΣΗ B: Pending μετρήσεις του VEE (sp_dso_run_vee βήμα 1), ευρετήριο IX_RAW_READING_Pending
-- Στα δεδομένα δεν υπάρχουν Pending, άρα μέσα σε συναλλαγή σημαίνουμε ως Pending τις μετρήσεις της
-- τελευταίας ημέρας και κάνουμε ROLLBACK στο τέλος.
-- =====================================================================
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RAW_READING_Pending' AND object_id = OBJECT_ID('RAW_READING'))
    DROP INDEX IX_RAW_READING_Pending ON RAW_READING;
GO
DECLARE @To DATETIME2(0) = DATEADD(SECOND, 1, (SELECT MAX(IntervalStart) FROM RAW_READING));
DECLARE @From DATETIME2(0) = DATEADD(DAY, -1, @To);
DECLARE @rawAll INT = (SELECT COUNT(*) FROM RAW_READING), @pend INT;
PRINT N'=== B1: ΠΡΙΝ (χωρίς ευρετήριο). Όλες οι raw = ' + CAST(@rawAll AS VARCHAR(10));
BEGIN TRAN;
    UPDATE RAW_READING SET VeeStatus = 'Pending' WHERE IntervalStart >= @From AND IntervalStart < @To AND VeeStatus <> 'Pending';
    SET @pend = (SELECT COUNT(*) FROM RAW_READING WHERE VeeStatus = 'Pending');
    PRINT N'Pending στο τεστ = ' + CAST(@pend AS VARCHAR(10));
    SET STATISTICS IO ON; SET STATISTICS TIME ON;
    SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue
    INTO #b1
    FROM RAW_READING r WHERE r.VeeStatus = 'Pending' AND r.IntervalStart >= @From AND r.IntervalStart < @To;
    SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
ROLLBACK;
IF OBJECT_ID('tempdb..#b1') IS NOT NULL DROP TABLE #b1;
GO

CREATE NONCLUSTERED INDEX IX_RAW_READING_Pending
    ON RAW_READING (IntervalStart, MeterID, ObisCode)
    INCLUDE (ReceivedValue)
    WHERE VeeStatus = 'Pending';
GO
DECLARE @To DATETIME2(0) = DATEADD(SECOND, 1, (SELECT MAX(IntervalStart) FROM RAW_READING));
DECLARE @From DATETIME2(0) = DATEADD(DAY, -1, @To);
PRINT N'=== B2: ΜΕΤΑ (με φιλτραρισμένο ευρετήριο)';
BEGIN TRAN;
    UPDATE RAW_READING SET VeeStatus = 'Pending' WHERE IntervalStart >= @From AND IntervalStart < @To AND VeeStatus <> 'Pending';
    SET STATISTICS IO ON; SET STATISTICS TIME ON;
    SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue
    INTO #b2
    FROM RAW_READING r WHERE r.VeeStatus = 'Pending' AND r.IntervalStart >= @From AND r.IntervalStart < @To;
    SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
ROLLBACK;
IF OBJECT_ID('tempdb..#b2') IS NOT NULL DROP TABLE #b2;
GO

-- Εκτιμώμενα πλάνα ως κείμενο. ΜΕΤΑ:
SET SHOWPLAN_TEXT ON;
GO
DECLARE @From DATETIME2(0) = '2026-11-19', @To DATETIME2(0) = '2026-11-20';
SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue
FROM RAW_READING r WHERE r.VeeStatus = 'Pending' AND r.IntervalStart >= @From AND r.IntervalStart < @To;
GO
SET SHOWPLAN_TEXT OFF;
GO
-- ΠΡΙΝ (hint στο PK = όπως χωρίς το ευρετήριο):
SET SHOWPLAN_TEXT ON;
GO
DECLARE @From DATETIME2(0) = '2026-11-19', @To DATETIME2(0) = '2026-11-20';
SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue
FROM RAW_READING r WITH (INDEX(PK_RAW_READING)) WHERE r.VeeStatus = 'Pending' AND r.IntervalStart >= @From AND r.IntervalStart < @To;
GO
SET SHOWPLAN_TEXT OFF;
GO

-- =====================================================================
-- ΠΕΡΙΠΤΩΣΗ Γ: λίστα εργασιών τεχνικού, ευρετήριο IX_FIELD_TASK_Technician_Status
-- =====================================================================
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FIELD_TASK_Technician_Status' AND object_id = OBJECT_ID('FIELD_TASK'))
    DROP INDEX IX_FIELD_TASK_Technician_Status ON FIELD_TASK;
GO
DECLARE @t INT = (SELECT TOP 1 TechnicianID FROM FIELD_TASK GROUP BY TechnicianID ORDER BY COUNT(*) DESC, TechnicianID);
PRINT N'=== C1: ΠΡΙΝ. TechnicianID = ' + ISNULL(CAST(@t AS VARCHAR(10)), N'NULL (δεν υπάρχουν εργασίες)');
SET STATISTICS IO ON;
SELECT t.TaskID, t.TaskType, t.ScheduledFrom, t.ScheduledTo, t.Status, t.PremiseID, t.MeterID, t.RequestID
INTO #c1 FROM FIELD_TASK t WHERE t.TechnicianID = @t ORDER BY t.ScheduledFrom DESC, t.TaskID DESC;
SET STATISTICS IO OFF;
DROP TABLE #c1;
GO
CREATE NONCLUSTERED INDEX IX_FIELD_TASK_Technician_Status
    ON FIELD_TASK (TechnicianID, Status)
    INCLUDE (TaskType, ScheduledFrom, ScheduledTo, PremiseID, MeterID, RequestID);
GO
DECLARE @t INT = (SELECT TOP 1 TechnicianID FROM FIELD_TASK GROUP BY TechnicianID ORDER BY COUNT(*) DESC, TechnicianID);
PRINT N'=== C2: ΜΕΤΑ';
SET STATISTICS IO ON;
SELECT t.TaskID, t.TaskType, t.ScheduledFrom, t.ScheduledTo, t.Status, t.PremiseID, t.MeterID, t.RequestID
INTO #c2 FROM FIELD_TASK t WHERE t.TechnicianID = @t ORDER BY t.ScheduledFrom DESC, t.TaskID DESC;
SET STATISTICS IO OFF;
DROP TABLE #c2;
GO

-- Έλεγχος ότι και τα 3 ευρετήρια υπάρχουν στο τέλος.
SELECT name, has_filter FROM sys.indexes
WHERE name IN ('IX_INVOICE_User_IssueDate', 'IX_RAW_READING_Pending', 'IX_FIELD_TASK_Technician_Status');
GO
