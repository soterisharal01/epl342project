-- MDMS-Cy Φάση Β, Βήμα 0: έλεγχοι για τις 4 αλλαγές του καθηγητή.
-- Τρέχει σε ΚΕΝΗ βάση αμέσως μετά το create.sql. Κάθε έλεγχος τυπώνει OK ή FAIL.
-- Γράφει λίγες γραμμές δοκιμής: μετά τρέξτε drop.sql και create.sql για να αδειάσει η βάση.
-- (Δεν γίνεται μέσα σε ένα transaction, γιατί ένα THROW από trigger ακυρώνει όλο το transaction.)
SET NOCOUNT ON;
DECLARE @ok INT;

-- εταιρείες, γεωγραφία, μοντέλα
INSERT SUPPLIER (Name) VALUES (N'EAC Supply');
INSERT AGGREGATOR (Name) VALUES (N'GridFlex');
INSERT GEOFENCE (Name, MinLat, MinLon, MaxLat, MaxLon) VALUES
 (N'Κύπρος', 34.5, 32.2, 35.7, 34.6), (N'Λευκωσία', 35.0, 33.2, 35.3, 33.5), (N'Στρόβολος', 35.1, 33.3, 35.2, 33.4);
INSERT METER_MODEL (Manufacturer, ModelName, MeterType, PhaseCount) VALUES (N'Landis', N'E450', 'Electricity', 1);
INSERT COMM_TYPE (Name) VALUES (N'PLC');
INSERT OBIS_CODE (ObisCode, Description, Unit, Kind) VALUES ('1.8.0', N'Active import', 'kWh', 'Cumulative register');

-- 1. Χρήστες: ένας πίνακας, ένας ρόλος ανά username, ίδιο email για 2 usernames
INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName) VALUES ('admin1', 'x', 'Admin', 'a@mdms.cy', N'Α', N'Δ');
INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName, RawRetentionMonths) VALUES ('chris_home', 'x', 'Consumer', 'chris@mail.cy', N'Χριστόφορος', N'Χ', 36);
INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName, BirthDate, Photo, ApprovalStatus) VALUES ('chris_tech', 'x', 'Technician', 'chris@mail.cy', N'Χριστόφορος', N'Χ', '1990-01-01', N'p.jpg', 'Pending');
SELECT CASE WHEN COUNT(*) = 2 THEN N'OK  ' ELSE N'FAIL' END + N' 1a ίδιο άτομο, 2 usernames, 2 ρόλοι' FROM USER_ACCOUNT WHERE Email = 'chris@mail.cy';
BEGIN TRY INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName) VALUES ('chris_home', 'x', 'DSO', 'z@z.cy', N'Ζ', N'Ζ'); PRINT N'FAIL 1b διπλό username'; END TRY BEGIN CATCH PRINT N'OK   1b διπλό username απορρίπτεται'; END CATCH;
BEGIN TRY INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName) VALUES ('boss', 'x', 'King', 'k@k.cy', N'Κ', N'Κ'); PRINT N'FAIL 1c άγνωστος ρόλος'; END TRY BEGIN CATCH PRINT N'OK   1c άγνωστος ρόλος απορρίπτεται'; END CATCH;
BEGIN TRY INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName, BirthDate) VALUES ('dso1x', 'x', 'DSO', 'd@d.cy', N'Δ', N'Δ', '1990-01-01'); PRINT N'FAIL 1d πεδίο τεχνικού σε DSO'; END TRY BEGIN CATCH PRINT N'OK   1d πεδία τεχνικού μόνο σε Technician'; END CATCH;
BEGIN TRY INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName) VALUES ('sup1x', 'x', 'Supplier', 's@s.cy', N'Σ', N'Σ'); PRINT N'FAIL 1e Supplier χωρίς εταιρεία'; END TRY BEGIN CATCH PRINT N'OK   1e Supplier χρειάζεται SupplierID'; END CATCH;
INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName) VALUES ('dso1', 'x', 'DSO', 'd@d.cy', N'Δ', N'Δ');
INSERT USER_ACCOUNT (Username, PasswordHash, Role, Email, FirstName, LastName, SupplierID) VALUES ('sup1', 'x', 'Supplier', 's@s.cy', N'Σ', N'Σ', 1);

-- 3. Μετασχηματιστές: δέντρο, μετρητές μόνο στα φύλλα
INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID, ParentTransformerID) VALUES (N'T-ROOT', 35.1, 33.3, 1, NULL);
INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID, ParentTransformerID) VALUES (N'T-LEF', 35.15, 33.35, 2, 1);
INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID, ParentTransformerID) VALUES (N'T-STR', 35.16, 33.36, 3, 2);
INSERT METER (SerialNumber, NetworkID, Firmware, MaxLoadAmps, Latitude, Longitude, Status, ModelID, CommTypeID, TransformerID) VALUES ('S1', 'N1', '1.0', 60, 35.16, 33.36, 'Active', 1, 1, 3);
PRINT N'OK   3a μετρητής σε φύλλο';
BEGIN TRY INSERT METER (SerialNumber, NetworkID, Firmware, MaxLoadAmps, Latitude, Longitude, ModelID, CommTypeID, TransformerID) VALUES ('S2', 'N2', '1.0', 60, 35.1, 33.3, 1, 1, 2); PRINT N'FAIL 3b μετρητής σε μη-φύλλο'; END TRY BEGIN CATCH PRINT N'OK   3b μετρητής σε μη-φύλλο απορρίπτεται'; END CATCH;
BEGIN TRY INSERT GEOFENCE (Name, MinLat, MinLon, MaxLat, MaxLon) VALUES (N'x', 1, 1, 2, 2); INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID, ParentTransformerID) VALUES (N'T-BAD', 35.1, 33.3, SCOPE_IDENTITY(), 3); PRINT N'FAIL 3c παιδί σε μετασχηματιστή με μετρητές'; END TRY BEGIN CATCH PRINT N'OK   3c παιδί σε μετασχηματιστή με μετρητές απορρίπτεται'; END CATCH;
BEGIN TRY UPDATE TRANSFORMER SET ParentTransformerID = 2 WHERE TransformerID = 1; PRINT N'FAIL 3d κύκλος'; END TRY BEGIN CATCH PRINT N'OK   3d κύκλος απορρίπτεται'; END CATCH;
BEGIN TRY INSERT TRANSFORMER (Name, Latitude, Longitude, GeofenceID) VALUES (N'T-DUP', 35.1, 33.3, 3); PRINT N'FAIL 3e δεύτερος μετασχηματιστής στο ίδιο geofence'; END TRY BEGIN CATCH PRINT N'OK   3e ένα geofence ανά μετασχηματιστή'; END CATCH;

