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

-- =====================================================================
-- DSO-2 / DSO-3: VEE, ύποπτες μετρήσεις, χειροκίνητη διόρθωση
-- Μέρος 1: τα Pending των δεδομένων βάσης (20/11 00:00-05:45, 142 γραμμές).
-- Μέρος 2: δικό μας σενάριο 22/11 για τον μετρητή 2 (spike 25.4 και κενό 10:30 -> 2.1).
-- =====================================================================
DECLARE @vr TABLE (RunID INT, Validated INT, Estimated INT, Suspect INT, Events INT);
DECLARE @vrun INT, @vval INT, @vest INT, @vsus INT, @vev INT, @vcnt INT;

BEGIN TRY EXEC sp_dso_run_vee 3, '2026-11-20 00:00:00', '2026-11-20 06:00:00'; PRINT 'FAIL consumer ran VEE'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot run VEE -> 53000' ELSE PRINT 'FAIL vee role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_run_vee 7, '2026-11-20 06:00:00', '2026-11-20 00:00:00'; PRINT 'FAIL reversed VEE period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53100 PRINT 'OK   reversed VEE period -> 53100' ELSE PRINT 'FAIL vee period: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Μέρος 1: δεδομένα βάσης ----------
INSERT @vr EXEC sp_dso_run_vee 7, '2026-11-20 00:00:00', '2026-11-20 06:00:00';
SELECT @vrun = RunID, @vval = Validated, @vest = Estimated, @vsus = Suspect, @vev = Events FROM @vr;
IF @vrun IS NOT NULL AND EXISTS (SELECT 1 FROM VEE_RUN WHERE RunID = @vrun AND FinishedAt IS NOT NULL
                                  AND PeriodFrom = '2026-11-20 00:00:00' AND PeriodTo = '2026-11-20 06:00:00')
    PRINT 'OK   VEE run recorded in VEE_RUN with FinishedAt' ELSE PRINT 'FAIL VEE_RUN row';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE IntervalStart >= '2026-11-20 00:00:00' AND IntervalStart < '2026-11-20 06:00:00' AND VeeStatus = 'Pending')
    PRINT 'OK   no Pending raw row left in the period' ELSE PRINT 'FAIL Pending rows left';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE IntervalStart >= '2026-11-20 00:00:00' AND IntervalStart < '2026-11-20 06:00:00' AND VeeStatus NOT IN ('Validated', 'Suspect'))
   AND (SELECT COUNT(*) FROM RAW_READING WHERE IntervalStart >= '2026-11-20 00:00:00' AND IntervalStart < '2026-11-20 06:00:00') = @vval + @vsus
    PRINT 'OK   every base Pending row is Validated or Suspect, counts add up' ELSE PRINT 'FAIL base row statuses vs counts';
IF @vval = (SELECT COUNT(*) FROM VALIDATED_READING WHERE RunID = @vrun AND Quality = 'Validated')
   AND @vest = (SELECT COUNT(*) FROM VALIDATED_READING WHERE RunID = @vrun AND Quality = 'Estimated')
   AND @vsus = (SELECT COUNT(*) FROM RAW_READING WHERE IntervalStart >= '2026-11-20 00:00:00' AND IntervalStart < '2026-11-20 06:00:00' AND VeeStatus = 'Suspect')
    PRINT 'OK   returned counts match the tables' ELSE PRINT 'FAIL returned counts';
IF @vest = 1 AND EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 02:30:00' AND Quality = 'Estimated' AND RunID = @vrun)
    PRINT 'OK   base gap at 02:30 (meter 1) estimated' ELSE PRINT 'FAIL base gap estimate';
IF EXISTS (SELECT 1 FROM READING_EDIT WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 02:30:00' AND EditNo = 1
              AND Origin = 'Automatic estimate' AND OldValue IS NULL AND EditedBy IS NULL
              AND RuleID = (SELECT RuleID FROM VEE_RULE WHERE RuleType = 'LinearEstimate'))
    PRINT 'OK   estimate has READING_EDIT (Automatic estimate, rule LinearEstimate, OldValue NULL)' ELSE PRINT 'FAIL estimate READING_EDIT';
IF EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 04:00:00' AND VeeStatus = 'Suspect')
   AND NOT EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 04:00:00')
    PRINT 'OK   base spike 25.4 at 04:00 (meter 1) is Suspect, no validated row' ELSE PRINT 'FAIL base spike';
IF EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Suspect reading' AND MeterID = 1 AND OccurredAt = '2026-11-20 04:00:00' AND Description LIKE N'%Spike%')
    PRINT 'OK   Suspect reading EVENT with reason' ELSE PRINT 'FAIL suspect event';
IF EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 4 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 05:45:00' AND Value = 0.6966 AND Quality = 'Validated')
   AND EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 00:00:00' AND Value = 0.1748)
    PRINT 'OK   cumulative counter becomes 15-minute energy (counter minus previous counter)' ELSE PRINT 'FAIL energy values';
IF EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '32.7.0' AND IntervalStart = '2026-11-20 00:00:00' AND Value = 227.2)
    PRINT 'OK   instantaneous voltage keeps the measured value' ELSE PRINT 'FAIL voltage value';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 3 AND IntervalStart >= '2026-11-20 00:00:00' AND IntervalStart < '2026-11-20 06:00:00' AND VeeStatus = 'Suspect')
    PRINT 'OK   quiet PV counter (meter 3, 2.8.0) is not flagged as spike' ELSE PRINT 'FAIL false spike on meter 3';
