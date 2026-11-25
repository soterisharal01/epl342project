-- =====================================================================
-- procs_tso.sql : ΙΙΙ.4 Δέντρο μετασχηματιστών (περιοχή TSO)
--   TSO-1 νέος μετασχηματιστής + γεωφράκτης, δέντρο (αναδρομικό CTE), εύρεση φύλλου από συντεταγμένες
--   TSO-2 τρέχουσα κατάσταση (refresh φύλλων + άθροισμα προς τα πάνω)
--   TSO-3 aggregates σε οποιοδήποτε επίπεδο (Day/Month/Quarter/Year)
--   TSO-4 load shedding (εντολή + μία REMOTE_COMMAND ανά ενεργό μετρητή)
-- Τρέχει μετά το procs_common.sql. Λάθη: 53500-53999 (υποπεριοχή TSO).
-- Κανόνες: αυστηρό δέντρο (ένας γονέας), μετρητές ΜΟΝΟ σε φύλλα, ένας ορθογώνιος γεωφράκτης ανά μετασχηματιστή.
-- Κάθε procedure παίρνει πρώτο το @UserID και ελέγχει ότι είναι ενεργός TSO.
--
-- Αριθμοί λαθών:
--   53500 όχι ενεργός TSO            53505 υπάρχει ήδη ρίζα (ο γονέας δεν μπορεί να λείπει)
--   53501 λείπει όνομα                53506 ο γονέας έχει μετρητές (μόνο φύλλα έχουν μετρητές)
--   53502 μη έγκυρο ορθογώνιο         53507 ο γεωφράκτης του παιδιού δεν είναι μέσα στου γονέα
--   53503 το σημείο εκτός γεωφράκτη   53508 μη έγκυρες συντεταγμένες
--   53504 ο γονέας δεν υπάρχει        53509 ο κόμβος του δέντρου δεν υπάρχει
--   TSO-2: 53600 δεν υπάρχουν επικυρωμένες μετρήσεις 1.8.0/2.8.0   53601 ο μετασχηματιστής δεν υπάρχει
--   TSO-3: 53610 άγνωστος τύπος περιόδου   53611 μη έγκυρο διάστημα ημερομηνιών   53612 ο μετασχηματιστής δεν υπάρχει
--   TSO-4: 53620 λείπει αιτιολογία   53621 ο μετασχηματιστής δεν υπάρχει   53622 κανένας ενεργός μετρητής από κάτω
-- =====================================================================

CREATE OR ALTER PROCEDURE sp_tso_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'TSO' AND AccountStatus = 'Active')
        THROW 53500, N'Δεν επιτρέπεται: μόνο για ενεργό TSO.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- Νέος μετασχηματιστής: GEOFENCE + TRANSFORMER σε μία συναλλαγή.
-- @ParentTransformerID = NULL επιτρέπεται μόνο όταν δεν υπάρχει ακόμη ρίζα (ακριβώς μία ρίζα).
-- Απόφαση: ο γεωφράκτης του παιδιού ΠΡΕΠΕΙ να είναι μέσα στου γονέα (απορρίπτεται, δεν είναι απλή προειδοποίηση),
-- ώστε το δέντρο των γεωφρακτών να ακολουθεί το δέντρο των μετασχηματιστών.
-- Επιστρέφει: TransformerID, GeofenceID.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_add_transformer
    @UserID INT, @Name NVARCHAR(50), @Latitude DECIMAL(9,6), @Longitude DECIMAL(9,6),
    @ParentTransformerID INT, @GeofenceName NVARCHAR(100),
    @MinLat DECIMAL(9,6), @MinLon DECIMAL(9,6), @MaxLat DECIMAL(9,6), @MaxLon DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tso_assert @UserID;
    IF @Name IS NULL OR LEN(LTRIM(RTRIM(@Name))) = 0 OR @GeofenceName IS NULL OR LEN(LTRIM(RTRIM(@GeofenceName))) = 0
        THROW 53501, N'Δώστε όνομα μετασχηματιστή και όνομα γεωφράκτη.', 1;
    IF @MinLat IS NULL OR @MinLon IS NULL OR @MaxLat IS NULL OR @MaxLon IS NULL
       OR @MinLat < -90 OR @MaxLat > 90 OR @MinLon < -180 OR @MaxLon > 180
       OR @MinLat >= @MaxLat OR @MinLon >= @MaxLon
        THROW 53502, N'Μη έγκυρο ορθογώνιο: πρέπει MinLat < MaxLat και MinLon < MaxLon, μέσα στα όρια της Γης.', 1;
    IF @Latitude IS NULL OR @Longitude IS NULL OR @Latitude NOT BETWEEN -90 AND 90 OR @Longitude NOT BETWEEN -180 AND 180
        THROW 53508, N'Μη έγκυρες συντεταγμένες.', 1;
    IF @Latitude NOT BETWEEN @MinLat AND @MaxLat OR @Longitude NOT BETWEEN @MinLon AND @MaxLon
        THROW 53503, N'Ο μετασχηματιστής πρέπει να βρίσκεται μέσα στον δικό του γεωφράκτη.', 1;

    IF @ParentTransformerID IS NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM TRANSFORMER WHERE ParentTransformerID IS NULL)
            THROW 53505, N'Υπάρχει ήδη ρίζα στο δέντρο: δώστε γονέα.', 1;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @ParentTransformerID)
            THROW 53504, N'Ο γονέας μετασχηματιστής δεν υπάρχει.', 1;
        IF EXISTS (SELECT 1 FROM METER WHERE TransformerID = @ParentTransformerID)
            THROW 53506, N'Ο γονέας έχει μετρητές: μετρητές μπαίνουν μόνο σε φύλλα, άρα δεν παίρνει παιδιά.', 1;
        IF NOT EXISTS (SELECT 1 FROM TRANSFORMER p JOIN GEOFENCE pg ON pg.GeofenceID = p.GeofenceID
                       WHERE p.TransformerID = @ParentTransformerID
                         AND @MinLat >= pg.MinLat AND @MaxLat <= pg.MaxLat
                         AND @MinLon >= pg.MinLon AND @MaxLon <= pg.MaxLon)
            THROW 53507, N'Ο γεωφράκτης του παιδιού πρέπει να είναι εντός του γεωφράκτη του γονέα.', 1;
    END

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @GeofenceID INT, @TransformerID INT;
        INSERT GEOFENCE (Name, MinLat, MinLon, MaxLat, MaxLon) VALUES (@GeofenceName, @MinLat, @MinLon, @MaxLat, @MaxLon);
        SET @GeofenceID = SCOPE_IDENTITY();
        INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID, ParentTransformerID)
        VALUES (@Name, @Latitude, @Longitude, @GeofenceID, @ParentTransformerID);
        SET @TransformerID = SCOPE_IDENTITY();
        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('TRANSFORMER', CAST(@TransformerID AS VARCHAR(20)), 'Create', NULL,
                N'Parent=' + ISNULL(CAST(@ParentTransformerID AS NVARCHAR(20)), N'ρίζα') + N'; GeofenceID=' + CAST(@GeofenceID AS NVARCHAR(20)),
                @UserID);
        COMMIT;
        SELECT @TransformerID AS TransformerID, @GeofenceID AS GeofenceID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Το δέντρο από τη ρίζα (ή από έναν κόμβο @RootID). Level: ρίζα = 0.
