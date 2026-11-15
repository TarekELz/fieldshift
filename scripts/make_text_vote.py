"""Build docs/text_vote/index.html: a single-file "which wording works better?" vote for the app's key texts.

For each text, option A is what the app says now (read from docs/text_review/texts.json so it is exact); B and C are alternative
wordings DRAFTED BY THE ASSISTANT in simple spoken Egyptian Arabic and English. They are drafts for Tarek and the team to judge, not
approved text. A voter picks one or writes their own, and sends the answers back as a JSON file.
Collect with scripts/collect_text_votes.py. Run: .venv/Scripts/python scripts/make_text_vote.py
"""
import base64
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "text_vote"
FONTS = ROOT / "app" / "assets" / "fonts"
texts = {t["id"]: t for t in json.loads((ROOT / "docs" / "text_review" / "texts.json").read_text(encoding="utf8"))}

# (id of the current text in texts.json, where the farmer meets it, [(B ar, B en), (C ar, C en)])
ITEMS = [
    (1, "Welcome screen, Eyad introduces himself", [("أنا إياد، مساعدك الذكي في الغيط", "I'm Eyad, your smart helper in the field"), ("أهلاً، أنا إياد. مساعد ذكي بيسمعك وبيحسبلك", "Hi, I'm Eyad, a smart assistant who listens and works it out for you")]),
    (2, "Welcome screen, the big headline", [("قبل ما تزرع، اسأل إياد", "Before you sow, ask Eyad"), ("ازرع في الميعاد المظبوط", "Sow at the right time")]),
    (3, "Welcome screen, under the headline", [("الجو من ناسا، والملوحة من جداول الفاو، وكلامك أنت", "The weather from NASA, the salt from FAO tables, and what you tell me"), ("بنقارن دورتك بدورتين تانيين، وبنستخدم بيانات من ناسا", "We compare your rotation with two others, using NASA data")]),
    (15, "Setup screen 2, what Eyad is and is not", [("إياد بيساعدك، لكن القرار قرارك والمرشد الزراعي أدرى", "Eyad helps, but the decision is yours and the agricultural adviser knows best"), ("إياد مساعد بس. خبرتك وكلام المرشد الزراعي هما الأساس", "Eyad is only a helper. Your experience and the adviser's word come first")]),
    (17, "Setup screen 3, voice or typing", [("تحب أرد عليك بالصوت ولا بالكتابة؟", "Should I answer you aloud or in writing?"), ("نتكلم ولا نكتب؟", "Shall we talk or type?")]),
    (36, "First question (also invites free speech)", [("احكيلي: أرضك فين وبتزرع إيه؟ أو دوس على الخريطة", "Tell me: where is your field and what do you grow? Or tap the map"), ("قولّي أرضك في أنهي محافظة، أو دوس عليها في الخريطة", "Tell me which governorate your field is in, or tap it on the map")]),
    (37, "Question: summer crop", [("بتزرع إيه في الصيف؟ رز ولا ذرة ولا قطن؟", "What do you grow in summer? Rice, maize or cotton?"), ("المحصول بتاع الصيف عندك إيه؟", "What is your summer crop?")]),
    (38, "Question: when the summer crop is sown", [("إمتى بتزرع {arCrop}؟ قول الشهر.", "When do you sow {arCrop}? Say the month."), ("{arCrop} بتتزرع في أنهي شهر؟ أول الشهر ولا نصه ولا آخره؟", "In which month is {arCrop} sown? Early, middle or late?")]),
    (39, "Question: when the wheat is sown", [("وبعد كده القمح بتزرعه إمتى؟ من نوفمبر لحد يناير", "And when do you sow the wheat after it? From November to January"), ("القمح بتزرعه في أنهي شهر؟", "In which month do you sow the wheat?")]),
    (40, "Question: how often canal water comes", [("الميّه بتوصل أرضك كل كام يوم؟", "How many days apart does water reach your field?"), ("بتروي كل كام يوم تقريباً؟", "Roughly how many days between your waterings?")]),
    (43, "Question: salt on the soil", [("الأرض فيها ملح؟ يعني قشرة بيضاء أو بقع؟ لو عملت تحليل قول الرقم", "Is there salt on the soil, meaning a white crust or patches? If you had a soil test, say the number"), ("شايف على الأرض ملح أبيض أو بقع؟", "Do you see white salt or patches on the soil?")]),
    (50, "When Eyad did not understand (place)", [("معلش مسمعتش كويس. قول اسم المحافظة تاني", "Sorry, I did not catch that. Say the governorate again"), ("سامحني، ممكن تقولها تاني؟ اسم المحافظة بس", "Forgive me, could you say it again? Just the governorate")]),
    (28, "While the microphone is listening", [("أنا سامعك، اتكلم", "I'm listening, go ahead"), ("اتفضل، قول", "Please, say it")]),
    (23, "When the phone has no working microphone", [("الميكروفون مش شغال هنا. اكتب أو دوس على إجابة", "The microphone is not working here. Type or tap an answer"), ("مقدرش أسمعك دلوقتي. اكتب أو اختار من الأزرار", "I can't hear you now. Type or choose a button")]),
    (59, "Result screen, the heading", [("ده اللي لقيته لأرضك في {arSite}", "This is what I found for your field in {arSite}"), ("نتيجة {arSite}:", "Result for {arSite}:")]),
    (145, "Result screen, the reminder under the numbers", [("الأرقام دي للاسترشاد بس. اسأل المرشد الزراعي قبل ما تغير دورتك", "These numbers are a guide only. Ask the agricultural adviser before you change your rotation"), ("ده تقدير من بيانات ناسا مش ضمان. الكلمة الأخيرة ليك وللمرشد الزراعي", "This is an estimate from NASA data, not a guarantee. The last word is yours and the adviser's")]),
    (81, "Result screen, under 'Water need'", [("استهلاك المية للمحصول الصيفي، مقارنةً بدورتك", "Water use of the summer crop, compared with your rotation"), ("كام مية هياخد المحصول الصيفي بالنسبة لدورتك", "How much water the summer crop will take compared with your rotation")]),
]


