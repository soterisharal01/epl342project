-- MDMS-Cy, EPL342 Phase B: demo and analytic queries (Part 1: SELECTs, task REL-5; Part 2: one EXEC per main function of every role, task DAT-5).
-- Read-only. Run on a database that has create.sql, procs and the data sets loaded.
-- Run the whole file in SSMS, or one query at a time (select it and press Execute).
-- This file is NOT part of the automatic build (build_all.py); it is a hand-in file and an exam aid.
-- No GO in this file on purpose: the variables below live for the whole script.
-- Value meaning (decision B2): RAW_READING.ReceivedValue = what the meter sent (1.8.0 = counter);
-- VALIDATED_READING.Value = energy in that 15 minutes for cumulative codes. Aggregates sum Value.
-- OBIS: 1.8.0 = import energy, 2.8.0 = export energy.

SET NOCOUNT ON;

-- Parameters picked from the data so the file works on any loaded set.
DECLARE @Meter INT = (SELECT TOP 1 MeterID FROM VALIDATED_READING GROUP BY MeterID ORDER BY COUNT(*) DESC);
DECLARE @Day DATE = (SELECT MAX(IntervalStart) FROM VALIDATED_READING WHERE MeterID = @Meter);
DECLARE @MonthStart DATE = (SELECT MAX(PeriodStart) FROM METER_AGGREGATE WHERE PeriodType = 'Month');
DECLARE @AggDay DATE = (SELECT MAX(PeriodStart) FROM TRANSFORMER_AGGREGATE WHERE PeriodType = 'Day');
DECLARE @Supplier INT = (SELECT TOP 1 SupplierID FROM SUPPLY_CONTRACT WHERE EndDate IS NULL GROUP BY SupplierID ORDER BY COUNT(*) DESC);
DECLARE @AuditType VARCHAR(30), @AuditID VARCHAR(100);
SELECT TOP 1 @AuditType = ObjectType, @AuditID = ObjectID FROM AUDIT_LOG GROUP BY ObjectType, ObjectID ORDER BY COUNT(*) DESC;

-- =====================================================================================================
-- Q01. Consumers with their premises and the active supply contract.
-- Question: who holds which premise now, and with which supplier and tariff? (III.1.1, III.5.1)
-- =====================================================================================================
SELECT u.UserID, u.FirstName, u.LastName, p.PremiseID, p.Address, p.UsageType,
       s.Name AS Supplier, t.Name AS Tariff, c.StartDate AS ContractStart
FROM USER_ACCOUNT u
JOIN HOLDING h ON h.UserID = u.UserID AND h.EndDate IS NULL
JOIN PREMISE p ON p.PremiseID = h.PremiseID
LEFT JOIN SUPPLY_CONTRACT c ON c.PremiseID = p.PremiseID AND c.UserID = u.UserID AND c.EndDate IS NULL
LEFT JOIN SUPPLIER s ON s.SupplierID = c.SupplierID
LEFT JOIN TARIFF_TYPE t ON t.TariffTypeID = c.TariffTypeID
WHERE u.Role = 'Consumer'
ORDER BY u.LastName, u.FirstName, p.PremiseID;

-- =====================================================================================================
-- Q02. Premises per municipality and district, with usage type.
-- Question: how are the premises spread over the geography? (III.1.1)
-- =====================================================================================================
SELECT d.Name AS District, m.Name AS Municipality, p.UsageType, COUNT(*) AS Premises
FROM PREMISE p
JOIN PARISH pa ON pa.ParishID = p.ParishID
JOIN MUNICIPALITY m ON m.MunicipalityID = pa.MunicipalityID
JOIN DISTRICT d ON d.DistrictID = m.DistrictID
GROUP BY d.Name, m.Name, p.UsageType
ORDER BY d.Name, m.Name, p.UsageType;

-- =====================================================================================================
-- Q03. 15-minute readings of one meter for one day, import and export side by side.
-- Question: what did the meter measure each quarter of an hour? (III.1.2, III.3.2)
-- =====================================================================================================
SELECT i.IntervalStart,
       i.Value AS ImportKWh, i.Quality AS ImportQuality,
       e.Value AS ExportKWh, e.Quality AS ExportQuality
FROM VALIDATED_READING i
LEFT JOIN VALIDATED_READING e ON e.MeterID = i.MeterID AND e.ObisCode = '2.8.0' AND e.IntervalStart = i.IntervalStart
WHERE i.MeterID = @Meter AND i.ObisCode = '1.8.0'
  AND i.IntervalStart >= @Day AND i.IntervalStart < DATEADD(DAY, 1, @Day)
ORDER BY i.IntervalStart;