IF @vev >= @vsus AND (SELECT COUNT(*) FROM EVENT WHERE EventType IN ('Suspect reading', 'Undervoltage', 'Overvoltage')
                       AND OccurredAt >= '2026-11-20 00:00:00' AND OccurredAt < '2026-11-20 06:00:00') >= @vev
    PRINT 'OK   events written (suspect readings and voltage band)' ELSE PRINT 'FAIL events';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'VEE_RUN' AND ObjectID = CAST(@vrun AS VARCHAR(100)) AND Action = 'Run VEE' AND PerformedBy = 7)
    PRINT 'OK   VEE audit row written' ELSE PRINT 'FAIL VEE audit row';

DELETE @vr;
INSERT @vr EXEC sp_dso_run_vee 7, '2026-11-20 00:00:00', '2026-11-20 06:00:00';
IF EXISTS (SELECT 1 FROM @vr WHERE Validated = 0 AND Estimated = 0 AND Suspect = 0 AND Events = 0)
    PRINT 'OK   second VEE run finds nothing to do' ELSE PRINT 'FAIL second run';

BEGIN TRY UPDATE VALIDATED_READING SET Value = 999 WHERE MeterID = 4 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-20 05:45:00'; PRINT 'FAIL validated reading was updated'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 50005 PRINT 'OK   UPDATE on VALIDATED_READING refused (immutable)' ELSE PRINT 'FAIL immutability: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Μέρος 2: σενάριο 22/11, μετρητής 2 (EAC-NIC-1002), κωδικός 1.8.0 ----------
-- Μετρητές 8400.0, 8401.8, 8403.8, 8405.7 -> ενέργειες 1.8, 2.0, 1.9; μετά +25.4 (spike);
-- μετά 2.0, 1.9, 2.0, 1.8, 2.0 στις 10:15; λείπει το 10:30; στις 10:45 μετρητής +4.3 (= 2.1 + 2.2).
DELETE @r;
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T08:00:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8400.0, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T08:15:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8401.8, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T08:30:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8403.8, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T08:45:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8405.7, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T09:00:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8431.1, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T09:15:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8433.1, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T09:30:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8435.0, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T09:45:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8437.0, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T10:00:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8438.8, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T10:15:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8440.8, "unit": "kWh"}]}';
INSERT @r EXEC sp_dso_ingest_packet 7, N'{"Meter_Network_ID": "EAC-NIC-1002", "Transmission_Timestamp": "2026-11-22T10:45:00Z", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 8445.1, "unit": "kWh"}]}';
SELECT @vcnt = COUNT(*) FROM RAW_READING WHERE MeterID = 2 AND IntervalStart >= '2026-11-22' AND IntervalStart < '2026-11-23' AND VeeStatus = 'Pending';
IF @vcnt = 11 PRINT 'OK   scenario: 11 Pending readings ingested for 22/11' ELSE PRINT 'FAIL scenario ingest';

DELETE @vr;
INSERT @vr EXEC sp_dso_run_vee 7, '2026-11-22 00:00:00', '2026-11-23 00:00:00';
IF EXISTS (SELECT 1 FROM @vr WHERE Validated = 9 AND Estimated = 1 AND Suspect = 1 AND Events = 1)
    PRINT 'OK   scenario run: 9 validated, 1 estimated, 1 suspect, 1 event' ELSE PRINT 'FAIL scenario counts';
IF EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00' AND VeeStatus = 'Suspect')
   AND NOT EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00')
    PRINT 'OK   spike 25.4 -> Suspect, no validated row' ELSE PRINT 'FAIL scenario spike';
IF (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart BETWEEN '2026-11-22 08:15:00' AND '2026-11-22 08:45:00'
        AND Quality = 'Validated' AND Value IN (1.8, 2.0, 1.9)) = 3
    PRINT 'OK   deltas 1.8, 2.0, 1.9 validated' ELSE PRINT 'FAIL scenario deltas';
IF NOT EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 08:00:00')
   AND EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 08:00:00' AND VeeStatus = 'Validated')
    PRINT 'OK   first reading after a long gap is a baseline (no energy, raw Validated)' ELSE PRINT 'FAIL baseline';
IF EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 10:30:00' AND Quality = 'Estimated' AND Value = 2.1)
   AND EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 10:45:00' AND Quality = 'Validated' AND Value = 2.2)
    PRINT 'OK   gap at 10:30 between 2.0 and 2.2 -> Estimated 2.1, next value 2.2' ELSE PRINT 'FAIL scenario gap';
IF EXISTS (SELECT 1 FROM READING_EDIT WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 10:30:00' AND NewValue = 2.1
              AND Origin = 'Automatic estimate' AND OldValue IS NULL AND EditedBy IS NULL AND RuleID IS NOT NULL)
    PRINT 'OK   estimate recorded in READING_EDIT' ELSE PRINT 'FAIL scenario READING_EDIT';

-- ---------- DSO-3: λίστα ύποπτων ----------
DECLARE @ls TABLE (MeterID INT, SerialNumber NVARCHAR(100), ObisCode VARCHAR(20), IntervalStart DATETIME2(0), ReceivedValue DECIMAL(15,4),
                   ComputedValue DECIMAL(16,4), PrevIntervalStart DATETIME2(0), PrevReceived DECIMAL(15,4), PrevValidatedValue DECIMAL(15,4),
                   NextIntervalStart DATETIME2(0), NextReceived DECIMAL(15,4), Reason NVARCHAR(300));
