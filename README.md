# Enterprise Business Intelligence Suite for a Multi-Region Company

One reporting system that combines **sales, finance, HR and supply-chain** data from Microsoft's AdventureWorksDW, with **secure per-region access** (row-level security).

**Track:** Data Analytics · **Project:** DA-01 #2 · **Stack:** SQL Server · Azure Data Factory (or SQL Agent) · Power Query · DAX · Power BI Service

## Repository layout
```
sql/            Star-schema views, RLS map, ETL procs, data-quality checks, SQL Agent fallback job
adf/            Azure Data Factory pipeline + nightly trigger (JSON, importable)
powerquery/     M queries for every table in the model
dax/            All measures (YTD, YoY, margin %, rolling averages, HR, inventory, finance)
docs/           Setup, architecture, dashboard design, RLS guide, user guide, test plan, presentation outline, reflection
```

## Quick start (about 45 minutes)
1. Install SQL Server (Developer/Express) and restore **AdventureWorksDW2022** (see `docs/SETUP.md`).
2. Run `sql/01` → `02` → `03` in SSMS/Azure Data Studio. All `03` checks should say PASS / return 0 rows.
3. Open Power BI Desktop → create parameters `pServer`, `pDatabase` → paste each query from `powerquery/queries.m`.
4. Build relationships as listed in `docs/RLS_GUIDE.md`, mark `DimDate` as the date table, hide key columns.
5. Create the `_Measures` table and paste `dax/measures.dax`.
6. Build the pages described in `docs/DASHBOARD_DESIGN.md`.
7. Add RLS roles (`docs/RLS_GUIDE.md`), test with *View as*.
8. Publish → configure scheduled refresh (gateway if SQL Server is local) → publish an App.
9. Fill in `docs/TEST_RESULTS.md`, record the demo, and push everything to GitHub.

## Architecture
See `docs/ARCHITECTURE.md` (diagram + data dictionary).

## Key design choices
- **Star schema as SQL views (`rpt` schema)**: source untouched, easy to explain, easy to materialise later for performance.
- **Internet + Reseller sales stacked** into one `FactSales` with a `Channel` column.
- **Time intelligence anchored on the last sales date** because AdventureWorksDW data ends in 2014 (a `TODAY()` approach would show blanks).
- **Dynamic RLS** from a `SecurityMap` table: onboarding a manager is a SQL insert.
- **Fallback orchestration**: ADF pipeline *or* SQL Agent job running the same stored procedure.

## Limitations (be upfront about these)
- AdventureWorksDW inventory and finance facts are not territory-level, so they are executive-only (see RLS guide).
- Data is synthetic and historical (2010–2014).
