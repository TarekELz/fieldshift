"""Build app/assets/data/egypt_map.json: a small, simplified map of Egypt for the app's location picker.

Sources:
  HDX "Egypt - Subnational Administrative Boundaries" (COD-AB, CAPMAS via OCHA, CC BY-IGO, modified 2026-01-26),
    admin 1: the 27 governorates with their Arabic names. Downloaded to data/raw/hdx_egy/ (gitignored) if missing.
  Natural Earth (public domain), https://www.naturalearthdata.com/, nvkelso/natural-earth-vector repo:
    ne_10m_admin_0_disputed_areas    the Halayeb Triangle (drawn and named as its own area inside Egypt's outline)
    ne_10m_rivers_lake_centerlines   the Nile, the Rosetta and Damietta branches, the Suez Canal
    ne_10m_lakes                     Lake Nasser
Natural Earth rivers/lakes are generalized cartographic data, NOT a survey. Output coordinates are [longitude, latitude],
rounded to 3 decimals and simplified (Douglas-Peucker, ~0.5 km).

Checked 2026-11-15 against OpenStreetMap: the western, southern and Sinai land borders coincide with OSM's; river lines
lie within 0.4-2 km of Mansoura, Zifta, Mit Ghamr, Desouk, Rashid, Damietta, Aswan, Luxor, Asyut and Giza.

Run: .venv/Scripts/python scripts/build_egypt_map.py
"""
import io
import json
import pathlib
import zipfile

import requests

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
HDX_ZIP = "https://data.humdata.org/dataset/b90d81ba-7c7a-4283-9899-827480d80a79/resource/2080e95f-51c7-45b6-b5ab-613ff1cfc041/download/egy_admin_boundaries.geojson.zip"
HDX_DIR = ROOT / "data" / "raw" / "hdx_egy"
EGYPT_BOX = (24.0, 21.5, 37.0, 32.2)  # lon_min, lat_min, lon_max, lat_max

# Governorates the app covers (the Nile Delta and its edges) and the NASA data point each one owns, if any.
DELTA = ["Alexandria", "Behera", "Kafr El-Shikh", "Gharbia", "Dakahlia", "Damietta", "Menoufia", "Sharkia", "Kalyoubia", "Port Said"]
OWN_SITE = {"Behera": "beheira", "Kafr El-Shikh": "kafr_el_sheikh", "Gharbia": "gharbia", "Menoufia": "menoufia", "Sharkia": "sharqia", "Dakahlia": "dakahlia", "Damietta": "damietta"}


NE_DISPUTED = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_disputed_areas.geojson"


def _ne_disputed(name):
    f = ROOT / "data" / "raw" / "natural_earth" / "disputed.geojson"
    if not f.exists():
        f.parent.mkdir(parents=True, exist_ok=True)
        r = requests.get(NE_DISPUTED, timeout=300)
        r.raise_for_status()
        f.write_bytes(r.content)
    feat = [x for x in json.loads(f.read_text(encoding="utf8"))["features"] if x["properties"].get("NAME") == name][0]
    g = feat["geometry"]
    polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    rings = [simplify_ring([tuple(q) for q in poly[0]], 0.004) for poly in polys]
    big = max(rings, key=lambda r: abs(area_centroid(r)[0]))
    _, cx, cy = area_centroid(big)
    return [rnd(r) for r in rings], [round(cx, 3), round(cy, 3)]