BEGIN TRY EXEC sp_dso_list_suspect 3; PRINT 'FAIL consumer listed suspect'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list suspect -> 53000' ELSE PRINT 'FAIL suspect role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_suspect 7, 999; PRINT 'FAIL unknown meter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53110 PRINT 'OK   list suspect unknown meter -> 53110' ELSE PRINT 'FAIL suspect meter: ' + ERROR_MESSAGE(); END CATCH;
INSERT @ls EXEC sp_dso_list_suspect 7, 2;
IF (SELECT COUNT(*) FROM @ls) = 1
   AND EXISTS (SELECT 1 FROM @ls WHERE IntervalStart = '2026-11-22 09:00:00' AND ReceivedValue = 8431.1 AND ComputedValue = 25.4
                  AND PrevIntervalStart = '2026-11-22 08:45:00' AND PrevReceived = 8405.7 AND PrevValidatedValue = 1.9
                  AND NextIntervalStart = '2026-11-22 09:15:00' AND NextReceived = 8433.1 AND Reason LIKE N'%Spike%')
    PRINT 'OK   list suspect: spike with neighbours and reason' ELSE PRINT 'FAIL list suspect content';
DELETE @ls;
INSERT @ls EXEC sp_dso_list_suspect 7;
IF EXISTS (SELECT 1 FROM @ls WHERE MeterID = 1 AND IntervalStart = '2026-11-20 04:00:00') AND EXISTS (SELECT 1 FROM @ls WHERE MeterID = 2 AND IntervalStart = '2026-11-22 09:00:00')
    PRINT 'OK   list suspect without meter shows all meters' ELSE PRINT 'FAIL list suspect all';

-- ---------- DSO-3: διόρθωση ----------
DECLARE @ed TABLE (MeterID INT, ObisCode VARCHAR(20), IntervalStart DATETIME2(0), OldValue DECIMAL(15,4), NewValue DECIMAL(15,4), EditNo SMALLINT);
BEGIN TRY EXEC sp_dso_edit_reading 3, 2, '1.8.0', '2026-11-22 09:00:00', 2.0, N'δοκιμή'; PRINT 'FAIL consumer edited a reading'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot edit -> 53000' ELSE PRINT 'FAIL edit role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2026-11-22 08:15:00', 2.0, N'δοκιμή'; PRINT 'FAIL edited a non-suspect reading'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53121 PRINT 'OK   non-suspect reading cannot be edited -> 53121' ELSE PRINT 'FAIL edit status: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2030-01-01 00:00:00', 2.0, N'δοκιμή'; PRINT 'FAIL edited a missing reading'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53120 PRINT 'OK   missing reading -> 53120' ELSE PRINT 'FAIL edit missing: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2026-11-22 09:00:00', 999, N'δοκιμή'; PRINT 'FAIL out-of-range value accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53122 PRINT 'OK   value above MaxValid -> 53122' ELSE PRINT 'FAIL edit range: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2026-11-22 09:00:00', 2.0, N'  '; PRINT 'FAIL empty reason accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53123 PRINT 'OK   empty reason -> 53123' ELSE PRINT 'FAIL edit reason: ' + ERROR_MESSAGE(); END CATCH;

INSERT @ed EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2026-11-22 09:00:00', 2.0, N'Σφάλμα ανάγνωσης: ο μετρητής έδειξε 25.4 αντί για περίπου 2.0';
IF EXISTS (SELECT 1 FROM @ed WHERE OldValue = 25.4 AND NewValue = 2.0 AND EditNo = 1)
    PRINT 'OK   edit returns old value 25.4, new 2.0, EditNo 1' ELSE PRINT 'FAIL edit result';
IF EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00' AND Quality = 'Edited' AND Value = 2.0)
   AND EXISTS (SELECT 1 FROM RAW_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00' AND VeeStatus = 'Validated')
    PRINT 'OK   edited reading: VALIDATED Quality Edited, raw Validated' ELSE PRINT 'FAIL edited reading rows';
IF EXISTS (SELECT 1 FROM READING_EDIT WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00' AND EditNo = 1
              AND Origin = 'Manual edit' AND OldValue = 25.4 AND NewValue = 2.0 AND EditedBy = 7 AND RuleID IS NULL AND Reason LIKE N'%25.4%')
    PRINT 'OK   READING_EDIT Manual edit keeps old value, new value, user, reason' ELSE PRINT 'FAIL manual READING_EDIT';
IF EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Suspect reading' AND MeterID = 2 AND OccurredAt = '2026-11-22 09:00:00' AND Status = 'Closed')
   AND EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'VALIDATED_READING' AND Action = 'Manual edit' AND PerformedBy = 7 AND ObjectID = '2/1.8.0/2026-11-22 09:00:00')
    PRINT 'OK   suspect event closed, audit row written' ELSE PRINT 'FAIL edit event/audit';
