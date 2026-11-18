/* =====================================================================
   04_sql_agent_job.sql  --  FALLBACK for "scheduled SQL jobs if Azure is unavailable"
   Creates a nightly SQL Server Agent job that runs rpt.usp_Run_All.
   (SQL Server Express has no Agent: use Windows Task Scheduler + sqlcmd,
    see docs/SETUP.md.)
   ===================================================================== */
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'BI_Suite_Nightly_Load')
    EXEC msdb.dbo.sp_delete_job @job_name = N'BI_Suite_Nightly_Load';
GO
EXEC msdb.dbo.sp_add_job         @job_name = N'BI_Suite_Nightly_Load';
EXEC msdb.dbo.sp_add_jobstep     @job_name = N'BI_Suite_Nightly_Load',
     @step_name = N'Run ETL', @subsystem = N'TSQL',
     @database_name = N'AdventureWorksDW2022',
     @command = N'EXEC rpt.usp_Run_All;';
EXEC msdb.dbo.sp_add_schedule    @schedule_name = N'Nightly 2AM',
     @freq_type = 4, @freq_interval = 1, @active_start_time = 020000;
EXEC msdb.dbo.sp_attach_schedule @job_name = N'BI_Suite_Nightly_Load', @schedule_name = N'Nightly 2AM';
EXEC msdb.dbo.sp_add_jobserver   @job_name = N'BI_Suite_Nightly_Load';
GO
