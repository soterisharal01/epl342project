-- =====================================================================
-- test_consumer.sql : έλεγχοι για το procs_consumer.sql (CON-1, CON-4, CON-5).
-- Πάνω στα κοινά δεδομένα: consumer1 = UserID 3 (υποστατικά 1, 2, λογαριασμός 1,
-- τιμολόγια 1 Paid και 2 Issued 47.90), consumer2 = UserID 4, operator = UserID 2.
-- Κάθε γραμμή τυπώνει OK ή FAIL. Τρέχει σε δοκιμαστική βάση (sql/tools/test_local.sh).
-- =====================================================================
SET NOCOUNT ON;
DECLARE @n INT, @x INT;

-- ---------- Έλεγχος ρόλου ----------
BEGIN TRY EXEC sp_consumer_list_premises 2; PRINT 'FAIL operator saw consumer premises'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51000 PRINT 'OK   non-consumer -> 51000' ELSE PRINT 'FAIL role: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- CON-1 υποστατικά ----------
DECLARE @pr TABLE (PremiseID INT);
INSERT @pr EXEC sp_consumer_add_premise 3, N'Οδός Δοκιμής 1', '1010', 35.17, 33.36, 'Residential', 1, 1;
DECLARE @newp INT = (SELECT PremiseID FROM @pr);
IF EXISTS (SELECT 1 FROM HOLDING WHERE UserID = 3 AND PremiseID = @newp AND EndDate IS NULL)
    PRINT 'OK   add premise -> PREMISE + HOLDING' ELSE PRINT 'FAIL add premise';

BEGIN TRY EXEC sp_consumer_add_premise 3, N'Λάθος', '10A0', 35.17, 33.36, 'Residential', 1, 1; PRINT 'FAIL bad postal code accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51001 PRINT 'OK   bad postal code -> 51001' ELSE PRINT 'FAIL postal: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_add_premise 3, N'Αθήνα', '1010', 37.98, 23.72, 'Residential', 1, 1; PRINT 'FAIL coords outside Cyprus accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51005 PRINT 'OK   coords outside Cyprus -> 51005' ELSE PRINT 'FAIL coords: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @lp TABLE (PremiseID INT, Address NVARCHAR(200), PostalCode CHAR(4), Usage NVARCHAR(20), District NVARCHAR(50),
                   Municipality NVARCHAR(100), Parish NVARCHAR(100), Scheme NVARCHAR(50), Latitude DECIMAL(9,6),
                   Longitude DECIMAL(9,6), StartDate DATE, EndDate DATE, Meter VARCHAR(40));
INSERT @lp EXEC sp_consumer_list_premises 3;
IF (SELECT COUNT(*) FROM @lp) = 3 AND NOT EXISTS (SELECT 1 FROM @lp WHERE PremiseID IN (3, 4))
    PRINT 'OK   list premises -> only own (3)' ELSE PRINT 'FAIL list premises';
IF (SELECT Meter FROM @lp WHERE PremiseID = 1) IS NOT NULL PRINT 'OK   list premises shows meter' ELSE PRINT 'FAIL premise meter';

EXEC sp_consumer_end_holding 3, @newp;
IF EXISTS (SELECT 1 FROM HOLDING WHERE UserID = 3 AND PremiseID = @newp AND EndDate IS NOT NULL)
    PRINT 'OK   end holding' ELSE PRINT 'FAIL end holding';
BEGIN TRY EXEC sp_consumer_end_holding 3, 3; PRINT 'FAIL ended someone else''s holding'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51006 PRINT 'OK   foreign premise -> 51006' ELSE PRINT 'FAIL foreign: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- CON-1 λογαριασμοί ----------
DECLARE @ba TABLE (BankAccountID INT);
INSERT @ba EXEC sp_consumer_add_bank_account 3, 'cy47 0020 0128 0000 0012 0099 9999', N'Μαρία Γεωργίου', 1;
DECLARE @newb INT = (SELECT BankAccountID FROM @ba);
IF EXISTS (SELECT 1 FROM BANK_ACCOUNT b JOIN ACCOUNT_FOR af ON af.BankAccountID = b.BankAccountID
           WHERE b.BankAccountID = @newb AND b.IBAN = 'CY47002001280000001200999999' AND af.PremiseID = 1)
    PRINT 'OK   add bank account (IBAN normalised) + ACCOUNT_FOR' ELSE PRINT 'FAIL add bank account';
BEGIN TRY EXEC sp_consumer_add_bank_account 3, 'CY47002001280000001200999999', N'X'; PRINT 'FAIL duplicate IBAN accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51011 PRINT 'OK   duplicate IBAN -> 51011' ELSE PRINT 'FAIL dup IBAN: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_add_bank_account 3, 'XX12', N'X'; PRINT 'FAIL bad IBAN accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51010 PRINT 'OK   bad IBAN -> 51010' ELSE PRINT 'FAIL bad IBAN: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- CON-4 αιτήματα ----------
DECLARE @rq TABLE (RequestID INT);
INSERT @rq EXEC sp_consumer_submit_request 3, 1, 1, 'Meter check', N'Ο μετρητής δείχνει πολύ μεγάλη κατανάλωση.';
DECLARE @rid INT = (SELECT RequestID FROM @rq);
IF EXISTS (SELECT 1 FROM SERVICE_REQUEST WHERE RequestID = @rid AND Status = 'Submitted' AND UserID = 3)
    PRINT 'OK   submit request' ELSE PRINT 'FAIL submit request';
