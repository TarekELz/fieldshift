# Roles and what each of us does

Confirmed by Tarek on 2026-11-14. The main build (engines, documents, review) is done centrally with an AI coding assistant under Tarek's direction. **Each member's job below is small, concrete and independent**, so nobody has to wait for anyone else. If something is unclear, ask Tarek in the group chat.

**Rules for everyone**
- Start with `git pull`. Read the [README](../README.md) first (5 minutes).
- Do not commit big files (anything over about 5 MB), passwords, tokens, or AppEEARS `*-request.json` files (they contain your email).
- Put your results where the task says, then tell Tarek. If you prefer not to use git, send the file to Tarek.
- Never invent a number. If you cannot find a source, write "not found".

---

## Tarek: lead and story
1. **Find our deadline.** Open our team page on spaceappschallenge.org, check which Local Event we are registered in, and ask the Local Lead whether there is a local pitch and when. *Done when:* the event name and exact deadline are in `docs/status.md`.
2. **Write the farmer conversation in Egyptian Arabic** (about 1 hour). In a text file, write how a farmer would really say these, and how a trusted agent would answer in one or two short spoken sentences:
   - "What should I plant this summer?"
   - "My rice came off late. When can I sow wheat?"
   - "The canal reaches me every 10 days. Is rice possible?"
   - "There is white crust on my soil. What can I grow?"
   - plus the 4 or 5 questions the assistant must ask the farmer first (where is the field, what was the last crop, how often does water come, any salt signs).
   *Put it in:* `app/conversation_ar.md`. *Done when:* a teammate reads it aloud and it sounds natural.
3. **Confirm the avatar** (about 5 minutes). Eyad's pictures are an AI-generated cartoon of a friend's face (the file is named by Gemini). Check with that friend: (a) they agree to being the face of the app, and (b) they are over 18 (Tarek stated on 2026-11-15 that the friend is 22, so (b) is settled; (a) consent still to be confirmed) (the competition does not allow likenesses of people under 18). Until confirmed, do not push or publish `app/assets/eyad/`. The "AI" mark must stay on every use of the pictures (app, slides, video).
4. **Decide at the gates** when asked (method G3, scope G4, demo G5, final claims G6).
5. **Record the 30-second demo** on Sunday (or approve the 7 slides).

## Hussain: data
1. **Share the big files** (about 20 minutes). Upload the MODIS GeoTIFFs and SRTM tiles you have to a shared drive folder, and write the link in `data/NOTES.md`. Do not put them in git.
2. **Check our six points are farmland** (about 20 minutes). Open each coordinate from `models/sites.yaml` in Google Maps satellite view. For each one write: fields / town / water / desert, and a better nearby coordinate if it is not fields. *Put it in:* `data/NOTES.md`, a small table.
3. **Request water-use data from AppEEARS** (about 30 minutes, you already know the tool). New *point* request, the six coordinates from `models/sites.yaml`, product **MOD16A2GF.061**, layers `ET_500m` and `PET_500m`, dates 2015-01-01 to 2025-12-31, CSV output. *Put the results CSV in:* `data/MODIS_nile/` (it is small). Leave out the request JSON.
4. If time remains: the same kind of request for **MCD12Q2.061** (layers `Greenup`, `Maturity`, `Senescence`, `Dormancy`, `NumCycles`), 2015 to 2023.

## Al-Ashmawy: tester for the wheat calendar engine
1. **Run the tests** once the engine is pushed (Tarek will say when): `python -m pytest tests/`. *Done when:* you report pass or fail with the output.
2. **Try to break it** (about 1 hour). Run it for strange inputs: sowing on 1 October, 28 February, 29 February in a leap year, a site name that does not exist, a date typed wrongly. Write down every case where it crashes or gives a silly answer. *Put it in:* a GitHub issue per bug, or a list sent to Tarek.
3. **Find the official Egyptian advice on wheat sowing dates** (about 30 minutes). Search in Arabic for the Ministry of Agriculture / Agricultural Research Center recommendation (for example "ميعاد زراعة القمح الوجه البحري"). Save the link, the date of the page, and the exact sentence. *Put it in:* `literature/local_sources.md`. This checks our engine against what farmers are told.

## Youssef: voice and phone testing
1. **Test on a real Android phone** (about 1.5 hours, the most valuable task). Install the app from `app/build/app/outputs/flutter-apk/app-debug.apk` (Tarek will send the file; USB debugging or "install unknown apps" on the phone). Try the whole conversation by voice and by typing. For each of the six questions note: did it hear you correctly (what you said / what appeared), did it speak in Arabic, any crash. *Put it in:* `docs/phone_test.md`, a table. Take 3 screenshots of the result card.
2. **Compare speech recognition on Egyptian Arabic** (about 1 hour). Say 10 short answers (for example "نص نوفمبر", "كفر الشيخ", "كل ١٠ ايام", "في قشرة بيضاء"). Count how many the phone understood. If fewer than 7 of 10, tell Tarek: we will add a typed or button fallback to the demo, or try a cloud speech service.
3. **Check the phone has an Arabic voice** (Settings, Language, Text-to-speech output). Write down the phone model, Android version, and whether Arabic is installed.
4. Keys for any paid or free API go in your own `.env`, never in git or chat.

## Eyad: salt data, then integration testing
1. **Build the crop salt-tolerance table** (about 1 hour). Source: FAO Irrigation and Drainage Paper 29, "Water quality for agriculture" (Ayers and Westcot), the crop tolerance table (free on fao.org). For wheat, rice, maize, cotton, berseem clover, sugar beet, barley, faba bean and tomato, copy: the soil salinity (ECe, dS/m) at which yield is 100%, 90%, 75% and 50%. *Put it in:* `models/salt_tolerance.csv` with columns `crop, ece_100, ece_90, ece_75, ece_50, source_table, page_or_url`. Copy numbers exactly; leave a cell empty if the table does not give it.
2. **Get the soil map** (about 45 minutes). From the FAO soils portal download the Harmonized World Soil Database v2.0 (raster and database). Do not commit it. Write in `data/NOTES.md` where you saved it and its size.
3. **Later, on Sunday:** run the whole demo from a clean clone with the internet off and write down anything that fails. Tarek will say when.

---

## Priorities and cut order
- The wheat calendar engine and a comparison card are the minimum product.
- If time runs short we cut: the salt engine first, then live voice (we fall back to a recording), then detail in the water engine.

## Open before the detailed build plan
- G3: the method for each engine (`docs/methodology.md`).
- Speech and language-model providers, and who holds the keys (after Youssef's test).
