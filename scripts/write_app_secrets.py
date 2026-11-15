"""Write app/assets/secrets/secrets.json from .env so a build can call Gemini (decision D18: keys inside the APK, tried in turn when one runs out).
The file is gitignored and must never be committed. Anyone holding the APK can extract these keys: delete them after the hackathon.
Run before `flutter build apk`: .venv/Scripts/python scripts/write_app_secrets.py   (add --none to remove the file: a build without keys)
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "app" / "assets" / "secrets" / "secrets.json"


def main():
    if "--none" in sys.argv:
        OUT.unlink(missing_ok=True)
        print("removed", OUT)
        return
    ks = [l.split("=", 1)[1].strip() for l in (ROOT / ".env").read_text().splitlines() if re.match(r"GEMINI_API_KEY(_\d+)?=", l) and l.split("=", 1)[1].strip()]
    OUT.write_text(json.dumps({"gemini": ks}), encoding="utf8")
    print("wrote", len(ks), "key(s) to", OUT, "(gitignored)")


if __name__ == "__main__":
    main()