DELETE @ls;
INSERT @ls EXEC sp_dso_list_suspect 7, 2;
IF NOT EXISTS (SELECT 1 FROM @ls) PRINT 'OK   edited reading leaves the suspect list' ELSE PRINT 'FAIL suspect list after edit';
BEGIN TRY EXEC sp_dso_edit_reading 7, 2, '1.8.0', '2026-11-22 09:00:00', 2.1, N'ξανά'; PRINT 'FAIL edited twice'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53121 PRINT 'OK   second edit refused (no longer Suspect) -> 53121' ELSE PRINT 'FAIL second edit: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY UPDATE VALIDATED_READING SET Value = 3 WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart = '2026-11-22 09:00:00'; PRINT 'FAIL edited reading was updated'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 50005 PRINT 'OK   UPDATE on an edited VALIDATED_READING still refused' ELSE PRINT 'FAIL immutability after edit: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- DSO-3: λίστα runs ----------
DECLARE @vlr TABLE (RunID INT, PeriodFrom DATETIME2(0), PeriodTo DATETIME2(0), StartedAt DATETIME2(0), FinishedAt DATETIME2(0),
                    Validated INT, Estimated INT, Edited INT, SuspectNow INT);
BEGIN TRY EXEC sp_dso_list_runs 3; PRINT 'FAIL consumer listed runs'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list runs -> 53000' ELSE PRINT 'FAIL runs role: ' + ERROR_MESSAGE(); END CATCH;
INSERT @vlr EXEC sp_dso_list_runs 7;
IF EXISTS (SELECT 1 FROM @vlr WHERE RunID = @vrun AND Validated = @vval AND Estimated = @vest AND SuspectNow = @vsus)
   AND (SELECT TOP 1 RunID FROM @vlr ORDER BY RunID DESC) > @vrun
   AND EXISTS (SELECT 1 FROM @vlr WHERE PeriodFrom = '2026-11-22 00:00:00' AND Estimated = 1 AND Edited = 1)
    PRINT 'OK   list runs: counts per run, newest first' ELSE PRINT 'FAIL list runs';


-- =====================================================================
-- DSO-4: aggregates. Χρησιμοποιεί τα επικυρωμένα δεδομένα των 20/11 και 22/11 παραπάνω.
-- Μεταβλητές με πρόθεμα @d4_ (το αρχείο είναι ένα batch). Τρέχει μία φορά ανά καθαρή βάση.
-- =====================================================================
DECLARE @d4_agg TABLE (Day DATE, MeterRows INT, TransformerRows INT, MonthRows INT, YearRows INT);
DECLARE @d4_pend TABLE (DaysBuilt INT, MeterRows INT, TransformerRows INT, MonthRows INT, YearRows INT);
DECLARE @d4_sum DECIMAL(18,4), @d4_cnt INT, @d4_est INT, @d4_msum DECIMAL(18,4), @d4_mcnt INT, @d4_at DATETIME2(0);

-- ---------- Ρόλος ----------
BEGIN TRY EXEC sp_dso_build_aggregates 3, '2026-11-22'; PRINT 'FAIL consumer built aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot build aggregates -> 53000' ELSE PRINT 'FAIL build role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_build_aggregates_pending 3; PRINT 'FAIL consumer built pending aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot build pending aggregates -> 53000' ELSE PRINT 'FAIL pending role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_aggregates 3; PRINT 'FAIL consumer listed aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list aggregates -> 53000' ELSE PRINT 'FAIL list agg role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_transformer_aggregates 3; PRINT 'FAIL consumer listed transformer aggregates'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list transformer aggregates -> 53000' ELSE PRINT 'FAIL list tr agg role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_build_aggregates 7, NULL; PRINT 'FAIL NULL day accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53300 PRINT 'OK   NULL day -> 53300' ELSE PRINT 'FAIL null day: ' + ERROR_MESSAGE(); END CATCH;

-- ---------- Ημέρα 22/11 (μετρητής 2, 1.8.0, φύλλο 5) ----------
SELECT @d4_sum = SUM(Value), @d4_cnt = COUNT(*), @d4_est = SUM(CASE WHEN Quality = 'Estimated' THEN 1 ELSE 0 END)
  FROM VALIDATED_READING WHERE MeterID = 2 AND ObisCode = '1.8.0' AND IntervalStart >= '2026-11-22' AND IntervalStart < '2026-11-23';
INSERT @d4_agg EXEC sp_dso_build_aggregates 7, '2026-11-22';
IF EXISTS (SELECT 1 FROM @d4_agg WHERE Day = '2026-11-22' AND MeterRows = 1 AND TransformerRows = 1 AND MonthRows = 0 AND YearRows = 0)
    PRINT 'OK   build 22/11: 1 meter row, 1 transformer row, no month/year' ELSE PRINT 'FAIL build 22/11 counts';
IF EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-22'
              AND SumValue = @d4_sum AND ReadingCount = @d4_cnt AND EstimatedCount = @d4_est AND @d4_est = 1 AND @d4_cnt > 5)
    PRINT 'OK   meter aggregate = sum of validated values, counts match (1 estimated)' ELSE PRINT 'FAIL meter aggregate values';
IF EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE WHERE TransformerID = 5 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-22'
              AND SumValue = @d4_sum AND MeterCount = 1)
    PRINT 'OK   leaf transformer aggregate = sum of its meters' ELSE PRINT 'FAIL leaf aggregate';
IF NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE a JOIN TRANSFORMER c ON c.ParentTransformerID = a.TransformerID WHERE a.PeriodStart = '2026-11-22')
    PRINT 'OK   no aggregate on a non-leaf transformer' ELSE PRINT 'FAIL non-leaf aggregate';
IF NOT EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE PeriodType IN ('Month', 'Year') AND PeriodStart >= '2026-01-01')
    PRINT 'OK   no month/year rows while the month is still open' ELSE PRINT 'FAIL premature month';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'AGGREGATE' AND ObjectID = '2026-11-22' AND Action = 'Build aggregates' AND PerformedBy = 7)
    PRINT 'OK   audit row written' ELSE PRINT 'FAIL aggregate audit';

