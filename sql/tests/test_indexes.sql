-- =====================================================================
-- test_indexes.sql : PRF-1/2/3. Υπάρχουν τα 3 ευρετήρια του sql/indexes.sql;
-- =====================================================================
SET NOCOUNT ON;
DECLARE @t TABLE (IndexName SYSNAME, TableName SYSNAME);
INSERT @t VALUES ('IX_RAW_READING_Pending', 'RAW_READING'),
                 ('IX_FIELD_TASK_Technician_Status', 'FIELD_TASK'),
                 ('IX_INVOICE_User_IssueDate', 'INVOICE');
DECLARE @n SYSNAME, @tb SYSNAME;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT IndexName, TableName FROM @t;
OPEN c; FETCH NEXT FROM c INTO @n, @tb;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = @n AND object_id = OBJECT_ID(@tb))
        PRINT 'OK   index ' + @n + ' exists';
    ELSE PRINT 'FAIL index ' + @n + ' missing';
    FETCH NEXT FROM c INTO @n, @tb;
END;
CLOSE c; DEALLOCATE c;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RAW_READING_Pending' AND has_filter = 1)
    PRINT 'OK   index IX_RAW_READING_Pending is filtered';
ELSE PRINT 'FAIL index IX_RAW_READING_Pending is not filtered';
