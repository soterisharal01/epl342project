-- =====================================================================
-- indexes.sql : PRF-1/2/3. Τα ευρετήρια της εφαρμογής (πέρα από PK/UNIQUE/UX_* του create.sql).
-- Idempotent: ξανατρέχει χωρίς λάθος. Φιλτραρισμένα ευρετήρια θέλουν QUOTED_IDENTIFIER ON.
-- Μέθοδος μέτρησης: sql/perf/before_after.sql, αποτελέσματα στο docs/14-indexes-and-performance.md.
-- =====================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ---------------------------------------------------------------------
-- PRF-3: IX_RAW_READING_Pending  (φιλτραρισμένο)
-- Ποιο query: sp_dso_run_vee, βήμα 1:
--     FROM RAW_READING WITH (UPDLOCK, READPAST)
--     WHERE VeeStatus = 'Pending' AND IntervalStart >= @From AND IntervalStart < @To
-- Γιατί δεν αρκεί το PK: το PK είναι (MeterID, ObisCode, IntervalStart). Το query δεν δίνει MeterID,
--   άρα το PK δεν μπορεί να κάνει seek: διαβάζει ΟΛΟΝ τον πίνακα (~64.000 γραμμές και αυξάνεται)
--   για να βρει τις λίγες Pending.
-- Γιατί αυτή η σειρά στηλών: το πρώτο κλειδί είναι το εύρος IntervalStart (range seek), μετά
--   MeterID, ObisCode. Το PK (MeterID, ObisCode, IntervalStart) προστίθεται αυτόματα σε κάθε
--   μη-clustered ευρετήριο, άρα το ευρετήριο ταυτίζεται με την ταξινόμηση που θέλει το VEE.
-- INCLUDE ReceivedValue: το query επιστρέφει και την τιμή, άρα δεν χρειάζεται key lookup.
-- Φίλτρο WHERE VeeStatus = 'Pending': το ευρετήριο περιέχει ΜΟΝΟ τις Pending. Όταν το VEE τις
--   επικυρώνει, βγαίνουν από το ευρετήριο, που μένει μικρό. Μικρό = λίγες σελίδες, φτηνή συντήρηση.
-- Αναμενόμενη αλλαγή πλάνου: Clustered Index Scan (όλος ο πίνακας) -> Index Seek στο φιλτραρισμένο.
-- Σημείωση: το query πρέπει να έχει το κατηγόρημα VeeStatus = 'Pending' ως σταθερά (το έχει).
-- ---------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RAW_READING_Pending' AND object_id = OBJECT_ID('RAW_READING'))
    CREATE NONCLUSTERED INDEX IX_RAW_READING_Pending
        ON RAW_READING (IntervalStart, MeterID, ObisCode)
        INCLUDE (ReceivedValue)
        WHERE VeeStatus = 'Pending';
GO

-- ---------------------------------------------------------------------
-- PRF-2: IX_FIELD_TASK_Technician_Status
-- Ποιο query: sp_tech_list_tasks:
--     WHERE t.TechnicianID = @UserID AND (@Status IS NULL OR t.Status = @Status)
--     ORDER BY t.ScheduledFrom DESC, t.TaskID DESC
-- Γιατί δεν αρκεί το PK: το PK είναι (TaskID). Το FK TechnicianID δεν δημιουργεί ευρετήριο στο SQL
--   Server, άρα κάθε λίστα εργασιών ενός τεχνικού σκανάρει όλο το FIELD_TASK.
-- Κλειδί (TechnicianID, Status): equality στον τεχνικό και, όταν δίνεται, στην κατάσταση.
--   Η ταξινόμηση ScheduledFrom γίνεται σε λίγες γραμμές (ένας τεχνικός), όχι σε όλο τον πίνακα.
-- INCLUDE: οι στήλες που διαβάζει η λίστα από το FIELD_TASK (TaskType, ScheduledFrom/To, PremiseID,
--   MeterID, RequestID), ώστε να μην γίνεται key lookup ανά γραμμή.
-- Αναμενόμενη αλλαγή: Clustered Index Scan -> Index Seek (TechnicianID = @UserID), χωρίς Key Lookup.
-- ---------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FIELD_TASK_Technician_Status' AND object_id = OBJECT_ID('FIELD_TASK'))
    CREATE NONCLUSTERED INDEX IX_FIELD_TASK_Technician_Status
        ON FIELD_TASK (TechnicianID, Status)
        INCLUDE (TaskType, ScheduledFrom, ScheduledTo, PremiseID, MeterID, RequestID);
GO

-- ---------------------------------------------------------------------
-- PRF-1: IX_INVOICE_User_IssueDate
-- Ποιο query: sp_consumer_list_invoices:
--     WHERE i.UserID = @UserID [AND YEAR(i.IssueDate) = @Year]
--     ORDER BY i.IssueDate DESC, i.InvoiceID DESC
-- Γιατί δεν αρκεί το PK: το PK είναι (InvoiceID). Το FK UserID δεν έχει ευρετήριο, άρα η σελίδα
--   λογαριασμών ενός καταναλωτή σκανάρει και ταξινομεί όλα τα τιμολόγια (~4.500 και αυξάνονται).
-- Κλειδί (UserID, IssueDate DESC): seek στον χρήστη και οι γραμμές βγαίνουν ήδη ταξινομημένες
--   κατά IssueDate φθίνουσα (το InvoiceID DESC ακολουθεί, ως κλειδί του clustered), άρα
--   χωρίς Sort operator.
-- INCLUDE: Amount, Status, PeriodFrom, PeriodTo, ContractID = οι στήλες που επιστρέφει το query.
-- Αναμενόμενη αλλαγή: Clustered Index Scan + Sort -> Index Seek (UserID), χωρίς Sort και Key Lookup.
-- ---------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_INVOICE_User_IssueDate' AND object_id = OBJECT_ID('INVOICE'))
    CREATE NONCLUSTERED INDEX IX_INVOICE_User_IssueDate
        ON INVOICE (UserID, IssueDate DESC)
        INCLUDE (Amount, Status, PeriodFrom, PeriodTo, ContractID);
GO
-- Δεν προσθέτουμε άλλα: η sp_dso_list_packets ταξινομεί κατά PacketID (PK, ήδη ευρετήριο).
