# Field Shift: pre-submission review (15 Nov 2026, about 22:30 Egypt time)

Base: `main` at 6bc1d02 (PR #12, the key proxy, is **already merged**). Three reviews ran in parallel: A (criteria and competition), B (code, security, tests) and C (writing, disclosure, submission pack). Their full reports are in the appendix below.

## Summary
The engines, data and method are strong. Judges will see the presentation first, and right now it fails: **the repo is private, the Pages build fails, there is no AI disclosure file, and the demo is not linked.** Five small PRs fix what can be fixed in code. The rest needs Tarek.

## Findings (ranked)
| Sev | Where | Finding | Fix |
|---|---|---|---|
| BLOCKER | repo settings | Repo is private, but judges need a public link | Tarek: make it public (after the history secret scan below) |
| BLOCKER | `.github/workflows/pages.yml`, `app/web` missing | Every Pages run today failed ("This project is not configured for the web"), so there is no live project page or web app | Tarek: in `app/` run `flutter create . --platforms web`, commit `app/web`, re-run Pages. Or remove the Flutter-web steps and publish `docs/` only |
| BLOCKER | `docs/ai-disclosure.md` | Missing; linked from README:141, `docs/index.html`:171 and :204, AGENTS.md and code comments | **PR docs/ai-disclosure** |
| HIGH | `app/pubspec.yaml`:67 | `assets/secrets/` is bundled, so an APK built where `secrets.json` exists ships the raw keys | Build the release after deleting `app/assets/secrets/secrets.json`; check with `unzip -l app-release.apk \| grep secrets` |
| HIGH | git history | Not scanned: the clone used here is shallow | Before going public, on a full clone run `gitleaks detect` or `git log -p --all \| grep -E 'AIza\|sk-'` |
| HIGH | `proxy/worker.js`:75-86 | The daily cap wrote to KV on every request, even past the cap. With about 1,000 KV writes a day on the free plan (plan not checked), every uncached request would then fail with a 500 | **PR fix/proxy-cap-and-limits** |
| HIGH | README:20, 106, 117, 151; `proof.svg` | 86 voice lines (there are 103); "about 266 pass" (the clean-clone run gives 272 pass, 154 skip); Relevance row lists 5 NASA datasets, not 6 | **PR docs/readme-claims-and-copy** |
| HIGH | `docs/index.html` | Says 5 datasets and 4 engines (the README says 6 and 5) and 446 tests (the README says 309 + 62). Says "anything the AI wrote or voiced is marked", but only the avatar is | same PR |
| MEDIUM | `docs/explorer/img/crops/*.svg` | No visible AI mark; the origin of the pictures is not recorded | Tarek: confirm who drew them; if AI, add a caption on the crops page |
| MEDIUM | `proxy/worker.js`:130 | Temperature 0 (sent by `interpret.dart`) was turned into 0.3; `/tts` read the body with no size limit | **PR fix/proxy-cap-and-limits** |
| MEDIUM | `proxy` | If `APP_TOKEN` is not set in production, /gemini and /tts are open relays (30/min per IP plus the daily caps) | Tarek: confirm `APP_TOKEN` is set |
| MEDIUM | `app/lib/flow.dart` | The "BOTTOM OVERFLOWED BY 1.3 PIXELS" stripe over Send/X with the keyboard open (seen on a phone) | **PR fix/keyboard-overflow** (not compiled here) |
| MEDIUM | `dialogue.dart`:45, 200 | The Egyptian spellings يونيه / يوليه are not recognised as months | Proposed, not applied: `if (n.contains('يونيه')) month = 6; if (n.contains('يوليه')) month = 7;` |
| MEDIUM | `ui_kit.dart`:243 | RoundButton is 44 dp (the guideline minimum is 48) | Proposed: 48 x 48; changes the layout height |
| MEDIUM | `docs/references.md`:3, 17 | Still marked "DRAFT" and "to confirm" | Tarek: remove the draft wording once confirmed |
| LOW | README:117 | "Flutter: 62 pass": `app/test` has 68 test declarations; not run here | Run `flutter test` and use the exact count (the project page now says 371 = 309 + 62, so confirm both) |
| LOW | `docs/submission-rules.md`:62-68 | The live judging guide puts completeness, feasibility and user-friendliness under Relevance | Update the note |
| INFO | `voice.dart`:303 | The voice cancel bug from the speculation report is already fixed on main | none |

Arabic flags (for a native speaker; **nothing changed**): appendix C, 9 items. Most important: `models/blueprints.json`:45 says "sow wheat **first**" where the English says "earlier"; `:14` says the **farm** is near the sea, when it is the NASA cell; `docs/explorer/js/app.js`:536 "مش أمان، بس مش موثوق" makes no sense.

## Criteria scores (1 to 5)
| | Impact | Creativity | Validity | Relevance | Presentation |
|---|---|---|---|---|---|
| Now | 4 | 4 | 4 | 4 | 2-3 |
| After PRs + Tarek's steps | 4 | 4 | 4 | 4-5 | 4 |

## Submission checklist
| Item | Status |
|---|---|
| Public repo | **FAIL** (private) |
| LICENSE (MIT) | PASS |
| Live project link (Pages) | **FAIL** (build failing) |
| AI disclosure | **FAIL**, PASS after PR docs/ai-disclosure |
| References field | PASS (still marked draft) |
| NASA data stated honestly (6 datasets, all in `data/catalog.yaml`) | PASS |
| Demo: 30 s video in English with subtitles, public link | UNKNOWN: the video exists but is not linked in the repo |
| Team fields, Members tab, challenge selected | UNKNOWN (form not visible) |
| English throughout | PASS |

## Not verified
Flutter analyze/test and every phone test (no SDK, no device here): first run, mic permission, the three goals, typed answers, Arabic months, offline clips, Terms, Professional view, 360x640 with the keyboard open, RTL, text scaling. The 309 Python figure (needs `data/raw/`). The git history. The production proxy settings (APP_TOKEN, ALLOWED_ORIGINS, KV plan). Whether the APK to be submitted contains `secrets.json`. The winners' README layouts. The local submission cutoff (confirm with the Mansoura Local Lead).

## For Tarek
**Decisions only you can make:** make the repo public; enable Pages (and which fix: add `app/web`, or publish `docs/` only); confirm or edit the AI disclosure; confirm the origin of the crop SVGs; approve the Arabic proposals.

**Manual steps, in order:**
1. Secret-scan the full history.
2. Run `flutter analyze && flutter test`.
3. Merge the PRs.
4. Fix Pages.
5. Build a keyless APK (delete `secrets.json` first) and attach it to a GitHub Release.
6. Make the repo public.
7. Upload the 30 s video and link it at the top of the README.
8. Fill the form from `docs/submission/fields.md`.
9. Open every link while logged out.

**Merge order** (all touch separate hunks; tested to merge cleanly together):
1. docs/ai-disclosure
2. docs/readme-claims-and-copy
3. docs/submission-pack
4. fix/proxy-cap-and-limits: then redeploy the worker
5. fix/keyboard-overflow: after `flutter analyze` and a phone check

---
# Appendix

## Agent A findings (repo at 6bc1d02, reviewed ~22:20-22:45 Egypt time)

## Competitor table
| Entry | Award / year | What it did | Lesson for us |
|---|---|---|---|
| GaamaRamma "WaterWise" | Best Use of Data 2024 | field mapping, irrigation log, 7-day rain, NASA OpenET | one named NASA product tied to one farmer action ([universemagazine](https://universemagazine.com/en/ukrainian-team-wins-nasa-space-apps-challenge-2024)) |
| NVS-knot (Kyiv) | Galactic Impact 2024 | farmers analyse NASA data for water problems | same |
| Nave/VITech "2Plant or not 2Plant" | Galactic Impact 2024 | planting window, soil moisture, frost risk; beta test planned with real customers | real-user pilot plan was the story ([siliconprairienews](https://siliconprairienews.com/2025/02/nebraska-startup-wins-nasas-galactic-impact-award-in-the-2024-space-apps-challenge)) |
| TerraTales (Egypt) | Best Storytelling 2024 | interactive climate game | Egyptian teams win on story |
| Ometeotl: Crop Connect | Global Nominee 2024 | dashboard, LLM summaries, chatbot, WhatsApp alerts | very close to us; we beat it on grounding, not on reach ([meteomatics](https://meteomatics.com/en/news/ometeotl-crop-connect)) |
| Zumorroda-X (Egypt) | Art & Technology 2025 | farming game on heat waves and floods | ([nasa.gov 2025](https://www.nasa.gov/learning-resources/stem-engagement-at-nasa/nasa-announces-2025-international-space-apps-challenge-global-winners/)) |
| Twisters "SkySense" | Best Use of Technology 2025 | NASA EO + AI hyperlocal weather risk | same page |
| QUEÑARIS (Peru) | Local Impact 2025 | NASA satellite data for water-retaining forests | local problem, named place |
| Hackathon repos | stars | | |
| sahat/hackathon-starter | 35,260 | boilerplate; quick-start up top | install in 3 lines |
| alurubalakarthikeya/NASA-Space-Apps | 34 | 3D viz | visuals first |
| aibelbin/Nasa_space_apps | 10 | "how we won" | |
Space Apps repos rarely get stars (top result 34), so stars are a weak signal. NOT VERIFIED: README layouts of the winners. The news pages describe the projects, not their repos.

## Criteria scores (before, then after fixes)
The live judging guide names the criteria **Influence**, Creativity, Validity, Relevance and Presentation. Under it, **Relevance also covers completeness, technical feasibility and user-friendliness**. docs/submission-rules.md:62-68 files those under Validity; correct it.
| Criterion | Before | After | Evidence |
|---|---|---|---|
| Impact | 4 | 4 | read-in-full figures README:72-81; all Delta README:148; no farmer has used it (status.md:126 "phone test" not done) |
| Creativity | 4 | 4 | code chooses the advice and the AI may only reword it, behind a guard README:104; voice-first; Pro view README:53 |
| Validity | 4 | 4 | checks README:108-119; ET0 0.92-0.99 of MOD16 (docs/checks/et0_check.json); no station or yield check; Arabic clips not heard by a native speaker (status.md:127) |
| Relevance | 4 | 4-5 | POWER drives every number README:157; soil health only as salinity README:151; app on a phone untested lowers completeness |
| Presentation | 2-3 | 4 | repo private, Pages failing, demo not linked, AI-disclosure file missing |

## Gap list (gain/effort, next hour)
1. Make the repo public; check the CI badge renders (5 min, BLOCKER).
2. Write docs/ai-disclosure.md. Start from the "AI tools used" section of docs/references.md (:37-42) and add the Claude coding use, in line with D13 (10 min). The file is linked from docs/index.html:171,204 and README:141, and those links are broken now.
3. Pages: delete the Flutter-web steps from .github/workflows/pages.yml (publish only docs/), or run `flutter create --platforms=web .` in app/ and commit app/web (10 min). This gives a live, clickable project page.
4. Put the 30 s video link at the top of the README and in "For the judges" (2 min).
5. Attach a key-free debug APK to a GitHub Release (10 min). README:124 says only "with the team".
6. Turn the README:141-142 rows to "Yes" with links once 2 and 4 are done.
7. One line on what we add over Crop-Connect-style chatbots: grounded numbers, offline use, dialect voice.

## Submission checklist
| Item | Status | Note |
|---|---|---|
| Public repo, no login | FAIL | private (team). The final-project link must be public |
| LICENSE | PASS | MIT, /LICENSE |
| One official challenge | PASS* | the form is not visible to me |
| Team 1-6, all on Members tab | UNKNOWN | 5 listed README:186-190 |
| Demo: 30 s video, English subtitles, public host | UNKNOWN | the video exists; subtitles, length and public link not checked; not linked in the repo |
| Final project link works | FAIL until public | the Pages run failed (app/web missing; confirmed absent) |
| References field | PASS (draft) | docs/references.md says "DRAFT…to confirm" (:3) and EcoCrop licence "to confirm" (:17); remove the draft wording |
| AI disclosure | FAIL | docs/ai-disclosure.md is not in the repo. The form answer "will not impact judging", but rules require indicators in the project |
| NASA data stated honestly | PASS | six datasets, all in data/catalog.yaml (POWER :4, MOD13Q1, MCD12Q2 :223, MOD16A3GF :192, SRTM :145, IMERG :127); "no farmer-facing number" stated for each one other than POWER |
| English throughout | PASS | README/page English; Arabic appears as product content |
| Deadline | UNKNOWN | the live submission guide still shows "October 5/6" template dates; docs/submission-rules.md says Nov 15 23:59 local; ask Local Lead |

## README claim audit (fixes APPLIED in the review copy unless marked)
| Sev | Line | Claim | Evidence | Fix |
|---|---|---|---|---|
| HIGH | 117 | "about 266 pass" on clean clone | `pytest tests`: **272 passed, 154 skipped** | applied "(272 pass, 154 skip)" |
| HIGH | 20, 106 + proof.svg | "86 recorded voice lines" | app/assets/audio has 103 wav + index.json with 103 lines; all bundled (pubspec.yaml:68) | applied 103 in README and proof.svg. Better: rerun scripts/build_readme_assets.py |
| MEDIUM | 151 | Relevance lists 5 NASA sets; line 137 says six | SRTM omitted | applied "Six NASA datasets … SRTM terrain …" |
| LOW | 111 | "within 1 to 8%" | ratios 0.92-0.99, all below MOD16 (Damietta 8.4%) | applied "1 to 8% below … ratios 0.92 to 0.99" |
| HIGH | 122 | "published with GitHub Pages once public" | the workflow builds Flutter web, and app/web is absent, so it fails | NOT applied: fix the workflow (gap 3) or say "open docs/index.html locally" |
| BLOCKER | 141 | AI disclosure "in progress" | file missing | NOT applied: write the file |
| MEDIUM | 117 | "Flutter: 62 pass" | 68 literal test()/testWidgets() calls in app/test; Flutter not installed here | NOT applied: run `flutter test`, use the exact number |
| LOW | 161 | MOD16 "2015-2024" | et0_check.json gives "years": 9 per point | NOT applied: say "9 years in 2015-2024" or check |
| LOW | 117 | "309 pass with raw data" | data/raw not in clone | not verified |

## Not verified
Flutter test count; the 309 figure; 18 golden cases; the 4- and 26-day hero numbers (only that they are in hero.svg); WorldCover/SRTM ranges (srtm_terrain.csv not recomputed); video content and length; form fields; team registration; winners' repo layouts; Mansoura local cutoff.

## Agent B findings (main 6bc1d02, clean shallow clone)

## Test results
- `python3 -m pytest tests -q`: **272 passed, 154 skipped, 0 failed**. Skips: 111 in test_apply_text_review.py (marked as intentionally obsolete), and 43 that need `data/raw/` (test_season_engine, test_rotation, test_calendar_engine, test_water_engine; "POWER files not downloaded").
- `node --test proxy/test/worker.test.mjs`: 13/13 pass before my changes, **16/16 pass after** (3 new tests).
- **Could not run:** `flutter analyze`, `flutter test`, any build, and anything on a phone (no SDK, no device). My Dart edit has **not been compiled**. Untested: first run, mic permission, the three goals, typed answers, Arabic month parsing, offline clips, Terms, Professional view, layout at 360x640 with the keyboard open, RTL, text scaling.

## BLOCKER / HIGH
1. **HIGH (compliance): `docs/ai-disclosure.md` is missing** from the repo. It is linked from README.md:141 (marked "In progress"), docs/index.html:171 and :204 (both broken links on the public site), AGENTS.md, eyad.dart:4, voice.dart:21, and submission-rules.md:75 says the rules require it. The team has to write it. I did not write it, because that would mean making up their disclosure.
2. **HIGH (secrets in APK): `assets/secrets/` is bundled** (app/pubspec.yaml:67). If the submitted APK is built on a machine where `scripts/write_app_secrets.py` created `secrets.json`, the raw Gemini and Hamsa keys ship inside the APK, even when the proxy is used (proxy.dart:1-3 says direct keys "still work as an extra"). Build the release only after deleting `app/assets/secrets/secrets.json`, and check with `unzip -l app-release.apk | grep secrets`.
3. **HIGH (availability, fixed): proxy daily cap broke the proxy on the KV write limit.** Every /tts and /gemini call did a KV `put` (worker.js:75-86), and kept doing so after the cap was reached. Workers KV on the free plan allows about 1,000 writes a day, below the 3,000 caps; once that runs out, `put` throws and every uncached request gets a 500. I have not checked which plan the account is on. Fix: no write once over the cap, and a KV error falls back to the per-address limit. Trade-off: if KV fails, spend is capped only by the 30/min per-address limit.

## MEDIUM
4. **Proxy turned temperature 0 into 0.3 (fixed).** worker.js:130 used `Number(x) || 0.3`, and interpret.dart:43 sends `temperature: 0.0`, so the phrase classifier was not deterministic through the proxy. Negative `maxOutputTokens` and temperature were also passed upstream. Now clamped to [0,1] and [1,400].
5. **The proxy read the /tts body with no size limit (fixed)** (`request.json()` before the length check). It now reads the text and rejects anything over 1,200 characters, as /gemini already does.
6. **Proxy abuse surface (not fixed, design choice):** `APP_TOKEN` can be pulled out of the APK, and I can't tell whether it is set in production. If it isn't, anyone can use /gemini as an open relay for arbitrary prompts (up to 8 KB in, 400 tokens out) and /tts to make any 300-character text in the Ibrahim voice. Limits: 30/min per IP (per worker instance, in memory only, easy to get around with many IPs) plus the daily caps (see 3). A client-caused 400 is retried on every key (worker.js withKeys). No secrets are logged; upstreams are fixed (Hamsa realtime, a single Gemini model); CORS is an allowlist and only enforced by browsers.
7. **Egyptian month spellings `يونيه` / `يوليه` are not parsed** (dialogue.dart:45, :200 match only `يونيو`/`يوليو`). "زرعت في يونيه" gives month=null and Eyad asks again. Proposed fix (not applied, untested in Dart): after the loop at :201, add `if (n.contains('يونيه')) month = 6; if (n.contains('يوليه')) month = 7;`. English `\bdec`/`\bmar` also match "decide"/"mark" (LOW).
8. **Touch targets below 48dp:** RoundButton is 44x44 (ui_kit.dart:243). It is used for Back, Terms, Restart, Send, Close, Type and Listen. Fix: 48x48, or wrap it in `ConstrainedBox(BoxConstraints(minWidth:48,minHeight:48))`. Not applied, because it changes the layout height.
9. **references.md is still marked DRAFT** with "(to confirm)" items (EcoCrop licence, Medhi 2009 citation). The crop SVG illustrations in docs/explorer/img/crops/ and workflow.svg have no stated source. If the team drew them, say so.
10. **README numbers are stale** (README.md:117: "about 266 pass" on a clean clone, "309 with raw data"). The actual count is 272 passed, 154 skipped, out of 426 collected. The README also gives no command for downloading `data/raw/`: `scripts/export_app_data.py` fails with FileNotFoundError `data/raw/power/gharbia_daily.json`. Point to `src/fieldshift/ingest/fetch_power_sites.py`.

## LOW
11. **The voice cancel bug is already fixed on main.** voice.dart:303 has `if (my != _gen) return;` after `_playSource` returns false, and `_playSource` returns early on cancel (:337). No change needed.
12. **Keyboard overflow (fixed, not compiled).** With the keyboard open, the fixed rows (avatar 56, name label, a bubble of up to 110, the typing row, the top bar) can add up to more than the roughly 320dp left on a 360x640 screen, which matches the 1.3px stripe. The existing `kb` compact mode was not enough. Fix in flow.dart:284 and :292: hide the "إياد" label while typing, and wrap the 110-high bubble in `Flexible` so it shrinks and scrolls instead of overflowing. No text changes.
13. goals.dart:253 `goalSpoken` uses `groups['winter']!.first`, which throws on an empty group. The line is also Arabic-only, even in English mode (dialogue.dart:790). Check that English mode does not speak it.
14. **Security grep:** no AIza/sk-/gsk_/ghp_/JWT/"Token xxx" patterns or `key = "..."` literals in tracked files. The only UUID is the public Hamsa voice ID, and the KV namespace id in wrangler.toml is not a secret. .gitignore covers `.env*` and `app/assets/secrets/secrets.json`; .env.example has empty values. **The history could not be scanned: the clone is shallow (1 commit).** Run `gitleaks detect` or `git log -p --all | grep -E 'AIza|sk-'` on a full clone before making the repo public.
15. **Licences are in place:** the IBM Plex Sans licence and the OFL text for IBM Plex Sans Arabic are in both app/assets/fonts and docs/explorer/fonts. The ABOUT.txt files for the avatar and images are present, and the "AI" mark is drawn in the app (eyad.dart:61-68) and on the site (index.html:119, app.js:114).

## Files changed (uncommitted, in the review copy)
- **PR "security/robustness: proxy":** `proxy/worker.js` (dailyCap with no write past the cap and a fallback when KV fails; /tts body size limit; temperature/token clamp that keeps 0) and `proxy/test/worker.test.mjs` (+3 tests). 16/16 pass.
- **PR "bug: keyboard overflow":** `app/lib/flow.dart` (2 lines: hide the name label while typing; Flexible bubble). **Must be checked with `flutter analyze` and on a 360x640 device before merging.**

## Not verified
Anything Flutter or on a device; the production proxy config (APP_TOKEN, ALLOWED_ORIGINS, KV plan); the git history; whether the APK being submitted contains secrets.json; and the README results numbers that depend on data/raw.

## Agent C findings (copy at the review copy, base 6bc1d02)

## AI-tell and credibility findings
Banned vocabulary scan (delve, leverage, seamless, robust, empower, unlock, cutting-edge, harness, holistic, crucial, pivotal...) across README, docs/index.html, docs/demo.md, the explorer (index.html, js), app/lib/terms.dart and i18n.dart: **no hits**. Em dashes in prose: none (the only ones are '—' placeholders for empty table cells in docs/explorer/js/app.js:320, which is fine).

**BLOCKER**
- B1 docs/ai-disclosure.md missing, and README:141 and docs/demo.md said "being updated". *Fixed:* file written; README judges row set to Yes and linked; nav link added; references.md heading now links it.
- B2 docs/explorer/img/crops/*.svg (crop pictures and icons, used by docs/explorer/js/app.js:68-69) carry **no visible AI mark**. Only the field scene has the caption "Illustration: drawn by AI" (i18n.js:48). If these are AI-drawn, the rules require a visible watermark. *Not fixed* (JS, out of my edit scope): add a caption like "Pictures: drawn by AI" on the #crops page, or confirm they were drawn by code. The disclosure states only what is true today.

**HIGH**
- H1 docs/index.html:159 (old) "Anything the AI wrote or voiced is marked as AI": not true. Only the avatar has a mark (app/lib/eyad.dart:68); reworded advice and the voice are disclosed in Terms only. *Fixed:* precise wording.
- H2 docs/index.html stats contradicted README: "5 NASA datasets held" vs "Six NASA datasets used" (same page, line 139); "4 engines" vs README's five (income). *Fixed:* 6 datasets used, 5 engines.
- H3 Test count: index.html said 446 (from status.md:125, "403 Python and 43 Flutter"); README says 309 Python + 62 Flutter = 371; status.md:126 says 306 + 54. *Changed index.html to 371 (309 + 62) to match README.* Tarek must confirm by running both test suites before publishing.
- H4 "independent reviews that caught and fixed real bugs" (index.html, README scorecard) hid that the reviews were AI reviews (README:119 says so). *Fixed:* "independent AI code reviews whose findings we fixed".

**MEDIUM**
- M1 index.html:154 formulaic "built to be checked, not just to look convincing". *Fixed:* "Every number on this page can be traced to a dataset, a table or a paper, and checked."
- M2 index.html:161 filler "The foundations to do it are already in place." *Removed.*
- M3 README:159 "hundreds of automated tests" (vague). *Fixed:* "371 automated tests, 18 golden cases".
- M4 Footer data list omitted NASA SRTM. *Added.*

**LOW**
- L1 README proof.svg alt and graphic: "36 seasons of weather" vs methodology's 35 wheat seasons (36 years). Both are right in context; consider "36 years".
- L2 index.html nav "Why trust it" / heading "Why you can trust it": slightly salesy; "How it is checked" would read better. Left as is.
- L3 explorer i18n.js:129 "Arabic interface text is a draft awaiting native review" is honest; keep until the review is done.

## Arabic flags (for a native speaker; nothing changed)
1. models/blueprints.json:45: "ازرع القمح الأول" means "sow wheat first", English says "sow wheat earlier"; "هتبقى عالية" implies salt will become high. Proposal: "...والملوحة عالية على {crop}. ابدأ بإنك تزرع القمح بدري، واعمل تحليل تربة."
2. models/blueprints.json:14: "مكانك قريب من البحر" says the farm is near the sea; the fact is that the NASA cell is mostly sea. Proposal: "خلية بيانات ناسا عند مكانك أغلبها بحر، فأرقام الحرارة هنا مش دقيقة."
3. docs/explorer/js/app.js:536: "مش أمان، بس مش موثوق" is nonsensical. Proposal: "خلية دمياط أغلبها بحر (صفر أيام حر في كل المواعيد)، فأرقام الحر بتاعتها مش موثوقة."
4. docs/explorer/js/i18n.js:122: "وإيه اللي هي مش هو" garbled. Proposal: "وإيه اللي مش معناها".
5. i18n.js:124: "خمس معايير، وكل واحد بالدليل": number agreement. Proposal: "خمسة معايير، وكل معيار بدليله" (i18n.js:42 already uses "المعايير الخمسة").
6. i18n.js:80: "الملوحة هتقلل شوية" lacks an object. Proposal: "الملوحة هتقلل المحصول شوية".
7. i18n.js:84: "Reduced" as "أقل" is unclear alone. Proposal: "المحصول أقل".
8. i18n.js:64: "White patches" as "بقع ملح" while blueprints.json:244 says "بقع ... بيضا". Pick one term.
9. i18n.js:102: unit dropped. Proposal: "متوسط العظمى في يوليو (درجة مئوية)".
Not checked line by line: app/lib/*.dart Arabic (only a typo regex scan, no hits) and spoken_ar.dart (out of scope).

## Files created or changed (all in the review copy)
- Disclosure: docs/ai-disclosure.md (new); docs/references.md (link line); README.md (judges row, nav link).
- README and copy: README.md (test counts, AI reviews); docs/index.html (stats, AI-mark claim, tests, filler, footer).
- Submission pack: docs/submission/fields.md, tarek_checklist.md, prepublish_checklist.md (new).
- Demo: docs/demo.md rewritten around "4 versus 13 hot days". Verified: docs/methodology.md:28-30 and app/assets/data/heat.json, Gharbia, median 4 (sown 11-01) and 13 (sown 12-01), 35 seasons, hot day = Tmax at or above 32 C. The farmer's line in the script already sows wheat "أول ديسمبر".

## Could not verify
- Current test counts (the three figures in the repo disagree; no full run done here).
- Whether the crop SVGs were AI-drawn (shallow clone, no history; disclosure follows the brief).
- Piper narration and video assembly: not in the repo; included because the brief states them.
- The app's heat page shows 1 November as the comparison date: the explorer does (i18n.js:56); the demo has a note to check on screen.
- The Space Apps website was not fetched again; rules come from docs/submission-rules.md.
- Gemini image generation for the avatar comes from ABOUT.txt only.
