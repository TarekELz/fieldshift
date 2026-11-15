"""Local server for the Field Shift page. Standard library only, no install needed.

    python app/server.py            then open http://localhost:8765

Endpoints
  GET  /                 the page (app/index.html)
  GET  /api/sites        areas and their caveats
  POST /api/compare      JSON in, rotation comparison out (see rotation.compare_rotations)

The assistant behind the voice button is grounded: it only reads out what the engines return.
It never invents numbers.
"""
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import rotation  # noqa: E402

PAGE = ROOT / "app" / "index.html"
SITES = {k: v for k, v in rotation.load_sites().items()}


def parse_sequences(body):
    seqs = []
    for s in body.get("sequences", []):
        crop = s["summer_crop"]
        item = {"name": s.get("name") or f"{crop} then wheat", "summer_crop": crop, "wheat_sowing": tuple(int(x) for x in s["wheat_sowing"])}
        if s.get("summer_sowing"):
            item["summer_sowing"] = tuple(int(x) for x in s["summer_sowing"])
        seqs.append(item)
    return seqs


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload, ctype="application/json; charset=utf-8"):
        data = payload if isinstance(payload, bytes) else json.dumps(payload, ensure_ascii=False, default=str).encode("utf8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, PAGE.read_bytes(), "text/html; charset=utf-8")
        elif self.path == "/api/sites":
            self._send(200, {k: {"name": v["name_en"], "caveat": v.get("weather_caveat")} for k, v in SITES.items()})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/compare":
            return self._send(404, {"error": "not found"})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            res = rotation.compare_rotations(
                body.get("site", "gharbia"), parse_sequences(body), ece=body.get("ece"), signs=body.get("signs") or None,
                interval_days=int(body["interval_days"]) if body.get("interval_days") else None)
            self._send(200, res)
        except (ValueError, KeyError, TypeError) as e:  # bad input from the page: say so, do not crash
            self._send(400, {"error": str(e)})
        except FileNotFoundError:
            self._send(503, {"error": "NASA POWER weather files are missing: run src/fieldshift/ingest/fetch_power_sites.py"})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Field Shift on http://localhost:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
