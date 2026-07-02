run the update below on all secondaries. 

UPDATE c
SET c.job_id = s.job_id
FROM msdb.dbo.cdc_jobs c
JOIN msdb.dbo.sysjobs s
    ON s.name = 'cdc.' + DB_NAME(c.database_id) + '_' + c.job_type;