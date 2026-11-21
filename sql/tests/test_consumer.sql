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

-- =====================================================================
-- CON-2 μετρήσεις / ιστορικό / αγορά ιστορικού
-- =====================================================================
DECLARE @cur DATE = DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1);
DECLARE @prev DATE = DATEADD(MONTH, -1, @cur);
DECLARE @fee DECIMAL(10,2) = (SELECT Fee FROM SERVICE_TYPE WHERE ServiceTypeID = 1);

-- ---------- ρόλος ----------
BEGIN TRY EXEC sp_consumer_readings 2, 1, '2026-11-18', '2026-11-19'; PRINT 'FAIL operator read meter'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51000 PRINT 'OK   readings: operator -> 51000' ELSE PRINT 'FAIL readings role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_buy_history 2, 1, @prev, @prev; PRINT 'FAIL operator bought history'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51000 PRINT 'OK   buy_history: operator -> 51000' ELSE PRINT 'FAIL buy role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_history 2, 1, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL operator read history'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51000 PRINT 'OK   history: operator -> 51000' ELSE PRINT 'FAIL history role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_list_purchases 2; PRINT 'FAIL operator listed purchases'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51000 PRINT 'OK   list_purchases: operator -> 51000' ELSE PRINT 'FAIL list_purchases role: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- fn_consumer_meters ----------
IF (SELECT COUNT(*) FROM fn_consumer_meters(3)) = 2 AND NOT EXISTS (SELECT 1 FROM fn_consumer_meters(3) WHERE MeterID NOT IN (1, 2))
   AND EXISTS (SELECT 1 FROM fn_consumer_meters(3) WHERE MeterID = 1 AND PremiseID = 1)
    PRINT 'OK   fn_consumer_meters: consumer1 sees only meters 1 and 2' ELSE PRINT 'FAIL fn_consumer_meters';

-- ---------- ανάγνωση 15λέπτου, τρέχων μήνας (δωρεάν) ----------
DECLARE @rd TABLE (IntervalStart DATETIME2(0), ImportKWh DECIMAL(15,4), ExportKWh DECIMAL(15,4), VoltageL1 DECIMAL(15,4), Quality VARCHAR(9));
IF @cur = '2026-11-01'
BEGIN
    INSERT @rd EXEC sp_consumer_readings 3, 1, '2026-11-18', '2026-11-19';
    DECLARE @expected INT = (SELECT COUNT(DISTINCT IntervalStart) FROM VALIDATED_READING
                             WHERE MeterID = 1 AND ObisCode IN ('1.8.0', '2.8.0', '32.7.0')
                               AND IntervalStart >= '2026-11-18' AND IntervalStart < '2026-11-19');
    IF @expected > 0 AND (SELECT COUNT(*) FROM @rd) = @expected
        PRINT 'OK   readings: current month free, ' + CAST(@expected AS VARCHAR(10)) + ' rows' ELSE PRINT 'FAIL readings count';
    IF (SELECT SUM(ImportKWh) FROM @rd) = (SELECT SUM(Value) FROM VALIDATED_READING
                                           WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart >= '2026-11-18' AND IntervalStart < '2026-11-19')
        PRINT 'OK   readings: import values equal VALIDATED_READING' ELSE PRINT 'FAIL readings import values';
END
ELSE
BEGIN
    PRINT 'OK   readings: (skipped, base data is not in the current month)';
    PRINT 'OK   readings: (skipped, base data is not in the current month)';
END;

-- prosumer (consumer2, meter 3 = premise 3): import and export side by side
IF @cur = '2026-11-01'
BEGIN
    DECLARE @rd2 TABLE (IntervalStart DATETIME2(0), ImportKWh DECIMAL(15,4), ExportKWh DECIMAL(15,4), VoltageL1 DECIMAL(15,4), Quality VARCHAR(9));
    INSERT @rd2 EXEC sp_consumer_readings 4, 3, '2026-11-18', '2026-11-19';
    IF (SELECT SUM(ExportKWh) FROM @rd2) = (SELECT SUM(Value) FROM VALIDATED_READING
                                            WHERE MeterID = 3 AND ObisCode = '2.8.0' AND IntervalStart >= '2026-11-18' AND IntervalStart < '2026-11-19')
       AND (SELECT SUM(ExportKWh) FROM @rd2) > 0
        PRINT 'OK   readings: prosumer export (2.8.0) shown separately' ELSE PRINT 'FAIL prosumer export';
END
ELSE PRINT 'OK   readings: (skipped, base data is not in the current month)';