-- =====================================================================================================
-- Q04. Validated readings per VEE run and quality.
-- Question: what did each VEE run produce: measured, estimated or edited values? (III.3.2)
-- =====================================================================================================
SELECT r.RunID, r.PeriodFrom, r.PeriodTo, r.StartedAt, r.FinishedAt,
       v.Quality, COUNT(*) AS Readings
FROM VEE_RUN r
LEFT JOIN VALIDATED_READING v ON v.RunID = r.RunID
GROUP BY r.RunID, r.PeriodFrom, r.PeriodTo, r.StartedAt, r.FinishedAt, v.Quality
ORDER BY r.RunID, v.Quality;

-- =====================================================================================================
-- Q05. Raw readings by VEE status.
-- Question: how many raw readings are waiting for VEE, passed it, or are suspect? (III.3.2)
-- =====================================================================================================
SELECT VeeStatus, COUNT(*) AS RawReadings, MIN(IntervalStart) AS Oldest, MAX(IntervalStart) AS Newest
FROM RAW_READING
GROUP BY VeeStatus
ORDER BY VeeStatus;

-- =====================================================================================================
-- Q06. Suspect readings that the DSO has to look at.
-- Question: which raw readings failed validation, on which meter, and what range is allowed? (III.3.2)
-- =====================================================================================================
SELECT TOP 100 rr.MeterID, mt.SerialNumber, rr.ObisCode, o.MinValid, o.MaxValid,
       rr.IntervalStart, rr.ReceivedValue, rr.PacketID
FROM RAW_READING rr
JOIN METER mt ON mt.MeterID = rr.MeterID
JOIN OBIS_CODE o ON o.ObisCode = rr.ObisCode
WHERE rr.VeeStatus = 'Suspect'
ORDER BY rr.IntervalStart DESC, rr.MeterID;

-- =====================================================================================================
-- Q07. Edit history of readings (VEE estimates and manual fixes).
-- Question: who or which rule changed which value, from what to what, and why? (III.3.2)
-- =====================================================================================================
SELECT TOP 100 re.MeterID, re.ObisCode, re.IntervalStart, re.EditNo, re.Origin,
       re.OldValue, re.NewValue, re.EditedAt, re.Reason,
       COALESCE(u.Username, vr.RuleType) AS ByWhom
FROM READING_EDIT re
LEFT JOIN USER_ACCOUNT u ON u.UserID = re.EditedBy
LEFT JOIN VEE_RULE vr ON vr.RuleID = re.RuleID
ORDER BY re.EditedAt DESC, re.MeterID, re.IntervalStart, re.EditNo;

-- =====================================================================================================
-- Q08. Daily aggregates of one meter for the most recent month that has data.
-- Question: how much energy per day, and how many of the readings were estimated? (III.3.2)
-- =====================================================================================================
SELECT a.PeriodStart AS Day, a.ObisCode, a.SumValue, a.ReadingCount, a.EstimatedCount
FROM METER_AGGREGATE a
WHERE a.MeterID = @Meter AND a.PeriodType = 'Day'
  AND a.PeriodStart >= @MonthStart AND a.PeriodStart < DATEADD(MONTH, 1, @MonthStart)
ORDER BY a.PeriodStart, a.ObisCode;

-- =====================================================================================================
-- Q09. Monthly aggregate of every meter, import energy, with month-on-month change.
-- Question: how did each meter's monthly import change from the previous month? (III.3.2)
-- =====================================================================================================
SELECT a.MeterID, a.PeriodStart AS Month, a.SumValue AS ImportKWh,
       LAG(a.SumValue) OVER (PARTITION BY a.MeterID ORDER BY a.PeriodStart) AS PreviousMonthKWh,
       a.SumValue - LAG(a.SumValue) OVER (PARTITION BY a.MeterID ORDER BY a.PeriodStart) AS Change
FROM METER_AGGREGATE a
WHERE a.PeriodType = 'Month' AND a.ObisCode = '1.8.0'
ORDER BY a.MeterID, a.PeriodStart;

-- =====================================================================================================
-- Q10. Top 10 consumers by import energy in the most recent month.
-- Question: who consumed most? Follows meter -> open installation -> premise -> open holding. (III.1.2)
-- =====================================================================================================
SELECT TOP 10 u.UserID, u.FirstName, u.LastName, p.Address, SUM(a.SumValue) AS ImportKWh
FROM METER_AGGREGATE a
JOIN METER_INSTALLATION mi ON mi.MeterID = a.MeterID AND mi.RemovedAt IS NULL
JOIN PREMISE p ON p.PremiseID = mi.PremiseID
JOIN HOLDING h ON h.PremiseID = p.PremiseID AND h.EndDate IS NULL
JOIN USER_ACCOUNT u ON u.UserID = h.UserID
WHERE a.PeriodType = 'Month' AND a.ObisCode = '1.8.0' AND a.PeriodStart = @MonthStart
GROUP BY u.UserID, u.FirstName, u.LastName, p.Address
ORDER BY ImportKWh DESC;

