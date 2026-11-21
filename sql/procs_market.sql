-- =====================================================================
-- procs_market.sql : ΙΙΙ.5 Προμηθευτές και Aggregators (περιοχή MKT)
--   MKT-1 ★ sp_supplier_aggregates / sp_supplier_totals (Day-Ahead, επικυρωμένα)
--   MKT-3 ★ sp_market_intraday (15λεπτα ΠΡΟΣΩΡΙΝΑ από RAW_READING)
--   MKT-2   χαρτοφυλάκια aggregator (save / add premise / remove premise)
-- Τρέχει μετά το procs_common.sql. Λάθη: 52500-52999 (απόφαση Α4, υπο-εύρος MKT).
-- Ο Προμηθευτής/Aggregator βλέπει ΜΟΝΟ αθροίσματα των δικών του πελατών/χαρτοφυλακίων,
-- ΠΟΤΕ γραμμή-γραμμή μετρήσεις. Διαβάζει METER_AGGREGATE και RAW_READING μόνο (συμφωνία X6).
-- Τιμές (απόφαση B2): τα RAW 1.8.0/2.8.0 είναι σωρευτικοί μετρητές, οι επικυρωμένες τιμές
-- (και άρα τα METER_AGGREGATE) είναι ενέργεια 15λεπτου.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: σταματά με λάθος αν ο χρήστης δεν είναι ενεργός Προμηθευτής ή Aggregator.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_market_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT
                   WHERE UserID = @UserID AND AccountStatus = 'Active'
                     AND ((Role = 'Supplier' AND SupplierID IS NOT NULL)
                       OR (Role = 'Aggregator' AND AggregatorID IS NOT NULL)))
        THROW 52500, N'Δεν επιτρέπεται: μόνο για ενεργό Προμηθευτή ή Aggregator.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- «Δικοί του πελάτες»: υποστατικά (+ μετρητές) της εταιρείας του χρήστη στην περίοδο [@From, @To].
--   Supplier   -> υποστατικά με SUPPLY_CONTRACT του SupplierID του, που επικαλύπτεται με την περίοδο.
--   Aggregator -> υποστατικά σε INCLUDES χαρτοφυλακίου του AggregatorID του, που επικαλύπτεται.
--   Μετρητής   -> εγκατάσταση Confirmed στο υποστατικό, που δεν αφαιρέθηκε πριν την περίοδο.
-- Άλλος ρόλος / ανενεργός λογαριασμός -> καμία γραμμή.
-- Inline table-valued function (καλείται χωρίς σχήμα, καμία scalar function).
-- Χρήση:  SELECT DISTINCT MeterID FROM fn_market_premises(@UserID, @From, @To)
-- ---------------------------------------------------------------------
CREATE OR ALTER FUNCTION fn_market_premises (@UserID INT, @From DATE, @To DATE)
RETURNS TABLE
AS
RETURN (
    WITH prem AS (
        SELECT sc.PremiseID
        FROM USER_ACCOUNT u
        JOIN SUPPLY_CONTRACT sc ON sc.SupplierID = u.SupplierID
                               AND sc.StartDate <= @To
                               AND (sc.EndDate IS NULL OR sc.EndDate >= @From)
        WHERE u.UserID = @UserID AND u.Role = 'Supplier' AND u.AccountStatus = 'Active'
        UNION
        SELECT i.PremiseID
        FROM USER_ACCOUNT u
        JOIN PORTFOLIO po ON po.AggregatorID = u.AggregatorID
        JOIN INCLUDES i ON i.PortfolioID = po.PortfolioID
                       AND i.StartDate <= @To
                       AND (i.EndDate IS NULL OR i.EndDate >= @From)
        WHERE u.UserID = @UserID AND u.Role = 'Aggregator' AND u.AccountStatus = 'Active'
    )
    SELECT DISTINCT prem.PremiseID, mi.MeterID
    FROM prem
    JOIN METER_INSTALLATION mi ON mi.PremiseID = prem.PremiseID
                              AND mi.ConfirmationStatus = 'Confirmed'
                              AND mi.InstalledAt < DATEADD(DAY, 1, CAST(@To AS DATETIME2(0)))
                              AND (mi.RemovedAt IS NULL OR mi.RemovedAt >= CAST(@From AS DATETIME2(0)))
);
GO

