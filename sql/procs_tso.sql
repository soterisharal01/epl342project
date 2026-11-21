-- =====================================================================
-- procs_tso.sql : ΙΙΙ.4 Δέντρο μετασχηματιστών (περιοχή TSO)
--   TSO-1 νέος μετασχηματιστής + γεωφράκτης, δέντρο (αναδρομικό CTE), εύρεση φύλλου από συντεταγμένες
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
