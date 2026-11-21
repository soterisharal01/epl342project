import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
head, rest = src.split('\nGO\n', 1)
blocks = re.findall(r'-- (\w+)\n(CREATE TABLE \1 \(.*?\n\);)\nGO\n', rest, re.S)
order = [n for n, _ in blocks]
B = dict(blocks)
assert len(order) == 62, len(order)

ROLE_TABLES = ['CONSUMER','SYSTEM_ADMIN','SYSTEM_OPERATOR','FIELD_TECHNICIAN','MARKET_USER','TSO_OPERATOR','DSO_OPERATOR']

B['USER_ACCOUNT'] = """CREATE TABLE USER_ACCOUNT (
    UserID INT IDENTITY(1,1) NOT NULL,
    Username NVARCHAR(50) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Role VARCHAR(10) NOT NULL CONSTRAINT CK_USER_ACCOUNT_Role CHECK (Role IN ('Admin', 'Operator', 'Consumer', 'Technician', 'DSO', 'TSO', 'Supplier', 'Aggregator')),
    Email VARCHAR(254) NOT NULL CONSTRAINT CK_USER_ACCOUNT_Email CHECK (Email LIKE '%_@_%._%'),
    Phone VARCHAR(20) NULL CONSTRAINT CK_USER_ACCOUNT_Phone CHECK (Phone NOT LIKE '%[^0-9+ ]%'),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    AccountStatus VARCHAR(9) NOT NULL CONSTRAINT DF_USER_ACCOUNT_AccountStatus DEFAULT 'Active' CONSTRAINT CK_USER_ACCOUNT_AccountStatus CHECK (AccountStatus IN ('Active', 'Suspended')),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_USER_ACCOUNT_CreatedAt DEFAULT SYSUTCDATETIME(),
    CreatedBy INT NULL,
    RawRetentionMonths TINYINT NULL CONSTRAINT CK_USER_ACCOUNT_RawRetentionMonths CHECK (RawRetentionMonths BETWEEN 1 AND 36),
    BirthDate DATE NULL,
    Photo NVARCHAR(400) NULL,
    ApprovalStatus VARCHAR(9) NULL CONSTRAINT CK_USER_ACCOUNT_ApprovalStatus CHECK (ApprovalStatus IN ('Pending', 'Approved', 'Rejected', 'Suspended')),
    ApprovalDecidedAt DATETIME2(0) NULL,
    ApprovedBy INT NULL,
    SupplierID INT NULL,
    AggregatorID INT NULL,
    CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (UserID),
    CONSTRAINT UQ_USER_ACCOUNT_Username UNIQUE (Username),
    CONSTRAINT FK_USER_ACCOUNT_CREATES FOREIGN KEY (CreatedBy) REFERENCES USER_ACCOUNT (UserID),
    CONSTRAINT FK_USER_ACCOUNT_APPROVES FOREIGN KEY (ApprovedBy) REFERENCES USER_ACCOUNT (UserID),
    CONSTRAINT FK_USER_ACCOUNT_WORKS_FOR_SUPPLIER FOREIGN KEY (SupplierID) REFERENCES SUPPLIER (SupplierID),
    CONSTRAINT FK_USER_ACCOUNT_WORKS_FOR_AGGREGATOR FOREIGN KEY (AggregatorID) REFERENCES AGGREGATOR (AggregatorID),
    CONSTRAINT CK_USER_ACCOUNT_Consumer CHECK ((Role = 'Consumer' AND RawRetentionMonths IS NOT NULL) OR (Role <> 'Consumer' AND RawRetentionMonths IS NULL)),
    CONSTRAINT CK_USER_ACCOUNT_Operator CHECK (Role = 'Operator' OR CreatedBy IS NULL),
    CONSTRAINT CK_USER_ACCOUNT_Technician CHECK ((Role = 'Technician' AND BirthDate IS NOT NULL AND Photo IS NOT NULL AND ApprovalStatus IS NOT NULL
        AND ((ApprovalStatus = 'Pending' AND ApprovedBy IS NULL AND ApprovalDecidedAt IS NULL)
          OR (ApprovalStatus <> 'Pending' AND ApprovedBy IS NOT NULL AND ApprovalDecidedAt IS NOT NULL)))
    OR (Role <> 'Technician' AND BirthDate IS NULL AND Photo IS NULL AND ApprovalStatus IS NULL AND ApprovalDecidedAt IS NULL AND ApprovedBy IS NULL)),
    CONSTRAINT CK_USER_ACCOUNT_Company CHECK ((Role = 'Supplier' AND SupplierID IS NOT NULL AND AggregatorID IS NULL)
    OR (Role = 'Aggregator' AND AggregatorID IS NOT NULL AND SupplierID IS NULL)
    OR (Role NOT IN ('Supplier', 'Aggregator') AND SupplierID IS NULL AND AggregatorID IS NULL))
);"""
for t in ROLE_TABLES:
    order.remove(t); del B[t]