-- Path: ονόματα από τη ρίζα (π.χ. T-ROOT > T-NIC > T-NIC-AGL). Η σειρά είναι κατά βάθος (SortKey με IDs).
-- DirectMeters: μετρητές πάνω στον κόμβο. TotalMeters: σε όλο το υποδέντρο (όλες οι καταστάσεις μετρητών).
-- Το TotalMeters υπολογίζεται σε ξεχωριστό βήμα (το αναδρομικό μέρος του CTE δεν δέχεται aggregates).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_tree
    @UserID INT, @RootID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    IF @RootID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @RootID)
        THROW 53509, N'Ο μετασχηματιστής δεν υπάρχει στο δέντρο.', 1;

    -- Βήμα 1: ζεύγη (πρόγονος, απόγονος) για όλο το δέντρο, ο κάθε κόμβος και με τον εαυτό του.
    DECLARE @Closure TABLE (AncestorID INT NOT NULL, DescendantID INT NOT NULL);
    WITH down AS (
        SELECT t.TransformerID AS AncestorID, t.TransformerID AS DescendantID, 0 AS Depth FROM TRANSFORMER t
        UNION ALL
        SELECT d.AncestorID, c.TransformerID, d.Depth + 1
        FROM down d JOIN TRANSFORMER c ON c.ParentTransformerID = d.DescendantID
        WHERE d.Depth < 100
    )
    INSERT @Closure (AncestorID, DescendantID)
    SELECT AncestorID, DescendantID FROM down OPTION (MAXRECURSION 100);

    -- Βήμα 2: μετρητές ανά πρόγονο.
    DECLARE @Totals TABLE (TransformerID INT PRIMARY KEY, TotalMeters INT NOT NULL);
    INSERT @Totals (TransformerID, TotalMeters)
    SELECT c.AncestorID, COUNT(m.MeterID)
    FROM @Closure c LEFT JOIN METER m ON m.TransformerID = c.DescendantID
    GROUP BY c.AncestorID;

    -- Βήμα 3: το δέντρο με Level και Path.
    WITH tree AS (
        SELECT t.TransformerID, t.Name, t.ParentTransformerID, t.GeofenceID,
               0 AS Level,
               CAST(t.Name AS NVARCHAR(4000)) AS Path,
               CONVERT(VARCHAR(1000), RIGHT('000000' + CAST(t.TransformerID AS VARCHAR(10)), 7)) AS SortKey
        FROM TRANSFORMER t
        WHERE (@RootID IS NULL AND t.ParentTransformerID IS NULL) OR t.TransformerID = @RootID
        UNION ALL
        SELECT c.TransformerID, c.Name, c.ParentTransformerID, c.GeofenceID,
               tr.Level + 1,
               CAST(tr.Path + N' > ' + c.Name AS NVARCHAR(4000)),
               CONVERT(VARCHAR(1000), tr.SortKey + RIGHT('000000' + CAST(c.TransformerID AS VARCHAR(10)), 7))
        FROM tree tr JOIN TRANSFORMER c ON c.ParentTransformerID = tr.TransformerID
        WHERE tr.Level < 100
    )
    SELECT tr.TransformerID, tr.Name, tr.ParentTransformerID, tr.Level, tr.Path,
           CAST(CASE WHEN EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = tr.TransformerID) THEN 0 ELSE 1 END AS BIT) AS IsLeaf,
           (SELECT COUNT(*) FROM METER m WHERE m.TransformerID = tr.TransformerID) AS DirectMeters,
           tt.TotalMeters,
           g.GeofenceID, g.Name AS GeofenceName, g.MinLat, g.MinLon, g.MaxLat, g.MaxLon
    FROM tree tr
    JOIN @Totals tt ON tt.TransformerID = tr.TransformerID
    JOIN GEOFENCE g ON g.GeofenceID = tr.GeofenceID
    ORDER BY tr.SortKey
    OPTION (MAXRECURSION 100);
END;
GO

-- ---------------------------------------------------------------------
-- Από συντεταγμένες στο φύλλο-μετασχηματιστή. Τα όρια του ορθογωνίου είναι ΣΥΜΠΕΡΙΛΑΜΒΑΝΟΜΕΝΑ.
-- Μόνο φύλλα (μετρητές μόνο σε φύλλα). Αν το σημείο πέφτει σε πολλά φύλλα (γειτονικά ορθογώνια που
-- αγγίζουν ή επικαλύπτονται) επιστρέφονται όλα, με το μικρότερο εμβαδόν πρώτο (πρώτη γραμμή = η καλύτερη).
-- Κανένα φύλλο => 0 γραμμές (π.χ. σημείο εκτός Κύπρου). Path = από τη ρίζα μέχρι το φύλλο.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_locate
    @UserID INT, @Latitude DECIMAL(9,6), @Longitude DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    IF @Latitude IS NULL OR @Longitude IS NULL OR @Latitude NOT BETWEEN -90 AND 90 OR @Longitude NOT BETWEEN -180 AND 180
        THROW 53508, N'Μη έγκυρες συντεταγμένες.', 1;

    WITH hits AS (
        SELECT t.TransformerID, t.Name, g.GeofenceID, g.Name AS GeofenceName, g.MinLat, g.MinLon, g.MaxLat, g.MaxLon,
               CAST((g.MaxLat - g.MinLat) * (g.MaxLon - g.MinLon) AS DECIMAL(18,8)) AS AreaDeg2
        FROM TRANSFORMER t JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
        WHERE @Latitude BETWEEN g.MinLat AND g.MaxLat AND @Longitude BETWEEN g.MinLon AND g.MaxLon
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID)
    ),
    up AS (
        SELECT h.TransformerID AS LeafID, t.ParentTransformerID AS Cur, CAST(t.Name AS NVARCHAR(4000)) AS Path, 0 AS Depth
        FROM hits h JOIN TRANSFORMER t ON t.TransformerID = h.TransformerID
        UNION ALL
        SELECT up.LeafID, p.ParentTransformerID, CAST(p.Name + N' > ' + up.Path AS NVARCHAR(4000)), up.Depth + 1
        FROM up JOIN TRANSFORMER p ON p.TransformerID = up.Cur
        WHERE up.Depth < 100
    )
    SELECT h.TransformerID, h.Name, h.GeofenceID, h.GeofenceName, h.MinLat, h.MinLon, h.MaxLat, h.MaxLon, h.AreaDeg2, up.Path
    FROM hits h JOIN up ON up.LeafID = h.TransformerID AND up.Cur IS NULL
    ORDER BY h.AreaDeg2, h.TransformerID
    OPTION (MAXRECURSION 100);
END;
GO

-- ---------------------------------------------------------------------
-- Έλεγχος θέσης μετρητών: για κάθε μετρητή, ο μετασχηματιστής που έχει καταχωρηθεί
-- έναντι του φύλλου που βρίσκεται από τις συντεταγμένες του.
-- Result: OK (ίδιο), Mismatch (άλλο φύλλο), NoGeofence (καμία περιοχή δεν τον περιέχει).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_check_meter_locations
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    SELECT m.MeterID, m.SerialNumber, m.Status, m.Latitude, m.Longitude,
           m.TransformerID, rt.Name AS TransformerName,
           f.TransformerID AS FoundTransformerID, f.Name AS FoundTransformerName,
           CASE WHEN f.TransformerID IS NULL THEN 'NoGeofence'
                WHEN f.TransformerID = m.TransformerID THEN 'OK'
                ELSE 'Mismatch' END AS Result
    FROM METER m
    JOIN TRANSFORMER rt ON rt.TransformerID = m.TransformerID
    OUTER APPLY (
        SELECT TOP 1 t.TransformerID, t.Name
        FROM TRANSFORMER t JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
        WHERE m.Latitude BETWEEN g.MinLat AND g.MaxLat AND m.Longitude BETWEEN g.MinLon AND g.MaxLon
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID)
        ORDER BY (g.MaxLat - g.MinLat) * (g.MaxLon - g.MinLon), t.TransformerID
    ) f
    ORDER BY m.MeterID;
END;
GO

-- =====================================================================
-- TSO-2: ΤΡΕΧΟΥΣΑ ΚΑΤΑΣΤΑΣΗ
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ανανέωση (κουμπί, όχι scheduler). Κοινό διάστημα αναφοράς: το ΤΕΛΕΥΤΑΙΟ IntervalStart που έχει
-- επικυρωμένη μέτρηση 1.8.0 ή 2.8.0 (MAX του VALIDATED_READING για τους δύο κωδικούς).
-- 1) Για κάθε ΦΥΛΛΟ και κάθε κωδικό: SUM(Value) των μετρητών του στο διάστημα αυτό και πόσοι μετρητές συνεισέφεραν
--    (Value = ενέργεια 15λέπτου, απόφαση B2). Όσοι μετρητές δεν έχουν μέτρηση απλώς δεν μετράνε.
-- 2) Για ΚΑΘΕ κόμβο του δέντρου (φύλλα ΚΑΙ όλοι οι πρόγονοι, απόφαση B16 / spec III.4.2): το άθροισμα των φύλλων
--    από κάτω του, σε οποιοδήποτε βάθος (αναδρομικό CTE: ζεύγη πρόγονος-απόγονος).
-- Κόμβος χωρίς καμία μέτρηση παίρνει γραμμή με SumValue 0 και MeterCount 0 (ώστε η σελίδα να δείχνει όλο το δέντρο).
-- Ένα MERGE για όλους τους κόμβους στην ίδια συναλλαγή: όταν αλλάζει ένα φύλλο, ενημερώνονται μαζί και όλοι οι πρόγονοί του.
-- Μία συναλλαγή + μία γραμμή AUDIT_LOG. Επιστρέφει: RefInterval, LeafCount, RowsAffected.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_refresh_current_state
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tso_assert @UserID;

    DECLARE @Ref DATETIME2(0) =
        (SELECT MAX(IntervalStart) FROM VALIDATED_READING WHERE ObisCode IN ('1.8.0', '2.8.0'));
    IF @Ref IS NULL
        THROW 53600, N'Δεν υπάρχουν επικυρωμένες μετρήσεις 1.8.0/2.8.0 για υπολογισμό.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Leaf TABLE (TransformerID INT NOT NULL, ObisCode VARCHAR(20) NOT NULL,
                             SumValue DECIMAL(18,4) NOT NULL, MeterCount INT NOT NULL,
                             PRIMARY KEY (TransformerID, ObisCode));
        INSERT @Leaf (TransformerID, ObisCode, SumValue, MeterCount)
        SELECT l.TransformerID, c.ObisCode,
               CAST(ISNULL(SUM(vr.Value), 0) AS DECIMAL(18,4)),
               COUNT(DISTINCT vr.MeterID)
        FROM TRANSFORMER l
        CROSS JOIN (VALUES ('1.8.0'), ('2.8.0')) AS c (ObisCode)
        LEFT JOIN METER m ON m.TransformerID = l.TransformerID
        LEFT JOIN VALIDATED_READING vr ON vr.MeterID = m.MeterID AND vr.ObisCode = c.ObisCode AND vr.IntervalStart = @Ref
        WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = l.TransformerID)
        GROUP BY l.TransformerID, c.ObisCode;

        DECLARE @Leaves INT = (SELECT COUNT(DISTINCT TransformerID) FROM @Leaf), @Rows INT;

        -- Ζεύγη (πρόγονος, απόγονος), μαζί με τον ίδιο τον κόμβο, για δέντρο οποιουδήποτε βάθους.
        DECLARE @Closure TABLE (AncestorID INT NOT NULL, DescendantID INT NOT NULL);
        WITH down AS (
            SELECT t.TransformerID AS AncestorID, t.TransformerID AS DescendantID, 0 AS Depth FROM TRANSFORMER t
            UNION ALL
            SELECT d.AncestorID, c.TransformerID, d.Depth + 1
            FROM down d JOIN TRANSFORMER c ON c.ParentTransformerID = d.DescendantID
            WHERE d.Depth < 100
        )
        INSERT @Closure (AncestorID, DescendantID)
        SELECT AncestorID, DescendantID FROM down OPTION (MAXRECURSION 100);

        -- Κάθε κόμβος = άθροισμα των φύλλων του υποδέντρου του (ένα φύλλο = ο εαυτός του).
        DECLARE @Src TABLE (TransformerID INT NOT NULL, ObisCode VARCHAR(20) NOT NULL,
                            SumValue DECIMAL(18,4) NOT NULL, MeterCount INT NOT NULL,
                            PRIMARY KEY (TransformerID, ObisCode));
        INSERT @Src (TransformerID, ObisCode, SumValue, MeterCount)
        SELECT c.AncestorID, k.ObisCode,
               CAST(ISNULL(SUM(l.SumValue), 0) AS DECIMAL(18,4)), ISNULL(SUM(l.MeterCount), 0)
        FROM @Closure c
        CROSS JOIN (VALUES ('1.8.0'), ('2.8.0')) AS k (ObisCode)
        LEFT JOIN @Leaf l ON l.TransformerID = c.DescendantID AND l.ObisCode = k.ObisCode
        GROUP BY c.AncestorID, k.ObisCode;

        MERGE TRANSFORMER_CURRENT_STATE AS t
        USING @Src AS s ON t.TransformerID = s.TransformerID AND t.ObisCode = s.ObisCode
        WHEN MATCHED THEN
            UPDATE SET RefInterval = @Ref, SumValue = s.SumValue, MeterCount = s.MeterCount, ComputedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (TransformerID, ObisCode, RefInterval, SumValue, MeterCount, ComputedAt)
            VALUES (s.TransformerID, s.ObisCode, @Ref, s.SumValue, s.MeterCount, SYSUTCDATETIME())
        WHEN NOT MATCHED BY SOURCE THEN
            DELETE;
        SET @Rows = @@ROWCOUNT;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('TRANSFORMER_CURRENT_STATE', 'all', 'Refresh', NULL,
                N'RefInterval=' + CONVERT(NVARCHAR(19), @Ref, 120) + N'; Leaves=' + CAST(@Leaves AS NVARCHAR(20))
                + N'; Rows=' + CAST(@Rows AS NVARCHAR(20)), @UserID);
        COMMIT;
        SELECT @Ref AS RefInterval, @Leaves AS LeafCount, @Rows AS RowsAffected;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Τρέχουσα κατάσταση ανά κόμβο: για κάθε κόμβο (ή τον @TransformerID και το υποδέντρο του) η αποθηκευμένη
-- γραμμή του ενδιάμεσου πίνακα TRANSFORMER_CURRENT_STATE (η ανανέωση γράφει φύλλα ΚΑΙ προγόνους, B16).
-- Μόνο ανάγνωση, κανένας επανυπολογισμός. Κόμβος που προστέθηκε μετά την τελευταία ανανέωση δείχνει 0.
-- Level: 0 για τη ρίζα (ή για τον κόμβο που ζητήθηκε). ImportKWh = 1.8.0, ExportKWh = 2.8.0, NetKWh = Import - Export.
-- MeterCount = μετρητές που συνεισέφεραν στο 1.8.0. RefInterval = το πιο πρόσφατο διάστημα των φύλλων (NULL αν δεν έγινε ανανέωση).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_current_state
    @UserID INT, @TransformerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    IF @TransformerID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @TransformerID)
        THROW 53601, N'Ο μετασχηματιστής δεν υπάρχει στο δέντρο.', 1;

    DECLARE @Sums TABLE (TransformerID INT PRIMARY KEY, RefInterval DATETIME2(0) NULL,
                         ImportKWh DECIMAL(18,4) NOT NULL, ExportKWh DECIMAL(18,4) NOT NULL, MeterCount INT NOT NULL);
    INSERT @Sums (TransformerID, RefInterval, ImportKWh, ExportKWh, MeterCount)
    SELECT t.TransformerID, MAX(cs.RefInterval),
           CAST(ISNULL(SUM(CASE WHEN cs.ObisCode = '1.8.0' THEN cs.SumValue END), 0) AS DECIMAL(18,4)),
           CAST(ISNULL(SUM(CASE WHEN cs.ObisCode = '2.8.0' THEN cs.SumValue END), 0) AS DECIMAL(18,4)),
           ISNULL(SUM(CASE WHEN cs.ObisCode = '1.8.0' THEN cs.MeterCount END), 0)
    FROM TRANSFORMER t
    LEFT JOIN TRANSFORMER_CURRENT_STATE cs ON cs.TransformerID = t.TransformerID
    GROUP BY t.TransformerID;

    WITH tree AS (
        SELECT t.TransformerID, t.Name, 0 AS Level,
               CAST(t.Name AS NVARCHAR(4000)) AS Path,
               CONVERT(VARCHAR(1000), RIGHT('000000' + CAST(t.TransformerID AS VARCHAR(10)), 7)) AS SortKey
        FROM TRANSFORMER t
        WHERE (@TransformerID IS NULL AND t.ParentTransformerID IS NULL) OR t.TransformerID = @TransformerID
        UNION ALL
        SELECT c.TransformerID, c.Name, tr.Level + 1,
               CAST(tr.Path + N' > ' + c.Name AS NVARCHAR(4000)),
               CONVERT(VARCHAR(1000), tr.SortKey + RIGHT('000000' + CAST(c.TransformerID AS VARCHAR(10)), 7))
        FROM tree tr JOIN TRANSFORMER c ON c.ParentTransformerID = tr.TransformerID
        WHERE tr.Level < 100
    )
    SELECT tr.TransformerID, tr.Name, tr.Level, tr.Path, s.RefInterval,
           s.ImportKWh, s.ExportKWh, CAST(s.ImportKWh - s.ExportKWh AS DECIMAL(18,4)) AS NetKWh, s.MeterCount
    FROM tree tr
    JOIN @Sums s ON s.TransformerID = tr.TransformerID
    ORDER BY tr.SortKey
    OPTION (MAXRECURSION 100);
END;
GO

-- =====================================================================
-- TSO-3: AGGREGATES ΣΕ ΟΠΟΙΟΔΗΠΟΤΕ ΕΠΙΠΕΔΟ
-- =====================================================================