-- =====================================================================
-- MKT-1 ★ Αθροίσματα προμηθευτή / aggregator (ΙΙΙ.5.1, Day-Ahead)
-- =====================================================================

-- Ανά περίοδο και ανά μετασχηματιστή (+ όνομα geofence): εισαγωγή (1.8.0), εξαγωγή (2.8.0), καθαρό.
-- Δουλεύει και για Supplier και για Aggregator (η σελίδα του aggregator το ξαναχρησιμοποιεί).
-- @PeriodType: 'Day' (= Day-Ahead), 'Month' ή 'Year'. Day-Ahead = ΜΟΝΟ επικυρωμένα δεδομένα:
-- το METER_AGGREGATE φτιάχνεται από το DSO μόνο από VALIDATED_READING, ποτέ από RAW_READING.
-- Επιστρέφει ΜΟΝΟ αθροίσματα (καμία γραμμή ανά μετρητή).
-- Στήλες: PeriodStart, TransformerID, TransformerName, GeofenceName, ImportKWh, ExportKWh, NetKWh,
--         MeterCount (διακριτοί μετρητές), EstimatedCount (εκτιμημένες 15λεπτες τιμές στο άθροισμα).
CREATE OR ALTER PROCEDURE sp_supplier_aggregates
    @UserID INT, @PeriodType VARCHAR(5), @From DATE, @To DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_market_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Year')
        THROW 52501, N'Μη έγκυρος τύπος περιόδου (Day, Month ή Year).', 1;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 52502, N'Μη έγκυρο διάστημα ημερομηνιών.', 1;

    WITH my AS (SELECT DISTINCT MeterID FROM fn_market_premises(@UserID, @From, @To))
    SELECT ma.PeriodStart,
           t.TransformerID,
           t.Name  AS TransformerName,
           g.Name  AS GeofenceName,
           CAST(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS ImportKWh,
           CAST(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS ExportKWh,
           CAST(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue
                         WHEN ma.ObisCode = '2.8.0' THEN -ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS NetKWh,
           COUNT(DISTINCT ma.MeterID) AS MeterCount,
           SUM(ma.EstimatedCount)     AS EstimatedCount
    FROM METER_AGGREGATE ma
    JOIN my ON my.MeterID = ma.MeterID
    JOIN METER m ON m.MeterID = ma.MeterID
    JOIN TRANSFORMER t ON t.TransformerID = m.TransformerID
    JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
    WHERE ma.PeriodType = @PeriodType
      AND ma.PeriodStart BETWEEN @From AND @To
      AND ma.ObisCode IN ('1.8.0', '2.8.0')
    GROUP BY ma.PeriodStart, t.TransformerID, t.Name, g.Name
    ORDER BY ma.PeriodStart, t.TransformerID;
END;
GO

-- Γραμμή συνόλου ανά περίοδο (όλοι οι μετασχηματιστές μαζί). Ίδια ορίσματα και κανόνες με το
-- sp_supplier_aggregates. Στήλες: PeriodStart, ImportKWh, ExportKWh, NetKWh, MeterCount, EstimatedCount.
CREATE OR ALTER PROCEDURE sp_supplier_totals
    @UserID INT, @PeriodType VARCHAR(5), @From DATE, @To DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_market_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Year')
        THROW 52501, N'Μη έγκυρος τύπος περιόδου (Day, Month ή Year).', 1;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 52502, N'Μη έγκυρο διάστημα ημερομηνιών.', 1;

    WITH my AS (SELECT DISTINCT MeterID FROM fn_market_premises(@UserID, @From, @To))
    SELECT ma.PeriodStart,
           CAST(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS ImportKWh,
           CAST(SUM(CASE WHEN ma.ObisCode = '2.8.0' THEN ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS ExportKWh,
           CAST(SUM(CASE WHEN ma.ObisCode = '1.8.0' THEN ma.SumValue
                         WHEN ma.ObisCode = '2.8.0' THEN -ma.SumValue ELSE 0 END) AS DECIMAL(18,4)) AS NetKWh,
           COUNT(DISTINCT ma.MeterID) AS MeterCount,
           SUM(ma.EstimatedCount)     AS EstimatedCount
    FROM METER_AGGREGATE ma
    JOIN my ON my.MeterID = ma.MeterID
    WHERE ma.PeriodType = @PeriodType
      AND ma.PeriodStart BETWEEN @From AND @To
      AND ma.ObisCode IN ('1.8.0', '2.8.0')
    GROUP BY ma.PeriodStart
    ORDER BY ma.PeriodStart;
END;
GO

-- =====================================================================
-- MKT-3 ★ Intraday: προσωρινά 15λεπτα από RAW_READING (ΙΙΙ.5.2)
-- =====================================================================

-- Δεν περιμένει το VEE: διαβάζει RAW_READING με οποιοδήποτε VeeStatus (Pending/Validated/Suspect),
-- γι' αυτό κάθε γραμμή έχει Provisional = 1 (τιμές που μπορεί να αλλάξουν μετά το VEE).
-- Μέθοδος (απόφαση B2): τα RAW 1.8.0/2.8.0 είναι ΣΩΡΕΥΤΙΚΟΙ μετρητές, άρα η ενέργεια του 15λεπτου
-- είναι η διαφορά από την προηγούμενη τιμή του ΙΔΙΟΥ μετρητή και κωδικού (LAG ανά MeterID, ObisCode
-- κατά IntervalStart). Η διαφορά ανήκει στο IntervalStart της μεταγενέστερης τιμής, όπως στις
-- επικυρωμένες τιμές. Για να έχει διαφορά και το πρώτο 15λεπτο (00:00) διαβάζεται και η τιμή 23:45
-- της προηγούμενης μέρας. Παραλείπονται 15λεπτα όπου: η προηγούμενη τιμή λείπει ή δεν είναι
-- ακριβώς 15 λεπτά πριν (κενό στη μετάδοση), ή η διαφορά είναι αρνητική (reset/αντικατάσταση μετρητή).
-- Επιστρέφει ΜΟΝΟ αθροίσματα ανά 15λεπτο και μετασχηματιστή, ποτέ μετρητή-μετρητή.
-- Στήλες: IntervalStart, TransformerID, TransformerName, GeofenceName, ImportKWh, ExportKWh, NetKWh,
--         MeterCount, Provisional (πάντα 1).
CREATE OR ALTER PROCEDURE sp_market_intraday
    @UserID INT, @Date DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_market_assert @UserID;
    IF @Date IS NULL
        THROW 52503, N'Δώστε ημερομηνία.', 1;

    DECLARE @dayStart DATETIME2(0) = CAST(@Date AS DATETIME2(0));
    DECLARE @dayEnd   DATETIME2(0) = DATEADD(DAY, 1, @dayStart);

    WITH my AS (SELECT DISTINCT MeterID FROM fn_market_premises(@UserID, @Date, @Date)),
    lagged AS (
        SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue,
               LAG(r.ReceivedValue) OVER (PARTITION BY r.MeterID, r.ObisCode ORDER BY r.IntervalStart) AS PrevValue,
               LAG(r.IntervalStart) OVER (PARTITION BY r.MeterID, r.ObisCode ORDER BY r.IntervalStart) AS PrevStart
        FROM RAW_READING r
        JOIN my ON my.MeterID = r.MeterID
        WHERE r.ObisCode IN ('1.8.0', '2.8.0')
          AND r.IntervalStart >= DATEADD(MINUTE, -15, @dayStart)
          AND r.IntervalStart <  @dayEnd
    ),
    delta AS (
        SELECT MeterID, ObisCode, IntervalStart, ReceivedValue - PrevValue AS Energy
        FROM lagged
        WHERE IntervalStart >= @dayStart
          AND PrevValue IS NOT NULL
          AND DATEDIFF(MINUTE, PrevStart, IntervalStart) = 15
          AND ReceivedValue - PrevValue >= 0
    )
    SELECT d.IntervalStart,
           t.TransformerID,
           t.Name AS TransformerName,
           g.Name AS GeofenceName,
           CAST(SUM(CASE WHEN d.ObisCode = '1.8.0' THEN d.Energy ELSE 0 END) AS DECIMAL(18,4)) AS ImportKWh,
           CAST(SUM(CASE WHEN d.ObisCode = '2.8.0' THEN d.Energy ELSE 0 END) AS DECIMAL(18,4)) AS ExportKWh,
           CAST(SUM(CASE WHEN d.ObisCode = '1.8.0' THEN d.Energy ELSE -d.Energy END) AS DECIMAL(18,4)) AS NetKWh,
           COUNT(DISTINCT d.MeterID) AS MeterCount,
           CAST(1 AS BIT) AS Provisional
    FROM delta d
    JOIN METER m ON m.MeterID = d.MeterID
    JOIN TRANSFORMER t ON t.TransformerID = m.TransformerID
    JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
    GROUP BY d.IntervalStart, t.TransformerID, t.Name, g.Name
    ORDER BY d.IntervalStart, t.TransformerID;
END;
GO

-- =====================================================================
-- MKT-2 Χαρτοφυλάκια aggregator (ΙΙΙ.5.1)
-- =====================================================================

-- Δημιουργία (μόνο Aggregator, όχι Supplier): (@PortfolioID NULL) ή μετονομασία χαρτοφυλακίου της εταιρείας του. Επιστρέφει PortfolioID.
CREATE OR ALTER PROCEDURE sp_aggregator_save_portfolio
    @UserID INT, @PortfolioID INT = NULL, @Name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_market_assert @UserID;
    DECLARE @agg INT = (SELECT AggregatorID FROM USER_ACCOUNT WHERE UserID = @UserID);
    IF @agg IS NULL
        THROW 52510, N'Δεν επιτρέπεται: μόνο για Aggregator.', 1;
    SET @Name = LTRIM(RTRIM(@Name));
    IF @Name IS NULL OR @Name = N''
        THROW 52511, N'Το όνομα χαρτοφυλακίου είναι υποχρεωτικό.', 1;
    IF @PortfolioID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PORTFOLIO WHERE PortfolioID = @PortfolioID AND AggregatorID = @agg)
        THROW 52512, N'Το χαρτοφυλάκιο δεν είναι δικό σας.', 1;
    BEGIN TRY
        BEGIN TRAN;
        IF @PortfolioID IS NULL
        BEGIN
            INSERT PORTFOLIO (Name, AggregatorID) VALUES (@Name, @agg);
            SET @PortfolioID = SCOPE_IDENTITY();
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
            VALUES ('PORTFOLIO', CAST(@PortfolioID AS VARCHAR(100)), 'Create portfolio', @Name, @UserID);
        END
        ELSE
        BEGIN
            DECLARE @old NVARCHAR(100) = (SELECT Name FROM PORTFOLIO WITH (UPDLOCK) WHERE PortfolioID = @PortfolioID);
            UPDATE PORTFOLIO SET Name = @Name WHERE PortfolioID = @PortfolioID;
            INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
            VALUES ('PORTFOLIO', CAST(@PortfolioID AS VARCHAR(100)), 'Rename portfolio', @old, @Name, @UserID);
        END
        COMMIT;
        SELECT @PortfolioID AS PortfolioID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Προσθήκη υποστατικού σε δικό του χαρτοφυλάκιο από την @StartDate (default σήμερα, UTC).
-- Αν το υποστατικό είχε αφαιρεθεί παλιότερα, ανοίγει ξανά (EndDate = NULL, νέα StartDate).
CREATE OR ALTER PROCEDURE sp_aggregator_add_premise
    @UserID INT, @PortfolioID INT, @PremiseID INT, @StartDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_market_assert @UserID;
    DECLARE @agg INT = (SELECT AggregatorID FROM USER_ACCOUNT WHERE UserID = @UserID);
    IF @agg IS NULL
        THROW 52510, N'Δεν επιτρέπεται: μόνο για Aggregator.', 1;
    IF NOT EXISTS (SELECT 1 FROM PORTFOLIO WHERE PortfolioID = @PortfolioID AND AggregatorID = @agg)
        THROW 52512, N'Το χαρτοφυλάκιο δεν είναι δικό σας.', 1;
    IF NOT EXISTS (SELECT 1 FROM PREMISE WHERE PremiseID = @PremiseID)
        THROW 52513, N'Το υποστατικό δεν υπάρχει.', 1;
    IF EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @PortfolioID AND PremiseID = @PremiseID AND EndDate IS NULL)
        THROW 52514, N'Το υποστατικό ανήκει ήδη στο χαρτοφυλάκιο.', 1;
    SET @StartDate = ISNULL(@StartDate, CAST(SYSUTCDATETIME() AS DATE));
    BEGIN TRY
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @PortfolioID AND PremiseID = @PremiseID)
            UPDATE INCLUDES SET StartDate = @StartDate, EndDate = NULL
            WHERE PortfolioID = @PortfolioID AND PremiseID = @PremiseID;
        ELSE
            INSERT INCLUDES (PortfolioID, PremiseID, StartDate) VALUES (@PortfolioID, @PremiseID, @StartDate);
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, NewState, PerformedBy)
        VALUES ('INCLUDES', CAST(@PortfolioID AS VARCHAR(20)) + '/' + CAST(@PremiseID AS VARCHAR(20)),
                'Add premise to portfolio', CONVERT(VARCHAR(10), @StartDate, 23), @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Αφαίρεση υποστατικού: κλείνει την εγγραφή (EndDate = σήμερα UTC, ή StartDate αν αυτή είναι μελλοντική).
-- Το ιστορικό μένει, ώστε παλιά αθροίσματα να εξακολουθούν να εξηγούνται.
CREATE OR ALTER PROCEDURE sp_aggregator_remove_premise
    @UserID INT, @PortfolioID INT, @PremiseID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_market_assert @UserID;
    DECLARE @agg INT = (SELECT AggregatorID FROM USER_ACCOUNT WHERE UserID = @UserID);
    IF @agg IS NULL
        THROW 52510, N'Δεν επιτρέπεται: μόνο για Aggregator.', 1;
    IF NOT EXISTS (SELECT 1 FROM PORTFOLIO WHERE PortfolioID = @PortfolioID AND AggregatorID = @agg)
        THROW 52512, N'Το χαρτοφυλάκιο δεν είναι δικό σας.', 1;
    IF NOT EXISTS (SELECT 1 FROM INCLUDES WHERE PortfolioID = @PortfolioID AND PremiseID = @PremiseID AND EndDate IS NULL)
        THROW 52515, N'Το υποστατικό δεν ανήκει αυτή τη στιγμή στο χαρτοφυλάκιο.', 1;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);
        UPDATE INCLUDES
        SET EndDate = CASE WHEN StartDate > @today THEN StartDate ELSE @today END
        WHERE PortfolioID = @PortfolioID AND PremiseID = @PremiseID AND EndDate IS NULL;
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, PerformedBy)
        VALUES ('INCLUDES', CAST(@PortfolioID AS VARCHAR(20)) + '/' + CAST(@PremiseID AS VARCHAR(20)),
                'Remove premise from portfolio', 'Active', @UserID);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO
