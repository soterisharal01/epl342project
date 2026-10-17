// Step 3: maps the plain ER model (model.js) to T-SQL tables with the textbook algorithm, adds types and constraints, and writes the DDL.
const { areas } = require('./model.js');
const { parseAttr } = require('./diagram.js');

// ---------- column types and attribute constraints (FK columns take the type of the key they point to) ----------
// t: type, nul: NULL allowed, id: IDENTITY, def: DEFAULT, chk: CHECK on the column, fixed: CHECK ... IN list
const C = (t, o = {}) => ({ t, ...o });
const NOW = 'SYSUTCDATETIME()';
const LAT = C('DECIMAL(9,6)', { chk: 'Latitude BETWEEN -90 AND 90' });
const LON = C('DECIMAL(9,6)', { chk: 'Longitude BETWEEN -180 AND 180' });
const SLOT = col => `DATEPART(MINUTE, ${col}) % 15 = 0 AND DATEPART(SECOND, ${col}) = 0`;
const TYPES = {
  USER_ACCOUNT: { UserID: C('INT', { id: true }), Username: C('NVARCHAR(50)'), PasswordHash: C('VARCHAR(255)'), Email: C('VARCHAR(254)', { chk: "Email LIKE '%_@_%._%'" }),
    Phone: C('VARCHAR(20)', { nul: true, chk: "Phone NOT LIKE '%[^0-9+ ]%'" }), FirstName: C('NVARCHAR(50)'), LastName: C('NVARCHAR(50)'),
    AccountStatus: C('VARCHAR(9)', { def: "'Active'", fixed: ['Active', 'Suspended'] }), CreatedAt: C('DATETIME2(0)', { def: NOW }) },
  CONSUMER: { RawRetentionMonths: C('TINYINT', { def: '36', chk: 'RawRetentionMonths BETWEEN 1 AND 36' }) },
  CONSUMER_NOTIFICATION_CHANNEL: { NotificationChannel: C('VARCHAR(5)', { fixed: ['Email', 'SMS'] }) },
  FIELD_TECHNICIAN: { BirthDate: C('DATE'), Photo: C('NVARCHAR(400)'), ApprovalStatus: C('VARCHAR(9)', { def: "'Pending'", fixed: ['Pending', 'Approved', 'Rejected', 'Suspended'] }),
    ApprovalDecidedAt: C('DATETIME2(0)', { nul: true }) },
  PREMISE: { PremiseID: C('INT', { id: true }), Address: C('NVARCHAR(200)'), PostalCode: C('CHAR(4)', { chk: "PostalCode LIKE '[0-9][0-9][0-9][0-9]'" }), Latitude: LAT, Longitude: LON,
    UsageType: C('VARCHAR(12)', { fixed: ['Residential', 'Commercial', 'Industrial', 'Agricultural'] }) },
  HOLDING: { StartDate: C('DATE'), EndDate: C('DATE', { nul: true }) },
  PARISH: { ParishID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  MUNICIPALITY: { MunicipalityID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  DISTRICT: { DistrictID: C('INT', { id: true }), Name: C('NVARCHAR(50)') },
  SUPPLY_SCHEME: { SchemeID: C('INT', { id: true }), Name: C('NVARCHAR(50)') },
  CONSUMPTION_THRESHOLD: { ThresholdID: C('INT', { id: true }), LimitKWh: C('DECIMAL(12,3)', { chk: 'LimitKWh > 0' }), PeriodType: C('VARCHAR(5)', { fixed: ['Day', 'Month'] }), IsActive: C('BIT', { def: '1' }) },
  SERVICE_REQUEST: { RequestID: C('INT', { id: true }), RequestType: C('VARCHAR(12)', { fixed: ['Meter check', 'Fault report'] }), Description: C('NVARCHAR(1000)'),
    Status: C('VARCHAR(9)', { def: "'Submitted'", fixed: ['Submitted', 'Assigned', 'Resolved', 'Cancelled'] }), SubmittedAt: C('DATETIME2(0)', { def: NOW }) },
  BANK_ACCOUNT: { BankAccountID: C('INT', { id: true }), IBAN: C('VARCHAR(34)', { chk: "IBAN LIKE '[A-Z][A-Z][0-9][0-9]%' AND IBAN NOT LIKE '%[^A-Z0-9]%' AND LEN(IBAN) BETWEEN 15 AND 34" }), HolderName: C('NVARCHAR(100)') },
  INVOICE: { InvoiceID: C('INT', { id: true }), IssueDate: C('DATE'), PeriodFrom: C('DATE'), PeriodTo: C('DATE'), Amount: C('DECIMAL(12,2)', { chk: 'Amount >= 0' }),
    Status: C('VARCHAR(14)', { def: "'Issued'", fixed: ['Issued', 'Partially paid', 'Paid', 'Cancelled'] }) },
  PAYMENT: { PaymentID: C('INT', { id: true }), Amount: C('DECIMAL(12,2)', { chk: 'Amount > 0' }), PaidAt: C('DATETIME2(0)'), Reference: C('NVARCHAR(50)', { nul: true }) },
  SERVICE_TYPE: { ServiceTypeID: C('INT', { id: true }), Name: C('NVARCHAR(100)'), Fee: C('DECIMAL(10,2)', { chk: 'Fee >= 0' }) },
  SERVICE_PURCHASE: { PurchaseID: C('INT', { id: true }), MonthFrom: C('DATE', { nul: true }), MonthTo: C('DATE', { nul: true }), PurchasedAt: C('DATETIME2(0)', { def: NOW }), Amount: C('DECIMAL(10,2)', { chk: 'Amount >= 0' }) },
  TECHNICIAN_CATEGORY: { CategoryID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  AVAILABILITY: { AvailDate: C('DATE'), FromTime: C('TIME(0)'), ToTime: C('TIME(0)') },
  DOCUMENT: { DocumentID: C('INT', { id: true }), DocType: C('VARCHAR(27)', { fixed: ['ID card', 'Installer licence', 'Training certificate', 'Calibration certificate', 'CE and protocol declaration', 'Encryption certificate'] }),
    DocNumber: C('NVARCHAR(50)'), IssueDate: C('DATE'), ExpiryDate: C('DATE', { nul: true }), FilePath: C('NVARCHAR(400)'),
    ReviewStatus: C('VARCHAR(8)', { def: "'Pending'", fixed: ['Pending', 'Accepted', 'Rejected'] }), ReviewComment: C('NVARCHAR(500)', { nul: true }), ReviewedAt: C('DATETIME2(0)', { nul: true }) },
  ATTACHMENT: { AttachmentID: C('INT', { id: true }), FilePath: C('NVARCHAR(400)'), Caption: C('NVARCHAR(200)', { nul: true }), UploadedAt: C('DATETIME2(0)', { def: NOW }) },
  FIELD_TASK: { TaskID: C('INT', { id: true }), TaskType: C('VARCHAR(17)', { fixed: ['Installation', 'Replacement', 'Technical check', 'Anti-tamper check'] }),
    ScheduledFrom: C('DATETIME2(0)'), ScheduledTo: C('DATETIME2(0)'), Status: C('VARCHAR(9)', { def: "'Assigned'", fixed: ['Assigned', 'Accepted', 'Done', 'Cancelled'] }),
    Result: C('NVARCHAR(1000)', { nul: true }), CreatedAt: C('DATETIME2(0)', { def: NOW }), CompletedAt: C('DATETIME2(0)', { nul: true }) },
  TASK_NOTE: { NoteNo: C('SMALLINT', { chk: 'NoteNo >= 1' }), NoteKind: C('VARCHAR(11)', { fixed: ['Observation', 'Finding'] }), Text: C('NVARCHAR(2000)'), WrittenAt: C('DATETIME2(0)', { def: NOW }) },
  METER_MODEL: { ModelID: C('INT', { id: true }), Manufacturer: C('NVARCHAR(100)'), ModelName: C('NVARCHAR(100)'), MeterType: C('VARCHAR(12)', { fixed: ['Single-Phase', 'Three-Phase'] }) },
  COMM_TYPE: { CommTypeID: C('INT', { id: true }), Name: C('NVARCHAR(30)') },
  METER: { MeterID: C('INT', { id: true }), SerialNumber: C('VARCHAR(40)'), NetworkID: C('VARCHAR(40)'), Firmware: C('VARCHAR(30)'), MaxLoadAmps: C('DECIMAL(6,1)', { chk: 'MaxLoadAmps > 0' }),
    Latitude: LAT, Longitude: LON, Status: C('VARCHAR(20)', { def: "'Pending confirmation'", fixed: ['Pending confirmation', 'Active', 'Retired'] }) },
  METER_CONNECTED_PHASE: { ConnectedPhase: C('CHAR(2)', { fixed: ['L1', 'L2', 'L3'] }) },
  METER_INSTALLATION: { InstallationID: C('INT', { id: true }), InstalledAt: C('DATETIME2(0)'), RemovedAt: C('DATETIME2(0)', { nul: true }),
    ConfirmationStatus: C('VARCHAR(9)', { def: "'Pending'", fixed: ['Pending', 'Confirmed', 'Rejected'] }), ConfirmedAt: C('DATETIME2(0)', { nul: true }), ConfirmComment: C('NVARCHAR(500)', { nul: true }) },
  REMOTE_COMMAND: { CommandID: C('INT', { id: true }), CommandType: C('VARCHAR(16)', { fixed: ['Disconnect', 'Reconnect', 'Firmware upgrade', 'Load shed'] }),
    Parameters: C('NVARCHAR(1000)', { nul: true, chk: 'ISJSON(Parameters) = 1' }), RequestedAt: C('DATETIME2(0)', { def: NOW }),
    Status: C('VARCHAR(17)', { fixed: ['Awaiting approval', 'Sent', 'Acknowledged', 'Failed', 'Cancelled'] }) },
  COMMAND_ATTEMPT: { AttemptNo: C('SMALLINT', { chk: 'AttemptNo >= 1' }), AttemptAt: C('DATETIME2(3)'), RespondedAt: C('DATETIME2(3)', { nul: true }), Outcome: C('VARCHAR(7)', { nul: true, fixed: ['Timeout', 'NAK', 'ACK'] }) },
  LOAD_SHED_ORDER: { ShedOrderID: C('INT', { id: true }), Reason: C('NVARCHAR(500)'), CreatedAt: C('DATETIME2(0)', { def: NOW }), Status: C('VARCHAR(16)', { def: "'Issued'", fixed: ['Issued', 'Completed', 'Partially failed'] }) },
  OBIS_CODE: { ObisCode: C('VARCHAR(20)'), Description: C('NVARCHAR(200)'), Unit: C('VARCHAR(10)'), Kind: C('VARCHAR(19)', { fixed: ['Cumulative register', 'Instantaneous'] }),
    Phase: C('CHAR(2)', { nul: true, fixed: ['L1', 'L2', 'L3'] }), MinValid: C('DECIMAL(15,4)', { nul: true }), MaxValid: C('DECIMAL(15,4)', { nul: true }) },
  TELEMETRY_PACKET: { PacketID: C('BIGINT', { id: true }), ReceivedNetworkID: C('VARCHAR(40)', { nul: true }), TransmissionTimestamp: C('DATETIME2(0)', { nul: true }), ReceivedAt: C('DATETIME2(3)', { def: NOW }),
    NetworkType: C('VARCHAR(20)', { nul: true }), SignalDbm: C('SMALLINT', { nul: true, chk: 'SignalDbm BETWEEN -150 AND 0' }), RawPayload: C('NVARCHAR(MAX)'),
    IngestStatus: C('VARCHAR(18)', { fixed: ['Accepted', 'Partially accepted', 'Unknown meter', 'Meter not active', 'Malformed'] }), ErrorMessage: C('NVARCHAR(1000)', { nul: true }) },
  READING: { IntervalStart: C('DATETIME2(0)', { chk: SLOT('IntervalStart') }), ReceivedValue: C('DECIMAL(15,4)', { nul: true }), UsedValue: C('DECIMAL(15,4)', { nul: true }),
    Status: C('VARCHAR(9)', { def: "'Raw'", fixed: ['Raw', 'Validated', 'Estimated', 'Edited', 'Suspect'] }) },
  READING_EDIT: { EditNo: C('SMALLINT', { chk: 'EditNo >= 1' }), OldValue: C('DECIMAL(15,4)', { nul: true }), NewValue: C('DECIMAL(15,4)'),
    Origin: C('VARCHAR(18)', { fixed: ['Automatic estimate', 'Manual estimate', 'Manual edit'] }), EditedAt: C('DATETIME2(0)', { def: NOW }), Reason: C('NVARCHAR(500)', { nul: true }) },
  VEE_RULE: { RuleID: C('INT', { id: true }), RuleType: C('VARCHAR(30)'), Parameters: C('NVARCHAR(1000)', { nul: true, chk: 'ISJSON(Parameters) = 1' }), IsActive: C('BIT', { def: '1' }) },
  VEE_RUN: { RunID: C('INT', { id: true }), PeriodFrom: C('DATETIME2(0)'), PeriodTo: C('DATETIME2(0)'), StartedAt: C('DATETIME2(0)', { def: NOW }), FinishedAt: C('DATETIME2(0)', { nul: true }) },
  TRANSFORMER: { TransformerID: C('INT', { id: true }), Name: C('NVARCHAR(50)'), Latitude: LAT, Longitude: LON },
  GEOFENCE: { GeofenceID: C('INT', { id: true }), Name: C('NVARCHAR(100)'), Level: C('TINYINT', { chk: 'Level >= 1' }),
    MinLat: C('DECIMAL(9,6)', { chk: 'MinLat BETWEEN -90 AND 90' }), MinLon: C('DECIMAL(9,6)', { chk: 'MinLon BETWEEN -180 AND 180' }),
    MaxLat: C('DECIMAL(9,6)', { chk: 'MaxLat BETWEEN -90 AND 90' }), MaxLon: C('DECIMAL(9,6)', { chk: 'MaxLon BETWEEN -180 AND 180' }) },
  METER_AGGREGATE: { PeriodType: C('VARCHAR(5)', { fixed: ['Day', 'Month', 'Year'] }), PeriodStart: C('DATE'), SumValue: C('DECIMAL(18,4)'), ReadingCount: C('INT', { chk: 'ReadingCount >= 1' }), EstimatedCount: C('INT', { chk: 'EstimatedCount >= 0' }) },
  GEOFENCE_AGGREGATE: { PeriodType: C('VARCHAR(6)', { fixed: ['15 min', 'Day', 'Month', 'Year'] }), PeriodStart: C('DATETIME2(0)'), SumValue: C('DECIMAL(18,4)'), MeterCount: C('INT', { chk: 'MeterCount >= 0' }) },
  GEOFENCE_CURRENT_STATE: { RefInterval: C('DATETIME2(0)', { chk: SLOT('RefInterval') }), SumValue: C('DECIMAL(18,4)'), MeterCount: C('INT', { chk: 'MeterCount >= 0' }), ComputedAt: C('DATETIME2(0)', { def: NOW }) },
  SUPPLIER: { SupplierID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  AGGREGATOR: { AggregatorID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  TARIFF_TYPE: { TariffTypeID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  SUPPLY_CONTRACT: { ContractID: C('INT', { id: true }), StartDate: C('DATE'), EndDate: C('DATE', { nul: true }) },
  PORTFOLIO: { PortfolioID: C('INT', { id: true }), Name: C('NVARCHAR(100)') },
  INCLUDES: { StartDate: C('DATE'), EndDate: C('DATE', { nul: true }) },
  GDPR_REQUEST: { GdprRequestID: C('INT', { id: true }), SubmittedAt: C('DATETIME2(0)', { def: NOW }),
    Status: C('VARCHAR(12)', { def: "'Submitted'", fixed: ['Submitted', 'Under review', 'Pre-approved', 'Approved', 'Rejected', 'Applied'] }),
    PreApprovedAt: C('DATETIME2(0)', { nul: true }), DecidedAt: C('DATETIME2(0)', { nul: true }), AppliedAt: C('DATETIME2(0)', { nul: true }) },
  AUDIT_LOG: { LogID: C('BIGINT', { id: true }), ObjectType: C('VARCHAR(30)'), ObjectID: C('VARCHAR(100)'), Action: C('VARCHAR(50)'), ActorMechanism: C('NVARCHAR(100)', { nul: true }),
    LoggedAt: C('DATETIME2(3)', { def: NOW }), OldState: C('NVARCHAR(400)', { nul: true }), NewState: C('NVARCHAR(400)', { nul: true }), ResultComment: C('NVARCHAR(1000)', { nul: true }) },
  EVENT: { EventID: C('BIGINT', { id: true }), EventType: C('VARCHAR(21)', { fixed: ['Undervoltage', 'Overvoltage', 'Communication failure', 'Unmatched packet', 'Tamper', 'Suspected theft'] }),
    Severity: C('VARCHAR(8)', { fixed: ['Info', 'Warning', 'Critical'] }), Description: C('NVARCHAR(1000)', { nul: true }), OccurredAt: C('DATETIME2(0)'),
    Status: C('VARCHAR(11)', { def: "'Open'", fixed: ['Open', 'In progress', 'Closed'] }) }
};

// ---------- row-level rules: CHECK constraints over several columns of one row ----------
const PERIOD = (type, start, withTime) => `(${type} = 'Day'${withTime ? ` AND CAST(${start} AS TIME) = '00:00'` : ''})
    OR (${type} = 'Month' AND DAY(${start}) = 1${withTime ? ` AND CAST(${start} AS TIME) = '00:00'` : ''})
    OR (${type} = 'Year' AND DAY(${start}) = 1 AND MONTH(${start}) = 1${withTime ? ` AND CAST(${start} AS TIME) = '00:00'` : ''})`;
const CHECKS = {
  FIELD_TECHNICIAN: [{ n: 'Decision', e: `(ApprovalStatus = 'Pending' AND ApprovedBy IS NULL AND ApprovalDecidedAt IS NULL)
    OR (ApprovalStatus <> 'Pending' AND ApprovedBy IS NOT NULL AND ApprovalDecidedAt IS NOT NULL)`, why: 'A decided technician has the ΛΣ who decided and the time; a pending one has neither.', src: ['S33', 'D31'] }],
  MARKET_USER: [{ n: 'OneCompany', e: `(SupplierID IS NOT NULL AND AggregatorID IS NULL) OR (SupplierID IS NULL AND AggregatorID IS NOT NULL)`, why: 'Exactly one company: a supplier or an aggregator.', src: ['D30'] }],
  HOLDING: [{ n: 'Dates', e: 'EndDate IS NULL OR EndDate >= StartDate', why: 'A holding period cannot end before it starts.', src: ['D5'] }],
  INVOICE: [{ n: 'Period', e: 'PeriodFrom <= PeriodTo', why: 'The billed period cannot end before it starts.', src: ['S24'] }],
  SERVICE_PURCHASE: [{ n: 'Months', e: `(MonthFrom IS NULL AND MonthTo IS NULL)
    OR (MonthFrom IS NOT NULL AND MonthTo IS NOT NULL AND DAY(MonthFrom) = 1 AND DAY(MonthTo) = 1 AND MonthFrom <= MonthTo)`, why: 'Unlocked months are given together, as first days of months, in order.', src: ['S21'] }],
  AVAILABILITY: [{ n: 'Slot', e: 'ToTime > FromTime', why: 'A time slot ends after it starts.', src: ['S31'] }],
  DOCUMENT: [
    { n: 'Owner', e: `(TechnicianID IS NOT NULL AND MeterID IS NULL AND DocType IN ('ID card', 'Installer licence', 'Training certificate'))
    OR (TechnicianID IS NULL AND MeterID IS NOT NULL AND DocType IN ('Calibration certificate', 'CE and protocol declaration', 'Encryption certificate'))`, why: 'Exactly one owner, and a document type that fits it.', src: ['D8', 'S32', 'S37'] },
    { n: 'Expiry', e: 'ExpiryDate IS NULL OR ExpiryDate > IssueDate', why: 'A document expires after it is issued.', src: ['S32'] },
    { n: 'Review', e: `(ReviewStatus = 'Pending' AND ReviewedBy IS NULL AND ReviewedAt IS NULL)
    OR (ReviewStatus <> 'Pending' AND ReviewedBy IS NOT NULL AND ReviewedAt IS NOT NULL)`, why: 'A reviewed document has the ΛΣ who reviewed it and the time.', src: ['S12', 'D31'] }],
  FIELD_TASK: [
    { n: 'Schedule', e: 'ScheduledTo > ScheduledFrom', why: 'The scheduled period ends after it starts.', src: ['S34'] },
    { n: 'Done', e: `(Status = 'Done' AND CompletedAt IS NOT NULL AND Result IS NOT NULL) OR (Status <> 'Done' AND CompletedAt IS NULL)`, why: 'A done task has the date it was carried out and its result; only a done task has a completion date.', src: ['S34', 'S41'] },
    { n: 'Target', e: 'PremiseID IS NOT NULL OR MeterID IS NOT NULL', why: 'A task names a premise, a meter, or both.', src: ['D9'] },
    { n: 'Install', e: `(TaskType NOT IN ('Installation', 'Replacement') OR PremiseID IS NOT NULL)
    AND (TaskType <> 'Installation' OR MeterID IS NULL)
    AND (TaskType <> 'Replacement' OR MeterID IS NOT NULL)`, why: 'Installations and replacements name the premise; TASK_ON is empty for an installation and names the old meter for a replacement.', src: ['D26'] }],
  METER_INSTALLATION: [
    { n: 'Removed', e: 'RemovedAt IS NULL OR RemovedAt > InstalledAt', why: 'A meter is removed after it is installed.', src: ['D10'] },
    { n: 'Confirmation', e: `(ConfirmationStatus = 'Pending' AND ConfirmedBy IS NULL AND ConfirmedAt IS NULL)
    OR (ConfirmationStatus <> 'Pending' AND ConfirmedBy IS NOT NULL AND ConfirmedAt IS NOT NULL)`, why: 'A confirmed or rejected installation has the ΛΣ who decided and the time.', src: ['S38'] }],
  REMOTE_COMMAND: [
    { n: 'ShedOrder', e: `(CommandType = 'Load shed' AND ShedOrderID IS NOT NULL) OR (CommandType <> 'Load shed' AND ShedOrderID IS NULL)`, why: 'Load shed commands, and only they, belong to a shedding order.', src: ['D11', 'D24'] },
    { n: 'Approval', e: `NOT (Status = 'Awaiting approval' AND ApprovedBy IS NOT NULL)`, why: 'A command that has an approver is no longer awaiting approval.', src: ['S4'] }],
  COMMAND_ATTEMPT: [{ n: 'Response', e: `((Outcome IS NULL OR Outcome = 'Timeout') AND RespondedAt IS NULL)
    OR (Outcome IN ('NAK', 'ACK') AND RespondedAt IS NOT NULL AND RespondedAt >= AttemptAt)`, why: 'Only an answer (NAK or ACK) has a response time, never earlier than the attempt.', src: ['S40'] }],
  OBIS_CODE: [{ n: 'Range', e: 'MinValid IS NULL OR MaxValid IS NULL OR MinValid < MaxValid', why: 'The valid range is not empty.', src: ['S45'] }],
  TELEMETRY_PACKET: [
    { n: 'Meter', e: `(IngestStatus IN ('Accepted', 'Partially accepted', 'Meter not active') AND MeterID IS NOT NULL)
    OR (IngestStatus = 'Unknown meter' AND MeterID IS NULL) OR IngestStatus = 'Malformed'`, why: 'A packet from a known meter points to it; an unknown network ID has no meter.', src: ['S42', 'S43'] },
    { n: 'Error', e: `IngestStatus NOT IN ('Partially accepted', 'Malformed') OR ErrorMessage IS NOT NULL`, why: 'What was rejected is written down, so nothing is lost silently.', src: ['S43'] }],
  READING: [
    { n: 'Gap', e: `ReceivedValue IS NOT NULL OR Status IN ('Suspect', 'Estimated', 'Edited')`, why: 'A gap is never Raw or Validated.', src: ['S45', 'S67'] },
    { n: 'Packet', e: '(PacketID IS NULL AND ReceivedValue IS NULL) OR (PacketID IS NOT NULL AND ReceivedValue IS NOT NULL)', why: 'A received value comes from a packet; a gap comes from none.', src: ['S42', 'S67'] },
    { n: 'Value', e: `Status NOT IN ('Validated', 'Estimated', 'Edited') OR UsedValue IS NOT NULL`, why: 'A reading that later functions may use has a value to use.', src: ['S46', 'D12'] },
    { n: 'Final', e: `RunID IS NULL OR Status IN ('Validated', 'Estimated', 'Edited')`, why: 'Only a validated, estimated or edited reading is finalized; a suspect one goes back for correction.', src: ['S49', 'S75', 'D13'] }],
  READING_EDIT: [{ n: 'OriginActor', e: `(Origin = 'Automatic estimate' AND EditedBy IS NULL AND RuleID IS NOT NULL)
    OR (Origin = 'Manual estimate' AND EditedBy IS NOT NULL)
    OR (Origin = 'Manual edit' AND EditedBy IS NOT NULL AND RuleID IS NULL)`, why: 'An automatic estimate has a rule and no user; a manual change has a DSO user, and a manual edit no rule.', src: ['S48', 'S75'] }],
  VEE_RUN: [{ n: 'Period', e: 'PeriodTo > PeriodFrom AND (FinishedAt IS NULL OR FinishedAt >= StartedAt)', why: 'The period and the run end after they start.', src: ['S49'] }],
  GEOFENCE: [
    { n: 'Rectangle', e: 'MinLat < MaxLat AND MinLon < MaxLon', why: 'The rectangle is not empty.', src: ['S52'] },
    { n: 'Parent', e: 'ParentGeofenceID IS NULL OR ParentGeofenceID <> GeofenceID', why: 'A geofence is not its own parent.', src: ['D14'] }],
  METER_AGGREGATE: [
    { n: 'Counts', e: 'EstimatedCount <= ReadingCount', why: 'Estimated readings are part of the readings counted.', src: ['S22'] },
    { n: 'Period', e: PERIOD('PeriodType', 'PeriodStart', false), why: 'A month starts on the 1st and a year on 1 January.', src: ['S22'] }],
  GEOFENCE_AGGREGATE: [{ n: 'Period', e: `(PeriodType = '15 min' AND ${SLOT('PeriodStart')})
    OR ${PERIOD('PeriodType', 'PeriodStart', true)}`, why: 'Each period starts on its boundary: a 15-minute slot, midnight, the 1st of the month or 1 January.', src: ['S30', 'S56'] }],
  GEOFENCE_CURRENT_STATE: [{ n: 'Code', e: `ObisCode IN ('1.8.0', '2.8.0')`, why: 'The current state is kept only for 1.8.0 and 2.8.0.', src: ['S55'] }],
  SUPPLY_CONTRACT: [{ n: 'Dates', e: 'EndDate IS NULL OR EndDate >= StartDate', why: 'A contract cannot end before it starts.', src: ['D16'] }],
  INCLUDES: [{ n: 'Dates', e: 'EndDate IS NULL OR EndDate >= StartDate', why: 'A membership cannot end before it starts.', src: ['D28'] }],
  GDPR_REQUEST: [
    { n: 'OneFinal', e: 'DecidedBy IS NULL OR DecidedByAdmin IS NULL', why: 'At most one final approver, a ΛΣ or a ΔΣ.', src: ['D17'] },
    { n: 'PreApproval', e: '(PreApprovedBy IS NULL AND PreApprovedAt IS NULL) OR (PreApprovedBy IS NOT NULL AND PreApprovedAt IS NOT NULL)', why: 'The examining ΛΣ and the time come together.', src: ['S25'] },
    { n: 'Decision', e: '(DecidedAt IS NULL AND DecidedBy IS NULL AND DecidedByAdmin IS NULL) OR (DecidedAt IS NOT NULL AND (DecidedBy IS NOT NULL OR DecidedByAdmin IS NOT NULL))', why: 'The final decision has its approver and its time.', src: ['S25', 'S30'] },
    { n: 'Stage', e: `(Status IN ('Submitted', 'Under review') AND PreApprovedAt IS NULL AND DecidedAt IS NULL AND AppliedAt IS NULL)
    OR (Status = 'Pre-approved' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NULL AND AppliedAt IS NULL)
    OR (Status = 'Approved' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NULL)
    OR (Status = 'Rejected' AND PreApprovedAt IS NOT NULL AND AppliedAt IS NULL)
    OR (Status = 'Applied' AND PreApprovedAt IS NOT NULL AND DecidedAt IS NOT NULL AND AppliedAt IS NOT NULL)`, why: 'The status matches the stages already passed. PreApprovedBy and PreApprovedAt record the examination, so a request rejected there has them and no final decision; one rejected at the final decision has both.', src: ['S25', 'S30'] },
    { n: 'Order', e: '(PreApprovedAt IS NULL OR PreApprovedAt >= SubmittedAt) AND (DecidedAt IS NULL OR DecidedAt >= PreApprovedAt) AND (AppliedAt IS NULL OR AppliedAt >= DecidedAt)', why: 'The stages happen in order.', src: ['S25'] }],
  AUDIT_LOG: [{ n: 'Actor', e: 'PerformedBy IS NOT NULL OR ActorMechanism IS NOT NULL', why: 'Every entry names the user or the mechanism that caused it.', src: ['S13'] }],
  EVENT: [{ n: 'Unmatched', e: `EventType <> 'Unmatched packet' OR PacketID IS NOT NULL`, why: 'An unmatched-packet event points to its packet.', src: ['S43'] }]
};

// UNIQUE over several columns, and filtered UNIQUE indexes (at most one open row)
const UNIQUES = {
  PARISH: [{ cols: ['MunicipalityID', 'Name'], why: 'No two parishes of one municipality share a name.', src: ['D4'] }],
  MUNICIPALITY: [{ cols: ['DistrictID', 'Name'], why: 'No two municipalities of one district share a name.', src: ['D4'] }],
  METER_MODEL: [{ cols: ['Manufacturer', 'ModelName'], why: 'A model is entered once.', src: ['S12'] }]
};
const FILTERED = [
  { table: 'HOLDING', name: 'UX_HOLDING_Open', cols: ['UserID', 'PremiseID'], where: 'EndDate IS NULL', why: 'A consumer has at most one open holding period per premise.', src: ['D5'] },
  { table: 'METER_INSTALLATION', name: 'UX_METER_INSTALLATION_Open', cols: ['MeterID'], where: 'RemovedAt IS NULL', why: 'A meter is installed in at most one place at a time.', src: ['D10'] },
  { table: 'SUPPLY_CONTRACT', name: 'UX_SUPPLY_CONTRACT_Open', cols: ['PremiseID'], where: 'EndDate IS NULL', why: 'A premise has at most one open supply contract, so one supplier at a time.', src: ['S7', 'D16'] }
];

// tables whose rows are part of their owner: ON DELETE CASCADE from the owner (T8)
const CASCADE = new Set(['AVAILABILITY', 'TASK_NOTE', 'COMMAND_ATTEMPT', 'READING_EDIT']);

// ---------- the mapping ----------
const ents = new Map(); const homeArea = new Map(); const rels = [];
areas.forEach(a => { a.entities.forEach(e => { ents.set(e.name, e); homeArea.set(e.name, a.id); }); a.rels.forEach(r => rels.push({ ...r, area: a.id })); });
const snake = s => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toUpperCase();
const tables = new Map();
const T = name => tables.get(name);
const isIdent = r => r.ident;
// in an identifying relationship the weak end is the N side (1:N) or the total side (1:1); the other end is the owner
const weakEnd = r => { const [a, b] = r.ends; if (a.card !== b.card) return a.card === '1' ? b : a; return a.total ? a : b; };
const ownerRels = name => rels.filter(r => r.ident && weakEnd(r).e === name);
const pkCols = name => T(name).cols.filter(c => c.pk);
const typeOf = (table, col) => { const s = TYPES[table] && TYPES[table][col]; if (!s) throw new Error(`no type for ${table}.${col}`); return s; };

function addEntityTable(e) {
  const t = { name: e.name, area: homeArea.get(e.name), kind: e.weak ? 'weak' : 'entity', from: { entity: e.name }, cols: [], fks: [], uniques: [], checks: [] };
  tables.set(e.name, t);
  return t;
}
function attrCols(e, t) {
  for (const a of e.attrs) {
    const at = parseAttr(a);
    if (at.multi) continue;
    const names = at.parts || [at.name];
    for (const n of names) {
      const s = typeOf(t.name, n);
      t.cols.push({ name: n, type: s.t, nul: !!s.nul, id: !!s.id, def: s.def, chk: s.chk, fixed: s.fixed, pk: !!(at.key || at.partial), origin: { attr: at.parts ? `${at.name}(${at.parts.join(', ')})` : at.name, key: at.key ? 'key' : at.partial ? 'partial' : at.unique ? 'unique' : null } });
    }
    if (at.unique) t.uniques.push({ cols: [at.name], why: 'Alternate key of the ER model.', src: [] });
  }
}
function fkCols(target, rel, names, opts) {
  // copies the key of `target` (with its types) as foreign-key columns
  const pk = pkCols(target);
  const rename = names || (rel && rel.fk && pk.length === 1 ? [rel.fk] : null);
  return pk.map((c, i) => ({ name: rename ? rename[i] : c.name, type: c.type, refCol: c.name, nul: !!opts.nul, pk: !!opts.pk, origin: { fk: target, rel: rel ? rel.name : null } }));
}
function addFk(t, target, rel, opts) {
  const cols = fkCols(target, rel, opts.names, opts);
  cols.forEach(c => { if (t.cols.some(x => x.name === c.name)) throw new Error(`column clash ${t.name}.${c.name} from ${rel ? rel.name : target}`); });
  t.cols.push(...cols);
  t.fks.push({ cols: cols.map(c => c.name), ref: target, refCols: cols.map(c => c.refCol), rel: rel ? rel.name : null, onDelete: opts.cascade ? 'CASCADE' : 'NO ACTION', name: `FK_${t.name}_${rel ? rel.name : target}` });
  if (opts.unique) t.uniques.push({ cols: cols.map(c => c.name), why: 'One-to-one relationship: the foreign key is unique.', src: ['L16'] });
  return cols;
}

// Step 1 (regular entities) and Step 2 (weak entities, owners first)
for (const e of ents.values()) if (!e.weak) { const t = addEntityTable(e); attrCols(e, t); }
const pending = [...ents.values()].filter(e => e.weak);
while (pending.length) {
  const i = pending.findIndex(e => ownerRels(e.name).every(r => r.ends.filter(x => x.e !== e.name).every(x => tables.has(x.e))));
  if (i < 0) throw new Error('weak owner cycle: ' + pending.map(e => e.name + '<' + ownerRels(e.name).map(r => r.name).join('+')).join(', '));
  const e = pending.splice(i, 1)[0]; const t = addEntityTable(e);
  for (const r of ownerRels(e.name)) for (const x of r.ends.filter(x => x.e !== e.name)) addFk(t, x.e, r, { pk: true, cascade: CASCADE.has(e.name) });
  attrCols(e, t);
  t.from.owners = ownerRels(e.name).map(r => ({ rel: r.name, owner: r.ends.find(x => x.e !== e.name).e }));
}
// Steps 3 to 5: binary relationships (identifying ones are done)
const mnTables = [];
for (const r of rels) {
  if (r.ident) continue;
  const [a, b] = r.ends; const rec = a.e === b.e;
  if (a.card === '1' && b.card === '1') {
    const fkSide = a.total ? a : b; const other = fkSide === a ? b : a;
    addFk(T(fkSide.e), other.e, r, { nul: !fkSide.total, unique: true });
  } else if (a.card === '1' || b.card === '1') {
    const one = a.card === '1' ? a : b; const many = one === a ? b : a;
    addFk(T(many.e), one.e, r, { nul: !many.total });
  } else {
    const t = { name: r.name, area: r.area, kind: 'mn', from: { rel: r.name }, cols: [], fks: [], uniques: [], checks: [] };
    tables.set(r.name, t); mnTables.push(t);
    for (const x of r.ends) addFk(t, x.e, { name: r.name + '_' + x.e }, { pk: true, cascade: true });
    t.fks.forEach((f, k) => { f.rel = r.name; f.name = `FK_${r.name}_${r.ends[k].e}`; });
    t.cols.forEach(c => { c.origin.rel = r.name; });
    for (const a2 of r.attrs || []) { const s = typeOf(r.name, a2); t.cols.push({ name: a2, type: s.t, nul: !!s.nul, def: s.def, chk: s.chk, fixed: s.fixed, origin: { attr: a2, relAttr: r.name } }); }
  }
  if (rec) T(a.e).recursive = r.name;
}
// Step 6: multivalued attributes
for (const e of ents.values()) for (const a of e.attrs) {
  const at = parseAttr(a); if (!at.multi) continue;
  const name = `${e.name}_${snake(at.name)}`;
  const t = { name, area: homeArea.get(e.name), kind: 'multi', from: { entity: e.name, attr: at.name }, cols: [], fks: [], uniques: [], checks: [] };
  tables.set(name, t);
  addFk(t, e.name, null, { pk: true, cascade: true });
  const s = typeOf(name, at.name);
  t.cols.push({ name: at.name, type: s.t, nul: false, chk: s.chk, fixed: s.fixed, pk: true, origin: { attr: `{${at.name}}` } });
}
// extra row rules and uniques
for (const [name, list] of Object.entries(CHECKS)) { if (!T(name)) throw new Error('CHECK on unknown table ' + name); T(name).checks.push(...list.map(c => ({ ...c, name: `CK_${name}_${c.n}` }))); }
for (const [name, list] of Object.entries(UNIQUES)) T(name).uniques.push(...list);
// every type entry must be used
for (const [tn, cols] of Object.entries(TYPES)) for (const cn of Object.keys(cols)) if (!T(tn) || !T(tn).cols.some(c => c.name === cn)) throw new Error(`unused type ${tn}.${cn}`);
// every column referenced in a CHECK must exist
for (const t of tables.values()) for (const c of t.checks) for (const w of c.e.match(/\b[A-Z][A-Za-z]+(?:ID|At|By|Date|Value|Type|Status|Count|From|To|Time|Start|Lat|Lon|Code|Origin|Outcome|Message|Mechanism)\b/g) || []) {
  if (!t.cols.some(x => x.name === w)) throw new Error(`CHECK ${c.name} uses unknown column ${w}`);
}

// every constraint name is unique in the database and fits sysname
{
  const names = [];
  for (const t of tables.values()) {
    names.push('PK_' + t.name, ...t.uniques.map(u => `UQ_${t.name}_${u.cols.join('_')}`), ...t.fks.map(f => f.name), ...t.checks.map(c => c.name));
    for (const c of t.cols) { if (c.def) names.push(`DF_${t.name}_${c.name}`); if (c.fixed) names.push(`CK_${t.name}_${c.name}`); if (c.chk) names.push(`CK_${t.name}_${c.name}${c.fixed ? '2' : ''}`); }
  }
  names.push(...FILTERED.map(f => f.name));
  const dup = names.filter((n, i) => names.indexOf(n) !== i); if (dup.length) throw new Error('duplicate constraint names ' + dup.join(', '));
  const long = names.filter(n => n.length > 128); if (long.length) throw new Error('names too long ' + long.join(', '));
}

// ---------- order (foreign keys before use) and DDL ----------
const order = [];
const seen = new Set();
const areaRank = new Map(areas.map((a, i) => [a.id, i]));
const listed = [...tables.values()].sort((x, y) => areaRank.get(x.area) - areaRank.get(y.area));
const visit = (t, path = []) => {
  if (seen.has(t.name)) return; if (path.includes(t.name)) throw new Error('FK cycle ' + path.join('>'));
  for (const f of t.fks) if (f.ref !== t.name) visit(T(f.ref), [...path, t.name]);
  seen.add(t.name); order.push(t);
};
listed.forEach(t => visit(t));

const q = s => s; // names need no brackets (checked against the reserved words in SQL Server)
function colDdl(t, c) {
  let s = `    ${q(c.name)} ${c.type}`;
  if (c.id) s += ' IDENTITY(1,1)';
  s += c.nul ? ' NULL' : ' NOT NULL';
  if (c.def) s += ` CONSTRAINT DF_${t.name}_${c.name} DEFAULT ${c.def}`;
  if (c.fixed) s += ` CONSTRAINT CK_${t.name}_${c.name} CHECK (${c.name} IN (${c.fixed.map(v => `'${v}'`).join(', ')}))`;
  if (c.chk) s += ` CONSTRAINT CK_${t.name}_${c.name}${c.fixed ? '2' : ''} CHECK (${c.chk})`;
  return s;
}
function tableDdl(t) {
  const lines = t.cols.map(c => colDdl(t, c));
  const pk = t.cols.filter(c => c.pk).map(c => c.name);
  lines.push(`    CONSTRAINT PK_${t.name} PRIMARY KEY (${pk.join(', ')})`);
  t.uniques.forEach(u => lines.push(`    CONSTRAINT UQ_${t.name}_${u.cols.join('_')} UNIQUE (${u.cols.join(', ')})`));
  t.fks.forEach(f => lines.push(`    CONSTRAINT ${f.name} FOREIGN KEY (${f.cols.join(', ')}) REFERENCES ${f.ref} (${f.refCols.join(', ')})${f.onDelete === 'CASCADE' ? ' ON DELETE CASCADE' : ''}`));
  t.checks.forEach(c => lines.push(`    CONSTRAINT ${c.name} CHECK (${c.e})`));
  return `CREATE TABLE ${t.name} (\n${lines.join(',\n')}\n);`;
}
const filteredDdl = f => `CREATE UNIQUE INDEX ${f.name} ON ${f.table} (${f.cols.join(', ')}) WHERE ${f.where};`;
const header = `-- MDMS-Cy, ΕΠΛ342 Φάση Α: σχεσιακό σχήμα (T-SQL, Microsoft SQL Server 2025 ή 2022)
-- Από το απλό μοντέλο ER (χωρίς EER) του βήματος 2. ${tables.size} πίνακες, σε σειρά ώστε κάθε ξένο κλειδί να δείχνει σε πίνακα που υπάρχει ήδη.
-- Τρέξτε το σε κενή βάση. Το drop.sql σβήνει τους πίνακες με την αντίστροφη σειρά.
-- Οι τρεις φιλτραρισμένοι δείκτες UNIQUE θέλουν SET QUOTED_IDENTIFIER ON σε κάθε σύνδεση που γράφει σε αυτούς τους πίνακες:
-- το SSMS και οι οδηγοί SQL Server της PHP το ενεργοποιούν, στο sqlcmd δώστε -I.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
`;
const ddl = header + order.map(t => `-- ${t.name}\n${tableDdl(t)}\nGO\n`).join('\n') + '\n-- Μοναδικότητα με φίλτρο: το πολύ μία ανοιχτή γραμμή\n' + FILTERED.map(f => filteredDdl(f)).join('\n') + '\nGO\n';
const dropDdl = `-- MDMS-Cy: σβήνει όλους τους πίνακες του create.sql, με την αντίστροφη σειρά.\n` + [...order].reverse().map(t => `DROP TABLE IF EXISTS ${t.name};`).join('\n') + '\nGO\n';

// ---------- rules a CHECK cannot express (Phase B: triggers or stored procedures) ----------
const RULES = [
  { area: 'users', text: 'Every account has at least one role row. The registration procedures create the account and its first role in one transaction, and a trigger refuses to delete the last role of an account.', how: 'procedure + trigger', src: ['D2'] },
  { area: 'users', text: 'A technician belongs to at least one category and has the three required documents, each Accepted, before APPROVES may set Approved. Tasks are assigned only to Approved technicians.', how: 'procedure', src: ['S31', 'S32'] },
  { area: 'premises', text: 'Holding periods of the same consumer and premise do not overlap.', how: 'trigger', src: ['D5'] },
  { area: 'premises', text: 'A consumer sets thresholds, files requests, buys services, links bank accounts and signs contracts only for premises they hold at that time.', how: 'procedure', src: ['D24'] },
  { area: 'billing', text: 'A bank account has an owner (OWNS_ACCOUNT) or at least one ACCOUNT_FOR row. The insert procedure adds the account and its ACCOUNT_FOR rows and checks this at its end, because an AFTER INSERT trigger runs before those rows exist; a trigger refuses to remove the last ACCOUNT_FOR row of an account without an owner.', how: 'procedure + trigger', src: ['D22'] },
  { area: 'billing', text: 'An invoice has a contract or at least one SERVICE_PURCHASE. Its consumer equals the contract\'s consumer and the buyer of its purchases, and a PAID_FROM account belongs to that consumer or pays for that premise. The insert procedure adds the invoice and its SERVICE_PURCHASE rows and checks this at its end, because an AFTER INSERT trigger runs before those rows exist; a trigger refuses to remove the last purchase of an invoice without a contract.', how: 'procedure + trigger', src: ['D23', 'D24'] },
  { area: 'billing', text: 'A Historical data access purchase gives MonthFrom and MonthTo, inside the consumer\'s retention period; other service types leave them empty.', how: 'procedure', src: ['S21', 'S66'] },
  { area: 'field', text: 'The availability slots of a technician do not overlap, and each slot covers at least one municipality.', how: 'trigger', src: ['S31', 'D7'] },
  { area: 'field', text: 'An installation is done in an Installation or Replacement task whose premise is the installation\'s premise. When a task or request names a premise and a meter, the meter is installed there at that date.', how: 'trigger', src: ['D24', 'D26'] },
  { area: 'meters', text: 'The installations of a meter do not overlap, and METER.Status follows its open installation (Active only while it is Confirmed).', how: 'trigger', src: ['D10', 'S38'] },
  { area: 'meters', text: 'A meter has at least one document, and one of each equipment type, Accepted, before CONFIRMS may set Confirmed.', how: 'procedure', src: ['S37', 'S38'] },
  { area: 'meters', text: 'A Single-Phase meter has one connected phase and a Three-Phase meter three.', how: 'trigger', src: ['S36'] },
  { area: 'meters', text: 'A shedding order creates one Load shed command for every Active meter SERVED_BY its transformer, so it has at least one. Order status follows its commands, and command status follows its attempts.', how: 'procedure', src: ['D11', 'D24'] },
  { area: 'telemetry', text: 'A finalized reading (RunID set) is immutable: its value and status never change, and it gets no more edits.', how: 'trigger', src: ['S49', 'S50'] },
  { area: 'telemetry', text: 'A reading from a packet has the packet\'s meter, and an event from a packet has the packet\'s meter as EVENT_ON.', how: 'trigger', src: ['D24'] },
  { area: 'telemetry', text: 'The retention purge deletes raw readings after the holder\'s RawRetentionMonths (36, or 1 after an approved GDPR request), then the packets that no reading or event still uses, and never deletes aggregates.', how: 'procedure', src: ['D19', 'D29'] },
  { area: 'grid', text: 'An aggregate row is written once, when every reading of its period is final, only for cumulative registers, and never changed.', how: 'procedure + trigger', src: ['D13'] },
  { area: 'grid', text: 'Geofence levels follow the tree: a child is one level below its parent, only level-1 geofences have a transformer, every higher geofence has a child, and level-1 rectangles do not overlap.', how: 'trigger', src: ['D14'] },
  { area: 'grid', text: 'SERVED_BY is the transformer of the level-1 geofence that contains the meter\'s coordinates.', how: 'procedure', src: ['D25'] },
  { area: 'market', text: 'The supply contracts of a premise do not overlap in time.', how: 'trigger', src: ['D16'] },
  { area: 'trace', text: 'Every critical state change (approvals, statuses, VEE results, GDPR stages) writes an AUDIT_LOG row with user or mechanism, time, old and new state.', how: 'procedure', src: ['S13', 'D18'] }
];

// ---------- schema conventions ----------
const SDEC = [
  { id: 'T1', title: 'Tables follow the textbook mapping', text: 'Every regular entity becomes a table with its key. A weak entity becomes a table whose key is its owner\'s key plus its partial key. A 1:N relationship becomes a foreign key on the N side, NOT NULL when that side takes part totally. A 1:1 relationship becomes a UNIQUE foreign key on the side that takes part totally. An M:N relationship and a multivalued attribute become tables of their own, and a composite attribute becomes its parts. Only the M:N INCLUDES carries attributes (D31).', src: ['L16', 'L2', 'D31'] },
  { id: 'T2', title: 'Names follow ERD+', text: 'A foreign key takes the name of the key it points to, as the ERD+ conversion does. It is renamed where two would clash or where the role would not be clear (the rename table on the ER page). Constraint names say what they guard: PK_TABLE, FK_TABLE_RELATIONSHIP, UQ_, CK_ and DF_, so an error message names the rule that was broken.', src: ['L9'] },
  { id: 'T3', title: 'Keys', text: 'Surrogate keys are INT IDENTITY(1,1). The three tables that grow fastest, TELEMETRY_PACKET, AUDIT_LOG and EVENT, use BIGINT. OBIS_CODE keeps its natural key, the code itself, which the packets carry. The role tables take UserID from USER_ACCOUNT, so a role is a row, not a new number.', src: ['S42', 'S64', 'D2'] },
  { id: 'T4', title: 'Text, files and passwords', text: 'NVARCHAR holds text that people type and that may be in Greek (names, addresses, comments). VARCHAR holds codes, e-mail, IBAN and the fixed English status values. Photos, documents and attachments are files outside the database, which keeps their path. PasswordHash is VARCHAR(255) for the output of PHP password_hash(), which salts and hashes, so no one can read a password from the table.', src: ['S10', 'S78'] },
  { id: 'T5', title: 'Times and dates', text: 'All times are DATETIME2 in UTC, as the packets carry UTC times (for example "2026-10-30T12:00:00Z"). DATETIME2(0) keeps seconds; reception, command attempts and the audit log keep milliseconds, where order within a second matters. Reading slots and current-state slots start at :00, :15, :30 or :45 (CHECK). Date ranges (holdings, contracts, portfolio membership, invoices) include both ends, and EndDate is empty while the period is open.', src: ['S42', 'S64'] },
  { id: 'T6', title: 'Numbers', text: 'Energy, voltage and current are DECIMAL(15,4), since the sample packet has four decimals; sums are DECIMAL(18,4). Money is DECIMAL(12,2), fees DECIMAL(10,2). Coordinates are DECIMAL(9,6) (about 0.1 m), with range CHECKs.', src: ['S64', 'S16'] },
  { id: 'T7', title: 'Fixed lists are CHECKs, open lists are tables', text: 'A status or type whose values the spec fixes has a CHECK ... IN (...) list. Where the spec wants new values without a change of structure (meter models, communication types, supply schemes, OBIS codes, VEE methods), the values are rows of a table, and VEE_RULE.RuleType has no fixed list.', src: ['S60', 'S44'] },
  { id: 'T8', title: 'ON DELETE', text: 'CASCADE only from an owner to rows that are part of it: multivalued attributes, M:N rows, AVAILABILITY, TASK_NOTE, COMMAND_ATTEMPT and READING_EDIT (the retention purge deletes the edits with their reading). Every other foreign key is NO ACTION, so deleting an account, meter or premise that has history fails instead of erasing that history.', src: ['S39', 'S49', 'D19', 'D29'] },
  { id: 'T9', title: 'One row: CHECK. More rows: Phase B', text: 'A CHECK in SQL Server sees only its own row. So the rules inside one row are CHECKs: exactly one of two foreign keys, a status that matches its times, the Origin rule. Filtered UNIQUE indexes allow at most one open holding per consumer and premise, one open installation per meter and one open contract per premise. These indexes need SET QUOTED_IDENTIFIER ON in every connection that writes to those tables: SSMS and the PHP drivers for SQL Server turn it on, and sqlcmd needs the -I option. Rules that read other rows or tables are listed below; in Phase B they become triggers or stored procedures, which the spec wants inside the database anyway.', src: ['S78', 'D24'] },
  { id: 'T10', title: 'Indexes come in step 6', text: 'Primary keys and UNIQUE constraints already create indexes. The performance indexes, of which the spec asks for the three most important with an explanation, belong to step 6, when there is enough synthetic data to measure them.', src: ['S79'] }
];

module.exports = { tables, order, ddl, dropDdl, FILTERED, RULES, SDEC, CASCADE };

if (require.main === module) {
  const fs = require('fs');
  fs.writeFileSync('create.sql', ddl); fs.writeFileSync('drop.sql', dropDdl);
  const n = { tables: tables.size, cols: [...tables.values()].reduce((s, t) => s + t.cols.length, 0), fks: [...tables.values()].reduce((s, t) => s + t.fks.length, 0),
    checks: [...tables.values()].reduce((s, t) => s + t.checks.length + t.cols.filter(c => c.fixed || c.chk).length, 0), uniques: [...tables.values()].reduce((s, t) => s + t.uniques.length, 0) + FILTERED.length };
  console.log(JSON.stringify(n), 'order:', order.map(t => t.name).join(' '));
}