-- ---------------------------------------------------------------------
-- Aggregates ενός κόμβου και του υποδέντρου του, ανά περίοδο. Διαβάζει ΜΟΝΟ τις αποθηκευμένες γραμμές των ΦΥΛΛΩΝ
-- (TRANSFORMER_AGGREGATE, κωδικοί 1.8.0 και 2.8.0) και τις αθροίζει. ΔΕΝ γράφει ποτέ στον πίνακα (αυτό είναι δουλειά του DSO-4).
-- @PeriodType: 'Day', 'Month', 'Quarter', 'Year'. Το @From/@To είναι ημερομηνίες (συμπεριλαμβανόμενες).
-- Επιλογή roll-up:
--   Day     : οι γραμμές Day των φύλλων με PeriodStart μέσα στο [@From, @To].
--   Month / Quarter / Year : βάση είναι ο ΜΗΝΑΣ ανά φύλλο και κωδικό. Αν υπάρχει αποθηκευμένη γραμμή Month, χρησιμοποιείται αυτή,
--     αλλιώς οι γραμμές Day του μήνα αθροίζονται (ώστε να μη μετρηθεί τίποτα δύο φορές). Μετά ο μήνας μπαίνει στο τρίμηνο/έτος του,
--     με τρίμηνο = DATEFROMPARTS(YEAR, (DATEPART(QUARTER)-1)*3+1, 1). Οι αποθηκευμένες γραμμές Year δεν χρησιμοποιούνται.
--   Οι περίοδοι είναι ΟΛΟΚΛΗΡΕΣ: το διάστημα επεκτείνεται στην αρχή της περιόδου του @From και στο τέλος της περιόδου του @To.
-- Επιστρέφει: PeriodStart, ImportKWh (1.8.0), ExportKWh (2.8.0), NetKWh, LeafCount (φύλλα με δεδομένα στην περίοδο).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_aggregates
    @UserID INT, @TransformerID INT, @PeriodType VARCHAR(7), @From DATE, @To DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Quarter', 'Year')
        THROW 53610, N'Ο τύπος περιόδου πρέπει να είναι Day, Month, Quarter ή Year.', 1;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 53611, N'Μη έγκυρο διάστημα ημερομηνιών: δώστε από ≤ έως.', 1;
    IF @TransformerID IS NULL OR NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @TransformerID)
        THROW 53612, N'Ο μετασχηματιστής δεν υπάρχει στο δέντρο.', 1;

    -- Όρια [Lo, Hi] σε μέρες, επεκταμένα σε ολόκληρες περιόδους εκτός από το Day.
    DECLARE @Lo DATE, @Hi DATE;
    IF @PeriodType = 'Day'
    BEGIN
        SET @Lo = @From; SET @Hi = @To;
    END
    ELSE IF @PeriodType = 'Month'
    BEGIN
        SET @Lo = DATEFROMPARTS(YEAR(@From), MONTH(@From), 1);
        SET @Hi = EOMONTH(@To);
    END
    ELSE IF @PeriodType = 'Quarter'
    BEGIN
        SET @Lo = DATEFROMPARTS(YEAR(@From), (DATEPART(QUARTER, @From) - 1) * 3 + 1, 1);
        SET @Hi = EOMONTH(DATEFROMPARTS(YEAR(@To), (DATEPART(QUARTER, @To) - 1) * 3 + 3, 1));
    END
    ELSE
    BEGIN
        SET @Lo = DATEFROMPARTS(YEAR(@From), 1, 1);
        SET @Hi = DATEFROMPARTS(YEAR(@To), 12, 31);
    END

    -- Φύλλα κάτω από τον κόμβο (και ο ίδιος ο κόμβος αν είναι φύλλο).
    DECLARE @Leaves TABLE (TransformerID INT PRIMARY KEY);
    WITH down AS (
        SELECT t.TransformerID, 0 AS Depth FROM TRANSFORMER t WHERE t.TransformerID = @TransformerID
        UNION ALL
        SELECT c.TransformerID, d.Depth + 1
        FROM down d JOIN TRANSFORMER c ON c.ParentTransformerID = d.TransformerID
        WHERE d.Depth < 100
    )
    INSERT @Leaves (TransformerID)
    SELECT d.TransformerID FROM down d
    WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = d.TransformerID)
    OPTION (MAXRECURSION 100);

    -- Βάση: μία γραμμή ανά (φύλλο, κωδικός, ημέρα ή μήνας).
    DECLARE @Base TABLE (TransformerID INT NOT NULL, ObisCode VARCHAR(20) NOT NULL, BaseDate DATE NOT NULL, SumValue DECIMAL(18,4) NOT NULL);
    IF @PeriodType = 'Day'
    BEGIN
        INSERT @Base (TransformerID, ObisCode, BaseDate, SumValue)
        SELECT a.TransformerID, a.ObisCode, a.PeriodStart, a.SumValue
        FROM TRANSFORMER_AGGREGATE a JOIN @Leaves l ON l.TransformerID = a.TransformerID
        WHERE a.PeriodType = 'Day' AND a.ObisCode IN ('1.8.0', '2.8.0') AND a.PeriodStart BETWEEN @Lo AND @Hi;
    END
    ELSE
    BEGIN
        INSERT @Base (TransformerID, ObisCode, BaseDate, SumValue)
        SELECT a.TransformerID, a.ObisCode, a.PeriodStart, a.SumValue
        FROM TRANSFORMER_AGGREGATE a JOIN @Leaves l ON l.TransformerID = a.TransformerID
        WHERE a.PeriodType = 'Month' AND a.ObisCode IN ('1.8.0', '2.8.0') AND a.PeriodStart BETWEEN @Lo AND @Hi;

        INSERT @Base (TransformerID, ObisCode, BaseDate, SumValue)
        SELECT a.TransformerID, a.ObisCode, DATEFROMPARTS(YEAR(a.PeriodStart), MONTH(a.PeriodStart), 1), SUM(a.SumValue)
        FROM TRANSFORMER_AGGREGATE a JOIN @Leaves l ON l.TransformerID = a.TransformerID
        WHERE a.PeriodType = 'Day' AND a.ObisCode IN ('1.8.0', '2.8.0') AND a.PeriodStart BETWEEN @Lo AND @Hi
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE mo
                          WHERE mo.TransformerID = a.TransformerID AND mo.ObisCode = a.ObisCode AND mo.PeriodType = 'Month'
                            AND mo.PeriodStart = DATEFROMPARTS(YEAR(a.PeriodStart), MONTH(a.PeriodStart), 1))
        GROUP BY a.TransformerID, a.ObisCode, DATEFROMPARTS(YEAR(a.PeriodStart), MONTH(a.PeriodStart), 1);
    END

    SELECT x.PeriodStart,
           CAST(ISNULL(SUM(CASE WHEN x.ObisCode = '1.8.0' THEN x.SumValue END), 0) AS DECIMAL(18,4)) AS ImportKWh,
           CAST(ISNULL(SUM(CASE WHEN x.ObisCode = '2.8.0' THEN x.SumValue END), 0) AS DECIMAL(18,4)) AS ExportKWh,
           CAST(ISNULL(SUM(CASE WHEN x.ObisCode = '1.8.0' THEN x.SumValue END), 0)
              - ISNULL(SUM(CASE WHEN x.ObisCode = '2.8.0' THEN x.SumValue END), 0) AS DECIMAL(18,4)) AS NetKWh,
           COUNT(DISTINCT x.TransformerID) AS LeafCount
    FROM (
        SELECT b.TransformerID, b.ObisCode, b.SumValue,
               CASE @PeriodType
                    WHEN 'Day'     THEN b.BaseDate
                    WHEN 'Month'   THEN b.BaseDate
                    WHEN 'Quarter' THEN DATEFROMPARTS(YEAR(b.BaseDate), (DATEPART(QUARTER, b.BaseDate) - 1) * 3 + 1, 1)
                    ELSE DATEFROMPARTS(YEAR(b.BaseDate), 1, 1) END AS PeriodStart
        FROM @Base b
    ) x
    GROUP BY x.PeriodStart
    ORDER BY x.PeriodStart;
