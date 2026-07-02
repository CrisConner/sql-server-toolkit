USE msdb;
GO

DECLARE @schedule_name SYSNAME = 'CDC - Every 5 Minutes';
DECLARE @schedule_id INT;

------------------------------------------------------------
-- 1. Create schedule if it does not exist
------------------------------------------------------------
SELECT @schedule_id = schedule_id
FROM dbo.sysschedules
WHERE name = @schedule_name;

IF @schedule_id IS NULL
BEGIN
    EXEC dbo.sp_add_schedule
        @schedule_name = @schedule_name,
        @enabled = 1,
        @freq_type = 4,              -- daily
        @freq_interval = 1,          -- every day
        @freq_subday_type = 4,       -- minutes
        @freq_subday_interval = 5,   -- every 5 minutes
        @active_start_time = 0;      -- midnight

    SELECT @schedule_id = schedule_id
    FROM dbo.sysschedules
    WHERE name = @schedule_name;

    PRINT 'Created schedule: ' + @schedule_name;
END
ELSE
BEGIN
    PRINT 'Schedule already exists: ' + @schedule_name;
END

------------------------------------------------------------
-- 2. Attach schedule to all CDC jobs
------------------------------------------------------------
DECLARE @job_id UNIQUEIDENTIFIER;
DECLARE @job_name SYSNAME;

DECLARE job_cursor CURSOR FAST_FORWARD FOR
SELECT job_id, name
FROM dbo.sysjobs
WHERE name LIKE 'cdc.%[_]capture'
   OR name LIKE 'cdc.%[_]cleanup';

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_id, @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Check if schedule already attached
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.sysjobschedules
        WHERE job_id = @job_id
          AND schedule_id = @schedule_id
    )
    BEGIN
        EXEC dbo.sp_attach_schedule
            @job_id = @job_id,
            @schedule_id = @schedule_id;

        PRINT 'Attached schedule to job: ' + @job_name;
    END
    ELSE
    BEGIN
        PRINT 'Schedule already attached to: ' + @job_name;
    END

    FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
END

