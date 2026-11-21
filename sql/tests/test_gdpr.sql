-- =====================================================================
-- test_gdpr.sql : έλεγχοι για το procs_gdpr.sql (GDP-1, δικαίωμα λήθης).
-- Βασικοί χρήστες: admin = 1, operator = 2, consumer1 = 3, consumer2 = 4.
-- ΠΟΤΕ δεν εφαρμόζουμε GDPR στους consumer1/consumer2 (χρειάζονται για το demo):
-- τα tests φτιάχνουν δικούς τους καταναλωτές test_gdp_*. Κάθε γραμμή τυπώνει OK ή FAIL.
-- ΣΗΜ.: ΟΧΙ BEGIN TRAN γύρω από όλο το αρχείο (το THROW με XACT_ABORT το χαλάει).
-- =====================================================================
SET NOCOUNT ON;

-- ---------- Νέοι καταναλωτές: A (ευτυχής ροή), B (απόρριψη Operator), C (απόρριψη Admin) ----------
DECLARE @r TABLE (UserID INT);
INSERT @r EXEC sp_auth_register_consumer N'test_gdp_a', '$2y$10$abcdefghijklmnopqrstuv', 'gdp_a@test.cy', '99111111', N'Άννα', N'Δοκιμή', 'Email,SMS';
DECLARE @a INT = (SELECT MAX(UserID) FROM @r);
DELETE @r;
INSERT @r EXEC sp_auth_register_consumer N'test_gdp_b', '$2y$10$abcdefghijklmnopqrstuv', 'gdp_b@test.cy', NULL, N'Βασίλης', N'Δοκιμή', 'Email';
DECLARE @b INT = (SELECT MAX(UserID) FROM @r);
DELETE @r;
INSERT @r EXEC sp_auth_register_consumer N'test_gdp_c', '$2y$10$abcdefghijklmnopqrstuv', 'gdp_c@test.cy', NULL, N'Γιώργος', N'Δοκιμή', 'Email';
DECLARE @c INT = (SELECT MAX(UserID) FROM @r);

-- Υποστατικό + λογαριασμός + όριο + τιμολόγιο + πληρωμή για τον A
DECLARE @pr TABLE (PremiseID INT);
INSERT @pr EXEC sp_consumer_add_premise @a, N'Οδός GDPR 1', '1010', 35.17, 33.36, 'Residential', 1, 1;
DECLARE @pa INT = (SELECT PremiseID FROM @pr);
DECLARE @ba TABLE (BankAccountID INT);
INSERT @ba EXEC sp_consumer_add_bank_account @a, 'CY47 0020 0128 0000 0012 0088 8801', N'Άννα Δοκιμή', @pa;
DECLARE @bank INT = (SELECT BankAccountID FROM @ba);
INSERT CONSUMPTION_THRESHOLD (LimitKWh, PeriodType, IsActive, UserID, PremiseID) VALUES (300, 'Month', 1, @a, @pa);
INSERT INVOICE (IssueDate, PeriodFrom, PeriodTo, Amount, Status, UserID)
VALUES ('2026-10-01', '2026-09-01', '2026-09-30', 50.00, 'Issued', @a);
DECLARE @inv INT = SCOPE_IDENTITY();
EXEC sp_consumer_pay_invoice @a, @inv, @bank, 50.00;
IF EXISTS (SELECT 1 FROM PAYMENT WHERE InvoiceID = @inv AND BankAccountID = @bank)
    PRINT 'OK   setup: payment from bank account' ELSE PRINT 'FAIL setup payment';

-- ---------- Υποβολή ----------
DECLARE @s TABLE (GdprRequestID INT);
INSERT @s EXEC sp_gdpr_submit @a;
DECLARE @ra INT = (SELECT GdprRequestID FROM @s);
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @ra AND ConsumerID = @a AND Status = 'Submitted')
    PRINT 'OK   submit -> Submitted' ELSE PRINT 'FAIL submit';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'GDPR_REQUEST' AND ObjectID = CAST(@ra AS VARCHAR) AND Action = 'Submit' AND NewState = 'Submitted' AND PerformedBy = @a)
    PRINT 'OK   submit -> AUDIT_LOG' ELSE PRINT 'FAIL submit audit';

BEGIN TRY EXEC sp_gdpr_submit @a; PRINT 'FAIL double submit accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51403 PRINT 'OK   double submit -> 51403' ELSE PRINT 'FAIL double submit: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_submit 2; PRINT 'FAIL operator submitted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51400 PRINT 'OK   operator submit -> 51400' ELSE PRINT 'FAIL operator submit: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Λίστα ----------
DECLARE @l TABLE (GdprRequestID INT, SubmittedAt DATETIME2(0), Status VARCHAR(12), PreApprovedAt DATETIME2(0), DecidedAt DATETIME2(0),
                  AppliedAt DATETIME2(0), ConsumerID INT, Username NVARCHAR(50), FirstName NVARCHAR(50), LastName NVARCHAR(50),
                  PreApprovedBy INT, PreApprovedByUsername NVARCHAR(50), DecidedBy INT, DecidedByUsername NVARCHAR(50));
