-- =====================================================================
-- test_dso.sql : έλεγχοι για το procs_dso.sql (DSO-1).
-- Πάνω στα κοινά δεδομένα: dso1 = UserID 7, consumer1 = UserID 3.
-- Μετρητές: 1 EAC-NIC-1001, 2 EAC-NIC-1002 (Active), 5 EAC-LIM-2002 (Pending confirmation).
-- Τα δεδομένα βάσης φτάνουν ως 2026-11-20 05:45, άρα τα tests γράφουν στις 2026-11-21.
-- ΣΗΜ.: τρέχει μία φορά ανά καθαρή βάση (ξανατρέξιμο = διπλότυπα, άρα FAIL).
-- Κάθε γραμμή τυπώνει OK ή FAIL. ΟΧΙ BEGIN TRAN γύρω από όλο το αρχείο.
-- =====================================================================
SET NOCOUNT ON;

-- ---------- Έλεγχος ρόλου ----------
BEGIN TRY EXEC sp_dso_assert 3; PRINT 'FAIL consumer passed sp_dso_assert'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer -> 53000 (assert)' ELSE PRINT 'FAIL assert: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_ingest_packet 3, N'{}'; PRINT 'FAIL consumer ingested a packet'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot ingest -> 53000' ELSE PRINT 'FAIL ingest role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_packets 3; PRINT 'FAIL consumer listed packets'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list packets -> 53000' ELSE PRINT 'FAIL list role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_raw 3, 1, '2026-11-21', '2026-11-22'; PRINT 'FAIL consumer listed raw'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list raw -> 53000' ELSE PRINT 'FAIL raw role: ' + ERROR_MESSAGE(); END CATCH;

DECLARE @r TABLE (PacketID BIGINT, IngestStatus VARCHAR(18), ReadingsStored INT, ErrorMessage NVARCHAR(1000));
DECLARE @pid BIGINT, @n INT;

-- ---------- Επιτυχία: 10:07:30 -> διάστημα 10:00, δύο κωδικοί ----------
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T10:07:30Z", "Cell_Signal_Strength_dBm": -92, "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 14400.5, "unit": "kWh"}, {"obis": "32.7.0", "value": 228.4, "unit": "V"}]}';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Accepted' AND ReadingsStored = 2 AND ErrorMessage IS NULL)
    PRINT 'OK   valid packet -> Accepted, 2 readings' ELSE PRINT 'FAIL valid packet result';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID = 1 AND IntervalStart = '2026-11-21 10:00:00' AND PacketID = @pid AND VeeStatus = 'Pending') = 2
    PRINT 'OK   10:07:30 lands in the 10:00 slot, VeeStatus Pending' ELSE PRINT 'FAIL slot 10:00';
IF EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-21 10:00:00' AND ReceivedValue = 14400.5)
    PRINT 'OK   reading value stored' ELSE PRINT 'FAIL reading value';
IF EXISTS (SELECT 1 FROM TELEMETRY_PACKET WHERE PacketID = @pid AND MeterID = 1 AND IngestStatus = 'Accepted' AND SignalDbm = -92
              AND NetworkType = 'NB-IoT' AND TransmissionTimestamp = '2026-11-21 10:07:30' AND RawPayload LIKE N'%EAC-NIC-1001%')
    PRINT 'OK   packet row keeps raw JSON and parsed fields' ELSE PRINT 'FAIL packet row';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'TELEMETRY_PACKET' AND ObjectID = CAST(@pid AS VARCHAR(100)) AND Action = 'Ingest' AND PerformedBy = 7)
    PRINT 'OK   audit row written' ELSE PRINT 'FAIL audit row';

-- ---------- Διπλότυπο: ίδιο πακέτο ξανά ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T10:07:30Z", "Cell_Signal_Strength_dBm": -92, "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 14400.5, "unit": "kWh"}, {"obis": "32.7.0", "value": 228.4, "unit": "V"}]}';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Partially accepted' AND ReadingsStored = 0 AND ErrorMessage IS NOT NULL)
    PRINT 'OK   duplicate packet -> Partially accepted, 0 stored' ELSE PRINT 'FAIL duplicate packet result';
IF (SELECT COUNT(*) FROM RAW_READING WHERE MeterID = 1 AND IntervalStart = '2026-11-21 10:00:00') = 2
    PRINT 'OK   duplicate did not add readings' ELSE PRINT 'FAIL duplicate added readings';
IF EXISTS (SELECT 1 FROM TELEMETRY_PACKET WHERE PacketID = @pid AND IngestStatus = 'Partially accepted')
    PRINT 'OK   duplicate packet itself is kept' ELSE PRINT 'FAIL duplicate packet lost';

-- ---------- Άγνωστος κωδικός OBIS: μερική αποδοχή, και όριο 10:15:00 -> 10:15 ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-21T10:15:00Z", "Cell_Signal_Strength_dBm": -85, "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8300.25, "unit": "kWh"}, {"obis": "99.9.9", "value": 1, "unit": "x"}]}';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Partially accepted' AND ReadingsStored = 1 AND ErrorMessage LIKE N'%99.9.9%')
    PRINT 'OK   unknown OBIS -> Partially accepted, 1 stored, code listed' ELSE PRINT 'FAIL unknown OBIS result';