-- ---------- άρνηση ----------
BEGIN TRY EXEC sp_consumer_readings 3, 3, '2026-11-18', '2026-11-19'; PRINT 'FAIL consumer1 read consumer2 meter'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51100 PRINT 'OK   readings: foreign meter -> 51100' ELSE PRINT 'FAIL foreign meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_readings 3, 1, '2026-11-19', '2026-11-18'; PRINT 'FAIL reversed range accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51102 PRINT 'OK   readings: reversed range -> 51102' ELSE PRINT 'FAIL reversed range: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_readings 3, 1, '2026-11-01', '2026-12-15'; PRINT 'FAIL range > 31 days accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51104 PRINT 'OK   readings: range > 31 days -> 51104' ELSE PRINT 'FAIL long range: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_readings 3, 1, '2026-09-01', '2026-09-02'; PRINT 'FAIL read before installation'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51103 PRINT 'OK   readings: before installation -> 51103' ELSE PRINT 'FAIL before install: ' + ERROR_MESSAGE(); END CATCH;
-- προηγούμενος μήνας (εντός εγκατάστασης: 2026-10-05) χωρίς αγορά: 51105 (ή 51106 αν έχει περάσει η διατήρηση)
BEGIN TRY EXEC sp_consumer_readings 3, 1, '2026-10-05', '2026-10-06'; PRINT 'FAIL earlier month without purchase accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() IN (51105, 51106) PRINT 'OK   readings: earlier month without purchase -> ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) ELSE PRINT 'FAIL no purchase: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- αγορά ιστορικού ----------
BEGIN TRY EXEC sp_consumer_buy_history 3, 3, @prev, @prev; PRINT 'FAIL bought history for foreign premise'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51101 PRINT 'OK   buy_history: foreign premise -> 51101' ELSE PRINT 'FAIL buy foreign: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_buy_history 3, 1, @cur, @cur; PRINT 'FAIL bought the free current month'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51108 PRINT 'OK   buy_history: current month -> 51108' ELSE PRINT 'FAIL buy current: ' + ERROR_MESSAGE(); END CATCH;
-- EXEC arguments must be variables or literals, not expressions: precompute the dates.
DECLARE @fut DATE = DATEADD(MONTH, 3, @cur), @before DATE = DATEADD(MONTH, -2, @prev), @old37 DATE = DATEADD(MONTH, -37, @cur);
BEGIN TRY EXEC sp_consumer_buy_history 3, 1, @prev, @fut; PRINT 'FAIL bought future month'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51108 PRINT 'OK   buy_history: future month -> 51108' ELSE PRINT 'FAIL buy future: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_buy_history 3, 1, @prev, @before; PRINT 'FAIL MonthFrom > MonthTo accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51109 PRINT 'OK   buy_history: MonthFrom > MonthTo -> 51109' ELSE PRINT 'FAIL buy order: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_buy_history 3, 1, @old37, @old37; PRINT 'FAIL bought month beyond retention'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51111 PRINT 'OK   buy_history: beyond retention -> 51111' ELSE PRINT 'FAIL buy retention: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @bh TABLE (PurchaseID INT, InvoiceID INT, Amount DECIMAL(10,2));
INSERT @bh EXEC sp_consumer_buy_history 3, 1, @prev, @prev;
DECLARE @pur INT = (SELECT PurchaseID FROM @bh), @inv INT = (SELECT InvoiceID FROM @bh);
IF EXISTS (SELECT 1 FROM INVOICE WHERE InvoiceID = @inv AND UserID = 3 AND Status = 'Issued' AND Amount = @fee
                                     AND PeriodFrom = @prev AND PeriodTo = EOMONTH(@prev) AND IssueDate = CAST(SYSUTCDATETIME() AS DATE))
   AND EXISTS (SELECT 1 FROM SERVICE_PURCHASE WHERE PurchaseID = @pur AND InvoiceID = @inv AND PremiseID = 1 AND ServiceTypeID = 1
                                                AND MonthFrom = @prev AND MonthTo = @prev AND Amount = @fee)
    PRINT 'OK   buy_history: invoice + purchase created, amount = fee' ELSE PRINT 'FAIL buy_history rows';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'SERVICE_PURCHASE' AND ObjectID = CAST(@pur AS VARCHAR(100)) AND PerformedBy = 3)
    PRINT 'OK   buy_history: AUDIT_LOG row' ELSE PRINT 'FAIL buy_history audit';