INSERT @l EXEC sp_gdpr_list @a;
IF (SELECT COUNT(*) FROM @l) = 1 AND (SELECT ConsumerID FROM @l) = @a PRINT 'OK   consumer list -> only own' ELSE PRINT 'FAIL consumer list';
DELETE @l;
DECLARE @sb TABLE (GdprRequestID INT);
INSERT @sb EXEC sp_gdpr_submit @b;
DECLARE @rb INT = (SELECT GdprRequestID FROM @sb);
INSERT @l EXEC sp_gdpr_list @b;
IF (SELECT COUNT(*) FROM @l) = 1 AND (SELECT ConsumerID FROM @l) = @b PRINT 'OK   other consumer sees only own' ELSE PRINT 'FAIL consumer isolation';
DELETE @l;
INSERT @l EXEC sp_gdpr_list 2, 'Submitted';
IF EXISTS (SELECT 1 FROM @l WHERE GdprRequestID = @ra AND Username = N'test_gdp_a' AND FirstName = N'Άννα')
   AND EXISTS (SELECT 1 FROM @l WHERE GdprRequestID = @rb)
    PRINT 'OK   operator list -> all, with names' ELSE PRINT 'FAIL operator list';
DELETE @l;
INSERT @l EXEC sp_gdpr_list 1;
IF EXISTS (SELECT 1 FROM @l WHERE GdprRequestID = @ra) PRINT 'OK   admin list' ELSE PRINT 'FAIL admin list';
BEGIN TRY EXEC sp_gdpr_list 2, 'Nonsense'; PRINT 'FAIL bad status filter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51405 PRINT 'OK   bad status filter -> 51405' ELSE PRINT 'FAIL status filter: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Λάθος ρόλος / λάθος σειρά ----------
BEGIN TRY EXEC sp_gdpr_preapprove @a, @ra, 1; PRINT 'FAIL consumer preapproved'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51401 PRINT 'OK   consumer preapprove -> 51401' ELSE PRINT 'FAIL consumer preapprove: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_preapprove 1, @ra, 1; PRINT 'FAIL admin preapproved'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51401 PRINT 'OK   admin preapprove -> 51401' ELSE PRINT 'FAIL admin preapprove: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_start_review @a, @ra; PRINT 'FAIL consumer started review'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51401 PRINT 'OK   consumer start review -> 51401' ELSE PRINT 'FAIL start review role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_decide 1, @ra, 1; PRINT 'FAIL decide before preapproval'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51410 PRINT 'OK   decide before pre-approval -> 51410' ELSE PRINT 'FAIL decide early: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_apply 1, @ra; PRINT 'FAIL apply before approval'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51411 PRINT 'OK   apply before approval -> 51411' ELSE PRINT 'FAIL apply early: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_preapprove 2, 999999, 1; PRINT 'FAIL unknown request accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51406 PRINT 'OK   unknown request -> 51406' ELSE PRINT 'FAIL unknown request: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Εξέταση και προέγκριση ----------
EXEC sp_gdpr_start_review 2, @ra;
IF (SELECT Status FROM GDPR_REQUEST WHERE GdprRequestID = @ra) = 'Under review' PRINT 'OK   start review -> Under review' ELSE PRINT 'FAIL start review';
BEGIN TRY EXEC sp_gdpr_start_review 2, @ra; PRINT 'FAIL review started twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51407 PRINT 'OK   start review twice -> 51407' ELSE PRINT 'FAIL review twice: ' + ERROR_MESSAGE(); END CATCH;

EXEC sp_gdpr_preapprove 2, @ra, 1, N'Ταυτοποίηση εντάξει';
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @ra AND Status = 'Pre-approved' AND PreApprovedBy = 2 AND PreApprovedAt IS NOT NULL AND DecidedAt IS NULL)
    PRINT 'OK   preapprove -> Pre-approved (PreApprovedBy/At)' ELSE PRINT 'FAIL preapprove';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'GDPR_REQUEST' AND ObjectID = CAST(@ra AS VARCHAR) AND Action = 'Pre-approve' AND OldState = 'Under review' AND NewState = 'Pre-approved' AND PerformedBy = 2)
    PRINT 'OK   preapprove -> AUDIT_LOG old/new' ELSE PRINT 'FAIL preapprove audit';
