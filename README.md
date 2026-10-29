# NYC Taxi Analytics Pipeline (Python + DuckDB + dbt)

An end-to-end, reproducible ELT pipeline built on public NYC TLC yellow taxi data.
It ingests millions of raw trip records, transforms them into a star schema with dbt,
validates data quality with automated tests, and runs on a daily schedule via GitHub Actions.

> Personal portfolio project built with public data only.

## Architecture

```
NYC TLC public data (parquet + csv)
        |  Python ingestion (retry, idempotent)
        v
DuckDB  raw.yellow_trips / raw.taxi_zones
        |  dbt staging  (typing, cleaning, surrogate key)
        v
stg_trips / stg_zones
        |  dbt marts    (star schema)
        v
fct_trips + dim_zone  ->  mart_daily_borough_revenue
        |  dbt tests    (unique, not_null, relationships, accepted_values)
        v
GitHub Actions: daily run + CI on every push
```

## Tech stack and why

| Tool | Why |
|---|---|
| Python | Ingestion with retry/backoff and logging |
| DuckDB | Zero-setup analytical warehouse, handles millions of rows locally |
| dbt (dbt-duckdb) | Versioned SQL transformations, tests, documentation, lineage |
| GitHub Actions | Scheduled runs and CI so the pipeline is continuously verified |

## Data model

- `stg_trips`: typed and cleaned trips; removes invalid records (negative amounts or distance, dropoff before pickup); creates deterministic `trip_id`
- `fct_trips`: one row per valid trip, with trip duration and readable payment type
- `dim_zone`: zone, borough, and service zone
- `mart_daily_borough_revenue`: daily trips, revenue, average fare, duration, and tip rate per pickup borough

## Data quality

dbt tests cover uniqueness and not-null on keys, referential integrity between fact and dimension,
and accepted values for payment type. Tests run in CI on every push.

## Run it locally

```bash
git clone <your-repo-url> && cd nyc-taxi-dbt-pipeline
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python ingestion/load_raw.py --months 2024-01 2024-02
cd dbt_project
dbt build --profiles-dir .
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
```

## Results

- Rows ingested: **<fill in, e.g. 5.9M>**
- dbt models: **5**, tests passing: **<fill in>**
- Pipeline runtime locally: **<fill in>**

<!-- Add screenshots: docs/lineage.png (dbt docs lineage graph), docs/ci-green.png (GitHub Actions) -->

## Design decisions and trade-offs

- **Idempotent ingestion**: raw tables are rebuilt from source files, so re-runs never duplicate data.
- **Cleaning in staging, not in raw**: raw stays as-is for traceability; filtering rules are explicit in `stg_trips.sql`.
- **Deterministic surrogate key**: the source has no trip id, so a hash of business columns plus a duplicate sequence is used.

## What I would do at scale

- Move the warehouse to BigQuery/Snowflake/Redshift and land raw files in object storage (S3/GCS)
- Use dbt **incremental models** partitioned by pickup date instead of full rebuilds
- Orchestrate with **Airflow** (or Dagster) with alerting and backfills
- Add source freshness checks and data contracts