END;
GO

-- =====================================================================
-- TSO-4: LOAD SHEDDING
-- =====================================================================

-- ---------------------------------------------------------------------
-- Εντολή αποκοπής φορτίου σε ΟΛΟΥΣ τους Active μετρητές κάτω από έναν μετασχηματιστή (σε όλα τα φύλλα του υποδέντρου).
-- Μία συναλλαγή: LOAD_SHED_ORDER (Status 'Issued', OrderedBy) + μία REMOTE_COMMAND ανά μετρητή
-- (CommandType 'Load shed', Status 'Sent', ShedOrderID, RequestedBy = @UserID: συμφωνία X3) + AUDIT_LOG.
-- Parameters = {"shedOrderID": n} (έγκυρο JSON). Αν δεν υπάρχει κανένας ενεργός μετρητής: απορρίπτεται, δεν μένει εντολή.
-- Μετρητές 'Pending confirmation' και 'Retired' δεν παίρνουν εντολή.
-- Επιστρέφει: ShedOrderID, CommandCount.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_load_shed
    @UserID INT, @TransformerID INT, @Reason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_tso_assert @UserID;
    IF @Reason IS NULL OR LEN(LTRIM(RTRIM(@Reason))) = 0
        THROW 53620, N'Δώστε αιτιολογία για την αποκοπή φορτίου.', 1;
    IF @TransformerID IS NULL OR NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @TransformerID)
        THROW 53621, N'Ο μετασχηματιστής δεν υπάρχει στο δέντρο.', 1;

    DECLARE @Meters TABLE (MeterID INT PRIMARY KEY);
    WITH down AS (
        SELECT t.TransformerID, 0 AS Depth FROM TRANSFORMER t WHERE t.TransformerID = @TransformerID
        UNION ALL
        SELECT c.TransformerID, d.Depth + 1
        FROM down d JOIN TRANSFORMER c ON c.ParentTransformerID = d.TransformerID
        WHERE d.Depth < 100
    )
    INSERT @Meters (MeterID)
    SELECT m.MeterID
    FROM down d
    JOIN METER m ON m.TransformerID = d.TransformerID AND m.Status = 'Active'
    WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = d.TransformerID)
    OPTION (MAXRECURSION 100);

    DECLARE @Count INT = (SELECT COUNT(*) FROM @Meters);
    IF @Count = 0
        THROW 53622, N'Δεν υπάρχει κανένας ενεργός μετρητής κάτω από αυτόν τον μετασχηματιστή.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @OrderID INT;
        INSERT LOAD_SHED_ORDER (Reason, Status, TransformerID, OrderedBy)
        VALUES (LTRIM(RTRIM(@Reason)), 'Issued', @TransformerID, @UserID);
        SET @OrderID = SCOPE_IDENTITY();

        INSERT REMOTE_COMMAND (CommandType, Parameters, Status, MeterID, RequestedBy, ShedOrderID)
        SELECT 'Load shed', N'{"shedOrderID":' + CAST(@OrderID AS NVARCHAR(20)) + N'}', 'Sent', m.MeterID, @UserID, @OrderID
        FROM @Meters m;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, PerformedBy)
        VALUES ('LOAD_SHED_ORDER', CAST(@OrderID AS VARCHAR(20)), 'Create', NULL,
                N'Transformer=' + CAST(@TransformerID AS NVARCHAR(20)) + N'; Commands=' + CAST(@Count AS NVARCHAR(20)), @UserID);
        COMMIT;
        SELECT @OrderID AS ShedOrderID, @Count AS CommandCount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Λίστα εντολών αποκοπής (νεότερες πρώτα) με όνομα μετασχηματιστή και πλήθος εντολών ανά κατάσταση.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_list_shed_orders
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_tso_assert @UserID;
    SELECT o.ShedOrderID, o.CreatedAt, o.Status, o.Reason, o.TransformerID, t.Name AS TransformerName,
           u.Username AS OrderedByName,
           COUNT(rc.CommandID) AS Commands,
           ISNULL(SUM(CASE WHEN rc.Status = 'Awaiting approval' THEN 1 END), 0) AS AwaitingApproval,
           ISNULL(SUM(CASE WHEN rc.Status = 'Sent' THEN 1 END), 0) AS Sent,
           ISNULL(SUM(CASE WHEN rc.Status = 'Acknowledged' THEN 1 END), 0) AS Acknowledged,
           ISNULL(SUM(CASE WHEN rc.Status = 'Failed' THEN 1 END), 0) AS Failed,
           ISNULL(SUM(CASE WHEN rc.Status = 'Cancelled' THEN 1 END), 0) AS Cancelled
    FROM LOAD_SHED_ORDER o
    JOIN TRANSFORMER t ON t.TransformerID = o.TransformerID
    JOIN USER_ACCOUNT u ON u.UserID = o.OrderedBy
    LEFT JOIN REMOTE_COMMAND rc ON rc.ShedOrderID = o.ShedOrderID
    GROUP BY o.ShedOrderID, o.CreatedAt, o.Status, o.Reason, o.TransformerID, t.Name, u.Username
    ORDER BY o.ShedOrderID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- TSO-6 (bonus): δεδομένα για τον χάρτη Leaflet, ΕΝΑ result set (το call_proc διαβάζει μόνο το πρώτο).
