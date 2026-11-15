# Explorer website

A static site for exploring the data, tables and rules behind Eyad: plain HTML, CSS and JavaScript, no build step, no server, no network calls. It works offline in a browser.

**Run it.** Open `index.html` (double click). Every table is also shipped as a `.js` file, so nothing is fetched and `file://` works. On GitHub Pages it is published at `/explorer/` with the rest of `docs/`.

## Pages
| Route | What it holds |
|---|---|
| `#views` | Five paths through the site: farmer, extension officer, researcher, judge, everyone |
| `#learn` | An illustrated Delta field with five hotspots (canal, rice stubble, wheat, salt patch, satellite). Each plays out as cause, effect, what NASA data shows, what Eyad advises. Early and late wheat side by side, then a short step through water, salt and Eyad's advice |
| `#lab` | Place, summer crop, two sowing dates and a salt sign. Eyad's advice and a verdict for your rotation and two alternatives |
| `#crops` | The 14 crops ranked by approximate gross income per feddan, lowered by the salt sign. Crops the season screen cannot judge are dimmed and say why |
| `#compare` | The 19 NASA POWER points ranked on one measure, with a tappable map and a CSV copy |
| `#data` | The six NASA datasets and the role of each, the MODIS winter and summer pictures, the phenology table |
| `#ask` | Ask Eyad: offline, rule based answers from the tables. No AI model |
| `#methods`, `#judges` | The engines, what we do not claim, what is not modelled, and the five criteria with links to the evidence |

The top bar holds a place and wheat date that every page uses, a view selector, English and Arabic (with right to left layout), and a light or dark theme.

## Where the numbers come from
All numbers are lookups or ratios from the same exported tables the app uses (`app/assets/data/`). `js/engine.js` is a port of the engine rules in `docs/site/try.js`, `app/lib/goals.dart`, `app/lib/result_pages.dart` and `app/lib/engine.dart`. Every number on screen carries a source chip that names its file and says what it does not mean.

## How it was checked
- **Same data as the app.** `tests/test_explorer_data.py` fails if any shared table differs from `app/assets/data/` or a `.js` wrapper differs from its `.json`. The one extra file, `site_data_extra.json` (phenology medians and the reasons a crop cannot be judged), was checked against `data/interim/phenology_sites.csv` for Gharbia and matches.
- **Same engine as the app.** Run unchanged against the 18 rotation cases in `app/test/fixtures/rotation_cases.json` (270 values) and the income ranking in `economics_cases.json` (56 values), it gives identical results.
- **No third party requests.** IBM Plex is self hosted (`fonts/`, SIL Open Font License, files from the app). The test above checks that the page loads nothing from another host. IBM Plex Mono is not included, so small labels use the system monospace font.

## Known limits
- **Arabic.** All Arabic interface text is a draft and needs a native Egyptian speaker. The Arabic advice is the team's blueprint text.
- **Listen button.** It uses the browser's own text to speech, not Eyad's recorded Egyptian voice. Whether an Arabic voice exists depends on the device. The button is hidden when speech is unavailable.
- **Devices.** Tested in desktop Chrome and a 390 px phone width, not on Safari, Firefox, a real phone or a screen reader.
- **Ask Eyad** answers in the interface language, even when the question is in the other one. It does not read Coptic months (هاتور، بشنس) or number words for months ("شهر خمسة"). When it cannot answer it says so.
- **The validation table** on the judges page is copied from the main README and is not run again here.
- **Crop ranking** changes with the salt sign but not with the place, because income comes from national averages.
- Settings (place, date, view, language) are kept in this browser only.
