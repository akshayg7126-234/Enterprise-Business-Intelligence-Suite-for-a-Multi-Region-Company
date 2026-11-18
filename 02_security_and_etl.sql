/* =====================================================================
   02_security_and_etl.sql
   (a) RLS mapping table  (b) audit/refresh log  (c) incremental load procs
   Target: a reporting database/schema that Power BI reads from.
   ===================================================================== */
USE AdventureWorksDW2022;
GO

/* ---------- (a) Region-manager security map (used by Power BI RLS) ---- */
IF OBJECT_ID('rpt.SecurityMap') IS NOT NULL DROP TABLE rpt.SecurityMap;
CREATE TABLE rpt.SecurityMap (
    UserEmail         NVARCHAR(256) NOT NULL,   -- must match the Power BI sign-in (UPN)
    SalesTerritoryKey INT           NOT NULL,
    RoleName          NVARCHAR(50)  NOT NULL DEFAULT 'RegionManager',
    CONSTRAINT PK_SecurityMap PRIMARY KEY (UserEmail, SalesTerritoryKey)
);
GO
/* Replace the example emails with real test accounts (or Entra ID groups' members).
   Territory keys in AdventureWorksDW: 1 NW, 2 NE, 3 Central, 4 SW, 5 SE,
   6 Canada, 7 France, 8 Germany, 9 Australia, 10 United Kingdom            */
INSERT INTO rpt.SecurityMap (UserEmail, SalesTerritoryKey, RoleName) VALUES
 ('na.manager@yourtenant.onmicrosoft.com', 1,  'RegionManager'),
 ('na.manager@yourtenant.onmicrosoft.com', 2,  'RegionManager'),
 ('na.manager@yourtenant.onmicrosoft.com', 3,  'RegionManager'),
 ('na.manager@yourtenant.onmicrosoft.com', 4,  'RegionManager'),
 ('na.manager@yourtenant.onmicrosoft.com', 5,  'RegionManager'),
 ('canada.manager@yourtenant.onmicrosoft.com', 6, 'RegionManager'),
 ('europe.manager@yourtenant.onmicrosoft.com', 7, 'RegionManager'),
 ('europe.manager@yourtenant.onmicrosoft.com', 8, 'RegionManager'),
 ('europe.manager@yourtenant.onmicrosoft.com', 10,'RegionManager'),
 ('apac.manager@yourtenant.onmicrosoft.com', 9,  'RegionManager');
GO

/* ---------- (b) ETL / refresh audit log ------------------------------ */
IF OBJECT_ID('rpt.EtlLog') IS NULL
CREATE TABLE rpt.EtlLog (
    LogId       INT IDENTITY PRIMARY KEY,
    RunStart    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    RunEnd      DATETIME2 NULL,
    StepName    NVARCHAR(100) NOT NULL,
    RowsLoaded  BIGINT NULL,
    Status      NVARCHAR(20) NOT NULL DEFAULT 'Running',
    ErrorMsg    NVARCHAR(4000) NULL
);
GO

/* ---------- (c) Materialised copies for faster Power BI import -------
   Views are fine for a demo. For "performance numbers" in the report,
   materialise the big fact into a table and compare refresh times.       */
IF OBJECT_ID('rpt.FactSales_T') IS NULL
SELECT TOP 0 * INTO rpt.FactSales_T FROM rpt.FactSales;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='CCI_FactSales_T')
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales_T ON rpt.FactSales_T;
GO

CREATE OR ALTER PROCEDURE rpt.usp_Load_FactSales
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @log INT, @rows BIGINT;
    INSERT INTO rpt.EtlLog (StepName) VALUES ('Load FactSales_T');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
            TRUNCATE TABLE rpt.FactSales_T;          -- full reload; dataset is small
            INSERT INTO rpt.FactSales_T SELECT * FROM rpt.FactSales;
            SET @rows = @@ROWCOUNT;
        COMMIT;
        UPDATE rpt.EtlLog SET RunEnd = SYSUTCDATETIME(), RowsLoaded = @rows, Status = 'Success'
        WHERE LogId = @log;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE rpt.EtlLog SET RunEnd = SYSUTCDATETIME(), Status = 'Failed',
               ErrorMsg = ERROR_MESSAGE() WHERE LogId = @log;
        THROW;
    END CATCH
END;
GO

/* Called by the ADF pipeline's failure branch */
CREATE OR ALTER PROCEDURE rpt.usp_LogFailure @StepName NVARCHAR(100)
AS
BEGIN
    INSERT INTO rpt.EtlLog (StepName, RunEnd, Status, ErrorMsg)
    VALUES (@StepName, SYSUTCDATETIME(), 'Failed', 'Reported by ADF failure branch');
END;
GO

CREATE OR ALTER PROCEDURE rpt.usp_Run_All
AS
BEGIN
    EXEC rpt.usp_Load_FactSales;
    -- add further loads here (inventory, finance...) if you materialise them
END;
GO
