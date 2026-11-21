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
