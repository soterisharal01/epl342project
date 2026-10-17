// Constraint tests for create.sql: each test runs in its own transaction, which is rolled back.
// expect 'OK' = must succeed; otherwise the name of the constraint that must stop it.
// node tests.js writes test.sql; the results of running it are read back by build-schema.js.
const fs = require('fs');

// committed sample rows that every test starts from (they also test that valid data goes in)
const setup = `
INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, Phone, FirstName, LastName) VALUES
 ('admin1', '$2y$10$hash', 'admin@mdms.cy', '+357 22000000', N'Άννα', N'Διαχειρίστρια'),
 ('op1', '$2y$10$hash', 'op1@mdms.cy', NULL, N'Πέτρος', N'Λειτουργός'),
 ('cons1', '$2y$10$hash', 'c1@mail.cy', '99123456', N'Μαρία', N'Καταναλώτρια'),
 ('tech1', '$2y$10$hash', 't1@mail.cy', NULL, N'Γιώργος', N'Τεχνικός'),
 ('mkt1', '$2y$10$hash', 'm1@supplier.cy', NULL, N'Ελένη', N'Προμηθευτή'),
 ('tso1', '$2y$10$hash', 'tso@tso.cy', NULL, N'Κώστας', N'ΔΣΜΚ'),
 ('dso1', '$2y$10$hash', 'dso@dso.cy', NULL, N'Νίκος', N'ΔΣΔ');
INSERT INTO SYSTEM_ADMIN (UserID) VALUES (1);
INSERT INTO SYSTEM_OPERATOR (UserID, CreatedBy) VALUES (2, 1);
INSERT INTO CONSUMER (UserID) VALUES (3);
INSERT INTO FIELD_TECHNICIAN (UserID, BirthDate, Photo) VALUES (4, '1990-05-01', N'/files/photos/4.jpg');
INSERT INTO SUPPLIER (Name) VALUES (N'Supplier A');
INSERT INTO AGGREGATOR (Name) VALUES (N'Aggregator A');
INSERT INTO MARKET_USER (UserID, SupplierID) VALUES (5, 1);
INSERT INTO TSO_OPERATOR (UserID) VALUES (6);
INSERT INTO DSO_OPERATOR (UserID) VALUES (7);
INSERT INTO CONSUMER_NOTIFICATION_CHANNEL (UserID, NotificationChannel) VALUES (3, 'Email'), (3, 'SMS');
INSERT INTO DISTRICT (Name) VALUES (N'Λευκωσία');
INSERT INTO MUNICIPALITY (Name, DistrictID) VALUES (N'Στρόβολος', 1);
INSERT INTO PARISH (Name, MunicipalityID) VALUES (N'Άγιος Δημήτριος', 1);
INSERT INTO SUPPLY_SCHEME (Name) VALUES (N'Net metering');
INSERT INTO PREMISE (Address, PostalCode, Latitude, Longitude, UsageType, ParishID, SchemeID) VALUES (N'Οδός Παράδεισου 1', '2001', 35.150000, 33.350000, 'Residential', 1, 1);
INSERT INTO HOLDING (UserID, PremiseID, StartDate) VALUES (3, 1, '2026-01-01');
INSERT INTO METER_MODEL (Manufacturer, ModelName, MeterType) VALUES (N'Landis+Gyr', N'E450', 'Single-Phase');
INSERT INTO COMM_TYPE (Name) VALUES (N'PLC');
INSERT INTO GEOFENCE (Name, Level, MinLat, MinLon, MaxLat, MaxLon) VALUES (N'Στρόβολος 1', 1, 35.100000, 33.300000, 35.200000, 33.400000);
INSERT INTO TRANSFORMER (Name, Latitude, Longitude, GeofenceID) VALUES (N'TR-001', 35.150000, 33.350000, 1);
INSERT INTO METER (SerialNumber, NetworkID, Firmware, MaxLoadAmps, Latitude, Longitude, ModelID, CommTypeID, TransformerID) VALUES ('SN-0001', 'NET-0001', '1.0.3', 60, 35.150100, 33.350100, 1, 1, 1);
INSERT INTO METER_CONNECTED_PHASE (MeterID, ConnectedPhase) VALUES (1, 'L1');
INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID, PremiseID) VALUES ('Installation', '2026-02-01 08:00', '2026-02-01 10:00', 4, 1);
INSERT INTO METER_INSTALLATION (InstalledAt, MeterID, PremiseID, TaskID) VALUES ('2026-02-01 09:00', 1, 1, 1);
INSERT INTO OBIS_CODE (ObisCode, Description, Unit, Kind, Phase) VALUES ('1.8.0', N'Active energy import', 'kWh', 'Cumulative register', NULL), ('32.7.0', N'Voltage L1', 'V', 'Instantaneous', 'L1');
INSERT INTO TELEMETRY_PACKET (ReceivedNetworkID, TransmissionTimestamp, RawPayload, IngestStatus, MeterID) VALUES ('NET-0001', '2026-10-30 12:00', N'{"meter":"NET-0001"}', 'Accepted', 1);
INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, '1.8.0', '2026-10-30 12:00', 1234.5678, 1);
INSERT INTO VEE_RULE (RuleType, Parameters) VALUES ('Linear interpolation', N'{"maxGap": 4}');
INSERT INTO VEE_RUN (PeriodFrom, PeriodTo) VALUES ('2026-10-30 00:00', '2026-10-31 00:00');
INSERT INTO TARIFF_TYPE (Name) VALUES (N'Οικιακό');
INSERT INTO SUPPLY_CONTRACT (StartDate, UserID, PremiseID, SupplierID, TariffTypeID) VALUES ('2026-01-01', 3, 1, 1, 1);
INSERT INTO INVOICE (IssueDate, PeriodFrom, PeriodTo, Amount, UserID, ContractID) VALUES ('2026-03-01', '2026-02-01', '2026-02-28', 55.20, 3, 1);
INSERT INTO SERVICE_TYPE (Name, Fee) VALUES (N'Historical data access', 5.00);
INSERT INTO BANK_ACCOUNT (IBAN, HolderName, UserID) VALUES ('CY17002001280000001200527600', N'Μαρία Καταναλώτρια', 3);
INSERT INTO GDPR_REQUEST (ConsumerID) VALUES (3);
INSERT INTO PORTFOLIO (Name, AggregatorID) VALUES (N'Χαρτοφυλάκιο 1', 1);
INSERT INTO INCLUDES (PortfolioID, PremiseID, StartDate) VALUES (1, 1, '2026-01-01');
INSERT INTO LOAD_SHED_ORDER (Reason, TransformerID, OrderedBy) VALUES (N'Υπερφόρτωση', 1, 6);
INSERT INTO REMOTE_COMMAND (CommandType, Status, MeterID, RequestedBy, ShedOrderID) VALUES ('Load shed', 'Sent', 1, 6, 1);
INSERT INTO COMMAND_ATTEMPT (CommandID, AttemptNo, AttemptAt, RespondedAt, Outcome) VALUES (1, 1, '2026-10-30 12:00:00.000', '2026-10-30 12:00:01.500', 'ACK');
INSERT INTO AUDIT_LOG (ObjectType, ObjectID, Action, PerformedBy, NewState) VALUES ('METER', '1', 'Created', 2, 'Pending confirmation');
`;