-- =====================================================================================================
-- Q11. Monthly consumption against the active monthly thresholds.
-- Question: which premises are over the limit the consumer set? (III.1.2)
-- =====================================================================================================
SELECT ct.ThresholdID, ct.UserID, ct.PremiseID, ct.LimitKWh, SUM(a.SumValue) AS MonthKWh,
       SUM(a.SumValue) - ct.LimitKWh AS OverBy
FROM CONSUMPTION_THRESHOLD ct
JOIN METER_INSTALLATION mi ON mi.PremiseID = ct.PremiseID AND mi.RemovedAt IS NULL
JOIN METER_AGGREGATE a ON a.MeterID = mi.MeterID AND a.PeriodType = 'Month'
                      AND a.ObisCode = '1.8.0' AND a.PeriodStart = @MonthStart
WHERE ct.IsActive = 1 AND ct.PeriodType = 'Month'
GROUP BY ct.ThresholdID, ct.UserID, ct.PremiseID, ct.LimitKWh
HAVING SUM(a.SumValue) > ct.LimitKWh
ORDER BY OverBy DESC;

-- =====================================================================================================
-- Q12. Transformer tree with the number of meters and the stored aggregate of each leaf.
-- Question: how is the grid shaped, and what does each leaf carry on the latest aggregated day? (III.4.1)
-- Recursive CTE from the roots (ParentTransformerID IS NULL) down.
-- =====================================================================================================
WITH tree AS (
    SELECT t.TransformerID, t.Name, t.ParentTransformerID, 0 AS Lvl,
           CAST(RIGHT('0000' + CAST(t.TransformerID AS VARCHAR(10)), 6) AS VARCHAR(400)) AS SortPath
    FROM TRANSFORMER t
    WHERE t.ParentTransformerID IS NULL
    UNION ALL
    SELECT c.TransformerID, c.Name, c.ParentTransformerID, tree.Lvl + 1,
           CAST(tree.SortPath + '.' + RIGHT('0000' + CAST(c.TransformerID AS VARCHAR(10)), 6) AS VARCHAR(400))
    FROM TRANSFORMER c
    JOIN tree ON c.ParentTransformerID = tree.TransformerID
)
SELECT REPLICATE('    ', tree.Lvl) + tree.Name AS Node, tree.TransformerID, tree.Lvl,
       (SELECT COUNT(*) FROM METER m WHERE m.TransformerID = tree.TransformerID) AS Meters,
       ta.SumValue AS ImportKWhOnDay
FROM tree
LEFT JOIN TRANSFORMER_AGGREGATE ta ON ta.TransformerID = tree.TransformerID AND ta.ObisCode = '1.8.0'
                                  AND ta.PeriodType = 'Day' AND ta.PeriodStart = @AggDay
ORDER BY tree.SortPath
OPTION (MAXRECURSION 100);

-- =====================================================================================================
-- Q13. Totals at every level of the transformer tree (stored leaf aggregates summed upwards).
-- Question: what is the import energy of every transformer, leaf or not, on the latest day? (III.4.2, professor)
-- Only leaves are stored (trigger TR_TRANSFORMER_AGGREGATE_Leaf); higher levels are computed here.
-- anc pairs every transformer with each of its descendants (and itself).
-- =====================================================================================================
WITH anc AS (
    SELECT t.TransformerID AS AncestorID, t.TransformerID AS NodeID, 0 AS Depth
    FROM TRANSFORMER t
    UNION ALL
    SELECT anc.AncestorID, c.TransformerID, anc.Depth + 1
    FROM anc
    JOIN TRANSFORMER c ON c.ParentTransformerID = anc.NodeID
)
SELECT t.TransformerID, t.Name,
       CASE WHEN t.ParentTransformerID IS NULL THEN 'root'
            WHEN EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID) THEN 'inner'
            ELSE 'leaf' END AS NodeKind,
       COUNT(ta.TransformerID) AS LeavesWithData,
       SUM(ta.SumValue) AS ImportKWh
FROM anc
JOIN TRANSFORMER t ON t.TransformerID = anc.AncestorID
LEFT JOIN TRANSFORMER_AGGREGATE ta ON ta.TransformerID = anc.NodeID AND ta.ObisCode = '1.8.0'
                                  AND ta.PeriodType = 'Day' AND ta.PeriodStart = @AggDay
GROUP BY t.TransformerID, t.Name, t.ParentTransformerID
ORDER BY t.TransformerID
OPTION (MAXRECURSION 100);