BEGIN TRY EXEC sp_gdpr_preapprove 2, @ra, 1; PRINT 'FAIL preapproved twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51409 PRINT 'OK   preapprove twice -> 51409' ELSE PRINT 'FAIL preapprove twice: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_decide 2, @ra, 1; PRINT 'FAIL operator decided'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51402 PRINT 'OK   operator decide -> 51402' ELSE PRINT 'FAIL operator decide: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_apply 1, @ra; PRINT 'FAIL apply when only pre-approved'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51411 PRINT 'OK   apply when pre-approved -> 51411' ELSE PRINT 'FAIL apply pre-approved: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Απόφαση Admin ----------
EXEC sp_gdpr_decide 1, @ra, 1, N'Εγκρίνεται';
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @ra AND Status = 'Approved' AND DecidedByAdmin = 1 AND DecidedBy IS NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NULL)
    PRINT 'OK   decide -> Approved (DecidedByAdmin)' ELSE PRINT 'FAIL decide';
BEGIN TRY EXEC sp_gdpr_apply 2, @ra; PRINT 'FAIL operator applied'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51402 PRINT 'OK   operator apply -> 51402' ELSE PRINT 'FAIL operator apply: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_submit @a; PRINT 'FAIL submit while Approved'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51403 PRINT 'OK   submit while Approved -> 51403' ELSE PRINT 'FAIL submit approved: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Εφαρμογή ----------
DECLARE @ap TABLE (GdprRequestID INT, ConsumerID INT, AnonymisedUsername NVARCHAR(50), ChannelsDeleted INT, ThresholdsDeactivated INT,
                   PaymentsDetached INT, AccountForDeleted INT, BankAccountsDeleted INT, InvoicesKept INT, PaymentsKept INT,
                   HoldingsKept INT, RawRetentionMonths TINYINT);
INSERT @ap EXEC sp_gdpr_apply 1, @ra;
IF EXISTS (SELECT 1 FROM @ap WHERE ConsumerID = @a AND ChannelsDeleted = 2 AND ThresholdsDeactivated = 1 AND PaymentsDetached = 1
           AND AccountForDeleted = 1 AND BankAccountsDeleted = 1 AND InvoicesKept = 1 AND PaymentsKept = 1 AND HoldingsKept = 1 AND RawRetentionMonths = 1)
    PRINT 'OK   apply -> summary counts' ELSE PRINT 'FAIL apply summary';
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @a AND Username = CONCAT(N'deleted_', @a) AND FirstName = N'Διαγραμμένος'
           AND Email = CONCAT('deleted', @a, '@anon.invalid') AND Phone IS NULL AND AccountStatus = 'Suspended'
           AND RawRetentionMonths = 1 AND PasswordHash LIKE '!ERASED!%')
    PRINT 'OK   user anonymised, Suspended, RawRetentionMonths = 1' ELSE PRINT 'FAIL anonymise';
IF NOT EXISTS (SELECT 1 FROM BANK_ACCOUNT WHERE UserID = @a OR BankAccountID = @bank)
   AND NOT EXISTS (SELECT 1 FROM ACCOUNT_FOR WHERE BankAccountID = @bank)
    PRINT 'OK   bank account and ACCOUNT_FOR deleted' ELSE PRINT 'FAIL bank account';
IF NOT EXISTS (SELECT 1 FROM CONSUMER_NOTIFICATION_CHANNEL WHERE UserID = @a) PRINT 'OK   notification channels deleted' ELSE PRINT 'FAIL channels';
IF NOT EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE UserID = @a AND IsActive = 1) AND EXISTS (SELECT 1 FROM CONSUMPTION_THRESHOLD WHERE UserID = @a)
    PRINT 'OK   thresholds deactivated' ELSE PRINT 'FAIL thresholds';
IF EXISTS (SELECT 1 FROM INVOICE WHERE InvoiceID = @inv AND UserID = @a AND Amount = 50.00)
   AND EXISTS (SELECT 1 FROM PAYMENT WHERE InvoiceID = @inv AND Amount = 50.00 AND BankAccountID IS NULL)
    PRINT 'OK   invoice and payment kept (payment detached from bank)' ELSE PRINT 'FAIL invoice/payment kept';
IF EXISTS (SELECT 1 FROM HOLDING WHERE UserID = @a AND PremiseID = @pa) PRINT 'OK   holding kept' ELSE PRINT 'FAIL holding kept';
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @ra AND Status = 'Applied' AND AppliedAt IS NOT NULL)
    PRINT 'OK   request -> Applied, AppliedAt set' ELSE PRINT 'FAIL applied status';
