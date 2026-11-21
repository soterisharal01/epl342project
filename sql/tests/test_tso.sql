-- =====================================================================
-- test_tso.sql : έλεγχοι για το procs_tso.sql (TSO-1).
-- Πάνω στα κοινά δεδομένα: tso1 = UserID 8, operator = UserID 2.
-- Δέντρο βάσης: 1 ρίζα, 2 και 3 κάτω από αυτήν, φύλλα 4, 5 (κάτω από 2) και 6 (κάτω από 3).
-- Μετρητές: 1 και 4 στον 4, 2 στον 5, 3 και 5 στον 6.
-- Οι δοκιμαστικοί μετασχηματιστές T-TEST-* μένουν στη βάση: μπαίνουν ως φύλλα κάτω από τον 3 (Λεμεσός),
-- σε χώρο που δεν περιέχει κανέναν μετρητή, ώστε να μη χαλάσουν τα πλήθη των άλλων ελέγχων.
-- Κάθε γραμμή τυπώνει OK ή FAIL.
-- =====================================================================
SET NOCOUNT ON;
DECLARE @n INT;

-- ---------- Έλεγχος ρόλου (και τα τέσσερα procedures) ----------
BEGIN TRY EXEC sp_tso_tree 2; PRINT 'FAIL operator saw the tree'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   tree: non-TSO -> 53500' ELSE PRINT 'FAIL tree role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_locate 2, 35.145, 33.39; PRINT 'FAIL operator located'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   locate: non-TSO -> 53500' ELSE PRINT 'FAIL locate role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_check_meter_locations 2; PRINT 'FAIL operator checked meters'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   check meters: non-TSO -> 53500' ELSE PRINT 'FAIL check role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 2, N'T-TEST-ROLE', 34.71, 33.06, 3, N'T-TEST geofence', 34.70, 33.05, 34.72, 33.07; PRINT 'FAIL operator added a transformer'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   add: non-TSO -> 53500' ELSE PRINT 'FAIL add role: ' + ERROR_MESSAGE(); END CATCH;
IF NOT EXISTS (SELECT 1 FROM TRANSFORMER WHERE Name = N'T-TEST-ROLE') PRINT 'OK   add: refused role wrote nothing' ELSE PRINT 'FAIL add: row written despite refusal';

-- ---------- sp_tso_add_transformer: επιτυχία ----------
DECLARE @cnt_t0 INT = (SELECT COUNT(*) FROM TRANSFORMER), @cnt_g0 INT = (SELECT COUNT(*) FROM GEOFENCE);
DECLARE @a TABLE (TransformerID INT, GeofenceID INT);
INSERT @a EXEC sp_tso_add_transformer 8, N'T-TEST-LIM-A', 34.71, 33.06, 3, N'T-TEST Λεμεσός A', 34.70, 33.05, 34.72, 33.07;
DECLARE @newt INT = (SELECT TransformerID FROM @a), @newg INT = (SELECT GeofenceID FROM @a);
IF @newt IS NOT NULL AND @newg IS NOT NULL
   AND EXISTS (SELECT 1 FROM TRANSFORMER WHERE TransformerID = @newt AND GeofenceID = @newg AND ParentTransformerID = 3 AND Name = N'T-TEST-LIM-A')
   AND EXISTS (SELECT 1 FROM GEOFENCE WHERE GeofenceID = @newg AND MinLat = 34.70 AND MaxLon = 33.07)
   AND (SELECT COUNT(*) FROM TRANSFORMER) = @cnt_t0 + 1 AND (SELECT COUNT(*) FROM GEOFENCE) = @cnt_g0 + 1
    PRINT 'OK   add transformer -> TRANSFORMER + GEOFENCE (ids returned)' ELSE PRINT 'FAIL add transformer';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'TRANSFORMER' AND ObjectID = CAST(@newt AS VARCHAR(20)) AND Action = 'Create' AND PerformedBy = 8)
    PRINT 'OK   add transformer -> AUDIT_LOG' ELSE PRINT 'FAIL add transformer audit';