-- ---------- Τελικό: δεύτερη κλήση δεν γράφει τίποτα ----------
SELECT @d4_at = ComputedAt FROM TRANSFORMER_AGGREGATE WHERE TransformerID = 5 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-22';
DELETE @d4_agg;
INSERT @d4_agg EXEC sp_dso_build_aggregates 7, '2026-11-22';
IF EXISTS (SELECT 1 FROM @d4_agg WHERE MeterRows = 0 AND TransformerRows = 0 AND MonthRows = 0 AND YearRows = 0)
   AND (SELECT COUNT(*) FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart = '2026-11-22') = 1
   AND EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE WHERE TransformerID = 5 AND PeriodType = 'Day' AND PeriodStart = '2026-11-22' AND SumValue = @d4_sum AND ComputedAt = @d4_at)
    PRINT 'OK   second build inserts nothing (aggregates are final)' ELSE PRINT 'FAIL aggregates not final';

-- ---------- Μήνας και έτος με force ----------
SELECT @d4_msum = SUM(SumValue), @d4_mcnt = SUM(ReadingCount) FROM METER_AGGREGATE
 WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart >= '2026-11-01' AND PeriodStart <= '2026-11-22';
DELETE @d4_agg;
INSERT @d4_agg EXEC sp_dso_build_aggregates 7, '2026-11-22', 1, 1;
IF EXISTS (SELECT 1 FROM @d4_agg WHERE MonthRows >= 2 AND YearRows >= 2)
    PRINT 'OK   force month/year writes meter and transformer rows' ELSE PRINT 'FAIL force counts';
IF EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Month' AND PeriodStart = '2026-11-01'
              AND SumValue = @d4_msum AND ReadingCount = @d4_mcnt)
   AND EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Year' AND PeriodStart = '2026-01-01' AND SumValue = @d4_msum)
    PRINT 'OK   month row = sum of the month''s day rows, year row starts 2026-01-01' ELSE PRINT 'FAIL month/year values';
IF EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE t WHERE t.TransformerID = 5 AND t.ObisCode = '1.8.0' AND t.PeriodType = 'Month' AND t.PeriodStart = '2026-11-01'
              AND t.SumValue = (SELECT SUM(SumValue) FROM TRANSFORMER_AGGREGATE WHERE TransformerID = 5 AND ObisCode = '1.8.0' AND PeriodType = 'Day' AND PeriodStart >= '2026-11-01' AND PeriodStart <= '2026-11-22'))
   AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE a JOIN TRANSFORMER c ON c.ParentTransformerID = a.TransformerID WHERE a.PeriodType IN ('Month', 'Year'))
    PRINT 'OK   leaf month row = sum of its day rows, no month/year row on a non-leaf' ELSE PRINT 'FAIL transformer month';
DELETE @d4_agg;
INSERT @d4_agg EXEC sp_dso_build_aggregates 7, '2026-11-22', 1, 1;
IF EXISTS (SELECT 1 FROM @d4_agg WHERE MonthRows = 0 AND YearRows = 0)
    PRINT 'OK   month/year rows are final too (second force writes nothing)' ELSE PRINT 'FAIL month not final';

-- ---------- Λίστες ----------
DECLARE @d4_la TABLE (MeterID INT, SerialNumber NVARCHAR(100), ObisCode VARCHAR(20), PeriodType VARCHAR(5), PeriodStart DATE,
                      SumValue DECIMAL(18,4), ReadingCount INT, EstimatedCount INT, TransformerID INT);
DECLARE @d4_lt TABLE (TransformerID INT, Name NVARCHAR(100), ObisCode VARCHAR(20), PeriodType VARCHAR(5), PeriodStart DATE,
                      SumValue DECIMAL(18,4), MeterCount INT, ComputedAt DATETIME2(0));
INSERT @d4_la EXEC sp_dso_list_aggregates 7, 2, 'Day', '2026-11-22', '2026-11-22';
IF (SELECT COUNT(*) FROM @d4_la) = 1 AND EXISTS (SELECT 1 FROM @d4_la WHERE SumValue = @d4_sum AND TransformerID = 5)
    PRINT 'OK   list aggregates for one meter and one day' ELSE PRINT 'FAIL list aggregates';
