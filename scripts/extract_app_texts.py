"""Extract every user-facing piece of text from the Flutter app's source so the team can review the wording.

Reads app/lib/*.dart and writes docs/text_review/texts.json: a list of items
  {id, group, where, ar: {text, raw, file, line} | null, en: {...} | null}
Arabic and English are paired when the code pairs them (tr('..', '..'), BotMessage(.., en: ..)) or when a fixed table says
two sentences in different files are the same sentence (PAIRS below). ${...} placeholders (numbers and names filled in at run
time) are shown as {..}; `raw` keeps the source text so a changed wording can be written back exactly.

Run: .venv/Scripts/python scripts/extract_app_texts.py   then   scripts/make_text_review.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIB = ROOT / "app" / "lib"
OUT = ROOT / "docs" / "text_review"
AR = re.compile(r"[؀-ۿ]")


def read(name):
    return (LIB / name).read_bytes().decode("utf8").replace("\r\n", "\n")


def parse_string(src, i):
    q = src[i]
    if q not in "'\"" or src.startswith(q * 3, i):
        return None
    j, out = i + 1, []
    while j < len(src):
        c = src[j]
        if c == "\\":
            out.append(src[j:j + 2])
            j += 2
            continue
        if c == "$" and src[j + 1:j + 2] == "{":
            depth, k = 1, j + 2
            while k < len(src) and depth:
                depth += (src[k] == "{") - (src[k] == "}")
                k += 1
            out.append(src[j:k])
            j = k
            continue
        if c == q:
            return "".join(out), j + 1
        if c == "\n":
            return None
        out.append(c)
        j += 1
    return None


def show(raw):
    s = re.sub(r"\$\{([^}]*)\}", lambda m: "{" + (re.sub(r"[^A-Za-z0-9_.]+", " ", m.group(1)).strip().split(" ")[0] or "x") + "}", raw)
    s = re.sub(r"\$([A-Za-z_][A-Za-z0-9_]*)", r"{\1}", s)
    return s.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\").replace("\\$", "$")


def skip_ws(src, i):
    while i < len(src) and src[i] in " \t\n":
        i += 1
    return i


def line_of(src, i):
    return src.count("\n", 0, i) + 1


def in_comment(src, i):
    ls = src.rfind("\n", 0, i) + 1
    return "//" in src[ls:i]


def enclosing_method(src, pos):
    m = None
    for m in re.finditer(r"^\s{2}(?:Widget|String\??|Future<void>|void|List<Widget>|IconData\??|BotMessage)\s+(_?\w+)\(", src[:pos], re.M):
        pass
    return m.group(1) if m else ""


GROUPS = {
    "welcome.dart": "1. Setup screens",
    "flow.dart": "2. Question screen",
    "dialogue.dart": "3. Eyad's questions and replies",
    "map_picker.dart": "4. Map",
    "result_view.dart": "5. Result screen and detail sheets",
    "ui_kit.dart": "2. Question screen",
    "arabic.dart": "6. Notices and sentences",
    "i18n.dart": "6. Notices and sentences",
}
WHERE = {
    ("welcome.dart", "_welcomeBody"): "Setup screen 1 (welcome)", ("welcome.dart", "_what"): "Setup screen 2 (what Eyad helps with)",
    ("welcome.dart", "_how"): "Setup screen 3 (how to talk)", ("welcome.dart", "_topBar"): "Setup, top bar", ("welcome.dart", "build"): "Setup",
    ("flow.dart", "_question"): "Question screen", ("flow.dart", "_bottom"): "Question screen, bottom buttons", ("flow.dart", "_topBar"): "Question screen, top bar",
    ("flow.dart", "_toggleMic"): "Shown when the microphone is not available", ("flow.dart", "build"): "Shown if the data cannot load", ("flow.dart", "_answered"): "Question screen, summary chips",
    ("result_view.dart", "_headline"): "Result, headline", ("result_view.dart", "_heroArt"): "Result, picture readings", ("result_view.dart", "build"): "Result screen, text and buttons",
    ("result_view.dart", "_dialCard"): "Result, water card", ("result_view.dart", "_heatCard"): "Result, heat card", ("result_view.dart", "_saltCard"): "Result, salt card",
    ("result_view.dart", "_water"): "Result, Water sheet", ("result_view.dart", "_heat"): "Result, Heat sheet", ("result_view.dart", "_salt"): "Result, Salt sheet",
    ("result_view.dart", "_weather"): "Result, Weather sheet", ("result_view.dart", "_pill"): "Result, rotation tabs",
}

# Fixed table: (Arabic file, line, English file, line) = the same sentence in two files. k-th literal on a line pairs with the k-th on the other.
PAIRS = [
    ("arabic.dart", 34, "i18n.dart", 82), ("arabic.dart", 35, "i18n.dart", 83), ("arabic.dart", 36, "i18n.dart", 84),
    ("arabic.dart", 40, "i18n.dart", 106), ("arabic.dart", 42, "i18n.dart", 108), ("arabic.dart", 43, "i18n.dart", 109),
    ("dialogue.dart", 365, "i18n.dart", 114), ("dialogue.dart", 366, "i18n.dart", 115), ("dialogue.dart", 368, "i18n.dart", 117),
    ("dialogue.dart", 372, "i18n.dart", 100), ("dialogue.dart", 373, "i18n.dart", 101),
    ("dialogue.dart", 380, "i18n.dart", 93), ("dialogue.dart", 382, "i18n.dart", 94),
    ("dialogue.dart", 386, "i18n.dart", 123), ("dialogue.dart", 390, "i18n.dart", 127), ("dialogue.dart", 392, "i18n.dart", 129),
    ("dialogue.dart", 394, "i18n.dart", 130), ("dialogue.dart", 401, "i18n.dart", 134), ("dialogue.dart", 403, "i18n.dart", 136),
    ("dialogue.dart", 404, "i18n.dart", 137),
    ("dialogue.dart", 300, "dialogue.dart", 305), ("dialogue.dart", 302, "dialogue.dart", 307), ("dialogue.dart", 303, "dialogue.dart", 308),
]
# the same label in the two languages, paired by text (the answer buttons)
TEXT_PAIRS = [("كل {arDigits} يوم", "Every {c.value} days"), ("مش عارف", "I don't know"), ("مفيش علامات", "No signs"), ("في بقع", "Salty patches"),
              ("قشرة بيضاء", "White crust"), ("ابدأ من جديد", "Start again"), ("اقرأ النتيجة تاني", "Read it again")]
# internal strings and hidden messages: never shown to the farmer
SKIP = {("arabic.dart", 5), ("dialogue.dart", 39), ("dialogue.dart", 230), ("dialogue.dart", 245), ("dialogue.dart", 346), ("dialogue.dart", 348), ("dialogue.dart", 252)}


def main():
    side = []  # single-language literals: {lang, text, raw, file, line, pos, method}
    pairs = []  # explicit pairs from tr() and BotMessage

    def lit(file, src, pos, raw):
        return {"text": show(raw), "raw": raw, "file": file, "line": line_of(src, pos)}

    for f in sorted(LIB.glob("*.dart")):
        name = f.name
        src = read(name)
        for m in re.finditer(r"\btr\(", src):
            a = parse_string(src, skip_ws(src, m.end()))
            if not a:
                continue
            j = skip_ws(src, a[1])
            b = parse_string(src, skip_ws(src, j + 1)) if src[j] == "," else None
            if b and not in_comment(src, m.start()):
                pairs.append({"where": WHERE.get((name, enclosing_method(src, m.start()))) or enclosing_method(src, m.start()) or name, "file": name, "ar": lit(name, src, m.start(), a[0]), "en": lit(name, src, m.start(), b[0])})
        if name == "dialogue.dart":
            for m in re.finditer(r"BotMessage\(|_retry\(", src):
                a = parse_string(src, skip_ws(src, m.end()))
                if not a:
                    continue
                if m.group().startswith("_retry"):
                    b = parse_string(src, skip_ws(src, skip_ws(src, a[1]) + 1))
                else:
                    e = re.search(r"\ben:\s*", src[a[1]:a[1] + 700])
                    b = parse_string(src, a[1] + e.end()) if e else None
                if (name, line_of(src, m.start())) in SKIP:
                    continue
                pairs.append({"where": "Eyad's question or reply", "file": name, "ar": lit(name, src, m.start(), a[0]), "en": lit(name, src, m.start(), b[0]) if b else None})

    # generic single-language literals in the language files
    covered_ar = {(p["ar"]["file"], p["ar"]["raw"]) for p in pairs if p["ar"]}
    covered_en = {(p["en"]["file"], p["en"]["raw"]) for p in pairs if p["en"]}
    for name in ("arabic.dart", "dialogue.dart", "i18n.dart"):
        src = read(name)
        i = 0
        while i < len(src):
            if src[i] in "'\"" and (i == 0 or src[i - 1] not in "rR\\"):
                p = parse_string(src, i)
                if p:
                    raw, end = p
                    txt = show(raw)
                    ln = line_of(src, i)
                    ctx = src[max(0, i - 30):i]
                    internal = re.search(r"(contains|startsWith|RegExp|replaceAll|replaceFirst|import|part|firstWhere)\(\s*$", ctx) or ctx.rstrip().endswith("import")
                    if not in_comment(src, i) and not internal and (name, ln) not in SKIP:
                        if name == "dialogue.dart":
                            # keep only sentence pieces shown or read aloud; the parser words live in parse*/_unknown/month tables
                            if re.search(r"^(parse|_unknown|_areaByName|_governorateByName|normalizeAr)", src[:i].rsplit("\n", 1)[0][-0:] or "") or ln < 60 or 112 < ln < 140:
                                pass
                        if name != "i18n.dart" and AR.search(txt) and len(txt.strip()) >= 2 and (name, raw) not in covered_ar and not (name == "dialogue.dart" and (ln < 60 or 112 <= ln <= 140)):
                            side.append({"lang": "ar", **lit(name, src, i, raw), "method": enclosing_method(src, i)})
                        elif name == "dialogue.dart" and 305 <= ln <= 310 and re.search(r"[A-Za-z]{3,}", txt) and len(txt) > 20:
                            side.append({"lang": "en", **lit(name, src, i, raw), "method": enclosing_method(src, i)})
                        elif name == "i18n.dart" and re.search(r"[A-Za-z]{3,}", txt) and " " in txt.strip() and len(txt.strip()) >= 6 and (name, raw) not in covered_en and "assets" not in txt and not txt.startswith(("package", "dart")):
                            side.append({"lang": "en", **lit(name, src, i, raw), "method": enclosing_method(src, i)})
                    i = end
                    continue
            i += 1

    # fixed pairing of the same sentence across files
    by_line = {}
    for s in side:
        by_line.setdefault((s["file"], s["line"], s["lang"]), []).append(s)
    paired_ids = set()
    items = []
    for af, al, ef, el in PAIRS:
        ars = by_line.get((af, al, "ar"), [])
        ens = by_line.get((ef, el, "en"), [])
        for k in range(max(len(ars), len(ens))):
            a = ars[k] if k < len(ars) else None
            e = ens[k] if k < len(ens) else None
            if a: paired_ids.add(id(a))
            if e: paired_ids.add(id(e))
            items.append({"where": "Eyad's spoken summary and notices", "group": "6. Notices and sentences", "ar": a and {k2: a[k2] for k2 in ("text", "raw", "file", "line")}, "en": e and {k2: e[k2] for k2 in ("text", "raw", "file", "line")}})

    ar_by_text = {}
    for s in side:
        if s["lang"] == "ar":
            ar_by_text.setdefault(s["text"], s)
    en_by_text = {}
    for s in side:
        if s["lang"] == "en":
            en_by_text.setdefault(s["text"], s)
    for a_text, e_text in TEXT_PAIRS:
        a, e = ar_by_text.get(a_text), en_by_text.get(e_text)
        if a or e:
            if a: paired_ids.add(id(a))
            if e: paired_ids.add(id(e))
            items.append({"where": "Answer buttons", "group": "3. Eyad's questions and replies", "ar": a and {k2: a[k2] for k2 in ("text", "raw", "file", "line")}, "en": e and {k2: e[k2] for k2 in ("text", "raw", "file", "line")}})

    # name tables: places, crops, months, salt words (Arabic table and English table pair by key / position)
    def table(src, marker, as_map=True, end="}"):
        i = src.index(marker) + len(marker)
        stop = src.index(end if as_map else "]", i)
        vals, k = [], i
        while k < stop:
            if src[k] in "'\"":
                p = parse_string(src, k)
                if p:
                    vals.append((p[0], k))
                    k = p[1]
                    continue
            k += 1
        return vals

    ar_src, en_src = read("arabic.dart"), read("i18n.dart")
    def kv(vals):  # [(key, value)] from alternating literals
        return [(vals[n][0], vals[n + 1]) for n in range(0, len(vals) - 1, 2)]
    tables = [
        ("Place names", kv(table(ar_src, "const arSite = {")), kv(table(en_src, "const enSite = {"))),
        ("Crop names", kv(table(ar_src, "const arCrop = {")), kv(table(en_src, "const enCrop = {"))),
        ("Salt words", kv(table(ar_src, "const arSalt = {")), kv(table(en_src, "{'fine': 'Suitable'"[:1] + "'fine': 'Suitable'", ))) if False else None,
    ]
    tables = [t for t in tables if t]
    for label, a_kv, e_kv in tables:
        emap = dict(e_kv)
        for key, (val, pos) in a_kv:
            e = emap.get(key)
            items.append({"where": label, "group": "7. Names and words", "ar": {"text": show(val), "raw": val, "file": "arabic.dart", "line": line_of(ar_src, pos)},
                          "en": {"text": show(e[0]), "raw": e[0], "file": "i18n.dart", "line": line_of(en_src, e[1])} if e else None})
    # months (list against list)
    am = table(ar_src, "const arMonth = [", False, "];")
    em = table(en_src, "const enMonthNames = [", False, "];")
    for (a, ap), (e, ep) in zip(am, em):
        items.append({"where": "Month names", "group": "7. Names and words", "ar": {"text": a, "raw": a, "file": "arabic.dart", "line": line_of(ar_src, ap)}, "en": {"text": e, "raw": e, "file": "i18n.dart", "line": line_of(en_src, ep)}})
    # salt words
    sa = kv(table(ar_src, "const arSalt = {"))
    i0 = en_src.index("const {'fine': 'Suitable'")
    se = kv(table(en_src[i0:], "const {"))
    smap = dict(se)
    for key, (val, pos) in sa:
        e = smap.get(key)
        items.append({"where": "Salt words", "group": "7. Names and words", "ar": {"text": val, "raw": val, "file": "arabic.dart", "line": line_of(ar_src, pos)},
                      "en": {"text": e[0], "raw": e[0], "file": "i18n.dart", "line": line_of(en_src, i0 + e[1])} if e else None})

    # remaining single-language items (not paired, not in the tables above)
    table_lines = {(it["ar"]["file"], it["ar"]["line"]) for it in items if it.get("ar")} | {(it["en"]["file"], it["en"]["line"]) for it in items if it.get("en")}
    for s in side:
        if id(s) in paired_ids or (s["file"], s["line"]) in table_lines:
            continue
        m = s["method"]
        entry = {k2: s[k2] for k2 in ("text", "raw", "file", "line")}
        items.append({"where": WHERE.get((s["file"], m)) or "Eyad's sentence pieces", "group": GROUPS.get(s["file"], s["file"]), "ar": entry if s["lang"] == "ar" else None, "en": entry if s["lang"] == "en" else None})
    for p in pairs:
        items.append({"where": p["where"], "group": GROUPS.get(p["file"], p["file"]), "ar": p["ar"], "en": p["en"]})

    # drop single-language leftovers whose text already sits in a paired item, and pure templates (only placeholders)
    ar_done = {it["ar"]["raw"] for it in items if it["ar"] and it["en"]}
    en_done = {it["en"]["raw"] for it in items if it["en"] and it["ar"]}
    def has_words(s):
        return len(re.sub(r"[^A-Za-z\u0600-\u06FF]", "", re.sub(r"\{[^}]*\}", "", s["text"]))) >= 3
    items = [it for it in items
             if not ((it["ar"] and not it["en"] and it["ar"]["raw"] in ar_done) or (it["en"] and not it["ar"] and it["en"]["raw"] in en_done))
             and all(has_words(s) for s in (it["ar"], it["en"]) if s)]
    # drop exact duplicates, then number
    seen, final = set(), []
    for it in items:
        key = (it["ar"]["raw"] if it["ar"] else None, it["en"]["raw"] if it["en"] else None)
        if key in seen or not (it["ar"] or it["en"]):
            continue
        seen.add(key)
        final.append(it)
    final.sort(key=lambda it: (it["group"], (it["ar"] or it["en"])["file"], (it["ar"] or it["en"])["line"]))
    for n, it in enumerate(final, 1):
        it["id"] = n
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "texts.json").write_text(json.dumps(final, ensure_ascii=False, indent=1), encoding="utf8")
    both = sum(1 for it in final if it["ar"] and it["en"])
    print(len(final), "texts;", both, "with both languages;", sum(1 for it in final if it["ar"] and not it["en"]), "Arabic only;", sum(1 for it in final if it["en"] and not it["ar"]), "English only")
    by = {}
    for it in final:
        by[it["group"]] = by.get(it["group"], 0) + 1
    for g in sorted(by):
        print(f"  {by[g]:3d}  {g}")


if __name__ == "__main__":
    main()