BEGIN TRY EXEC sp_consumer_submit_request 3, 1, 3, 'Meter check', N'Ξένος μετρητής εδώ'; PRINT 'FAIL meter of other premise accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51021 PRINT 'OK   meter not on premise -> 51021' ELSE PRINT 'FAIL meter/premise: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_submit_request 3, 3, NULL, 'Fault report', N'Όχι δικό μου υποστατικό'; PRINT 'FAIL request on foreign premise'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51006 PRINT 'OK   request on foreign premise -> 51006' ELSE PRINT 'FAIL foreign req: ' + ERROR_MESSAGE(); END CATCH;

EXEC sp_consumer_cancel_request 3, @rid;
IF (SELECT Status FROM SERVICE_REQUEST WHERE RequestID = @rid) = 'Cancelled' PRINT 'OK   cancel request' ELSE PRINT 'FAIL cancel';
BEGIN TRY EXEC sp_consumer_cancel_request 4, 1; PRINT 'FAIL cancelled other user''s request'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51023 PRINT 'OK   cancel foreign -> 51023' ELSE PRINT 'FAIL cancel foreign: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @lr TABLE (RequestID INT, SubmittedAt DATETIME2(0), RequestType NVARCHAR(30), Address NVARCHAR(200), Meter VARCHAR(40),
                   Description NVARCHAR(1000), Status NVARCHAR(20), VisitFrom DATETIME2(0), VisitTo DATETIME2(0), Result NVARCHAR(1000));
INSERT @lr EXEC sp_consumer_list_requests 3;
IF (SELECT COUNT(*) FROM @lr) = 2 PRINT 'OK   list requests -> 2 own' ELSE PRINT 'FAIL list requests';

-- ---------- CON-5 τιμολόγια / πληρωμές ----------
DECLARE @li TABLE (InvoiceID INT, IssueDate DATE, PeriodFrom DATE, PeriodTo DATE, Amount DECIMAL(12,2), Paid DECIMAL(12,2),
                   Remaining DECIMAL(12,2), Status NVARCHAR(30), Supplier NVARCHAR(100), Address NVARCHAR(200));
INSERT @li EXEC sp_consumer_list_invoices 3;
IF (SELECT COUNT(*) FROM @li) = 2 AND (SELECT Remaining FROM @li WHERE InvoiceID = 2) = 47.90
    PRINT 'OK   list invoices -> own 2, remaining 47.90' ELSE PRINT 'FAIL list invoices';

EXEC sp_consumer_pay_invoice 3, 2, 1, 20.00;
IF (SELECT Status FROM INVOICE WHERE InvoiceID = 2) = 'Partially paid' PRINT 'OK   partial payment' ELSE PRINT 'FAIL partial';
BEGIN TRY EXEC sp_consumer_pay_invoice 3, 2, 1, 100.00; PRINT 'FAIL overpayment accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51034 PRINT 'OK   overpayment -> 51034' ELSE PRINT 'FAIL overpay: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_consumer_pay_invoice 3, 2, 1, 27.90;
IF (SELECT Status FROM INVOICE WHERE InvoiceID = 2) = 'Paid' PRINT 'OK   full payment -> Paid' ELSE PRINT 'FAIL full';
BEGIN TRY EXEC sp_consumer_pay_invoice 3, 2, 1, 1.00; PRINT 'FAIL paid twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51033 PRINT 'OK   already paid -> 51033' ELSE PRINT 'FAIL paid twice: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_pay_invoice 3, 3, 1, 1.00; PRINT 'FAIL paid foreign invoice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51030 PRINT 'OK   foreign invoice -> 51030' ELSE PRINT 'FAIL foreign inv: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_pay_invoice 4, 3, 1, 1.00; PRINT 'FAIL paid from foreign account'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51031 PRINT 'OK   foreign account -> 51031' ELSE PRINT 'FAIL foreign acc: ' + ERROR_MESSAGE(); END CATCH;

IF (SELECT COUNT(*) FROM AUDIT_LOG WHERE ObjectType = 'INVOICE' AND ObjectID = '2' AND Action = 'Payment') = 2
    PRINT 'OK   payments in AUDIT_LOG' ELSE PRINT 'FAIL payment audit';

DECLARE @lpay TABLE (PaymentID INT, PaidAt DATETIME2(0), Amount DECIMAL(12,2), InvoiceID INT, IBAN VARCHAR(20), Reference NVARCHAR(50));
INSERT @lpay EXEC sp_consumer_list_payments 3;
IF (SELECT COUNT(*) FROM @lpay) = 3 AND NOT EXISTS (SELECT 1 FROM @lpay WHERE IBAN NOT LIKE '%****%')
    PRINT 'OK   list payments -> 3, IBAN masked' ELSE PRINT 'FAIL list payments';

PRINT 'test_consumer.sql: τέλος';
