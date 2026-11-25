-- =====================================================================
-- test_tso.sql : έλεγχοι για το procs_tso.sql (TSO-1 … TSO-4).
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


-- =====================================================================
-- TSO-2 / TSO-3 / TSO-4: τρέχουσα κατάσταση, aggregates, load shedding
-- (οι μεταβλητές ξεκινούν με @s_ για να μη συγκρούονται με του TSO-1)
-- =====================================================================

-- ---------- Έλεγχος ρόλου (operator = UserID 2) ----------
BEGIN TRY EXEC sp_tso_refresh_current_state 2; PRINT 'FAIL operator refreshed state'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   refresh state: non-TSO -> 53500' ELSE PRINT 'FAIL refresh role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_current_state 2; PRINT 'FAIL operator read state'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   current state: non-TSO -> 53500' ELSE PRINT 'FAIL state role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_aggregates 2, 1, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL operator read aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   aggregates: non-TSO -> 53500' ELSE PRINT 'FAIL aggregates role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_load_shed 2, 2, N'δοκιμή'; PRINT 'FAIL operator shed load'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   load shed: non-TSO -> 53500' ELSE PRINT 'FAIL shed role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_list_shed_orders 2; PRINT 'FAIL operator listed orders'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53500 PRINT 'OK   list shed orders: non-TSO -> 53500' ELSE PRINT 'FAIL list role: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tso_refresh_current_state ----------
DECLARE @s_ref TABLE (RefInterval DATETIME2(0), LeafCount INT, RowsAffected INT);
INSERT @s_ref EXEC sp_tso_refresh_current_state 8;
DECLARE @s_latest DATETIME2(0) = (SELECT MAX(IntervalStart) FROM VALIDATED_READING WHERE ObisCode IN ('1.8.0', '2.8.0'));
DECLARE @s_leaves INT = (SELECT COUNT(*) FROM TRANSFORMER t WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID));
IF (SELECT RefInterval FROM @s_ref) = @s_latest AND (SELECT LeafCount FROM @s_ref) = @s_leaves
    PRINT 'OK   refresh: RefInterval is the latest validated interval, one pass over all leaves' ELSE PRINT 'FAIL refresh result';
IF (SELECT COUNT(*) FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID IN (4, 5, 6) AND ObisCode IN ('1.8.0', '2.8.0')) = 6
    PRINT 'OK   refresh: leaves 4, 5, 6 have rows for 1.8.0 and 2.8.0' ELSE PRINT 'FAIL refresh rows for leaves 4, 5, 6';
IF (SELECT COUNT(*) FROM TRANSFORMER_CURRENT_STATE) = 2 * (SELECT COUNT(*) FROM TRANSFORMER)
   AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_CURRENT_STATE WHERE RefInterval <> @s_latest)
    PRINT 'OK   refresh: every node (leaves and ancestors) stored, 2 codes each, all with the same RefInterval' ELSE PRINT 'FAIL refresh does not store the whole tree or mixed intervals';
IF (SELECT SumValue FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID = 2 AND ObisCode = '1.8.0')
     = (SELECT SUM(SumValue) FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID IN (4, 5) AND ObisCode = '1.8.0')
   AND (SELECT SumValue FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID = 1 AND ObisCode = '2.8.0')
     = (SELECT SUM(SumValue) FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID IN (4, 5, 6) AND ObisCode = '2.8.0')
   AND (SELECT MeterCount FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID = 1 AND ObisCode = '1.8.0')
     = (SELECT SUM(MeterCount) FROM TRANSFORMER_CURRENT_STATE WHERE TransformerID IN (4, 5, 6) AND ObisCode = '1.8.0')
    PRINT 'OK   refresh: stored ancestor rows = sum of their leaves (node 2 = 4 + 5, root = 4 + 5 + 6)' ELSE PRINT 'FAIL refresh ancestor rows';
