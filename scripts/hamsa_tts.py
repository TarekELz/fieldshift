"""Generate Eyad's fixed spoken lines with the Hamsa Egyptian voice (decision D18) and save them as audio clips.

Reads HAMSA_API_KEY, HAMSA_API_KEY_2, ... from .env (gitignored) and tries the next key when one fails. The clips are saved to
app/assets/audio/<hash>.mp3 (or .wav) and listed in app/assets/audio/index.json (text -> file) so the app can play a clip instead of the phone's voice.
The voice is AI-generated: it is disclosed in docs/ai-disclosure.md and the app shows an AI label while a generated voice speaks.

Run: .venv/Scripts/python scripts/hamsa_tts.py --test            (one short line, prints the cost the API reports)
     .venv/Scripts/python scripts/hamsa_tts.py                   (all fixed lines in scripts/spoken_lines.json; existing clips are skipped)
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
import time

import requests

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from fix_wav_headers import fix as fix_wav  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "app" / "assets" / "audio"
B = "https://api.tryhamsa.com"
VOICE_ID = "8f329168-6604-4f13-9572-994984f894c4"  # Ibrahim (Egyptian male, enthusiastic / educational / conversational), chosen by Tarek


def keys():
    out = []
    for line in (ROOT / ".env").read_text().splitlines():
        if re.match(r"HAMSA_API_KEY(_\d+)?=", line):
            v = line.split("=", 1)[1].strip()
            if v:
                out.append(v)
    return out


def clip_name(text):
    return hashlib.sha1(text.strip().encode("utf8")).hexdigest()[:16]


def generate(text, ks, wait_s=90):
    last = "no key"
    for k in ks:
        h = {"Authorization": f"Token {k}", "Content-Type": "application/json"}
        try:
            r = requests.post(f"{B}/v1/jobs/text-to-speech", headers=h, json={"voiceId": VOICE_ID, "text": text}, timeout=60)
            if not r.ok:
                last = f"{r.status_code} {r.text[:120]}"
                continue
            job = r.json()["data"]
            t0 = time.time()
            while time.time() - t0 < wait_s:
                url = (job.get("jobResponse") or {}).get("ttsMediaFile") or job.get("mediaUrl")
                if job.get("status") == "COMPLETED" and url:
                    a = requests.get(url, timeout=90)
                    a.raise_for_status()
                    return a.content, url, job.get("totalCost")
                if job.get("status") == "FAILED":
                    last = "job failed"
                    break
                time.sleep(2)
                g = requests.get(f"{B}/v1/jobs", headers=h, params={"jobId": job["id"]}, timeout=60)
                job = g.json()["data"] if g.ok else job
            else:
                last = "timeout"
        except requests.RequestException as e:
            last = type(e).__name__
    raise RuntimeError(last)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", action="store_true")
    a = ap.parse_args()
    ks = keys()
    OUT.mkdir(parents=True, exist_ok=True)
    if a.test:
        data, url, cost = generate("أهلاً بيك، أنا إياد. احكيلي عن أرضك.", ks)
        ext = ".mp3" if url.split("?")[0].lower().endswith(".mp3") else (".wav" if ".wav" in url.lower() else ".mp3")
        (OUT / ("_test" + ext)).write_bytes(data)
        print("ok", len(data), "bytes", ext, "cost reported:", cost)
        return 0
    lines = json.loads((ROOT / "scripts" / "spoken_lines.json").read_text(encoding="utf8"))
    idx_path = OUT / "index.json"
    idx = json.loads(idx_path.read_text(encoding="utf8")) if idx_path.exists() else {}
    bad = 0
    for text in lines:
        if text in idx and (OUT / idx[text]).exists():
            continue
        try:
            data, url, cost = generate(text, ks)
        except RuntimeError as e:
            print("FAILED", text[:40], e)
            bad += 1
            continue
        ext = ".wav" if ".wav" in url.lower().split("?")[0] else ".mp3"
        name = clip_name(text) + ext
        (OUT / name).write_bytes(fix_wav(data) if name.endswith('.wav') else data)
        idx[text] = name
        idx_path.write_text(json.dumps(idx, ensure_ascii=False, indent=1), encoding="utf8")
        print("ok", name, len(data), "bytes, cost", cost, "|", text[:40], flush=True)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