def named_areas():
    """Two areas at Egypt's southern edge, from Natural Earth's disputed-areas layer (public domain).
    Halayeb Triangle: inside Egypt's official outline (north of the 22nd parallel, which is Egypt's border); the HDX
    governorate polygons already contain it, so it is only drawn and named as its own area.
    Bir Tawil: south of 22N, claimed by neither Egypt nor Sudan; NOT inside Egypt's outline. Drawn as a separate, dashed,
    neutral area (kind 'unclaimed') so the border is shown honestly and the area is not painted as a governorate."""
    h_rings, h_label = _ne_disputed("Halayib Triangle")
    b_rings, b_label = _ne_disputed("Bir Tawil")
    return [
        {"id": "Halayeb and Shalateen", "ar": "حلايب وشلاتين", "parent": "Red Sea", "kind": "egypt_administered",
         "aliases": ["حلايب", "شلاتين", "ابو رماد", "halayeb", "halaib", "halayib", "shalateen", "shalatin", "abu ramad"], "label": h_label, "rings": h_rings},
        {"id": "Bir Tawil", "ar": "بئر طويل", "parent": None, "kind": "unclaimed",
         "aliases": ["بير طويل", "بئر طويل", "bir tawil", "bir tawil", "birtawil"], "label": b_label, "rings": b_rings},
    ]


def hdx_admin1():
    f = HDX_DIR / "egy_admin1.geojson"
    if not f.exists():
        HDX_DIR.mkdir(parents=True, exist_ok=True)
        r = requests.get(HDX_ZIP, timeout=600)
        r.raise_for_status()
        zipfile.ZipFile(io.BytesIO(r.content)).extractall(HDX_DIR)
    return json.loads(f.read_text(encoding="utf8"))["features"]


def get(name):
    r = requests.get(BASE + name, timeout=300)
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


def area_centroid(ring):
    """Signed area and centroid of a ring (shoelace), in degrees."""
    a = cx = cy = 0.0
    for i in range(len(ring) - 1):
        x0, y0 = ring[i]
        x1, y1 = ring[i + 1]
        cr = x0 * y1 - x1 * y0
        a += cr
        cx += (x0 + x1) * cr
        cy += (y0 + y1) * cr
    a /= 2
    if abs(a) < 1e-12:
        return 0.0, ring[0][0], ring[0][1]
    return a, cx / (6 * a), cy / (6 * a)


def main():
    governorates = []
    for f in hdx_admin1():
        p = f["properties"]
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        rings = [simplify_ring([tuple(q) for q in poly[0]], 0.006) for poly in polys]  # outer rings only
        rings = [r for r in rings if len(r) >= 4]
        big = max(rings, key=lambda r: abs(area_centroid(r)[0]))
        area, cx, cy = area_centroid(big)
        total = sum(abs(area_centroid(r)[0]) for r in rings)
        name = p["adm1_name"]
        governorates.append({
            "id": name, "ar": p["adm1_name1"].replace("مدينة ", ""), "delta": name in DELTA, "site": OWN_SITE.get(name),
            "label": [round(cx, 3), round(cy, 3)], "size": round(total ** 0.5, 3), "rings": [rnd(r) for r in rings],
        })
    governorates.sort(key=lambda g: g["id"])

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

    lake_polys = []
    for f in get("ne_10m_lakes.geojson")["features"]:
        if f["properties"].get("name") in ("Lake Nasser", "Great Bitter Lake"):
            g = f["geometry"]
            polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
            for p in polys:
                lake_polys.append({"name": f["properties"]["name"], "pts": rnd(simplify_ring([tuple(q) for q in p[0]], 0.01))})

    out = {
        "source": "Governorates: HDX COD-AB Egypt (CAPMAS via OCHA, CC BY-IGO), simplified to about 0.6 km. Rivers and lakes: Natural Earth (public domain), generalized.",
        "bbox": [24.5, 21.8, 36.95, 31.9], "governorates": governorates, "areas": named_areas(), "water": water, "lakes": lake_polys,
    }
    dest = ROOT / "app" / "assets" / "data" / "egypt_map.json"
    dest.write_text(json.dumps(out, separators=(",", ":"), ensure_ascii=False), encoding="utf8")
    print("wrote", dest.stat().st_size, "bytes;", len(governorates), "governorates,", sum(len(r) for g in governorates for r in g["rings"]), "points |",
          "water lines", len(water), "| lakes", len(lake_polys))
    print("delta:", [g["ar"] for g in governorates if g["delta"]])


if __name__ == "__main__":
    main()