-- =====================================================================================================
-- Q14. Total per tree level (depth from the root).
-- Question: how much energy flows at each level of the grid on the latest day? (III.4.2)
-- =====================================================================================================
WITH tree AS (
    SELECT t.TransformerID, 0 AS Lvl FROM TRANSFORMER t WHERE t.ParentTransformerID IS NULL
    UNION ALL
    SELECT c.TransformerID, tree.Lvl + 1 FROM TRANSFORMER c JOIN tree ON c.ParentTransformerID = tree.TransformerID
),
anc AS (
    SELECT t.TransformerID AS AncestorID, t.TransformerID AS NodeID FROM TRANSFORMER t
    UNION ALL
    SELECT anc.AncestorID, c.TransformerID FROM anc JOIN TRANSFORMER c ON c.ParentTransformerID = anc.NodeID
)
SELECT tree.Lvl, COUNT(DISTINCT tree.TransformerID) AS Transformers, SUM(ta.SumValue) AS ImportKWh
FROM tree
JOIN anc ON anc.AncestorID = tree.TransformerID
LEFT JOIN TRANSFORMER_AGGREGATE ta ON ta.TransformerID = anc.NodeID AND ta.ObisCode = '1.8.0'
                                  AND ta.PeriodType = 'Day' AND ta.PeriodStart = @AggDay
GROUP BY tree.Lvl
ORDER BY tree.Lvl
OPTION (MAXRECURSION 100);

-- =====================================================================================================
-- Q15. Current state of every leaf transformer (latest 15 minutes, import and export).
-- Question: what is the grid doing right now? (III.4.2)
-- =====================================================================================================
SELECT t.TransformerID, t.Name,
       i.RefInterval, i.SumValue AS ImportKWh, i.MeterCount AS ImportMeters,
       e.SumValue AS ExportKWh, e.ComputedAt
FROM TRANSFORMER t
LEFT JOIN TRANSFORMER_CURRENT_STATE i ON i.TransformerID = t.TransformerID AND i.ObisCode = '1.8.0'
LEFT JOIN TRANSFORMER_CURRENT_STATE e ON e.TransformerID = t.TransformerID AND e.ObisCode = '2.8.0'
WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER k WHERE k.ParentTransformerID = t.TransformerID)
ORDER BY t.TransformerID;

-- =====================================================================================================
-- Q16. Day-Ahead data of one supplier per transformer.
-- Question: how much energy do the supplier's customers take under each leaf transformer on the latest
-- day? Only the supplier's own customers (open supply contracts), never other suppliers'. (III.5.1-5.2)
-- =====================================================================================================
SELECT s.Name AS Supplier, t.TransformerID, t.Name AS Transformer,
       COUNT(DISTINCT mt.MeterID) AS Meters, SUM(a.SumValue) AS ImportKWh
FROM SUPPLY_CONTRACT sc
JOIN SUPPLIER s ON s.SupplierID = sc.SupplierID
JOIN METER_INSTALLATION mi ON mi.PremiseID = sc.PremiseID AND mi.RemovedAt IS NULL
JOIN METER mt ON mt.MeterID = mi.MeterID
JOIN TRANSFORMER t ON t.TransformerID = mt.TransformerID
JOIN METER_AGGREGATE a ON a.MeterID = mt.MeterID AND a.ObisCode = '1.8.0'
                      AND a.PeriodType = 'Day' AND a.PeriodStart = @AggDay
WHERE sc.EndDate IS NULL AND sc.SupplierID = @Supplier
GROUP BY s.Name, t.TransformerID, t.Name
ORDER BY ImportKWh DESC;

-- =====================================================================================================
-- Q17. Intraday provisional energy from raw readings, using LAG.
-- Question: what was consumed in each 15 minutes of the day before VEE has finalised it? (III.5.2)
-- Raw 1.8.0 is a counter, so the energy is the difference from the previous interval (decision B2).
-- =====================================================================================================
SELECT rr.MeterID, rr.IntervalStart, rr.ReceivedValue AS CounterKWh,
       rr.ReceivedValue - LAG(rr.ReceivedValue) OVER (PARTITION BY rr.MeterID ORDER BY rr.IntervalStart) AS ProvisionalKWh,
       rr.VeeStatus
FROM RAW_READING rr
WHERE rr.ObisCode = '1.8.0' AND rr.MeterID = @Meter
  AND rr.IntervalStart >= DATEADD(DAY, -1, @Day) AND rr.IntervalStart < DATEADD(DAY, 1, @Day)
ORDER BY rr.IntervalStart;

-- =====================================================================================================
-- Q18. Telemetry ingest results and open events.
-- Question: how many packets were accepted or rejected, and which problems are still open? (III.3.1)
-- =====================================================================================================
SELECT tp.IngestStatus, COUNT(*) AS Packets, MIN(tp.ReceivedAt) AS First, MAX(tp.ReceivedAt) AS Last
FROM TELEMETRY_PACKET tp
GROUP BY tp.IngestStatus
ORDER BY Packets DESC;

