SET NOCOUNT ON;
SELECT 'tables', COUNT(*) FROM sys.tables
UNION ALL SELECT 'columns', COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
UNION ALL SELECT 'foreign keys', COUNT(*) FROM sys.foreign_keys
UNION ALL SELECT 'checks', COUNT(*) FROM sys.check_constraints
UNION ALL SELECT 'unique constraints', COUNT(*) FROM sys.key_constraints WHERE type = 'UQ'
UNION ALL SELECT 'primary keys', COUNT(*) FROM sys.key_constraints WHERE type = 'PK'
UNION ALL SELECT 'filtered unique indexes', COUNT(*) FROM sys.indexes WHERE has_filter = 1 AND is_unique = 1
UNION ALL SELECT 'defaults', COUNT(*) FROM sys.default_constraints;