IF (SELECT COUNT(*) FROM AUDIT_LOG WHERE ObjectType = 'GDPR_REQUEST' AND ObjectID = CAST(@ra AS VARCHAR)
      AND Action IN ('Submit', 'Start review', 'Pre-approve', 'Decide approve', 'Apply')) = 5
    PRINT 'OK   AUDIT_LOG has all 5 stages' ELSE PRINT 'FAIL audit stages';
IF NOT EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'GDPR_REQUEST' AND ObjectID = CAST(@ra AS VARCHAR)
      AND (ISNULL(NewState, '') + ISNULL(ResultComment, '') LIKE N'%test_gdp_a%' OR ISNULL(NewState, '') + ISNULL(ResultComment, '') LIKE N'%gdp_a@%'
           OR ISNULL(NewState, '') + ISNULL(ResultComment, '') LIKE N'%Άννα%' OR ISNULL(NewState, '') + ISNULL(ResultComment, '') LIKE N'%8801%'))
    PRINT 'OK   AUDIT_LOG of request holds no personal data' ELSE PRINT 'FAIL audit leaks personal data';
BEGIN TRY EXEC sp_gdpr_apply 1, @ra; PRINT 'FAIL applied twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51411 PRINT 'OK   apply twice -> 51411' ELSE PRINT 'FAIL apply twice: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_gdpr_submit @a; PRINT 'FAIL erased (suspended) user submitted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51400 PRINT 'OK   erased user cannot submit -> 51400' ELSE PRINT 'FAIL erased submit: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Απόρριψη από Operator (καταναλωτής B) ----------
EXEC sp_gdpr_preapprove 2, @rb, 0, N'Ανεπαρκή στοιχεία';
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @rb AND Status = 'Rejected' AND PreApprovedBy = 2 AND PreApprovedAt IS NOT NULL AND DecidedAt IS NULL AND AppliedAt IS NULL)
    PRINT 'OK   operator rejection -> Rejected (review stamp)' ELSE PRINT 'FAIL operator rejection';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'GDPR_REQUEST' AND ObjectID = CAST(@rb AS VARCHAR) AND Action = 'Operator reject' AND OldState = 'Submitted' AND NewState = 'Rejected')
    PRINT 'OK   operator rejection -> AUDIT_LOG' ELSE PRINT 'FAIL operator rejection audit';
BEGIN TRY EXEC sp_gdpr_decide 1, @rb, 1; PRINT 'FAIL decided a rejected request'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51410 PRINT 'OK   decide rejected request -> 51410' ELSE PRINT 'FAIL decide rejected: ' + ERROR_MESSAGE(); END CATCH;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @b AND Username = N'test_gdp_b' AND RawRetentionMonths = 36)
    PRINT 'OK   rejected consumer untouched' ELSE PRINT 'FAIL rejected consumer changed';
-- μετά από απόρριψη μπορεί να υποβάλει νέο αίτημα
DECLARE @sb2 TABLE (GdprRequestID INT);
INSERT @sb2 EXEC sp_gdpr_submit @b;
IF (SELECT GdprRequestID FROM @sb2) > @rb PRINT 'OK   resubmit after rejection' ELSE PRINT 'FAIL resubmit';

-- ---------- Απόρριψη από Admin (καταναλωτής C) ----------
DECLARE @sc TABLE (GdprRequestID INT);
INSERT @sc EXEC sp_gdpr_submit @c;
DECLARE @rc INT = (SELECT GdprRequestID FROM @sc);
EXEC sp_gdpr_preapprove 2, @rc, 1;
EXEC sp_gdpr_decide 1, @rc, 0, N'Απορρίπτεται';
IF EXISTS (SELECT 1 FROM GDPR_REQUEST WHERE GdprRequestID = @rc AND Status = 'Rejected' AND DecidedByAdmin = 1 AND DecidedBy IS NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NULL)
    PRINT 'OK   admin rejection -> Rejected (DecidedByAdmin)' ELSE PRINT 'FAIL admin rejection';
BEGIN TRY EXEC sp_gdpr_apply 1, @rc; PRINT 'FAIL applied a rejected request'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51411 PRINT 'OK   apply rejected request -> 51411' ELSE PRINT 'FAIL apply rejected: ' + ERROR_MESSAGE(); END CATCH;
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @c AND Username = N'test_gdp_c' AND AccountStatus = 'Active' AND RawRetentionMonths = 36)
    PRINT 'OK   admin-rejected consumer untouched' ELSE PRINT 'FAIL admin-rejected consumer changed';

-- ---------- Το demo δεν πειράχτηκε ----------
IF EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = 3 AND Username = N'consumer1' AND AccountStatus = 'Active')
   AND EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = 4 AND Username = N'consumer2' AND AccountStatus = 'Active')
    PRINT 'OK   base consumers untouched' ELSE PRINT 'FAIL base consumers changed';
