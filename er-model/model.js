// Attribute shorthand: 'Name' plain, '_Name' key (underlined), '~Name' partial key (dashed underline), '{Name}' multivalued, '!Name' unique (not underlined).
const E = (name, attrs, src, opts = {}) => ({ name, attrs, src, ...opts });
// Relationship ends: [entity, ratio label written on that entity's line, total?, role?]
const R = (name, ends, src, opts = {}) => ({ name, ends: ends.map(([e, card, total, role]) => ({ e, card, total: !!total, role })), src, ...opts });

const areas = [
  {
    id: 'users', title: 'Users and roles',
    lead: 'One account per person. Each role is its own entity, because each has its own attributes or its own relationships. A role is a weak entity of USER_ACCOUNT with a 1:1 identifying relationship, so its key is the UserID of the account. One person can hold several roles, and every account has at least one.',
    leadSrc: ['S9', 'S11', 'D1', 'D2', 'D32'],
    entities: [
      E('USER_ACCOUNT', ['_UserID', '!Username', 'PasswordHash', '!Email', 'Phone', 'FirstName', 'LastName', 'AccountStatus', 'CreatedAt'], ['S9', 'S10', 'S14', 'S32'],
        { note: 'PasswordHash holds a salted one-way hash, never the password. AccountStatus: Active or Suspended; Suspended blocks login for every role.' }),
      E('CONSUMER', ['RawRetentionMonths', '{NotificationChannel}'], ['S14', 'S20', 'S27', 'S28', 'D19', 'C4'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_CONSUMER), so Key = UserID. RawRetentionMonths is 36 by default and 1 after an approved GDPR request. NotificationChannel takes Email and/or SMS.' }),
      E('FIELD_TECHNICIAN', ['BirthDate', 'Photo', 'ApprovalStatus', 'ApprovalDecidedAt'], ['S31', 'S32', 'S33', 'D31'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_TECHNICIAN), so Key = UserID. ApprovalStatus: Pending, Approved, Rejected, Suspended (Suspended stops technician work only). ApprovalDecidedAt is the time of the latest ΛΣ decision. No task may be assigned before Approved.' }),
      E('MARKET_USER', [], ['S57', 'D3'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_MARKET_USER), for supplier and aggregator staff. It has no own attributes, only WORKS_FOR_SUPPLIER or WORKS_FOR_AGGREGATOR (Market area).' }),
      E('SYSTEM_ADMIN', [], ['S11', 'D2'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_ADMIN), for the ΔΣ, the root role. The first ΔΣ is inserted by hand in the database. A ΔΣ creates ΛΣ accounts (CREATES) and may give the final approval of a GDPR request (FINAL_APPROVES_ADMIN).' }),
      E('SYSTEM_OPERATOR', [], ['S11', 'D2'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_OPERATOR), for the ΛΣ, the approval role. Every ΛΣ is created by a ΔΣ. Its decisions: APPROVES, REVIEWS, CONFIRMS, APPROVED_BY, PRE_APPROVES and FINAL_APPROVES.' }),
      E('TSO_OPERATOR', [], ['S6', 'D2'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_TSO), for TSO staff, who order load shedding (ORDERED_BY).' }),
      E('DSO_OPERATOR', [], ['S73', 'S74', 'D2'],
        { weak: true, note: 'Weak entity owned by USER_ACCOUNT (IS_DSO), for DSO staff. VEE is a DSO function, so only they estimate or edit readings by hand (EDITED_BY).' })
    ],
    rels: [
      R('IS_CONSUMER', [['USER_ACCOUNT', '1', false], ['CONSUMER', '1', true]], ['S14', 'D2', 'L2'],
        { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_TECHNICIAN', [['USER_ACCOUNT', '1', false], ['FIELD_TECHNICIAN', '1', true]], ['S31', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_MARKET_USER', [['USER_ACCOUNT', '1', false], ['MARKET_USER', '1', true]], ['S57', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_ADMIN', [['USER_ACCOUNT', '1', false], ['SYSTEM_ADMIN', '1', true]], ['S11', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_OPERATOR', [['USER_ACCOUNT', '1', false], ['SYSTEM_OPERATOR', '1', true]], ['S11', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_TSO', [['USER_ACCOUNT', '1', false], ['TSO_OPERATOR', '1', true]], ['S6', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('IS_DSO', [['USER_ACCOUNT', '1', false], ['DSO_OPERATOR', '1', true]], ['S73', 'D2', 'L2'], { ident: true, note: 'Identifying 1:1: an account has at most one row of this role, and the row exists only while the account holds the role.' }),
      R('CREATES', [['SYSTEM_ADMIN', '1', false], ['SYSTEM_OPERATOR', 'N', true]], ['S11', 'D2'],
        { fk: 'CreatedBy', note: 'Total on the ΛΣ side: every ΛΣ is created by a ΔΣ. Partial on the ΔΣ side: a ΔΣ need not have created anyone.' }),
      R('APPROVES', [['SYSTEM_OPERATOR', '1', false], ['FIELD_TECHNICIAN', 'N', false]], ['S31', 'S33', 'D31'],
        { fk: 'ApprovedBy', note: 'Records which ΛΣ approved or rejected the technician. ApprovalStatus and ApprovalDecidedAt hold the latest result, and every decision is also written to AUDIT_LOG. Partial on the technician side: a newly registered technician is still Pending.' })
    ]
  },
  {
    id: 'premises', title: 'Consumers and premises',
    lead: 'A consumer can hold many premises over time, and each holding period is its own row. Each premise sits in one parish of the District, Municipality, Parish hierarchy and follows one supply scheme.',
    leadSrc: ['S15', 'S16', 'S18'],
    entities: [
      E('PREMISE', ['_PremiseID', 'Address', 'PostalCode', 'Latitude', 'Longitude', 'UsageType'], ['S16'],
        { note: 'UsageType: Residential, Commercial, Industrial, Agricultural. Coordinates are WGS84.' }),
      E('HOLDING', ['~StartDate', 'EndDate'], ['S15', 'D5', 'L2'], { weak: true,
        note: 'Weak entity with two owners, CONSUMER and PREMISE: one row per holding period. Key = (UserID, PremiseID, StartDate). EndDate is empty while the consumer still holds the premise; periods of the same pair do not overlap.' }),
      E('PARISH', ['_ParishID', 'Name'], ['S16', 'D4']),
      E('MUNICIPALITY', ['_MunicipalityID', 'Name'], ['S16', 'D4']),
      E('DISTRICT', ['_DistrictID', '!Name'], ['S16', 'D4']),
      E('SUPPLY_SCHEME', ['_SchemeID', '!Name'], ['S18', 'S60'],
        { note: 'Rows: Consumption only, Net Metering, Net Billing. A new prosumer class is a new row.' }),
      E('CONSUMPTION_THRESHOLD', ['_ThresholdID', 'LimitKWh', 'PeriodType', 'IsActive'], ['S20', 'D6'],
        { note: 'PeriodType: Day or Month.' }),
      E('SERVICE_REQUEST', ['_RequestID', 'RequestType', 'Description', 'Status', 'SubmittedAt'], ['S23'],
        { note: 'RequestType: Meter check or Fault report. Status: Submitted, Assigned, Resolved, Cancelled. Status history goes to AUDIT_LOG.' })
    ],
    rels: [
      R('HOLDS', [['CONSUMER', '1', false], ['HOLDING', 'N', true]], ['S15', 'D5', 'L2'], { ident: true }),
      R('HOLDING_OF', [['PREMISE', '1', false], ['HOLDING', 'N', true]], ['S15', 'D5', 'L2'], { ident: true }),
      R('LOCATED_IN', [['PREMISE', 'N', true], ['PARISH', '1', false]], ['S16', 'D4']),
      R('PART_OF_MUNICIPALITY', [['PARISH', 'N', true], ['MUNICIPALITY', '1', false]], ['S16', 'D4']),
      R('PART_OF_DISTRICT', [['MUNICIPALITY', 'N', true], ['DISTRICT', '1', false]], ['S16', 'D4']),
      R('UNDER_SCHEME', [['PREMISE', 'N', true], ['SUPPLY_SCHEME', '1', false]], ['S18', 'S60']),
      R('SETS', [['CONSUMER', '1', false], ['CONSUMPTION_THRESHOLD', 'N', true]], ['S20']),
      R('THRESHOLD_FOR', [['CONSUMPTION_THRESHOLD', 'N', true], ['PREMISE', '1', false]], ['S20', 'D6']),
      R('SUBMITS', [['CONSUMER', '1', false], ['SERVICE_REQUEST', 'N', true]], ['S23']),
      R('REQUEST_PREMISE', [['SERVICE_REQUEST', 'N', true], ['PREMISE', '1', false]], ['S23']),
      R('REQUEST_METER', [['SERVICE_REQUEST', 'N', false], ['METER', '1', false]], ['S23'],
        { note: 'Optional: the spec says premise/meter, so the request may or may not name the meter.' })
    ]
  },
  {
    id: 'billing', title: 'Billing and payments',
    lead: 'Invoices link the consumer, the supplier (through the supply contract) and any MDMS-Cy service fee (through the service purchases charged in them). Paid access to past months is a purchase of the Historical data access service type.',
    leadSrc: ['S17', 'S21', 'S24', 'D23'],
    entities: [
      E('BANK_ACCOUNT', ['_BankAccountID', '!IBAN', 'HolderName'], ['S17']),
      E('INVOICE', ['_InvoiceID', 'IssueDate', 'PeriodFrom', 'PeriodTo', 'Amount', 'Status'], ['S24'],
        { note: 'Status: Issued, Partially paid, Paid, Cancelled. Amount is the total fixed at issue.' }),
      E('PAYMENT', ['_PaymentID', 'Amount', 'PaidAt', 'Reference'], ['S24']),
      E('SERVICE_TYPE', ['_ServiceTypeID', '!Name', 'Fee'], ['S12', 'S21'],
        { note: 'Defined by a System Operator. Example row: Historical data access.' }),
      E('SERVICE_PURCHASE', ['_PurchaseID', 'MonthFrom', 'MonthTo', 'PurchasedAt', 'Amount'], ['S21', 'S66', 'S28', 'S2'],
        { note: 'One purchase of a SERVICE_TYPE for one premise. For Historical data access, MonthFrom and MonthTo give the unlocked months, which must still be inside the consumer\'s retention period; other service types leave them empty. Amount keeps the price paid, since the service fee can change later.' })
    ],
    rels: [
      R('OWNS_ACCOUNT', [['CONSUMER', '1', false], ['BANK_ACCOUNT', 'N', false]], ['S17', 'D22']),
      R('ACCOUNT_FOR', [['BANK_ACCOUNT', 'M', false], ['PREMISE', 'N', false]], ['S17', 'D22'],
        { note: 'M:N: one account can pay for several premises. Both links are optional because the spec says consumer and/or premise; at least one must exist, which Phase B enforces in the insert procedure and with a trigger, since a CHECK cannot read another table.' }),
      R('ISSUED_TO', [['INVOICE', 'N', true], ['CONSUMER', '1', false]], ['S24']),
      R('BILLED_UNDER', [['INVOICE', 'N', false], ['SUPPLY_CONTRACT', '1', false]], ['S24', 'D23'],
        { note: 'A supplier invoice points to its contract, which gives the supplier and the premise. Partial: an invoice for an MDMS-Cy fee has no contract and is reached through CHARGED_IN instead.' }),
      R('SETTLES', [['PAYMENT', 'N', true], ['INVOICE', '1', false]], ['S24']),
      R('PAID_FROM', [['PAYMENT', 'N', false], ['BANK_ACCOUNT', '1', false]], ['S17', 'S24']),
      R('BUYS', [['CONSUMER', '1', false], ['SERVICE_PURCHASE', 'N', true]], ['S21']),
      R('PURCHASE_OF', [['SERVICE_PURCHASE', 'N', true], ['SERVICE_TYPE', '1', false]], ['S21']),
      R('PURCHASE_FOR', [['SERVICE_PURCHASE', 'N', true], ['PREMISE', '1', false]], ['S21']),
      R('CHARGED_IN', [['SERVICE_PURCHASE', 'N', true], ['INVOICE', '1', false]], ['S21', 'S24'])
    ]
  },
  {
    id: 'field', title: 'Field technicians and tasks',
    lead: 'Technicians join categories, declare daily availability and upload documents. Every job is a FIELD_TASK with notes, evidence and people to notify.',
    leadSrc: ['S31', 'S32', 'S34', 'S35', 'S41'],
    entities: [
      E('TECHNICIAN_CATEGORY', ['_CategoryID', '!Name'], ['S31']),
      E('AVAILABILITY', ['~Slot(AvailDate,FromTime)', 'ToTime'], ['S31', 'D7', 'L2', 'L11'], { weak: true,
        note: 'Weak entity owned by FIELD_TECHNICIAN. Its partial key is the composite attribute Slot (AvailDate, FromTime), so Key = (UserID, AvailDate, FromTime).' }),
      E('DOCUMENT', ['_DocumentID', 'DocType', 'DocNumber', 'IssueDate', 'ExpiryDate', 'FilePath', 'ReviewStatus', 'ReviewComment', 'ReviewedAt'], ['S32', 'S37', 'S12', 'D8', 'D31'],
        { note: 'DocType: ID card, Installer licence, Training certificate (technician); Calibration certificate, CE and protocol declaration, Encryption certificate (meter). ExpiryDate may be empty. ReviewStatus: Pending, Accepted, Rejected.' }),
      E('ATTACHMENT', ['_AttachmentID', 'FilePath', 'Caption', 'UploadedAt'], ['S35', 'S37', 'D8'],
        { note: 'Installation photos and other task evidence. Every attachment belongs to one task; an installation\'s photos are the EVIDENCE of the task it was DONE_IN.' }),
      E('FIELD_TASK', ['_TaskID', 'TaskType', 'ScheduledFrom', 'ScheduledTo', 'Status', 'Result', 'CreatedAt', 'CompletedAt'], ['S34', 'S35', 'S41', 'D9'],
        { note: 'TaskType: Installation, Replacement, Technical check, Anti-tamper check. Status: Assigned, Accepted, Done, Cancelled. CompletedAt is the date the check or job was actually carried out.' }),
      E('TASK_NOTE', ['~NoteNo', 'NoteKind', 'Text', 'WrittenAt'], ['S35', 'S41', 'L2'], { weak: true,
        note: 'Weak entity owned by FIELD_TASK. NoteKind: Observation or Finding.' })
    ],
    rels: [
      R('IN_CATEGORY', [['FIELD_TECHNICIAN', 'M', true], ['TECHNICIAN_CATEGORY', 'N', false]], ['S31'],
        { note: 'Total on the technician side: at least one category.' }),
      R('DECLARES', [['FIELD_TECHNICIAN', '1', true], ['AVAILABILITY', 'N', true]], ['S31', 'L2'], { ident: true }),
      R('AVAILABLE_IN', [['AVAILABILITY', 'M', true], ['MUNICIPALITY', 'N', false]], ['S31', 'D7'],
        { note: 'M:N: one time slot can cover several municipalities.' }),
      R('TECH_DOC', [['FIELD_TECHNICIAN', '1', true], ['DOCUMENT', 'N', false]], ['S32', 'D8'],
        { fk: 'TechnicianID', note: 'Total on the technician side: at least one document. That there is one of each required type (ID card, Installer licence, Training certificate) cannot be drawn in ER; Phase B checks it before APPROVES can set Approved.' }),
      R('METER_DOC', [['METER', '1', true], ['DOCUMENT', 'N', false]], ['S37', 'D8'],
        { note: 'Total on the meter side: at least one document. One of each equipment type (Calibration certificate, CE and protocol declaration, Encryption certificate) is checked in Phase B before CONFIRMS.' }),
      R('REVIEWS', [['SYSTEM_OPERATOR', '1', false], ['DOCUMENT', 'N', false]], ['S11', 'S12', 'S38', 'D31'],
        { fk: 'ReviewedBy', note: 'ReviewStatus, ReviewComment and ReviewedAt on DOCUMENT hold the result.' }),
      R('ASSIGNED_TO', [['FIELD_TASK', 'N', true], ['FIELD_TECHNICIAN', '1', false]], ['S34', 'S35', 'S41'],
        { fk: 'TechnicianID', note: 'Total on the task side: the spec links every task to the technician who takes it on. That technician is the responsible technician of the check; who created or assigned the task is in AUDIT_LOG.' }),
      R('TASK_AT', [['FIELD_TASK', 'N', false], ['PREMISE', '1', false]], ['S34', 'D9']),
      R('TASK_ON', [['FIELD_TASK', 'N', false], ['METER', '1', false]], ['S34', 'D9']),
      R('HAS_NOTE', [['FIELD_TASK', '1', false], ['TASK_NOTE', 'N', true]], ['S35', 'L2'], { ident: true }),
      R('WROTE', [['USER_ACCOUNT', '1', false], ['TASK_NOTE', 'N', true]], ['S35', 'S41'],
        { fk: 'WrittenBy', note: 'The author of the note. A user account, not only a technician, so that an operator can add notes too.' }),
      R('EVIDENCE', [['FIELD_TASK', '1', false], ['ATTACHMENT', 'N', true]], ['S35', 'S37', 'D26'],
        { note: 'Total on the attachment side: every photo or file belongs to a task, including installation photos.' }),
      R('NOTIFIES', [['FIELD_TASK', 'M', false], ['USER_ACCOUNT', 'N', false]], ['S41']),
      R('RESOLVED_BY', [['SERVICE_REQUEST', '1', false], ['FIELD_TASK', 'N', false]], ['S23']),
      R('LEADS_TO', [['EVENT', 'M', false], ['FIELD_TASK', 'N', false]], ['S41'],
        { note: 'M:N: several events (for example repeated tamper alarms) can lead to one task.' })
    ]
  },
  {
    id: 'meters', title: 'Meters, installations and commands',
    lead: 'A meter is linked to premises through dated installations, so a replacement never breaks the premise history. Remote commands keep every attempt until the ACK.',
    leadSrc: ['S36', 'S38', 'S39', 'S40'],
    entities: [
      E('METER_MODEL', ['_ModelID', 'Manufacturer', 'ModelName', 'MeterType'], ['S12', 'S36', 'S60'],
        { note: 'Defined by a System Operator. MeterType: Single-Phase or Three-Phase. A new meter type is a new row.' }),
      E('COMM_TYPE', ['_CommTypeID', '!Name'], ['S42', 'S60'],
        { note: 'Rows: Cellular, NB-IoT, PLC. A new telemetry protocol is a new row.' }),
      E('METER', ['_MeterID', '!SerialNumber', '!NetworkID', 'Firmware', '{ConnectedPhase}', 'MaxLoadAmps', 'Latitude', 'Longitude', 'Status'], ['S36', 'S38', 'S42', 'S51', 'S64'],
        { note: 'NetworkID is the Meter_Network_ID that packets carry. ConnectedPhase: L1, L2, L3, the transformer phases the meter is wired to (one for a Single-Phase model, three for a Three-Phase model). Status: Pending confirmation, Active, Retired. Only Active meters are ingested; a disconnected or shed meter stays Active and keeps sending data. Status is Active only while the open installation is Confirmed (set in the same transaction as CONFIRMS), Pending confirmation while it is Pending or Rejected, and Retired when no installation is open.' }),
      E('METER_INSTALLATION', ['_InstallationID', 'InstalledAt', 'RemovedAt', 'ConfirmationStatus', 'ConfirmedAt', 'ConfirmComment'], ['S36', 'S38', 'S39', 'D10'],
        { note: 'RemovedAt is empty while the meter is in place. In a replacement, the old installation\'s RemovedAt equals the new installation\'s InstalledAt. ConfirmationStatus: Pending, Confirmed, Rejected.' }),
      E('REMOTE_COMMAND', ['_CommandID', 'CommandType', 'Parameters', 'RequestedAt', 'Status'], ['S40', 'S6'],
        { note: 'CommandType: Disconnect, Reconnect, Firmware upgrade, Load shed. Status: Awaiting approval, Sent, Acknowledged, Failed, Cancelled; Acknowledged if and only if the last attempt has Outcome ACK. A meter\'s supply state (connected or cut) is its latest acknowledged Disconnect, Reconnect or Load shed command.' }),
      E('COMMAND_ATTEMPT', ['~AttemptNo', 'AttemptAt', 'RespondedAt', 'Outcome'], ['S40', 'L2'], { weak: true,
        note: 'Weak entity owned by REMOTE_COMMAND. Outcome: Timeout, NAK, ACK, and empty while the attempt waits for an answer. RespondedAt is when the meter answered; no attempt follows an ACK.' }),
      E('LOAD_SHED_ORDER', ['_ShedOrderID', 'Reason', 'CreatedAt', 'Status'], ['S6', 'D11'],
        { note: 'Status: Issued, Completed, Partially failed. Completed if and only if every SHED_COMMAND command is Acknowledged.' })
    ],
    rels: [
      R('OF_MODEL', [['METER', 'N', true], ['METER_MODEL', '1', false]], ['S12', 'S36']),
      R('USES_COMM', [['METER', 'N', true], ['COMM_TYPE', '1', false]], ['S36', 'S42']),
      R('INSTALLED', [['METER', '1', true], ['METER_INSTALLATION', 'N', true]], ['S36', 'S39', 'D10', 'D26'],
        { note: 'Total on both sides: a meter is entered at its installation, so every meter has at least one.' }),
      R('INSTALLED_AT', [['METER_INSTALLATION', 'N', true], ['PREMISE', '1', false]], ['S36', 'S39']),
      R('CONFIRMS', [['SYSTEM_OPERATOR', '1', false], ['METER_INSTALLATION', 'N', false]], ['S11', 'S38'],
        { fk: 'ConfirmedBy', note: 'ConfirmationStatus, ConfirmedAt and ConfirmComment on METER_INSTALLATION hold the result.' }),
      R('DONE_IN', [['METER_INSTALLATION', '1', true], ['FIELD_TASK', '1', false]], ['S34', 'S36', 'D26'],
        { note: 'Total on the installation side: every installation is done in a field task, and the installer is that task\'s technician. 1:1: a task performs at most one installation.' }),
      R('TARGETS', [['REMOTE_COMMAND', 'N', true], ['METER', '1', false]], ['S40']),
      R('REQUESTED_BY', [['REMOTE_COMMAND', 'N', true], ['USER_ACCOUNT', '1', false]], ['S40'], { fk: 'RequestedBy' }),
      R('APPROVED_BY', [['REMOTE_COMMAND', 'N', false], ['SYSTEM_OPERATOR', '1', false]], ['S4', 'S11'],
        { fk: 'ApprovedBy', note: 'The ΛΣ is the spec\'s approval role. Partial: a command that needs no approval, such as one from a TSO order, has none.' }),
      R('TRIES', [['REMOTE_COMMAND', '1', false], ['COMMAND_ATTEMPT', 'N', true]], ['S40', 'L2'], { ident: true }),
      R('SHED_COMMAND', [['LOAD_SHED_ORDER', '1', true], ['REMOTE_COMMAND', 'N', false]], ['S6', 'D11']),
      R('SHEDS', [['LOAD_SHED_ORDER', 'N', true], ['TRANSFORMER', '1', false]], ['S6']),
      R('ORDERED_BY', [['LOAD_SHED_ORDER', 'N', true], ['TSO_OPERATOR', '1', false]], ['S6', 'D2'], { fk: 'OrderedBy' })
    ]
  },
  {
    id: 'telemetry', title: 'Telemetry and VEE',
    lead: 'One READING per meter, OBIS code and 15-minute slot. Every packet is recorded, matched or not, until the retention purge, and every correction keeps the old value.',
    leadSrc: ['S42', 'S43', 'S44', 'S48'],
    entities: [
      E('OBIS_CODE', ['_ObisCode', 'Description', 'Unit', 'Kind', 'Phase', 'MinValid', 'MaxValid'], ['S44', 'S45', 'S62'],
        { note: 'Kind: Cumulative register or Instantaneous. MinValid/MaxValid feed the range check. A new code is a new row.' }),
      E('TELEMETRY_PACKET', ['_PacketID', 'ReceivedNetworkID', 'TransmissionTimestamp', 'ReceivedAt', 'NetworkType', 'SignalDbm', 'RawPayload', 'IngestStatus', 'ErrorMessage'], ['S42', 'S43', 'S64'],
        { note: 'IngestStatus: Accepted, Partially accepted, Unknown meter, Meter not active, Malformed. ErrorMessage lists any OBIS pairs that were rejected (for example an unsupported code), so nothing is dropped silently.' }),
      E('READING', ['~IntervalStart', 'ReceivedValue', 'UsedValue', 'Status'], ['S42', 'S46', 'S47', 'S49', 'D12', 'C3', 'L2'], { weak: true,
        note: 'Weak entity with two owners. Key = (MeterID, ObisCode, IntervalStart). ReceivedValue is the value as sent and never changes. It is empty only when nothing was received for the slot (a gap); an estimate of a received but unusable value keeps it. UsedValue is what later functions use: the energy of the 15-minute slot for a Cumulative register, the measured value for an Instantaneous code. Status: Raw, Validated, Estimated, Edited, Suspect. The Origin of the latest READING_EDIT decides between Estimated (an automatic or manual estimate) and Edited (a manual edit). A reading is final once it has a FINALIZED_IN link.' }),
      E('READING_EDIT', ['~EditNo', 'OldValue', 'NewValue', 'Origin', 'EditedAt', 'Reason'], ['S48', 'S47', 'S75', 'L2'], { weak: true,
        note: 'Weak entity owned by READING. OldValue and NewValue are the UsedValue before and after. Origin: Automatic estimate, Manual estimate or Manual edit (Figure 3 names automatic and manual estimation). EDITED_BY is set if and only if the Origin is Manual estimate or Manual edit. APPLIED_RULE is required for an Automatic estimate, optional for a Manual estimate (the method used) and empty for a Manual edit. Both foreign keys sit in this table, so a row CHECK enforces this. When estimating a gap changes the next slot\'s UsedValue, that slot gets its own automatic edit before it is finalized.' }),
      E('VEE_RULE', ['_RuleID', 'RuleType', 'Parameters', 'IsActive'], ['S45', 'S47', 'S60', 'S67'],
        { note: 'RuleType: the validation checks Syntax, Unsupported code, Range, Spike, Gap, and the estimation methods Linear interpolation (previous and next reading) and Previous value. A new VEE method is a new row. A Range rule uses MinValid and MaxValid of each OBIS code it applies to; Parameters holds only whole-rule settings.' }),
      E('VEE_RUN', ['_RunID', 'PeriodFrom', 'PeriodTo', 'StartedAt', 'FinishedAt'], ['S49', 'D13'])
    ],
    rels: [
      R('SENT_BY', [['TELEMETRY_PACKET', 'N', false], ['METER', '1', false]], ['S42', 'S43'],
        { note: 'Partial on the packet side: a packet whose network ID matches no meter has none. A packet from a known meter that is not active keeps its meter and the status Meter not active.' }),
      R('MEASURED', [['METER', '1', false], ['READING', 'N', true]], ['S42', 'L2'], { ident: true }),
      R('READ_CODE', [['OBIS_CODE', '1', false], ['READING', 'N', true]], ['S42', 'S44', 'L2'], { ident: true }),
      R('FROM_PACKET', [['READING', 'N', false], ['TELEMETRY_PACKET', '1', false]], ['S42', 'S67'],
        { note: 'Partial: a reading estimated for a gap comes from no packet.' }),
      R('HAS_EDIT', [['READING', '1', false], ['READING_EDIT', 'N', true]], ['S48', 'L2'], { ident: true }),
      R('EDITED_BY', [['READING_EDIT', 'N', false], ['DSO_OPERATOR', '1', false]], ['S48', 'S73', 'S75'],
        { fk: 'EditedBy', note: 'The DSO user who estimated or edited the reading by hand. Partial: automatic estimates have no user.' }),
      R('APPLIED_RULE', [['READING_EDIT', 'N', false], ['VEE_RULE', '1', false]], ['S48', 'S13', 'S67'],
        { note: 'Partial: a manual edit has a user instead of a rule, and a manual estimate names its method only if one was used.' }),
      R('FINALIZED_IN', [['READING', 'N', false], ['VEE_RUN', '1', false]], ['S49', 'D13']),
      R('RULE_FOR', [['VEE_RULE', 'M', false], ['OBIS_CODE', 'N', false]], ['S45'],
        { note: 'M:N: one rule can cover several codes (for example the three voltages). Partial: a packet-level rule such as Syntax checks no particular code.' })
    ]
  },
  {
    id: 'grid', title: 'Grid topology and aggregates',
    lead: 'Every meter is served by one LV transformer. Each transformer serves one level-1 geofence, and geofences form a tree of any depth.',
    leadSrc: ['S51', 'S53', 'S54', 'S55'],
    entities: [
      E('TRANSFORMER', ['_TransformerID', 'Name', 'Latitude', 'Longitude'], ['S51', 'S54']),
      E('GEOFENCE', ['_GeofenceID', 'Name', 'Level', 'MinLat', 'MinLon', 'MaxLat', 'MaxLon'], ['S52', 'S53'],
        { note: 'Rectangle in WGS84 (MinLat, MinLon, MaxLat, MaxLon), which the spec allows for a simpler implementation. Level-1 rectangles do not overlap, and each child lies inside its parent.' }),
      E('METER_AGGREGATE', ['~Period(PeriodType,PeriodStart)', 'SumValue', 'ReadingCount', 'EstimatedCount'], ['S22', 'S27', 'S49', 'S62', 'L2', 'L11'], { weak: true,
        note: 'Weak, owners METER and OBIS_CODE, with the composite partial key Period (PeriodType, PeriodStart), so Key = (MeterID, ObisCode, PeriodType, PeriodStart). PeriodType: Day, Month, Year. Written once, when every reading of the period is final (D13), and never changed. One row per meter, Cumulative register code (1.8.0, 1.8.1, 1.8.2, 2.8.0, 3.8.0, 4.8.0) and period; SumValue is the sum of UsedValue. Instantaneous codes are not aggregated.' }),
      E('GEOFENCE_AGGREGATE', ['~Period(PeriodType,PeriodStart)', 'SumValue', 'MeterCount'], ['S29', 'S30', 'S56', 'D21', 'L2', 'L11'], { weak: true,
        note: 'Weak, owners GEOFENCE and OBIS_CODE, with the composite partial key Period (PeriodType, PeriodStart), so Key = (GeofenceID, ObisCode, PeriodType, PeriodStart). PeriodType: 15 min, Day, Month, Year. A row is written once, when every reading it covers is final (D13); Day, Month and Year rows are built from complete rows one level down. These are the transformer measurements, kept permanently.' }),
      E('GEOFENCE_CURRENT_STATE', ['RefInterval', 'SumValue', 'MeterCount', 'ComputedAt'], ['S55', 'S72', 'S68', 'C3', 'L2'], { weak: true,
        note: 'Weak, owners GEOFENCE and OBIS_CODE, with no partial key: one row per geofence and code (only 1.8.0 and 2.8.0, as III.4.2 sets), overwritten by each run. It is the intermediate table the spec asks for: the manually started run computes it from the latest final readings of the meters under each geofence and ignores missing ones (III.4.2). It is not copied into GEOFENCE_AGGREGATE, whose rows wait until every reading is final.' })
    ],
    rels: [
      R('SERVED_BY', [['METER', 'N', true], ['TRANSFORMER', '1', false]], ['S51', 'D25'],
        { note: 'Stored result of the geofence lookup on the meter\'s coordinates (D25). A Retired meter keeps its last transformer; load shedding targets only Active meters (D11).' }),
      R('SERVICE_AREA', [['TRANSFORMER', '1', true], ['GEOFENCE', '1', false]], ['S51', 'S54'],
        { note: 'Partial on the geofence side: only level-1 geofences have a transformer, and every level-1 geofence has one.' }),
      R('PARENT_OF', [['GEOFENCE', '1', false, 'parent'], ['GEOFENCE', 'N', false, 'child']], ['S53', 'S54', 'D14'],
        { fk: 'ParentGeofenceID', note: 'Recursive. The root has no parent and level-1 geofences have no children. A child\'s Level is its parent\'s Level minus 1, and every geofence of level 2 or higher has at least one child (Phase B triggers).' }),
      R('METER_AGG', [['METER', '1', false], ['METER_AGGREGATE', 'N', true]], ['S22', 'L2'], { ident: true }),
      R('METER_AGG_CODE', [['OBIS_CODE', '1', false], ['METER_AGGREGATE', 'N', true]], ['S22', 'L2'], { ident: true }),
      R('GEO_AGG', [['GEOFENCE', '1', false], ['GEOFENCE_AGGREGATE', 'N', true]], ['S30', 'S56', 'L2'], { ident: true }),
      R('GEO_AGG_CODE', [['OBIS_CODE', '1', false], ['GEOFENCE_AGGREGATE', 'N', true]], ['S30', 'L2'], { ident: true }),
      R('GEO_STATE', [['GEOFENCE', '1', false], ['GEOFENCE_CURRENT_STATE', 'N', true]], ['S55', 'L2'], { ident: true }),
      R('STATE_CODE', [['OBIS_CODE', '1', false], ['GEOFENCE_CURRENT_STATE', 'N', true]], ['S55', 'L2'], { ident: true })
    ]
  },
  {
    id: 'market', title: 'Suppliers and aggregators',
    lead: 'A supplier sees only premises it has a contract for; an aggregator sees only premises in its portfolios. Both get aggregates, never raw readings.',
    leadSrc: ['S7', 'S8', 'S57', 'S58'],
    entities: [
      E('SUPPLIER', ['_SupplierID', '!Name'], ['S7', 'S57', 'D30'],
        { note: 'An electricity supplier. Only suppliers have supply contracts (SUPPLIED_BY).' }),
      E('AGGREGATOR', ['_AggregatorID', '!Name'], ['S8', 'S57', 'D30'],
        { note: 'An aggregator. Only aggregators manage portfolios (MANAGES).' }),
      E('TARIFF_TYPE', ['_TariffTypeID', '!Name'], ['S12', 'D27'], { note: 'Defined by a System Operator.' }),
      E('SUPPLY_CONTRACT', ['_ContractID', 'StartDate', 'EndDate'], ['S7', 'S24', 'D16']),
      E('PORTFOLIO', ['_PortfolioID', 'Name'], ['S8', 'S57'])
    ],
    rels: [
      R('WORKS_FOR_SUPPLIER', [['MARKET_USER', 'N', false], ['SUPPLIER', '1', false]], ['S57', 'D3', 'D30'],
        { note: 'Partial on the user side, because a market user works for a supplier or for an aggregator. Each market user is in exactly one of WORKS_FOR_SUPPLIER and WORKS_FOR_AGGREGATOR; both foreign keys sit in MARKET_USER, so a row CHECK enforces this (D30).' }),
      R('WORKS_FOR_AGGREGATOR', [['MARKET_USER', 'N', false], ['AGGREGATOR', '1', false]], ['S57', 'D3', 'D30'],
        { note: 'Partial on the user side, the other half of the rule in WORKS_FOR_SUPPLIER: exactly one of the two is set.' }),
      R('CONTRACT_OF', [['SUPPLY_CONTRACT', 'N', true], ['CONSUMER', '1', false]], ['S7', 'D16']),
      R('CONTRACT_FOR', [['SUPPLY_CONTRACT', 'N', true], ['PREMISE', '1', false]], ['S7', 'D16']),
      R('SUPPLIED_BY', [['SUPPLY_CONTRACT', 'N', true], ['SUPPLIER', '1', false]], ['S7', 'D16', 'D30']),
      R('ON_TARIFF', [['SUPPLY_CONTRACT', 'N', false], ['TARIFF_TYPE', '1', false]], ['S12', 'D27']),
      R('MANAGES', [['AGGREGATOR', '1', false], ['PORTFOLIO', 'N', true]], ['S8', 'S57', 'D30']),
      R('INCLUDES', [['PORTFOLIO', 'M', false], ['PREMISE', 'N', false]], ['S8', 'S57', 'D28'], { attrs: ['StartDate', 'EndDate'] })
    ]
  },
  {
    id: 'trace', title: 'GDPR, audit log and events',
    lead: 'A GDPR request moves through four logged stages. AUDIT_LOG records every critical state change, and EVENT records what happened in the network.',
    leadSrc: ['S13', 'S25', 'S30', 'S41'],
    entities: [
      E('GDPR_REQUEST', ['_GdprRequestID', 'SubmittedAt', 'Status', 'PreApprovedAt', 'DecidedAt', 'AppliedAt'], ['S25', 'S26', 'S28', 'S30', 'D17', 'D29'],
        { note: 'Status: Submitted, Under review, Pre-approved, Approved, Rejected, Applied. PRE_APPROVES names the ΛΣ who pre-approved, and FINAL_APPROVES or FINAL_APPROVES_ADMIN the ΛΣ or ΔΣ who gave the final decision. AUDIT_LOG keeps the dated history. D29 says what applying the request deletes and keeps.' }),
      E('AUDIT_LOG', ['_LogID', 'ObjectType', 'ObjectID', 'Action', 'ActorMechanism', 'LoggedAt', 'OldState', 'NewState', 'ResultComment'], ['S13', 'S33', 'S4', 'D18'],
        { note: 'ActorMechanism names a job (e.g. the VEE run and rule) when no user acted. A VEE result is logged with ObjectType READING, ObjectID the reading key (MeterID, ObisCode, IntervalStart), the status change in OldState and NewState, and the reason in ResultComment.' }),
      E('EVENT', ['_EventID', 'EventType', 'Severity', 'Description', 'OccurredAt', 'Status'], ['S5', 'S19', 'S41', 'S43'],
        { note: 'EventType: Undervoltage, Overvoltage, Communication failure, Unmatched packet, Tamper, Suspected theft. Severity: Info, Warning, Critical. Status: Open, In progress, Closed. An Unmatched packet event points (EVENT_FROM) to a packet whose IngestStatus is Unknown meter or Meter not active, and is raised when follow-up is needed.' })
    ],
    rels: [
      R('REQUESTS_ERASURE', [['CONSUMER', '1', false], ['GDPR_REQUEST', 'N', true]], ['S25'], { fk: 'ConsumerID' }),
      R('PRE_APPROVES', [['SYSTEM_OPERATOR', '1', false], ['GDPR_REQUEST', 'N', false]], ['S25', 'S11', 'D17'],
        { fk: 'PreApprovedBy', note: 'The ΛΣ who examined the request and pre-approved or rejected it. Partial: a new request has not been examined yet.' }),
      R('FINAL_APPROVES', [['SYSTEM_OPERATOR', '1', false], ['GDPR_REQUEST', 'N', false]], ['S25', 'S30', 'S11', 'D17'],
        { fk: 'DecidedBy', note: 'The ΛΣ who gave the final decision; Status holds the outcome. Partial: only requests that reach the final stage have one, and a ΔΣ may decide instead (FINAL_APPROVES_ADMIN).' }),
      R('FINAL_APPROVES_ADMIN', [['SYSTEM_ADMIN', '1', false], ['GDPR_REQUEST', 'N', false]], ['S30', 'D17'],
        { fk: 'DecidedByAdmin', note: 'The ΔΣ who gave the final decision, since Figure 2 lets a ΛΣ or a ΔΣ decide. At most one of FINAL_APPROVES and FINAL_APPROVES_ADMIN is set; both foreign keys sit in GDPR_REQUEST, so a row CHECK enforces this.' }),
      R('PERFORMED_BY', [['AUDIT_LOG', 'N', false], ['USER_ACCOUNT', '1', false]], ['S13'],
        { fk: 'PerformedBy', note: 'Partial: automatic actions have no user.' }),
      R('EVENT_ON', [['EVENT', 'N', false], ['METER', '1', false]], ['S19', 'S41']),
      R('EVENT_FROM', [['EVENT', 'N', false], ['TELEMETRY_PACKET', '1', false]], ['S43']),
      R('FOUND_DURING', [['EVENT', 'N', false], ['FIELD_TASK', '1', false]], ['S41'])
    ]
  }
];

const decisions = [
  { id: 'D1', title: 'Roles are entities, not rows of a ROLE table', text: 'The spec names seven roles: ΔΣ, ΛΣ, ΚΧ, ΤΠ, DSO, TSO and market users. Each has its own attributes or its own relationships, so each is its own entity (D2). A ROLE table as well would store the same membership twice and need a rule to keep the two in step. The spec\'s examples of future extension are meter types, telemetry protocols, prosumer classes and VEE methods, not roles, and a new role later would be a new entity and a new table, which extends the schema without changing it. If the lab says the ΛΣ is the DSO (C5), SYSTEM_OPERATOR and DSO_OPERATOR become one entity.', src: ['S3', 'S11', 'S60', 'C5'] },
  { id: 'D2', title: 'Each role is a weak entity of USER_ACCOUNT', text: 'A role becomes its own entity when it has its own attributes or its own relationships: CONSUMER, FIELD_TECHNICIAN, MARKET_USER, SYSTEM_ADMIN (creates ΛΣ, may give the final GDPR approval), SYSTEM_OPERATOR (approvals), TSO_OPERATOR (load-shed orders) and DSO_OPERATOR (manual estimates and edits in VEE). Without EER (D32), each is a weak entity owned by USER_ACCOUNT through a 1:1 identifying relationship (IS_CONSUMER to IS_DSO) with no partial key, so its key is the UserID of the account; lecture 5 allows an identifying relationship to be 1:1. A role row exists only while the account holds that role, and one account can have several role rows, because one person can hold several roles. Every other relationship points to the role entity, so only a ΛΣ can approve (a ΔΣ may also give the final GDPR decision, D17), only a TSO can order shedding and only DSO staff can change readings by hand. That every account has at least one role cannot be drawn without EER; Phase B creates each account together with its first role in one procedure, and a trigger refuses to remove the last role of an account.', src: ['S11', 'S14', 'S31', 'S73', 'L2', 'D32'] },
  { id: 'D3', title: 'MARKET_USER for supplier and aggregator staff', text: 'The spec requires authenticated, permission-checked calls for suppliers and aggregators, so their staff need accounts tied to their company.', src: ['S57'] },
  { id: 'D4', title: 'Administrative areas as three entities', text: 'Parish belongs to municipality and municipality to district. Storing all three on PREMISE would create a transitive dependency, so they become a chain of N:1 relationships. Postal code stays an attribute because postal areas do not nest inside parishes.', src: ['S16'] },
  { id: 'D5', title: 'HOLDING records each holding period', text: 'The spec only demands that one consumer can have many premises. Each period in which a consumer holds a premise is its own HOLDING row, a weak entity owned by CONSUMER and PREMISE with key (UserID, PremiseID, StartDate). A premise can change hands, and a consumer who leaves and later returns gets a new row, so no period covers another holder\'s readings. The app limits each consumer to readings inside their own periods.', src: ['S15', 'L2'] },
  { id: 'D6', title: 'Thresholds are per premise', text: 'A consumer with two premises will want different limits, so each threshold points to one premise.', src: ['S20'] },
  { id: 'D7', title: 'Availability area is a municipality', text: 'The spec asks for daily time and geographic availability but does not fix the unit. Municipality is used; a geofence would also work. Each availability row is one date and time slot, and it can cover several municipalities.', src: ['S31'] },
  { id: 'D8', title: 'Documents have exactly one owner', text: 'DOCUMENT belongs either to a technician or to a meter. Phase B enforces this with a CHECK that exactly one of its two foreign keys is set. Attachments always belong to a task (EVIDENCE), including installation photos.', src: ['S32', 'S37', 'D26'] },
  { id: 'D9', title: 'A task names a premise, a meter, or both', text: 'The spec says premise and/or meter, so both links are optional and a CHECK requires at least one. An installation task starts before the meter is linked.', src: ['S34'] },
  { id: 'D10', title: 'METER_INSTALLATION keeps the history', text: 'Each installation has InstalledAt and RemovedAt. A replacement closes one row and opens another, so the premise history is the union of its installations, and readings stay with the meter that produced them.', src: ['S39'] },
  { id: 'D11', title: 'LOAD_SHED_ORDER groups the commands', text: 'One TSO shedding order for a transformer creates one Load shed command per Active meter SERVED_BY that transformer, each with its own attempts and ACK. A Retired meter keeps its last transformer but gets no command, since it could never send an ACK.', src: ['S6', 'S40'] },
  { id: 'D12', title: 'READING keeps the received value and the value in use', text: '1.8.0 is a cumulative counter, but the VEE examples reason in kWh per 15 minutes. ReceivedValue keeps what the meter sent and never changes. UsedValue is what spikes, gaps, aggregates and reports use: the slot\'s energy (the difference from the previous slot) for a Cumulative register, the measured value for an Instantaneous code. Estimation and editing change only UsedValue, and READING_EDIT records each change.', src: ['S63', 'S47', 'S48'] },
  { id: 'D13', title: 'VEE_RUN records each VEE execution', text: 'The end of a run is the moment readings become final and aggregation starts, so each final reading points to the run that finalized it. Readings that fail a run go back for correction and become final in a later run (Figure 3). So an aggregate row for a period is written once, after the run in which the last reading of that period becomes final: every slot of the period, within each meter\'s installation dates, has a final reading, received or estimated, for each meter that reports that code. Until then the period has no row, so an aggregate never needs recomputing and a Month always equals the sum of its Days.', src: ['S49', 'S50', 'S75', 'S44'] },
  { id: 'D14', title: 'The geofence hierarchy is a tree', text: 'The text allows arbitrary depth; Figure 4 shows each geofence under exactly one parent, so PARENT_OF is 1:N. Level must follow the tree: a child is one level below its parent, upper geofences have at least one child, and only level-1 geofences have a transformer.', src: ['S53', 'S54'] },
  { id: 'D15', title: 'Intraday sums are not stored', text: 'The spec asks that intraday data be computable straight from the latest readings, so it is a query over non-final READING rows, not an entity.', src: ['S59'] },
  { id: 'D16', title: 'SUPPLY_CONTRACT decides supplier access', text: 'The spec says consumers choose a supplier and suppliers see only their own customers. A dated contract between consumer, premise and SUPPLIER records exactly that.', src: ['S7', 'S57', 'D30'] },
  { id: 'D17', title: 'GDPR stages: who on the request, history in AUDIT_LOG', text: 'The ΛΣ who pre-approved and the ΛΣ or ΔΣ who gave the final decision are relationships (PRE_APPROVES, and FINAL_APPROVES or FINAL_APPROVES_ADMIN, since Figure 2 lets either role decide), like the other approvals in the model, and their times are attributes of GDPR_REQUEST. At most one final approver is set. AUDIT_LOG keeps the dated record of every stage with its user, so no separate step entity is needed.', src: ['S25', 'S13', 'S11'] },
  { id: 'D18', title: 'One generic AUDIT_LOG', text: 'ObjectType + ObjectID cannot be a foreign key. The gain is that any new object type can be logged without a new table. The alternative is one log table per area.', src: ['S13', 'S60'] },
  { id: 'D19', title: 'Retention follows the holder at the time of the reading', text: 'RawRetentionMonths (36 or 1) sits on CONSUMER. A raw READING of meter m at time t belongs to the consumers whose HOLDING covers t at the premise where m was installed at t (METER_INSTALLATION). It is purged after the shortest RawRetentionMonths among them, or after 36 months if the premise had no holder. The TELEMETRY_PACKET rows of that meter for the same window are purged too, and packets with no meter after 36 months. Aggregates are never purged. The spec\'s wording "the meter of the consumer" would also allow a per-meter setting (C4).', src: ['S27', 'S28', 'S66', 'S70'] },
  { id: 'D20', title: 'Notifications are not an entity', text: 'The spec says the system may inform consumers. For network events, EVENT_ON gives the meter, which leads to the premise and its holders. For thresholds, SETS and THRESHOLD_FOR give the consumer and the premise, which are compared with readings or aggregates as they are built. NotificationChannel says how. Alerts are sent, not stored.', src: ['S19', 'S20'] },
  { id: 'D21', title: 'Transformer measurements are geofence aggregates', text: 'The spec never gives transformers their own meters. Figure 2 shows transformer data as per-geofence 15-minute aggregates kept permanently, which GEOFENCE_AGGREGATE stores. Technical losses therefore cannot be computed (C7).', src: ['S29', 'S30', 'C7'] },
  { id: 'D22', title: 'Bank accounts follow "consumer and/or premise"', text: 'An account can belong to a consumer, be tied to premises, or both, so both links are optional. At least one must exist; Phase B enforces this in the insert procedure and with a trigger, because a CHECK cannot read the ACCOUNT_FOR table. ACCOUNT_FOR is M:N because one account often pays for several premises.', src: ['S17'] },
  { id: 'D23', title: 'An invoice points to a contract or to purchases', text: 'A supplier invoice belongs to a SUPPLY_CONTRACT, which already gives the supplier and the premise. An MDMS-Cy fee invoice charges SERVICE_PURCHASE rows (CHARGED_IN), whose service type gives the fee. At least one of the two must exist; Phase B enforces this in the insert procedure and with a trigger, because CHARGED_IN is a foreign key in SERVICE_PURCHASE, which a CHECK on INVOICE cannot read. There is no separate fee link that could disagree.', src: ['S24', 'S21', 'D16'] },
  { id: 'D24', title: 'Paths that must agree', text: 'Some facts can be reached two ways and Phase B must keep them consistent. A consumer may only set thresholds, file requests, buy services, link accounts or sign contracts for premises they hold (HOLDING) in that period. An invoice\'s consumer equals its contract\'s consumer and the buyer of its purchases, and a PAID_FROM account belongs to that consumer or pays for that premise. A READING from a packet has that packet\'s SENT_BY meter as its MEASURED meter, and an EVENT with EVENT_FROM has that meter as EVENT_ON. When a task or request names both a premise and a meter, the meter is installed there at that date (except the task\'s own new installation), and an installation is INSTALLED_AT the TASK_AT premise of its DONE_IN task. A task RESOLVED_BY a request is at that request\'s premise. Every SHED_COMMAND command is a Load shed that TARGETS a meter that was Active and SERVED_BY the order\'s transformer when the order was created. METER.Status agrees with the open installation, and REMOTE_COMMAND.Status with its attempts.', src: ['S15', 'S24', 'S42', 'S6'] },
  { id: 'D25', title: 'SERVED_BY is stored, not computed', text: 'The spec finds a meter\'s transformer from its coordinates and the geofence that contains them. The result is stored in SERVED_BY so that load shedding and aggregation do not repeat the lookup; it must match the transformer of the level-1 geofence that contains the meter. Level-1 rectangles do not overlap and every meter lies inside exactly one, so the lookup gives one transformer.', src: ['S51', 'S52'] },
  { id: 'D26', title: 'Installations are field tasks', text: 'Installation and replacement are field tasks, and the meter\'s data is entered at installation. So every meter has an installation, every installation is done in exactly one task (DONE_IN, 1:1), and the installer is the task\'s technician. For these tasks the new meter comes from DONE_IN and TASK_AT is required; TASK_ON names only a meter that is checked or removed (empty for an Installation, the old meter for a Replacement). In a Replacement the old installation\'s RemovedAt, the new InstalledAt and the task\'s CompletedAt are the same.', src: ['S34', 'S36', 'S39'] },
  { id: 'D27', title: 'Tariff types attach to supply contracts', text: '"τύπους υπηρεσιών και τιμολογίων" is read as service types and tariff types, since invoices are records rather than types. The tariff is chosen per supply contract.', src: ['S12', 'D16'] },
  { id: 'D28', title: 'Portfolios hold premises', text: 'Aggregates are computed from meters, which are installed at premises, so a portfolio lists premises with dates. INCLUDES keeps one row per portfolio and premise: a premise that leaves and later re-joins gets new dates, and only its latest membership is kept. If the lab wants the full membership history, INCLUDES can become a weak entity like HOLDING (D5).', src: ['S8', 'S57', 'D5'] },
  { id: 'D29', title: 'What applying a GDPR request does', text: 'It sets CONSUMER.RawRetentionMonths to 1, and the purge of D19 then deletes the raw readings older than one month (with their READING_EDIT rows) and the matching packets for the consumer\'s holding periods. It keeps the account and its login (the consumer is still a user), invoices, payments and the bank accounts they use, contracts, service purchases, aggregates and AUDIT_LOG, because these are needed for accounting or legal reasons. Whether the name and contact details of a consumer who has left should also be anonymized is asked in C6.', src: ['S25', 'S26', 'S28', 'S66'] },
  { id: 'D30', title: 'Suppliers and aggregators are two entities', text: 'Suppliers have customers through contracts and aggregators have portfolios ("τους πελάτες ή τα χαρτοφυλάκια που εκπροσωπούν"), so each gets its own relationship, by the same rule as D2. Without EER (D32) they are two separate entities, the way lecture 6 writes subclasses in plain ER (slide 6-39), instead of subclasses of one participant entity. A company that acts as both is registered once in each. A market user works for exactly one of them (WORKS_FOR_SUPPLIER or WORKS_FOR_AGGREGATOR); both foreign keys sit in MARKET_USER, so a row CHECK enforces it, as in D8.', src: ['S57', 'D2', 'D32', 'L15'] },
  { id: 'D31', title: 'Only M:N relationships carry attributes', text: 'On a 1:N relationship an attribute moves to the N side (lecture 5, slide 5-16), so the decision times are ApprovalDecidedAt on FIELD_TECHNICIAN, ReviewedAt on DOCUMENT, and PreApprovedAt and DecidedAt on GDPR_REQUEST. Only the M:N INCLUDES keeps attributes. ERD+ also copies relationship attributes into tables only for M:N relationships.', src: ['L12'] },
  { id: 'D32', title: 'Plain Chen ER, without EER', text: 'Phase A asks for "Εννοιολογική Σχεδίαση με Χρήση του Διαγράμματος Chen ER" and a "Διάγραμμα Οντοτήτων Συσχετίσεων (ER)", and never mentions EER. Assignment 1 asked explicitly for "ER – όχι EER", and lecture 6 teaches EER as an extension of ER. So the model uses only plain ER shapes. Lecture 6 (slide 6-39) says any EER can be written in ER with some loss of meaning, which the database program must then handle. Here the roles become weak entities of USER_ACCOUNT (D2) and SUPPLIER and AGGREGATOR become two entities (D30). For the roles, the tables are exactly those of the textbook mapping of a specialization: one table per role, keyed by UserID. For suppliers and aggregators they are the mapping that keeps only the subclass tables, which the textbook allows for a disjoint, total specialization. The one rule that no longer shows in the diagram, at least one role per account, is enforced in Phase B (D2).', src: ['S76', 'S61', 'L14', 'L3', 'L9', 'L15', 'L16'] },
];

const changes = [
  { text: 'Removed transformer meters (MeterClass, installations on transformers). The spec never says transformers have meters; their data is the per-geofence aggregate in Figure 2.', src: ['S29', 'S30', 'D21'] },
  { text: 'Fixed SERVICE_AREA participation. The draft had total participation on both sides, but only level-1 geofences have a transformer.', src: ['S51', 'S54'] },
  { text: 'Merged the two invented GDPR request types into one. The spec has one right-to-be-forgotten flow whose approval both erases personal data and cuts raw retention to 1 month.', src: ['S25', 'S26', 'S28', 'S30'] },
  { text: 'Marked the conflict between "never deleted after VEE" (Figure 3) and the 3-year and 1-month deletion rule. The draft presented its own resolution as if the spec said it.', src: ['S27', 'S50', 'C2'] },
  { text: 'FIELD_TASK now links to a premise and/or a meter, both optional. The draft made the premise mandatory.', src: ['S34', 'D9'] },
  { text: 'READING is a weak entity identified by METER and OBIS_CODE plus the slot, matching the lecture rules for weak entities.', src: ['L2'] },
  { text: 'Removed entities the spec does not need: API_CALL_LOG, NOTIFICATION, PROVISIONAL_AGGREGATE, VEE_FINDING, GDPR_REQUEST_STEP, RETENTION_POLICY, and the TASK_TYPE, COMMAND_TYPE, EVENT_TYPE and DOCUMENT_TYPE lookups. 59 entities became 48.', src: ['D15', 'D17', 'D19', 'D20'] },
  { text: 'Kept lookup entities only where the spec requires extension without structural change (meter types, protocols, prosumer classes, OBIS codes, VEE methods) or where a System Operator defines the values.', src: ['S2', 'S60', 'S12'] },
  { text: 'Removed invented attributes such as transformer capacity, correspondence address and last login time.', src: [] },
  { text: 'Labelled every choice the spec does not make as a design decision (D), so it is clear what comes from the spec and what is ours.', src: [] }
];

const recheck = [
  { text: 'INSTALLED is now total on METER. The model said "a meter in stock has no installation" while SERVED_BY and METER_DOC required every meter to be in the network; the spec enters a meter at its installation.', src: ['S36', 'S51', 'D26'] },
  { text: 'Dropped INSTALLED_BY and made DONE_IN total: every installation is a field task, so the installer is the task\'s technician.', src: ['S34', 'D26'] },
  { text: 'ASSIGNED_TO is total on FIELD_TASK, because every task is linked to the technician who takes it on. FIELD_TASK gained CompletedAt, the actual date of the check.', src: ['S34', 'S41'] },
  { text: 'Dropped FEE_FOR and replaced ISSUED_BY with BILLED_UNDER (invoice to supply contract). The fee was reachable two ways, and an invoice could point at an aggregator.', src: ['S24', 'D23'] },
  { text: 'ACCOUNT_FOR is M:N and OWNS_ACCOUNT is optional on the account side, matching "consumer and/or premise".', src: ['S17', 'D22'] },
  { text: 'DATA_ACCESS_PURCHASE keeps the Amount paid.', src: ['S66'] },
  { text: 'AVAILABLE_IN, LEADS_TO and RULE_FOR are now M:N.', src: ['S31', 'S41', 'S45'] },
  { text: 'New APPLIED_RULE: an automatic correction records which VEE rule made it, so every change has an origin.', src: ['S48', 'S13'] },
  { text: 'Removed IsFinal and FinalizedAt from READING (derived from FINALIZED_IN). Packets can be "Partially accepted" so rejected OBIS pairs are not lost silently.', src: ['S45', 'D13'] },
  { text: 'New decisions D22 to D28 cover choices that were implicit, and four citations now point at better quotes.', src: [] }
];

const third = [
  { text: 'The roles with their own relationships are now subclasses: SYSTEM_ADMIN creates SYSTEM_OPERATOR (CREATES is no longer recursive), every approval points to SYSTEM_OPERATOR, and ORDERED_BY points to TSO_OPERATOR. D2 stated this rule but did not follow it.', src: ['S11', 'D2'] },
  { text: 'SUPPLIER and AGGREGATOR are subclasses of MARKET_PARTICIPANT, defined by ParticipantType, so only a supplier can have contracts and only an aggregator portfolios.', src: ['S57', 'D30'] },
  { text: 'HOLDS became the weak entity HOLDING, so each holding period is its own row and a returning consumer cannot see another holder\'s readings.', src: ['S15', 'D5'] },
  { text: 'Two-part partial keys are now one composite attribute: Slot (AvailDate, FromTime) and Period (PeriodType, PeriodStart). Two separate dashed underlines would mean two separate keys.', src: ['L11'] },
  { text: 'READING has ReceivedValue and UsedValue instead of Value and IntervalValue, so it is clear which value edits change and which value later functions use.', src: ['S47', 'D12'] },
  { text: 'METER.Status lost Disconnected: a cut supply does not stop ingestion, and the supply state comes from the acknowledged commands. REMOTE_COMMAND.AckAt was dropped because the attempts already record the ACK.', src: ['S38', 'S40'] },
  { text: 'DONE_IN is 1:1 and INSTALL_PHOTO was dropped: installation photos are the evidence of the installation task. TASK_ON is defined for installations and replacements (D26).', src: ['S37', 'D26'] },
  { text: 'Approval times moved from 1:N relationships to the N side, the ΛΣ of each GDPR stage is now a relationship, and ConnectedPhase is multivalued.', src: ['L12', 'D17', 'D31'] },
  { text: 'DATA_ACCESS_PURCHASE became SERVICE_PURCHASE, so any service type can be charged. The meter aggregates now cover all six energy registers.', src: ['S2', 'S62'] },
  { text: 'Retention now follows the holder at the time of each reading and also purges the packets. New decisions D29 to D31, new conflicts C5 to C7, and CHECK rules that would need another table are now trigger rules.', src: ['D19', 'D29', 'C5'] },
  { text: 'DSO staff are a subclass, DSO_OPERATOR, and EDITED_BY points to it, because VEE is a DSO function. ROLE and HAS_ROLE were dropped: every role is already a subclass, so the table stored each role twice. The specialization of USER_ACCOUNT is now total.', src: ['S73', 'S74', 'D1', 'D2'] },
  { text: 'A ΔΣ can give the final approval of a GDPR request (FINAL_APPROVES_ADMIN), since Figure 2 names "ΛΣ/ΔΣ" for that stage.', src: ['S30', 'D17'] },
  { text: 'An aggregate row is written once, when every reading of its period is final, so a reading that becomes final in a later VEE run is not left out. The current-state table is computed from the latest final readings, ignoring missing ones, instead of copying a 15-minute aggregate.', src: ['S49', 'S72', 'S75', 'D13'] },
  { text: 'Manual estimate is a third Origin of READING_EDIT, as Figure 3 names manual estimation. A received value that is estimated keeps its ReceivedValue. Load shedding targets only Active meters, since a Retired meter could never send an ACK.', src: ['S75', 'S6', 'D11'] },
  { text: 'The ERD+ guide lists the foreign-key columns to rename after the conversion, so that no table ends up with two UserID columns.', src: ['L9'] }
];

const fourth = [
  { text: 'The model is now plain Chen ER, without EER, because the spec asks for a Chen ER diagram and Assignment 1 asked for ER, not EER. Lecture 6 shows how to write EER in plain ER.', src: ['S76', 'L14', 'L15', 'D32'] },
  { text: 'The seven roles are weak entities of USER_ACCOUNT, each with a 1:1 identifying relationship (IS_CONSUMER, IS_TECHNICIAN, IS_MARKET_USER, IS_ADMIN, IS_OPERATOR, IS_TSO, IS_DSO). Their key is the UserID of the account, so the tables are the same as with the specialization, and every relationship still points to the role it needs.', src: ['L2', 'D2'] },
  { text: 'MARKET_PARTICIPANT and its ParticipantType, which defined the specialization, were dropped. SUPPLIER and AGGREGATOR are two entities with their own key and a unique Name, and WORKS_FOR became WORKS_FOR_SUPPLIER and WORKS_FOR_AGGREGATOR, exactly one of which a market user has.', src: ['S57', 'L13', 'D30'] },
  { text: 'The rule "every account has at least one role", which only the EER double line showed, is now a Phase B rule.', src: ['D2', 'L15'] },
  { text: 'For the schema of step 3, the notes now list the values of SERVICE_REQUEST.Status, DOCUMENT.ReviewStatus, METER_INSTALLATION.ConfirmationStatus and EVENT.Severity and Status, and COMMAND_ATTEMPT.Outcome may be empty while an attempt waits. Six more foreign keys get readable names (ConfirmedBy, OrderedBy, EditedBy, TechnicianID, WrittenBy, PerformedBy).', src: ['S77', 'L9'] }
];

const conflicts = [
  { id: 'C1', title: 'Phase A deadline', text: 'The cover says "Friday 19/10/26", but 19 October 2026 is a Monday. Check the date on Moodle.', src: ['S1'] },
  { id: 'C2', title: 'Can final readings be deleted?', text: 'Figure 3 says readings are neither modified nor deleted after VEE, and III.4.2 says final readings and historical aggregates are kept permanently as immutable data. Yet III.1.4 deletes raw readings after 3 years, or 1 month after an approved request. Our reading: immutable means value and status never change; the retention purge is the only delete allowed, and it also removes the matching packets (D19).', src: ['S49', 'S50', 'S68', 'S27', 'S28', 'D19'] },
  { id: 'C3', title: 'Summing cumulative registers', text: 'III.4.2 sums 1.8.0 and 2.8.0, which are counters since installation. A sum of counters is a valid "total so far", but per-slot energy needs differences. READING keeps both the received counter and the per-slot UsedValue (D12); ask the lab which one they expect.', src: ['S55', 'S63', 'D12'] },
  { id: 'C4', title: 'Retention per consumer or per meter', text: 'The spec says "the meter of the consumer", but also that the period follows the preferences the user has set. We keep one setting per consumer and apply it by holding period (D19). Switching to a per-meter attribute is a small change if the lab prefers it. If a premise had several holders at the same time, the shorter period wins.', src: ['S28', 'S70', 'D19'] },
  { id: 'C5', title: 'Who is the Λειτουργός Συστήματος?', text: 'Figure 1 labels the DSO actor "Λειτουργός Συστήματος (DSO)", but section III makes the ΛΣ a separate approval role created by a ΔΣ. We keep SYSTEM_OPERATOR and DSO_OPERATOR as separate role entities. One account can hold both roles, so DSO staff can also be ΛΣ, and either answer fits; if the lab says they are one role, the two entities merge.', src: ['S71', 'S11', 'D1', 'D2'] },
  { id: 'C6', title: 'What does the right to be forgotten erase?', text: 'The spec erases "the personal data that may be deleted" but keeps what accounting needs, and it also says the request cuts raw retention to 1 month, which implies the consumer stays a user. We keep the account and its contact details (D29). Ask whether the name and contact details of a consumer who has left should also be anonymized.', src: ['S26', 'S28', 'D29'] },
  { id: 'C7', title: 'Transformer measurements and technical losses', text: 'The DSO must compute technical losses, but the spec never gives transformers their own meters, so we store transformer data as geofence aggregates (D21). Losses (energy fed in minus energy metered) then cannot be computed. Ask whether transformers or grid equipment send their own measurements. If they do, a weak TRANSFORMER_READING owned by TRANSFORMER and OBIS_CODE can be added without changing the existing structure.', src: ['S5', 'S29', 'S60', 'D21'] }
];

const assumptions = [
  { text: 'One person has one account and may hold several roles; every account has at least one.', src: ['S9', 'D1', 'D2'] },
  { text: 'A premise can change consumers over time; each holding period is its own row with start and end dates.', src: ['S15', 'D5'] },
  { text: 'Readings belong to the meter. A premise\'s history is the union of the meters installed there.', src: ['S39', 'D10'] },
  { text: 'Every meter is served by exactly one LV transformer, and each level-1 geofence covers exactly one transformer. Geofences are rectangles that form a tree, and level-1 rectangles do not overlap.', src: ['S51', 'S52', 'S54', 'D14', 'D25'] },
  { text: 'Packet timestamps are placed in their 15-minute slot. A reading keeps the value received and the per-slot value that later functions use.', src: ['S42', 'D12'] },
  { text: 'After VEE, a reading\'s value and status never change. The only deletion allowed is the retention purge of consumer readings and their packets (36 months, or 1 month after an approved GDPR request). Transformer data, i.e. geofence aggregates, is never deleted.', src: ['S49', 'S68', 'S27', 'S28', 'S29', 'C2', 'D19'] },
  { text: 'An approved GDPR request cuts raw retention to 1 month; the account, invoices, payments and aggregates are kept.', src: ['S26', 'D29'] },
  { text: 'Suppliers see only premises with a supply contract, aggregators only premises in their portfolios, and both only as aggregates.', src: ['S57', 'D16'] },
  { text: 'Dynamic pricing, forecasting, technical losses and real email or SMS delivery are outside the database scope.', src: ['S24', 'S69', 'D20', 'C7'] },
  { text: 'In the ERD+ drawing every underlined attribute other than the entity\'s ID is an alternative key, because ERD+ has no overline.', src: ['L4', 'L8'] }
];

module.exports = { areas, decisions, changes, recheck, third, fourth, conflicts, assumptions };
