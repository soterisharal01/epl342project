-- =====================================================================
-- procs_dso.sql : ΙΙΙ.3 Λήψη τηλεμετρίας και VEE (περιοχή DSO)
--   DSO-1 λήψη πακέτου JSON -> TELEMETRY_PACKET + RAW_READING
-- Τρέχει μετά το procs_common.sql. Λάθη: 53000-53499 (DSO, απόφαση B4).
-- Κάθε procedure παίρνει πρώτο το @UserID και ελέγχει ότι είναι ενεργός DSO.
-- Όλες οι ώρες είναι UTC (απόφαση B1).
--
-- Αριθμοί λάθους (DSO-1):
--   53000 ο χρήστης δεν είναι ενεργός DSO
--   53001 sp_dso_list_packets: @Top εκτός 1..1000
--   53002 sp_dso_list_packets: άγνωστο @Status
--   53003 sp_dso_list_raw: δεν υπάρχει ο μετρητής
--   53004 sp_dso_list_raw: λάθος περίοδος (κενή ημερομηνία ή @From > @To)
--
-- Κανόνας DSO-1: ένα πακέτο ΔΕΝ χάνεται ποτέ. Ό,τι και να έρθει (σπασμένο JSON,
-- άγνωστος μετρητής, ανενεργός μετρητής) γράφεται στο TELEMETRY_PACKET με την
-- κατάλληλη IngestStatus και ένα EVENT. Γι' αυτό η sp_dso_ingest_packet δεν κάνει
-- THROW για κακό πακέτο: επιστρέφει τη γραμμή αποτελέσματος. THROW μόνο για τον ρόλο.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Βοηθητικό: σταματά με λάθος αν ο χρήστης δεν είναι ενεργός DSO.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_assert
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNT WHERE UserID = @UserID AND Role = 'DSO' AND AccountStatus = 'Active')
        THROW 53000, N'Δεν επιτρέπεται: μόνο για ενεργό χρήστη DSO.', 1;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-1: λήψη ενός πακέτου τηλεμετρίας (JSON του Παραρτήματος).
-- Επιστρέφει ΜΙΑ γραμμή: PacketID, IngestStatus, ReadingsStored, ErrorMessage.
--
-- Κανόνες κατάστασης (IngestStatus):
--   Malformed         άκυρο JSON, λείπει Meter_Network_ID ή έγκυρο Transmission_Timestamp,
--                     ή λείπει ο πίνακας Telemetry_Payload. ErrorMessage πάντα. MeterID NULL
--                     (ή ο μετρητής, αν ήταν γνωστός όταν βρέθηκε το λάθος στον πίνακα).
--   Unknown meter     το NetworkID δεν ταιριάζει σε μετρητή. MeterID NULL. EVENT 'Unmatched packet'.
--   Meter not active  ο μετρητής υπάρχει αλλά METER.Status <> 'Active' (συμφωνία X2). Καμία μέτρηση.
--   Accepted          όλες οι μετρήσεις του πακέτου αποθηκεύτηκαν.
--   Partially accepted κάποιες (ή καμία) μέτρηση δεν αποθηκεύτηκε: άγνωστος κωδικός OBIS, τιμή που
--                     δεν είναι αριθμός, διπλότυπο (υπάρχει ήδη ή επαναλαμβάνεται μέσα στο πακέτο).
--                     Τα αίτια γράφονται στο ErrorMessage. ΑΠΟΦΑΣΗ: πακέτο με άδειο πίνακα ή με
--                     μηδέν αποθηκεύσιμες μετρήσεις (π.χ. ξαναστάλθηκε το ίδιο) είναι επίσης
--                     'Partially accepted' (ο μετρητής είναι γνωστός και ενεργός, άρα όχι
--                     Unknown/Not active, και το CHECK θέλει ErrorMessage), με ReadingsStored = 0.
-- Το διάστημα της μέτρησης = Transmission_Timestamp στρογγυλεμένο προς τα κάτω στο 15λεπτο (UTC):
-- 10:07:30 -> 10:00, 10:15:00 -> 10:15.
--
-- Ταυτοχρονισμός: δύο ίδια πακέτα ταυτόχρονα. Πριν γράψουμε, ελέγχουμε ποιες τριάδες
-- (MeterID, ObisCode, IntervalStart) υπάρχουν ήδη με WITH (UPDLOCK, HOLDLOCK). Το HOLDLOCK
-- (SERIALIZABLE) κλειδώνει ΚΑΙ το κενό του κλειδιού που δεν υπάρχει ακόμη, και το UPDLOCK
-- δεν αφήνει δεύτερη συνεδρία να πάρει το ίδιο κλειδί. Άρα η δεύτερη συνεδρία περιμένει
-- μέχρι το COMMIT της πρώτης, μετά βλέπει τη γραμμή και την παραλείπει ως διπλότυπο. Το
-- κλειδί του πίνακα (PK_RAW_READING) μένει δίχτυ ασφαλείας: σε απρόβλεπτη σύγκρουση το
-- transaction αναιρείται και το πακέτο καταγράφεται ως Malformed (δες το CATCH).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_ingest_packet
    @UserID INT,
    @PayloadJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;

    DECLARE @Raw NVARCHAR(MAX) = ISNULL(@PayloadJson, N'');   -- RawPayload είναι NOT NULL: τίποτα δεν χάνεται
    DECLARE @NetID NVARCHAR(200) = NULL, @TsText NVARCHAR(100) = NULL, @Ts3 DATETIME2(3) = NULL;
    DECLARE @Dbm SMALLINT = NULL, @NetType VARCHAR(20) = NULL, @Arr NVARCHAR(MAX) = NULL;
    DECLARE @MeterID INT = NULL, @MeterStatus VARCHAR(20) = NULL;
    DECLARE @Status VARCHAR(18) = NULL, @Err NVARCHAR(1000) = NULL;   -- NULL = πάμε στις μετρήσεις
    DECLARE @PacketID BIGINT = NULL, @Stored INT = 0, @Interval DATETIME2(0) = NULL;

    -- 1. Ανάγνωση του JSON (μόνο αν είναι έγκυρο). Κάθε μετατροπή με TRY_CONVERT.
    IF ISJSON(@Raw) = 1
    BEGIN
        SET @NetID  = NULLIF(LTRIM(RTRIM(JSON_VALUE(@Raw, '$.Meter_Network_ID'))), N'');
        SET @TsText = JSON_VALUE(@Raw, '$.Transmission_Timestamp');
        -- DATETIMEOFFSET: δέχεται "...Z" ή "+02:00" και το φέρνουμε σε UTC.
        SET @Ts3    = CONVERT(DATETIME2(3), SWITCHOFFSET(TRY_CONVERT(DATETIMEOFFSET(3), @TsText), '+00:00'));
        SET @Dbm    = TRY_CONVERT(SMALLINT, JSON_VALUE(@Raw, '$.Cell_Signal_Strength_dBm'));
        IF @Dbm NOT BETWEEN -150 AND 0 SET @Dbm = NULL;       -- το CHECK του πίνακα θα το απέρριπτε
        SET @NetType = LEFT(JSON_VALUE(@Raw, '$.Network_Type'), 20);
        SET @Arr    = JSON_QUERY(@Raw, '$.Telemetry_Payload');  -- NULL αν λείπει ή δεν είναι πίνακας/αντικείμενο
    END;

    -- 2. Ποια κατάσταση, πριν γράψουμε οτιδήποτε.
    IF ISJSON(@Raw) <> 1
        SELECT @Status = 'Malformed', @Err = N'Το πακέτο δεν είναι έγκυρο JSON.'
    ELSE IF @NetID IS NULL
        SELECT @Status = 'Malformed', @Err = N'Λείπει το Meter_Network_ID.'
    ELSE IF @Ts3 IS NULL
        SELECT @Status = 'Malformed', @Err = N'Λείπει ή δεν είναι έγκυρο το Transmission_Timestamp.'
    ELSE
    BEGIN
        SELECT @MeterID = MeterID, @MeterStatus = Status FROM METER WHERE NetworkID = @NetID;
        IF @MeterID IS NULL
            SELECT @Status = 'Unknown meter', @Err = LEFT(N'Δεν υπάρχει μετρητής με NetworkID ' + @NetID, 1000)
        ELSE IF @MeterStatus <> 'Active'
            SELECT @Status = 'Meter not active',
                   @Err = N'Ο μετρητής δεν είναι ενεργός (κατάσταση: ' + @MeterStatus + N'). Οι μετρήσεις δεν αποθηκεύτηκαν.'
        ELSE IF @Arr IS NULL OR LEFT(LTRIM(@Arr), 1) <> N'['
            SELECT @Status = 'Malformed', @Err = N'Λείπει ο πίνακας Telemetry_Payload.';
    END;

    DECLARE @StoredNetID VARCHAR(40) = LEFT(@NetID, 40);
    DECLARE @StoredTs DATETIME2(0) = CAST(@Ts3 AS DATETIME2(0));

    BEGIN TRY
        BEGIN TRAN;

        IF @Status IS NOT NULL
        BEGIN
            -- Αποτυχία: το πακέτο γράφεται όπως ήρθε, μαζί με ένα συμβάν. Καμία μέτρηση.
            INSERT TELEMETRY_PACKET (ReceivedNetworkID, TransmissionTimestamp, NetworkType, SignalDbm,
                                     RawPayload, IngestStatus, ErrorMessage, MeterID)
            VALUES (@StoredNetID, @StoredTs, @NetType, @Dbm, @Raw, @Status, @Err,
                    CASE WHEN @Status = 'Unknown meter' THEN NULL ELSE @MeterID END);
            SET @PacketID = SCOPE_IDENTITY();

            INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID, PacketID)
            VALUES (CASE @Status WHEN 'Unknown meter' THEN 'Unmatched packet'
                                 WHEN 'Meter not active' THEN 'Packet from inactive meter'
                                 ELSE 'Malformed packet' END,
                    'Warning', @Err, SYSUTCDATETIME(), 'Open',
                    CASE WHEN @Status = 'Unknown meter' THEN NULL ELSE @MeterID END, @PacketID);
        END
        ELSE
        BEGIN
            -- Γνωστός, ενεργός μετρητής και πίνακας μετρήσεων. Πρώτα το πακέτο (προσωρινά 'Accepted',
            -- διορθώνεται παρακάτω στην ίδια συναλλαγή), γιατί το RAW_READING δείχνει σε αυτό.
            INSERT TELEMETRY_PACKET (ReceivedNetworkID, TransmissionTimestamp, NetworkType, SignalDbm,
                                     RawPayload, IngestStatus, ErrorMessage, MeterID)
            VALUES (@StoredNetID, @StoredTs, @NetType, @Dbm, @Raw, 'Accepted', NULL, @MeterID);
            SET @PacketID = SCOPE_IDENTITY();

            -- Διάστημα 15λέπτου: κόβουμε τα δευτερόλεπτα και τα λεπτά πάνω από το τελευταίο :00/:15/:30/:45.
            SET @Interval = CAST(DATEADD(MINUTE, -(DATEPART(MINUTE, @Ts3) % 15),
                                  DATEADD(MILLISECOND, -DATEPART(MILLISECOND, @Ts3),
                                          DATEADD(SECOND, -DATEPART(SECOND, @Ts3), @Ts3))) AS DATETIME2(0));

            DECLARE @items TABLE (Idx INT, Obis VARCHAR(100) NULL, Val DECIMAL(15,4) NULL, Reason NVARCHAR(100) NULL);
            INSERT @items (Idx, Obis, Val)
            SELECT TRY_CONVERT(INT, j.[key]), x.obis,
                   COALESCE(TRY_CONVERT(DECIMAL(15,4), x.val), TRY_CONVERT(DECIMAL(15,4), TRY_CONVERT(FLOAT, x.val)))
            FROM OPENJSON(@Arr) AS j
            CROSS APPLY OPENJSON(CASE WHEN j.[type] = 5 THEN j.[value] ELSE N'{}' END)
                 WITH (obis VARCHAR(100) '$.obis', val NVARCHAR(60) '$.value') AS x;

            -- Ποιες γραμμές δεν μπορούν να αποθηκευτούν, και γιατί (η πρώτη αιτία κερδίζει).
            UPDATE @items SET Reason = N'ελλιπές ή μη αριθμητικό στοιχείο' WHERE Obis IS NULL OR Val IS NULL;
            UPDATE i SET Reason = N'άγνωστος κωδικός OBIS'
              FROM @items i
             WHERE i.Reason IS NULL AND NOT EXISTS (SELECT 1 FROM OBIS_CODE o WHERE o.ObisCode = i.Obis);
            UPDATE i SET Reason = N'επαναλαμβάνεται μέσα στο πακέτο'
              FROM @items i
             WHERE i.Reason IS NULL
               AND EXISTS (SELECT 1 FROM @items p WHERE p.Obis = i.Obis AND p.Idx < i.Idx AND p.Reason IS NULL);
            -- Έλεγχος διπλότυπου με κλείδωμα (δες την εξήγηση στην κορυφή). Τα κλειδώματα μένουν ως το COMMIT.
            UPDATE i SET Reason = N'διπλότυπο (υπάρχει ήδη για αυτό το διάστημα)'
              FROM @items i
             WHERE i.Reason IS NULL
               AND EXISTS (SELECT 1 FROM RAW_READING r WITH (UPDLOCK, HOLDLOCK)
                            WHERE r.MeterID = @MeterID AND r.ObisCode = i.Obis AND r.IntervalStart = @Interval);

            INSERT RAW_READING (MeterID, ObisCode, IntervalStart, ReceivedValue, VeeStatus, PacketID)
            SELECT @MeterID, Obis, @Interval, Val, 'Pending', @PacketID FROM @items WHERE Reason IS NULL;
            SET @Stored = @@ROWCOUNT;

            -- Μήνυμα με τα αίτια (κόβεται στα 1000 χαρακτήρες του πεδίου).
            SELECT @Err = STRING_AGG(CAST(CONCAT(ISNULL(Obis, '?'), N': ', Reason) AS NVARCHAR(MAX)), N'; ') WITHIN GROUP (ORDER BY Idx)
              FROM @items WHERE Reason IS NOT NULL;
            IF NOT EXISTS (SELECT 1 FROM @items) SET @Err = N'Το πακέτο δεν περιέχει μετρήσεις.';
            IF @Err IS NOT NULL AND @Stored = 0 SET @Err = N'Δεν αποθηκεύτηκε καμία μέτρηση. ' + @Err;
            SET @Err = LEFT(@Err, 1000);

            SET @Status = CASE WHEN @Err IS NULL THEN 'Accepted' ELSE 'Partially accepted' END;
            UPDATE TELEMETRY_PACKET SET IngestStatus = @Status, ErrorMessage = @Err WHERE PacketID = @PacketID;

            IF @Status = 'Partially accepted'
                INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID, PacketID)
                VALUES ('Packet partly rejected', 'Warning', @Err, SYSUTCDATETIME(), 'Open', @MeterID, @PacketID);
        END;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('TELEMETRY_PACKET', CAST(@PacketID AS VARCHAR(100)), 'Ingest', NULL, @Status,
                LEFT(CONCAT(N'Μετρήσεις: ', @Stored, ISNULL(N'. ' + @Err, N'')), 1000), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        DECLARE @Msg NVARCHAR(900) = LEFT(ERROR_MESSAGE(), 900);
        IF @@TRANCOUNT > 0 ROLLBACK;
        -- Ακόμη και σε απρόβλεπτο σφάλμα το πακέτο δεν χάνεται: καταγράφεται (best effort) ως Malformed.
        BEGIN TRY
            INSERT TELEMETRY_PACKET (ReceivedNetworkID, TransmissionTimestamp, NetworkType, SignalDbm,
                                     RawPayload, IngestStatus, ErrorMessage, MeterID)
            VALUES (@StoredNetID, @StoredTs, @NetType, @Dbm, @Raw, 'Malformed',
                    N'Σφάλμα επεξεργασίας: ' + @Msg, NULL);
            INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, PacketID)
            VALUES ('Malformed packet', 'Warning', N'Σφάλμα επεξεργασίας: ' + @Msg, SYSUTCDATETIME(), 'Open', SCOPE_IDENTITY());
        END TRY
        BEGIN CATCH
            SET @Msg = @Msg;   -- το δεύτερο σφάλμα αγνοείται: θα ξαναριχτεί το αρχικό
        END CATCH;
        THROW;
    END CATCH;

    SELECT @PacketID AS PacketID, @Status AS IngestStatus, @Stored AS ReadingsStored, @Err AS ErrorMessage;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-1: τα πιο πρόσφατα πακέτα (νεότερο πρώτο), με κατάσταση, σειριακό μετρητή