IF NOT EXISTS (
    SELECT 1
    FROM TRANSFORMER_CURRENT_STATE cs
    OUTER APPLY (SELECT SUM(vr.Value) AS S, COUNT(DISTINCT vr.MeterID) AS C
                 FROM METER m JOIN VALIDATED_READING vr ON vr.MeterID = m.MeterID
                 WHERE m.TransformerID = cs.TransformerID AND vr.ObisCode = cs.ObisCode AND vr.IntervalStart = @s_latest) d
    WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = cs.TransformerID)
      AND (cs.SumValue <> ISNULL(d.S, 0) OR cs.MeterCount <> ISNULL(d.C, 0)))
    PRINT 'OK   refresh: every stored leaf SumValue/MeterCount equals a direct SUM over VALIDATED_READING' ELSE PRINT 'FAIL refresh sums differ from direct SUM';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'TRANSFORMER_CURRENT_STATE' AND Action = 'Refresh' AND PerformedBy = 8)
    PRINT 'OK   refresh: AUDIT_LOG row written' ELSE PRINT 'FAIL refresh audit';

-- Δεύτερη ανανέωση: ίδιο αποτέλεσμα, καμία διπλή γραμμή.
DECLARE @s_cnt1 INT = (SELECT COUNT(*) FROM TRANSFORMER_CURRENT_STATE);
EXEC sp_tso_refresh_current_state 8;
IF (SELECT COUNT(*) FROM TRANSFORMER_CURRENT_STATE) = @s_cnt1 PRINT 'OK   refresh twice: MERGE does not duplicate rows' ELSE PRINT 'FAIL refresh twice';

-- ---------- sp_tso_current_state ----------
DECLARE @s_st TABLE (TransformerID INT, Name NVARCHAR(50), Level INT, Path NVARCHAR(4000), RefInterval DATETIME2(0),
                     ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), MeterCount INT);
INSERT @s_st EXEC sp_tso_current_state 8;
IF (SELECT COUNT(*) FROM @s_st) = (SELECT COUNT(*) FROM TRANSFORMER) AND (SELECT Level FROM @s_st WHERE TransformerID = 1) = 0
   AND (SELECT Level FROM @s_st WHERE TransformerID = 4) = 2
    PRINT 'OK   current state: one row per node, Level from the root' ELSE PRINT 'FAIL current state shape';
IF (SELECT ImportKWh FROM @s_st WHERE TransformerID = 1) = (SELECT SUM(SumValue) FROM TRANSFORMER_CURRENT_STATE WHERE ObisCode = '1.8.0' AND TransformerID IN (4, 5, 6))
   AND (SELECT ExportKWh FROM @s_st WHERE TransformerID = 1) = (SELECT SUM(SumValue) FROM TRANSFORMER_CURRENT_STATE WHERE ObisCode = '2.8.0' AND TransformerID IN (4, 5, 6))
   AND (SELECT NetKWh FROM @s_st WHERE TransformerID = 1) = (SELECT ImportKWh - ExportKWh FROM @s_st WHERE TransformerID = 1)
    PRINT 'OK   current state: root = sum of all leaves (import, export, net)' ELSE PRINT 'FAIL current state root sum';
IF (SELECT ImportKWh FROM @s_st WHERE TransformerID = 2) = (SELECT SUM(SumValue) FROM TRANSFORMER_CURRENT_STATE WHERE ObisCode = '1.8.0' AND TransformerID IN (4, 5))
   AND (SELECT MeterCount FROM @s_st WHERE TransformerID = 2) = (SELECT SUM(MeterCount) FROM TRANSFORMER_CURRENT_STATE WHERE ObisCode = '1.8.0' AND TransformerID IN (4, 5))
   AND (SELECT ImportKWh FROM @s_st WHERE TransformerID = 4) = (SELECT SumValue FROM TRANSFORMER_CURRENT_STATE WHERE ObisCode = '1.8.0' AND TransformerID = 4)
    PRINT 'OK   current state: transformer 2 = leaves 4 + 5, a leaf equals its stored row' ELSE PRINT 'FAIL current state intermediate node';
