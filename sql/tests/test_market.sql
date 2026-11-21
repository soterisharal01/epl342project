-- =====================================================================
-- test_market.sql : έλεγχοι για το procs_market.sql (MKT-1, MKT-2, MKT-3).
-- Κοινά δεδομένα: supplier1 = UserID 9 (SupplierID 1: υποστατικά 1, 2, 4 -> μετρητές 1, 2, 4),
-- ο μετρητής 3 (υποστατικό 3) ανήκει στον προμηθευτή 2. aggregator1 = UserID 10
-- (χαρτοφυλάκιο 1: υποστατικά 3, 4 -> μετρητές 3, 4). consumer1 = 3, dso1 = 7.
-- Κάθε γραμμή τυπώνει OK ή FAIL.
-- =====================================================================
SET NOCOUNT ON;

-- ---------- Έλεγχος ρόλου (52500) ----------
BEGIN TRY EXEC sp_supplier_aggregates 3, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL consumer saw supplier aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   consumer -> aggregates 52500' ELSE PRINT 'FAIL consumer aggregates: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_supplier_aggregates 7, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL DSO saw supplier aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   DSO -> aggregates 52500' ELSE PRINT 'FAIL DSO aggregates: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_supplier_totals 3, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL consumer saw totals'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   consumer -> totals 52500' ELSE PRINT 'FAIL consumer totals: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_market_intraday 3, '2026-11-19'; PRINT 'FAIL consumer saw intraday'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   consumer -> intraday 52500' ELSE PRINT 'FAIL consumer intraday: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_market_intraday 7, '2026-11-19'; PRINT 'FAIL DSO saw intraday'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   DSO -> intraday 52500' ELSE PRINT 'FAIL DSO intraday: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_market_assert 9; PRINT 'OK   assert passes for supplier1'; END TRY
BEGIN CATCH PRINT 'FAIL assert supplier1: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_market_assert 10; PRINT 'OK   assert passes for aggregator1'; END TRY
BEGIN CATCH PRINT 'FAIL assert aggregator1: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Μη έγκυρα ορίσματα ----------
BEGIN TRY EXEC sp_supplier_aggregates 9, 'Week', '2026-11-18', '2026-11-19'; PRINT 'FAIL bad PeriodType accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52501 PRINT 'OK   bad PeriodType -> 52501' ELSE PRINT 'FAIL PeriodType: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_supplier_aggregates 9, 'Day', '2026-11-19', '2026-11-18'; PRINT 'FAIL From > To accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52502 PRINT 'OK   From > To -> 52502' ELSE PRINT 'FAIL range: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_market_intraday 9, NULL; PRINT 'FAIL NULL date accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52503 PRINT 'OK   NULL date -> 52503' ELSE PRINT 'FAIL NULL date: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- MKT-1: προμηθευτής 1 (Day-Ahead 18-19/11/2026) ----------
DECLARE @ag TABLE (PeriodStart DATE, TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @ag EXEC sp_supplier_aggregates 9, 'Day', '2026-11-18', '2026-11-19';

-- Αναμενόμενο υπολογισμένο απευθείας από τα δεδομένα: μετρητές των υποστατικών με σύμβαση SupplierID 1
DECLARE @expImp DECIMAL(18,4), @expExp DECIMAL(18,4);
SELECT @expImp = ISNULL(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue END), 0),
       @expExp = ISNULL(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue END), 0)
FROM METER_AGGREGATE ma
WHERE ma.PeriodType = 'Day' AND ma.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
  AND ma.MeterID IN (SELECT mi.MeterID FROM METER_INSTALLATION mi
                     JOIN SUPPLY_CONTRACT sc ON sc.PremiseID = mi.PremiseID
                     WHERE sc.SupplierID = 1 AND mi.ConfirmationStatus = 'Confirmed');
IF EXISTS (SELECT 1 FROM @ag) PRINT 'OK   supplier1 aggregates return rows' ELSE PRINT 'FAIL supplier1 aggregates empty';
IF (SELECT SUM(ImportKWh) FROM @ag) = @expImp AND @expImp > 0
    PRINT 'OK   supplier1 import = sum of own meters (' + CAST(@expImp AS VARCHAR(30)) + ')' ELSE PRINT 'FAIL supplier1 import sum';