-- και πλήθος μετρήσεων. @Status NULL = όλες οι καταστάσεις.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_packets
    @UserID INT,
    @Top INT = 50,
    @Status VARCHAR(18) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @Top IS NULL OR @Top < 1 OR @Top > 1000
        THROW 53001, N'Το πλήθος πακέτων πρέπει να είναι από 1 έως 1000.', 1;
    IF @Status IS NOT NULL AND @Status NOT IN ('Accepted', 'Partially accepted', 'Unknown meter', 'Meter not active', 'Malformed')
        THROW 53002, N'Άγνωστη κατάσταση πακέτου.', 1;

    SELECT p.PacketID, p.ReceivedAt, p.TransmissionTimestamp, p.ReceivedNetworkID, m.SerialNumber,
           p.NetworkType, p.SignalDbm, p.IngestStatus, c.ReadingsStored, p.ErrorMessage
    FROM (SELECT TOP (@Top) PacketID, ReceivedAt, TransmissionTimestamp, ReceivedNetworkID, NetworkType,
                 SignalDbm, IngestStatus, ErrorMessage, MeterID
            FROM TELEMETRY_PACKET
           WHERE @Status IS NULL OR IngestStatus = @Status
           ORDER BY PacketID DESC) p
    LEFT JOIN METER m ON m.MeterID = p.MeterID
    OUTER APPLY (SELECT COUNT(*) AS ReadingsStored FROM RAW_READING r WHERE r.PacketID = p.PacketID) c
    ORDER BY p.PacketID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-1: ακατέργαστες μετρήσεις ενός μετρητή σε περίοδο (UTC, και τα δύο άκρα μέσα).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_raw
    @UserID INT,
    @MeterID INT,
    @From DATETIME2(0),
    @To DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF NOT EXISTS (SELECT 1 FROM METER WHERE MeterID = @MeterID)
        THROW 53003, N'Δεν υπάρχει ο μετρητής.', 1;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 53004, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν ή ίση με το τέλος.', 1;

    SELECT r.IntervalStart, r.ObisCode, o.Description, o.Unit, r.ReceivedValue, r.VeeStatus, r.PacketID
    FROM RAW_READING r
    JOIN OBIS_CODE o ON o.ObisCode = r.ObisCode
    WHERE r.MeterID = @MeterID AND r.IntervalStart >= @From AND r.IntervalStart <= @To
    ORDER BY r.IntervalStart, r.ObisCode;
END;
GO

