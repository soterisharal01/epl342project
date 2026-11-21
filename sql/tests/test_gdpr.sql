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