-- Στήλη Kind: 'Transformer' (μία γραμμή ανά μετασχηματιστή) ή 'Meter' (μία ανά μετρητή).
-- Στήλες που δεν ταιριάζουν στο είδος είναι NULL. Μόνο ανάγνωση.
-- Ρόλοι: ενεργός TSO, DSO ή Operator (οι DSO/Operator βλέπουν το ίδιο δίκτυο, δεν αλλάζει τίποτα).
-- ImportKWh/ExportKWh: η αποθηκευμένη γραμμή 1.8.0/2.8.0 του κόμβου στο TRANSFORMER_CURRENT_STATE (ήδη άθροισμα του υποδέντρου).
-- Λάθος: 53800 ο χρήστης δεν είναι ενεργός TSO/DSO/Operator.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_tso_map_data
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role IN ('TSO', 'DSO', 'Operator') AND AccountStatus = 'Active')
        THROW 53800, N'Δεν επιτρέπεται: ο χάρτης είναι μόνο για ενεργό TSO, DSO ή Operator.', 1;

    DECLARE @Sums TABLE (TransformerID INT PRIMARY KEY, ImportKWh DECIMAL(18,4) NOT NULL, ExportKWh DECIMAL(18,4) NOT NULL);
    INSERT @Sums (TransformerID, ImportKWh, ExportKWh)
    SELECT t.TransformerID,
           CAST(ISNULL(SUM(CASE WHEN cs.ObisCode = '1.8.0' THEN cs.SumValue END), 0) AS DECIMAL(18,4)),
           CAST(ISNULL(SUM(CASE WHEN cs.ObisCode = '2.8.0' THEN cs.SumValue END), 0) AS DECIMAL(18,4))
    FROM TRANSFORMER t
    LEFT JOIN TRANSFORMER_CURRENT_STATE cs ON cs.TransformerID = t.TransformerID
    GROUP BY t.TransformerID;

    WITH tree AS (
        SELECT t.TransformerID, 0 AS Level FROM TRANSFORMER t WHERE t.ParentTransformerID IS NULL
        UNION ALL
        SELECT c.TransformerID, tr.Level + 1 FROM tree tr JOIN TRANSFORMER c ON c.ParentTransformerID = tr.TransformerID
        WHERE tr.Level < 100
    )
    SELECT CAST('Transformer' AS VARCHAR(12)) AS Kind,
           t.TransformerID AS Id, t.Name AS Name, CAST(NULL AS VARCHAR(40)) AS SerialNumber,
           t.Latitude AS Latitude, t.Longitude AS Longitude,
           t.ParentTransformerID AS ParentId, tree.Level AS Level,
           CAST(CASE WHEN EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID) THEN 0 ELSE 1 END AS BIT) AS IsLeaf,
           g.MinLat AS MinLat, g.MinLon AS MinLon, g.MaxLat AS MaxLat, g.MaxLon AS MaxLon,
           s.ImportKWh AS ImportKWh, s.ExportKWh AS ExportKWh,
           CAST(NULL AS VARCHAR(20)) AS Status, CAST(NULL AS INT) AS TransformerID
    FROM TRANSFORMER t
    JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
    JOIN tree ON tree.TransformerID = t.TransformerID
    LEFT JOIN @Sums s ON s.TransformerID = t.TransformerID
    UNION ALL
    SELECT 'Meter', m.MeterID, NULL, m.SerialNumber, m.Latitude, m.Longitude,
           NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
           m.Status, m.TransformerID
    FROM METER m
    ORDER BY Kind DESC, Id
    OPTION (MAXRECURSION 100);
END;
GO