-- =====================================================================
-- DSO-2 / DSO-3 : VEE (Validation, Estimation, Editing)
-- Αριθμοί λάθους (DSO-2/3):
--   53100 sp_dso_run_vee: λάθος περίοδος (κενή ημερομηνία ή @From >= @To)
--   53101 sp_dso_run_vee: τρέχει ήδη άλλο VEE (sp_getapplock)
--   53110 sp_dso_list_suspect: δεν υπάρχει ο μετρητής
--   53120 sp_dso_edit_reading: δεν υπάρχει τέτοια μέτρηση
--   53121 sp_dso_edit_reading: η μέτρηση δεν είναι Suspect
--   53122 sp_dso_edit_reading: η νέα τιμή λείπει ή είναι εκτός ορίων του κωδικού OBIS
--   53123 sp_dso_edit_reading: ο λόγος διόρθωσης είναι υποχρεωτικός
--   53124 sp_dso_edit_reading: υπάρχει ήδη επικυρωμένη τιμή για το διάστημα
--
-- ΠΩΣ ΔΟΥΛΕΥΕΙ ΤΟ VEE (απόφαση B2, docs/19-conventions.md):
--  * RAW_READING.ReceivedValue των σωρευτικών κωδικών (1.8.0, 2.8.0 ...) είναι ο ΜΕΤΡΗΤΗΣ
--    (counter από την εγκατάσταση). Η ΕΠΙΚΥΡΩΜΕΝΗ τιμή (VALIDATED_READING.Value) είναι η ΕΝΕΡΓΕΙΑ
--    του 15λέπτου = μετρητής - μετρητής του προηγούμενου διαστήματος. Για στιγμιαίους κωδικούς
--    (τάση, ένταση) η τιμή είναι αυτή που στάλθηκε.
--  * Κάθε σειρά (μετρητής + κωδικός) επεξεργάζεται κατά χρονική σειρά, γιατί κάθε τιμή εξαρτάται
--    από την προηγούμενη (διαφορά μετρητή, μέσος όρος για spike, παρεμβολή κενού).
--  * Έλεγχοι ανά κωδικό, μόνο από ΕΝΕΡΓΟΥΣ κανόνες που συνδέονται με τον κωδικό στον RULE_FOR:
--      Range    η τιμή ανάμεσα σε MinValid/MaxValid του OBIS_CODE
--      Spike    τιμή > factor x μέσος όρος των τελευταίων `window` επικυρωμένων τιμών (παράμετροι JSON
--               του κανόνα, προεπιλογή 5 και 3). Δάπεδο: 10% του MaxValid, ώστε ένας "ήσυχος" μέσος
--               όρος κοντά στο 0 (π.χ. φωτοβολταϊκά τα ξημερώματα) να μη θεωρεί κάθε αύξηση spike.
--      Gap+LinearEstimate  λείπουν 1..4 διαστήματα ανάμεσα σε δύο έγκυρες τιμές -> εκτίμηση.
--      VoltageBand  τάση εκτός ζώνης: η τιμή μένει έγκυρη, γράφεται μόνο EVENT.
--    Αρνητική διαφορά μετρητή είναι ΠΑΝΤΑ Suspect (ο μετρητής δεν γυρίζει πίσω).
--  * Suspect = η raw γραμμή γίνεται 'Suspect', ΔΕΝ γράφεται VALIDATED_READING, γράφεται EVENT
--    'Suspect reading' με τον λόγο. Ένας άνθρωπος το λύνει με sp_dso_edit_reading.
--  * ΚΑΝΟΝΑΣ ΠΡΩΤΗΣ ΜΕΤΡΗΣΗΣ: χωρίς προηγούμενο μετρητή (πρώτη μέτρηση της σειράς) ή με κενό
--    μεγαλύτερο από 4 διαστήματα (μακρά διακοπή, αλλαγή μετρητή) δεν υπάρχει ενέργεια να βγει.
--    Η raw γραμμή γίνεται 'Validated' ως ΒΑΣΗ (baseline) χωρίς VALIDATED_READING: αρχίζει νέα
--    αλυσίδα διαφορών από εκεί. Το πλήθος τους μπαίνει στο AUDIT_LOG.
--  * Μετά το VEE τα VALIDATED_READING δεν αλλάζουν ποτέ (trigger): μόνο INSERT.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DSO-2 ★: τρέξιμο VEE για Pending μετρήσεις με IntervalStart στο [@From, @To) (UTC).
-- Επιστρέφει ΜΙΑ γραμμή: RunID, Validated, Estimated, Suspect, Events.
--   Validated = νέες επικυρωμένες (ενέργεια ή τιμή), Estimated = νέες εκτιμήσεις,
--   Suspect = raw γραμμές που περιμένουν άνθρωπο, Events = νέα EVENT (Suspect reading, Undervoltage, Overvoltage).
--
-- Εκτίμηση κενού (γραμμική παρεμβολή της ΕΝΕΡΓΕΙΑΣ): ανάμεσα στον προηγούμενο μετρητή P (ενέργεια
-- e0 στο προηγούμενο διάστημα) και τον μετρητή C υπάρχουν g διαστήματα χωρίς μέτρηση. Η διαφορά
-- D = C - P είναι η ενέργεια των g+1 διαστημάτων. Ζητάμε ευθεία e_i = e0 + i*s (i = 1..g+1) με
-- άθροισμα D:  s = 2*(D - (g+1)*e0) / ((g+1)*(g+2)). Τα i=1..g είναι οι εκτιμήσεις (Quality
-- 'Estimated'), το i=g+1 η επικυρωμένη τιμή της πραγματικής μέτρησης. Παράδειγμα της εκφώνησης:
-- e0 = 2.0, D = 4.3, g = 1 -> s = 0.1 -> κενό 2.1 και επόμενο 2.2 (το κενό είναι ο μέσος όρος
-- των γειτόνων). Ο συνολικός μετρητής διατηρείται: 2.1 + 2.2 = D.
--
-- Ταυτοχρονισμός (docs/15-concurrency.md):
--  * sp_getapplock (Exclusive, ανά συναλλαγή, χωρίς αναμονή): μόνο ένα VEE τη φορά. Το δεύτερο
--    παίρνει αμέσως 53101 αντί να περιμένει και να διπλο-επεξεργαστεί τις ίδιες γραμμές.
--  * Οι Pending γραμμές διαβάζονται WITH (UPDLOCK, READPAST): κλειδώνουμε αυτές που θα
--    επεξεργαστούμε, και προσπερνάμε (δεν περιμένουμε) γραμμές που κλειδώνει εκείνη τη στιγμή
--    άλλη συναλλαγή, π.χ. η sp_dso_ingest_packet που γράφει νέο πακέτο. Έτσι η λήψη
--    τηλεμετρίας συνεχίζεται όσο τρέχει το VEE και το VEE δεν μπλοκάρει. Ό,τι προσπεράστηκε
--    ή ήρθε αργότερα μένει Pending για το επόμενο τρέξιμο.
--  * Όλα γίνονται σε ΜΙΑ συναλλαγή: ή γράφονται όλα (VEE_RUN, VALIDATED, READING_EDIT, raw status,
--    EVENT, AUDIT_LOG) ή τίποτα.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_run_vee
    @UserID INT,
    @From DATETIME2(0),
    @To DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @From IS NULL OR @To IS NULL OR @From >= @To
        THROW 53100, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν από το τέλος.', 1;

    DECLARE @MaxGap INT = 4;                         -- μέγιστο πλήθος διαστημάτων που εκτιμάται (1 ώρα)
    DECLARE @RunID INT, @rc INT, @k INT, @maxK INT;
    DECLARE @nVal INT = 0, @nEst INT = 0, @nSus INT = 0, @nBase INT = 0, @nLate INT = 0, @nEv INT = 0, @c INT = 0;
    DECLARE @EstRuleID INT = (SELECT TOP 1 RuleID FROM VEE_RULE WHERE RuleType = 'LinearEstimate' AND IsActive = 1 ORDER BY RuleID);

    BEGIN TRY
        BEGIN TRAN;

        -- Ένα VEE τη φορά (κλείδωμα εφαρμογής, ελευθερώνεται στο COMMIT/ROLLBACK).
        EXEC @rc = sp_getapplock @Resource = N'mdms_vee_run', @LockMode = N'Exclusive',
                                 @LockOwner = N'Transaction', @LockTimeout = 0;
        IF @rc < 0
            THROW 53101, N'Τρέχει ήδη άλλο VEE. Δοκιμάστε ξανά όταν τελειώσει.', 1;

        INSERT VEE_RUN (PeriodFrom, PeriodTo) VALUES (@From, @To);
        SET @RunID = SCOPE_IDENTITY();

        -- Πίνακας εργασίας: μία γραμμή ανά διάστημα που επεξεργαζόμαστε + γραμμές "πλαισίου"
        -- (ctx) = ο τελευταίος μετρητής πριν την περίοδο και οι τελευταίες 10 επικυρωμένες τιμές.
        -- Verdict: pending (δεν κρίθηκε ακόμη), ok, suspect, base (πρώτη μέτρηση/μακρά διακοπή),
        --          late (υπάρχει ήδη επικυρωμένη τιμή), est (εκτίμηση), ctx/anchor (πλαίσιο).
        CREATE TABLE #w (
            Id INT IDENTITY(1,1) NOT NULL, MeterID INT NOT NULL, Obis VARCHAR(20) NOT NULL,
            Slot DATETIME2(0) NOT NULL, IsPending BIT NOT NULL, Verdict VARCHAR(8) NOT NULL,
            Reason NVARCHAR(200) NULL, Counter DECIMAL(15,4) NULL, Val DECIMAL(15,4) NULL,
            Rk INT NULL, PrevSlot DATETIME2(0) NULL, PrevCounter DECIMAL(15,4) NULL,
            PrevVal DECIMAL(15,4) NULL, PrevVerdict VARCHAR(8) NULL, Gap INT NULL,
            Delta DECIMAL(16,4) NULL, EstS DECIMAL(18,8) NULL,
            UseEst BIT NOT NULL DEFAULT 0, BandOut BIT NOT NULL DEFAULT 0);
        CREATE INDEX IX_w ON #w (MeterID, Obis, Slot);
        CREATE TABLE #n (n INT NOT NULL PRIMARY KEY);
        WHILE @c < @MaxGap BEGIN SET @c += 1; INSERT #n (n) VALUES (@c); END;

        -- 1. Οι Pending γραμμές της περιόδου (δες την ιστορία ταυτοχρονισμού παραπάνω).
        INSERT #w (MeterID, Obis, Slot, Counter, IsPending, Verdict)
        SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue, 1, 'pending'
        FROM RAW_READING r WITH (UPDLOCK, READPAST)
        WHERE r.VeeStatus = 'Pending' AND r.IntervalStart >= @From AND r.IntervalStart < @To;

        -- Αργοπορημένη raw για διάστημα που έχει ήδη επικυρωμένη τιμή (π.χ. εκτίμηση): τα
        -- επικυρωμένα είναι αμετάβλητα, άρα η raw κλείνει χωρίς να αλλάξει τίποτα.
        UPDATE w SET Verdict = 'late', Counter = NULL
        FROM #w w
        WHERE EXISTS (SELECT 1 FROM VALIDATED_READING v
                       WHERE v.MeterID = w.MeterID AND v.ObisCode = w.Obis AND v.IntervalStart = w.Slot);

        -- 2. Ρυθμίσεις ανά κωδικό: ποιοι ενεργοί κανόνες ισχύουν (RULE_FOR) και οι παράμετροί τους.
        SELECT o.ObisCode, o.Kind, o.MinValid, o.MaxValid,
               CASE WHEN EXISTS (SELECT 1 FROM RULE_FOR f JOIN VEE_RULE r ON r.RuleID = f.RuleID
                                  WHERE f.ObisCode = o.ObisCode AND r.IsActive = 1 AND r.RuleType = 'Range') THEN 1 ELSE 0 END AS HasRange,
               CASE WHEN sp.Parameters IS NOT NULL THEN 1 ELSE 0 END AS HasSpike,
               ISNULL(TRY_CONVERT(DECIMAL(9,4), JSON_VALUE(sp.Parameters, '$.factor')), 5) AS SpFactor,
               CASE WHEN ISNULL(TRY_CONVERT(INT, JSON_VALUE(sp.Parameters, '$.window')), 3) BETWEEN 1 AND 10
                    THEN ISNULL(TRY_CONVERT(INT, JSON_VALUE(sp.Parameters, '$.window')), 3) ELSE 3 END AS SpWindow,
               CASE WHEN bd.Parameters IS NOT NULL THEN 1 ELSE 0 END AS HasBand,
               ISNULL(TRY_CONVERT(DECIMAL(9,4), JSON_VALUE(bd.Parameters, '$.min')), 207) AS BandMin,
               ISNULL(TRY_CONVERT(DECIMAL(9,4), JSON_VALUE(bd.Parameters, '$.max')), 253) AS BandMax,
               CASE WHEN EXISTS (SELECT 1 FROM RULE_FOR f JOIN VEE_RULE r ON r.RuleID = f.RuleID
                                  WHERE f.ObisCode = o.ObisCode AND r.IsActive = 1 AND r.RuleType = 'Gap')
                     AND EXISTS (SELECT 1 FROM RULE_FOR f JOIN VEE_RULE r ON r.RuleID = f.RuleID
                                  WHERE f.ObisCode = o.ObisCode AND r.IsActive = 1 AND r.RuleType = 'LinearEstimate')
                    THEN 1 ELSE 0 END AS GapOn
        INTO #code
        FROM OBIS_CODE o
        OUTER APPLY (SELECT TOP 1 r.Parameters FROM RULE_FOR f JOIN VEE_RULE r ON r.RuleID = f.RuleID
                      WHERE f.ObisCode = o.ObisCode AND r.IsActive = 1 AND r.RuleType = 'Spike' ORDER BY r.RuleID) sp
        OUTER APPLY (SELECT TOP 1 r.Parameters FROM RULE_FOR f JOIN VEE_RULE r ON r.RuleID = f.RuleID
                      WHERE f.ObisCode = o.ObisCode AND r.IsActive = 1 AND r.RuleType = 'VoltageBand' ORDER BY r.RuleID) bd
        WHERE o.ObisCode IN (SELECT Obis FROM #w);

        -- 3. Πλαίσιο: για κάθε σειρά ο τελευταίος raw μετρητής και οι 10 τελευταίες επικυρωμένες τιμές πριν την πρώτη Pending.
        ;WITH s AS (SELECT MeterID, Obis, MIN(Slot) AS FirstSlot FROM #w WHERE Verdict = 'pending' GROUP BY MeterID, Obis),
        vv AS (SELECT v.MeterID, v.ObisCode AS Obis, v.IntervalStart AS Slot,
                      ROW_NUMBER() OVER (PARTITION BY v.MeterID, v.ObisCode ORDER BY v.IntervalStart DESC) AS rn
                 FROM VALIDATED_READING v JOIN s ON s.MeterID = v.MeterID AND s.Obis = v.ObisCode
                WHERE v.IntervalStart < s.FirstSlot),
        rr AS (SELECT r.MeterID, r.ObisCode AS Obis, r.IntervalStart AS Slot,
                      ROW_NUMBER() OVER (PARTITION BY r.MeterID, r.ObisCode ORDER BY r.IntervalStart DESC) AS rn
                 FROM RAW_READING r JOIN s ON s.MeterID = r.MeterID AND s.Obis = r.ObisCode
                WHERE r.IntervalStart < s.FirstSlot)
        INSERT #w (MeterID, Obis, Slot, IsPending, Verdict)
        SELECT MeterID, Obis, Slot, 0, 'ctx' FROM vv WHERE rn <= 10
        UNION
        SELECT MeterID, Obis, Slot, 0, 'ctx' FROM rr WHERE rn = 1;

        UPDATE w SET Counter = r.ReceivedValue
          FROM #w w JOIN RAW_READING r ON r.MeterID = w.MeterID AND r.ObisCode = w.Obis AND r.IntervalStart = w.Slot
         WHERE w.Verdict = 'ctx';
        UPDATE w SET Val = v.Value
          FROM #w w JOIN VALIDATED_READING v ON v.MeterID = w.MeterID AND v.ObisCode = w.Obis AND v.IntervalStart = w.Slot
         WHERE w.Verdict = 'ctx';
        UPDATE #w SET Verdict = CASE WHEN Val IS NOT NULL THEN 'ok' ELSE 'anchor' END WHERE Verdict = 'ctx';

        -- Σειρά επεξεργασίας: Rk = 1, 2, 3 ... ανά σειρά (μετρητής + κωδικός).
        ;WITH x AS (SELECT Rk, ROW_NUMBER() OVER (PARTITION BY MeterID, Obis ORDER BY Slot) AS n
                      FROM #w WHERE IsPending = 1 AND Verdict = 'pending')
        UPDATE x SET Rk = n;

        -- 4. Ο βρόχος: ένα "κύμα" ανά Rk, και μέσα σε κάθε κύμα όλες οι σειρές μαζί (set-based).
        -- Χρειάζεται βρόχος γιατί το αποτέλεσμα μιας γραμμής (ok/suspect/εκτίμηση) επηρεάζει την επόμενη.
        SELECT @maxK = ISNULL(MAX(Rk), 0) FROM #w;
        SET @k = 1;
        WHILE @k <= @maxK
        BEGIN
            -- 4a. Η προηγούμενη γραμμή με μετρητή (οποιασδήποτε κατάστασης: ο μετρητής είναι αλήθεια του μετρητή).
            UPDATE w SET PrevSlot = p.Slot, PrevCounter = p.Counter, PrevVal = p.Val, PrevVerdict = p.Verdict
            FROM #w w
            OUTER APPLY (SELECT TOP 1 q.Slot, q.Counter, q.Val, q.Verdict FROM #w q
                          WHERE q.MeterID = w.MeterID AND q.Obis = w.Obis AND q.Slot < w.Slot AND q.Counter IS NOT NULL
                          ORDER BY q.Slot DESC) p
            WHERE w.Rk = @k;

            -- 4b. Τιμή: στιγμιαίοι = όπως στάλθηκε.
            UPDATE w SET Val = w.Counter
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND c.Kind = 'Instantaneous';

            -- 4c. Σωρευτικοί: κενό (g διαστήματα που λείπουν) και διαφορά μετρητή D.
            UPDATE w SET Gap = CASE WHEN w.PrevSlot IS NULL THEN NULL ELSE DATEDIFF(MINUTE, w.PrevSlot, w.Slot) / 15 - 1 END,
                         Delta = w.Counter - w.PrevCounter
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND c.Kind = 'Cumulative register';

            -- 4d. Πρώτη μέτρηση ή μακρά διακοπή: βάση (baseline), όχι ενέργεια.
            UPDATE w SET Verdict = 'base', Reason = N'Πρώτη μέτρηση ή μεγάλο κενό: νέα βάση μετρητή'
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND w.Verdict = 'pending' AND c.Kind = 'Cumulative register'
               AND (w.PrevSlot IS NULL OR w.Gap > @MaxGap);

            -- 4e. Αρνητική διαφορά: ο μετρητής δεν γυρίζει πίσω (πάντα Suspect, ανεξάρτητα από κανόνες).
            UPDATE #w SET Verdict = 'suspect', Reason = N'Αρνητική διαφορά μετρητή'
             WHERE Rk = @k AND Verdict = 'pending' AND Delta < 0;

            -- 4f. Χωρίς κενό: ενέργεια = D.
            UPDATE #w SET Val = Delta WHERE Rk = @k AND Verdict = 'pending' AND Gap = 0;

            -- 4g. Με κενό (1..@MaxGap): γραμμική παρεμβολή αν οι κανόνες Gap+LinearEstimate είναι ενεργοί
            --     και υπάρχει έγκυρη προηγούμενη ενέργεια e0. Αλλιώς Suspect (θέλει άνθρωπο).
            UPDATE w SET EstS = CAST(2 * (w.Delta - (w.Gap + 1) * w.PrevVal) AS DECIMAL(18,8)) / ((w.Gap + 1) * (w.Gap + 2)),
                         UseEst = 1
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND w.Verdict = 'pending' AND w.Gap >= 1 AND c.GapOn = 1
               AND w.PrevVal IS NOT NULL AND w.PrevVerdict = 'ok';
            UPDATE #w SET Val = ROUND(PrevVal + (Gap + 1) * EstS, 4) WHERE Rk = @k AND Verdict = 'pending' AND UseEst = 1;
            UPDATE #w SET Verdict = 'suspect', Reason = N'Κενό που δεν μπορεί να εκτιμηθεί (λείπει προηγούμενη έγκυρη τιμή ή κανόνας)'
             WHERE Rk = @k AND Verdict = 'pending' AND Gap >= 1 AND UseEst = 0;
            UPDATE #w SET Verdict = 'suspect', Reason = N'Αρνητική τιμή μετά την παρεμβολή του κενού'
             WHERE Rk = @k AND Verdict = 'pending' AND UseEst = 1 AND Val < 0;

            -- 4h. Κανόνας Range (MinValid/MaxValid).
            UPDATE w SET Verdict = 'suspect', Reason = N'Εκτός ορίων τιμής (Range)'
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND w.Verdict = 'pending' AND w.Val IS NOT NULL AND c.HasRange = 1
               AND ((c.MinValid IS NOT NULL AND w.Val < c.MinValid) OR (c.MaxValid IS NOT NULL AND w.Val > c.MaxValid));

            -- 4i. Κανόνας Spike: > factor x μέσος όρος των τελευταίων `window` επικυρωμένων/εκτιμημένων τιμών,
            --     και πάνω από το δάπεδο (10% του MaxValid). Οι Suspect τιμές δεν μετράνε στον μέσο όρο.
            UPDATE w SET Verdict = 'suspect', Reason = N'Αιχμή (Spike): υπερβολικά μεγαλύτερη από τις προηγούμενες τιμές'
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
              CROSS APPLY (SELECT AVG(x.Val) AS Av
                             FROM (SELECT q.Val, ROW_NUMBER() OVER (ORDER BY q.Slot DESC) AS rn
                                     FROM #w q
                                    WHERE q.MeterID = w.MeterID AND q.Obis = w.Obis AND q.Slot < w.Slot
                                      AND q.Verdict IN ('ok', 'est') AND q.Val IS NOT NULL) x
                            WHERE x.rn <= c.SpWindow) a
             WHERE w.Rk = @k AND w.Verdict = 'pending' AND w.Val IS NOT NULL AND c.HasSpike = 1 AND a.Av IS NOT NULL
               AND w.Val > CASE WHEN c.SpFactor * a.Av > 0.1 * ISNULL(c.MaxValid, 0) THEN c.SpFactor * a.Av
                                ELSE 0.1 * ISNULL(c.MaxValid, 0) END;

            -- 4j. Ό,τι έμεινε είναι έγκυρο. Τάση εκτός ζώνης: έγκυρη, αλλά σημειώνεται για EVENT.
            UPDATE #w SET Verdict = 'ok' WHERE Rk = @k AND Verdict = 'pending';
            UPDATE w SET BandOut = 1
              FROM #w w JOIN #code c ON c.ObisCode = w.Obis
             WHERE w.Rk = @k AND w.Verdict = 'ok' AND c.HasBand = 1 AND (w.Val < c.BandMin OR w.Val > c.BandMax);

            -- 4k. Οι εκτιμήσεις των κενών μπαίνουν ως γραμμές 'est' (μετράνε στον μέσο όρο του spike μετά).
            INSERT #w (MeterID, Obis, Slot, IsPending, Verdict, Val)
            SELECT w.MeterID, w.Obis, DATEADD(MINUTE, 15 * n.n, w.PrevSlot), 0, 'est', ROUND(w.PrevVal + n.n * w.EstS, 4)
              FROM #w w JOIN #n n ON n.n <= w.Gap
             WHERE w.Rk = @k AND w.Verdict = 'ok' AND w.UseEst = 1;

            SET @k += 1;
        END;

        -- Μια εκτίμηση δεν γράφεται πάνω σε διάστημα που έχει ήδη επικυρωμένη τιμή (αμετάβλητη).
        DELETE w FROM #w w
         WHERE w.Verdict = 'est'
           AND EXISTS (SELECT 1 FROM VALIDATED_READING v
                        WHERE v.MeterID = w.MeterID AND v.ObisCode = w.Obis AND v.IntervalStart = w.Slot);

        -- 5. Εγγραφές. Μόνο INSERT στα VALIDATED_READING (αμετάβλητα).
        INSERT VALIDATED_READING (MeterID, ObisCode, IntervalStart, Value, Quality, RunID)
        SELECT MeterID, Obis, Slot, Val, CASE WHEN Verdict = 'ok' THEN 'Validated' ELSE 'Estimated' END, @RunID
          FROM #w
         WHERE (IsPending = 1 AND Verdict = 'ok') OR (IsPending = 0 AND Verdict = 'est');

        -- Κάθε αυτόματη εκτίμηση αφήνει ίχνος: READING_EDIT 'Automatic estimate' με τον κανόνα, OldValue NULL.
        INSERT READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, Reason, EditedBy, RuleID)
        SELECT w.MeterID, w.Obis, w.Slot,
               (SELECT ISNULL(MAX(e.EditNo), 0) + 1 FROM READING_EDIT e
                 WHERE e.MeterID = w.MeterID AND e.ObisCode = w.Obis AND e.IntervalStart = w.Slot),
               NULL, w.Val, 'Automatic estimate', N'Γραμμική παρεμβολή κενού (VEE)', NULL, @EstRuleID
          FROM #w w WHERE w.Verdict = 'est';

        -- Κατάσταση της raw γραμμής: έγκυρη/βάση/αργοπορημένη -> Validated, ύποπτη -> Suspect.
        UPDATE r SET VeeStatus = CASE WHEN w.Verdict = 'suspect' THEN 'Suspect' ELSE 'Validated' END
          FROM RAW_READING r
          JOIN #w w ON w.MeterID = r.MeterID AND w.Obis = r.ObisCode AND w.Slot = r.IntervalStart
         WHERE w.IsPending = 1 AND w.Verdict IN ('ok', 'suspect', 'base', 'late');

        SELECT @nVal = COUNT(*) FROM #w WHERE IsPending = 1 AND Verdict = 'ok';
        SELECT @nEst = COUNT(*) FROM #w WHERE Verdict = 'est';
        SELECT @nSus = COUNT(*) FROM #w WHERE IsPending = 1 AND Verdict = 'suspect';
        SELECT @nBase = COUNT(*) FROM #w WHERE IsPending = 1 AND Verdict = 'base';
        SELECT @nLate = COUNT(*) FROM #w WHERE IsPending = 1 AND Verdict = 'late';

        -- Συμβάντα (B14): ύποπτη μέτρηση (με τον λόγο) και τάση εκτός ζώνης.
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT 'Suspect reading', 'Warning',
               LEFT(CONCAT(N'Ύποπτη μέτρηση ', Obis, N' (', CONVERT(NVARCHAR(30), ISNULL(Val, Counter)), N'): ', Reason), 1000),
               Slot, 'Open', MeterID
          FROM #w WHERE IsPending = 1 AND Verdict = 'suspect';
        SET @nEv += @@ROWCOUNT;
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT CASE WHEN w.Val < c.BandMin THEN 'Undervoltage' ELSE 'Overvoltage' END, 'Warning',
               LEFT(CONCAT(N'Τάση ', w.Obis, N' = ', CONVERT(NVARCHAR(30), w.Val), N' V εκτός ζώνης ',
                           CONVERT(NVARCHAR(30), c.BandMin), N'-', CONVERT(NVARCHAR(30), c.BandMax)), 1000),
               w.Slot, 'Open', w.MeterID
          FROM #w w JOIN #code c ON c.ObisCode = w.Obis
         WHERE w.IsPending = 1 AND w.Verdict = 'ok' AND w.BandOut = 1;
        SET @nEv += @@ROWCOUNT;

        UPDATE VEE_RUN SET FinishedAt = SYSUTCDATETIME() WHERE RunID = @RunID;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('VEE_RUN', CAST(@RunID AS VARCHAR(100)), 'Run VEE', NULL, 'Finished',
                CONCAT(N'Περίοδος ', CONVERT(VARCHAR(19), @From, 120), N' - ', CONVERT(VARCHAR(19), @To, 120),
                       N'. Validated: ', @nVal, N', Estimated: ', @nEst, N', Suspect: ', @nSus,
                       N', βάσεις: ', @nBase, N', αργοπορημένες: ', @nLate, N', συμβάντα: ', @nEv), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @RunID AS RunID, @nVal AS Validated, @nEst AS Estimated, @nSus AS Suspect, @nEv AS Events;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-3: ύποπτες μετρήσεις (raw 'Suspect') με γείτονες και λόγο. @MeterID NULL = όλοι οι μετρητές.
-- Ο λόγος ΔΕΝ αποθηκεύεται σε στήλη (δεν αλλάζει το create.sql): ξαναϋπολογίζεται εδώ από τα
-- δεδομένα, με τους ίδιους κανόνες με το VEE (το VEE γράφει τον λόγο και στο EVENT 'Suspect reading').
-- Σειρά ελέγχου: αρνητική διαφορά, κενό, εκτός ορίων, αλλιώς αιχμή.
-- ComputedValue = η ενέργεια (σωρευτικοί: μετρητής - προηγούμενος μετρητής) ή η τιμή (στιγμιαίοι).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_suspect
    @UserID INT,
    @MeterID INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @MeterID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM METER WHERE MeterID = @MeterID)
        THROW 53110, N'Δεν υπάρχει ο μετρητής.', 1;

    ;WITH r AS (
        SELECT x.MeterID, x.ObisCode, x.IntervalStart, x.ReceivedValue, x.VeeStatus,
               LAG(x.IntervalStart) OVER (PARTITION BY x.MeterID, x.ObisCode ORDER BY x.IntervalStart) AS PrevSlot,
               LAG(x.ReceivedValue) OVER (PARTITION BY x.MeterID, x.ObisCode ORDER BY x.IntervalStart) AS PrevReceived,
               LEAD(x.IntervalStart) OVER (PARTITION BY x.MeterID, x.ObisCode ORDER BY x.IntervalStart) AS NextSlot,
               LEAD(x.ReceivedValue) OVER (PARTITION BY x.MeterID, x.ObisCode ORDER BY x.IntervalStart) AS NextReceived
          FROM RAW_READING x
         WHERE (@MeterID IS NULL OR x.MeterID = @MeterID)
           AND EXISTS (SELECT 1 FROM RAW_READING s WHERE s.MeterID = x.MeterID AND s.ObisCode = x.ObisCode AND s.VeeStatus = 'Suspect')
    ), c AS (
        SELECT r.MeterID, r.ObisCode, r.IntervalStart, r.ReceivedValue, r.PrevSlot, r.PrevReceived, r.NextSlot, r.NextReceived,
               o.Kind, o.MinValid, o.MaxValid, m.SerialNumber,
               CASE WHEN o.Kind = 'Cumulative register' THEN r.ReceivedValue - r.PrevReceived ELSE r.ReceivedValue END AS ComputedValue
          FROM r JOIN OBIS_CODE o ON o.ObisCode = r.ObisCode JOIN METER m ON m.MeterID = r.MeterID
         WHERE r.VeeStatus = 'Suspect'
    )
    SELECT c.MeterID, c.SerialNumber, c.ObisCode, c.IntervalStart, c.ReceivedValue, c.ComputedValue,
           c.PrevSlot AS PrevIntervalStart, c.PrevReceived, pv.Value AS PrevValidatedValue,
           c.NextSlot AS NextIntervalStart, c.NextReceived,
           CASE WHEN c.Kind = 'Cumulative register' AND c.ComputedValue < 0 THEN N'Αρνητική διαφορά μετρητή'
                WHEN c.Kind = 'Cumulative register' AND (c.PrevSlot IS NULL OR DATEDIFF(MINUTE, c.PrevSlot, c.IntervalStart) > 15)
                     THEN N'Κενό που δεν μπορεί να εκτιμηθεί'
                WHEN (c.MinValid IS NOT NULL AND c.ComputedValue < c.MinValid) OR (c.MaxValid IS NOT NULL AND c.ComputedValue > c.MaxValid)
                     THEN N'Εκτός ορίων τιμής (Range)'
                ELSE CONCAT(N'Αιχμή (Spike): μέσος όρος προηγούμενων ', CONVERT(NVARCHAR(30), a.Av)) END AS Reason
    FROM c
    OUTER APPLY (SELECT v.Value FROM VALIDATED_READING v
                  WHERE v.MeterID = c.MeterID AND v.ObisCode = c.ObisCode AND v.IntervalStart = c.PrevSlot) pv
    OUTER APPLY (SELECT AVG(t.Value) AS Av
                   FROM (SELECT TOP (3) v.Value FROM VALIDATED_READING v
                          WHERE v.MeterID = c.MeterID AND v.ObisCode = c.ObisCode AND v.IntervalStart < c.IntervalStart
                          ORDER BY v.IntervalStart DESC) t) a
    ORDER BY c.MeterID, c.ObisCode, c.IntervalStart;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-3: χειροκίνητη διόρθωση ύποπτης μέτρησης. Μόνο raw 'Suspect'.
--  * @NewValue = η ΔΙΟΡΘΩΜΕΝΗ επικυρωμένη τιμή (ενέργεια 15λέπτου για σωρευτικούς), μέσα στα όρια του κωδικού.
--  * Γράφει READING_EDIT 'Manual edit' (OldValue = η ύποπτη τιμή που υπολογίστηκε, NewValue, λόγος, χρήστης,
--    EditNo = επόμενος αριθμός με UPDLOCK ώστε δύο ταυτόχρονες διορθώσεις να μη πάρουν τον ίδιο),
--    νέο VALIDATED_READING Quality 'Edited' (INSERT, όχι UPDATE: αμετάβλητα), raw -> 'Validated',
--    κλείνει το EVENT 'Suspect reading' και γράφει AUDIT_LOG. Όλα σε μία συναλλαγή.
--  * RunID του VALIDATED_READING (στήλη NOT NULL): το πιο πρόσφατο VEE_RUN που καλύπτει το διάστημα,
--    αλλιώς το πιο πρόσφατο run.
-- Επιστρέφει ΜΙΑ γραμμή: MeterID, ObisCode, IntervalStart, OldValue, NewValue, EditNo.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_edit_reading
    @UserID INT,
    @MeterID INT,
    @ObisCode VARCHAR(20),
    @IntervalStart DATETIME2(0),
    @NewValue DECIMAL(15,4),
    @Reason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @Reason IS NULL OR LEN(LTRIM(RTRIM(@Reason))) = 0
        THROW 53123, N'Ο λόγος της διόρθωσης είναι υποχρεωτικός.', 1;

    DECLARE @Status VARCHAR(9), @Received DECIMAL(15,4), @Kind VARCHAR(19), @Min DECIMAL(15,4), @Max DECIMAL(15,4);
    DECLARE @Prev DECIMAL(15,4), @Old DECIMAL(15,4), @EditNo SMALLINT, @RunID INT;

    BEGIN TRY
        BEGIN TRAN;

        -- Κλειδώνουμε τη raw γραμμή: δύο διορθωτές της ίδιας μέτρησης δεν περνούν μαζί.
        SELECT @Status = r.VeeStatus, @Received = r.ReceivedValue
          FROM RAW_READING r WITH (UPDLOCK, HOLDLOCK)
         WHERE r.MeterID = @MeterID AND r.ObisCode = @ObisCode AND r.IntervalStart = @IntervalStart;
        IF @Status IS NULL
            THROW 53120, N'Δεν υπάρχει τέτοια μέτρηση.', 1;
        IF @Status <> 'Suspect'
            THROW 53121, N'Διορθώνονται μόνο ύποπτες (Suspect) μετρήσεις.', 1;

        SELECT @Kind = Kind, @Min = MinValid, @Max = MaxValid FROM OBIS_CODE WHERE ObisCode = @ObisCode;
        IF @NewValue IS NULL OR (@Min IS NOT NULL AND @NewValue < @Min) OR (@Max IS NOT NULL AND @NewValue > @Max)
            THROW 53122, N'Η νέα τιμή λείπει ή είναι εκτός των ορίων του κωδικού OBIS.', 1;
        IF EXISTS (SELECT 1 FROM VALIDATED_READING WHERE MeterID = @MeterID AND ObisCode = @ObisCode AND IntervalStart = @IntervalStart)
            THROW 53124, N'Υπάρχει ήδη επικυρωμένη τιμή για το διάστημα.', 1;

        -- Παλιά τιμή = αυτή που θα είχε επικυρωθεί (σωρευτικοί: διαφορά από τον προηγούμενο raw μετρητή).
        IF @Kind = 'Cumulative register'
        BEGIN
            SELECT TOP 1 @Prev = r.ReceivedValue FROM RAW_READING r
             WHERE r.MeterID = @MeterID AND r.ObisCode = @ObisCode AND r.IntervalStart < @IntervalStart
             ORDER BY r.IntervalStart DESC;
            SET @Old = @Received - @Prev;          -- NULL αν δεν υπάρχει προηγούμενος
        END
        ELSE SET @Old = @Received;

        SELECT @EditNo = ISNULL(MAX(e.EditNo), 0) + 1
          FROM READING_EDIT e WITH (UPDLOCK, HOLDLOCK)
         WHERE e.MeterID = @MeterID AND e.ObisCode = @ObisCode AND e.IntervalStart = @IntervalStart;

        SELECT TOP 1 @RunID = RunID FROM VEE_RUN
         ORDER BY CASE WHEN PeriodFrom <= @IntervalStart AND @IntervalStart < PeriodTo THEN 0 ELSE 1 END, RunID DESC;

        INSERT READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, Reason, EditedBy, RuleID)
        VALUES (@MeterID, @ObisCode, @IntervalStart, @EditNo, @Old, @NewValue, 'Manual edit', LTRIM(RTRIM(@Reason)), @UserID, NULL);

        INSERT VALIDATED_READING (MeterID, ObisCode, IntervalStart, Value, Quality, RunID)
        VALUES (@MeterID, @ObisCode, @IntervalStart, @NewValue, 'Edited', @RunID);

        UPDATE RAW_READING SET VeeStatus = 'Validated'
         WHERE MeterID = @MeterID AND ObisCode = @ObisCode AND IntervalStart = @IntervalStart;

        UPDATE EVENT SET Status = 'Closed'
         WHERE EventType = 'Suspect reading' AND MeterID = @MeterID AND OccurredAt = @IntervalStart
           AND Description LIKE N'%' + @ObisCode + N'%' AND Status <> 'Closed';

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('VALIDATED_READING',
                CONCAT(@MeterID, '/', @ObisCode, '/', CONVERT(VARCHAR(19), @IntervalStart, 120)),
                'Manual edit', 'Suspect', 'Edited',
                LEFT(CONCAT(N'Παλιά τιμή: ', ISNULL(CONVERT(NVARCHAR(30), @Old), N'-'), N', νέα: ', CONVERT(NVARCHAR(30), @NewValue),
                            N'. Λόγος: ', @Reason), 1000), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @MeterID AS MeterID, @ObisCode AS ObisCode, @IntervalStart AS IntervalStart,
           @Old AS OldValue, @NewValue AS NewValue, @EditNo AS EditNo;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-3: τα τρεξίματα VEE (νεότερο πρώτο) με πλήθη επικυρωμένων/εκτιμημένων/διορθωμένων
-- τιμών ανά run, και πόσες ύποπτες μένουν ακόμη μέσα στην περίοδό του.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_runs
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;

    SELECT u.RunID, u.PeriodFrom, u.PeriodTo, u.StartedAt, u.FinishedAt,
           ISNULL(q.Validated, 0) AS Validated, ISNULL(q.Estimated, 0) AS Estimated, ISNULL(q.Edited, 0) AS Edited,
           s.SuspectNow
    FROM VEE_RUN u
    OUTER APPLY (SELECT SUM(CASE WHEN v.Quality = 'Validated' THEN 1 ELSE 0 END) AS Validated,
                        SUM(CASE WHEN v.Quality = 'Estimated' THEN 1 ELSE 0 END) AS Estimated,
                        SUM(CASE WHEN v.Quality = 'Edited' THEN 1 ELSE 0 END) AS Edited
                   FROM VALIDATED_READING v WHERE v.RunID = u.RunID) q
    OUTER APPLY (SELECT COUNT(*) AS SuspectNow FROM RAW_READING r
                  WHERE r.VeeStatus = 'Suspect' AND r.IntervalStart >= u.PeriodFrom AND r.IntervalStart < u.PeriodTo) s
    ORDER BY u.RunID DESC;
END;
GO

-- =====================================================================
-- DSO-4: aggregates (ημερήσια/μηνιαία/ετήσια αθροίσματα). Λάθη 53300-53399.
--   53300 sp_dso_build_aggregates: λείπει η ημέρα
--   53301 sp_dso_build_aggregates_pending: λάθος περίοδος (@From >= @UpTo)
--   53305 sp_dso_build_aggregates: η ημέρα δεν έχει τελειώσει (σήμερα ή μέλλον, UTC)
--   53302 sp_dso_list_aggregates: άγνωστος @PeriodType
--   53303 sp_dso_list_aggregates: δεν υπάρχει ο μετρητής
--   53304 sp_dso_list_aggregates: λάθος περίοδος (@From > @To)
--
-- ΚΑΝΟΝΕΣ (απόφαση B2 και spec III.3.2):
--  * Αθροίζονται ΜΟΝΟ οι σωρευτικοί κωδικοί 1.8.0 και 2.8.0 (η επικυρωμένη τιμή τους είναι
--    ενέργεια 15λέπτου, άρα το άθροισμα ημέρας έχει νόημα. Η τάση/ένταση δεν αθροίζεται).
--  * Τα aggregates είναι ΤΕΛΙΚΑ: μόνο INSERT, ποτέ UPDATE/DELETE/επανυπολογισμός. Γραμμή που
--    υπάρχει ήδη (PK) παραλείπεται. Άρα δεύτερη κλήση για την ίδια ημέρα γράφει 0 γραμμές.
--  * Ημέρα: METER_AGGREGATE για κάθε (μετρητής, κωδικός) με επικυρωμένες τιμές εκείνης της ημέρας
--    (SumValue, ReadingCount, EstimatedCount = πόσες είναι Estimated).
--    TRANSFORMER_AGGREGATE Day ΜΟΝΟ για φύλλα (τα πάνω επίπεδα υπολογίζονται με ερώτημα, B16):
--    άθροισμα των μετρητών του φύλλου, MeterCount = πόσοι μετρητές είχαν τιμές.
--  * Μήνας: όταν η ημέρα είναι η τελευταία του μήνα (ή @ForceMonth = 1), από τις γραμμές Day
--    του μήνα (έως και την @Day). Έτος: στις 31/12 (ή @ForceYear = 1), από τις γραμμές Day του έτους.
--    Το force είναι ρητή απόφαση του DSO: ό,τι λείπει μέχρι τότε δεν θα μπει ποτέ (τελικό).
--  * Μια ημέρα που δεν έχει επικυρωμένες τιμές δεν γράφει τίποτα (ReadingCount >= 1).
--  * ΜΟΝΟ ΟΡΙΣΤΙΚΟΠΟΙΗΜΕΝΑ (spec III.3.2: «η ολοκλήρωση του VEE είναι το σημείο ενεργοποίησης»):
--    ένας μετρητής/κωδικός που έχει ακόμη ωμή μέτρηση 'Pending' ή 'Suspect' μέσα στην ημέρα ΔΕΝ παίρνει
--    aggregate τώρα (αλλιώς το «τελικό» άθροισμα θα έμενε για πάντα λάθος όταν διορθωθεί η ύποπτη τιμή).
--    Το ίδιο για το φύλλο-μετασχηματιστή αν κάποιος μετρητής του δεν τελείωσε, και για τον αυτόματο μήνα/έτος
--    αν κάτι στο διάστημα δεν τελείωσε (το force είναι ρητή απόφαση του DSO και κλείνει τον μήνα όπως είναι).
--    Παραλείπονται χωρίς λάθος· τα χτίζει επόμενη κλήση (π.χ. η pending) μετά το VEE ή τη διόρθωση.
--    Πόσες σειρές της ημέρας παραλείφθηκαν γράφεται στο AUDIT_LOG.
--  * Η σημερινή (UTC) ή μελλοντική ημέρα δεν χτίζεται: δεν έχει τελειώσει, άρα θα «κλείδωνε» μισά δεδομένα (53305).
-- Δομή: ο πυρήνας sp_dso_build_aggregates_day δεν ανοίγει δικό του transaction (το ανοίγει
-- ο καλών), ώστε και η pending να είναι ένα ατομικό σύνολο.
-- =====================================================================
CREATE OR ALTER PROCEDURE sp_dso_build_aggregates_day
    @UserID INT, @Day DATE, @ForceMonth BIT, @ForceYear BIT,
    @MeterRows INT OUTPUT, @TrRows INT OUTPUT, @MonthRows INT OUTPUT, @YearRows INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;

    DECLARE @From DATETIME2(0) = CAST(@Day AS DATETIME2(0));
    DECLARE @Next DATETIME2(0) = DATEADD(DAY, 1, @From);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Day), MONTH(@Day), 1);
    DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@Day), 1, 1);
    DECLARE @Cnt INT;
    SELECT @MeterRows = 0, @TrRows = 0, @MonthRows = 0, @YearRows = 0;
    IF @Day >= CAST(SYSUTCDATETIME() AS DATE)
        THROW 53305, N'Η ημέρα δεν έχει τελειώσει ακόμη (UTC): τα aggregates χτίζονται μόνο για ολοκληρωμένες ημέρες.', 1;

    -- Σειρές (μετρητής, κωδικός) με ωμές μετρήσεις που δεν πέρασαν ακόμη το VEE ('Pending') ή περιμένουν
    -- διόρθωση ('Suspect'), από την αρχή του έτους μέχρι το τέλος της ημέρας (καλύπτει ημέρα, μήνα, έτος).
    DECLARE @Open TABLE (MeterID INT NOT NULL, ObisCode VARCHAR(20) NOT NULL, IntervalStart DATETIME2(0) NOT NULL);
    INSERT @Open (MeterID, ObisCode, IntervalStart)
    SELECT r.MeterID, r.ObisCode, r.IntervalStart
      FROM RAW_READING r
     WHERE r.VeeStatus IN ('Pending', 'Suspect') AND r.ObisCode IN ('1.8.0', '2.8.0')
       AND r.IntervalStart >= CAST(@YearStart AS DATETIME2(0)) AND r.IntervalStart < @Next;
    DECLARE @Skipped INT = (SELECT COUNT(*) FROM (SELECT DISTINCT MeterID, ObisCode FROM @Open
                                                  WHERE IntervalStart >= @From) x);

    -- Ημέρα, μετρητές
    INSERT METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount)
    SELECT v.MeterID, v.ObisCode, 'Day', @Day, SUM(v.Value), COUNT(*), SUM(CASE WHEN v.Quality = 'Estimated' THEN 1 ELSE 0 END)
      FROM VALIDATED_READING v
     WHERE v.ObisCode IN ('1.8.0', '2.8.0') AND v.IntervalStart >= @From AND v.IntervalStart < @Next
       AND NOT EXISTS (SELECT 1 FROM @Open o WHERE o.MeterID = v.MeterID AND o.ObisCode = v.ObisCode AND o.IntervalStart >= @From)
       AND NOT EXISTS (SELECT 1 FROM METER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                        WHERE a.MeterID = v.MeterID AND a.ObisCode = v.ObisCode AND a.PeriodType = 'Day' AND a.PeriodStart = @Day)
     GROUP BY v.MeterID, v.ObisCode;
    SET @MeterRows = @@ROWCOUNT;

    -- Ημέρα, φύλλα μετασχηματιστών
    INSERT TRANSFORMER_AGGREGATE (TransformerID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount)
    SELECT m.TransformerID, v.ObisCode, 'Day', @Day, SUM(v.Value), COUNT(DISTINCT v.MeterID)
      FROM VALIDATED_READING v
      JOIN METER m ON m.MeterID = v.MeterID
     WHERE v.ObisCode IN ('1.8.0', '2.8.0') AND v.IntervalStart >= @From AND v.IntervalStart < @Next
       AND NOT EXISTS (SELECT 1 FROM TRANSFORMER c WHERE c.ParentTransformerID = m.TransformerID)
       AND NOT EXISTS (SELECT 1 FROM @Open o JOIN METER om ON om.MeterID = o.MeterID
                        WHERE om.TransformerID = m.TransformerID AND o.ObisCode = v.ObisCode AND o.IntervalStart >= @From)
       AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                        WHERE a.TransformerID = m.TransformerID AND a.ObisCode = v.ObisCode AND a.PeriodType = 'Day' AND a.PeriodStart = @Day)
     GROUP BY m.TransformerID, v.ObisCode;
    SET @TrRows = @@ROWCOUNT;

    -- Μήνας
    IF @ForceMonth = 1 OR @Day = EOMONTH(@Day)
    BEGIN
        INSERT METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount)
        SELECT d.MeterID, d.ObisCode, 'Month', @MonthStart, SUM(d.SumValue), SUM(d.ReadingCount), SUM(d.EstimatedCount)
          FROM METER_AGGREGATE d
         WHERE d.PeriodType = 'Day' AND d.PeriodStart >= @MonthStart AND d.PeriodStart <= @Day
           AND (@ForceMonth = 1 OR NOT EXISTS (SELECT 1 FROM @Open o WHERE o.MeterID = d.MeterID AND o.ObisCode = d.ObisCode
                                                   AND o.IntervalStart >= CAST(@MonthStart AS DATETIME2(0))))
           AND NOT EXISTS (SELECT 1 FROM METER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                            WHERE a.MeterID = d.MeterID AND a.ObisCode = d.ObisCode AND a.PeriodType = 'Month' AND a.PeriodStart = @MonthStart)
         GROUP BY d.MeterID, d.ObisCode;
        SET @Cnt = @@ROWCOUNT;
        INSERT TRANSFORMER_AGGREGATE (TransformerID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount)
        SELECT d.TransformerID, d.ObisCode, 'Month', @MonthStart, SUM(d.SumValue), MAX(d.MeterCount)
          FROM TRANSFORMER_AGGREGATE d
         WHERE d.PeriodType = 'Day' AND d.PeriodStart >= @MonthStart AND d.PeriodStart <= @Day
           AND (@ForceMonth = 1 OR NOT EXISTS (SELECT 1 FROM @Open o JOIN METER om ON om.MeterID = o.MeterID
                            WHERE om.TransformerID = d.TransformerID AND o.ObisCode = d.ObisCode
                              AND o.IntervalStart >= CAST(@MonthStart AS DATETIME2(0))))
           AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                            WHERE a.TransformerID = d.TransformerID AND a.ObisCode = d.ObisCode AND a.PeriodType = 'Month' AND a.PeriodStart = @MonthStart)
         GROUP BY d.TransformerID, d.ObisCode;
        SET @MonthRows = @Cnt + @@ROWCOUNT;
    END;

    -- Έτος
    IF @ForceYear = 1 OR (MONTH(@Day) = 12 AND DAY(@Day) = 31)
    BEGIN
        INSERT METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount)
        SELECT d.MeterID, d.ObisCode, 'Year', @YearStart, SUM(d.SumValue), SUM(d.ReadingCount), SUM(d.EstimatedCount)
          FROM METER_AGGREGATE d
         WHERE d.PeriodType = 'Day' AND d.PeriodStart >= @YearStart AND d.PeriodStart <= @Day
           AND (@ForceYear = 1 OR NOT EXISTS (SELECT 1 FROM @Open o WHERE o.MeterID = d.MeterID AND o.ObisCode = d.ObisCode
                                                   AND o.IntervalStart >= CAST(@YearStart AS DATETIME2(0))))
           AND NOT EXISTS (SELECT 1 FROM METER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                            WHERE a.MeterID = d.MeterID AND a.ObisCode = d.ObisCode AND a.PeriodType = 'Year' AND a.PeriodStart = @YearStart)
         GROUP BY d.MeterID, d.ObisCode;
        SET @Cnt = @@ROWCOUNT;
        INSERT TRANSFORMER_AGGREGATE (TransformerID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount)
        SELECT d.TransformerID, d.ObisCode, 'Year', @YearStart, SUM(d.SumValue), MAX(d.MeterCount)
          FROM TRANSFORMER_AGGREGATE d
         WHERE d.PeriodType = 'Day' AND d.PeriodStart >= @YearStart AND d.PeriodStart <= @Day
           AND (@ForceYear = 1 OR NOT EXISTS (SELECT 1 FROM @Open o JOIN METER om ON om.MeterID = o.MeterID
                            WHERE om.TransformerID = d.TransformerID AND o.ObisCode = d.ObisCode
                              AND o.IntervalStart >= CAST(@YearStart AS DATETIME2(0))))
           AND NOT EXISTS (SELECT 1 FROM TRANSFORMER_AGGREGATE a WITH (UPDLOCK, HOLDLOCK)
                            WHERE a.TransformerID = d.TransformerID AND a.ObisCode = d.ObisCode AND a.PeriodType = 'Year' AND a.PeriodStart = @YearStart)
         GROUP BY d.TransformerID, d.ObisCode;
        SET @YearRows = @Cnt + @@ROWCOUNT;
    END;

    INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
    VALUES ('AGGREGATE', CONVERT(VARCHAR(10), @Day, 120), 'Build aggregates', NULL, 'Final',
            CONCAT(N'Μετρητές: ', @MeterRows, N', μετασχηματιστές (φύλλα): ', @TrRows,
                   N', μήνας: ', @MonthRows, N', έτος: ', @YearRows,
                   N', παραλείφθηκαν (VEE όχι ολοκληρωμένο): ', @Skipped), @UserID);