IF (SELECT RefInterval FROM @s_st WHERE TransformerID = 1) = @s_latest PRINT 'OK   current state: RefInterval shown' ELSE PRINT 'FAIL current state RefInterval';
DELETE @s_st;
INSERT @s_st EXEC sp_tso_current_state 8, 2;
IF (SELECT COUNT(*) FROM @s_st) = 3 AND (SELECT Level FROM @s_st WHERE TransformerID = 2) = 0 AND NOT EXISTS (SELECT 1 FROM @s_st WHERE TransformerID IN (1, 3, 6))
    PRINT 'OK   current state of transformer 2: itself + subtree only' ELSE PRINT 'FAIL current state subtree';
BEGIN TRY EXEC sp_tso_current_state 8, 99999; PRINT 'FAIL unknown transformer accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53601 PRINT 'OK   current state: unknown transformer -> 53601' ELSE PRINT 'FAIL current state unknown: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tso_aggregates ----------
DECLARE @s_ag TABLE (PeriodStart DATE, ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), NetKWh DECIMAL(18,4), LeafCount INT);
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Day', '2026-11-18', '2026-11-19';
IF (SELECT COUNT(*) FROM @s_ag) = 2
   AND (SELECT SUM(ImportKWh) FROM @s_ag) = (SELECT SUM(a.SumValue) FROM TRANSFORMER_AGGREGATE a
        WHERE a.PeriodType = 'Day' AND a.ObisCode = '1.8.0' AND a.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = a.TransformerID))
   AND (SELECT SUM(ExportKWh) FROM @s_ag) = (SELECT SUM(a.SumValue) FROM TRANSFORMER_AGGREGATE a
        WHERE a.PeriodType = 'Day' AND a.ObisCode = '2.8.0' AND a.PeriodStart BETWEEN '2026-11-18' AND '2026-11-19'
          AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = a.TransformerID))
    PRINT 'OK   aggregates Day 18-19/11 at the root = sum of the leaf rows' ELSE PRINT 'FAIL aggregates Day root';
IF (SELECT LeafCount FROM @s_ag WHERE PeriodStart = '2026-11-18') = 3
   AND (SELECT NetKWh FROM @s_ag WHERE PeriodStart = '2026-11-18') = (SELECT ImportKWh - ExportKWh FROM @s_ag WHERE PeriodStart = '2026-11-18')
    PRINT 'OK   aggregates Day: LeafCount 3 and Net = Import - Export' ELSE PRINT 'FAIL aggregates Day leaf count';
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 2, 'Day', '2026-11-18', '2026-11-18';
IF (SELECT COUNT(*) FROM @s_ag) = 1 AND (SELECT LeafCount FROM @s_ag) = 2
   AND (SELECT ImportKWh FROM @s_ag) = (SELECT SUM(SumValue) FROM TRANSFORMER_AGGREGATE
        WHERE TransformerID IN (4, 5) AND PeriodType = 'Day' AND ObisCode = '1.8.0' AND PeriodStart = '2026-11-18')
    PRINT 'OK   aggregates Day for transformer 2 = leaves 4 + 5' ELSE PRINT 'FAIL aggregates Day transformer 2';
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 6, 'Day', '2026-11-18', '2026-11-18';
IF (SELECT COUNT(*) FROM @s_ag) = 1 AND (SELECT LeafCount FROM @s_ag) = 1
   AND (SELECT ExportKWh FROM @s_ag) = (SELECT SumValue FROM TRANSFORMER_AGGREGATE WHERE TransformerID = 6 AND PeriodType = 'Day' AND ObisCode = '2.8.0' AND PeriodStart = '2026-11-18')
    PRINT 'OK   aggregates Day for a leaf = its own row' ELSE PRINT 'FAIL aggregates Day leaf';

-- Quarter: Q4 2026 = ένα αποτέλεσμα. Η σύγκριση με τα Day γίνεται μόνο αν δεν υπάρχουν αποθηκευμένα Month στο τρίμηνο.
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Quarter', '2026-11-18', '2026-11-19';
IF (SELECT COUNT(*) FROM @s_ag) = 1 AND (SELECT PeriodStart FROM @s_ag) = '2026-10-01'
    PRINT 'OK   aggregates Quarter -> one row, PeriodStart 2026-10-01 (Q4 2026)' ELSE PRINT 'FAIL aggregates Quarter shape';