# USER_ACCOUNT now needs SUPPLIER and AGGREGATOR first
order.remove('USER_ACCOUNT')
order.insert(order.index('AGGREGATOR') + 1, 'USER_ACCOUNT')

# every FK to a role table now points to USER_ACCOUNT
for n in order:
    B[n] = re.sub(r'REFERENCES (%s) \(UserID\)' % '|'.join(ROLE_TABLES), 'REFERENCES USER_ACCOUNT (UserID)', B[n])

# geofence: hierarchy comes from the transformer tree
g = B['GEOFENCE']
g = re.sub(r'\n    Level TINYINT[^\n]*', '', g)
g = re.sub(r'\n    ParentGeofenceID INT NULL,', '', g)
g = re.sub(r'\n    CONSTRAINT FK_GEOFENCE_PARENT_OF[^\n]*', '', g)
g = re.sub(r',\n    CONSTRAINT CK_GEOFENCE_Parent[^\n]*', '', g)
B['GEOFENCE'] = g

B['TRANSFORMER'] = """CREATE TABLE TRANSFORMER (
    TransformerID INT IDENTITY(1,1) NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    Latitude DECIMAL(9,6) NOT NULL CONSTRAINT CK_TRANSFORMER_Latitude CHECK (Latitude BETWEEN -90 AND 90),
    Longitude DECIMAL(9,6) NOT NULL CONSTRAINT CK_TRANSFORMER_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    GeofenceID INT NOT NULL,
    ParentTransformerID INT NULL,
    CONSTRAINT PK_TRANSFORMER PRIMARY KEY (TransformerID),
    CONSTRAINT UQ_TRANSFORMER_GeofenceID UNIQUE (GeofenceID),
    CONSTRAINT FK_TRANSFORMER_SERVICE_AREA FOREIGN KEY (GeofenceID) REFERENCES GEOFENCE (GeofenceID),
    CONSTRAINT FK_TRANSFORMER_PARENT_OF FOREIGN KEY (ParentTransformerID) REFERENCES TRANSFORMER (TransformerID),
    CONSTRAINT CK_TRANSFORMER_Parent CHECK (ParentTransformerID IS NULL OR ParentTransformerID <> TransformerID)
);"""

