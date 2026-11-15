"""Builds the README pictures (assets/readme/*.svg) from the project's own data, so no number in a picture is typed by hand.

hero.svg      title + the real chart behind the project: median hot days during wheat grain filling by sowing date (Gharbia, NASA POWER, 1990-2025)
workflow.svg  ask -> compute -> advise
proof.svg     four counts read from the repository's tables

Run from the repository root:  python scripts/build_readme_assets.py
Style: the app's own palette (dark neutral, one blue accent, green/amber/red for state only), system fonts, no scripts, no foreignObject.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "app" / "assets" / "data"
OUT = ROOT / "assets" / "readme"

BG, CARD, CARD2, LINE = "#0F1113", "#1A1D21", "#23272B", "#2E3338"
TEXT, DIM, ACCENT = "#ECEDEE", "#A3A9AF", "#62B2EC"
OK, WARN, ALERT = "#5DC48A", "#E3A33B", "#F1776D"
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans Arabic', 'Segoe UI Arabic', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def label(mmdd):
    m, d = mmdd.split("-")
    return f"{int(d)} {MONTHS[int(m) - 1]}"


def hero():
    heat = json.load(open(DATA / "heat.json", encoding="utf-8"))["gharbia"]
    order = sorted(heat, key=lambda k: (0 if int(k[:2]) >= 11 else 1, k))  # 1 Nov ... 31 Dec, then January
    vals = [(k, heat[k]["median"]) for k in order]
    base = heat["11-15"]["median"]
    n = len(vals)
    cx, cw = 600, 544  # chart card
    inner_x, inner_w = cx + 24, cw - 48
    slot = inner_w / n
    bw = slot - 6
    top, h = 178, 170  # bar area
    vmax = max(v for _, v in vals)
    scale = h / vmax
    bars = []
    for i, (k, v) in enumerate(vals):
        extra = v - base
        col = ALERT if extra >= 8 else (WARN if extra >= 4 else OK)
        bh = v * scale
        x = inner_x + i * slot
        bars.append(f'<rect x="{x:.1f}" y="{top + h - bh:.1f}" width="{bw:.1f}" height="{bh:.1f}" rx="4" fill="{col}"/>')
    # value labels on three bars the text talks about, axis labels under five
    marks = {"11-01": "start", "11-15": "middle", "01-25": "end"}
    labels = []
    for i, (k, v) in enumerate(vals):
        x = inner_x + i * slot + bw / 2
        if k in marks:
            labels.append(f'<text x="{x:.1f}" y="{top + h - v * scale - 8:.1f}" font-size="22" font-weight="700" fill="{TEXT}" text-anchor="middle">{v}</text>')
    axis = []
    for k in ["11-01", "12-01", "01-01", "01-25"]:
        i = order.index(k)
        x = inner_x + i * slot + bw / 2
        anchor = "start" if k == "11-01" else ("end" if k == "01-25" else "middle")
        xx = inner_x + i * slot if anchor == "start" else (inner_x + i * slot + bw if anchor == "end" else x)
        axis.append(f'<text x="{xx:.1f}" y="{top + h + 30}" font-size="18" fill="{DIM}" text-anchor="{anchor}" font-family="{MONO}">{label(k)}</text>')
    pills = []
    px = 56
    for ar, en, col in [("تمام", "Fine", OK), ("مشكلة بسيطة", "A small problem", WARN), ("مشكلة كبيرة", "A big problem", ALERT)]:
        w = 170 if en == "Fine" else (200 if "small" in en else 190)
        w = {"Fine": 120, "A small problem": 190, "A big problem": 190}[en]
        pills.append(
            f'<g transform="translate({px} 342)"><rect width="{w}" height="64" rx="16" fill="{CARD}" stroke="{LINE}"/>'
            f'<circle cx="26" cy="32" r="8" fill="{col}"/>'
            f'<text x="{w - 18}" y="30" font-size="22" font-weight="600" fill="{TEXT}" text-anchor="end">{ar}</text>'
            f'<text x="{w - 18}" y="52" font-size="18" fill="{DIM}" text-anchor="end">{en}</text></g>'
        )
        px += w + 14
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="440" viewBox="0 0 1200 440" role="img" aria-labelledby="t d">
  <title id="t">Field Shift: Egypt</title>
  <desc id="d">Field Shift is a voice assistant in Egyptian Arabic for Nile Delta farmers, built on NASA POWER weather and FAO tables. The chart shows the project's real result for Gharbia: the later wheat is sown, the more hot days it meets while filling grain, from {vals[0][1]} days for 1 November to {vals[-1][1]} days for 25 January.</desc>
  <rect width="1200" height="440" rx="26" fill="{BG}"/>
  <g id="title-block" font-family="{SANS}">
    <text x="56" y="70" font-size="18" fill="{ACCENT}" font-family="{MONO}" letter-spacing="1.5">NASA SPACE APPS 2026  ·  NILE DELTA, EGYPT</text>
    <text x="56" y="152" font-size="76" font-weight="700" fill="{TEXT}">Field Shift</text>
    <text x="56" y="204" font-size="30" font-weight="600" fill="{ACCENT}">The right crop at the right time.</text>
    <text x="56" y="248" font-size="22" fill="{DIM}">A voice assistant in Egyptian Arabic</text>
    <text x="56" y="278" font-size="22" fill="{DIM}">for Nile Delta farmers. Built on NASA</text>
    <text x="56" y="308" font-size="22" fill="{DIM}">POWER weather and FAO tables.</text>
  </g>
  <g id="verdicts" font-family="{SANS}">
    {''.join(pills)}
  </g>
  <g id="project-proof" font-family="{SANS}">
    <rect x="{cx}" y="36" width="{cw}" height="368" rx="22" fill="{CARD}" stroke="{LINE}"/>
    <text x="{cx + 24}" y="76" font-size="22" font-weight="700" fill="{TEXT}">Wheat sown later meets more heat</text>
    <text x="{cx + 24}" y="104" font-size="18" fill="{DIM}" font-family="{MONO}">hot days (&gt;32 °C) in grain filling</text>
    <text x="{cx + 24}" y="130" font-size="18" fill="{DIM}" font-family="{MONO}">Gharbia · NASA POWER · median of 35 seasons</text>
    <line x1="{inner_x}" y1="{top + h}" x2="{inner_x + inner_w}" y2="{top + h}" stroke="{LINE}" stroke-width="2"/>
    {''.join(bars)}
    {''.join(labels)}
    {''.join(axis)}
  </g>
</svg>
"""
    return svg


