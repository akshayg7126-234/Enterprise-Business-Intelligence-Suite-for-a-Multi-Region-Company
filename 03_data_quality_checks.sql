/* =====================================================================
   03_data_quality_checks.sql
   Run after every load. Every query should return 0 rows / "PASS".
   Paste the output into docs/TEST_RESULTS.md as evidence.
   ===================================================================== */
USE AdventureWorksDW2022;
GO

-- 1. Row-count reconciliation: star schema fact vs. source tables
SELECT 'FactSales rows' AS [Check],
       (SELECT COUNT(*) FROM rpt.FactSales) AS Reporting,
       (SELECT COUNT(*) FROM dbo.FactInternetSales) + (SELECT COUNT(*) FROM dbo.FactResellerSales) AS Source,
       CASE WHEN (SELECT COUNT(*) FROM rpt.FactSales) =
                 (SELECT COUNT(*) FROM dbo.FactInternetSales) + (SELECT COUNT(*) FROM dbo.FactResellerSales)
            THEN 'PASS' ELSE 'FAIL' END AS Result;

-- 2. Total sales reconciliation
SELECT 'Total SalesAmount' AS [Check],
       (SELECT SUM(SalesAmount) FROM rpt.FactSales) AS Reporting,
       (SELECT SUM(SalesAmount) FROM dbo.FactInternetSales) + (SELECT SUM(SalesAmount) FROM dbo.FactResellerSales) AS Source,
       CASE WHEN ABS((SELECT SUM(SalesAmount) FROM rpt.FactSales) -
                    ((SELECT SUM(SalesAmount) FROM dbo.FactInternetSales) + (SELECT SUM(SalesAmount) FROM dbo.FactResellerSales))) < 0.01
            THEN 'PASS' ELSE 'FAIL' END AS Result;

-- 3. Orphan keys (fact rows with no matching dimension row) -> expect 0
SELECT 'Orphan ProductKey' AS [Check], COUNT(*) AS Bad
FROM rpt.FactSales f LEFT JOIN rpt.DimProduct p ON p.ProductKey = f.ProductKey WHERE p.ProductKey IS NULL;
SELECT 'Orphan OrderDateKey', COUNT(*)
FROM rpt.FactSales f LEFT JOIN rpt.DimDate d ON d.DateKey = f.OrderDateKey WHERE d.DateKey IS NULL;
SELECT 'Orphan SalesTerritoryKey', COUNT(*)
FROM rpt.FactSales f LEFT JOIN rpt.DimTerritory t ON t.SalesTerritoryKey = f.SalesTerritoryKey WHERE t.SalesTerritoryKey IS NULL;

-- 4. Duplicate grain (order + line + channel) -> expect 0 rows
SELECT Channel, SalesOrderNumber, SalesOrderLineNumber, COUNT(*) AS Dupes
FROM rpt.FactSales GROUP BY Channel, SalesOrderNumber, SalesOrderLineNumber HAVING COUNT(*) > 1;

-- 5. Negative / null measures -> expect 0
SELECT COUNT(*) AS BadRows FROM rpt.FactSales
WHERE SalesAmount IS NULL OR SalesAmount < 0 OR OrderQuantity <= 0;

-- 6. RLS map covers every territory used by sales -> expect 0 rows
SELECT t.Region FROM rpt.DimTerritory t
WHERE NOT EXISTS (SELECT 1 FROM rpt.SecurityMap m WHERE m.SalesTerritoryKey = t.SalesTerritoryKey);

-- 7. Reference numbers to compare with the Power BI report cards
SELECT YEAR(d.[Date]) AS [Year], SUM(f.SalesAmount) AS Sales,
       SUM(f.SalesAmount - f.TotalProductCost) AS GrossMargin
FROM rpt.FactSales f JOIN rpt.DimDate d ON d.DateKey = f.OrderDateKey
GROUP BY YEAR(d.[Date]) ORDER BY 1;