IF EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE WHERE PeriodType = 'Month' AND PeriodStart BETWEEN '2026-10-01' AND '2026-12-31')
    PRINT 'OK   aggregates Quarter = Day sum (skipped: stored Month rows exist in Q4)'
ELSE IF (SELECT ImportKWh FROM @s_ag) = (SELECT SUM(a.SumValue) FROM TRANSFORMER_AGGREGATE a
            WHERE a.PeriodType = 'Day' AND a.ObisCode = '1.8.0' AND a.PeriodStart BETWEEN '2026-10-01' AND '2026-12-31'
              AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = a.TransformerID))
        AND (SELECT ExportKWh FROM @s_ag) = (SELECT SUM(a.SumValue) FROM TRANSFORMER_AGGREGATE a
            WHERE a.PeriodType = 'Day' AND a.ObisCode = '2.8.0' AND a.PeriodStart BETWEEN '2026-10-01' AND '2026-12-31'
              AND NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = a.TransformerID))
    PRINT 'OK   aggregates Quarter Q4 2026 = sum of the leaf Day rows' ELSE PRINT 'FAIL aggregates Quarter sum';
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Month', '2026-11-05', '2026-11-30';
IF (SELECT COUNT(*) FROM @s_ag) = 1 AND (SELECT PeriodStart FROM @s_ag) = '2026-11-01'
   AND (SELECT ImportKWh FROM @s_ag) > 0
    PRINT 'OK   aggregates Month -> November rolled up (whole month)' ELSE PRINT 'FAIL aggregates Month';
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Year', '2026-01-01', '2026-12-31';
IF (SELECT COUNT(*) FROM @s_ag) = 1 AND (SELECT PeriodStart FROM @s_ag) = '2026-01-01'
    PRINT 'OK   aggregates Year -> one row, PeriodStart 2026-01-01' ELSE PRINT 'FAIL aggregates Year';
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Day', '2020-01-01', '2020-01-31';
IF NOT EXISTS (SELECT 1 FROM @s_ag) PRINT 'OK   aggregates for a period without data -> 0 rows' ELSE PRINT 'FAIL aggregates empty period';

-- Ο πίνακας δεν αλλάζει από τα aggregates.
DECLARE @s_agcnt INT = (SELECT COUNT(*) FROM TRANSFORMER_AGGREGATE), @s_agsum DECIMAL(18,4) = (SELECT SUM(SumValue) FROM TRANSFORMER_AGGREGATE);
DELETE @s_ag;
INSERT @s_ag EXEC sp_tso_aggregates 8, 1, 'Quarter', '2026-10-01', '2026-12-31';
IF (SELECT COUNT(*) FROM TRANSFORMER_AGGREGATE) = @s_agcnt AND (SELECT SUM(SumValue) FROM TRANSFORMER_AGGREGATE) = @s_agsum
    PRINT 'OK   aggregates never write to TRANSFORMER_AGGREGATE' ELSE PRINT 'FAIL aggregates wrote to the table';

BEGIN TRY EXEC sp_tso_aggregates 8, 1, 'Week', '2026-11-18', '2026-11-19'; PRINT 'FAIL bad period type accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53610 PRINT 'OK   aggregates: bad period type -> 53610' ELSE PRINT 'FAIL period type: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_aggregates 8, 1, 'Day', '2026-11-19', '2026-11-18'; PRINT 'FAIL inverted dates accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53611 PRINT 'OK   aggregates: From > To -> 53611' ELSE PRINT 'FAIL inverted dates: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_aggregates 8, 99999, 'Day', '2026-11-18', '2026-11-19'; PRINT 'FAIL unknown transformer accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53612 PRINT 'OK   aggregates: unknown transformer -> 53612' ELSE PRINT 'FAIL aggregates unknown: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_tso_load_shed ----------
DECLARE @s_o0 INT = (SELECT COUNT(*) FROM LOAD_SHED_ORDER), @s_c0 INT = (SELECT COUNT(*) FROM REMOTE_COMMAND);
DECLARE @s_shed TABLE (ShedOrderID INT, CommandCount INT);
INSERT @s_shed EXEC sp_tso_load_shed 8, 2, N'Δοκιμή TSO-4: υπερφόρτωση δικτύου';
DECLARE @s_oid INT = (SELECT ShedOrderID FROM @s_shed);
IF @s_oid IS NOT NULL AND (SELECT CommandCount FROM @s_shed) = 3
   AND (SELECT COUNT(*) FROM LOAD_SHED_ORDER) = @s_o0 + 1 AND (SELECT COUNT(*) FROM REMOTE_COMMAND) = @s_c0 + 3
   AND EXISTS (SELECT 1 FROM LOAD_SHED_ORDER WHERE ShedOrderID = @s_oid AND Status = 'Issued' AND TransformerID = 2 AND OrderedBy = 8)
    PRINT 'OK   load shed on transformer 2 -> one order, 3 commands' ELSE PRINT 'FAIL load shed on transformer 2';
