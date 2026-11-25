-- =============================================================================
-- NYC Hydrant Density Analysis. analysis.sql
-- Portfolio Project 2, Modern GIS Accelerator
--
-- Five progressive DuckDB (spatial extension) queries that build up to a
-- normalized density analysis and a 100-meter coverage analysis.
--
-- Assumes:
--   - DuckDB database file "nyc.duckdb" with the spatial extension available
--   - Tables loaded (see setup below):
--       nyc_neighborhoods (polygon, EPSG:4326, geom column called "geom",
--                          attributes including "ntaname" and "boroname")
--       nyc_hydrants      (point,   EPSG:4326, geom column called "geom",
--                          attributes including "unitid")
--   - No manual spatial index is needed: DuckDB optimizes spatial joins itself.
--
-- Run all queries (CLI):
--   duckdb nyc.duckdb < analysis.sql
-- Or paste them one at a time into the DuckDB CLI / a Python session.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Setup (run once)
--
-- Reads the two layers from the GeoPackage in data/raw/ (path is relative to
-- the repo root, so run DuckDB from there). The file is git-ignored.
-- Check layer names with:  SELECT * FROM ST_Read_Meta('data/raw/Exercise2_HydrantNYC.gpkg');
-- ST_Read names the geometry column "geom".
-- -----------------------------------------------------------------------------

INSTALL spatial;
LOAD spatial;

CREATE OR REPLACE TABLE nyc_neighborhoods AS
  SELECT * FROM ST_Read('data/raw/Exercise2_HydrantNYC.gpkg', layer = 'nyc_neighborhoods');

CREATE OR REPLACE TABLE nyc_hydrants AS
  SELECT * FROM ST_Read('data/raw/Exercise2_HydrantNYC.gpkg', layer = 'nyc_hydrants');

-- Quick check: expect 262 and 109725.
SELECT (SELECT count(*) FROM nyc_neighborhoods) AS neighborhoods,
       (SELECT count(*) FROM nyc_hydrants)      AS hydrants;


-- -----------------------------------------------------------------------------
-- Query 1: Filter
--
-- Goal: Sanity check that the data loaded. Pull all neighborhoods in Manhattan.
-- Expected output: ~37 rows (Manhattan neighborhoods).
-- source link: https://data.cityofnewyork.us/api/v3/views/9nt8-h7nd/query.geojson
-- -----------------------------------------------------------------------------

select ntaname, boroname
from nyc_neighborhoods
where boroname = 'Manhattan'
order by ntaname;


-- -----------------------------------------------------------------------------
-- Query 2: Spatial join
--
-- Goal: Match each hydrant to the neighborhood that contains it, using
-- ST_Contains.
-- Expected output: one row per hydrant (~109,725) with the neighborhood name.
-- -----------------------------------------------------------------------------

-- Selects h.unitid (the hydrant ID), n.ntaname, n.boroname by joining
-- nyc_hydrants h to nyc_neighborhoods n using ST_Contains(n.geom, h.geom).
-- Use LIMIT 10 for a first peek so you don't print the whole result set.
-- hydrant source: https://data.cityofnewyork.us/api/v3/views/5bgh-vtsn/query.geojson

select h.unitid, n.ntaname, n.boroname, h.geom
from nyc_hydrants h
join nyc_neighborhoods n on ST_Contains(n.geom, h.geom)
order by ntaname
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Query 3: Aggregate
--
-- Goal: Count hydrants per neighborhood.
-- Expected output: 262 rows (one per neighborhood) with a hydrant_count.
-- -----------------------------------------------------------------------------

-- [TODO] Take Query 2 and wrap it in a GROUP BY. Use COUNT(h.*) to count
-- hydrants per neighborhood. ORDER BY hydrant_count DESC.
-- (In DuckDB, COUNT(*) or COUNT(h.unitid) works; COUNT(h.*) does not.)

select n.ntaname, n.boroname, COUNT(h.unitid) as hydrant_count, any_value(n.geom) as geom
from nyc_neighborhoods n
left join nyc_hydrants h on ST_Contains(n.geom, h.geom)
group by n.ntaname, n.boroname
order by hydrant_count DESC;

-- -----------------------------------------------------------------------------
-- Query 4: Normalize (this is your headline result)
--
-- Goal: Compute density per square kilometer. Reproject to EPSG:2263
-- (NY State Plane Long Island, feet) before computing area, then convert
-- square feet to square kilometers.
-- Expected output: 262 rows with hydrant_count, area_km2, density_per_km2.
-- -----------------------------------------------------------------------------

-- [TODO] Extend Query 3 with:
--   - ST_Area(ST_Transform(n.geom, 'EPSG:4326', 'EPSG:2263', always_xy := true))
--       / 10763910.42  AS area_km2
--     (10,763,910.42 square feet = 1 square kilometer)
--     DuckDB's ST_Transform needs the source CRS spelled out. always_xy keeps
--     the x/y (lon/lat) order that ST_Read gives you; if your DuckDB version
--     rejects that argument, update DuckDB and the spatial extension.
--   - hydrant_count / area_km2  AS density_per_km2
-- ORDER BY density_per_km2 DESC.


-- -----------------------------------------------------------------------------
-- Query 5: Buffer + Union + Intersection (coverage analysis)
--
-- Goal: For each neighborhood, what percent of its area is within 100 meters
-- of a hydrant? This is the deeper finding.
-- Expected output: 262 rows with neighborhood, area_km2, covered_pct.
-- -----------------------------------------------------------------------------

-- [TODO] Build this in two CTEs:
--   1. hydrant_coverage: ST_Union_Agg(ST_Buffer(<hydrant geom in 2263>, 328.084))
--      across ALL hydrants. (One big multipolygon of 100m buffers.)
--      NOTE: EPSG:2263 is in FEET, so 100 meters = 328.084 feet. Buffering by
--      100 would only give you 100 feet. In DuckDB the aggregate is
--      ST_Union_Agg (ST_Union is the two-geometry version).
--   2. The main SELECT: for each neighborhood, compute
--        ST_Area(ST_Intersection(<n.geom in 2263>, hc.coverage_geom))
--        divided by ST_Area(<n.geom in 2263>)
--      to get the percent of each neighborhood within 100m of a hydrant.
--   <geom in 2263> = ST_Transform(geom, 'EPSG:4326', 'EPSG:2263', always_xy := true)
--   Tip: transform each layer once into a CTE or table instead of repeating it.
--   Unioning 109k buffers can take a while; start with a single borough to test.
-- ORDER BY covered_pct DESC.


-- =============================================================================
-- Notes for your README
--
-- - Query 1 is your sanity check. Don't skip it.
-- - Query 4 is your headline. Identify the top 5 and bottom 5 neighborhoods.
-- - Query 5 is the deeper insight. Look at the median covered_pct. That number
--   is your case-study finding.
-- =============================================================================