DELETE @d4_la;
INSERT @d4_la EXEC sp_dso_list_aggregates 7, NULL, 'Month';
IF EXISTS (SELECT 1 FROM @d4_la WHERE MeterID = 2 AND PeriodType = 'Month') PRINT 'OK   list aggregates Month for all meters' ELSE PRINT 'FAIL list month';
INSERT @d4_lt EXEC sp_dso_list_transformer_aggregates 7, 5, 'Day', '2026-11-22', '2026-11-22';
IF EXISTS (SELECT 1 FROM @d4_lt WHERE SumValue = @d4_sum AND MeterCount = 1) PRINT 'OK   list transformer aggregates' ELSE PRINT 'FAIL list transformer aggregates';
BEGIN TRY EXEC sp_dso_list_aggregates 7, NULL, 'Week'; PRINT 'FAIL bad period type accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53302 PRINT 'OK   bad period type -> 53302' ELSE PRINT 'FAIL period type: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_aggregates 7, 999; PRINT 'FAIL unknown meter accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53303 PRINT 'OK   unknown meter -> 53303' ELSE PRINT 'FAIL agg meter: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_aggregates 7, NULL, 'Day', '2026-11-23', '2026-11-22'; PRINT 'FAIL reversed period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53304 PRINT 'OK   reversed period -> 53304' ELSE PRINT 'FAIL agg period: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================
-- DSO-5: αναλυτικά. Σενάριο 23/11: μετρητής 4 (μετασχηματιστής 4) με χαμηλή τάση 08:15, υψηλή 08:30,
-- ανισορροπία ρευμάτων 08:45. Μετρητής 1 (ίδιος μετασχηματιστής) με σταθερό μετρητή: 9 διαστήματα
-- μηδενικής κατανάλωσης 08:15-10:15, ενώ ο μετρητής 4 καταναλώνει 0.5 kWh ανά διάστημα.
-- =====================================================================
DECLARE @d4_ev TABLE (Undervoltage INT, Overvoltage INT, PhaseUnbalance INT, SuspectedTheft INT, Total INT);
DECLARE @d4_r2 TABLE (PacketID BIGINT, IngestStatus VARCHAR(18), ReadingsStored INT, ErrorMessage NVARCHAR(1000));
DECLARE @d4_vr TABLE (RunID INT, Validated INT, Estimated INT, Suspect INT, Events INT);
DECLARE @d4_i INT = 0, @d4_p NVARCHAR(MAX), @d4_ts VARCHAR(30), @d4_extra NVARCHAR(500), @d4_n INT;

BEGIN TRY EXEC sp_dso_detect_events 3, '2026-11-23', '2026-11-24'; PRINT 'FAIL consumer detected events'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot detect events -> 53000' ELSE PRINT 'FAIL detect role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_events 3; PRINT 'FAIL consumer listed events'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot list events -> 53000' ELSE PRINT 'FAIL list events role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_losses_report 3, '2026-11-22', '2026-11-23'; PRINT 'FAIL consumer ran losses report'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53000 PRINT 'OK   consumer cannot run losses report -> 53000' ELSE PRINT 'FAIL losses role: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_detect_events 7, '2026-11-24', '2026-11-23'; PRINT 'FAIL reversed detect period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53310 PRINT 'OK   reversed detect period -> 53310' ELSE PRINT 'FAIL detect period: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_detect_events 7, '2026-11-01', '2026-12-15'; PRINT 'FAIL 44-day period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53311 PRINT 'OK   period over 31 days -> 53311' ELSE PRINT 'FAIL detect long: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_losses_report 7, '2026-11-23', '2026-11-22'; PRINT 'FAIL reversed losses period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53312 PRINT 'OK   reversed losses period -> 53312' ELSE PRINT 'FAIL losses period: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_events 7, 'Done'; PRINT 'FAIL bad event status accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53320 PRINT 'OK   bad event status -> 53320' ELSE PRINT 'FAIL event status: ' + ERROR_MESSAGE(); END CATCH;

-- Δεδομένα σεναρίου: 10 πακέτα ανά μετρητή (08:00-10:15)
WHILE @d4_i < 10
BEGIN
    SET @d4_ts = CONVERT(VARCHAR(19), DATEADD(MINUTE, 15 * @d4_i, CAST('2026-11-23T08:00:00' AS DATETIME2(0))), 126) + 'Z';
    -- μετρητής 1: σταθερός μετρητής 14500.0
    SET @d4_p = CONCAT(N'{"Meter_Network_ID": "EAC-NIC-1001", "Transmission_Timestamp": "', @d4_ts,
                       N'", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": 14500.0, "unit": "kWh"}]}');
    INSERT @d4_r2 EXEC sp_dso_ingest_packet 7, @d4_p;
    -- μετρητής 4: +0.5 kWh ανά διάστημα, και ειδικές τιμές στα 08:15, 08:30, 08:45
    SET @d4_extra = CASE @d4_i
        WHEN 1 THEN N', {"obis": "32.7.0", "value": 190.0, "unit": "V"}'
        WHEN 2 THEN N', {"obis": "52.7.0", "value": 260.0, "unit": "V"}'
        WHEN 3 THEN N', {"obis": "31.7.0", "value": 30.0, "unit": "A"}, {"obis": "51.7.0", "value": 10.0, "unit": "A"}, {"obis": "71.7.0", "value": 20.0, "unit": "A"}'
        ELSE N'' END;
    SET @d4_p = CONCAT(N'{"Meter_Network_ID": "EAC-NIC-1003", "Transmission_Timestamp": "', @d4_ts,
                       N'", "Network_Type": "NB-IoT", "Telemetry_Payload": [{"obis": "1.8.0", "value": ',
                       CONVERT(NVARCHAR(20), 5000.0 + 0.5 * @d4_i), N', "unit": "kWh"}', @d4_extra, N']}');
    INSERT @d4_r2 EXEC sp_dso_ingest_packet 7, @d4_p;
    SET @d4_i += 1;
END;
IF (SELECT COUNT(*) FROM @d4_r2 WHERE IngestStatus = 'Accepted') = 20
    PRINT 'OK   analytics scenario: 20 packets accepted' ELSE PRINT 'FAIL analytics scenario ingest';
