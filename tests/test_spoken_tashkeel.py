"""The voweled text that is sent to the voice (scripts/spoken_tashkeel*.json) must be the plain line plus marks, nothing else.

A bug once replaced the last letter of many words with a control character (a literal U+0001 instead of the backreference \1 in add_tashkeel.py), so
38 lines were sent to the voice with letters missing. The round-trip check (scripts/check_clips_roundtrip.py) found it. These tests keep it from coming back.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARK = re.compile("[ً-ْٰ]")


def load(name):
    f = ROOT / "scripts" / name
    return json.loads(f.read_text(encoding="utf8")) if f.exists() else {}


def test_no_control_characters_in_voweled_text():
    for name in ("spoken_tashkeel.json", "spoken_tashkeel_manual.json"):
        for k, v in load(name).items():
            assert not any(ord(c) < 32 and c not in "\n\t" for c in v), (name, k)


def test_voweled_text_is_the_plain_text_plus_marks():
    for name in ("spoken_tashkeel.json", "spoken_tashkeel_manual.json"):
        for k, v in load(name).items():
            assert MARK.sub("", v) == MARK.sub("", k), (name, k, v)


def test_final_letters_keep_their_letter_when_marks_are_dropped():
    import sys

    sys.path.insert(0, str(ROOT / "scripts"))
    import add_tashkeel  # noqa: E402  (reads .env only when keys() is called)

    assert add_tashkeel.egyptian("المَحْصُولُ، الصَّيْفِيُّ") == "المَحْصُول، الصَّيْفِي"
