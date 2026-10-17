-- MDMS-Cy: δοκιμές περιορισμών. Τρέχει σε κενή βάση μετά το create.sql.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON; -- the filtered UNIQUE indexes need it for INSERT and UPDATE (sqlcmd: -I)

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
INSERT INTO METER_MODEL (Manufacturer, ModelName, MeterType, PhaseCount) VALUES (N'Landis+Gyr', N'E450', 'Single-Phase', 1);
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
EXEC dbo.t_run 1, N'INSERT INTO DSO_OPERATOR (UserID) VALUES (2);', N'OK';
EXEC dbo.t_run 2, N'INSERT INTO CONSUMER (UserID) VALUES (3);', N'PK_CONSUMER';
EXEC dbo.t_run 3, N'INSERT INTO CONSUMER (UserID) VALUES (999);', N'FK_CONSUMER_IS_CONSUMER';
EXEC dbo.t_run 4, N'INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES (''cons1'', ''h'', ''other@mail.cy'', N''Α'', N''Β'');', N'UQ_USER_ACCOUNT_Username';
EXEC dbo.t_run 5, N'INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES (''x1'', ''h'', ''not-an-email'', N''Α'', N''Β'');', N'CK_USER_ACCOUNT_Email';
EXEC dbo.t_run 6, N'UPDATE CONSUMER SET RawRetentionMonths = 37 WHERE UserID = 3;', N'CK_CONSUMER_RawRetentionMonths';
EXEC dbo.t_run 7, N'UPDATE CONSUMER SET RawRetentionMonths = 1 WHERE UserID = 3;', N'OK';
EXEC dbo.t_run 8, N'UPDATE FIELD_TECHNICIAN SET ApprovalStatus = ''Approved'' WHERE UserID = 4;', N'CK_FIELD_TECHNICIAN_Decision';
EXEC dbo.t_run 9, N'UPDATE FIELD_TECHNICIAN SET ApprovalStatus = ''Approved'', ApprovedBy = 2, ApprovalDecidedAt = SYSUTCDATETIME() WHERE UserID = 4;', N'OK';
EXEC dbo.t_run 10, N'UPDATE FIELD_TECHNICIAN SET ApprovalStatus = ''Approved'', ApprovedBy = 3, ApprovalDecidedAt = SYSUTCDATETIME() WHERE UserID = 4;', N'FK_FIELD_TECHNICIAN_APPROVES';
EXEC dbo.t_run 11, N'INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES (''new1'', ''h'', ''new1@mail.cy'', N''Νέος'', N''Χρήστης''); INSERT INTO MARKET_USER (UserID, SupplierID, AggregatorID) VALUES (SCOPE_IDENTITY(), 1, 1);', N'CK_MARKET_USER_OneCompany';
EXEC dbo.t_run 12, N'INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES (''new1'', ''h'', ''new1@mail.cy'', N''Νέος'', N''Χρήστης''); INSERT INTO MARKET_USER (UserID) VALUES (SCOPE_IDENTITY());', N'CK_MARKET_USER_OneCompany';
EXEC dbo.t_run 13, N'INSERT INTO USER_ACCOUNT (Username, PasswordHash, Email, FirstName, LastName) VALUES (''new1'', ''h'', ''new1@mail.cy'', N''Νέος'', N''Χρήστης''); INSERT INTO MARKET_USER (UserID, AggregatorID) VALUES (SCOPE_IDENTITY(), 1);', N'OK';
EXEC dbo.t_run 14, N'INSERT INTO CONSUMER_NOTIFICATION_CHANNEL (UserID, NotificationChannel) VALUES (3, ''Fax'');', N'CK_CONSUMER_NOTIFICATION_CHANNEL_NotificationChannel';
EXEC dbo.t_run 15, N'DELETE FROM USER_ACCOUNT WHERE UserID = 3;', N'FK_CONSUMER_IS_CONSUMER';
EXEC dbo.t_run 16, N'INSERT INTO MUNICIPALITY (Name, DistrictID) VALUES (N''Στρόβολος'', 1);', N'UQ_MUNICIPALITY_DistrictID_Name';
EXEC dbo.t_run 17, N'UPDATE PREMISE SET PostalCode = ''20A1'' WHERE PremiseID = 1;', N'CK_PREMISE_PostalCode';
EXEC dbo.t_run 18, N'INSERT INTO HOLDING (UserID, PremiseID, StartDate) VALUES (3, 1, ''2026-06-01'');', N'UX_HOLDING_Open';
EXEC dbo.t_run 19, N'UPDATE HOLDING SET EndDate = ''2026-05-31'' WHERE UserID = 3 AND PremiseID = 1; INSERT INTO HOLDING (UserID, PremiseID, StartDate) VALUES (3, 1, ''2026-06-01'');', N'OK';
EXEC dbo.t_run 20, N'UPDATE HOLDING SET EndDate = ''2025-12-31'' WHERE UserID = 3 AND PremiseID = 1;', N'CK_HOLDING_Dates';
EXEC dbo.t_run 21, N'INSERT INTO SUPPLY_CONTRACT (StartDate, UserID, PremiseID, SupplierID) VALUES (''2026-06-01'', 3, 1, 1);', N'UX_SUPPLY_CONTRACT_Open';
EXEC dbo.t_run 22, N'UPDATE SUPPLY_CONTRACT SET EndDate = ''2026-05-31''; INSERT INTO SUPPLY_CONTRACT (StartDate, UserID, PremiseID, SupplierID) VALUES (''2026-06-01'', 3, 1, 99);', N'FK_SUPPLY_CONTRACT_SUPPLIED_BY';
EXEC dbo.t_run 23, N'INSERT INTO PAYMENT (Amount, PaidAt, InvoiceID, BankAccountID) VALUES (0, SYSUTCDATETIME(), 1, 1);', N'CK_PAYMENT_Amount';
EXEC dbo.t_run 24, N'INSERT INTO PAYMENT (Amount, PaidAt, InvoiceID, BankAccountID) VALUES (55.20, SYSUTCDATETIME(), 1, 1);', N'OK';
EXEC dbo.t_run 25, N'INSERT INTO BANK_ACCOUNT (IBAN, HolderName) VALUES (''CY17-0020-0128'', N''Χ'');', N'CK_BANK_ACCOUNT_IBAN';
EXEC dbo.t_run 26, N'INSERT INTO SERVICE_PURCHASE (MonthFrom, MonthTo, Amount, ServiceTypeID, PremiseID, InvoiceID) VALUES (''2026-03-15'', ''2026-04-01'', 5.00, 1, 1, 1);', N'CK_SERVICE_PURCHASE_Months';
EXEC dbo.t_run 27, N'INSERT INTO SERVICE_PURCHASE (MonthFrom, MonthTo, Amount, ServiceTypeID, PremiseID, InvoiceID) VALUES (''2026-03-01'', ''2026-04-01'', 5.00, 1, 1, 1);', N'OK';
EXEC dbo.t_run 28, N'UPDATE FIELD_TASK SET Status = ''Done'', Result = N''OK'' WHERE TaskID = 1;', N'CK_FIELD_TASK_Done';
EXEC dbo.t_run 29, N'INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID, PremiseID) VALUES (''Replacement'', ''2026-03-01 08:00'', ''2026-03-01 10:00'', 4, 1);', N'CK_FIELD_TASK_Install';
EXEC dbo.t_run 30, N'INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID) VALUES (''Technical check'', ''2026-03-01 08:00'', ''2026-03-01 10:00'', 4);', N'CK_FIELD_TASK_Target';
EXEC dbo.t_run 31, N'INSERT INTO AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (4, ''2026-03-02'', ''14:00'', ''09:00'');', N'CK_AVAILABILITY_Slot';
EXEC dbo.t_run 32, N'INSERT INTO AVAILABILITY (UserID, AvailDate, FromTime, ToTime) VALUES (4, ''2026-03-02'', ''09:00'', ''14:00''); INSERT INTO AVAILABLE_IN (UserID, AvailDate, FromTime, MunicipalityID) VALUES (4, ''2026-03-02'', ''09:00'', 1);', N'OK';
EXEC dbo.t_run 33, N'INSERT INTO DOCUMENT (DocType, DocNumber, IssueDate, FilePath, TechnicianID) VALUES (''Calibration certificate'', ''C-1'', ''2026-01-10'', N''/files/docs/1.pdf'', 4);', N'CK_DOCUMENT_Owner';
EXEC dbo.t_run 34, N'INSERT INTO DOCUMENT (DocType, DocNumber, IssueDate, FilePath, ReviewStatus, TechnicianID) VALUES (''ID card'', ''ID-1'', ''2020-01-10'', N''/files/docs/2.pdf'', ''Accepted'', 4);', N'CK_DOCUMENT_Review';
EXEC dbo.t_run 35, N'INSERT INTO TASK_NOTE (TaskID, NoteNo, NoteKind, Text, WrittenBy) VALUES (1, 0, ''Observation'', N''Κείμενο'', 4);', N'CK_TASK_NOTE_NoteNo';
EXEC dbo.t_run 36, N'INSERT INTO FIELD_TASK (TaskType, ScheduledFrom, ScheduledTo, TechnicianID, PremiseID) VALUES (''Installation'', ''2026-03-01 08:00'', ''2026-03-01 10:00'', 4, 1); INSERT INTO METER_INSTALLATION (InstalledAt, MeterID, PremiseID, TaskID) VALUES (''2026-03-01 09:00'', 1, 1, SCOPE_IDENTITY());', N'UX_METER_INSTALLATION_Open';
EXEC dbo.t_run 37, N'UPDATE METER_INSTALLATION SET RemovedAt = ''2026-02-20'' WHERE InstallationID = 1; INSERT INTO METER_INSTALLATION (InstalledAt, MeterID, PremiseID, TaskID) VALUES (''2026-03-01 09:00'', 1, 1, 1);', N'UQ_METER_INSTALLATION_TaskID';
EXEC dbo.t_run 38, N'UPDATE METER_INSTALLATION SET ConfirmationStatus = ''Confirmed'' WHERE InstallationID = 1;', N'CK_METER_INSTALLATION_Confirmation';
EXEC dbo.t_run 39, N'INSERT INTO METER_MODEL (Manufacturer, ModelName, MeterType, PhaseCount) VALUES (N''Kaifa'', N''MA309'', ''Split-Phase'', 2);', N'OK';
EXEC dbo.t_run 40, N'INSERT INTO METER_MODEL (Manufacturer, ModelName, MeterType, PhaseCount) VALUES (N''Kaifa'', N''MA310'', ''Three-Phase'', 4);', N'CK_METER_MODEL_PhaseCount';
EXEC dbo.t_run 41, N'UPDATE METER SET Status = ''Broken'' WHERE MeterID = 1;', N'CK_METER_Status';
EXEC dbo.t_run 42, N'INSERT INTO REMOTE_COMMAND (CommandType, Status, MeterID, RequestedBy) VALUES (''Load shed'', ''Sent'', 1, 6);', N'CK_REMOTE_COMMAND_ShedOrder';
EXEC dbo.t_run 43, N'INSERT INTO REMOTE_COMMAND (CommandType, Status, MeterID, RequestedBy, ApprovedBy) VALUES (''Disconnect'', ''Awaiting approval'', 1, 2, 2);', N'CK_REMOTE_COMMAND_Approval';
EXEC dbo.t_run 44, N'INSERT INTO REMOTE_COMMAND (CommandType, Status, Parameters, MeterID, RequestedBy) VALUES (''Firmware upgrade'', ''Awaiting approval'', N''version=2'', 1, 2);', N'CK_REMOTE_COMMAND_Parameters';
EXEC dbo.t_run 45, N'INSERT INTO COMMAND_ATTEMPT (CommandID, AttemptNo, AttemptAt, Outcome) VALUES (1, 2, ''2026-10-30 12:05'', ''ACK'');', N'CK_COMMAND_ATTEMPT_Response';
EXEC dbo.t_run 46, N'DELETE FROM METER_CONNECTED_PHASE WHERE MeterID = 1; DELETE FROM METER WHERE MeterID = 1;', N'REFERENCE constraint';
EXEC dbo.t_run 47, N'INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, ''1.8.0'', ''2026-10-30 12:07'', 1235, 1);', N'CK_READING_IntervalStart';
EXEC dbo.t_run 48, N'INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue, PacketID) VALUES (1, ''1.8.0'', ''2026-10-30 12:00'', 1235, 1);', N'PK_READING';
EXEC dbo.t_run 49, N'INSERT INTO READING (MeterID, ObisCode, IntervalStart) VALUES (1, ''1.8.0'', ''2026-10-30 12:15'');', N'CK_READING_Gap';
EXEC dbo.t_run 50, N'INSERT INTO READING (MeterID, ObisCode, IntervalStart, UsedValue, Status) VALUES (1, ''1.8.0'', ''2026-10-30 12:15'', 1236.1000, ''Estimated''); INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, NewValue, Origin, RuleID) VALUES (1, ''1.8.0'', ''2026-10-30 12:15'', 1, 1236.1000, ''Automatic estimate'', 1);', N'OK';
EXEC dbo.t_run 51, N'INSERT INTO READING (MeterID, ObisCode, IntervalStart, ReceivedValue) VALUES (1, ''1.8.0'', ''2026-10-30 12:30'', 1237);', N'CK_READING_Packet';
EXEC dbo.t_run 52, N'UPDATE READING SET Status = ''Suspect'', RunID = 1;', N'CK_READING_Final';
EXEC dbo.t_run 53, N'INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy, RuleID) VALUES (1, ''1.8.0'', ''2026-10-30 12:00'', 1, 1234.5678, 1234.6, ''Automatic estimate'', 7, 1);', N'CK_READING_EDIT_OriginActor';
EXEC dbo.t_run 54, N'INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy, Reason) VALUES (1, ''1.8.0'', ''2026-10-30 12:00'', 1, 1234.5678, 1234.6, ''Manual edit'', 7, N''Λάθος μετάδοσης'');', N'OK';
EXEC dbo.t_run 55, N'INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy) VALUES (1, ''1.8.0'', ''2026-10-30 12:00'', 1, 1234.5678, 1234.6, ''Manual edit'', 2);', N'FK_READING_EDIT_EDITED_BY';
EXEC dbo.t_run 56, N'INSERT INTO READING_EDIT (MeterID, ObisCode, IntervalStart, EditNo, OldValue, NewValue, Origin, EditedBy) VALUES (1, ''1.8.0'', ''2026-10-30 12:00'', 1, 1234.5678, 1234.6, ''Manual edit'', 7); DELETE FROM READING WHERE MeterID = 1; IF EXISTS (SELECT 1 FROM READING_EDIT) THROW 50001, ''edits left behind'', 1;', N'OK';
EXEC dbo.t_run 57, N'INSERT INTO TELEMETRY_PACKET (ReceivedNetworkID, RawPayload, IngestStatus, MeterID) VALUES (''NET-9999'', N''{}'', ''Unknown meter'', 1);', N'CK_TELEMETRY_PACKET_Meter';
EXEC dbo.t_run 58, N'INSERT INTO TELEMETRY_PACKET (ReceivedNetworkID, RawPayload, IngestStatus) VALUES (''NET-9999'', N''{}'', ''Unknown meter''); INSERT INTO EVENT (EventType, Severity, OccurredAt, PacketID) VALUES (''Unmatched packet'', ''Warning'', SYSUTCDATETIME(), SCOPE_IDENTITY());', N'OK';
EXEC dbo.t_run 59, N'INSERT INTO EVENT (EventType, Severity, OccurredAt) VALUES (''Unmatched packet'', ''Warning'', SYSUTCDATETIME());', N'CK_EVENT_Unmatched';
EXEC dbo.t_run 60, N'INSERT INTO TELEMETRY_PACKET (RawPayload, IngestStatus) VALUES (N''{bad'', ''Malformed'');', N'CK_TELEMETRY_PACKET_Error';
EXEC dbo.t_run 61, N'INSERT INTO GEOFENCE (Name, Level, MinLat, MinLon, MaxLat, MaxLon) VALUES (N''Λάθος'', 1, 35.3, 33.3, 35.2, 33.4);', N'CK_GEOFENCE_Rectangle';
EXEC dbo.t_run 62, N'INSERT INTO TRANSFORMER (Name, Latitude, Longitude, GeofenceID) VALUES (N''TR-002'', 35.16, 33.36, 1);', N'UQ_TRANSFORMER_GeofenceID';
EXEC dbo.t_run 63, N'INSERT INTO METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount) VALUES (1, ''1.8.0'', ''Month'', ''2026-10-15'', 300, 2976, 0);', N'CK_METER_AGGREGATE_Period';
EXEC dbo.t_run 64, N'INSERT INTO METER_AGGREGATE (MeterID, ObisCode, PeriodType, PeriodStart, SumValue, ReadingCount, EstimatedCount) VALUES (1, ''1.8.0'', ''Day'', ''2026-10-15'', 10, 96, 97);', N'CK_METER_AGGREGATE_Counts';
EXEC dbo.t_run 65, N'INSERT INTO GEOFENCE_AGGREGATE (GeofenceID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount) VALUES (1, ''1.8.0'', ''15 min'', ''2026-10-30 12:15'', 12.5, 1);', N'OK';
EXEC dbo.t_run 66, N'INSERT INTO GEOFENCE_AGGREGATE (GeofenceID, ObisCode, PeriodType, PeriodStart, SumValue, MeterCount) VALUES (1, ''1.8.0'', ''15 min'', ''2026-10-30 12:10'', 12.5, 1);', N'CK_GEOFENCE_AGGREGATE_Period';
EXEC dbo.t_run 67, N'INSERT INTO GEOFENCE_CURRENT_STATE (GeofenceID, ObisCode, RefInterval, SumValue, MeterCount) VALUES (1, ''32.7.0'', ''2026-10-30 12:00'', 230, 1);', N'CK_GEOFENCE_CURRENT_STATE_Code';
EXEC dbo.t_run 68, N'UPDATE GDPR_REQUEST SET Status = ''Approved'', PreApprovedBy = 2, PreApprovedAt = SYSUTCDATETIME(), DecidedBy = 2, DecidedByAdmin = 1, DecidedAt = SYSUTCDATETIME();', N'CK_GDPR_REQUEST_OneFinal';
EXEC dbo.t_run 69, N'UPDATE GDPR_REQUEST SET Status = ''Approved'', DecidedByAdmin = 1, DecidedAt = SYSUTCDATETIME();', N'CK_GDPR_REQUEST_Stage';
EXEC dbo.t_run 70, N'UPDATE GDPR_REQUEST SET Status = ''Pre-approved'', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt); UPDATE GDPR_REQUEST SET Status = ''Approved'', DecidedByAdmin = 1, DecidedAt = DATEADD(MINUTE, 2, SubmittedAt);', N'OK';
EXEC dbo.t_run 71, N'UPDATE GDPR_REQUEST SET Status = ''Approved'', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 5, SubmittedAt), DecidedBy = 2, DecidedAt = DATEADD(MINUTE, 1, SubmittedAt);', N'CK_GDPR_REQUEST_Order';
EXEC dbo.t_run 72, N'UPDATE GDPR_REQUEST SET Status = ''Rejected'', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt);', N'OK';
EXEC dbo.t_run 73, N'UPDATE GDPR_REQUEST SET Status = ''Pre-approved'', PreApprovedBy = 2, PreApprovedAt = DATEADD(MINUTE, 1, SubmittedAt); UPDATE GDPR_REQUEST SET Status = ''Rejected'', DecidedByAdmin = 1, DecidedAt = DATEADD(MINUTE, 2, SubmittedAt);', N'OK';
EXEC dbo.t_run 74, N'UPDATE GDPR_REQUEST SET Status = ''Rejected'';', N'CK_GDPR_REQUEST_Stage';
EXEC dbo.t_run 75, N'INSERT INTO AUDIT_LOG (ObjectType, ObjectID, Action) VALUES (''METER'', ''1'', ''Updated'');', N'CK_AUDIT_LOG_Actor';
EXEC dbo.t_run 76, N'INSERT INTO AUDIT_LOG (ObjectType, ObjectID, Action, ActorMechanism, OldState, NewState) VALUES (''READING'', ''1|1.8.0|2026-10-30T12:00'', ''VEE'', N''VEE run 1, rule 1'', ''Raw'', ''Validated'');', N'OK';
GO
SELECT n, expected, REPLACE(REPLACE(got, CHAR(13), ' '), CHAR(10), ' ') AS got FROM #r ORDER BY n FOR JSON PATH;
GO
DROP PROCEDURE dbo.t_run;
GO