IF (SELECT SUM(ExportKWh) FROM @ag) = @expExp
    PRINT 'OK   supplier1 export = sum of own meters (' + CAST(@expExp AS VARCHAR(30)) + ')' ELSE PRINT 'FAIL supplier1 export sum';
IF NOT EXISTS (SELECT 1 FROM @ag WHERE ABS(NetKWh - (ImportKWh - ExportKWh)) > 0.00005)
    PRINT 'OK   net = import - export in every row' ELSE PRINT 'FAIL net column';
-- Ο μετρητής 3 (προμηθευτής 2) εξάγει ενέργεια· ο προμηθευτής 1 δεν πρέπει να τη δει
IF (SELECT SUM(ExportKWh) FROM @ag) = 0
    PRINT 'OK   supplier1 sees nothing of supplier 2 (meter 3 export absent)' ELSE PRINT 'FAIL supplier1 sees supplier 2 export';
IF (SELECT MAX(MeterCount) FROM @ag) <= 3 AND NOT EXISTS (SELECT 1 FROM @ag WHERE TransformerID = 6)
    PRINT 'OK   supplier1 has no rows for meter 3 transformer (6)' ELSE PRINT 'FAIL supplier1 sees transformer 6';
IF EXISTS (SELECT 1 FROM @ag WHERE TransformerName IS NOT NULL AND GeofenceName IS NOT NULL)
    PRINT 'OK   transformer and geofence names present' ELSE PRINT 'FAIL names';

-- Σύνολα ανά περίοδο
DECLARE @tt TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @tt EXEC sp_supplier_totals 9, 'Day', '2026-11-18', '2026-11-19';
IF (SELECT COUNT(*) FROM @tt) = 2 AND (SELECT SUM(ImportKWh) FROM @tt) = @expImp
    PRINT 'OK   supplier totals: 2 days, same import' ELSE PRINT 'FAIL supplier totals';
IF (SELECT MeterCount FROM @tt WHERE PeriodStart = '2026-11-18') = 3
    PRINT 'OK   supplier1 18/11 has 3 meters (1, 2, 4)' ELSE PRINT 'FAIL supplier1 meter count';

-- Μήνας / κανένα αποτέλεσμα: ΔΕΝ αποτυγχάνει, απλώς 0 γραμμές
DECLARE @tm TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @tm EXEC sp_supplier_totals 9, 'Month', '2026-11-01', '2026-11-30';
IF NOT EXISTS (SELECT 1 FROM @tm) PRINT 'OK   Month period with no aggregates -> 0 rows' ELSE PRINT 'INFO Month rows exist (' + CAST((SELECT COUNT(*) FROM @tm) AS VARCHAR(10)) + ')';

-- ---------- MKT-1: aggregator 1 (χαρτοφυλάκιο: υποστατικά 3 και 4) ----------
DECLARE @ga TABLE (PeriodStart DATE, TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @ga EXEC sp_supplier_aggregates 10, 'Day', '2026-11-18', '2026-11-19';
DECLARE @aImp DECIMAL(18,4), @aExp DECIMAL(18,4);
SELECT @aImp = ISNULL(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue END), 0),
       @aExp = ISNULL(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue END), 0)
FROM METER_AGGREGATE ma
WHERE ma.PeriodType = 'Day' AND ma.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
  AND ma.MeterID IN (SELECT mi.MeterID FROM METER_INSTALLATION mi
                     JOIN INCLUDES i ON i.PremiseID = mi.PremiseID
                     WHERE i.PortfolioID = 1 AND mi.ConfirmationStatus = 'Confirmed');
IF (SELECT SUM(ImportKWh) FROM @ga) = @aImp AND (SELECT SUM(ExportKWh) FROM @ga) = @aExp AND @aImp > 0 AND @aExp > 0
    PRINT 'OK   aggregator1 sums = portfolio premises only' ELSE PRINT 'FAIL aggregator1 sums';
IF NOT EXISTS (SELECT 1 FROM @ga WHERE TransformerID = 5)
    PRINT 'OK   aggregator1 does not see meter 2 (transformer 5)' ELSE PRINT 'FAIL aggregator1 sees non-portfolio meter';
IF (SELECT SUM(ImportKWh) FROM @ga) <> (SELECT SUM(ImportKWh) FROM @ag)
    PRINT 'OK   aggregator and supplier see different data' ELSE PRINT 'FAIL same data for both';

