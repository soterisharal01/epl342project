-- verify_release.sql (REL-1): read-only checks after the release build. Changes nothing.
-- Run in SSMS or: run_sql.ps1 -File sql\tools\verify_release.sql   (every line must say OK)
-- Large-set rows have IDs >= 100000 (exact counts); base rows are counted separately.

-- 1. Space: the data file must stay under 27 MB (the department cap).
SELECT CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024.0 AS DECIMAL(9,2)) AS UsedMB,
       CAST(SUM(size) * 8 / 1024.0 AS DECIMAL(9,2)) AS AllocatedMB,
       CASE WHEN SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024.0 < 27 THEN 'OK under 27 MB' ELSE 'FAIL over the cap' END AS Verdict
FROM sys.database_files WHERE type_desc = 'ROWS';

-- 2. Query Store must be off.
SELECT CASE WHEN actual_state_desc = 'OFF' THEN 'OK query store off' ELSE 'FAIL query store ' + actual_state_desc END AS QueryStore
FROM sys.database_query_store_options;

-- 3. Row counts: expected = rows of the large set (docs/13-data-sets.md).
SELECT t.Name, t.Expected, t.Actual, CASE WHEN t.Actual = t.Expected THEN 'OK' ELSE 'FAIL' END AS Verdict
FROM (VALUES
  ('USER_ACCOUNT (large)',          1025,  (SELECT COUNT(*) FROM USER_ACCOUNT WHERE UserID >= 100000)),
  ('PREMISE (large)',               1100,  (SELECT COUNT(*) FROM PREMISE WHERE PremiseID >= 100000)),
  ('METER (large)',                 1000,  (SELECT COUNT(*) FROM METER WHERE MeterID >= 100000)),
  ('INVOICE (large)',               2400,  (SELECT COUNT(*) FROM INVOICE WHERE InvoiceID >= 100000)),
  ('PAYMENT (large)',               1600,  (SELECT COUNT(*) FROM PAYMENT WHERE PaymentID >= 100000)),
  ('RAW_READING (large meters)',   30912,  (SELECT COUNT(*) FROM RAW_READING WHERE MeterID >= 100000)),
  ('VALIDATED_READING (large)',    30912,  (SELECT COUNT(*) FROM VALIDATED_READING WHERE MeterID >= 100000)),
  ('METER_AGGREGATE (large)',        322,  (SELECT COUNT(*) FROM METER_AGGREGATE WHERE MeterID >= 100000)),
  ('TELEMETRY_PACKET (large)',       280,  (SELECT COUNT(*) FROM TELEMETRY_PACKET WHERE PacketID >= 100000)),
  ('Base users (admin..aggregator1)', 10,  (SELECT COUNT(*) FROM USER_ACCOUNT WHERE UserID < 1000))
) AS t(Name, Expected, Actual);

-- 4. The three indexes of indexes.sql exist.
SELECT n.Name, CASE WHEN i.name IS NULL THEN 'FAIL missing' ELSE 'OK' END AS Verdict
FROM (VALUES ('IX_INVOICE_User_IssueDate'), ('IX_FIELD_TASK_Technician_Status'), ('IX_RAW_READING_Pending')) AS n(Name)
LEFT JOIN sys.indexes i ON i.name = n.Name;

-- 5. Demo users exist (one per role).
SELECT u.Username, CASE WHEN a.UserID IS NULL THEN 'FAIL missing' ELSE 'OK ' + a.Role END AS Verdict
FROM (VALUES ('consumer1'),('operator'),('tech1'),('dso1'),('tso1'),('supplier1'),('aggregator1'),('admin')) AS u(Username)
LEFT JOIN USER_ACCOUNT a ON a.Username = u.Username;
