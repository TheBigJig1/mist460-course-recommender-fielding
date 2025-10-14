-- Run from master
USE master;
GO

-- Helper to drop cleanly
DECLARE @db SYSNAME;

-- List the target DBs you want to reset
DECLARE cur CURSOR FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE name IN (N'MIST460_RelationalDatabase_Lastname', N'Homework3Group1');

OPEN cur;
FETCH NEXT FROM cur INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT CONCAT('Dropping database ', @db, ' ...');

    DECLARE @sql NVARCHAR(MAX) =
        N'IF DB_ID(N''' + @db + N''') IS NOT NULL
          BEGIN
              ALTER DATABASE [' + @db + N'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
              DROP DATABASE [' + @db + N'];
          END';
    EXEC (@sql);

    FETCH NEXT FROM cur INTO @db;
END
CLOSE cur;
DEALLOCATE cur;

PRINT 'Done. Databases dropped.';
GO