-- 2. Μετρήσεις: raw -> VEE -> validated, αμετάβλητες
INSERT TELEMETRY_PACKET (RawPayload, IngestStatus, MeterID) VALUES (N'{}', 'Accepted', 1);
INSERT RAW_READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, '1.8.0', '2026-11-01 00:00', 10.5, 1), (1, '1.8.0', '2026-11-01 00:15', 10.9, 1);
INSERT VEE_RUN (PeriodFrom, PeriodTo) VALUES ('2026-11-01', '2026-11-02');
INSERT VALIDATED_READING (MeterID, ObisCode, IntervalStart, Value, Quality, RunID) SELECT MeterID, ObisCode, IntervalStart, ReceivedValue, 'Validated', 1 FROM RAW_READING;
UPDATE RAW_READING SET VeeStatus = 'Validated';
INSERT VALIDATED_READING (MeterID, ObisCode, IntervalStart, Value, Quality, RunID) VALUES (1, '1.8.0', '2026-11-01 00:30', 11.2, 'Estimated', 1);
PRINT N'OK   2a raw -> validated (και εκτίμηση για κενό)';
BEGIN TRY UPDATE VALIDATED_READING SET Value = 0 WHERE IntervalStart = '2026-11-01 00:00'; PRINT N'FAIL 2b UPDATE σε validated'; END TRY BEGIN CATCH PRINT N'OK   2b UPDATE σε validated απορρίπτεται'; END CATCH;
BEGIN TRY DELETE VALIDATED_READING WHERE IntervalStart = '2026-11-01 00:00'; PRINT N'FAIL 2c DELETE σε validated'; END TRY BEGIN CATCH PRINT N'OK   2c DELETE σε validated απορρίπτεται'; END CATCH;
EXEC sp_set_session_context N'mdms_purge', 1;
DELETE VALIDATED_READING WHERE IntervalStart = '2026-11-01 00:30';
EXEC sp_set_session_context N'mdms_purge', 0;
SELECT CASE WHEN COUNT(*) = 2 THEN N'OK  ' ELSE N'FAIL' END + N' 2d διαγραφή μόνο από διαδικασία διατήρησης' FROM VALIDATED_READING;

-- 4. Aggregates (ημέρα/μήνας/έτος) στα φύλλα, πάνω επίπεδα με ερώτημα
INSERT METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount)
SELECT MeterID, ObisCode, 'Month', '2026-11-01', SUM(Value), COUNT(*), SUM(CASE WHEN Quality = 'Estimated' THEN 1 ELSE 0 END) FROM VALIDATED_READING GROUP BY MeterID, ObisCode;
INSERT TRANSFORMER_AGGREGATE (TransformerID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount)
SELECT m.TransformerID, a.ObisCode, 'Month', a.PeriodStart, SUM(a.SumValue), COUNT(*) FROM METER_AGGREGATE a JOIN METER m ON m.MeterID = a.MeterID WHERE a.PeriodType = 'Month' GROUP BY m.TransformerID, a.ObisCode, a.PeriodStart;
PRINT N'OK   4a μηνιαίο aggregate στο φύλλο';
BEGIN TRY INSERT TRANSFORMER_AGGREGATE (TransformerID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount) VALUES (1, '1.8.0', 'Month', '2026-11-01', 1, 1); PRINT N'FAIL 4b aggregate σε μη-φύλλο'; END TRY BEGIN CATCH PRINT N'OK   4b αποθηκευμένο aggregate μόνο σε φύλλα'; END CATCH;
-- άθροισμα για ΚΑΘΕ μετασχηματιστή (και τα πάνω επίπεδα) με αναδρομικό CTE
WITH sub AS (
    SELECT TransformerID AS Top_, TransformerID AS Node FROM TRANSFORMER
    UNION ALL
    SELECT sub.Top_, t.TransformerID FROM sub JOIN TRANSFORMER t ON t.ParentTransformerID = sub.Node)
SELECT @ok = COUNT(*) FROM (
    SELECT sub.Top_, SUM(a.SumValue) AS Total FROM sub JOIN TRANSFORMER_AGGREGATE a ON a.TransformerID = sub.Node
    WHERE a.PeriodType = 'Month' AND a.PeriodStart = '2026-11-01' GROUP BY sub.Top_) x WHERE x.Total = 21.4;
SELECT CASE WHEN @ok = 3 THEN N'OK  ' ELSE N'FAIL' END + N' 4c ίδιο σύνολο 21.4 kWh σε φύλλο, γονέα και ρίζα (CTE)';