-- Η περίοδος μετράει: πριν την έναρξη του χαρτοφυλακίου/σύμβασης δεν φαίνεται τίποτα
DECLARE @old TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @old EXEC sp_supplier_totals 10, 'Day', '2025-01-01', '2025-12-31';
IF NOT EXISTS (SELECT 1 FROM @old) PRINT 'OK   period before the portfolio -> no rows' ELSE PRINT 'FAIL old period shows data';

-- ---------- MKT-3: Intraday 2026-11-19 ----------
DECLARE @id TABLE (IntervalStart DATETIME2(0), TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, Provisional BIT);
INSERT @id EXEC sp_market_intraday 9, '2026-11-19';
IF EXISTS (SELECT 1 FROM @id) PRINT 'OK   intraday supplier1 returns rows' ELSE PRINT 'FAIL intraday empty';
IF (SELECT COUNT(DISTINCT IntervalStart) FROM @id) <= 96 PRINT 'OK   intraday <= 96 intervals' ELSE PRINT 'FAIL intraday > 96 intervals';
IF NOT EXISTS (SELECT 1 FROM @id WHERE ImportKWh < 0 OR ExportKWh < 0)
    PRINT 'OK   intraday import/export non-negative' ELSE PRINT 'FAIL intraday negative';
IF NOT EXISTS (SELECT 1 FROM @id WHERE Provisional <> 1) PRINT 'OK   intraday all rows Provisional = 1' ELSE PRINT 'FAIL intraday provisional flag';
IF NOT EXISTS (SELECT 1 FROM @id WHERE IntervalStart < '2026-11-19' OR IntervalStart >= '2026-11-20')
    PRINT 'OK   intraday only that day' ELSE PRINT 'FAIL intraday other days';
IF EXISTS (SELECT 1 FROM @id WHERE IntervalStart = '2026-11-19 00:00:00')
    PRINT 'OK   first interval uses last reading of previous day' ELSE PRINT 'FAIL intraday 00:00 missing';
IF NOT EXISTS (SELECT 1 FROM @id WHERE TransformerID = 6) AND NOT EXISTS (SELECT 1 FROM @id WHERE ExportKWh <> 0)
    PRINT 'OK   intraday supplier1 has no meter 3 data' ELSE PRINT 'FAIL intraday supplier1 sees supplier 2';
-- Έλεγχος μεθόδου: ενέργεια 12:15 = RAW(12:15) - RAW(12:00). Οι μετρητές 1 και 4 του προμηθευτή 1 είναι
-- και οι δύο στον μετασχηματιστή 4, άρα το άθροισμά τους συγκρίνεται με τη διαφορά των RAW τιμών τους.
DECLARE @expImp DECIMAL(18,4), @expExp DECIMAL(18,4);
SELECT @expImp = ISNULL(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue END), 0),
       @expExp = ISNULL(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue END), 0)
FROM METER_AGGREGATE ma
WHERE ma.PeriodType = 'Day' AND ma.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
  AND ma.MeterID IN (SELECT mi.MeterID FROM METER_INSTALLATION mi
                     JOIN SUPPLY_CONTRACT sc ON sc.PremiseID = mi.PremiseID
                     WHERE sc.SupplierID = 1 AND mi.ConfirmationStatus = 'Confirmed');
IF EXISTS (SELECT 1 FROM @ag) PRINT 'OK   supplier1 aggregates return rows' ELSE PRINT 'FAIL supplier1 aggregates empty';
IF (SELECT SUM(ImportKWh) FROM @ag) = @expImp AND @expImp > 0
    PRINT 'OK   supplier1 import = sum of own meters (' + CAST(@expImp AS VARCHAR(30)) + ')' ELSE PRINT 'FAIL supplier1 import sum';
IF (SELECT SUM(ExportKWh) FROM @ag) = @expExp
    PRINT 'OK   supplier1 export = sum of own meters (' + CAST(@expExp AS VARCHAR(30)) + ')' ELSE PRINT 'FAIL supplier1 export sum';
IF NOT EXISTS (SELECT 1 FROM @ag WHERE ABS(NetKWh - (ImportKWh - ExportKWh)) > 0.00005)
    PRINT 'OK   net = import - export in every row' ELSE PRINT 'FAIL net column';