GO

-- =====================================================================
-- GDP-2: διατήρηση δεδομένων (sp_retention_preview, sp_retention_purge, fn_retention_cutoff)
-- Ο καταναλωτής A (GDPR εφαρμόστηκε παραπάνω, RawRetentionMonths = 1) παίρνει δικό του υποστατικό με μετρητή.
-- Τρεις δοκιμαστικοί μετρητές (ο καθένας με 5 ωμές + 5 επικυρωμένες μετρήσεις, 1.8.0):
--   MA: υποστατικό του A από 2025-06-01 (1 μήνας)      MB: υποστατικό του B (36 μήνες)
--   MN: υποστατικό ΧΩΡΙΣ κάτοχο (εφεδρικά 36 μήνες)
-- Χρόνοι: t0 = 2023-06-01 (πριν την εγκατάσταση -> εφεδρικά 36), t1 = 2026-10-01, t2 = 2026-11-24 23:45,
--         t3 = 2026-11-25 00:00, t4 = 2026-12-01.   Με @AsOf = 2026-12-25 (όριο 1 μήνα = 2026-11-25, 36 μηνών = 2023-12-25):
--   MA: σβήνονται t0, t1, t2 (3)   MB: μόνο t0 (1)   MN: μόνο t0 (1).
-- Τα βασικά demo (μετρητές 1-4, 18-20/11/2026, 36 μήνες) δεν πρέπει να χαθούν ποτέ.
-- =====================================================================
SET NOCOUNT ON;

DECLARE @a INT = (SELECT MAX(u.UserID) FROM USER_ACCOUNT u JOIN HOLDING h ON h.UserID = u.UserID
                  JOIN PREMISE p ON p.PremiseID = h.PremiseID
                  WHERE p.Address = N'Οδός GDPR 1' AND u.RawRetentionMonths = 1);
DECLARE @b INT = (SELECT UserID FROM USER_ACCOUNT WHERE Username = N'test_gdp_b');
IF @a IS NULL OR @b IS NULL
BEGIN
    PRINT 'FAIL retention setup: GDP-1 test users not found (run the GDP-1 part first)';
    RETURN;
END
IF EXISTS (SELECT 1 FROM METER WHERE SerialNumber = 'SN-GDP2-1')
BEGIN
    PRINT 'FAIL retention setup: fixture already exists (needs a fresh database)';
    RETURN;
END

-- ---------- Υποδομή: 3 υποστατικά, 3 μετρητές, εγκαταστάσεις, αναγνώσεις ----------
DECLARE @m TABLE (Tag INT PRIMARY KEY, MeterID INT, PremiseID INT);
DECLARE @i INT = 1, @pid INT, @mid INT, @tid INT, @pk BIGINT;
WHILE @i <= 3
BEGIN
    INSERT PREMISE (Address, PostalCode, Latitude, Longitude, UsageType, ParishID, SchemeID)
    VALUES (CONCAT(N'Οδός Διατήρησης ', @i), '1010', 35.17, 33.36, 'Residential', 1, 1);
    SET @pid = SCOPE_IDENTITY();
    IF @i = 1 INSERT HOLDING (UserID, PremiseID, StartDate, EndDate) VALUES (@a, @pid, '2025-06-01', NULL);
    IF @i = 2 INSERT HOLDING (UserID, PremiseID, StartDate, EndDate) VALUES (@b, @pid, '2025-06-01', NULL);
    INSERT METER (SerialNumber, NetworkID, Firmware, MaxLoadAmps, Latitude, Longitude, Status, ModelID, CommTypeID, TransformerID)
    VALUES (CONCAT('SN-GDP2-', @i), CONCAT('EAC-GDP2-', @i), '1.0', 60, 35.145, 33.39, 'Active', 1, 1, 4);
    SET @mid = SCOPE_IDENTITY();
    INSERT FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, Status, Result, CreatedAt, CompletedAt, TechnicianID, PremiseID)
    VALUES ('Installation', '2025-06-01 09:00:00', '2025-06-01 11:00:00', 'Done', N'Εγκαταστάθηκε (GDP-2 test)', '2025-05-30 09:00:00', '2025-06-01 10:00:00', 5, @pid);
    SET @tid = SCOPE_IDENTITY();
    INSERT METER_INSTALLATION (InstalledAt, ConfirmationStatus, ConfirmedAt, ConfirmComment, MeterID, PremiseID, ConfirmedBy, TaskID)
    VALUES ('2025-06-01 10:00:00', 'Confirmed', '2025-06-02 09:00:00', N'GDP-2 test', @mid, @pid, 2, @tid);
    INSERT TELEMETRY_PACKET (ReceivedNetworkID, TransmissionTimestamp, ReceivedAt, NetworkType, RawPayload, IngestStatus, MeterID)
    VALUES (CONCAT('EAC-GDP2-', @i), '2026-10-01 00:00:00', '2026-10-01 00:00:10', 'NB-IoT', N'{}', 'Accepted', @mid);
    SET @pk = SCOPE_IDENTITY();
    INSERT @m VALUES (@i, @mid, @pid);
    INSERT RAW_READING (MeterID, ObisCode, IntervalStart, ReceivedValue, VeeStatus, PacketID)
    SELECT @mid, '1.8.0', t.T, 100.0, 'Validated', @pk
    FROM (VALUES (CAST('2023-06-01 00:00:00' AS DATETIME2(0))), ('2026-10-01 00:00:00'), ('2026-11-24 23:45:00'),
                 ('2026-11-25 00:00:00'), ('2026-12-01 00:00:00')) t (T);
    INSERT VALIDATED_READING (MeterID, ObisCode, IntervalStart, Value, Quality, RunID)
    SELECT @mid, '1.8.0', t.T, 0.1, 'Validated', 1
    FROM (VALUES (CAST('2023-06-01 00:00:00' AS DATETIME2(0))), ('2026-10-01 00:00:00'), ('2026-11-24 23:45:00'),
                 ('2026-11-25 00:00:00'), ('2026-12-01 00:00:00')) t (T);
    SET @i += 1;