INSERT @d4_vr EXEC sp_dso_run_vee 7, '2026-11-23 00:00:00', '2026-11-24 00:00:00';
IF NOT EXISTS (SELECT 1 FROM RAW_READING WHERE IntervalStart >= '2026-11-23' AND IntervalStart < '2026-11-24' AND VeeStatus = 'Pending')
   AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart >= '2026-11-23' AND IntervalStart < '2026-11-24' AND Value = 0) = 9
   AND (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID = 4 AND ObisCode = '1.8.0' AND IntervalStart >= '2026-11-23' AND IntervalStart < '2026-11-24' AND Value = 0.5) = 9
    PRINT 'OK   scenario validated: meter 1 nine zero intervals, meter 4 nine intervals of 0.5' ELSE PRINT 'FAIL scenario VEE';

-- Πρώτη ανίχνευση: ανισορροπία και κλοπή είναι καινούργια. Η τάση μπορεί να την έγραψε ήδη το VEE.
INSERT @d4_ev EXEC sp_dso_detect_events 7, '2026-11-23 00:00:00', '2026-11-24 00:00:00';
IF EXISTS (SELECT 1 FROM @d4_ev WHERE PhaseUnbalance = 1 AND SuspectedTheft = 1)
    PRINT 'OK   detect: 1 phase unbalance, 1 suspected theft' ELSE PRINT 'FAIL detect first run';
IF (SELECT COUNT(*) FROM EVENT WHERE EventType = 'Undervoltage' AND MeterID = 4 AND OccurredAt = '2026-11-23 08:15:00') = 1
   AND (SELECT COUNT(*) FROM EVENT WHERE EventType = 'Overvoltage' AND MeterID = 4 AND OccurredAt = '2026-11-23 08:30:00') = 1
    PRINT 'OK   under/over-voltage: exactly one event each, no duplicate of the VEE ones' ELSE PRINT 'FAIL voltage events after first detect';
IF EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Phase unbalance' AND MeterID = 4 AND OccurredAt = '2026-11-23 08:45:00' AND Severity = 'Warning' AND Status = 'Open')
   AND EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Suspected theft' AND MeterID = 1 AND OccurredAt = '2026-11-23 08:15:00' AND Severity = 'Critical' AND Status = 'Open')
    PRINT 'OK   unbalance on meter 4 at 08:45, theft on meter 1 from 08:15' ELSE PRINT 'FAIL unbalance/theft events';
IF NOT EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Suspected theft' AND MeterID = 4)
    PRINT 'OK   the normal meter is not flagged for theft' ELSE PRINT 'FAIL theft false positive';

-- Δεύτερη ανίχνευση, αφού σβήσουμε τα συμβάντα τάσης (του VEE ή δικά μας): τα ξαναγράφει ο κανόνας.
DELETE EVENT WHERE EventType IN ('Undervoltage', 'Overvoltage') AND MeterID = 4 AND OccurredAt >= '2026-11-23' AND OccurredAt < '2026-11-24';
DELETE @d4_ev;
INSERT @d4_ev EXEC sp_dso_detect_events 7, '2026-11-23 00:00:00', '2026-11-24 00:00:00';
IF EXISTS (SELECT 1 FROM @d4_ev WHERE Undervoltage = 1 AND Overvoltage = 1 AND PhaseUnbalance = 0 AND SuspectedTheft = 0 AND Total = 2)
   AND EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Undervoltage' AND MeterID = 4 AND OccurredAt = '2026-11-23 08:15:00' AND Description LIKE N'%190%')
   AND EXISTS (SELECT 1 FROM EVENT WHERE EventType = 'Overvoltage' AND MeterID = 4 AND OccurredAt = '2026-11-23 08:30:00' AND Description LIKE N'%260%')
    PRINT 'OK   rerun: 1 undervoltage (190 V) and 1 overvoltage (260 V) created, nothing else duplicated' ELSE PRINT 'FAIL detect second run';

-- Τρίτη ανίχνευση: τίποτα νέο
SELECT @d4_n = COUNT(*) FROM EVENT;
DELETE @d4_ev;
INSERT @d4_ev EXEC sp_dso_detect_events 7, '2026-11-23 00:00:00', '2026-11-24 00:00:00';
IF EXISTS (SELECT 1 FROM @d4_ev WHERE Total = 0) AND (SELECT COUNT(*) FROM EVENT) = @d4_n
    PRINT 'OK   third run: 0 new events (no duplicates)' ELSE PRINT 'FAIL detect duplicates';
IF EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ObjectType = 'EVENT' AND Action = 'Detect events' AND PerformedBy = 7)
    PRINT 'OK   detect audit row written' ELSE PRINT 'FAIL detect audit';

-- Λίστα συμβάντων
DECLARE @d4_le TABLE (EventID BIGINT, EventType VARCHAR(30), Severity VARCHAR(8), Description NVARCHAR(1000), OccurredAt DATETIME2(0),
                      Status VARCHAR(11), MeterID INT, SerialNumber NVARCHAR(100), PacketID BIGINT, TaskID INT);
INSERT @d4_le EXEC sp_dso_list_events 7, 'Open', 'Suspected theft';
IF EXISTS (SELECT 1 FROM @d4_le WHERE MeterID = 1 AND SerialNumber = 'SN-0001') AND NOT EXISTS (SELECT 1 FROM @d4_le WHERE EventType <> 'Suspected theft' OR Status <> 'Open')
    PRINT 'OK   list events filtered by status and type' ELSE PRINT 'FAIL list events';
DELETE @d4_le;
INSERT @d4_le EXEC sp_dso_list_events 7;
IF EXISTS (SELECT 1 FROM @d4_le WHERE EventType = 'Unmatched packet') AND EXISTS (SELECT 1 FROM @d4_le WHERE EventType = 'Phase unbalance')
    PRINT 'OK   list events without filter shows all types' ELSE PRINT 'FAIL list events all';