IF (SELECT COUNT(*) FROM REMOTE_COMMAND WHERE ShedOrderID = @s_oid AND MeterID IN (1, 2, 4)) = 3
   AND (SELECT COUNT(*) FROM REMOTE_COMMAND WHERE ShedOrderID = @s_oid) = 3
    PRINT 'OK   load shed: commands only for the Active meters 1, 2, 4' ELSE PRINT 'FAIL load shed meters';
IF NOT EXISTS (SELECT 1 FROM REMOTE_COMMAND WHERE ShedOrderID = @s_oid
               AND (CommandType <> 'Load shed' OR Status <> 'Sent' OR RequestedBy <> 8 OR ISJSON(Parameters) <> 1))
   AND NOT EXISTS (SELECT 1 FROM REMOTE_COMMAND rc JOIN METER m ON m.MeterID = rc.MeterID WHERE rc.ShedOrderID = @s_oid AND m.Status <> 'Active')
    PRINT 'OK   load shed: all commands Load shed + Sent, RequestedBy = TSO, Parameters valid JSON' ELSE PRINT 'FAIL load shed command fields';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'LOAD_SHED_ORDER' AND ObjectID = CAST(@s_oid AS VARCHAR(20)) AND Action = 'Create' AND PerformedBy = 8)
    PRINT 'OK   load shed: AUDIT_LOG row' ELSE PRINT 'FAIL load shed audit';

-- Το root: ο Pending μετρητής 5 και ο Active 3 κάτω από τον 3 -> 4 εντολές (1, 2, 3, 4).
DELETE @s_shed;
INSERT @s_shed EXEC sp_tso_load_shed 8, 1, N'Δοκιμή TSO-4: όλο το δίκτυο';
IF (SELECT CommandCount FROM @s_shed) = 4
   AND NOT EXISTS (SELECT 1 FROM REMOTE_COMMAND WHERE ShedOrderID = (SELECT ShedOrderID FROM @s_shed) AND MeterID = 5)
    PRINT 'OK   load shed on the root -> 4 Active meters, the Pending meter 5 skipped' ELSE PRINT 'FAIL load shed root';

-- Απορρίψεις: τίποτα δεν μένει πίσω.
SET @s_o0 = (SELECT COUNT(*) FROM LOAD_SHED_ORDER);
SET @s_c0 = (SELECT COUNT(*) FROM REMOTE_COMMAND);
DECLARE @s_empty INT = (SELECT TransformerID FROM TRANSFORMER WHERE Name = N'T-TEST-LIM-A');
BEGIN TRY EXEC sp_tso_load_shed 8, @s_empty, N'Δοκιμή χωρίς μετρητές'; PRINT 'FAIL shed on transformer without meters accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53622 PRINT 'OK   load shed: no active meters below -> 53622' ELSE PRINT 'FAIL shed no meters: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_load_shed 8, 5, N'   '; PRINT 'FAIL empty reason accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53620 PRINT 'OK   load shed: empty reason -> 53620' ELSE PRINT 'FAIL shed reason: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_load_shed 8, 99999, N'Δοκιμή'; PRINT 'FAIL unknown transformer accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53621 PRINT 'OK   load shed: unknown transformer -> 53621' ELSE PRINT 'FAIL shed unknown: ' + ERROR_MESSAGE(); END CATCH;
IF (SELECT COUNT(*) FROM LOAD_SHED_ORDER) = @s_o0 AND (SELECT COUNT(*) FROM REMOTE_COMMAND) = @s_c0
    PRINT 'OK   load shed: refused calls left no order and no command behind' ELSE PRINT 'FAIL refused load shed left rows';