# readings: RAW_READING (as received) -> VEE -> VALIDATED_READING (immutable)
B['RAW_READING'] = """CREATE TABLE RAW_READING (
    MeterID INT NOT NULL,
    ObisCode VARCHAR(20) NOT NULL,
    IntervalStart DATETIME2(0) NOT NULL CONSTRAINT CK_RAW_READING_IntervalStart CHECK (DATEPART(MINUTE, IntervalStart) % 15 = 0 AND DATEPART(SECOND, IntervalStart) = 0),
    ReceivedValue DECIMAL(15,4) NOT NULL,
    VeeStatus VARCHAR(9) NOT NULL CONSTRAINT DF_RAW_READING_VeeStatus DEFAULT 'Pending' CONSTRAINT CK_RAW_READING_VeeStatus CHECK (VeeStatus IN ('Pending', 'Validated', 'Suspect')),
    PacketID BIGINT NOT NULL,
    CONSTRAINT PK_RAW_READING PRIMARY KEY (MeterID, ObisCode, IntervalStart),
    CONSTRAINT FK_RAW_READING_MEASURED FOREIGN KEY (MeterID) REFERENCES METER (MeterID),
    CONSTRAINT FK_RAW_READING_READ_CODE FOREIGN KEY (ObisCode) REFERENCES OBIS_CODE (ObisCode),
    CONSTRAINT FK_RAW_READING_FROM_PACKET FOREIGN KEY (PacketID) REFERENCES TELEMETRY_PACKET (PacketID)
);"""
B['VALIDATED_READING'] = """CREATE TABLE VALIDATED_READING (
    MeterID INT NOT NULL,
    ObisCode VARCHAR(20) NOT NULL,
    IntervalStart DATETIME2(0) NOT NULL CONSTRAINT CK_VALIDATED_READING_IntervalStart CHECK (DATEPART(MINUTE, IntervalStart) % 15 = 0 AND DATEPART(SECOND, IntervalStart) = 0),
    Value DECIMAL(15,4) NOT NULL,
    Quality VARCHAR(9) NOT NULL CONSTRAINT CK_VALIDATED_READING_Quality CHECK (Quality IN ('Validated', 'Estimated', 'Edited')),
    RunID INT NOT NULL,
    ValidatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_VALIDATED_READING_ValidatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_VALIDATED_READING PRIMARY KEY (MeterID, ObisCode, IntervalStart),
    CONSTRAINT FK_VALIDATED_READING_MEASURED FOREIGN KEY (MeterID) REFERENCES METER (MeterID),
    CONSTRAINT FK_VALIDATED_READING_READ_CODE FOREIGN KEY (ObisCode) REFERENCES OBIS_CODE (ObisCode),
    CONSTRAINT FK_VALIDATED_READING_FINALIZED_IN FOREIGN KEY (RunID) REFERENCES VEE_RUN (RunID)
);"""
i = order.index('READING')
order[i:i+1] = ['RAW_READING', 'VALIDATED_READING']
del B['READING']

e = B['READING_EDIT']
e = e.replace("CONSTRAINT FK_READING_EDIT_HAS_EDIT FOREIGN KEY (MeterID, ObisCode, IntervalStart) REFERENCES READING (MeterID, ObisCode, IntervalStart) ON DELETE CASCADE,",
 "CONSTRAINT FK_READING_EDIT_METER FOREIGN KEY (MeterID) REFERENCES METER (MeterID),\n    CONSTRAINT FK_READING_EDIT_CODE FOREIGN KEY (ObisCode) REFERENCES OBIS_CODE (ObisCode),")
assert 'FK_READING_EDIT_METER' in e
B['READING_EDIT'] = e