END
DECLARE @ma INT = (SELECT MeterID FROM @m WHERE Tag = 1), @mb INT = (SELECT MeterID FROM @m WHERE Tag = 2), @mn INT = (SELECT MeterID FROM @m WHERE Tag = 3);
-- διορθώσεις: MA t1 (σβήνεται), MA t3 (μένει), MB t0 (σβήνεται), MB t1 (μένει)
INSERT READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, Reason, EditedBy)
VALUES (@ma, '1.8.0', '2026-10-01 00:00:00', 1, 0.1, 0.2, 'Manual edit', N'test', 1),
       (@ma, '1.8.0', '2026-11-25 00:00:00', 1, 0.1, 0.2, 'Manual edit', N'test', 1),
       (@mb, '1.8.0', '2023-06-01 00:00:00', 1, 0.1, 0.2, 'Manual edit', N'test', 1),
       (@mb, '1.8.0', '2026-10-01 00:00:00', 1, 0.1, 0.2, 'Manual edit', N'test', 1);
-- aggregate που δεν πρέπει να χαθεί
INSERT METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount)
VALUES (@ma, '1.8.0', 'Month', '2026-10-01', 9.5, 5, 0);

DECLARE @baseRaw INT = (SELECT COUNT(*) FROM RAW_READING WHERE MeterID BETWEEN 1 AND 4);
DECLARE @baseVal INT = (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID BETWEEN 1 AND 4);
DECLARE @aggBefore INT = (SELECT COUNT(*) FROM METER_AGGREGATE);
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15 AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15
   AND @baseRaw > 0 AND @baseVal > 0
    PRINT 'OK   GDP-2 setup: 3 meters x 5 raw + 5 validated, base demo readings present' ELSE PRINT 'FAIL GDP-2 setup';

-- ---------- fn_retention_cutoff ----------
IF (SELECT RetentionMonths FROM fn_retention_cutoff('2026-12-25') WHERE MeterID = @ma) = 1
   AND (SELECT RetentionMonths FROM fn_retention_cutoff('2026-12-25') WHERE MeterID = @mb) = 36
   AND NOT EXISTS (SELECT 1 FROM fn_retention_cutoff('2026-12-25') WHERE MeterID = @mn)
   AND (SELECT Cutoff FROM fn_retention_cutoff('2026-12-25') WHERE MeterID = @ma) = '2026-11-25'
    PRINT 'OK   fn_retention_cutoff: A = 1 month, B = 36, no holder -> no segment' ELSE PRINT 'FAIL fn_retention_cutoff';

-- ---------- Preview ----------
DECLARE @pv TABLE (MeterID INT, SerialNumber VARCHAR(40), RetentionMonths INT, Cutoff DATETIME2(0),
                   RawToDelete INT, ValidatedToDelete INT, EditsToDelete INT, AsOf DATETIME2(0));