# texts.json is frozen (friends answer against it); these two were reworded in the app since, so A must be the real current text
CURRENT_OVERRIDE = {
    36: ("احكيلي عن أرضك بصوتك: فين هي، وبتزرع إيه، وإمتى؟ أو اضغط على مكانها في الخريطة.", "Tell me about your field in your own words: where it is, what you grow and when. Or tap it on the map."),
    81: ("مية المحصول الصيفي بس، قصاد دورتك الحالية", "summer crop only, compared with your current rotation"),
}


def pick(id_):
    t = texts.get(id_)
    if not t:
        raise SystemExit(f"text id {id_} not found in texts.json")
    return t


items = []
for n, (id_, where, alts) in enumerate(ITEMS, 1):
    t = pick(id_)
    # the current wording may have been reworded since texts.json was frozen: read it from the source when it is a pair we reworded
    cur_ar = t["ar"]["text"] if t.get("ar") else ""
    cur_en = t["en"]["text"] if t.get("en") else ""
    cur_ar, cur_en = CURRENT_OVERRIDE.get(id_, (cur_ar, cur_en))
    opts = [{"key": "A", "ar": cur_ar, "en": cur_en, "tag": "what the app says now"}]
    for k, (ar, en) in zip("BC", alts):
        opts.append({"key": k, "ar": ar, "en": en, "tag": "draft"})
    items.append({"id": n, "where": where, "options": opts})

version = hashlib.sha1(json.dumps(items, ensure_ascii=False, sort_keys=True).encode("utf8")).hexdigest()[:10]


def font_css():
    out = []
    for fam, file, w in (("Plex", "IBMPlexSans-Regular.ttf", 400), ("Plex", "IBMPlexSans-SemiBold.ttf", 600), ("PlexAr", "IBMPlexSansArabic-Regular.ttf", 400), ("PlexAr", "IBMPlexSansArabic-SemiBold.ttf", 600)):
        b64 = base64.b64encode((FONTS / file).read_bytes()).decode()
        out.append('@font-face { font-family: "%s"; src: url(data:font/ttf;base64,%s); font-weight: %d; }' % (fam, b64, w))
    return chr(10).join(out)