-- ---------- sp_tso_add_transformer: απορρίψεις (το καθένα δεν γράφει τίποτα) ----------
SET @cnt_t0 = (SELECT COUNT(*) FROM TRANSFORMER);
SET @cnt_g0 = (SELECT COUNT(*) FROM GEOFENCE);
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD1', 34.71, 33.06, 3, N'T-TEST bad', 34.72, 33.05, 34.70, 33.07; PRINT 'FAIL inverted rectangle accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53502 PRINT 'OK   inverted rectangle -> 53502' ELSE PRINT 'FAIL rectangle: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD2', 34.71, 33.06, 3, N'T-TEST bad', 34.70, 33.07, 34.72, 33.07; PRINT 'FAIL zero-width rectangle accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53502 PRINT 'OK   zero-width rectangle -> 53502' ELSE PRINT 'FAIL zero width: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD3', 34.75, 33.06, 3, N'T-TEST bad', 34.70, 33.05, 34.72, 33.07; PRINT 'FAIL point outside own geofence accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53503 PRINT 'OK   point outside own geofence -> 53503' ELSE PRINT 'FAIL point outside: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD4', 35.145, 33.39, 4, N'T-TEST bad', 35.14, 33.38, 35.15, 33.40; PRINT 'FAIL child under a parent with meters accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53506 PRINT 'OK   parent with meters -> 53506' ELSE PRINT 'FAIL parent meters: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD5', 34.71, 33.06, 9999, N'T-TEST bad', 34.70, 33.05, 34.72, 33.07; PRINT 'FAIL missing parent accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53504 PRINT 'OK   missing parent -> 53504' ELSE PRINT 'FAIL missing parent: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD6', 34.71, 33.06, NULL, N'T-TEST bad', 34.70, 33.05, 34.72, 33.07; PRINT 'FAIL second root accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53505 PRINT 'OK   second root -> 53505' ELSE PRINT 'FAIL second root: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'T-TEST-BAD7', 36.0, 33.06, 3, N'T-TEST bad', 35.9, 33.0, 36.1, 33.1; PRINT 'FAIL geofence outside parent accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53507 PRINT 'OK   geofence outside parent geofence -> 53507' ELSE PRINT 'FAIL outside parent: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_add_transformer 8, N'   ', 34.71, 33.06, 3, N'T-TEST bad', 34.70, 33.05, 34.72, 33.07; PRINT 'FAIL empty name accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53501 PRINT 'OK   empty name -> 53501' ELSE PRINT 'FAIL empty name: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM TRANSFORMER) = @cnt_t0 AND (SELECT COUNT(*) FROM GEOFENCE) = @cnt_g0
    PRINT 'OK   refused adds wrote nothing' ELSE PRINT 'FAIL refused adds left rows behind';

-- Ο γονέας γίνεται μη-φύλλο: το νέο παιδί δικό του φύλλο, και ο γονέας του δεν παίρνει πια μετρητές (το φράζει το trigger).
DECLARE @b TABLE (TransformerID INT, GeofenceID INT);
INSERT @b EXEC sp_tso_add_transformer 8, N'T-TEST-LIM-A1', 34.705, 33.055, @newt, N'T-TEST Λεμεσός A1', 34.70, 33.05, 34.71, 33.06;
IF EXISTS (SELECT 1 FROM @b WHERE TransformerID IS NOT NULL) PRINT 'OK   add child inside a test geofence (nested)' ELSE PRINT 'FAIL nested add';

-- ---------- sp_tso_tree ----------
DECLARE @tree TABLE (TransformerID INT, Name NVARCHAR(50), ParentTransformerID INT, Level INT, Path NVARCHAR(4000),
                     IsLeaf BIT, DirectMeters INT, TotalMeters INT, GeofenceID INT, GeofenceName NVARCHAR(100),
                     MinLat DECIMAL(9,6), MinLon DECIMAL(9,6), MaxLat DECIMAL(9,6), MaxLon DECIMAL(9,6));
INSERT @tree EXEC sp_tso_tree 8;
IF (SELECT Level FROM @tree WHERE TransformerID = 1) = 0 AND (SELECT Level FROM @tree WHERE TransformerID = 2) = 1
   AND (SELECT Level FROM @tree WHERE TransformerID = 4) = 2 AND (SELECT Level FROM @tree WHERE TransformerID = 6) = 2
    PRINT 'OK   tree levels (root 0, 2 -> 1, leaves 4 and 6 -> 2)' ELSE PRINT 'FAIL tree levels';