const ACC = `INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES ('new1', 'h', 'new1@mail.cy', N'Νέος', N'Χρήστης');`;
const tests = [
  // users
  { area: 'users', el: 'Ένας λογαριασμός με δεύτερο ρόλο (ΛΣ που είναι και ΔΣΔ)', sql: `INSERT INTO DSO_OPERATOR (UserID) VALUES (2);`, expect: 'OK' },
  { area: 'users', el: 'Ο ίδιος ρόλος δύο φορές στον ίδιο λογαριασμό', sql: `INSERT INTO CONSUMER (UserID) VALUES (3);`, expect: 'PK_CONSUMER' },
  { area: 'users', el: 'Ρόλος χωρίς λογαριασμό', sql: `INSERT INTO CONSUMER (UserID) VALUES (999);`, expect: 'FK_CONSUMER_IS_CONSUMER' },
  { area: 'users', el: 'Δεύτερος λογαριασμός με το ίδιο Username', sql: `INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES ('cons1', 'h', 'other@mail.cy', N'Α', N'Β');`, expect: 'UQ_USER_ACCOUNT_Username' },
  { area: 'users', el: 'E-mail χωρίς @', sql: `INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES ('x1', 'h', 'not-an-email', N'Α', N'Β');`, expect: 'CK_USER_ACCOUNT_Email' },
  { area: 'users', el: 'Διατήρηση 37 μηνών (πάνω από τα 3 χρόνια)', sql: `UPDATE CONSUMER SET RawRetentionMonths = 37 WHERE UserID = 3;`, expect: 'CK_CONSUMER_RawRetentionMonths' },
  { area: 'users', el: 'Διατήρηση 1 μήνα μετά από αίτημα GDPR', sql: `UPDATE CONSUMER SET RawRetentionMonths = 1 WHERE UserID = 3;`, expect: 'OK' },
  { area: 'users', el: 'Έγκριση τεχνικού χωρίς τον ΛΣ που ενέκρινε', sql: `UPDATE FIELD_TECHNICIAN SET ApprovalStatus = 'Approved' WHERE UserID = 4;`, expect: 'CK_FIELD_TECHNICIAN_Decision' },
  { area: 'users', el: 'Έγκριση τεχνικού με ΛΣ και ώρα', sql: `UPDATE FIELD_TECHNICIAN SET ApprovalStatus = 'Approved', ApprovedBy = 2, ApprovalDecidedAt = SYSUTCDATETIME() WHERE UserID = 4;`, expect: 'OK' },
  { area: 'users', el: 'Έγκριση τεχνικού από χρήστη που δεν είναι ΛΣ', sql: `UPDATE FIELD_TECHNICIAN SET ApprovalStatus = 'Approved', ApprovedBy = 3, ApprovalDecidedAt = SYSUTCDATETIME() WHERE UserID = 4;`, expect: 'FK_FIELD_TECHNICIAN_APPROVES' },
  { area: 'users', el: 'Χρήστης αγοράς σε προμηθευτή και σε aggregator μαζί', sql: `${ACC} INSERT INTO MARKET_USER (UserID, SupplierID, AggregatorID) VALUES (SCOPE_IDENTITY(), 1, 1);`, expect: 'CK_MARKET_USER_OneCompany' },
  { area: 'users', el: 'Χρήστης αγοράς χωρίς εταιρεία', sql: `${ACC} INSERT INTO MARKET_USER (UserID) VALUES (SCOPE_IDENTITY());`, expect: 'CK_MARKET_USER_OneCompany' },
  { area: 'users', el: 'Χρήστης αγοράς μόνο σε aggregator', sql: `${ACC} INSERT INTO MARKET_USER (UserID, AggregatorID) VALUES (SCOPE_IDENTITY(), 1);`, expect: 'OK' },
  { area: 'users', el: 'Κανάλι ειδοποίησης εκτός λίστας (Fax)', sql: `INSERT INTO CONSUMER_NOTIFICATION_CHANNEL (UserID, NotificationChannel) VALUES (3, 'Fax');`, expect: 'CK_CONSUMER_NOTIFICATION_CHANNEL_NotificationChannel' },
  { area: 'users', el: 'Διαγραφή λογαριασμού που έχει ρόλο και ιστορικό', sql: `DELETE FROM USER_ACCOUNT WHERE UserID = 3;`, expect: 'FK_CONSUMER_IS_CONSUMER' },
  // premises
  { area: 'premises', el: 'Δεύτερος δήμος με το ίδιο όνομα στην ίδια επαρχία', sql: `INSERT INTO MUNICIPALITY (Name, DistrictID) VALUES (N'Στρόβολος', 1);`, expect: 'UQ_MUNICIPALITY_DistrictID_Name' },
  { area: 'premises', el: 'Ταχυδρομικός κώδικας με γράμμα', sql: `UPDATE PREMISE SET PostalCode = '20A1' WHERE PremiseID = 1;`, expect: 'CK_PREMISE_PostalCode' },
  { area: 'premises', el: 'Δεύτερη ανοιχτή κατοχή του ίδιου ακινήτου από τον ίδιο καταναλωτή', sql: `INSERT INTO HOLDING (UserID, PremiseID, StartDate) VALUES (3, 1, '2026-06-01');`, expect: 'UX_HOLDING_Open' },
  { area: 'premises', el: 'Νέα κατοχή αφού έκλεισε η προηγούμενη', sql: `UPDATE HOLDING SET EndDate = '2026-05-31' WHERE UserID = 3 AND PremiseID = 1; INSERT INTO HOLDING (UserID, PremiseID, StartDate) VALUES (3, 1, '2026-06-01');`, expect: 'OK' },
  { area: 'premises', el: 'Κατοχή που λήγει πριν αρχίσει', sql: `UPDATE HOLDING SET EndDate = '2025-12-31' WHERE UserID = 3 AND PremiseID = 1;`, expect: 'CK_HOLDING_Dates' },
  // billing and market
  { area: 'billing', el: 'Δεύτερο ανοιχτό συμβόλαιο για το ίδιο ακίνητο', sql: `INSERT INTO SUPPLY_CONTRACT (StartDate, UserID, PremiseID, SupplierID) VALUES ('2026-06-01', 3, 1, 1);`, expect: 'UX_SUPPLY_CONTRACT_Open' },
  { area: 'billing', el: 'Συμβόλαιο με προμηθευτή που δεν υπάρχει', sql: `UPDATE SUPPLY_CONTRACT SET EndDate = '2026-05-31'; INSERT INTO SUPPLY_CONTRACT (StartDate, UserID, PremiseID, SupplierID) VALUES ('2026-06-01', 3, 1, 99);`, expect: 'FK_SUPPLY_CONTRACT_SUPPLIED_BY' },
  { area: 'billing', el: 'Πληρωμή μηδενικού ποσού', sql: `INSERT INTO PAYMENT (Amount, PaidAt, InvoiceID, BankAccountID) VALUES (0, SYSUTCDATETIME(), 1, 1);`, expect: 'CK_PAYMENT_Amount' },
  { area: 'billing', el: 'Πληρωμή από λογαριασμό του καταναλωτή', sql: `INSERT INTO PAYMENT (Amount, PaidAt, InvoiceID, BankAccountID) VALUES (55.20, SYSUTCDATETIME(), 1, 1);`, expect: 'OK' },
  { area: 'billing', el: 'IBAN με σύμβολα', sql: `INSERT INTO BANK_ACCOUNT (IBAN, HolderName) VALUES ('CY17-0020-0128', N'Χ');`, expect: 'CK_BANK_ACCOUNT_IBAN' },
  { area: 'billing', el: 'Αγορά ιστορικών μηνών που δεν αρχίζουν την 1η', sql: `INSERT INTO SERVICE_PURCHASE (MonthFrom, MonthTo, Amount, UserID, ServiceTypeID, PremiseID, InvoiceID) VALUES ('2026-03-15', '2026-04-01', 5.00, 3, 1, 1, 1);`, expect: 'CK_SERVICE_PURCHASE_Months' },
  { area: 'billing', el: 'Αγορά ιστορικών μηνών Μαρτίου έως Απριλίου', sql: `INSERT INTO SERVICE_PURCHASE (MonthFrom, MonthTo, Amount, UserID, ServiceTypeID, PremiseID, InvoiceID) VALUES ('2026-03-01', '2026-04-01', 5.00, 3, 1, 1, 1);`, expect: 'OK' },
  // field work
  { area: 'field', el: 'Εργασία Done χωρίς ημερομηνία ολοκλήρωσης', sql: `UPDATE FIELD_TASK SET Status = 'Done', Result = N'OK' WHERE TaskID = 1;`, expect: 'CK_FIELD_TASK_Done' },
  { area: 'field', el: 'Αντικατάσταση χωρίς τον παλιό μετρητή', sql: `INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID, PremiseID) VALUES ('Replacement', '2026-03-01 08:00', '2026-03-01 10:00', 4, 1);`, expect: 'CK_FIELD_TASK_Install' },
  { area: 'field', el: 'Τεχνικός έλεγχος χωρίς ακίνητο και χωρίς μετρητή', sql: `INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID) VALUES ('Technical check', '2026-03-01 08:00', '2026-03-01 10:00', 4);`, expect: 'CK_FIELD_TASK_Target' },
  { area: 'field', el: 'Διάστημα διαθεσιμότητας που τελειώνει πριν αρχίσει', sql: `INSERT INTO AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (4, '2026-03-02', '14:00', '09:00');`, expect: 'CK_AVAILABILITY_Slot' },
  { area: 'field', el: 'Διάστημα διαθεσιμότητας σε δήμο', sql: `INSERT INTO AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (4, '2026-03-02', '09:00', '14:00'); INSERT INTO AVAILABLE_IN (UserID, AvailDate, FromTime, MunicipalityID) VALUES (4, '2026-03-02', '09:00', 1);`, expect: 'OK' },
  { area: 'field', el: 'Έγγραφο τεχνικού με τύπο έγγραφου μετρητή', sql: `INSERT INTO DOCUMENT (DocType, DocNumber, IssueDate, FilePath, TechnicianID) VALUES ('Calibration certificate', 'C-1', '2026-01-10', N'/files/docs/1.pdf', 4);`, expect: 'CK_DOCUMENT_Owner' },
  { area: 'field', el: 'Έγγραφο Accepted χωρίς ΛΣ που το εξέτασε', sql: `INSERT INTO DOCUMENT (DocType, DocNumber, IssueDate, FilePath, ReviewStatus, TechnicianID) VALUES ('ID card', 'ID-1', '2020-01-10', N'/files/docs/2.pdf', 'Accepted', 4);`, expect: 'CK_DOCUMENT_Review' },
  { area: 'field', el: 'Σημείωση εργασίας με αριθμό 0', sql: `INSERT INTO TASK_NOTE (TaskID, NoteNo, NoteKind, Text, WrittenBy) VALUES (1, 0, 'Observation', N'Κείμενο', 4);`, expect: 'CK_TASK_NOTE_NoteNo' },
  // meters
  { area: 'meters', el: 'Δεύτερη ανοιχτή εγκατάσταση του ίδιου μετρητή', sql: `INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID, PremiseID) VALUES ('Installation', '2026-03-01 08:00', '2026-03-01 10:00', 4, 1); INSERT INTO METER_INSTALLATION (InstalledAt, MeterID, PremiseID, TaskID) VALUES ('2026-03-01 09:00', 1, 1, SCOPE_IDENTITY());`, expect: 'UX_METER_INSTALLATION_Open' },
  { area: 'meters', el: 'Δύο εγκαταστάσεις από την ίδια εργασία (DONE_IN 1:1)', sql: `UPDATE METER_INSTALLATION SET RemovedAt = '2026-02-20' WHERE InstallationID = 1; INSERT INTO METER_INSTALLATION (InstalledAt, MeterID, PremiseID, TaskID) VALUES ('2026-03-01 09:00', 1, 1, 1);`, expect: 'UQ_METER_INSTALLATION_TaskID' },
  { area: 'meters', el: 'Επιβεβαίωση εγκατάστασης χωρίς ΛΣ', sql: `UPDATE METER_INSTALLATION SET ConfirmationStatus = 'Confirmed' WHERE InstallationID = 1;`, expect: 'CK_METER_INSTALLATION_Confirmation' },
  { area: 'meters', el: 'Κατάσταση μετρητή εκτός λίστας', sql: `UPDATE METER SET Status = 'Broken' WHERE MeterID = 1;`, expect: 'CK_METER_Status' },
  { area: 'meters', el: 'Εντολή Load shed χωρίς εντολή περικοπής', sql: `INSERT INTO REMOTE_COMMAND (CommandType, Status, MeterID, RequestedBy) VALUES ('Load shed', 'Sent', 1, 6);`, expect: 'CK_REMOTE_COMMAND_ShedOrder' },
  { area: 'meters', el: 'Εντολή σε αναμονή έγκρισης που έχει ήδη εγκρίνοντα', sql: `INSERT INTO REMOTE_COMMAND (CommandType, Status, MeterID, RequestedBy, ApprovedBy) VALUES ('Disconnect', 'Awaiting approval', 1, 2, 2);`, expect: 'CK_REMOTE_COMMAND_Approval' },
  { area: 'meters', el: 'Παράμετροι εντολής που δεν είναι JSON', sql: `INSERT INTO REMOTE_COMMAND (CommandType, Status, Parameters, MeterID, RequestedBy) VALUES ('Firmware upgrade', 'Awaiting approval', N'version=2', 1, 2);`, expect: 'CK_REMOTE_COMMAND_Parameters' },
  { area: 'meters', el: 'Απάντηση ACK χωρίς ώρα απάντησης', sql: `INSERT INTO COMMAND_ATTEMPT (CommandID, AttemptNo, AttemptAt, Outcome) VALUES (1, 2, '2026-10-30 12:05', 'ACK');`, expect: 'CK_COMMAND_ATTEMPT_Response' },
  { area: 'meters', el: 'Διαγραφή μετρητή που έχει ιστορικό (εγκατάσταση, πακέτα, μετρήσεις)', sql: `DELETE FROM METER_CONNECTED_PHASE WHERE MeterID = 1; DELETE FROM METER WHERE MeterID = 1;`, expect: 'REFERENCE constraint' },
  // telemetry
  { area: 'telemetry', el: 'Μέτρηση στις 12:07 (όχι σε όριο 15 λεπτών)', sql: `INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, '1.8.0', '2026-10-30 12:07', 1235, 1);`, expect: 'CK_READING_IntervalStart' },
  { area: 'telemetry', el: 'Ίδια μέτρηση δεύτερη φορά (μετρητής, OBIS, διάστημα)', sql: `INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, '1.8.0', '2026-10-30 12:00', 1235, 1);`, expect: 'PK_READING' },
  { area: 'telemetry', el: 'Κενό (χωρίς τιμή) με κατάσταση Raw', sql: `INSERT INTO READING (MeterID, ObisCode, IntervalStart) VALUES (1, '1.8.0', '2026-10-30 12:15');`, expect: 'CK_READING_Gap' },
  { area: 'telemetry', el: 'Κενό που συμπληρώθηκε με εκτίμηση', sql: `INSERT INTO READING (MeterID, ObisCode, IntervalStart, UsedValue, Status) VALUES (1, '1.8.0', '2026-10-30 12:15', 1236.1000, 'Estimated'); INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, NewValue, Origin, RuleID) VALUES (1, '1.8.0', '2026-10-30 12:15', 1, 1236.1000, 'Automatic estimate', 1);`, expect: 'OK' },
  { area: 'telemetry', el: 'Τιμή μέτρησης χωρίς πακέτο', sql: `INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue) VALUES (1, '1.8.0', '2026-10-30 12:30', 1237);`, expect: 'CK_READING_Packet' },
  { area: 'telemetry', el: 'Οριστικοποίηση μέτρησης Suspect', sql: `UPDATE READING SET Status = 'Suspect', RunID = 1;`, expect: 'CK_READING_Final' },
  { area: 'telemetry', el: 'Αυτόματη εκτίμηση με χρήστη', sql: `INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy, RuleID) VALUES (1, '1.8.0', '2026-10-30 12:00', 1, 1234.5678, 1234.6, 'Automatic estimate', 7, 1);`, expect: 'CK_READING_EDIT_OriginActor' },
  { area: 'telemetry', el: 'Χειροκίνητη διόρθωση από ΔΣΔ', sql: `INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy, Reason) VALUES (1, '1.8.0', '2026-10-30 12:00', 1, 1234.5678, 1234.6, 'Manual edit', 7, N'Λάθος μετάδοσης');`, expect: 'OK' },
  { area: 'telemetry', el: 'Χειροκίνητη διόρθωση από χρήστη που δεν είναι ΔΣΔ', sql: `INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy) VALUES (1, '1.8.0', '2026-10-30 12:00', 1, 1234.5678, 1234.6, 'Manual edit', 2);`, expect: 'FK_READING_EDIT_EDITED_BY' },
  { area: 'telemetry', el: 'Διαγραφή μέτρησης παίρνει μαζί τις διορθώσεις της', sql: `INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy) VALUES (1, '1.8.0', '2026-10-30 12:00', 1, 1234.5678, 1234.6, 'Manual edit', 7); DELETE FROM READING WHERE MeterID = 1; IF EXISTS (SELECT 1 FROM READING_EDIT) THROW 50001, 'edits left behind', 1;`, expect: 'OK' },
  { area: 'telemetry', el: 'Πακέτο Unknown meter που δείχνει σε μετρητή', sql: `INSERT INTO TELEMETRY_PACKET (ReceivedNetworkID, RawPayload, IngestStatus, MeterID) VALUES ('NET-9999', N'{}', 'Unknown meter', 1);`, expect: 'CK_TELEMETRY_PACKET_Meter' },
  { area: 'telemetry', el: 'Πακέτο Unknown meter και το συμβάν του', sql: `INSERT INTO TELEMETRY_PACKET (ReceivedNetworkID, RawPayload, IngestStatus) VALUES ('NET-9999', N'{}', 'Unknown meter'); INSERT INTO EVENT (EventType, Severity, OccurredAt, PacketID) VALUES ('Unmatched packet', 'Warning', SYSUTCDATETIME(), SCOPE_IDENTITY());`, expect: 'OK' },
  { area: 'telemetry', el: 'Συμβάν Unmatched packet χωρίς πακέτο', sql: `INSERT INTO EVENT (EventType, Severity, OccurredAt) VALUES ('Unmatched packet', 'Warning', SYSUTCDATETIME());`, expect: 'CK_EVENT_Unmatched' },
  { area: 'telemetry', el: 'Πακέτο Malformed χωρίς μήνυμα λάθους', sql: `INSERT INTO TELEMETRY_PACKET (RawPayload, IngestStatus) VALUES (N'{bad', 'Malformed');`, expect: 'CK_TELEMETRY_PACKET_Error' },
  // grid
  { area: 'grid', el: 'Geofence με MinLat μεγαλύτερο από MaxLat', sql: `INSERT INTO GEOFENCE (Name, Level, MinLat, MinLon, MaxLat, MaxLon) VALUES (N'Λάθος', 1, 35.3, 33.3, 35.2, 33.4);`, expect: 'CK_GEOFENCE_Rectangle' },
  { area: 'grid', el: 'Δεύτερος μετασχηματιστής στο ίδιο geofence', sql: `INSERT INTO TRANSFORMER (Name, Latitude, Longitude, GeofenceID) VALUES (N'TR-002', 35.16, 33.36, 1);`, expect: 'UQ_TRANSFORMER_GeofenceID' },
  { area: 'grid', el: 'Μηνιαίο aggregate που αρχίζει στις 15 του μήνα', sql: `INSERT INTO METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount) VALUES (1, '1.8.0', 'Month', '2026-10-15', 300, 2976, 0);`, expect: 'CK_METER_AGGREGATE_Period' },
  { area: 'grid', el: 'Aggregate με περισσότερες εκτιμήσεις από μετρήσεις', sql: `INSERT INTO METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount) VALUES (1, '1.8.0', 'Day', '2026-10-15', 10, 96, 97);`, expect: 'CK_METER_AGGREGATE_Counts' },
  { area: 'grid', el: '15λεπτο aggregate geofence στις 12:15', sql: `INSERT INTO GEOFENCE_AGGREGATE (GeofenceID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount) VALUES (1, '1.8.0', '15 min', '2026-10-30 12:15', 12.5, 1);`, expect: 'OK' },
  { area: 'grid', el: '15λεπτο aggregate geofence στις 12:10', sql: `INSERT INTO GEOFENCE_AGGREGATE (GeofenceID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount) VALUES (1, '1.8.0', '15 min', '2026-10-30 12:10', 12.5, 1);`, expect: 'CK_GEOFENCE_AGGREGATE_Period' },
  { area: 'grid', el: 'Τρέχουσα κατάσταση για τάση (32.7.0)', sql: `INSERT INTO GEOFENCE_CURRENT_STATE (GeofenceID, ObisCode, RefInterval, SumValue, MeterCount) VALUES (1, '32.7.0', '2026-10-30 12:00', 230, 1);`, expect: 'CK_GEOFENCE_CURRENT_STATE_Code' },
  // trace
  { area: 'trace', el: 'Τελική έγκριση GDPR από ΛΣ και ΔΣ μαζί', sql: `UPDATE GDPR_REQUEST SET Status = 'Approved', PreApprovedBy = 2, PreApprovedAt = SYSUTCDATETIME(), DecidedBy = 2, DecidedByAdmin = 1, DecidedAt = SYSUTCDATETIME();`, expect: 'CK_GDPR_REQUEST_OneFinal' },
  { area: 'trace', el: 'GDPR Approved χωρίς προέγκριση', sql: `UPDATE GDPR_REQUEST SET Status = 'Approved', DecidedByAdmin = 1, DecidedAt = SYSUTCDATETIME();`, expect: 'CK_GDPR_REQUEST_Stage' },
  { area: 'trace', el: 'GDPR: προέγκριση από ΛΣ, τελική έγκριση από ΔΣ', sql: `UPDATE GDPR_REQUEST SET Status = 'Pre-approved', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt); UPDATE GDPR_REQUEST SET Status = 'Approved', DecidedByAdmin = 1, DecidedAt = DATEADD(MINUTE, 2, SubmittedAt);`, expect: 'OK' },
  { area: 'trace', el: 'GDPR: τελική απόφαση πριν από την προέγκριση', sql: `UPDATE GDPR_REQUEST SET Status = 'Approved', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 5, SubmittedAt), DecidedBy = 2, DecidedAt = DATEADD(MINUTE, 1, SubmittedAt);`, expect: 'CK_GDPR_REQUEST_Order' },
  { area: 'trace', el: 'GDPR: απόρριψη στην εξέταση από ΛΣ, χωρίς τελική απόφαση', sql: `UPDATE GDPR_REQUEST SET Status = 'Rejected', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt);`, expect: 'OK' },
  { area: 'trace', el: 'GDPR: απόρριψη στην τελική απόφαση από ΔΣ', sql: `UPDATE GDPR_REQUEST SET Status = 'Pre-approved', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt); UPDATE GDPR_REQUEST SET Status = 'Rejected', DecidedByAdmin = 1, DecidedAt = DATEADD(MINUTE, 2, SubmittedAt);`, expect: 'OK' },
  { area: 'trace', el: 'GDPR: απόρριψη χωρίς καταγραφή της εξέτασης', sql: `UPDATE GDPR_REQUEST SET Status = 'Rejected';`, expect: 'CK_GDPR_REQUEST_Stage' },
  { area: 'trace', el: 'Εγγραφή log χωρίς χρήστη και χωρίς μηχανισμό', sql: `INSERT INTO AUDIT_LOG (ObjectType, ObjectID, Action) VALUES ('METER', '1', 'Updated');`, expect: 'CK_AUDIT_LOG_Actor' },
  { area: 'trace', el: 'Εγγραφή log από τον μηχανισμό VEE', sql: `INSERT INTO AUDIT_LOG (ObjectType, ObjectID, Action, ActorMechanism, OldState, NewState) VALUES ('READING', '1|1.8.0|2026-10-30T12:00', 'VEE', N'VEE run 1, rule 1', 'Raw', 'Validated');`, expect: 'OK' }
];