# aggregates on (leaf) transformers instead of geofences
B['TRANSFORMER_AGGREGATE'] = """CREATE TABLE TRANSFORMER_AGGREGATE (
    TransformerID INT NOT NULL,
    ObisCode VARCHAR(20) NOT NULL,
    PeriodStart DATE NOT NULL CONSTRAINT CK_TRANSFORMER_AGGREGATE_PeriodStart CHECK (DAY(PeriodStart) = 1),
    SumValue DECIMAL(18,4) NOT NULL,
    MeterCount INT NOT NULL CONSTRAINT CK_TRANSFORMER_AGGREGATE_MeterCount CHECK (MeterCount >= 0),
    ComputedAt DATETIME2(0) NOT NULL CONSTRAINT DF_TRANSFORMER_AGGREGATE_ComputedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TRANSFORMER_AGGREGATE PRIMARY KEY (TransformerID, ObisCode, PeriodStart),
    CONSTRAINT FK_TRANSFORMER_AGGREGATE_TR_AGG FOREIGN KEY (TransformerID) REFERENCES TRANSFORMER (TransformerID),
    CONSTRAINT FK_TRANSFORMER_AGGREGATE_TR_AGG_CODE FOREIGN KEY (ObisCode) REFERENCES OBIS_CODE (ObisCode)
);"""
B['TRANSFORMER_CURRENT_STATE'] = """CREATE TABLE TRANSFORMER_CURRENT_STATE (
    TransformerID INT NOT NULL,
    ObisCode VARCHAR(20) NOT NULL,
    RefInterval DATETIME2(0) NOT NULL CONSTRAINT CK_TRANSFORMER_CURRENT_STATE_RefInterval CHECK (DATEPART(MINUTE, RefInterval) % 15 = 0 AND DATEPART(SECOND, RefInterval) = 0),
    SumValue DECIMAL(18,4) NOT NULL,
    MeterCount INT NOT NULL CONSTRAINT CK_TRANSFORMER_CURRENT_STATE_MeterCount CHECK (MeterCount >= 0),
    ComputedAt DATETIME2(0) NOT NULL CONSTRAINT DF_TRANSFORMER_CURRENT_STATE_ComputedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TRANSFORMER_CURRENT_STATE PRIMARY KEY (TransformerID, ObisCode),
    CONSTRAINT FK_TRANSFORMER_CURRENT_STATE_TR_STATE FOREIGN KEY (TransformerID) REFERENCES TRANSFORMER (TransformerID),
    CONSTRAINT FK_TRANSFORMER_CURRENT_STATE_STATE_CODE FOREIGN KEY (ObisCode) REFERENCES OBIS_CODE (ObisCode),
    CONSTRAINT CK_TRANSFORMER_CURRENT_STATE_Code CHECK (ObisCode IN ('1.8.0', '2.8.0'))
);"""
for old, new in [('GEOFENCE_AGGREGATE', 'TRANSFORMER_AGGREGATE'), ('GEOFENCE_CURRENT_STATE', 'TRANSFORMER_CURRENT_STATE')]:
    order[order.index(old)] = new; del B[old]

leftover = [n for n in order if re.search(r'REFERENCES (%s|READING|GEOFENCE_AGGREGATE) \(' % '|'.join(ROLE_TABLES), B[n])]
assert not leftover, leftover

TRIGGERS = r"""
-- Κανόνες που δεν εκφράζονται με CHECK (κοιτάνε άλλες γραμμές ή άλλους πίνακες): triggers.

-- Μετασχηματιστές: αυστηρό δέντρο. Μετρητές μόνο στα φύλλα. Ένας μετασχηματιστής
-- με μετρητές δεν παίρνει παιδιά, και ο γονέας δεν μπορεί να είναι απόγονος (κύκλος).
CREATE TRIGGER TR_TRANSFORMER_Tree ON TRANSFORMER AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN METER m ON m.TransformerID = i.ParentTransformerID)
        THROW 50001, N'Ο γονέας έχει μετρητές: μετρητές μπαίνουν μόνο σε μετασχηματιστές-φύλλα.', 1;
    IF UPDATE(ParentTransformerID)
    BEGIN
        DECLARE @cycles INT;
        WITH up AS (
            SELECT i.TransformerID AS StartID, i.ParentTransformerID AS Cur, 1 AS Depth FROM inserted i WHERE i.ParentTransformerID IS NOT NULL
            UNION ALL
            SELECT up.StartID, t.ParentTransformerID, up.Depth + 1 FROM up JOIN TRANSFORMER t ON t.TransformerID = up.Cur
            WHERE t.ParentTransformerID IS NOT NULL AND up.Depth < 100)
        SELECT @cycles = COUNT(*) FROM up WHERE Cur = StartID OPTION (MAXRECURSION 100);
        IF @cycles > 0 THROW 50002, N'Κύκλος στο δέντρο μετασχηματιστών.', 1;
    END
END;
GO

CREATE TRIGGER TR_METER_LeafTransformer ON METER AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN TRANSFORMER c ON c.ParentTransformerID = i.TransformerID)
        THROW 50003, N'Ο μετασχηματιστής έχει παιδιά: μετρητές μπαίνουν μόνο σε φύλλα.', 1;
END;
GO

CREATE TRIGGER TR_TRANSFORMER_AGGREGATE_Leaf ON TRANSFORMER_AGGREGATE AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN TRANSFORMER c ON c.ParentTransformerID = i.TransformerID)
        THROW 50004, N'Αποθηκευμένα aggregates μόνο για φύλλα· τα πάνω επίπεδα υπολογίζονται με ερώτημα.', 1;
END;
GO

-- Επικυρωμένες μετρήσεις: αμετάβλητες. UPDATE ποτέ. DELETE μόνο από τη διαδικασία
-- διατήρησης (3 χρόνια / GDPR), που πρώτα κάνει EXEC sp_set_session_context N'mdms_purge', 1.
CREATE TRIGGER TR_VALIDATED_READING_Immutable ON VALIDATED_READING AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    IF EXISTS (SELECT 1 FROM inserted)
        THROW 50005, N'Οι επικυρωμένες μετρήσεις δεν αλλάζουν.', 1;
    IF ISNULL(CAST(SESSION_CONTEXT(N'mdms_purge') AS INT), 0) <> 1
        THROW 50006, N'Διαγραφή επικυρωμένων μετρήσεων μόνο από τη διαδικασία διατήρησης δεδομένων.', 1;
END;
GO
"""