END;
GO

-- ---------------------------------------------------------------------
-- DSO-4: aggregates μιας ημέρας (UTC). Επιστρέφει μία γραμμή:
-- Day, MeterRows, TransformerRows, MonthRows, YearRows (πόσες γραμμές ΓΡΑΦΤΗΚΑΝ τώρα).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_build_aggregates
    @UserID INT,
    @Day DATE,
    @ForceMonth BIT = 0,
    @ForceYear BIT = 0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @Day IS NULL
        THROW 53300, N'Δώστε την ημέρα για τα aggregates.', 1;

    DECLARE @MeterRows INT, @TrRows INT, @MonthRows INT, @YearRows INT;
    BEGIN TRY
        BEGIN TRAN;
        EXEC sp_dso_build_aggregates_day @UserID, @Day, @ForceMonth, @ForceYear,
             @MeterRows OUTPUT, @TrRows OUTPUT, @MonthRows OUTPUT, @YearRows OUTPUT;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @Day AS Day, @MeterRows AS MeterRows, @TrRows AS TransformerRows,
           @MonthRows AS MonthRows, @YearRows AS YearRows;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-4: χτίζει τα aggregates για κάθε ΠΛΗΡΗ ημέρα που έχει επικυρωμένες σωρευτικές τιμές
-- (1.8.0/2.8.0) χωρίς Day aggregate για τον μετρητή/κωδικό. Πλήρης ημέρα = πριν από @UpTo
-- (προεπιλογή: η σημερινή ημερομηνία UTC). @From (προεπιλογή: από την αρχή) περιορίζει από κάτω.
-- Οι ημέρες με σειρά από την παλιά στη νέα (ώστε μήνας/έτος να βγαίνουν μετά τις ημέρες τους).
-- Ένα transaction για όλες. Το sp_dso_run_vee ΔΕΝ αλλάζει: το DSO καλεί αυτό μετά το VEE.
-- Επιστρέφει: DaysBuilt, MeterRows, TransformerRows, MonthRows, YearRows.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_build_aggregates_pending
    @UserID INT,
    @From DATE = NULL,
    @UpTo DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    SET @UpTo = ISNULL(@UpTo, CAST(SYSUTCDATETIME() AS DATE));
    IF @UpTo > CAST(SYSUTCDATETIME() AS DATE) SET @UpTo = CAST(SYSUTCDATETIME() AS DATE);   -- μόνο ολοκληρωμένες ημέρες
    IF @From IS NOT NULL AND @From >= @UpTo
        THROW 53301, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν από το όριο.', 1;

    DECLARE @d4_Day DATE, @d4_Days INT = 0, @d4_M INT, @d4_T INT, @d4_Mo INT, @d4_Y INT;
    DECLARE @d4_SumM INT = 0, @d4_SumT INT = 0, @d4_SumMo INT = 0, @d4_SumY INT = 0;

    BEGIN TRY
        BEGIN TRAN;
        SELECT DISTINCT CAST(v.IntervalStart AS DATE) AS Day
          INTO #d4_pending
          FROM VALIDATED_READING v
         WHERE v.ObisCode IN ('1.8.0', '2.8.0')
           AND CAST(v.IntervalStart AS DATE) < @UpTo
           AND (@From IS NULL OR CAST(v.IntervalStart AS DATE) >= @From)
           AND NOT EXISTS (SELECT 1 FROM METER_AGGREGATE a
                            WHERE a.MeterID = v.MeterID AND a.ObisCode = v.ObisCode AND a.PeriodType = 'Day'
                              AND a.PeriodStart = CAST(v.IntervalStart AS DATE));

        WHILE EXISTS (SELECT 1 FROM #d4_pending)
        BEGIN
            SELECT @d4_Day = MIN(Day) FROM #d4_pending;
            EXEC sp_dso_build_aggregates_day @UserID, @d4_Day, 0, 0, @d4_M OUTPUT, @d4_T OUTPUT, @d4_Mo OUTPUT, @d4_Y OUTPUT;
            SELECT @d4_Days += CASE WHEN @d4_M + @d4_T + @d4_Mo + @d4_Y > 0 THEN 1 ELSE 0 END, @d4_SumM += @d4_M, @d4_SumT += @d4_T, @d4_SumMo += @d4_Mo, @d4_SumY += @d4_Y;
            DELETE #d4_pending WHERE Day = @d4_Day;
        END;
        DROP TABLE #d4_pending;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @d4_Days AS DaysBuilt, @d4_SumM AS MeterRows, @d4_SumT AS TransformerRows,
           @d4_SumMo AS MonthRows, @d4_SumY AS YearRows;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-4: λίστα aggregates μετρητών. @PeriodType 'Day' (προεπιλογή), 'Month' ή 'Year'.
-- @MeterID NULL = όλοι. @From/@To (PeriodStart, και τα δύο άκρα μέσα) προαιρετικά.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_aggregates
    @UserID INT,
    @MeterID INT = NULL,
    @PeriodType VARCHAR(5) = 'Day',
    @From DATE = NULL,
    @To DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Year')
        THROW 53302, N'Ο τύπος περιόδου πρέπει να είναι Day, Month ή Year.', 1;
    IF @MeterID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM METER WHERE MeterID = @MeterID)
        THROW 53303, N'Δεν υπάρχει ο μετρητής.', 1;
    IF @From IS NOT NULL AND @To IS NOT NULL AND @From > @To
        THROW 53304, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν ή ίση με το τέλος.', 1;

    SELECT TOP (5000) a.MeterID, m.SerialNumber, a.ObisCode, a.PeriodType, a.PeriodStart,
           a.SumValue, a.ReadingCount, a.EstimatedCount, m.TransformerID
    FROM METER_AGGREGATE a
    JOIN METER m ON m.MeterID = a.MeterID
    WHERE a.PeriodType = @PeriodType
      AND (@MeterID IS NULL OR a.MeterID = @MeterID)
      AND (@From IS NULL OR a.PeriodStart >= @From)
      AND (@To IS NULL OR a.PeriodStart <= @To)
    ORDER BY a.PeriodStart DESC, a.MeterID, a.ObisCode;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-4: aggregates φύλλων μετασχηματιστών (ίδιες παράμετροι, @TransformerID NULL = όλοι).
