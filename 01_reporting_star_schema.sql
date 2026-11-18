/* =====================================================================
   01_reporting_star_schema.sql
   Builds the reporting star schema on top of AdventureWorksDW (2019/2022).
   Run against: AdventureWorksDW  (SQL Server 2019+ / Azure SQL)
   Sales, Finance, HR and Supply Chain are exposed as 4 fact groups
   sharing conformed dimensions (Date, Territory, Product, Employee).
   ===================================================================== */
USE AdventureWorksDW2022;   -- change to your restored DB name
GO
IF SCHEMA_ID('rpt') IS NULL EXEC('CREATE SCHEMA rpt');
GO

/* ---------------------------- DIMENSIONS --------------------------- */

CREATE OR ALTER VIEW rpt.DimDate AS
SELECT
    d.DateKey,
    d.FullDateAlternateKey                         AS [Date],
    d.CalendarYear,
    d.CalendarQuarter,
    CONCAT('Q', d.CalendarQuarter)                 AS QuarterName,
    d.MonthNumberOfYear                            AS MonthNumber,
    d.EnglishMonthName                             AS MonthName,
    LEFT(d.EnglishMonthName, 3)                    AS MonthShort,
    d.EnglishDayNameOfWeek                         AS DayName,
    d.DayNumberOfWeek                              AS DayNumber,
    CAST(d.CalendarYear * 100 + d.MonthNumberOfYear AS INT) AS YearMonthKey,
    CONCAT(d.CalendarYear, '-', RIGHT('0' + CAST(d.MonthNumberOfYear AS VARCHAR(2)), 2)) AS YearMonth
FROM dbo.DimDate d;
GO

CREATE OR ALTER VIEW rpt.DimTerritory AS
SELECT
    t.SalesTerritoryKey,
    t.SalesTerritoryRegion   AS Region,
    t.SalesTerritoryCountry  AS Country,
    t.SalesTerritoryGroup    AS TerritoryGroup
FROM dbo.DimSalesTerritory t
WHERE t.SalesTerritoryKey <> 11;   -- 11 = 'NA' placeholder row
GO

CREATE OR ALTER VIEW rpt.DimProduct AS
SELECT
    p.ProductKey,
    p.ProductAlternateKey                           AS ProductSKU,
    p.EnglishProductName                            AS ProductName,
    ISNULL(sc.EnglishProductSubcategoryName,'Unassigned') AS Subcategory,
    ISNULL(pc.EnglishProductCategoryName,'Unassigned')    AS Category,
    ISNULL(p.Color,'N/A')                           AS Color,
    ISNULL(p.Size,'N/A')                            AS Size,
    p.StandardCost,
    p.ListPrice,
    p.Status                                        AS ProductStatus
FROM dbo.DimProduct p
LEFT JOIN dbo.DimProductSubcategory sc ON sc.ProductSubcategoryKey = p.ProductSubcategoryKey
LEFT JOIN dbo.DimProductCategory   pc ON pc.ProductCategoryKey    = sc.ProductCategoryKey;
GO

CREATE OR ALTER VIEW rpt.DimCustomer AS
SELECT
    c.CustomerKey,
    CONCAT(c.FirstName, ' ', c.LastName)  AS CustomerName,
    c.Gender,
    c.MaritalStatus,
    c.YearlyIncome,
    c.EnglishEducation                    AS Education,
    c.EnglishOccupation                   AS Occupation,
    c.NumberCarsOwned,
    DATEDIFF(YEAR, c.BirthDate, '2014-01-01') AS AgeAtDataEnd,
    g.City,
    g.StateProvinceName                   AS StateProvince,
    g.EnglishCountryRegionName            AS Country,
    g.SalesTerritoryKey
FROM dbo.DimCustomer c
LEFT JOIN dbo.DimGeography g ON g.GeographyKey = c.GeographyKey;
GO

/* Employee dimension: HR attributes. Salary/pay fields are kept out of the
   default view for privacy; HR-only role gets rpt.DimEmployeeHR if needed.  */
CREATE OR ALTER VIEW rpt.DimEmployee AS
SELECT
    e.EmployeeKey,
    CONCAT(e.FirstName, ' ', e.LastName)  AS EmployeeName,
    e.Title                               AS JobTitle,
    e.DepartmentName                      AS Department,
    e.Gender,
    e.MaritalStatus,
    e.SalariedFlag,
    e.HireDate,
    e.StartDate,
    e.EndDate,
    e.Status,
    e.CurrentFlag,
    e.BaseRate,
    e.VacationHours,
    e.SickLeaveHours,
    e.SalesTerritoryKey
FROM dbo.DimEmployee e;
GO

/* ------------------------------ FACTS ------------------------------ */

/* Sales: Internet + Reseller stacked into one fact with a Channel column */
CREATE OR ALTER VIEW rpt.FactSales AS
SELECT 'Internet' AS Channel, s.SalesOrderNumber, s.SalesOrderLineNumber,
       s.OrderDateKey, s.ShipDateKey, s.ProductKey, s.CustomerKey,
       CAST(NULL AS INT) AS EmployeeKey, s.SalesTerritoryKey,
       s.OrderQuantity, s.UnitPrice, s.DiscountAmount,
       s.SalesAmount, s.TotalProductCost, s.TaxAmt, s.Freight
FROM dbo.FactInternetSales s
UNION ALL
SELECT 'Reseller', r.SalesOrderNumber, r.SalesOrderLineNumber,
       r.OrderDateKey, r.ShipDateKey, r.ProductKey, CAST(NULL AS INT),
       r.EmployeeKey, r.SalesTerritoryKey,
       r.OrderQuantity, r.UnitPrice, r.DiscountAmount,
       r.SalesAmount, r.TotalProductCost, r.TaxAmt, r.Freight
FROM dbo.FactResellerSales r;
GO

/* Supply chain: inventory movements (not region-specific) */
CREATE OR ALTER VIEW rpt.FactInventory AS
SELECT i.ProductKey,
       i.DateKey,
       i.UnitCost,
       i.UnitsIn,
       i.UnitsOut,
       i.UnitsBalance
FROM dbo.FactProductInventory i;
GO

/* Sales quota by employee-quarter */
CREATE OR ALTER VIEW rpt.FactQuota AS
SELECT q.EmployeeKey, q.DateKey, q.CalendarYear, q.CalendarQuarter, q.SalesAmountQuota
FROM dbo.FactSalesQuota q;
GO

/* Finance: P&L style amounts by account */
CREATE OR ALTER VIEW rpt.FactFinance AS
SELECT f.DateKey,
       f.OrganizationKey,
       sc.ScenarioName,
       a.AccountDescription  AS Account,
       a.AccountType,
       f.Amount
FROM dbo.FactFinance f
JOIN dbo.DimScenario sc ON sc.ScenarioKey = f.ScenarioKey
JOIN dbo.DimAccount  a  ON a.AccountKey   = f.AccountKey;
GO