IF (SELECT TotalMeters FROM @tree WHERE TransformerID = 1) = 5 AND (SELECT DirectMeters FROM @tree WHERE TransformerID = 1) = 0
    PRINT 'OK   tree: root TotalMeters = 5, DirectMeters = 0' ELSE PRINT 'FAIL tree root totals';
IF (SELECT TotalMeters FROM @tree WHERE TransformerID = 2) = 3 AND (SELECT TotalMeters FROM @tree WHERE TransformerID = 3) = 2
   AND (SELECT DirectMeters FROM @tree WHERE TransformerID = 4) = 2 AND (SELECT DirectMeters FROM @tree WHERE TransformerID = 5) = 1
   AND (SELECT DirectMeters FROM @tree WHERE TransformerID = 6) = 2
    PRINT 'OK   tree: subtree and direct meter counts' ELSE PRINT 'FAIL tree meter counts';
IF (SELECT IsLeaf FROM @tree WHERE TransformerID = 4) = 1 AND (SELECT IsLeaf FROM @tree WHERE TransformerID = 2) = 0
   AND (SELECT IsLeaf FROM @tree WHERE TransformerID = 1) = 0
    PRINT 'OK   tree: IsLeaf' ELSE PRINT 'FAIL tree IsLeaf';
IF (SELECT Path FROM @tree WHERE TransformerID = 4) = N'T-ROOT Κύπρος > T-NIC Λευκωσία > T-NIC-AGL'
    PRINT 'OK   tree: Path of leaf 4' ELSE PRINT 'FAIL tree path';
IF (SELECT TOP 1 TransformerID FROM @tree ORDER BY (SELECT NULL)) IS NOT NULL
   AND (SELECT Level FROM @tree WHERE TransformerID = @newt) = 2 AND (SELECT Level FROM @tree WHERE TransformerID IN (SELECT TransformerID FROM @b)) = 3
    PRINT 'OK   tree includes the added transformers at the right level' ELSE PRINT 'FAIL tree added levels';
IF NOT EXISTS (SELECT 1 FROM @tree WHERE ParentTransformerID IS NULL AND TransformerID <> 1)
   AND (SELECT COUNT(*) FROM @tree WHERE ParentTransformerID IS NULL) = 1
    PRINT 'OK   tree: exactly one root' ELSE PRINT 'FAIL tree roots';

DECLARE @sub TABLE (TransformerID INT, Name NVARCHAR(50), ParentTransformerID INT, Level INT, Path NVARCHAR(4000),
                    IsLeaf BIT, DirectMeters INT, TotalMeters INT, GeofenceID INT, GeofenceName NVARCHAR(100),
                    MinLat DECIMAL(9,6), MinLon DECIMAL(9,6), MaxLat DECIMAL(9,6), MaxLon DECIMAL(9,6));
INSERT @sub EXEC sp_tso_tree 8, 2;
IF (SELECT COUNT(*) FROM @sub) = 3 AND (SELECT Level FROM @sub WHERE TransformerID = 2) = 0
   AND (SELECT TotalMeters FROM @sub WHERE TransformerID = 2) = 3
    PRINT 'OK   tree from node 2: 3 rows, node at level 0, TotalMeters 3' ELSE PRINT 'FAIL subtree';
BEGIN TRY EXEC sp_tso_tree 8, 9999; PRINT 'FAIL tree of a missing node'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53509 PRINT 'OK   tree of missing node -> 53509' ELSE PRINT 'FAIL tree missing: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tso_locate ----------
DECLARE @loc TABLE (TransformerID INT, Name NVARCHAR(50), GeofenceID INT, GeofenceName NVARCHAR(100),
                    MinLat DECIMAL(9,6), MinLon DECIMAL(9,6), MaxLat DECIMAL(9,6), MaxLon DECIMAL(9,6),
                    AreaDeg2 DECIMAL(18,8), Path NVARCHAR(4000));
INSERT @loc EXEC sp_tso_locate 8, 35.145, 33.39;   -- συντεταγμένες μετρητή 1
IF (SELECT TOP 1 TransformerID FROM @loc ORDER BY AreaDeg2, TransformerID) = 4
   AND (SELECT TOP 1 Path FROM @loc ORDER BY AreaDeg2, TransformerID) = N'T-ROOT Κύπρος > T-NIC Λευκωσία > T-NIC-AGL'
    PRINT 'OK   locate meter 1 coordinates -> transformer 4 (with Path)' ELSE PRINT 'FAIL locate meter 1';
