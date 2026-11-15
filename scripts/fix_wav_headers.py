"""Repair the WAV headers of the Hamsa clips: the API returns a streaming-style header whose RIFF and data sizes are 0xFFFFFFFF, which Android's media player can reject.
Rewrites bytes 4..7 (RIFF size = file size - 8) and the data chunk size (file size - 44) in every app/assets/audio/*.wav. Safe to re-run.
Run: .venv/Scripts/python scripts/fix_wav_headers.py
"""
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]


def fix(b: bytes) -> bytes:
    """Return the WAV bytes with correct size fields (a 44-byte header with a 16-byte fmt chunk, as Hamsa writes it)."""
    if len(b) < 44 or b[:4] != b"RIFF" or b[8:12] != b"WAVE" or b[36:40] != b"data":
        return b
    out = bytearray(b)
    out[4:8] = struct.pack("<I", len(b) - 8)
    out[40:44] = struct.pack("<I", len(b) - 44)
    return bytes(out)


def main():
    n = 0
    for f in sorted((ROOT / "app" / "assets" / "audio").glob("*.wav")):
        b = f.read_bytes()
        g = fix(b)
        if g != b:
            f.write_bytes(g)
            n += 1
    print("repaired", n, "file(s)")


if __name__ == "__main__":
    main()
