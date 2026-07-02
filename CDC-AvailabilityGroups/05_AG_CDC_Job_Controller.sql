USE [msdb]
GO

/****** Object:  Job [DBA - Sync AG Job States (CDC)]    Script Date: 6/25/2026 7:46:37 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 6/25/2026 7:46:37 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Sync AG Job States (CDC)', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Ensures CDC SQL Agent jobs are correctly enabled or disabled based on Availability Group role.
When the replica is PRIMARY, CDC capture and cleanup jobs are enabled.
When the replica is SECONDARY, the jobs are disabled to prevent duplicate processing and errors.
This job runs on a schedule to automatically enforce correct job state after failover events, eliminating the need for manual intervention and ensuring CDC operates only on the primary replica.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa_disabled', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check AG role and enforce CDC job state]    Script Date: 6/25/2026 7:46:37 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check AG role and enforce CDC job state', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

PRINT ''=== CDC AG Job Enforcement Start: '' + CONVERT(varchar(30), GETDATE(), 120);

DECLARE @is_primary BIT = 0;

-- Since there is only ONE AG, just grab any DB in it to determine role
SELECT TOP (1)
    @is_primary = sys.fn_hadr_is_primary_replica(d.name)
FROM sys.databases d
WHERE d.replica_id IS NOT NULL   -- database is in AG
  AND d.state = 0;               -- ONLINE

PRINT ''Replica role: '' + CASE WHEN @is_primary = 1 THEN ''PRIMARY'' ELSE ''SECONDARY'' END;

DECLARE 
    @job_id UNIQUEIDENTIFIER,
    @job_name SYSNAME,
    @is_enabled INT,
    @desired_enabled INT = CASE WHEN @is_primary = 1 THEN 1 ELSE 0 END;

-- All CDC jobs (capture + cleanup)
DECLARE job_cursor CURSOR FAST_FORWARD FOR
SELECT job_id, name
FROM msdb.dbo.sysjobs
WHERE name LIKE ''cdc.%[_]capture''
   OR name LIKE ''cdc.%[_]cleanup'';

OPEN job_cursor;

FETCH NEXT FROM job_cursor INTO @job_id, @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @is_enabled = enabled
    FROM msdb.dbo.sysjobs
    WHERE job_id = @job_id;

    PRINT ''---'';
    PRINT ''Job: '' + @job_name;
    PRINT ''Current enabled: '' + CAST(@is_enabled AS varchar);
    PRINT ''Desired enabled: '' + CAST(@desired_enabled AS varchar);

    IF @is_enabled <> @desired_enabled
    BEGIN
        EXEC msdb.dbo.sp_update_job
            @job_id = @job_id,
            @enabled = @desired_enabled;

        PRINT ''>>> Job updated'';
    END
    ELSE
    BEGIN
        PRINT ''No change needed'';
    END

    FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor;

PRINT ''=== CDC AG Job Enforcement Complete ==='';', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DBA - Sync AG Job States (CDC)', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20260526, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'25ac2293-def6-4384-858f-ce25b69e1edc'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


