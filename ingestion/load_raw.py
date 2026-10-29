"""Download NYC TLC yellow taxi data and load it into the DuckDB raw layer.

Idempotent: re-running replaces the raw tables with the same result.
Usage:  python ingestion/load_raw.py --months 2024-01 2024-02
"""
import argparse
import logging
import time
import urllib.request
from pathlib import Path

import duckdb

BASE = "https://d37ci6vzurychx.cloudfront.net"
TRIPS_URL = BASE + "/trip-data/yellow_tripdata_{month}.parquet"
ZONES_URL = BASE + "/misc/taxi_zone_lookup.csv"

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "raw"
DB_PATH = ROOT / "warehouse.duckdb"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ingestion")


def download(url: str, dest: Path, retries: int = 3) -> Path:
    """Download a file with simple retry/backoff; skip if already present."""
    if dest.exists():
        log.info("Already downloaded: %s", dest.name)
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, retries + 1):
        try:
            log.info("Downloading %s (attempt %d/%d)", url, attempt, retries)
            urllib.request.urlretrieve(url, dest)
            return dest
        except Exception as exc:  # noqa: BLE001
            log.warning("Download failed: %s", exc)
            dest.unlink(missing_ok=True)
            if attempt == retries:
                raise
            time.sleep(2 * attempt)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--months", nargs="+", default=["2024-01", "2024-02"],
                        help="Months to load, format YYYY-MM")
    args = parser.parse_args()

    trip_files = [download(TRIPS_URL.format(month=m), DATA_DIR / f"yellow_{m}.parquet")
                  for m in args.months]
    zones_file = download(ZONES_URL, DATA_DIR / "taxi_zone_lookup.csv")

    con = duckdb.connect(str(DB_PATH))
    con.execute("create schema if not exists raw")

    file_list = [str(p) for p in trip_files]
    con.execute(
        """
        create or replace table raw.yellow_trips as
        select *, current_timestamp as _loaded_at
        from read_parquet(?, union_by_name = true, filename = true)
        """,
        [file_list],
    )
    con.execute(
        "create or replace table raw.taxi_zones as select * from read_csv_auto(?)",
        [str(zones_file)],
    )

    n_trips = con.execute("select count(*) from raw.yellow_trips").fetchone()[0]
    n_zones = con.execute("select count(*) from raw.taxi_zones").fetchone()[0]
    log.info("Loaded raw.yellow_trips=%s rows, raw.taxi_zones=%s rows", f"{n_trips:,}", n_zones)
    con.close()


if __name__ == "__main__":
    main()