-- Ο μετρητής 3 (προμηθευτής 2) εξάγει ενέργεια· ο προμηθευτής 1 δεν πρέπει να τη δει
IF (SELECT SUM(ExportKWh) FROM @ag) = 0
    PRINT 'OK   supplier1 sees nothing of supplier 2 (meter 3 export absent)' ELSE PRINT 'FAIL supplier1 sees supplier 2 export';
IF (SELECT MAX(MeterCount) FROM @ag) <= 3 AND NOT EXISTS (SELECT 1 FROM @ag WHERE TransformerID = 6)
    PRINT 'OK   supplier1 has no rows for meter 3 transformer (6)' ELSE PRINT 'FAIL supplier1 sees transformer 6';
IF EXISTS (SELECT 1 FROM @ag WHERE TransformerName IS NOT NULL AND GeofenceName IS NOT NULL)
    PRINT 'OK   transformer and geofence names present' ELSE PRINT 'FAIL names';

-- Σύνολα ανά περίοδο
DECLARE @tt TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @tt EXEC sp_supplier_totals 9, 'Day', '2026-11-18', '2026-11-19';
IF (SELECT COUNT(*) FROM @tt) = 2 AND (SELECT SUM(ImportKWh) FROM @tt) = @expImp
    PRINT 'OK   supplier totals: 2 days, same import' ELSE PRINT 'FAIL supplier totals';
IF (SELECT MeterCount FROM @tt WHERE PeriodStart = '2026-11-18') = 3
    PRINT 'OK   supplier1 18/11 has 3 meters (1, 2, 4)' ELSE PRINT 'FAIL supplier1 meter count';

-- Μήνας / κανένα αποτέλεσμα: ΔΕΝ αποτυγχάνει, απλώς 0 γραμμές
DECLARE @tm TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @tm EXEC sp_supplier_totals 9, 'Month', '2026-11-01', '2026-11-30';
IF NOT EXISTS (SELECT 1 FROM @tm) PRINT 'OK   Month period with no aggregates -> 0 rows' ELSE PRINT 'INFO Month rows exist (' + CAST((SELECT COUNT(*) FROM @tm) AS VARCHAR(10)) + ')';

-- ---------- MKT-1: aggregator 1 (χαρτοφυλάκιο: υποστατικά 3 και 4) ----------
DECLARE @ga TABLE (PeriodStart DATE, TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @ga EXEC sp_supplier_aggregates 10, 'Day', '2026-11-18', '2026-11-19';
DECLARE @aImp DECIMAL(18,4), @aExp DECIMAL(18,4);
SELECT @aImp = ISNULL(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue END), 0),
       @aExp = ISNULL(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue END), 0)
FROM METER_AGGREGATE ma
WHERE ma.PeriodType = 'Day' AND ma.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
  AND ma.MeterID IN (SELECT mi.MeterID FROM METER_INSTALLATION mi
                     JOIN INCLUDES i ON i.PremiseID = mi.PremiseID
                     WHERE i.PortfolioID = 1 AND mi.ConfirmationStatus = 'Confirmed');
IF (SELECT SUM(ImportKWh) FROM @ga) = @aImp AND (SELECT SUM(ExportKWh) FROM @ga) = @aExp AND @aImp > 0 AND @aExp > 0
    PRINT 'OK   aggregator1 sums = portfolio premises only' ELSE PRINT 'FAIL aggregator1 sums';
IF NOT EXISTS (SELECT 1 FROM @ga WHERE TransformerID = 5)
    PRINT 'OK   aggregator1 does not see meter 2 (transformer 5)' ELSE PRINT 'FAIL aggregator1 sees non-portfolio meter';
IF (SELECT SUM(ImportKWh) FROM @ga) <> (SELECT SUM(ImportKWh) FROM @ag)
    PRINT 'OK   aggregator and supplier see different data' ELSE PRINT 'FAIL same data for both';

-- Η περίοδος μετράει: πριν την έναρξη του χαρτοφυλακίου/σύμβασης δεν φαίνεται τίποτα
DECLARE @old TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, EstimatedCount INT);
INSERT @old EXEC sp_supplier_totals 10, 'Day', '2025-01-01', '2025-12-31';
IF NOT EXISTS (SELECT 1 FROM @old) PRINT 'OK   period before the portfolio -> no rows' ELSE PRINT 'FAIL old period shows data';