-- Λάθη: 53302 (τύπος), 53304 (περίοδος).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_transformer_aggregates
    @UserID INT,
    @TransformerID INT = NULL,
    @PeriodType VARCHAR(5) = 'Day',
    @From DATE = NULL,
    @To DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @PeriodType IS NULL OR @PeriodType NOT IN ('Day', 'Month', 'Year')
        THROW 53302, N'Ο τύπος περιόδου πρέπει να είναι Day, Month ή Year.', 1;
    IF @From IS NOT NULL AND @To IS NOT NULL AND @From > @To
        THROW 53304, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν ή ίση με το τέλος.', 1;

    SELECT TOP (5000) a.TransformerID, t.Name, a.ObisCode, a.PeriodType, a.PeriodStart,
           a.SumValue, a.MeterCount, a.ComputedAt
    FROM TRANSFORMER_AGGREGATE a
    JOIN TRANSFORMER t ON t.TransformerID = a.TransformerID
    WHERE a.PeriodType = @PeriodType
      AND (@TransformerID IS NULL OR a.TransformerID = @TransformerID)
      AND (@From IS NULL OR a.PeriodStart >= @From)
      AND (@To IS NULL OR a.PeriodStart <= @To)
    ORDER BY a.PeriodStart DESC, a.TransformerID, a.ObisCode;