SELECT ev.EventType, ev.Severity, ev.Status, COUNT(*) AS Events
FROM EVENT ev
GROUP BY ev.EventType, ev.Severity, ev.Status
ORDER BY ev.Severity, ev.EventType, ev.Status;

-- =====================================================================================================
-- Q19. Technicians with documents waiting for review.
-- Question: which technicians have Pending documents, and since when are they waiting? (III.2.1)
-- =====================================================================================================
SELECT u.UserID, u.FirstName, u.LastName, u.ApprovalStatus,
       COUNT(*) AS PendingDocuments, MIN(d.IssueDate) AS OldestIssueDate
FROM USER_ACCOUNT u
JOIN DOCUMENT d ON d.TechnicianID = u.UserID AND d.ReviewStatus = 'Pending'
WHERE u.Role = 'Technician'
GROUP BY u.UserID, u.FirstName, u.LastName, u.ApprovalStatus
ORDER BY PendingDocuments DESC, u.LastName;

-- =====================================================================================================
-- Q20. Open field tasks per technician.
-- Question: how much work does each technician have that is not done or cancelled? (III.2.2)
-- =====================================================================================================
SELECT u.UserID, u.FirstName, u.LastName,
       SUM(CASE WHEN ft.Status = 'Assigned' THEN 1 ELSE 0 END) AS Assigned,
       SUM(CASE WHEN ft.Status = 'Accepted' THEN 1 ELSE 0 END) AS Accepted,
       MIN(ft.ScheduledFrom) AS NextScheduled
FROM USER_ACCOUNT u
JOIN FIELD_TASK ft ON ft.TechnicianID = u.UserID AND ft.Status IN ('Assigned', 'Accepted')
WHERE u.Role = 'Technician'
GROUP BY u.UserID, u.FirstName, u.LastName
ORDER BY u.LastName, u.FirstName;

-- =====================================================================================================
-- Q21. Meter installations waiting for the operator's confirmation.
-- Question: which meters were installed by a technician and are still not Active? (III.2.3)
-- =====================================================================================================
SELECT mi.InstallationID, mt.MeterID, mt.SerialNumber, mt.Status AS MeterStatus,
       p.Address, mi.InstalledAt, ft.TechnicianID
FROM METER_INSTALLATION mi
JOIN METER mt ON mt.MeterID = mi.MeterID
JOIN PREMISE p ON p.PremiseID = mi.PremiseID
JOIN FIELD_TASK ft ON ft.TaskID = mi.TaskID
WHERE mi.ConfirmationStatus = 'Pending'
ORDER BY mi.InstalledAt;

-- =====================================================================================================
-- Q22. GDPR requests by stage.
-- Question: how many erasure requests are in each stage of the workflow, and how old is the oldest? (III.1.4)
-- =====================================================================================================
SELECT g.Status, COUNT(*) AS Requests, MIN(g.SubmittedAt) AS OldestSubmitted,
       SUM(CASE WHEN g.DecidedByAdmin IS NOT NULL THEN 1 ELSE 0 END) AS DecidedByAdmin
FROM GDPR_REQUEST g
GROUP BY g.Status
ORDER BY CASE g.Status WHEN 'Submitted' THEN 1 WHEN 'Under review' THEN 2 WHEN 'Pre-approved' THEN 3
                       WHEN 'Approved' THEN 4 WHEN 'Rejected' THEN 5 ELSE 6 END;

-- =====================================================================================================
-- Q23. Audit trail of one object (the most logged object in the data).
-- Question: who did what to this object, when, and what changed? (General: AUDIT_LOG, III.1.4)
-- =====================================================================================================
SELECT al.LogID, al.LoggedAt, al.ObjectType, al.ObjectID, al.Action,
       COALESCE(u.Username, al.ActorMechanism) AS Actor, al.OldState, al.NewState, al.ResultComment
FROM AUDIT_LOG al
LEFT JOIN USER_ACCOUNT u ON u.UserID = al.PerformedBy
WHERE al.ObjectType = @AuditType AND al.ObjectID = @AuditID
ORDER BY al.LoggedAt, al.LogID;

-- =====================================================================================================
-- Q24. Load-shed orders with the status of their commands.
-- Question: for each TSO order, how many meter commands were sent, acknowledged or failed? (II.D, III.4)
-- =====================================================================================================
SELECT lso.ShedOrderID, lso.CreatedAt, lso.Status AS OrderStatus, t.Name AS Transformer, u.Username AS OrderedBy,
       COUNT(rc.CommandID) AS Commands,
       SUM(CASE WHEN rc.Status = 'Acknowledged' THEN 1 ELSE 0 END) AS Acknowledged,
       SUM(CASE WHEN rc.Status = 'Sent' THEN 1 ELSE 0 END) AS Sent,
       SUM(CASE WHEN rc.Status = 'Failed' THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN rc.Status NOT IN ('Acknowledged', 'Sent', 'Failed') THEN 1 ELSE 0 END) AS Other