-- ---------- Αναμονή: aggregates για ό,τι λείπει (20/11 και 23/11), έως 24/11 ----------
SELECT @d4_msum = SumValue FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Month' AND PeriodStart = '2026-11-01';
BEGIN TRY EXEC sp_dso_build_aggregates_pending 7, '2026-11-24', '2026-11-20'; PRINT 'FAIL reversed pending period accepted'; END TRY
BEGIN CATCH IF ERROR_NUMBER() = 53301 PRINT 'OK   reversed pending period -> 53301' ELSE PRINT 'FAIL pending period: ' + ERROR_MESSAGE(); END CATCH;
INSERT @d4_pend EXEC sp_dso_build_aggregates_pending 7, '2026-11-20', '2026-11-24';
IF EXISTS (SELECT 1 FROM @d4_pend WHERE DaysBuilt = 2 AND MeterRows >= 3 AND TransformerRows >= 2)
    PRINT 'OK   pending built the 2 missing days (20/11 and 23/11)' ELSE PRINT 'FAIL pending counts';
IF EXISTS (SELECT 1 FROM METER_AGGREGATE a WHERE a.MeterID = 4 AND a.ObisCode = '1.8.0' AND a.PeriodType = 'Day' AND a.PeriodStart = '2026-11-23'
              AND a.SumValue = 4.5 AND a.ReadingCount = 9 AND a.EstimatedCount = 0)
   AND EXISTS (SELECT 1 FROM METER_AGGREGATE a WHERE a.MeterID = 1 AND a.ObisCode = '1.8.0' AND a.PeriodType = 'Day' AND a.PeriodStart = '2026-11-23' AND a.SumValue = 0 AND a.ReadingCount = 9)
   AND EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE t WHERE t.TransformerID = 4 AND t.ObisCode = '1.8.0' AND t.PeriodType = 'Day' AND t.PeriodStart = '2026-11-23' AND t.SumValue = 4.5 AND t.MeterCount = 2)
    PRINT 'OK   23/11 aggregates: meter 4 = 4.5 (9 readings), meter 1 = 0, transformer 4 = 4.5 from 2 meters' ELSE PRINT 'FAIL 23/11 aggregates';
IF EXISTS (SELECT 1 FROM METER_AGGREGATE a WHERE a.MeterID = 1 AND a.ObisCode = '1.8.0' AND a.PeriodType = 'Day' AND a.PeriodStart = '2026-11-20'
              AND a.SumValue = (SELECT SUM(Value) FROM VALIDATED_READING WHERE MeterID = 1 AND ObisCode = '1.8.0' AND IntervalStart >= '2026-11-20' AND IntervalStart < '2026-11-21'))
   AND EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE t WHERE t.TransformerID = 4 AND t.ObisCode = '1.8.0' AND t.PeriodType = 'Day' AND t.PeriodStart = '2026-11-20'
              AND t.SumValue = (SELECT SUM(v.Value) FROM VALIDATED_READING v JOIN METER m ON m.MeterID = v.MeterID
                                 WHERE m.TransformerID = 4 AND v.ObisCode = '1.8.0' AND v.IntervalStart >= '2026-11-20' AND v.IntervalStart < '2026-11-21'))
    PRINT 'OK   20/11 aggregates equal the validated sums (meter 1 and transformer 4)' ELSE PRINT 'FAIL 20/11 aggregates';
DELETE @d4_pend;
INSERT @d4_pend EXEC sp_dso_build_aggregates_pending 7, '2026-11-20', '2026-11-24';
IF EXISTS (SELECT 1 FROM @d4_pend WHERE DaysBuilt = 0 AND MeterRows = 0 AND TransformerRows = 0)
   AND EXISTS (SELECT 1 FROM METER_AGGREGATE WHERE MeterID = 2 AND ObisCode = '1.8.0' AND PeriodType = 'Month' AND PeriodStart = '2026-11-01' AND SumValue = @d4_msum)
    PRINT 'OK   pending again: nothing to do, the month row was not recomputed' ELSE PRINT 'FAIL pending rerun';

-- ---------- Αναφορά απωλειών ----------
DECLARE @d4_ls TABLE (TransformerID INT, Name NVARCHAR(100), ObisCode VARCHAR(20), PeriodStart DATE, TransformerSum DECIMAL(18,4), MetersSum DECIMAL(18,4),
                      Difference DECIMAL(18,4), DifferencePct DECIMAL(9,2), MeterCount INT, MetersWithData INT, ActiveMeters INT);
INSERT @d4_ls EXEC sp_dso_losses_report 7, '2026-11-22', '2026-11-23';
IF EXISTS (SELECT 1 FROM @d4_ls WHERE TransformerID = 5 AND PeriodStart = '2026-11-22' AND ObisCode = '1.8.0' AND Difference = 0 AND TransformerSum = MetersSum AND MetersWithData = 1)
   AND EXISTS (SELECT 1 FROM @d4_ls WHERE TransformerID = 4 AND PeriodStart = '2026-11-23' AND TransformerSum = 4.5 AND Difference = 0 AND MeterCount = 2 AND ActiveMeters = 2)
   AND NOT EXISTS (SELECT 1 FROM @d4_ls WHERE PeriodStart < '2026-11-22' OR PeriodStart > '2026-11-23')
    PRINT 'OK   losses report: leaf aggregates match their meters (difference 0) inside the period' ELSE PRINT 'FAIL losses report';