END;
GO

-- =====================================================================
-- DSO-5: αναλυτικά συμβάντα δικτύου -> EVENT. Λάθη 53310-53399.
--   53310 sp_dso_detect_events: λάθος περίοδος (κενή ή @From >= @To)
--   53311 sp_dso_detect_events: περίοδος μεγαλύτερη από 31 ημέρες
--   53312 sp_dso_losses_report: λάθος περίοδος
--   53320 sp_dso_list_events: άγνωστη κατάσταση
--
-- Οι κανόνες δουλεύουν πάνω σε VALIDATED_READING (επικυρωμένα, αμετάβλητα δεδομένα), για
-- διαστήματα IntervalStart μέσα στο [@From, @To). Όλες οι ώρες UTC. Τα συμβάντα παίρνουν
-- OccurredAt = την αρχή του διαστήματος και ΔΕΝ διπλογράφονται: δεν γράφεται συμβάν αν υπάρχει
-- ήδη EVENT με ίδιο μετρητή, ίδιο EventType και ίδιο OccurredAt (έτσι δεν διπλογράφονται ούτε
-- όσα έγραψε ήδη το VEE για την τάση). Άρα η επανάληψη της ίδιας περιόδου δίνει 0 νέα.
--
-- ΚΑΝΟΝΕΣ (σταθερές στην αρχή της procedure, αλλάζουν εύκολα):
--  1. Undervoltage / Overvoltage: τάση 32.7.0, 52.7.0 ή 72.7.0 εκτός της ζώνης του VEE_RULE
--     'VoltageBand' (ενεργός κανόνας, JSON min/max). Αν δεν υπάρχει: 207-253 V (230 V -10%/+10%).
--     ΕΝΑ συμβάν ανά μετρητή και διάστημα (η πιο ακραία φάση). Severity Warning.
--  2. Phase unbalance: και οι τρεις ένταση 31.7.0, 51.7.0, 71.7.0 υπάρχουν στο διάστημα, η
--     μεγαλύτερη >= 1 A, και (max - min) / max > 25%. Severity Warning.
--  3. Suspected theft: ο μετρητής έχει >= 8 ΣΥΝΕΧΟΜΕΝΑ διαστήματα (2 ώρες) με ενέργεια 1.8.0
--     <= 0.01 kWh (πρακτικά μηδέν), ενώ οι ΑΛΛΟΙ μετρητές του ίδιου μετασχηματιστή έχουν στο ίδιο
--     χρονικό εύρος μέση ενέργεια >= 0.05 kWh ανά διάστημα (δηλαδή το δίκτυο λειτουργεί κανονικά).
--     Ένα συμβάν ανά ακολουθία, με OccurredAt την αρχή της. Severity Critical.
--     Όριο: τρέχει μέσα στην περίοδο που ζητήθηκε, άρα ακολουθία που κόβεται από τα άκρα μπορεί
--     να μη φτάσει τα 8 διαστήματα. Είναι ένδειξη για έλεγχο πεδίου, όχι απόδειξη.
--  4. Τεχνικές απώλειες: δεν είναι συμβάν. Δες sp_dso_losses_report.
-- Επιστρέφει μία γραμμή: Undervoltage, Overvoltage, PhaseUnbalance, SuspectedTheft, Total (νέα συμβάντα).
-- =====================================================================
CREATE OR ALTER PROCEDURE sp_dso_detect_events
    @UserID INT,
    @From DATETIME2(0),
    @To DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @From IS NULL OR @To IS NULL OR @From >= @To
        THROW 53310, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν από το τέλος.', 1;
    IF DATEDIFF(DAY, @From, @To) > 31
        THROW 53311, N'Η περίοδος δεν μπορεί να είναι μεγαλύτερη από 31 ημέρες.', 1;

    -- Σταθερές των κανόνων
    DECLARE @d5_ImbalancePct DECIMAL(5,2) = 25;      -- ανισορροπία φάσεων %
    DECLARE @d5_MinAmps DECIMAL(9,2) = 1;            -- κάτω από αυτό το ρεύμα δεν ελέγχουμε
    DECLARE @d5_TheftN INT = 8;                      -- διαστήματα στη σειρά
    DECLARE @d5_ZeroKwh DECIMAL(9,4) = 0.01;         -- "μηδέν"
    DECLARE @d5_PeerKwh DECIMAL(9,4) = 0.05;         -- "κανονικός" γείτονας
    DECLARE @d5_VMin DECIMAL(9,2) = 207, @d5_VMax DECIMAL(9,2) = 253;
    DECLARE @d5_RuleMin DECIMAL(9,2) = NULL, @d5_RuleMax DECIMAL(9,2) = NULL;
    DECLARE @d5_Under INT = 0, @d5_Over INT = 0, @d5_Phase INT = 0, @d5_Theft INT = 0;

    SELECT TOP (1) @d5_RuleMin = TRY_CONVERT(DECIMAL(9,2), JSON_VALUE(Parameters, '$.min')),
                   @d5_RuleMax = TRY_CONVERT(DECIMAL(9,2), JSON_VALUE(Parameters, '$.max'))
      FROM VEE_RULE WHERE RuleType = 'VoltageBand' AND IsActive = 1 ORDER BY RuleID;
    IF @d5_RuleMin IS NOT NULL AND @d5_RuleMax IS NOT NULL AND @d5_RuleMin < @d5_RuleMax
        SELECT @d5_VMin = @d5_RuleMin, @d5_VMax = @d5_RuleMax;

    BEGIN TRY
        BEGIN TRAN;

        -- 1a. Υπόταση
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT 'Undervoltage', 'Warning',
               LEFT(CONCAT(N'Χαμηλή τάση ', CONVERT(NVARCHAR(30), g.MinV), N' V (ζώνη ',
                           CONVERT(NVARCHAR(30), @d5_VMin), N'-', CONVERT(NVARCHAR(30), @d5_VMax), N' V)'), 1000),
               g.IntervalStart, 'Open', g.MeterID
          FROM (SELECT MeterID, IntervalStart, MIN(Value) AS MinV
                  FROM VALIDATED_READING
                 WHERE ObisCode IN ('32.7.0', '52.7.0', '72.7.0') AND IntervalStart >= @From AND IntervalStart < @To
                 GROUP BY MeterID, IntervalStart
                HAVING MIN(Value) < @d5_VMin) g
         WHERE NOT EXISTS (SELECT 1 FROM EVENT e WHERE e.MeterID = g.MeterID AND e.EventType = 'Undervoltage' AND e.OccurredAt = g.IntervalStart);
        SET @d5_Under = @@ROWCOUNT;

        -- 1b. Υπέρταση
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT 'Overvoltage', 'Warning',
               LEFT(CONCAT(N'Υψηλή τάση ', CONVERT(NVARCHAR(30), g.MaxV), N' V (ζώνη ',
                           CONVERT(NVARCHAR(30), @d5_VMin), N'-', CONVERT(NVARCHAR(30), @d5_VMax), N' V)'), 1000),
               g.IntervalStart, 'Open', g.MeterID
          FROM (SELECT MeterID, IntervalStart, MAX(Value) AS MaxV
                  FROM VALIDATED_READING
                 WHERE ObisCode IN ('32.7.0', '52.7.0', '72.7.0') AND IntervalStart >= @From AND IntervalStart < @To
                 GROUP BY MeterID, IntervalStart
                HAVING MAX(Value) > @d5_VMax) g
         WHERE NOT EXISTS (SELECT 1 FROM EVENT e WHERE e.MeterID = g.MeterID AND e.EventType = 'Overvoltage' AND e.OccurredAt = g.IntervalStart);
        SET @d5_Over = @@ROWCOUNT;

        -- 2. Ανισορροπία φάσεων
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT 'Phase unbalance', 'Warning',
               LEFT(CONCAT(N'Ανισορροπία φάσεων: ρεύμα max ', CONVERT(NVARCHAR(30), g.MaxA), N' A, min ',
                           CONVERT(NVARCHAR(30), g.MinA), N' A (διαφορά > ', CONVERT(NVARCHAR(30), @d5_ImbalancePct), N'%)'), 1000),
               g.IntervalStart, 'Open', g.MeterID
          FROM (SELECT MeterID, IntervalStart, MAX(Value) AS MaxA, MIN(Value) AS MinA
                  FROM VALIDATED_READING
                 WHERE ObisCode IN ('31.7.0', '51.7.0', '71.7.0') AND IntervalStart >= @From AND IntervalStart < @To
                 GROUP BY MeterID, IntervalStart
                HAVING COUNT(*) = 3 AND MAX(Value) >= @d5_MinAmps
                   AND (MAX(Value) - MIN(Value)) > (@d5_ImbalancePct / 100.0) * MAX(Value)) g
         WHERE NOT EXISTS (SELECT 1 FROM EVENT e WHERE e.MeterID = g.MeterID AND e.EventType = 'Phase unbalance' AND e.OccurredAt = g.IntervalStart);
        SET @d5_Phase = @@ROWCOUNT;

        -- 3. Ύποπτη κλοπή (gaps-and-islands: διαδοχικά 15λεπτα μηδενικής κατανάλωσης)
        ;WITH z AS (
            SELECT MeterID, IntervalStart,
                   ROW_NUMBER() OVER (PARTITION BY MeterID ORDER BY IntervalStart) AS rn
              FROM VALIDATED_READING
             WHERE ObisCode = '1.8.0' AND IntervalStart >= @From AND IntervalStart < @To AND Value <= @d5_ZeroKwh),
        isl AS (
            SELECT MeterID, IntervalStart,
                   DATEDIFF(MINUTE, CAST('2000-01-01' AS DATETIME2(0)), IntervalStart) / 15 - rn AS grp
              FROM z),
        runs AS (
            SELECT MeterID, MIN(IntervalStart) AS StartAt, MAX(IntervalStart) AS EndAt, COUNT(*) AS n
              FROM isl GROUP BY MeterID, grp
            HAVING COUNT(*) >= @d5_TheftN)
        INSERT EVENT (EventType, Severity, Description, OccurredAt, Status, MeterID)
        SELECT 'Suspected theft', 'Critical',
               LEFT(CONCAT(N'Μηδενική κατανάλωση για ', r.n, N' διαδοχικά διαστήματα (έως ',
                           CONVERT(NVARCHAR(19), r.EndAt, 120), N'), ενώ οι υπόλοιποι μετρητές του μετασχηματιστή καταναλώνουν (μέσος όρος ',
                           CONVERT(NVARCHAR(30), CAST(pe.AvgPeer AS DECIMAL(9,4))), N' kWh)'), 1000),
               r.StartAt, 'Open', r.MeterID
          FROM runs r
          JOIN METER me ON me.MeterID = r.MeterID
         CROSS APPLY (SELECT AVG(p.Value) AS AvgPeer, COUNT(*) AS PeerN
                        FROM VALIDATED_READING p
                        JOIN METER pm ON pm.MeterID = p.MeterID
                       WHERE pm.TransformerID = me.TransformerID AND p.MeterID <> r.MeterID AND p.ObisCode = '1.8.0'
                         AND p.IntervalStart >= r.StartAt AND p.IntervalStart <= r.EndAt) pe
         WHERE pe.PeerN > 0 AND pe.AvgPeer >= @d5_PeerKwh
           AND NOT EXISTS (SELECT 1 FROM EVENT e WHERE e.MeterID = r.MeterID AND e.EventType = 'Suspected theft' AND e.OccurredAt = r.StartAt);
        SET @d5_Theft = @@ROWCOUNT;

        INSERT AUDIT_LOG (ObjectType, ObjectID, Action, OldState, NewState, ResultComment, PerformedBy)
        VALUES ('EVENT', CONCAT(CONVERT(VARCHAR(19), @From, 120), N' / ', CONVERT(VARCHAR(19), @To, 120)), 'Detect events', NULL, 'Open',
                CONCAT(N'Υπόταση: ', @d5_Under, N', υπέρταση: ', @d5_Over, N', ανισορροπία: ', @d5_Phase, N', ύποπτη κλοπή: ', @d5_Theft), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;

    SELECT @d5_Under AS Undervoltage, @d5_Over AS Overvoltage, @d5_Phase AS PhaseUnbalance,
           @d5_Theft AS SuspectedTheft, @d5_Under + @d5_Over + @d5_Phase + @d5_Theft AS Total;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-5: λίστα συμβάντων (νεότερα πρώτα, έως 500). @Status NULL = όλα, αλλιώς Open / In progress / Closed.
-- @Type NULL = όλοι οι τύποι (B14), αλλιώς ακριβής τύπος, π.χ. 'Suspected theft'. Λάθος: 53320 (κατάσταση).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_list_events
    @UserID INT,
    @Status VARCHAR(11) = NULL,
    @Type VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @Status IS NOT NULL AND @Status NOT IN ('Open', 'In progress', 'Closed')
        THROW 53320, N'Άγνωστη κατάσταση συμβάντος.', 1;

    SELECT TOP (500) e.EventID, e.EventType, e.Severity, e.Description, e.OccurredAt, e.Status,
           e.MeterID, m.SerialNumber, e.PacketID, e.TaskID
    FROM EVENT e
    LEFT JOIN METER m ON m.MeterID = e.MeterID
    WHERE (@Status IS NULL OR e.Status = @Status)
      AND (@Type IS NULL OR e.EventType = @Type)
    ORDER BY e.OccurredAt DESC, e.EventID DESC;
END;
GO

-- ---------------------------------------------------------------------
-- DSO-5: τεχνικές απώλειες (αναφορά, όχι συμβάντα). Για κάθε φύλλο και ημέρα της περιόδου
-- (@From..@To, PeriodStart, και τα δύο μέσα) συγκρίνει το TRANSFORMER_AGGREGATE (Day) με το άθροισμα
-- των METER_AGGREGATE (Day) των μετρητών που ανήκουν τώρα στον μετασχηματιστή.
-- Difference = aggregate μετασχηματιστή - άθροισμα μετρητών. ΕΙΛΙΚΡΙΝΕΙΑ: το σχήμα δεν έχει
-- ανεξάρτητη μέτρηση στον ίδιο τον μετασχηματιστή (και το TRANSFORMER_CURRENT_STATE προκύπτει από
-- τους μετρητές), άρα οι πραγματικές απώλειες γραμμής/πυρήνα δεν μετριούνται. Η αναφορά δείχνει
-- ασυμφωνίες δεδομένων (μετρητής που άλλαξε μετασχηματιστή, ύστερα επικυρωμένες τιμές, μετρητές
-- χωρίς δεδομένα: MetersWithData < ActiveMeters). Αν προστεθεί μέτρηση στον μετασχηματιστή, η
-- ίδια σύγκριση δίνει τις απώλειες. Λάθος: 53312 (περίοδος).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_dso_losses_report
    @UserID INT,
    @From DATE,
    @To DATE
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC sp_dso_assert @UserID;
    IF @From IS NULL OR @To IS NULL OR @From > @To
        THROW 53312, N'Λάθος περίοδος: η αρχή πρέπει να είναι πριν ή ίση με το τέλος.', 1;

    SELECT a.TransformerID, t.Name, a.ObisCode, a.PeriodStart,
           a.SumValue AS TransformerSum,
           ISNULL(m.MetersSum, 0) AS MetersSum,
           a.SumValue - ISNULL(m.MetersSum, 0) AS Difference,
           CASE WHEN a.SumValue = 0 THEN NULL ELSE CAST(100.0 * (a.SumValue - ISNULL(m.MetersSum, 0)) / a.SumValue AS DECIMAL(9,2)) END AS DifferencePct,
           a.MeterCount, ISNULL(m.MetersWithData, 0) AS MetersWithData, ac.ActiveMeters
    FROM TRANSFORMER_AGGREGATE a
    JOIN TRANSFORMER t ON t.TransformerID = a.TransformerID
    OUTER APPLY (SELECT SUM(ma.SumValue) AS MetersSum, COUNT(DISTINCT ma.MeterID) AS MetersWithData
                   FROM METER_AGGREGATE ma
                   JOIN METER mm ON mm.MeterID = ma.MeterID
                  WHERE mm.TransformerID = a.TransformerID AND ma.ObisCode = a.ObisCode
                    AND ma.PeriodType = 'Day' AND ma.PeriodStart = a.PeriodStart) m
    OUTER APPLY (SELECT COUNT(*) AS ActiveMeters FROM METER x WHERE x.TransformerID = a.TransformerID AND x.Status = 'Active') ac
    WHERE a.PeriodType = 'Day' AND a.PeriodStart >= @From AND a.PeriodStart <= @To
    ORDER BY a.PeriodStart, a.TransformerID, a.ObisCode;
END;
GO
