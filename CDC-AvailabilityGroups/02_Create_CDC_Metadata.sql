use msdb
go
CREATE TABLE [dbo].[cdc_jobs] (
[database_id] [int] NOT NULL
, [job_type] [nvarchar](20) NOT NULL
, [job_id] [uniqueidentifier] NULL
, [maxtrans] [int] NULL
, [maxscans] [int] NULL
, [continuous] [bit] NULL
, [pollinginterval] [bigint] NULL
, [retention] [bigint] NULL
, [threshold] [bigint] NULL
, PRIMARY KEY CLUSTERED (
[database_id] ASC
, [job_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY];
go
----------------------------------------------------------------------------------

CREATE VIEW dbo.cdc_jobs_view AS
SELECT
  [database_id],
  [job_type],
  [job_id],
  [maxtrans],
  [maxscans],
  [continuous],
  [pollinginterval],
  [retention],
  [threshold]
FROM dbo.cdc_jobs;