DELETE @loc;
INSERT @loc EXEC sp_tso_locate 8, 34.68, 33.045;   -- μετρητής 3
IF (SELECT COUNT(*) FROM @loc) = 1 AND (SELECT TransformerID FROM @loc) = 6 PRINT 'OK   locate meter 3 coordinates -> transformer 6' ELSE PRINT 'FAIL locate meter 3';
DELETE @loc;
INSERT @loc EXEC sp_tso_locate 8, 34.705, 33.055;  -- μέσα στο T-TEST-LIM-A1 (το A δεν είναι φύλλο πια)
IF (SELECT COUNT(*) FROM @loc) = 1 AND (SELECT TransformerID FROM @loc) = (SELECT TransformerID FROM @b)
    PRINT 'OK   locate returns the leaf, not its non-leaf parent' ELSE PRINT 'FAIL locate leaf only';
DELETE @loc;
INSERT @loc EXEC sp_tso_locate 8, 35.16, 33.37;    -- ακμή μεταξύ φύλλων 4 και 5 (συμπεριλαμβανόμενα όρια)
IF (SELECT COUNT(*) FROM @loc) = 2 AND (SELECT TOP 1 AreaDeg2 FROM @loc ORDER BY AreaDeg2, TransformerID) <= (SELECT MAX(AreaDeg2) FROM @loc)
   AND EXISTS (SELECT 1 FROM @loc WHERE TransformerID = 4) AND EXISTS (SELECT 1 FROM @loc WHERE TransformerID = 5)
    PRINT 'OK   locate on a shared edge -> both leaves (inclusive bounds)' ELSE PRINT 'FAIL locate shared edge';
DELETE @loc;
INSERT @loc EXEC sp_tso_locate 8, 37.98, 23.72;    -- Αθήνα
IF NOT EXISTS (SELECT 1 FROM @loc) PRINT 'OK   locate outside Cyprus -> 0 rows' ELSE PRINT 'FAIL locate outside Cyprus';
DELETE @loc;
INSERT @loc EXEC sp_tso_locate 8, 35.5, 34.0;      -- μέσα στη ρίζα, σε κανένα φύλλο
IF NOT EXISTS (SELECT 1 FROM @loc) PRINT 'OK   locate inside only a non-leaf geofence -> 0 rows' ELSE PRINT 'FAIL locate non-leaf only';
BEGIN TRY EXEC sp_tso_locate 8, 95, 33; PRINT 'FAIL latitude 95 accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53508 PRINT 'OK   invalid latitude -> 53508' ELSE PRINT 'FAIL invalid latitude: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tso_check_meter_locations ----------
DECLARE @chk TABLE (MeterID INT, SerialNumber VARCHAR(40), Status VARCHAR(20), Latitude DECIMAL(9,6), Longitude DECIMAL(9,6),
                    TransformerID INT, TransformerName NVARCHAR(50), FoundTransformerID INT, FoundTransformerName NVARCHAR(50),
                    Result VARCHAR(12));
INSERT @chk EXEC sp_tso_check_meter_locations 8;
IF (SELECT COUNT(*) FROM @chk WHERE MeterID BETWEEN 1 AND 5 AND Result = 'OK') = 5 PRINT 'OK   check meters: base meters 1-5 all match their leaf' ELSE PRINT 'FAIL check meters base';

-- Αναντιστοιχία: μετρητής 1 μπαίνει προσωρινά στον 5 (φύλλο), ο έλεγχος τον πιάνει, και η αλλαγή αναιρείται.
DELETE @chk;
BEGIN TRY
    BEGIN TRAN;
    UPDATE METER SET TransformerID = 5 WHERE MeterID = 1;
    INSERT @chk EXEC sp_tso_check_meter_locations 8;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT 'FAIL mismatch setup: ' + ERROR_MESSAGE();
END CATCH;
IF (SELECT Result FROM @chk WHERE MeterID = 1) = 'Mismatch' AND (SELECT FoundTransformerID FROM @chk WHERE MeterID = 1) = 4
   AND (SELECT TransformerID FROM METER WHERE MeterID = 1) = 4
    PRINT 'OK   check meters: moved meter flagged Mismatch (found 4), change rolled back' ELSE PRINT 'FAIL check meters mismatch';
