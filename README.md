# NYC Hydrant Density Analysis

## The question

Where is hydrant coverage densest in NYC, and which neighborhoods are underserved relative to their area?

## The data

- **NYC Neighborhoods.** 262 polygons (Source: [NYC Open Data](https://opendata.cityofnewyork.us))
- **NYC Fire Hydrants.** 109,725 points (Source: [NYC Open Data](https://opendata.cityofnewyork.us))
- License: NYC Open Data Terms of Use
- All data in EPSG:4326

## Methodology

Built the same analysis twice:

- **SQL (DuckDB + spatial extension).** Five progressive queries in `analysis.sql`, going from simple filter to spatial join to area-normalized density to 100m-buffer coverage analysis.
- **Python (GeoPandas).** Equivalent pipeline in `analysis.ipynb`, with a static choropleth and interactive `.explore()` map. Final output exported to GeoParquet.

Both pipelines produce the same density values to within rounding. The Python version produces the visualization. The SQL version runs against a database at scale.

## Findings

- Top 5 neighborhoods by hydrant density (per km²):
  1. [Fill in from your results]
  2. ...
- Bottom 5 neighborhoods (least coverage):
  1. ...
- Median neighborhood has X.X hydrants per km².
- Y% of every neighborhood is within 100m of a hydrant.

![NYC hydrant density choropleth](images/density_choropleth.png)

## How to run it

Requires Python 3.11+ with GeoPandas and DuckDB. No Docker or database server needed.

```bash
git clone https://github.com/tomtom776/nyc-hydrant-analysis.git
cd nyc-hydrant-analysis

pip install duckdb geopandas jupyterlab matplotlib

# Get the data (see "Getting the data" below) and save the GeoPackage as
# data/raw/Exercise2_HydrantNYC.gpkg

# Run the SQL pipeline (creates nyc.duckdb)
duckdb nyc.duckdb < analysis.sql

# Then the Python pipeline
jupyter lab analysis.ipynb
```

The first run downloads DuckDB's `spatial` extension (`INSTALL spatial;`), so it
needs internet access once.

### Getting the data

The raw data is not committed (`data/raw/` is git-ignored). To recreate it:

1. Download both layers from NYC Open Data as GeoJSON:
   - Neighborhoods (2020 NTAs): https://data.cityofnewyork.us/api/v3/views/9nt8-h7nd/query.geojson
   - Fire hydrants: https://data.cityofnewyork.us/api/v3/views/5bgh-vtsn/query.geojson
2. Load them into one GeoPackage (for example in QGIS: **Layer → Save Features As**,
   format GeoPackage) with these layer names, both in EPSG:4326:
   - `nyc_neighborhoods` (262 polygons)
   - `nyc_hydrants` (109,725 points)
3. Save it as `data/raw/Exercise2_HydrantNYC.gpkg`.

`analysis.sql` expects that exact path and those layer names. Each layer's
geometry column should be called `geom`.

## What I learned

[Two or three sentences. Be specific about which step was harder than expected and what you'd do differently. Do not skip this section.]

## Stack

- DuckDB + spatial extension
- GeoPandas + SQLAlchemy + matplotlib
- Jupyter Lab
- GeoParquet
