SET NOCOUNT ON;

DECLARE @Insert NVARCHAR(MAX) = N'';

SELECT @Insert = @Insert + 
'
INSERT INTO msdb.dbo.cdc_jobs
(
    database_id,
    job_type,
    job_id,
    maxtrans,
    maxscans,
    continuous,
    pollinginterval,
    retention,
    threshold
)
SELECT 
    DB_ID(''' + DB_NAME(database_id) + '''),
    ''' + job_type + ''',
    NULL,  -- job_id fixed later
    ' + CAST(maxtrans AS VARCHAR(20)) + ',
    ' + CAST(maxscans AS VARCHAR(20)) + ',
    ' + CAST(continuous AS VARCHAR(20)) + ',
    ' + CAST(pollinginterval AS VARCHAR(20)) + ',
    ' + CAST(retention AS VARCHAR(20)) + ',
    ' + CAST(threshold AS VARCHAR(20)) + '
WHERE NOT EXISTS
(
    SELECT 1
    FROM msdb.dbo.cdc_jobs c
    WHERE c.database_id = DB_ID(''' + DB_NAME(database_id) + ''')
    AND c.job_type = ''' + job_type + '''
);
'
FROM msdb.dbo.cdc_jobs;

PRINT @Insert;

--------------------------------
--run the output from above on all secondaries