BEGIN TRY EXEC sp_consumer_buy_history 3, 1, @prev, @prev; PRINT 'FAIL overlapping purchase accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51110 PRINT 'OK   buy_history: overlap -> 51110' ELSE PRINT 'FAIL overlap: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM SERVICE_PURCHASE WHERE PremiseID = 1) = 1
    PRINT 'OK   buy_history: refused overlap left no extra purchase' ELSE PRINT 'FAIL overlap rollback';

-- μετά την αγορά το διάστημα του προηγούμενου μήνα επιτρέπεται (αν πέφτει μέσα στην εγκατάσταση)
IF @prev = '2026-10-01'
BEGIN
    DECLARE @rd3 TABLE (IntervalStart DATETIME2(0), ImportKWh DECIMAL(15,4), ExportKWh DECIMAL(15,4), VoltageL1 DECIMAL(15,4), Quality VARCHAR(9));
    BEGIN TRY
        INSERT @rd3 EXEC sp_consumer_readings 3, 1, '2026-10-05', '2026-10-06';
        PRINT 'OK   readings: purchased earlier month is readable';
    END TRY
    BEGIN CATCH PRINT 'FAIL purchased month refused: ' + ERROR_MESSAGE(); END CATCH;
END
ELSE PRINT 'OK   readings: (skipped, previous month is not Oct 2026)';

DECLARE @lpu TABLE (PurchaseID INT, PurchasedAt DATETIME2(0), Address NVARCHAR(200), MonthFrom DATE, MonthTo DATE,
                    Amount DECIMAL(10,2), InvoiceID INT, InvoiceStatus NVARCHAR(30));
INSERT @lpu EXEC sp_consumer_list_purchases 3;
IF (SELECT COUNT(*) FROM @lpu) = 1 AND EXISTS (SELECT 1 FROM @lpu WHERE PurchaseID = @pur AND Address IS NOT NULL)
    PRINT 'OK   list_purchases: own purchase listed' ELSE PRINT 'FAIL list_purchases';
DECLARE @lpu2 TABLE (PurchaseID INT, PurchasedAt DATETIME2(0), Address NVARCHAR(200), MonthFrom DATE, MonthTo DATE,
                     Amount DECIMAL(10,2), InvoiceID INT, InvoiceStatus NVARCHAR(30));
INSERT @lpu2 EXEC sp_consumer_list_purchases 4;
IF (SELECT COUNT(*) FROM @lpu2) = 0 PRINT 'OK   list_purchases: other consumer sees none' ELSE PRINT 'FAIL list_purchases isolation';

-- ---------- ιστορικό από METER_AGGREGATE ----------
DECLARE @hd TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), EstimatedCount INT);
INSERT @hd EXEC sp_consumer_history 3, 1, 'Day', '2026-11-18', '2026-11-19';
IF (SELECT COUNT(*) FROM @hd) = 2
   AND NOT EXISTS (SELECT 1 FROM @hd h LEFT JOIN METER_AGGREGATE a
                     ON a.MeterID = 1 AND a.ObisCode = '1.8.0' AND a.PeriodType = 'Day' AND a.PeriodStart = h.PeriodStart
                   WHERE a.SumValue IS NULL OR a.SumValue <> h.ImportKWh OR h.ExportKWh <> 0 OR h.NetKWh <> h.ImportKWh)
    PRINT 'OK   history: Day rows match METER_AGGREGATE' ELSE PRINT 'FAIL history day';
DECLARE @hd2 TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), EstimatedCount INT);
INSERT @hd2 EXEC sp_consumer_history 4, 3, 'Day', '2026-11-18', '2026-11-18';
IF (SELECT COUNT(*) FROM @hd2) = 1
   AND EXISTS (SELECT 1 FROM @hd2 h WHERE h.ImportKWh = (SELECT SumValue FROM METER_AGGREGATE WHERE MeterID = 3 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-18')
                                      AND h.ExportKWh = (SELECT SumValue FROM METER_AGGREGATE WHERE MeterID = 3 AND ObisCode = '2.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-18')
                                      AND h.NetKWh = h.ImportKWh - h.ExportKWh)
    PRINT 'OK   history: prosumer import/export/net side by side' ELSE PRINT 'FAIL history prosumer';
BEGIN TRY EXEC sp_consumer_history 3, 3, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL history of foreign meter'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51100 PRINT 'OK   history: foreign meter -> 51100' ELSE PRINT 'FAIL history foreign: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_history 3, 1, 'Week', '2026-11-18', '2026-11-19'; PRINT 'FAIL bad period type accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 51107 PRINT 'OK   history: bad period type -> 51107' ELSE PRINT 'FAIL period type: ' + ERROR_MESSAGE(); END CATCH;


PRINT 'test_consumer.sql: τέλος';
