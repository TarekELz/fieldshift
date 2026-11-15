"""Make the Android launcher icon from Eyad's avatar (app/assets/eyad/eyad_main.jpg, AI-generated, see app/assets/eyad/ABOUT.txt).

A small "AI" badge goes in the bottom-right corner, as on every other place the avatar is shown. Writes:
- mipmap-*/ic_launcher.png (legacy, round-cornered square) for mdpi to xxxhdpi;
- mipmap-*/ic_launcher_foreground.png and mipmap-anydpi-v26/ic_launcher.xml (adaptive icon). The face sits inside the
  central 66% safe zone, so launchers that crop to a circle or a squircle do not cut it.
Needs only Pillow. Run: python scripts/make_app_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "app" / "assets" / "eyad" / "eyad_main.jpg"
RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
FONT = ROOT / "app" / "assets" / "fonts" / "IBMPlexSans-SemiBold.ttf"
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
BG = "#62B2EC"  # the app's accent blue (ui_kit.dart)


def badge(img, box):
    """Draw the "AI" mark: a light rounded tag with dark text, inside box (x0, y0, x1, y1)."""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=(y1 - y0) // 4, fill="#F3F1E8", outline="#0B1A12", width=max(1, (y1 - y0) // 14))
    font = ImageFont.truetype(str(FONT), int((y1 - y0) * 0.62))
    tw = d.textlength("AI", font=font)
    d.text(((x0 + x1 - tw) / 2, y0 + (y1 - y0) * 0.12), "AI", font=font, fill="#0B1A12")


def legacy(size):
    face = Image.open(SRC).convert("RGB").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 5, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(face, (0, 0), mask)
    b = int(size * 0.34)
    badge(out, (size - b - size // 20, size - int(b * 0.6) - size // 20, size - size // 20, size - size // 20))
    return out


def foreground(size):
    """Adaptive foreground: the face as a circle inside the safe zone (66% of the canvas), the badge still inside it."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    safe = int(size * 0.66)
    off = (size - safe) // 2
    face = Image.open(SRC).convert("RGB").resize((safe, safe), Image.LANCZOS)
    mask = Image.new("L", (safe, safe), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, safe - 1, safe - 1), fill=255)
    out.paste(face, (off, off), mask)
    b = int(safe * 0.36)
    x1, y1 = off + safe - safe // 20, off + safe - safe // 20
    badge(out, (x1 - b, y1 - int(b * 0.6), x1, y1))
    return out


def main():
    for dpi, px in LEGACY.items():
        legacy(px).save(RES / f"mipmap-{dpi}" / "ic_launcher.png")
    for dpi, px in ADAPTIVE.items():
        foreground(px).save(RES / f"mipmap-{dpi}" / "ic_launcher_foreground.png")
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf8")
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{BG}</color>\n</resources>\n', encoding="utf8")
    print("icons written to", RES)


if __name__ == "__main__":
    main()
