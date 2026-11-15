"""Build app/assets/data/egypt_map.json: a small, simplified map of Egypt for the app's location picker.

Source: Natural Earth (public domain), https://www.naturalearthdata.com/
  ne_50m_admin_0_countries  (Egypt outline), ne_10m_rivers_lake_centerlines (Nile, Rosetta and Damietta
  branches, Suez Canal), ne_10m_lakes (Lake Nasser). Downloaded from the nvkelso/natural-earth-vector repository.
Output coordinates are [longitude, latitude], rounded to 3 decimals and simplified (Douglas-Peucker).

Run: .venv/Scripts/python scripts/build_egypt_map.py
"""
import json
import pathlib

import requests

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
EGYPT_BOX = (24.0, 21.5, 37.0, 32.2)  # lon_min, lat_min, lon_max, lat_max


def get(name):
    r = requests.get(BASE + name, timeout=180)
    r.raise_for_status()
    return r.json()


def simplify(pts, tol):
    """Douglas-Peucker on a list of (x, y)."""
    if len(pts) < 3:
        return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = (dx * dx + dy * dy) ** 0.5 or 1e-12
    idx, dmax = 0, 0.0
    for i in range(1, len(pts) - 1):
        d = abs(dy * pts[i][0] - dx * pts[i][1] + x2 * y1 - y2 * x1) / norm
        if d > dmax:
            idx, dmax = i, d
    if dmax > tol:
        left = simplify(pts[: idx + 1], tol)
        right = simplify(pts[idx:], tol)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def simplify_ring(pts, tol):
    """Simplify a closed ring: split at the point farthest from the start, simplify both halves."""
    x0, y0 = pts[0]
    k = max(range(len(pts)), key=lambda i: (pts[i][0] - x0) ** 2 + (pts[i][1] - y0) ** 2)
    return simplify(pts[: k + 1], tol)[:-1] + simplify(pts[k:], tol)


def rnd(pts):
    return [[round(x, 3), round(y, 3)] for x, y in pts]


def in_box(pts):
    return any(EGYPT_BOX[0] <= x <= EGYPT_BOX[2] and EGYPT_BOX[1] <= y <= EGYPT_BOX[3] for x, y in pts)


def lines(g):
    return g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]


def main():
    countries = get("ne_50m_admin_0_countries.geojson")
    egypt = next(f for f in countries["features"] if f["properties"].get("ADM0_A3") == "EGY")
    geom = egypt["geometry"]
    rings = [p[0] for p in geom["coordinates"]] if geom["type"] == "MultiPolygon" else [geom["coordinates"][0]]
    outline = [rnd(simplify_ring([tuple(p) for p in r], 0.004)) for r in rings]

    rivers = get("ne_10m_rivers_lake_centerlines.geojson")
    keep = {"Nile", "Rosetta Branch", "Damietta Branch", "Suez Canal", "Ismailiya Canal"}
    water = []
    for f in rivers["features"]:
        n = f["properties"].get("name")
        if n in keep:
            for seg in lines(f["geometry"]):
                seg = [tuple(p) for p in seg]
                if in_box(seg):
                    water.append({"name": n, "pts": rnd(simplify(seg, 0.002))})

    lakes = get("ne_10m_lakes.geojson")
    lake_polys = []
    for f in lakes["features"]:
        if f["properties"].get("name") in ("Lake Nasser", "Great Bitter Lake"):
            g = f["geometry"]
            polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
            for p in polys:
                lake_polys.append({"name": f["properties"]["name"], "pts": rnd(simplify_ring([tuple(q) for q in p[0]], 0.01))})

    out = {"source": "Natural Earth (public domain), simplified", "bbox": [24.5, 21.8, 36.95, 31.9], "outline": outline, "water": water, "lakes": lake_polys}
    dest = ROOT / "app" / "assets" / "data" / "egypt_map.json"
    dest.write_text(json.dumps(out, separators=(",", ":")), encoding="utf8")
    print("wrote", dest.stat().st_size, "bytes;", "outline pts", sum(len(r) for r in outline), "| water lines", len(water), "| lakes", len(lake_polys))


if __name__ == "__main__":
    main()