IF EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-21 10:15:00' AND PacketID = @pid)
    PRINT 'OK   10:15:00 lands in the 10:15 slot' ELSE PRINT 'FAIL slot 10:15';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE ObisCode = '99.9.9')
    PRINT 'OK   unknown OBIS not stored' ELSE PRINT 'FAIL unknown OBIS stored';

-- ---------- Σπασμένο JSON ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'this is { not json';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Malformed' AND ReadingsStored = 0 AND ErrorMessage IS NOT NULL)
    PRINT 'OK   broken JSON -> Malformed with message' ELSE PRINT 'FAIL malformed result';
IF EXISTS (SELECT 1 FROM TELEMETRY_PACKET WHERE PacketID = @pid AND RawPayload = N'this is { not json' AND MeterID IS NULL)
    PRINT 'OK   malformed packet stored as received' ELSE PRINT 'FAIL malformed packet not stored';
IF EXISTS (SELECT 1 FROM EVENT WHERE PacketID = @pid AND EventType = 'Malformed packet' AND Status = 'Open')
    PRINT 'OK   malformed packet -> EVENT' ELSE PRINT 'FAIL malformed event';

-- ---------- Λείπει ώρα, λείπει NetworkID, λείπει πίνακας ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Telemetry_Payload": [{"obis": "1.8.0", "value": 1}]}';
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Malformed' AND ErrorMessage IS NOT NULL) PRINT 'OK   missing timestamp -> Malformed' ELSE PRINT 'FAIL missing timestamp';
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Transmission_Timestamp": "2026-11-21T11:00:00Z", "Telemetry_Payload": [{"obis": "1.8.0", "value": 1}]}';
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Malformed' AND ErrorMessage IS NOT NULL) PRINT 'OK   missing network id -> Malformed' ELSE PRINT 'FAIL missing network id';
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T11:00:00Z"}';
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Malformed' AND ReadingsStored = 0)
   AND NOT EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 1 AND IntervalStart = '2026-11-21 11:00:00')
    PRINT 'OK   missing Telemetry_Payload -> Malformed, nothing stored' ELSE PRINT 'FAIL missing payload';
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, NULL;
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Malformed' AND PacketID IS NOT NULL) PRINT 'OK   NULL payload still recorded (Malformed)' ELSE PRINT 'FAIL NULL payload';

-- ---------- Άγνωστος μετρητής ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-XXX-0001", "Transmission_Timestamp": "2026-11-21T12:00:00Z", "Telemetry_Payload": [{"obis": "1.8.0", "value": 5, "unit": "kWh"}]}';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Unknown meter' AND ReadingsStored = 0)
   AND EXISTS (SELECT 1 FROM TELEMETRY_PACKET WHERE PacketID = @pid AND MeterID IS NULL AND ReceivedNetworkID = 'EAC-XXX-0001')
    PRINT 'OK   unknown network id -> Unknown meter, packet kept' ELSE PRINT 'FAIL unknown meter';
IF EXISTS (SELECT 1 FROM EVENT WHERE PacketID = @pid AND EventType = 'Unmatched packet' AND Severity = 'Warning' AND Status = 'Open')
    PRINT 'OK   unknown meter -> Unmatched packet EVENT' ELSE PRINT 'FAIL unmatched event';

-- ---------- Ανενεργός μετρητής (X2) ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-LIM-2002", "Transmission_Timestamp": "2026-11-21T12:00:00Z", "Telemetry_Payload": [{"obis": "1.8.0", "value": 5, "unit": "kWh"}]}';
SET @pid = (SELECT PacketID FROM @r);
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Meter not active' AND ReadingsStored = 0)
   AND EXISTS (SELECT 1 FROM TELEMETRY_PACKET WHERE PacketID = @pid AND MeterID = 5)
    PRINT 'OK   inactive meter -> Meter not active, MeterID set' ELSE PRINT 'FAIL inactive meter';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 5 AND IntervalStart >= '2026-11-21')
    PRINT 'OK   inactive meter -> no readings stored' ELSE PRINT 'FAIL inactive meter readings';
IF EXISTS (SELECT 1 FROM EVENT WHERE PacketID = @pid AND MeterID = 5 AND EventType = 'Packet from inactive meter')
    PRINT 'OK   inactive meter -> EVENT' ELSE PRINT 'FAIL inactive event';