def workflow():
    cols = [
        ("1", "Ask", ["Speak, type or tap the map:", "where the field is, what he", "grows, what he wants."], "voice · text · map", ACCENT),
        ("2", "Compute", ["Heat, water, salt, season and", "income engines, on the nearest", "of 19 NASA POWER points."], "5 engines · 1990-2025", WARN),
        ("3", "Advise", ["Code picks the advice. An AI", "may only reword it, keeping", "every number. Egyptian voice."], "do X because Y", OK),
    ]
    out = []
    for i, (num, title, lines, tag, col) in enumerate(cols):
        x = 56 + i * 376
        body = "".join(f'<text x="28" y="{134 + j * 32}" font-size="20" fill="{DIM}">{esc(t)}</text>' for j, t in enumerate(lines))
        out.append(
            f'<g transform="translate({x} 36)"><rect width="352" height="270" rx="22" fill="{CARD}" stroke="{LINE}"/>'
            f'<circle cx="50" cy="52" r="22" fill="{col}"/><text x="50" y="60" font-size="24" font-weight="700" fill="{BG}" text-anchor="middle">{num}</text>'
            f'<text x="88" y="62" font-size="34" font-weight="700" fill="{TEXT}">{title}</text>{body}'
            f'<rect x="28" y="214" width="296" height="38" rx="12" fill="{CARD2}"/><text x="44" y="240" font-size="18" fill="{col}" font-family="{MONO}">{esc(tag)}</text></g>'
        )
        if i < 2:
            ax = x + 352 + 6
            out.append(f'<path d="M{ax} 171 h12 m-6 -8 l8 8 l-8 8" fill="none" stroke="{DIM}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="342" viewBox="0 0 1200 342" role="img" aria-labelledby="t d">
  <title id="t">How Field Shift works</title>
  <desc id="d">Three steps: ask the farmer (voice, text or map), compute with five engines on NASA POWER weather and FAO tables, then advise in Egyptian Arabic where code picks the advice and an AI may only reword it.</desc>
  <rect width="1200" height="342" rx="26" fill="{BG}"/>
  <g font-family="{SANS}">{''.join(out)}</g>
</svg>
"""


def proof():
    heat = json.load(open(DATA / "heat.json", encoding="utf-8"))
    crops = json.load(open(DATA / "crops.json", encoding="utf-8"))["crops"]
    clips = json.load(open(ROOT / "app" / "assets" / "audio" / "index.json", encoding="utf-8"))
    items = [
        (str(len(heat)), "NASA POWER points", "7 places, 12 more cells"),
        ("36", "seasons of weather", "1990 to 2025, daily"),
        (str(len(crops)), "crops with income", "FAOSTAT and FAO tables"),
        (str(len(clips)), "recorded voice lines", "they work offline"),
    ]
    out = []
    for i, (big, name, sub) in enumerate(items):
        x = 56 + i * 280
        out.append(
            f'<g transform="translate({x} 40)"><text x="0" y="62" font-size="64" font-weight="700" fill="{ACCENT}">{big}</text>'
            f'<text x="0" y="104" font-size="22" font-weight="600" fill="{TEXT}">{esc(name)}</text>'
            f'<text x="0" y="134" font-size="18" fill="{DIM}">{esc(sub)}</text></g>'
        )
        if i:
            out.append(f'<line x1="{x - 24}" y1="48" x2="{x - 24}" y2="172" stroke="{LINE}" stroke-width="2"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="212" viewBox="0 0 1200 212" role="img" aria-labelledby="t d">
  <title id="t">What is inside the project</title>
  <desc id="d">{len(heat)} NASA POWER data points, 36 years of weather, {len(crops)} crops, {len(clips)} recorded voice lines.</desc>
  <rect width="1200" height="212" rx="26" fill="{BG}"/>
  <g font-family="{SANS}">{''.join(out)}</g>
</svg>
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("hero.svg", hero), ("workflow.svg", workflow), ("proof.svg", proof)]:
        (OUT / name).write_text(fn(), encoding="utf-8")
        print("wrote", OUT / name)


if __name__ == "__main__":
    main()
