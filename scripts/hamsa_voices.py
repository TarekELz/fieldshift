"""List Hamsa Arabic text-to-speech voices (Egyptian dialect, male) so a voice can be chosen by listening.
Needs HAMSA_API_KEY in .env (gitignored). Read-only: it lists voices and prints their sample URLs; it generates no audio and spends no credit.
Run: .venv/Scripts/python scripts/hamsa_voices.py
"""
import pathlib
import sys

import requests

ROOT = pathlib.Path(__file__).resolve().parents[1]
B = "https://api.tryhamsa.com"


def key():
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("HAMSA_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("HAMSA_API_KEY missing in .env")


def main():
    h = {"Authorization": f"Token {key()}"}
    p = requests.get(f"{B}/v1/projects/by-api-key", headers=h, timeout=60)
    print("project:", p.status_code, (p.json().get("data") or {}).get("name") if p.ok else p.text[:150])
    if not p.ok:
        return 1
    pid = p.json()["data"]["id"]
    out = []
    page = 1
    while True:
        r = requests.get(f"{B}/v2/tts/voices", headers=h, timeout=60,
                         params={"page": page, "perPage": 50, "source": "jobs", "projectId": pid, "all": "true", "language": ["ar"]})
        if not r.ok:
            print("voices:", r.status_code, r.text[:200])
            return 1
        d = r.json()["data"]
        out += d["voices"]
        if page >= d.get("totalPages", 1):
            break
        page += 1
    print("arabic voices:", len(out))
    for v in out:
        dia = (v.get("dialect") or {}).get("name")
        print(f"- {v['name']:<22} dialect={dia} tags={v.get('tags')} id={v['id']}\n    sample: {(v.get('voiceRecord') or '')[:110]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