FROM LOAD_SHED_ORDER lso
JOIN TRANSFORMER t ON t.TransformerID = lso.TransformerID
JOIN USER_ACCOUNT u ON u.UserID = lso.OrderedBy
LEFT JOIN REMOTE_COMMAND rc ON rc.ShedOrderID = lso.ShedOrderID
GROUP BY lso.ShedOrderID, lso.CreatedAt, lso.Status, t.Name, u.Username
ORDER BY lso.CreatedAt DESC;

-- =====================================================================================================
-- Q25. Remote commands with the number of attempts and the last outcome.
-- Question: how many tries did each command need before an ACK? (III.2.4)
-- =====================================================================================================
SELECT rc.CommandID, rc.CommandType, rc.Status, rc.MeterID,
       COUNT(ca.AttemptNo) AS Attempts,
       MAX(CASE WHEN ca.Outcome = 'ACK' THEN ca.AttemptNo END) AS AckOnAttempt
FROM REMOTE_COMMAND rc
LEFT JOIN COMMAND_ATTEMPT ca ON ca.CommandID = rc.CommandID
GROUP BY rc.CommandID, rc.CommandType, rc.Status, rc.MeterID
ORDER BY rc.CommandID;

-- =====================================================================================================
-- Q26. Invoices with the unpaid amount.
-- Question: which invoices are not fully paid, and how much is still due? (III.1.3)
-- =====================================================================================================
SELECT i.InvoiceID, i.UserID, u.LastName, i.IssueDate, i.Amount,
       COALESCE(SUM(p.Amount), 0) AS Paid,
       i.Amount - COALESCE(SUM(p.Amount), 0) AS Unpaid
FROM INVOICE i
JOIN USER_ACCOUNT u ON u.UserID = i.UserID
LEFT JOIN PAYMENT p ON p.InvoiceID = i.InvoiceID
WHERE i.Status IN ('Issued', 'Partially paid')
GROUP BY i.InvoiceID, i.UserID, u.LastName, i.IssueDate, i.Amount
HAVING i.Amount - COALESCE(SUM(p.Amount), 0) > 0
ORDER BY Unpaid DESC;

-- =====================================================================================================
-- Q27. Aggregator portfolios and their premises.
-- Question: how many premises does each portfolio hold now, and how much did they use last month? (III.5.1)
-- =====================================================================================================
SELECT ag.Name AS Aggregator, po.Name AS Portfolio,
       COUNT(DISTINCT inc.PremiseID) AS Premises, SUM(a.SumValue) AS ImportKWhLastMonth
FROM PORTFOLIO po
JOIN AGGREGATOR ag ON ag.AggregatorID = po.AggregatorID
LEFT JOIN INCLUDES inc ON inc.PortfolioID = po.PortfolioID AND inc.EndDate IS NULL
LEFT JOIN METER_INSTALLATION mi ON mi.PremiseID = inc.PremiseID AND mi.RemovedAt IS NULL
LEFT JOIN METER_AGGREGATE a ON a.MeterID = mi.MeterID AND a.ObisCode = '1.8.0'
                           AND a.PeriodType = 'Month' AND a.PeriodStart = @MonthStart
GROUP BY ag.Name, po.Name
ORDER BY ag.Name, po.Name;

-- #####################################################################################################
-- PART 2 (task DAT-5). One EXEC for every main function of every role, plus the analytics.
-- These are the same stored procedures the PHP pages call, so the examiner sees exactly what each role sees.
-- Only procedures that READ are called here: running the whole file never changes the data.
-- The functions that change data (register, pay, submit, ingest, VEE, approve, load shed, ...) are run
-- with one call that succeeds and one that must be refused in sql/tests/test_<area>.sql.
-- Each block PRINTs its title, so the Messages tab shows which result grid belongs to which call.
-- A refused call (for example a role with no data on a small set) prints the reason and the file continues.
-- #####################################################################################################

-- Users of every role, picked from the data (the first active user of each role).
DECLARE @Admin INT      = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'Admin'      AND AccountStatus = 'Active');
DECLARE @Operator INT   = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'Operator'   AND AccountStatus = 'Active');
DECLARE @Tech INT       = (SELECT MIN(t.TechnicianID) FROM FIELD_TASK t JOIN USER_ACCOUNT u ON u.UserID = t.TechnicianID
                           WHERE u.AccountStatus = 'Active' AND u.ApprovalStatus = 'Approved');