HTML = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Field Shift: which wording works better?</title>
<style>
__FONTS__
:root { --bg:#F3F2EF; --card:#FFFFFF; --muted:#F0EEEA; --line:#E6E3DD; --text:#1B1D1F; --dim:#585D63; --accent:#0067AC; --onaccent:#fff; --ok:#1A7340; --shadow:0 8px 24px rgba(27,29,31,.10); }
@media (prefers-color-scheme: dark) { :root { --bg:#0F1113; --card:#1A1D21; --muted:#23272B; --line:#2E3338; --text:#ECEDEE; --dim:#A3A9AF; --accent:#62B2EC; --onaccent:#0B1A26; --ok:#5DC48A; --shadow:none; } }
* { box-sizing:border-box; } body { margin:0; background:var(--bg); color:var(--text); font:16px/1.5 "Plex", system-ui, sans-serif; }
header, main { max-width:880px; margin:0 auto; padding:16px; } h1 { font-size:25px; margin:0 0 6px; font-weight:600; }
.dim { color:var(--dim); } .bar { position:sticky; top:0; background:var(--bg); border-bottom:1px solid var(--line); padding:10px 16px; z-index:3; } .bar-in { max-width:880px; margin:0 auto; display:flex; gap:12px; align-items:center; flex-wrap:wrap; }
.card { background:var(--card); border-radius:22px; padding:16px; margin:14px 0; box-shadow:var(--shadow); border:2px solid transparent; } .card.done { border-color:var(--ok); }
.where { color:var(--dim); font-size:13px; margin-bottom:8px; font-weight:600; }
.opt { display:flex; gap:12px; align-items:flex-start; background:var(--muted); border-radius:16px; padding:12px; margin:8px 0; cursor:pointer; border:2px solid transparent; } .opt.sel { border-color:var(--accent); }
.opt input { margin-top:6px; transform:scale(1.3); } .key { font-weight:600; min-width:22px; } .tag { font-size:12px; color:var(--dim); }
.langs { flex:1; display:grid; grid-template-columns:1fr 1fr; gap:10px; } @media (max-width:640px) { .langs { grid-template-columns:1fr; } }
.ar { direction:rtl; text-align:right; font-family:"PlexAr","Plex",sans-serif; font-size:19px; line-height:1.7; white-space:pre-line; } .en { white-space:pre-line; }
.ph { display:inline-block; background:var(--card); border:1px dashed var(--dim); border-radius:8px; padding:0 6px; font-size:.8em; color:var(--dim); direction:ltr; font-family:ui-monospace,monospace; }
.own { margin-top:6px; display:none; } .card.ownon .own { display:block; } textarea { width:100%; font:inherit; background:var(--muted); color:var(--text); border:1px solid var(--line); border-radius:12px; padding:8px; min-height:56px; margin-top:4px; } textarea.ar { font-size:18px; }
button { font:inherit; cursor:pointer; border:0; border-radius:14px; padding:10px 16px; background:var(--accent); color:var(--onaccent); font-weight:600; } button.g { background:var(--muted); color:var(--text); }
input.t { font:inherit; padding:8px 12px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--text); } .note { font-size:13px; color:var(--dim); }
</style></head><body>
<header><h1>Field Shift: which wording works better?</h1>
<p class="dim">Thank you for helping! Field Shift is an app for Nile Delta farmers, and Eyad is its assistant. For each text below, pick the wording you think a farmer would understand best. <b>A is what the app says now; B and C are draft alternatives.</b> You can also write your own. About 10 minutes.</p>
<p class="dim" dir="rtl" style="font-family:PlexAr,sans-serif">شكراً لمساعدتك! لكل نص اختار الصيغة اللي تحس إن الفلاح هيفهمها أحسن. A هي الحالية، وB وC اقتراحات. وتقدر تكتب صيغتك.</p>
<p><b>Your name / اسمك:</b> <input class="t" id="who" placeholder="e.g. Youssef"></p></header>
<div class="bar"><div class="bar-in"><span id="prog"></span></div></div>
<main id="main"></main>
<main><button id="send">Send my answers</button> <button class="g" id="dl">Download answers</button> <button class="g" id="cp">Copy answers</button> <button class="g" id="reset">Clear</button><p class="note" id="msg">Write your name at the top first. "Send my answers" opens WhatsApp or Telegram on your phone; if it cannot, it downloads a file to send to Tarek.</p></main>
<script>
const ITEMS = __DATA__, VERSION = "__VERSION__", KEY = "fs_text_vote_" + VERSION;
const $ = (s) => document.querySelector(s);
const esc = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
const ph = (s) => esc(s).replace(/\{[^}]*\}/g, (m) => '<span class="ph">' + m + "</span>");
let ans = {}; try { ans = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
function save() { try { localStorage.setItem(KEY, JSON.stringify(ans)); } catch (e) {} const d = ITEMS.filter((i) => ans[i.id] && ans[i.id].pick).length; $("#prog").textContent = d + " of " + ITEMS.length + " answered"; }
function render() {
  $("#main").innerHTML = ITEMS.map((it) => { const a = ans[it.id] || {};
    return '<div class="card' + (a.pick ? " done" : "") + (a.pick === "own" ? " ownon" : "") + '" id="c' + it.id + '"><div class="where">' + it.id + ". " + esc(it.where) + "</div>"
      + it.options.map((o) => '<label class="opt' + (a.pick === o.key ? " sel" : "") + '"><input type="radio" name="r' + it.id + '"' + (a.pick === o.key ? " checked" : "") + ' onchange="pick(' + it.id + ',\'' + o.key + '\')"><span class="key">' + o.key + '</span><div class="langs"><div class="ar">' + ph(o.ar) + '</div><div class="en">' + ph(o.en) + '</div></div></label>').join("")
      + '<label class="opt' + (a.pick === "own" ? " sel" : "") + '"><input type="radio" name="r' + it.id + '"' + (a.pick === "own" ? " checked" : "") + ' onchange="pick(' + it.id + ',\'own\')"><span class="key">&#9998;</span><div>My own wording (write it below)</div></label>'
      + '<div class="own"><textarea class="ar" dir="rtl" placeholder="بالعربي" oninput="own(' + it.id + ',\'ar\',this.value)">' + esc(a.ar || "") + '</textarea><textarea placeholder="In English (optional)" oninput="own(' + it.id + ',\'en\',this.value)">' + esc(a.en || "") + "</textarea></div>"
      + '<textarea placeholder="Why? (optional)" style="min-height:44px" oninput="own(' + it.id + ',\'why\',this.value)">' + esc(a.why || "") + "</textarea></div>"; }).join("");
  save();
}
function pick(id, k) { ans[id] = Object.assign(ans[id] || {}, { pick: k }); save(); render(); }
function own(id, f, v) { ans[id] = Object.assign(ans[id] || {}, { [f]: v }); save(); }
function data() { return { version: VERSION, voter: ($("#who").value || "").trim(), exported: new Date().toISOString(), answers: ITEMS.filter((i) => ans[i.id] && ans[i.id].pick).map((i) => ({ id: i.id, where: i.where, pick: ans[i.id].pick, own_ar: ans[i.id].pick === "own" ? ans[i.id].ar || "" : "", own_en: ans[i.id].pick === "own" ? ans[i.id].en || "" : "", why: ans[i.id].why || "" })) }; }
function fname() { return "text_vote_" + ($("#who").value || "friend").trim().replace(/[^A-Za-z0-9؀-ۿ]+/g, "_") + ".json"; }
function needName() { if (!($("#who").value || "").trim()) { $("#msg").textContent = "Please write your name at the top first."; window.scrollTo(0, 0); return true; } return false; }
try { $("#who").value = localStorage.getItem("fs_vote_name") || ""; } catch (e) {} $("#who").oninput = () => { try { localStorage.setItem("fs_vote_name", $("#who").value); } catch (e) {} };
const asFile = () => new File([JSON.stringify(data(), null, 1)], fname(), { type: "application/json" });
$("#send").onclick = async () => { if (needName()) return; const f = asFile(); try { if (navigator.canShare && navigator.canShare({ files: [f] })) { await navigator.share({ files: [f], title: "Field Shift wording vote" }); $("#msg").textContent = "Thank you!"; return; } } catch (e) { if (e && e.name === "AbortError") return; } $("#dl").click(); };
$("#dl").onclick = () => { if (needName()) return; const a = document.createElement("a"); a.href = URL.createObjectURL(asFile()); a.download = fname(); a.click(); $("#msg").textContent = "Downloaded " + fname() + ". Send that file to Tarek."; };
$("#cp").onclick = async () => { if (needName()) return; try { await navigator.clipboard.writeText(JSON.stringify(data())); $("#msg").textContent = "Copied. Paste it in a message to Tarek."; } catch (e) { $("#msg").textContent = "Use Download instead."; } };
$("#reset").onclick = () => { if (confirm("Clear all your answers?")) { ans = {}; save(); render(); } };
render();
</script></body></html>
"""
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "index.html").write_text(HTML.replace("__FONTS__", font_css()).replace("__DATA__", json.dumps(items, ensure_ascii=False).replace("</", "<\\/")).replace("__VERSION__", version), encoding="utf8")
(OUT / "items.json").write_text(json.dumps({"version": version, "items": items}, ensure_ascii=False, indent=1), encoding="utf8")
print("wrote", (OUT / "index.html").stat().st_size // 1024, "KB;", len(items), "texts;", "version", version)