INSERT @pv EXEC sp_retention_preview 1, '2026-12-25';
IF EXISTS (SELECT 1 FROM @pv WHERE MeterID = @ma AND RetentionMonths = 1 AND RawToDelete = 2 AND ValidatedToDelete = 2 AND EditsToDelete = 1)
   AND EXISTS (SELECT 1 FROM @pv WHERE MeterID = @ma AND RetentionMonths = 36 AND RawToDelete = 1 AND ValidatedToDelete = 1 AND EditsToDelete = 0)
   AND EXISTS (SELECT 1 FROM @pv WHERE MeterID = @mb AND RetentionMonths = 36 AND RawToDelete = 1 AND ValidatedToDelete = 1 AND EditsToDelete = 1)
   AND NOT EXISTS (SELECT 1 FROM @pv WHERE MeterID = @mb AND RetentionMonths = 1)
   AND EXISTS (SELECT 1 FROM @pv WHERE MeterID = @mn AND RetentionMonths = 36 AND RawToDelete = 1 AND ValidatedToDelete = 1 AND EditsToDelete = 0)
    PRINT 'OK   preview @AsOf 2026-12-25: A 2+1 (1 month / fallback), B 1 (36 months), no-holder meter 1' ELSE PRINT 'FAIL preview counts';
IF NOT EXISTS (SELECT 1 FROM @pv WHERE MeterID BETWEEN 1 AND 4 AND (RawToDelete > 0 OR ValidatedToDelete > 0))
   AND EXISTS (SELECT 1 FROM @pv WHERE MeterID = 1 AND RetentionMonths = 36)
    PRINT 'OK   preview: base demo meters 1-4 have nothing to delete' ELSE PRINT 'FAIL preview base meters';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15 PRINT 'OK   preview deletes nothing' ELSE PRINT 'FAIL preview deleted rows';
DECLARE @pn TABLE (MeterID INT, SerialNumber VARCHAR(40), RetentionMonths INT, Cutoff DATETIME2(0),
                   RawToDelete INT, ValidatedToDelete INT, EditsToDelete INT, AsOf DATETIME2(0));
INSERT @pn EXEC sp_retention_preview 1;
IF EXISTS (SELECT 1 FROM @pn) AND (SELECT MIN(AsOf) FROM @pn) BETWEEN DATEADD(MINUTE, -5, SYSUTCDATETIME()) AND DATEADD(MINUTE, 1, SYSUTCDATETIME())
    PRINT 'OK   preview @AsOf NULL -> now (UTC)' ELSE PRINT 'FAIL preview default AsOf';

-- ---------- Λάθος ρόλος / λάθος ημερομηνία ----------
BEGIN TRY EXEC sp_retention_purge 2, '2026-12-25'; PRINT 'FAIL operator purged'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51402 PRINT 'OK   operator purge -> 51402' ELSE PRINT 'FAIL operator purge: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_retention_purge 3, '2026-12-25'; PRINT 'FAIL consumer purged'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51402 PRINT 'OK   consumer purge -> 51402' ELSE PRINT 'FAIL consumer purge: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_retention_preview 2, '2026-12-25'; PRINT 'FAIL operator previewed'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51402 PRINT 'OK   operator preview -> 51402' ELSE PRINT 'FAIL operator preview: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_retention_purge 1, '2099-01-01'; PRINT 'FAIL far-future AsOf accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51450 PRINT 'OK   AsOf far in the future -> 51450' ELSE PRINT 'FAIL future AsOf: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_retention_preview 1, '2099-01-01'; PRINT 'FAIL far-future preview accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51450 PRINT 'OK   preview AsOf far in the future -> 51450' ELSE PRINT 'FAIL future preview: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15 PRINT 'OK   refused calls deleted nothing' ELSE PRINT 'FAIL refused calls deleted rows';

-- ---------- Trigger: χωρίς flag η διαγραφή αποτυγχάνει ----------
BEGIN TRY DELETE VALIDATED_READING WHERE MeterID = @ma AND IntervalStart = '2026-12-01'; PRINT 'FAIL validated delete without flag'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 50006 PRINT 'OK   DELETE VALIDATED_READING without flag -> 50006' ELSE PRINT 'FAIL trigger: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Εκκαθάριση χωρίς τίποτα να λήγει: @AsOf = 2026-05-01 ----------
DECLARE @p0 TABLE (RawDeleted INT, ValidatedDeleted INT, EditsDeleted INT, AsOf DATETIME2(0));
INSERT @p0 EXEC sp_retention_purge 1, '2026-05-01';
IF EXISTS (SELECT 1 FROM @p0 WHERE RawDeleted = 0 AND ValidatedDeleted = 0 AND EditsDeleted = 0 AND AsOf = '2026-05-01')
   AND (SELECT COUNT(*) FROM RAW_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15
   AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID IN (@ma, @mb, @mn)) = 15
    PRINT 'OK   purge @AsOf 2026-05-01 -> 0 deleted, rows unchanged' ELSE PRINT 'FAIL purge with nothing to delete';
IF (SELECT CAST(SESSION_CONTEXT(N'mdms_purge') AS INT)) = 0 PRINT 'OK   session flag back to 0 after purge' ELSE PRINT 'FAIL session flag not reset';