DECLARE @DSO INT        = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'DSO'        AND AccountStatus = 'Active');
DECLARE @TSO INT        = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'TSO'        AND AccountStatus = 'Active');
DECLARE @SupplierU INT  = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'Supplier'   AND AccountStatus = 'Active');
DECLARE @AggregatorU INT = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'Aggregator' AND AccountStatus = 'Active');
-- The consumer who holds the premise where @Meter (the meter with most readings) is installed now.
DECLARE @Consumer INT   = (SELECT TOP 1 h.UserID FROM METER_INSTALLATION mi
                           JOIN HOLDING h ON h.PremiseID = mi.PremiseID AND h.EndDate IS NULL
                           WHERE mi.MeterID = @Meter AND mi.RemovedAt IS NULL ORDER BY h.StartDate DESC);
DECLARE @Task INT       = (SELECT MAX(TaskID) FROM FIELD_TASK WHERE TechnicianID = @Tech);
DECLARE @Portfolio INT  = (SELECT MIN(p.PortfolioID) FROM PORTFOLIO p JOIN USER_ACCOUNT u ON u.AggregatorID = p.AggregatorID
                           WHERE u.UserID = @AggregatorU);
DECLARE @Root INT       = (SELECT MIN(TransformerID) FROM TRANSFORMER WHERE ParentTransformerID IS NULL);
DECLARE @PendingTech INT = (SELECT MIN(UserID) FROM USER_ACCOUNT WHERE Role = 'Technician' AND ApprovalStatus = 'Pending');
DECLARE @DayFrom DATETIME2(0) = CAST(@Day AS DATETIME2(0)), @DayTo DATETIME2(0) = DATEADD(DAY, 1, CAST(@Day AS DATETIME2(0)));
DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@Day), 1, 1);
DECLARE @Lat DECIMAL(9,6), @Lon DECIMAL(9,6);
SELECT TOP 1 @Lat = (g.MinLat + g.MaxLat) / 2, @Lon = (g.MinLon + g.MaxLon) / 2
FROM TRANSFORMER t JOIN GEOFENCE g ON g.GeofenceID = t.GeofenceID
WHERE NOT EXISTS (SELECT 1 FROM TRANSFORMER c WHERE c.ParentTransformerID = t.TransformerID) ORDER BY t.TransformerID;

-- =====================================================================================================
-- E01-E08. CONSUMER (III.1.1-III.1.4)
-- =====================================================================================================
PRINT '--- E01 Consumer: my premises (III.1.1)';
BEGIN TRY EXEC sp_consumer_list_premises @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E02 Consumer: my meters';
BEGIN TRY EXEC sp_consumer_list_meters @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E03 Consumer: 15-minute readings of one day (III.1.2; current month free, older months need a purchase)';
BEGIN TRY EXEC sp_consumer_readings @Consumer, @Meter, @DayFrom, @DayTo; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E04 Consumer: monthly history from the aggregates (III.1.2)';
BEGIN TRY EXEC sp_consumer_history @Consumer, @Meter, 'Month', @YearStart, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E05 Consumer: thresholds and power-quality events (III.1.2)';
BEGIN TRY EXEC sp_consumer_list_thresholds @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_quality_events @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E06 Consumer: check/fault requests and their history (III.1.3)';
BEGIN TRY EXEC sp_consumer_list_requests @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E07 Consumer: invoices and payments (III.1.3)';
BEGIN TRY EXEC sp_consumer_list_invoices @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_consumer_list_payments @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E08 Consumer: my GDPR requests (III.1.4)';
BEGIN TRY EXEC sp_gdpr_list @Consumer; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================================================
-- E09-E12. TECHNICIAN (III.2.1-III.2.2)
-- =====================================================================================================
PRINT '--- E09 Technician: my documents (III.2.1)';
BEGIN TRY EXEC sp_tech_list_documents @Tech; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E10 Technician: my availability (III.2.1)';
BEGIN TRY EXEC sp_tech_list_availability @Tech; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E11 Technician: my field tasks (III.2.2)';
BEGIN TRY EXEC sp_tech_list_tasks @Tech; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E12 Technician: one task with its notes (III.2.2)';
BEGIN TRY EXEC sp_task_get @Tech, @Task; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_notes @Tech, @Task; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================================================
-- E13-E17. OPERATOR (III.2.1-III.2.2, III.1.4, catalogs)
-- =====================================================================================================
PRINT '--- E13 Operator: technicians waiting for approval, and the documents of one (III.2.1)';
BEGIN TRY EXEC sp_operator_list_pending_technicians @Operator; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
IF @PendingTech IS NOT NULL
BEGIN TRY EXEC sp_operator_list_technician_documents @Operator, @PendingTech; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E14 Operator: consumer requests waiting for a task, and approved technicians (III.2.2)';
BEGIN TRY EXEC sp_task_list_requests @Operator; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_task_list_technicians @Operator; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E15 Operator: all field tasks (III.2.2)';
BEGIN TRY EXEC sp_task_list @Operator; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E16 Operator: GDPR requests to pre-approve (III.1.4)';
BEGIN TRY EXEC sp_gdpr_list @Operator; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E17 Operator catalogs: meter models, service fees, tariffs';
EXEC sp_ref_list_meter_models;
EXEC sp_ref_list_service_types;
EXEC sp_ref_list_tariff_types;

