"""Merge the answers of every friend into one decision page.

Put each friend's file (text_review_<name>.json, sent from the review page) in docs/text_review_answers/ (not committed: it holds
people's names and opinions, and it is outside the folder the preview server shares). Then run:
  .venv/Scripts/python scripts/collect_text_reviews.py
It writes docs/text_review_answers/decide.html (open it by double-clicking): for every text somebody wanted changed you see who said yes or no and the wordings
they suggested, and you pick one (or write your own). The page exports decisions_answers.json in the same format as the
review page, which scripts/apply_text_review.py applies to the app.
Options: --dir <folder with the friends' files>
"""
import argparse
import base64
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "text_review"
FONTS = ROOT / "app" / "assets" / "fonts"
ANS = ROOT / "docs" / "text_review_answers"


def font_css():
    out = []
    for fam, file, w in (("Plex", "IBMPlexSans-Regular.ttf", 400), ("Plex", "IBMPlexSans-SemiBold.ttf", 600), ("PlexAr", "IBMPlexSansArabic-Regular.ttf", 400), ("PlexAr", "IBMPlexSansArabic-SemiBold.ttf", 600)):
        b64 = base64.b64encode((FONTS / file).read_bytes()).decode()
        out.append('@font-face { font-family: "%s"; src: url(data:font/ttf;base64,%s); font-weight: %d; }' % (fam, b64, w))
    return chr(10).join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(ANS))
    args = ap.parse_args()
    texts_bytes = (OUT / "texts.json").read_bytes()
    version = hashlib.sha1(texts_bytes).hexdigest()[:10]
    items = json.loads(texts_bytes.decode("utf8"))
    by_id = {i["id"]: i for i in items}
    files = sorted(pathlib.Path(args.dir).glob("*.json"))
    friends, votes = [], {}
    for f in files:
        d = json.loads(f.read_text(encoding="utf8"))
        who = (d.get("reviewer") or f.stem.replace("text_review_", "")).strip() or f.stem
        if d.get("version") and d["version"] != version:
            print(f"WARNING {f.name}: made with a different version of the text list ({d['version']} vs {version}); ids may not match")
        friends.append({"name": who, "file": f.name, "approved": d.get("approved", 0), "to_change": d.get("to_change", 0)})
        for a in d["answers"]:
            it = by_id.get(a["id"])
            if not it:
                continue
            sug = {}
            for lang in ("ar", "en"):
                side = a.get(lang)
                if side and side.get("new") not in (None, "") and side["new"] != side["original"]:
                    sug[lang] = side["new"]
            votes.setdefault(a["id"], []).append({"who": who, "status": a["status"], "sug": sug, "note": a.get("note", "")})
    data = {"version": version, "items": items, "votes": votes, "friends": friends}
    html = HTML.replace("__FONTS__", font_css()).replace("__DATA__", json.dumps(data, ensure_ascii=False).replace("</", "<\\/"))
    ANS.mkdir(exist_ok=True)
    (ANS / "decide.html").write_text(html, encoding="utf8")
    voted = len(votes)
    wants = sum(1 for v in votes.values() if any(x["status"] == "no" for x in v))
    print(f"{len(friends)} friends: {', '.join(f['name'] for f in friends) or 'none'}")
    print(f"{voted} of {len(items)} texts have at least one answer; {wants} have at least one 'change'")
    print("wrote", ANS / "decide.html")