-- ---------- sp_tso_list_shed_orders ----------
DECLARE @s_lst TABLE (ShedOrderID INT, CreatedAt DATETIME2(0), Status VARCHAR(16), Reason NVARCHAR(500), TransformerID INT,
                      TransformerName NVARCHAR(50), OrderedByName NVARCHAR(50), Commands INT, AwaitingApproval INT, Sent INT,
                      Acknowledged INT, Failed INT, Cancelled INT);
INSERT @s_lst EXEC sp_tso_list_shed_orders 8;
IF (SELECT COUNT(*) FROM @s_lst) = (SELECT COUNT(*) FROM LOAD_SHED_ORDER)
   AND (SELECT Commands FROM @s_lst WHERE ShedOrderID = @s_oid) = 3 AND (SELECT Sent FROM @s_lst WHERE ShedOrderID = @s_oid) = 3
   AND (SELECT TransformerName FROM @s_lst WHERE ShedOrderID = @s_oid) = (SELECT Name FROM TRANSFORMER WHERE TransformerID = 2)
    PRINT 'OK   list shed orders: transformer name and command counts by status' ELSE PRINT 'FAIL list shed orders';

-- ---------- sp_tso_map_data (TSO-6) ----------
DECLARE @m6_map TABLE (Kind VARCHAR(12), Id INT, Name NVARCHAR(50), SerialNumber VARCHAR(40), Latitude DECIMAL(9,6), Longitude DECIMAL(9,6),
                       ParentId INT, Level INT, IsLeaf BIT, MinLat DECIMAL(9,6), MinLon DECIMAL(9,6), MaxLat DECIMAL(9,6), MaxLon DECIMAL(9,6),
                       ImportKWh DECIMAL(18,4), ExportKWh DECIMAL(18,4), Status VARCHAR(20), TransformerID INT);
BEGIN TRY INSERT @m6_map EXEC sp_tso_map_data 3; PRINT 'FAIL consumer got the map data'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53800 PRINT 'OK   map data: Consumer -> 53800' ELSE PRINT 'FAIL map data role: ' + ERROR_MESSAGE(); END CATCH;
INSERT @m6_map EXEC sp_tso_map_data 8;
IF (SELECT COUNT(*) FROM @m6_map WHERE Kind = 'Transformer' AND Id BETWEEN 1 AND 6 AND Latitude IS NOT NULL AND MinLat < MaxLat AND MinLon < MaxLon) = 6
   AND (SELECT Level FROM @m6_map WHERE Kind = 'Transformer' AND Id = 1) = 0
   AND (SELECT IsLeaf FROM @m6_map WHERE Kind = 'Transformer' AND Id = 4) = 1
   AND (SELECT IsLeaf FROM @m6_map WHERE Kind = 'Transformer' AND Id = 2) = 0
    PRINT 'OK   map data: base transformers 1-6 with geofence, level and leaf flag' ELSE PRINT 'FAIL map data transformers';
IF (SELECT COUNT(*) FROM @m6_map WHERE Kind = 'Meter' AND Id BETWEEN 1 AND 5 AND Latitude IS NOT NULL AND Longitude IS NOT NULL
        AND TransformerID IS NOT NULL AND Status IS NOT NULL) = 5
    PRINT 'OK   map data: meters 1-5 with coordinates, status and transformer' ELSE PRINT 'FAIL map data meters';
INSERT @m6_map EXEC sp_tso_map_data 2;
IF EXISTS (SELECT 1 FROM @m6_map WHERE Kind = 'Transformer' AND Id = 1) PRINT 'OK   map data: Operator may read it' ELSE PRINT 'FAIL map data operator';
