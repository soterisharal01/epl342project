SET NOCOUNT ON;
SELECT (
 SELECT t.name AS [table],
  (SELECT c.name, ty.name AS type, c.max_length AS len, c.precision AS prec, c.scale, c.is_nullable AS nullable, c.is_identity AS ident,
     CASE WHEN EXISTS (SELECT 1 FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
                       WHERE i.object_id=t.object_id AND i.is_primary_key=1 AND ic.column_id=c.column_id) THEN 1 ELSE 0 END AS pk,
     CASE WHEN EXISTS (SELECT 1 FROM sys.foreign_key_columns f WHERE f.parent_object_id=t.object_id AND f.parent_column_id=c.column_id) THEN 1 ELSE 0 END AS fk
   FROM sys.columns c JOIN sys.types ty ON ty.user_type_id=c.user_type_id
   WHERE c.object_id=t.object_id ORDER BY c.column_id FOR JSON PATH) AS cols
 FROM sys.tables t ORDER BY t.name FOR JSON PATH
) AS tables,
(
 SELECT fk.name, OBJECT_NAME(fk.parent_object_id) AS child, OBJECT_NAME(fk.referenced_object_id) AS parent,
   fk.delete_referential_action_desc AS onDelete,
   (SELECT COL_NAME(f.parent_object_id,f.parent_column_id) AS c FROM sys.foreign_key_columns f WHERE f.constraint_object_id=fk.object_id ORDER BY f.constraint_column_id FOR JSON PATH) AS cols
 FROM sys.foreign_keys fk ORDER BY fk.name FOR JSON PATH
) AS fks
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