-- ---------- MKT-3: Intraday 2026-11-19 ----------
DECLARE @id TABLE (IntervalStart DATETIME2(0), TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, Provisional BIT);
INSERT @id EXEC sp_market_intraday 9, '2026-11-19';
IF EXISTS (SELECT 1 FROM @id) PRINT 'OK   intraday supplier1 returns rows' ELSE PRINT 'FAIL intraday empty';
IF (SELECT COUNT(DISTINCT IntervalStart) FROM @id) <= 96 PRINT 'OK   intraday <= 96 intervals' ELSE PRINT 'FAIL intraday > 96 intervals';
IF NOT EXISTS (SELECT 1 FROM @id WHERE ImportKWh < 0 OR ExportKWh < 0)
    PRINT 'OK   intraday import/export non-negative' ELSE PRINT 'FAIL intraday negative';
IF NOT EXISTS (SELECT 1 FROM @id WHERE Provisional <> 1) PRINT 'OK   intraday all rows Provisional = 1' ELSE PRINT 'FAIL intraday provisional flag';
IF NOT EXISTS (SELECT 1 FROM @id WHERE IntervalStart < '2026-11-19' OR IntervalStart >= '2026-11-20')
    PRINT 'OK   intraday only that day' ELSE PRINT 'FAIL intraday other days';
IF EXISTS (SELECT 1 FROM @id WHERE IntervalStart = '2026-11-19 00:00:00')
    PRINT 'OK   first interval uses last reading of previous day' ELSE PRINT 'FAIL intraday 00:00 missing';
IF NOT EXISTS (SELECT 1 FROM @id WHERE TransformerID = 6) AND NOT EXISTS (SELECT 1 FROM @id WHERE ExportKWh <> 0)
    PRINT 'OK   intraday supplier1 has no meter 3 data' ELSE PRINT 'FAIL intraday supplier1 sees supplier 2';
-- Έλεγχος μεθόδου: ενέργεια 00:15 του μετρητή 1 = RAW(00:15) - RAW(00:00). Ο μετρητής 1 είναι ο μόνος στον μετασχηματιστή 4 εκτός από τον 4, άρα
-- συγκρίνουμε το άθροισμα (μετρητές 1 + 4) με τη διαφορά των RAW τιμών τους.
DECLARE @expI DECIMAL(18,4) =
    (SELECT SUM(b.ReceivedValue - a.ReceivedValue)
     FROM RAW_READING a JOIN RAW_READING b ON b.MeterID = a.MeterID AND b.ObisCode = a.ObisCode
          AND b.IntervalStart = DATEADD(MINUTE, 15, a.IntervalStart)
     WHERE a.ObisCode = '1.8.0' AND a.MeterID IN (1, 4) AND a.IntervalStart = '2026-11-19 12:00:00'
       AND b.ReceivedValue >= a.ReceivedValue);
IF (SELECT SUM(ImportKWh) FROM @id WHERE IntervalStart = '2026-11-19 12:15:00' AND TransformerID = 4) = @expI
   OR (@expI IS NULL AND NOT EXISTS (SELECT 1 FROM @id WHERE IntervalStart = '2026-11-19 12:15:00' AND TransformerID = 4))
    PRINT 'OK   intraday 12:15 = RAW difference (meters 1 + 4)' ELSE PRINT 'FAIL intraday delta method';

DECLARE @ia TABLE (IntervalStart DATETIME2(0), TransformerID INT, TransformerName NVARCHAR(50), GeofenceName NVARCHAR(100),
                   ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT, Provisional BIT);
INSERT @ia EXEC sp_market_intraday 10, '2026-11-19';
IF EXISTS (SELECT 1 FROM @ia WHERE ExportKWh > 0) AND NOT EXISTS (SELECT 1 FROM @ia WHERE ImportKWh < 0 OR ExportKWh < 0)
    PRINT 'OK   intraday aggregator1 sees meter 3 export' ELSE PRINT 'FAIL intraday aggregator1';
IF NOT EXISTS (SELECT 1 FROM @ia WHERE TransformerID = 5) PRINT 'OK   intraday aggregator1 has no transformer 5' ELSE PRINT 'FAIL intraday aggregator1 foreign meter';

