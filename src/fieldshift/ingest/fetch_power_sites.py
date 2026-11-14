"""Download NASA POWER daily weather (1990-2025) for each site in models/sites.yaml.

No account needed. Output: data/raw/power/<site>_daily.json (one file per site).
Run: .venv/Scripts/python src/fieldshift/ingest/fetch_power_sites.py
Safe to re-run: existing files are skipped.
"""
import pathlib
import sys
import time

import requests
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "power"
PARAMS = "T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,ALLSKY_SFC_SW_DWN,RH2M,WS2M,GWETTOP,GWETROOT,GWETPROF,EVPTRNS"
URL = "https://power.larc.nasa.gov/api/temporal/daily/point"


def main():
    sites = yaml.safe_load((ROOT / "models" / "sites.yaml").read_text(encoding="utf8"))["sites"]
    OUT.mkdir(parents=True, exist_ok=True)
    bad = 0
    for key, s in sites.items():
        dest = OUT / f"{key}_daily.json"
        if dest.exists():
            print(key, "exists")
            continue
        q = dict(parameters=PARAMS, community="AG", longitude=s["lon"], latitude=s["lat"],
                 start="19900101", end="20251231", format="JSON")
        for attempt in range(4):
            try:
                r = requests.get(URL, params=q, timeout=240)
                r.raise_for_status()
                dest.write_bytes(r.content)
                print(key, len(r.content), "bytes")
                break
            except requests.RequestException as e:
                if attempt == 3:
                    print(key, "FAILED", repr(e)[:120])
                    bad += 1
                time.sleep(10 * (attempt + 1))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