newhead = """-- MDMS-Cy, ΕΠΛ342 Φάση Β: σχεσιακό σχήμα (T-SQL, Microsoft SQL Server 2025 ή 2022)
-- Το σχήμα της Φάσης Α με τις αλλαγές της συνάντησης με τον καθηγητή (20/11/26), βλ. docs/04-database-schema.md:
--   1. ένας πίνακας χρηστών με Role (ένα username = ένας ρόλος), χωρίς πίνακες ανά ρόλο
--   2. RAW_READING -> VEE -> VALIDATED_READING (αμετάβλητος)
--   3. μετασχηματιστές = αυστηρό δέντρο, μετρητές μόνο στα φύλλα
--   4. μηνιαία aggregates στους μετασχηματιστές-φύλλα (όχι στα geofences)
-- %d πίνακες, σε σειρά ώστε κάθε ξένο κλειδί να δείχνει σε πίνακα που υπάρχει ήδη. Τρέξτε το σε κενή βάση
-- (ή πρώτα drop.sql). Οι φιλτραρισμένοι δείκτες UNIQUE θέλουν SET QUOTED_IDENTIFIER ON (SSMS και PHP το έχουν, στο sqlcmd δώστε -I).
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
""" % len(order)
rest_tail = rest
# keep anything after the last table (indexes etc.)
last = blocks[-1]
tail = rest.split('-- %s\n%s\nGO\n' % last, 1)[1]
out = newhead + ''.join('\n-- %s\n%s\nGO\n' % (n, B[n]) for n in order) + tail + TRIGGERS
out = out.replace('\nGO\n\n\n-- ', '\nGO\n\n-- ')
open(sys.argv[2], 'w', encoding='utf-8').write(out)
rev = list(reversed(order))
OLD_FIRST = ['GEOFENCE_CURRENT_STATE', 'GEOFENCE_AGGREGATE', 'READING_EDIT', 'READING']
OLD_ROLES = ['DSO_OPERATOR', 'TSO_OPERATOR', 'MARKET_USER', 'FIELD_TECHNICIAN', 'SYSTEM_OPERATOR', 'SYSTEM_ADMIN', 'CONSUMER']
rev.remove('READING_EDIT')
i = rev.index('USER_ACCOUNT')
seq = OLD_FIRST + rev[:i] + OLD_ROLES + rev[i:]
drop = ("-- MDMS-Cy Φάση Β: σβήνει όλους τους πίνακες του create.sql, με την αντίστροφη σειρά (τα triggers φεύγουν μαζί με τους πίνακες).\n"
        "-- Σβήνει ΚΑΙ τους πίνακες της Φάσης Α που καταργήθηκαν (READING, GEOFENCE_AGGREGATE, CONSUMER, DSO_OPERATOR κ.λπ.),\n"
        "-- άρα δουλεύει και σε βάση που έχει ακόμα το παλιό σχήμα. Δεν αγγίζει άλλους πίνακες (π.χ. του lab).\n"
        + ''.join('DROP TABLE IF EXISTS %s;\n' % n for n in seq) + 'GO\n')
open(sys.argv[3], 'w', encoding='utf-8').write(drop)
print(len(order), 'tables; tail chars', len(tail))
print(repr(tail[:300]))