HTML = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Field Shift: decide the wording</title>
<style>
__FONTS__
:root { --bg:#F3F2EF; --card:#FFFFFF; --muted:#F0EEEA; --line:#E6E3DD; --text:#1B1D1F; --dim:#585D63; --accent:#0067AC; --onaccent:#fff; --ok:#1A7340; --warn:#9A5800; --shadow:0 8px 24px rgba(27,29,31,.10); }
@media (prefers-color-scheme: dark) { :root { --bg:#0F1113; --card:#1A1D21; --muted:#23272B; --line:#2E3338; --text:#ECEDEE; --dim:#A3A9AF; --accent:#62B2EC; --onaccent:#0B1A26; --ok:#5DC48A; --warn:#E3A33B; --shadow:none; } }
* { box-sizing:border-box; } body { margin:0; background:var(--bg); color:var(--text); font:16px/1.5 "Plex", system-ui, sans-serif; }
header, main { max-width:900px; margin:0 auto; padding:16px; } h1 { font-size:26px; margin:0 0 6px; font-weight:600; } h2 { font-size:19px; margin:26px 0 10px; font-weight:600; }
.dim { color:var(--dim); } .card { background:var(--card); border-radius:22px; padding:16px; margin:12px 0; box-shadow:var(--shadow); border:2px solid transparent; } .card.done { border-color:var(--ok); }
.langs { display:grid; grid-template-columns:1fr 1fr; gap:10px; } @media (max-width:640px) { .langs { grid-template-columns:1fr; } }
.lang { background:var(--muted); border-radius:14px; padding:8px 12px; } .lang b { display:block; font-size:12px; color:var(--dim); font-weight:600; }
.ar { direction:rtl; text-align:right; font-family:"PlexAr","Plex",sans-serif; font-size:19px; line-height:1.7; white-space:pre-line; } .en { white-space:pre-line; font-size:16px; }
.ph { display:inline-block; background:var(--card); border:1px dashed var(--dim); border-radius:8px; padding:0 6px; font-size:.8em; color:var(--dim); direction:ltr; font-family:ui-monospace,monospace; }
.votes { margin:8px 0; font-size:14px; } .y { color:var(--ok); font-weight:600; } .n { color:var(--warn); font-weight:600; }
.opt { display:block; background:var(--muted); border-radius:14px; padding:8px 12px; margin:6px 0; cursor:pointer; } .opt input { margin-right:8px; } .opt small { color:var(--dim); }
textarea { width:100%; font:inherit; background:var(--muted); color:var(--text); border:1px solid var(--line); border-radius:12px; padding:8px; min-height:56px; margin-top:4px; } textarea.ar { font-size:18px; }
button { font:inherit; cursor:pointer; border:0; border-radius:14px; padding:10px 16px; background:var(--accent); color:var(--onaccent); font-weight:600; } button.g { background:var(--muted); color:var(--text); }
.bar { position:sticky; top:0; background:var(--bg); border-bottom:1px solid var(--line); padding:10px 16px; z-index:3; } .bar-in { max-width:900px; margin:0 auto; display:flex; gap:12px; align-items:center; flex-wrap:wrap; }
.note { font-size:13px; color:var(--dim); } .hide { display:none !important; }
</style></head><body>
<header><h1>Field Shift: decide the wording</h1>
<p class="dim" id="who"></p>
<p class="dim">Only texts that at least one friend wanted changed are listed. For each one choose <b>Keep as is</b>, one friend's wording, or write your own. Texts nobody objected to stay as they are.</p></header>
<div class="bar"><div class="bar-in"><span id="prog"></span><button id="dl">Download decisions</button><button class="g" id="cp">Copy decisions</button><span class="note" id="msg"></span></div></div>
<main id="main"></main>
<script>
const D = __DATA__;
const $ = (s) => document.querySelector(s);
const esc = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
const ph = (s) => esc(s).replace(/\{[^}]*\}/g, (m) => '<span class="ph">' + m + '</span>');
const KEY = "fs_decide_" + D.version;
let dec = {}; try { dec = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
const shown = D.items.filter((i) => (D.votes[i.id] || []).some((v) => v.status === "no"));
const sugKey = (s) => (s.ar || "") + "\u0001" + (s.en || "");
function save() { try { localStorage.setItem(KEY, JSON.stringify(dec)); } catch (e) {} stats(); }
function stats() { const d = shown.filter((i) => dec[i.id] && dec[i.id].pick !== undefined).length; $("#prog").textContent = d + " of " + shown.length + " decided"; }
$("#who").textContent = D.friends.length + " friends answered: " + (D.friends.map((f) => f.name + " (" + f.approved + " yes, " + f.to_change + " changes)").join(" · ") || "nobody yet");
function render() {
  let html = "";
  const groups = [...new Set(shown.map((i) => i.group))];
  for (const g of groups) {
    html += "<h2>" + esc(g) + "</h2>";
    for (const it of shown.filter((x) => x.group === g)) {
      const v = D.votes[it.id], yes = v.filter((x) => x.status === "yes").map((x) => x.who), no = v.filter((x) => x.status === "no");
      const sugs = []; const seen = {};
      for (const x of no) { if (Object.keys(x.sug).length) { const k = sugKey(x.sug); if (!seen[k]) { seen[k] = { sug: x.sug, who: [] }; sugs.push(seen[k]); } seen[k].who.push(x.who); } }
      const d = dec[it.id] || {};
      html += '<div class="card' + (d.pick !== undefined ? " done" : "") + '" id="c' + it.id + '"><div class="note">#' + it.id + " · " + esc(it.where) + "</div>"
        + '<div class="langs">' + (it.ar ? '<div class="lang"><b>Arabic now</b><div class="ar">' + ph(it.ar.text) + "</div></div>" : "") + (it.en ? '<div class="lang"><b>English now</b><div class="en">' + ph(it.en.text) + "</div></div>" : "") + "</div>"
        + '<div class="votes"><span class="y">Yes:</span> ' + (esc(yes.join(", ")) || "nobody") + ' · <span class="n">Change:</span> ' + esc(no.map((x) => x.who).join(", ")) + "</div>"
        + no.filter((x) => x.note).map((x) => '<div class="note">' + esc(x.who) + " says: " + esc(x.note) + "</div>").join("")
        + '<label class="opt"><input type="radio" name="r' + it.id + '" ' + (d.pick === "keep" ? "checked" : "") + ' onchange="pick(' + it.id + ',\'keep\')">Keep as is</label>'
        + sugs.map((s, n) => '<label class="opt"><input type="radio" name="r' + it.id + '" ' + (d.pick === "s" + n ? "checked" : "") + ' onchange="pick(' + it.id + ',\'s' + n + '\')"><small>' + esc(s.who.join(", ")) + " suggest:</small>"
          + (s.sug.ar ? '<div class="ar">' + ph(s.sug.ar) + "</div>" : "") + (s.sug.en ? '<div class="en">' + ph(s.sug.en) + "</div>" : "") + "</label>").join("")
        + '<label class="opt"><input type="radio" name="r' + it.id + '" ' + (d.pick === "own" ? "checked" : "") + ' onchange="pick(' + it.id + ',\'own\')">My own wording</label>'
        + '<div ' + (d.pick === "own" ? "" : 'class="hide"') + ' id="own' + it.id + '">'
        + (it.ar ? '<textarea class="ar" dir="rtl" oninput="own(' + it.id + ',\'ar\',this.value)">' + esc(d.ar !== undefined ? d.ar : it.ar.text) + "</textarea>" : "")
        + (it.en ? '<textarea oninput="own(' + it.id + ',\'en\',this.value)">' + esc(d.en !== undefined ? d.en : it.en.text) + "</textarea>" : "") + "</div></div>";
      it._sugs = sugs;
    }
  }
  $("#main").innerHTML = html || '<p class="dim">Nobody asked for a change. Nothing to decide.</p>';
  stats();
}
function pick(id, p) { dec[id] = Object.assign(dec[id] || {}, { pick: p }); save(); const c = $("#c" + id); c.classList.add("done"); $("#own" + id).classList.toggle("hide", p !== "own"); }
function own(id, k, v) { dec[id] = Object.assign(dec[id] || {}, { [k]: v }); save(); }
function out() {
  const answers = [];
  for (const it of shown) {
    const d = dec[it.id]; if (!d || d.pick === undefined) continue;
    let ar = null, en = null;
    if (d.pick === "own") { ar = d.ar !== undefined ? d.ar : null; en = d.en !== undefined ? d.en : null; }
    else if (d.pick !== "keep") { const s = it._sugs[parseInt(d.pick.slice(1), 10)].sug; ar = s.ar || null; en = s.en || null; }
    const keep = d.pick === "keep";
    answers.push({ id: it.id, status: keep ? "yes" : "no", where: it.where,
      ar: it.ar && { file: it.ar.file, line: it.ar.line, original: it.ar.text, raw: it.ar.raw, new: keep ? null : ar },
      en: it.en && { file: it.en.file, line: it.en.line, original: it.en.text, raw: it.en.raw, new: keep ? null : en }, note: "" });
  }
  return { exported: new Date().toISOString(), version: D.version, reviewer: "decisions", total: D.items.length, approved: answers.filter((a) => a.status === "yes").length, to_change: answers.filter((a) => a.status === "no").length, answers };
}
$("#dl").onclick = () => { const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([JSON.stringify(out(), null, 1)], { type: "application/json" })); a.download = "decisions_answers.json"; a.click(); $("#msg").textContent = "Downloaded decisions_answers.json"; };
$("#cp").onclick = async () => { try { await navigator.clipboard.writeText(JSON.stringify(out())); $("#msg").textContent = "Copied."; } catch (e) { $("#msg").textContent = "Use Download instead."; } };
render();
</script></body></html>
"""

if __name__ == "__main__":
    main()