const lit = s => "N'" + s.replace(/'/g, "''") + "'";
const sql = `-- MDMS-Cy: δοκιμές περιορισμών. Τρέχει σε κενή βάση μετά το create.sql.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON; -- the filtered UNIQUE indexes need it for INSERT and UPDATE (sqlcmd: -I)
${setup}
GO
CREATE TABLE #r (n INT PRIMARY KEY, expected NVARCHAR(128), got NVARCHAR(2000));
GO
CREATE OR ALTER PROCEDURE dbo.t_run @n INT, @sql NVARCHAR(MAX), @expected NVARCHAR(128) AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @got NVARCHAR(2000) = N'OK';
  BEGIN TRAN;
  BEGIN TRY EXEC sp_executesql @sql; END TRY
  BEGIN CATCH SET @got = ERROR_MESSAGE(); END CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  INSERT INTO #r (n, expected, got) VALUES (@n, @expected, @got);
END
GO
${tests.map((t, i) => `EXEC dbo.t_run ${i + 1}, ${lit(t.sql)}, ${lit(t.expect)};`).join('\n')}
GO
SELECT n, expected, REPLACE(REPLACE(got, CHAR(13), ' '), CHAR(10), ' ') AS got FROM #r ORDER BY n FOR JSON PATH;
GO
DROP PROCEDURE dbo.t_run;
GO
`;
module.exports = { tests, setup };
if (require.main === module) { fs.writeFileSync('test.sql', sql); console.log('tests', tests.length); }