-- ---------- Εκκαθάριση @AsOf = 2026-12-25 ----------
DECLARE @p1 TABLE (RawDeleted INT, ValidatedDeleted INT, EditsDeleted INT, AsOf DATETIME2(0));
INSERT @p1 EXEC sp_retention_purge 1, '2026-12-25';
IF EXISTS (SELECT 1 FROM @p1 WHERE RawDeleted = (SELECT SUM(RawToDelete) FROM @pv) AND ValidatedDeleted = (SELECT SUM(ValidatedToDelete) FROM @pv)
           AND EditsDeleted = (SELECT SUM(EditsToDelete) FROM @pv) AND RawDeleted >= 5 AND AsOf = '2026-12-25')
    PRINT 'OK   purge result = preview totals (>= 5 raw, 5 validated, 2 edits)' ELSE PRINT 'FAIL purge result vs preview';
IF (SELECT CAST(SESSION_CONTEXT(N'mdms_purge') AS INT)) = 0 PRINT 'OK   session flag back to 0 after purge (2)' ELSE PRINT 'FAIL session flag not reset (2)';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID = @ma) = 2 AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = @ma) = 2
   AND NOT EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = @ma AND IntervalStart < '2026-11-25')
   AND NOT EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = @ma AND IntervalStart < '2026-11-25')
    PRINT 'OK   consumer with RawRetentionMonths = 1: only rows from 2026-11-25 on remain (cutoff itself kept)' ELSE PRINT 'FAIL A purge';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID = @mb) = 4 AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = @mb) = 4
   AND NOT EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = @mb AND IntervalStart = '2023-06-01')
   AND EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = @mb AND IntervalStart = '2026-10-01')
    PRINT 'OK   36-month consumer keeps 2026-10-01 rows (only the pre-installation 2023 row went)' ELSE PRINT 'FAIL B purge';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID = @mn) = 4 AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = @mn) = 4
    PRINT 'OK   premise without holder: 36-month fallback' ELSE PRINT 'FAIL fallback purge';
IF (SELECT COUNT(*) FROM READING_EDIT WHERE MeterID = @ma) = 1 AND EXISTS (SELECT 1 FROM READING_EDIT WHERE MeterID = @ma AND IntervalStart = '2026-11-25')
   AND (SELECT COUNT(*) FROM READING_EDIT WHERE MeterID = @mb) = 1 AND EXISTS (SELECT 1 FROM READING_EDIT WHERE MeterID = @mb AND IntervalStart = '2026-10-01')
    PRINT 'OK   READING_EDIT rows of purged readings deleted, others kept' ELSE PRINT 'FAIL READING_EDIT purge';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID BETWEEN 1 AND 4) = @baseRaw AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID BETWEEN 1 AND 4) = @baseVal
    PRINT 'OK   base demo readings (meters 1-4) untouched' ELSE PRINT 'FAIL base demo readings deleted';
IF (SELECT COUNT(*) FROM METER_AGGREGATE) = @aggBefore AND EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE MeterID = @ma AND PeriodType = 'Month' AND PeriodStart = '2026-10-01' AND SumValue = 9.5)
    PRINT 'OK   METER_AGGREGATE untouched' ELSE PRINT 'FAIL METER_AGGREGATE changed';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'RETENTION' AND ObjectID = '2026-12-25 00:00:00' AND Action = 'Retention purge' AND PerformedBy = 1
           AND ResultComment LIKE N'%ωμές%')
    PRINT 'OK   purge -> AUDIT_LOG with counts' ELSE PRINT 'FAIL purge audit';

-- ---------- Δεύτερη εκτέλεση: δεν υπάρχει τίποτα άλλο ----------
DECLARE @p2 TABLE (RawDeleted INT, ValidatedDeleted INT, EditsDeleted INT, AsOf DATETIME2(0));
INSERT @p2 EXEC sp_retention_purge 1, '2026-12-25';
IF EXISTS (SELECT 1 FROM @p2 WHERE RawDeleted = 0 AND ValidatedDeleted = 0 AND EditsDeleted = 0) PRINT 'OK   second purge -> 0 deleted (idempotent)' ELSE PRINT 'FAIL second purge';

-- ---------- Trigger ακόμα ενεργό ----------
BEGIN TRY DELETE VALIDATED_READING WHERE MeterID = @ma AND IntervalStart = '2026-12-01'; PRINT 'FAIL validated delete after purge'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 50006 PRINT 'OK   DELETE VALIDATED_READING after purge still refused -> 50006' ELSE PRINT 'FAIL trigger after purge: ' + ERROR_MESSAGE(); END CATCH;
GO
