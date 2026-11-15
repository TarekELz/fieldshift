"""Build docs/text_review/index.html: a self-contained page where every text of the app is a yes/no question.

Input: docs/text_review/texts.json (scripts/extract_app_texts.py). The page keeps the reviewer's answers in the browser
(localStorage) and exports them as JSON; scripts/apply_text_review.py writes approved changes back into the Dart source.
Run: .venv/Scripts/python scripts/make_text_review.py
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "text_review"
FONTS = ROOT / "app" / "assets" / "fonts"

items = json.loads((OUT / "texts.json").read_text(encoding="utf8"))
import base64
import hashlib


def font_css():
    """The four IBM Plex faces embedded as data URIs, so the page is one file that works offline on a phone."""
    out = []
    for fam, file, w in (("Plex", "IBMPlexSans-Regular.ttf", 400), ("Plex", "IBMPlexSans-SemiBold.ttf", 600), ("PlexAr", "IBMPlexSansArabic-Regular.ttf", 400), ("PlexAr", "IBMPlexSansArabic-SemiBold.ttf", 600)):
        b64 = base64.b64encode((FONTS / file).read_bytes()).decode()
        out.append('@font-face { font-family: "%s"; src: url(data:font/ttf;base64,%s); font-weight: %d; }' % (fam, b64, w))
    return chr(10).join(out)

data = json.dumps(items, ensure_ascii=False).replace("</", "<\\/")

HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Field Shift: text review</title>
<style>
__FONTS__
:root { --bg:#F3F2EF; --card:#FFFFFF; --muted:#F0EEEA; --line:#E6E3DD; --text:#1B1D1F; --dim:#585D63; --accent:#0067AC; --onaccent:#fff; --ok:#1A7340; --warn:#9A5800; --shadow:0 8px 24px rgba(27,29,31,.10); }
@media (prefers-color-scheme: dark) { :root { --bg:#0F1113; --card:#1A1D21; --muted:#23272B; --line:#2E3338; --text:#ECEDEE; --dim:#A3A9AF; --accent:#62B2EC; --onaccent:#0B1A26; --ok:#5DC48A; --warn:#E3A33B; --shadow:none; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--text); font:16px/1.5 "Plex", system-ui, sans-serif; }
header { padding:20px 16px 8px; max-width:880px; margin:0 auto; }
h1 { font-size:26px; margin:0 0 6px; font-weight:600; }
.lead { color:var(--dim); margin:0 0 4px; }
.bar { position:sticky; top:0; z-index:5; background:var(--bg); border-bottom:1px solid var(--line); padding:10px 16px; }
.bar-in { max-width:880px; margin:0 auto; display:flex; flex-wrap:wrap; gap:8px 14px; align-items:center; }
.prog { flex:1 1 220px; }
.prog .track { height:8px; background:var(--muted); border-radius:6px; overflow:hidden; display:flex; }
.prog .ok { background:var(--ok); } .prog .no { background:var(--warn); }
.prog small { color:var(--dim); }
.chips { display:flex; flex-wrap:wrap; gap:6px; }
button { font:inherit; cursor:pointer; border:0; border-radius:14px; padding:10px 16px; background:var(--muted); color:var(--text); font-weight:600; }
button.on { background:var(--accent); color:var(--onaccent); }
button.yes { background:var(--ok); color:#fff; } button.no { background:var(--warn); color:#fff; }
button.ghost { background:transparent; border:1px solid var(--line); }
main { max-width:880px; margin:0 auto; padding:8px 16px 80px; }
h2 { font-size:19px; margin:28px 0 10px; font-weight:600; }
.card { background:var(--card); border-radius:22px; padding:16px; margin:12px 0; box-shadow:var(--shadow); border:2px solid transparent; }
.card.yes { border-color:var(--ok); } .card.no { border-color:var(--warn); }
.where { color:var(--dim); font-size:13px; margin-bottom:8px; }
.langs { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
@media (max-width:640px) { .langs { grid-template-columns:1fr; } }
.lang { background:var(--muted); border-radius:14px; padding:10px 12px; }
.lang b { display:block; font-size:12px; color:var(--dim); font-weight:600; margin-bottom:2px; }
.ar { direction:rtl; text-align:right; font-family:"PlexAr", "Plex", sans-serif; font-size:20px; line-height:1.7; white-space:pre-line; }
.en { direction:ltr; font-size:17px; white-space:pre-line; }
.ph { display:inline-block; background:var(--card); border:1px dashed var(--dim); border-radius:8px; padding:0 6px; font-size:.8em; color:var(--dim); direction:ltr; font-family:ui-monospace, monospace; }
.q { margin:12px 0 8px; font-weight:600; }
.actions { display:flex; gap:10px; flex-wrap:wrap; }
.edit { margin-top:10px; display:none; }
.card.no .edit { display:block; }
.edit label { display:block; font-size:13px; color:var(--dim); margin:8px 0 3px; }
textarea { width:100%; font:inherit; background:var(--muted); color:var(--text); border:1px solid var(--line); border-radius:12px; padding:10px; min-height:64px; }
textarea.ar { font-size:19px; }
.note { font-size:13px; color:var(--dim); }
.hide { display:none !important; }
.sum { background:var(--card); border-radius:22px; padding:16px; margin:16px 0; box-shadow:var(--shadow); }
.sum button { margin:4px 6px 4px 0; }
code { font-family:ui-monospace, monospace; font-size:12px; color:var(--dim); }
</style>
</head>
<body>
<header>
  <h1>Field Shift: text review</h1>
  <p class="lead">Thank you for helping! Field Shift is an app for Nile Delta farmers. Below is every text in it. For each one: <b>is this wording OK?</b> Press <b>Yes</b> to keep it, or <b>No, change it</b> and write what it should say. It takes about 10 to 15 minutes, and you can stop and come back.</p>
  <p class="lead" dir="rtl" style="font-family:PlexAr,sans-serif">شكراً لمساعدتك! ده تطبيق لمزارعي دلتا النيل. تحت كل النصوص اللي فيه. لكل نص اضغط <b>Yes</b> لو الكلام مظبوط، أو <b>No, change it</b> واكتب الصيغة اللي تحبها.</p>
  <p class="lead"><b>Your name / اسمك:</b> <input id="who" placeholder="e.g. Youssef" style="font:inherit;padding:8px 12px;border-radius:12px;border:1px solid var(--line);background:var(--card);color:var(--text)"></p>
  <p class="lead">Words in <span class="ph">{dashed boxes}</span> are numbers and names the app fills in. Keep them where they make sense. Your answers save in this browser as you go.</p>
</header>
<div class="bar"><div class="bar-in">
  <div class="prog"><div class="track"><div class="ok" id="pok"></div><div class="no" id="pno"></div></div><small id="ptxt"></small></div>
  <div class="chips" id="filters"></div>
</div></div>
<main id="main"></main>
<main>
  <div class="sum">
    <b>When you finish</b>
    <p class="note">Write your name at the top, then press <b>Send my answers</b> and pick WhatsApp or Telegram to send them to Tarek. If that does not open, press <b>Download answers</b> and send the file, or <b>Copy answers</b> and paste them in a message.</p>
    <button class="on" id="send">Send my answers</button><button id="dl">Download answers</button><button id="cp">Copy answers</button><button class="ghost" id="reset">Clear all answers</button>
    <p class="note" id="msg"></p>
  </div>
</main>
<script>
const ITEMS = __DATA__;
const KEY = "fs_text_review_v1";
let ans = {};
try { ans = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) { ans = {}; }
let filter = "all";
const $ = (s) => document.querySelector(s);
const esc = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
const ph = (s) => esc(s).replace(/\{[^}]*\}/g, (m) => '<span class="ph">' + m + '</span>');
function save() { try { localStorage.setItem(KEY, JSON.stringify(ans)); } catch (e) {} stats(); }
function stats() {
  const n = ITEMS.length, y = ITEMS.filter((i) => ans[i.id] && ans[i.id].status === "yes").length, no = ITEMS.filter((i) => ans[i.id] && ans[i.id].status === "no").length;
  $("#pok").style.width = (100 * y / n) + "%"; $("#pno").style.width = (100 * no / n) + "%";
  $("#ptxt").textContent = (y + no) + " of " + n + " reviewed · " + y + " approved · " + no + " to change · " + (n - y - no) + " left";
}
function render() {
  const groups = [...new Set(ITEMS.map((i) => i.group))];
  let html = "";
  for (const g of groups) {
    html += '<h2 data-g="' + esc(g) + '">' + esc(g) + "</h2>";
    for (const it of ITEMS.filter((x) => x.group === g)) {
      const a = ans[it.id] || {};
      const st = a.status || "";
      const hidden = (filter === "todo" && st) || (filter === "yes" && st !== "yes") || (filter === "no" && st !== "no");
      html += '<div class="card ' + st + (hidden ? " hide" : "") + '" id="c' + it.id + '">'
        + '<div class="where">#' + it.id + " · " + esc(it.where) + "</div>"
        + '<div class="langs">'
        + (it.ar ? '<div class="lang"><b>Arabic</b><div class="ar">' + ph(it.ar.text) + "</div></div>" : "")
        + (it.en ? '<div class="lang"><b>English</b><div class="en">' + ph(it.en.text) + "</div></div>" : "")
        + "</div>"
        + '<div class="q">Is this wording OK?</div>'
        + '<div class="actions"><button class="' + (st === "yes" ? "yes" : "") + '" onclick="setS(' + it.id + ',\'yes\')">Yes, keep it</button>'
        + '<button class="' + (st === "no" ? "no" : "") + '" onclick="setS(' + it.id + ',\'no\')">No, change it</button></div>'
        + '<div class="edit">'
        + (it.ar ? '<label>Arabic: what it should say</label><textarea class="ar" dir="rtl" oninput="setT(' + it.id + ',\'ar\',this.value)">' + esc(a.ar !== undefined ? a.ar : it.ar.text) + "</textarea>" : "")
        + (it.en ? "<label>English: what it should say</label><textarea oninput=\"setT(" + it.id + ",'en',this.value)\">" + esc(a.en !== undefined ? a.en : it.en.text) + "</textarea>" : "")
        + '<label>Note for me (optional)</label><textarea oninput="setT(' + it.id + ',\'note\',this.value)" style="min-height:44px">' + esc(a.note || "") + "</textarea>"
        + "</div></div>";
    }
  }
  $("#main").innerHTML = html;
  stats();
}
function setS(id, s) {
  ans[id] = Object.assign(ans[id] || {}, { status: (ans[id] && ans[id].status === s) ? "" : s });
  if (!ans[id].status) delete ans[id].status;
  save();
  const c = $("#c" + id);
  c.className = "card " + (ans[id].status || "");
  const b = c.querySelectorAll(".actions button");
  b[0].className = ans[id].status === "yes" ? "yes" : ""; b[1].className = ans[id].status === "no" ? "no" : "";
  if (ans[id].status === "yes" && filter === "todo") c.classList.add("hide");
}
function setT(id, k, v) { ans[id] = Object.assign(ans[id] || {}, { [k]: v }); save(); }
function filters() {
  const f = [["all", "All"], ["todo", "To do"], ["yes", "Approved"], ["no", "To change"]];
  $("#filters").innerHTML = f.map(([k, t]) => '<button class="' + (filter === k ? "on" : "") + '" onclick="setF(\'' + k + '\')">' + t + "</button>").join("");
}
function setF(k) { filter = k; filters(); render(); }
function exportData() {
  const out = [];
  for (const it of ITEMS) {
    const a = ans[it.id];
    if (!a || !a.status) continue;
    out.push({ id: it.id, status: a.status, where: it.where,
      ar: it.ar && { file: it.ar.file, line: it.ar.line, original: it.ar.text, raw: it.ar.raw, new: a.status === "no" && a.ar !== undefined ? a.ar : null },
      en: it.en && { file: it.en.file, line: it.en.line, original: it.en.text, raw: it.en.raw, new: a.status === "no" && a.en !== undefined ? a.en : null },
      note: a.note || "" });
  }
  return { version: "__VERSION__", reviewer: ($("#who").value || "").trim(), exported: new Date().toISOString(), total: ITEMS.length, approved: out.filter((o) => o.status === "yes").length, to_change: out.filter((o) => o.status === "no").length, answers: out };
}
const NAMEKEY = "fs_text_review_name";
try { $("#who").value = localStorage.getItem(NAMEKEY) || ""; } catch (e) {}
$("#who").oninput = () => { try { localStorage.setItem(NAMEKEY, $("#who").value); } catch (e) {} };
function needName() { if (!($("#who").value || "").trim()) { $("#msg").textContent = "Please write your name at the top first."; $("#who").focus(); window.scrollTo(0, 0); return true; } return false; }
function fname() { return "text_review_" + ($("#who").value || "friend").trim().replace(/[^A-Za-z0-9؀-ۿ]+/g, "_") + ".json"; }
function asFile() { return new File([JSON.stringify(exportData(), null, 1)], fname(), { type: "application/json" }); }
$("#send").onclick = async () => {
  if (needName()) return;
  const f = asFile();
  try {
    if (navigator.canShare && navigator.canShare({ files: [f] })) { await navigator.share({ files: [f], title: "Field Shift text review", text: "My answers for the Field Shift text review" }); $("#msg").textContent = "Thank you!"; return; }
  } catch (e) { if (e && e.name === "AbortError") return; }
  $("#dl").click();
  $("#msg").textContent = "Your phone cannot share from here, so the file " + fname() + " was downloaded. Please send that file to Tarek.";
};
$("#dl").onclick = () => {
  if (needName()) return;
  const a = document.createElement("a"); a.href = URL.createObjectURL(asFile()); a.download = fname(); a.click();
  $("#msg").textContent = "Downloaded " + fname() + ". Send that file to Tarek.";
};
$("#cp").onclick = async () => {
  if (needName()) return;
  try { await navigator.clipboard.writeText(JSON.stringify(exportData())); $("#msg").textContent = "Copied. Paste it into the chat."; }
  catch (e) { $("#msg").textContent = "Could not copy automatically; use Download instead."; }
};
$("#reset").onclick = () => { if (confirm("Clear every answer on this page?")) { ans = {}; save(); render(); } };
filters(); render();
</script>
</body>
</html>
"""
(OUT / "index.html").write_text(HTML.replace("__FONTS__", font_css()).replace("__DATA__", data).replace("__VERSION__", hashlib.sha1((OUT / "texts.json").read_bytes()).hexdigest()[:10]), encoding="utf8")
print("wrote", (OUT / "index.html").stat().st_size // 1024, "KB with", len(items), "texts")
