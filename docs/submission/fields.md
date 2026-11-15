# Submission form: copy-paste text

Every figure below is taken from the README, `docs/methodology.md`, `data/catalog.yaml` or `docs/references.md`. Check each link while logged out before pasting.

## Project title
Field Shift: Egypt

## Short summary (under 200 characters)
Eyad, a voice assistant in Egyptian Arabic, tells Nile Delta farmers what to grow and when, using NASA POWER weather and FAO tables, and shows the numbers behind each answer.

## Challenge
Field Shift: Adapting Farms with NASA Data

## Full description
Nile Delta farmers choose each season what to plant and when, under three pressures that interact: short canal water (58% of tail-end farmers in a western Delta study said rice had become very difficult; ghazouani2014), rising soil salt (reported by 57.2% of surveyed Delta farmers; kassem2019) and a tight wheat calendar (wheat sown 7 to 13 January lost about 40% of its yield against mid-November sowing; elbasyoni2018). 31.7% of surveyed Delta farmers are illiterate and most get information from their sons or TV (kassem2019), so Field Shift is a voice assistant, not a dashboard.

The farmer tells Eyad, in Egyptian Arabic, where the field is, what he grows and when, and what he wants most: to earn more, to grow a certain crop at a certain time, or to improve what he grows now. Five deterministic engines answer: wheat heat during grain filling by sowing date (thermal time on 35 seasons of NASA POWER daily weather, 1990 to 2025), summer-crop water need (FAO-56 on NASA POWER), salt tolerance (FAO-29), a sowing-season screen (FAO EcoCrop against NASA POWER) and approximate gross income per feddan (FAOSTAT Egypt averages, lowered by the salt factor). Eyad gives one verdict per crop, then water, heat and salt pages. Example: in Gharbia, wheat sown on 1 November meets a median of 4 hot days (32 °C or more) while filling grain; sown on 1 December it meets 13.

Code chooses the advice from blueprints the team wrote. An AI model may only reword that advice, and a guard throws the rewrite away if it changes a number or drops a key fact. The engines, the advice and the recorded voice lines work offline. A Professional view shows the numbers for agronomists and researchers, including a comparison of all 19 NASA data points. A static explorer website and a project page use the same tables and rules as the app.

Checks: the engine's yearly reference evapotranspiration is within 1 to 8% of NASA MOD16A3GF potential ET at 7 points; NASA MCD12Q2 phenology agrees with the crop calendar; NASA SRTM terrain confirms which data cells sit on the floodplain; Python and Dart agree on 18 golden cases. Limits: no yield forecast, income is a national average before costs, soil salt comes from the farmer because no NASA product measures it.

## How NASA data is used
- **NASA POWER daily agroclimatology, 19 Delta points (7 named, 12 more cells), 1990 to 2025:** every number the farmer sees (wheat heat days, crop water need, season screen, climate charts).
- **MODIS MOD13Q1 v061 NDVI:** the winter and summer Delta pictures in the app and on the web; a plausibility check of the wheat calendar. No farmer-facing number.
- **MODIS MCD12Q2 v061 phenology:** cross-check of the wheat and summer-crop calendar; shown in the season lab.
- **MODIS MOD16A3GF v061 yearly ET:** input check of the engine's reference ET (within 1 to 8% at 7 points).
- **SRTMGL1 v003 terrain:** check of the 19 data points (floodplain vs desert-edge cells).
- **GPM IMERG daily precipitation:** context: summer rain is almost zero, so summer crops depend on irrigation.

## Space agency partner data
ESA WorldCover 2021 (10 m land cover) was used to confirm that the data points are cropland (73 to 91% within 2.5 km of six points). No other partner-agency data.

## Tools and languages
Python (numpy, rasterio, pyhdf, requests, PyYAML, Pillow, pytest); Dart and Flutter (Android app; speech_to_text, flutter_tts, audioplayers, http, shared_preferences); HTML, CSS and JavaScript (project page and explorer, no build step); Cloudflare Worker (JavaScript key proxy); GitHub Actions CI. AI services: Gemini API, Hamsa text-to-speech (see AI use below).

## References
Paste from `docs/references.md` (NASA data with DOIs, FAO and other tables, literature read in full, software and fonts). Full paper table: `literature/papers.csv`.

## Did you use AI (SI) tools? How?
Yes. Claude (Anthropic) through Claude Code was the coding and research assistant across the repository, and with an AI assistant built the explorer website, its illustrations and first drafts of the Arabic text. At run time the Gemini API rewords the advice that code has already chosen (a guard rejects any change to numbers or key facts) and classifies a short farmer phrase that matches no option. Gemini also added diacritics to spoken lines and transcribed recorded clips for a quality screen. Eyad's voice is Hamsa text-to-speech (voice Ibrahim); his avatar was generated with Google Gemini and carries a visible "AI" mark. The demo narration is Piper text-to-speech. The idea, the decisions, the engines, the data, the advice blueprints and every number are the team's. Details: docs/ai-disclosure.md.