-- ---------- MKT-2: χαρτοφυλάκια ----------
BEGIN TRY EXEC sp_aggregator_save_portfolio 9, NULL, N'Δεν επιτρέπεται'; PRINT 'FAIL supplier created a portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52510 PRINT 'OK   supplier cannot create portfolio -> 52510' ELSE PRINT 'FAIL supplier portfolio: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_save_portfolio 3, NULL, N'Καταναλωτής'; PRINT 'FAIL consumer created a portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52500 PRINT 'OK   consumer cannot create portfolio -> 52500' ELSE PRINT 'FAIL consumer portfolio: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_save_portfolio 10, NULL, N'   '; PRINT 'FAIL empty name accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52511 PRINT 'OK   empty portfolio name -> 52511' ELSE PRINT 'FAIL empty name: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_save_portfolio 10, 99999, N'Άγνωστο'; PRINT 'FAIL foreign portfolio renamed'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52512 PRINT 'OK   unknown/foreign portfolio -> 52512' ELSE PRINT 'FAIL foreign portfolio: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @pf TABLE (PortfolioID INT);
INSERT @pf EXEC sp_aggregator_save_portfolio 10, NULL, N'Test MKT χαρτοφυλάκιο';
DECLARE @newpf INT = (SELECT PortfolioID FROM @pf);
IF EXISTS (SELECT 1 FROM PORTFOLIO WHERE PortfolioID = @newpf AND AggregatorID = 1 AND Name = N'Test MKT χαρτοφυλάκιο')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'PORTFOLIO' AND ObjectID = CAST(@newpf AS VARCHAR(100)) AND Action = 'Create portfolio')
    PRINT 'OK   create portfolio + AUDIT_LOG' ELSE PRINT 'FAIL create portfolio';
DELETE @pf;
INSERT @pf EXEC sp_aggregator_save_portfolio 10, @newpf, N'Test MKT μετονομασμένο';
IF EXISTS (SELECT 1 FROM PORTFOLIO WHERE PortfolioID = @newpf AND Name = N'Test MKT μετονομασμένο')
    PRINT 'OK   rename portfolio' ELSE PRINT 'FAIL rename portfolio';

EXEC sp_aggregator_add_premise 10, @newpf, 5, '2026-11-01';
IF EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @newpf AND PremiseID = 5 AND StartDate = '2026-11-01' AND EndDate IS NULL)
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'INCLUDES' AND ObjectID = CAST(@newpf AS VARCHAR(20)) + '/5' AND Action = 'Add premise to portfolio')
    PRINT 'OK   add premise to portfolio + AUDIT_LOG' ELSE PRINT 'FAIL add premise';
BEGIN TRY EXEC sp_aggregator_add_premise 10, @newpf, 5; PRINT 'FAIL duplicate premise accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52514 PRINT 'OK   premise already in portfolio -> 52514' ELSE PRINT 'FAIL duplicate premise: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_add_premise 10, @newpf, 999999; PRINT 'FAIL unknown premise accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52513 PRINT 'OK   unknown premise -> 52513' ELSE PRINT 'FAIL unknown premise: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_aggregator_add_premise 10, 99999, 5; PRINT 'FAIL premise added to foreign portfolio'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52512 PRINT 'OK   add to foreign portfolio -> 52512' ELSE PRINT 'FAIL foreign add: ' + ERROR_MESSAGE(); END CATCH;

EXEC sp_aggregator_remove_premise 10, @newpf, 5;
IF EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @newpf AND PremiseID = 5 AND EndDate IS NOT NULL)
    PRINT 'OK   remove premise closes the row' ELSE PRINT 'FAIL remove premise';
BEGIN TRY EXEC sp_aggregator_remove_premise 10, @newpf, 5; PRINT 'FAIL removed twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 52515 PRINT 'OK   remove again -> 52515' ELSE PRINT 'FAIL remove twice: ' + ERROR_MESSAGE(); END CATCH;
EXEC sp_aggregator_add_premise 10, @newpf, 5, '2026-11-02';
IF EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @newpf AND PremiseID = 5 AND StartDate = '2026-11-02' AND EndDate IS NULL)
    PRINT 'OK   removed premise can be added again' ELSE PRINT 'FAIL re-add premise';
-- Η δοκιμή δεν αφήνει ανοιχτό υποστατικό στο δοκιμαστικό χαρτοφυλάκιο
EXEC sp_aggregator_remove_premise 10, @newpf, 5;