-- =====================================================================================================
-- E18-E21. ADMIN (users, audit log, GDPR decision, retention)
-- =====================================================================================================
PRINT '--- E18 Admin: every user account';
BEGIN TRY EXEC sp_admin_list_users @Admin; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E19 Admin: audit log (500 newest)';
BEGIN TRY EXEC sp_admin_audit_log @Admin; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E20 Admin: GDPR requests to decide (III.1.4)';
BEGIN TRY EXEC sp_gdpr_list @Admin; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E21 Admin: retention preview, what a purge would delete now (III.1.4)';
BEGIN TRY EXEC sp_retention_preview @Admin; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================================================
-- E22-E27. DSO (III.3.1-III.3.2, analytics II.C)
-- =====================================================================================================
PRINT '--- E22 DSO: latest telemetry packets (III.3.1)';
BEGIN TRY EXEC sp_dso_list_packets @DSO, 20; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E23 DSO: VEE runs and suspect readings (III.3.2)';
BEGIN TRY EXEC sp_dso_list_runs @DSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_dso_list_suspect @DSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E24 DSO: daily aggregates of one meter (III.3.2)';
BEGIN TRY EXEC sp_dso_list_aggregates @DSO, @Meter, 'Day', @YearStart, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E25 DSO: monthly aggregates of the leaf transformers (III.3.2, professor: leaves only)';
BEGIN TRY EXEC sp_dso_list_transformer_aggregates @DSO, NULL, 'Month', @YearStart, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E26 Analytics: grid events (under/over-voltage, phase imbalance, suspected theft) (II.C)';
BEGIN TRY EXEC sp_dso_list_events @DSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E27 Analytics: technical losses per leaf transformer, last 7 days of data (II.C)';
DECLARE @LossFrom DATE = DATEADD(DAY, -6, @Day);
BEGIN TRY EXEC sp_dso_losses_report @DSO, @LossFrom, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================================================
-- E28-E33. TSO (III.4.1-III.4.2, professor's aggregates per tree level, II.D)
-- =====================================================================================================
PRINT '--- E28 TSO: the transformer tree from the root (recursive CTE) (III.4.1)';
BEGIN TRY EXEC sp_tso_tree @TSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E29 TSO: which leaf transformer covers a point (III.4.1)';
BEGIN TRY EXEC sp_tso_locate @TSO, @Lat, @Lon; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E30 TSO: current state of every transformer, as last refreshed (III.4.2)';
BEGIN TRY EXEC sp_tso_current_state @TSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E31 Analytics: aggregates at the ROOT of the tree, per month and per quarter (professor)';
BEGIN TRY EXEC sp_tso_aggregates @TSO, @Root, 'Month', @YearStart, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_tso_aggregates @TSO, @Root, 'Quarter', @YearStart, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E32 TSO: past load-shedding orders (II.D)';
BEGIN TRY EXEC sp_tso_list_shed_orders @TSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E33 TSO: data behind the map (bonus)';
BEGIN TRY EXEC sp_tso_map_data @TSO; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;

-- =====================================================================================================
-- E34-E37. SUPPLIER and AGGREGATOR (III.5.1-III.5.2)
-- =====================================================================================================
PRINT '--- E34 Supplier: Day-Ahead totals per day, and per day and transformer (validated data only) (III.5.2)';
BEGIN TRY EXEC sp_supplier_totals @SupplierU, 'Day', @LossFrom, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC sp_supplier_aggregates @SupplierU, 'Day', @LossFrom, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E35 Supplier: Intraday provisional values of one day, from raw readings (III.5.2)';
BEGIN TRY EXEC sp_market_intraday @SupplierU, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E36 Aggregator: my portfolios and the premises of one (III.5.1)';
BEGIN TRY EXEC sp_aggregator_list_portfolios @AggregatorU; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
IF @Portfolio IS NOT NULL
BEGIN TRY EXEC sp_aggregator_list_portfolio_premises @AggregatorU, @Portfolio; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
PRINT '--- E37 Aggregator: Day-Ahead totals of the portfolio premises (III.5.1)';
BEGIN TRY EXEC sp_supplier_totals @AggregatorU, 'Day', @LossFrom, @Day; END TRY BEGIN CATCH PRINT 'refused: ' + ERROR_MESSAGE(); END CATCH;