-- ---------- Άδειος πίνακας, κακή τιμή, επανάληψη μέσα στο πακέτο ----------
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T13:00:00Z", "Telemetry_Payload": []}';
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Partially accepted' AND ReadingsStored = 0 AND ErrorMessage IS NOT NULL)
    PRINT 'OK   empty payload -> Partially accepted, 0 stored' ELSE PRINT 'FAIL empty payload';
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "2026-11-21T13:14:59Z", "Telemetry_Payload": [{"obis": "1.8.0", "value": "abc"}, {"obis": "32.7.0", "value": 230.1}, {"obis": "32.7.0", "value": 231.0}]}';
IF EXISTS (SELECT 1 FROM @r WHERE IngestStatus = 'Partially accepted' AND ReadingsStored = 1)
   AND EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 1 AND ObisCode = '32.7.0' AND IntervalStart = '2026-11-21 13:00:00' AND ReceivedValue = 230.1)
    PRINT 'OK   non-numeric value and repeated code skipped; 13:14:59 -> 13:00 slot' ELSE PRINT 'FAIL bad value / repeat';

-- ---------- sp_dso_list_packets ----------
DECLARE @lp TABLE (PacketID BIGINT, ReceivedAt DATETIME2(3), TransmissionTimestamp DATETIME2(0), ReceivedNetworkID VARCHAR(40),
                   SerialNumber VARCHAR(40), NetworkType VARCHAR(20), SignalDbm SMALLINT, IngestStatus VARCHAR(18),
                   ReadingsStored INT, ErrorMessage NVARCHAR(1000));
INSERT @lp EXEC sp_dso_list_packets 7, 3;
IF (SELECT COUNT(*) FROM @lp) = 3 AND (SELECT MAX(PacketID) FROM @lp) = (SELECT MAX(PacketID) FROM TELEMETRY_PACKET)
    PRINT 'OK   list packets: @Top 3, newest included' ELSE PRINT 'FAIL list packets top';
DELETE @lp;
INSERT @lp EXEC sp_dso_list_packets 7, 50, 'Unknown meter';
IF (SELECT COUNT(*) FROM @lp) >= 2 AND NOT EXISTS (SELECT 1 FROM @lp WHERE IngestStatus <> 'Unknown meter')
   AND EXISTS (SELECT 1 FROM @lp WHERE PacketID = 864 AND SerialNumber IS NULL)
    PRINT 'OK   list packets filtered by status (base packet 864 + new one)' ELSE PRINT 'FAIL list packets filter';
DELETE @lp;
INSERT @lp EXEC sp_dso_list_packets 7, 1000, 'Accepted';
IF EXISTS (SELECT 1 FROM @lp WHERE SerialNumber = 'SN-0001' AND ReadingsStored = 2 AND TransmissionTimestamp = '2026-11-21 10:07:30')
    PRINT 'OK   list packets shows serial number and reading count' ELSE PRINT 'FAIL list packets serial/count';
BEGIN TRY EXEC sp_dso_list_packets 7, 0; PRINT 'FAIL @Top 0 accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53001 PRINT 'OK   @Top 0 -> 53001' ELSE PRINT 'FAIL top: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_packets 7, 10, 'Bogus'; PRINT 'FAIL unknown status accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53002 PRINT 'OK   unknown status -> 53002' ELSE PRINT 'FAIL status: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- sp_dso_list_raw ----------
DECLARE @lr TABLE (IntervalStart DATETIME2(0), ObisCode VARCHAR(20), Description NVARCHAR(200), Unit VARCHAR(10),
                   ReceivedValue DECIMAL(15,4), VeeStatus VARCHAR(9), PacketID BIGINT);
INSERT @lr EXEC sp_dso_list_raw 7, 1, '2026-11-21 10:00:00', '2026-11-21 10:00:00';
IF (SELECT COUNT(*) FROM @lr) = 2 AND EXISTS (SELECT 1 FROM @lr WHERE ObisCode = '32.7.0' AND Unit = 'V' AND ReceivedValue = 228.4)
    PRINT 'OK   list raw: one slot, both codes' ELSE PRINT 'FAIL list raw slot';
DELETE @lr;
INSERT @lr EXEC sp_dso_list_raw 7, 1, '2026-11-20 05:30:00', '2026-11-20 05:45:00';
IF (SELECT COUNT(*) FROM @lr) >= 2 AND NOT EXISTS (SELECT 1 FROM @lr WHERE IntervalStart < '2026-11-20 05:30:00' OR IntervalStart > '2026-11-20 05:45:00')
    PRINT 'OK   list raw: base data in period, nothing outside' ELSE PRINT 'FAIL list raw base period';
DELETE @lr;
INSERT @lr EXEC sp_dso_list_raw 7, 1, '2030-01-01', '2030-01-02';
IF NOT EXISTS (SELECT 1 FROM @lr) PRINT 'OK   list raw: empty period -> 0 rows' ELSE PRINT 'FAIL list raw empty';
BEGIN TRY EXEC sp_dso_list_raw 7, 999, '2026-11-21', '2026-11-22'; PRINT 'FAIL unknown meter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53003 PRINT 'OK   unknown meter -> 53003' ELSE PRINT 'FAIL raw meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_raw 7, 1, '2026-11-22', '2026-11-21'; PRINT 'FAIL reversed period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53004 PRINT 'OK   reversed period -> 53004' ELSE PRINT 'FAIL raw period: ' + ERROR_MESSAGE(); END CATCH;
