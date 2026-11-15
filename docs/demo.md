# Demo materials (DRAFT for the team)

The rules allow either a 30-second video or a slide deck of up to 7 slides (title and intro included). The demo is in English; a video may be spoken in Arabic if it has English subtitles. Judges score Presentation from the demo and the full project, so the story matters as much as the screens.

## 30-second video (shot list with English subtitles)
Total 30 seconds. Screen-record the Android app on a phone; use the Egyptian voice as it is.

| Seconds | Picture | Arabic voice (Eyad or the narrator) | English subtitle |
|---|---|---|---|
| 0 to 4 | A farmer's field, then the Nile Delta from NASA MODIS (the picture in the app) | (music only) | "Delta farmers decide what to plant and when, with little advice." |
| 4 to 10 | The app opens; Eyad asks; the farmer speaks | «أنا في الغربية، بزرع رز في نص يونيو وقمح في أول ديسمبر» | "He just says where his field is and what he grows." |
| 10 to 16 | The goal question, then the verdict page | «إيه أكتر حاجة بتدور عليها دلوقتي؟» | "Eyad asks what he is looking for, and answers with a verdict for each crop." |
| 16 to 23 | The advice page; Eyad speaks it | «بلاش تزرع القمح متأخر كده... لو تعرف تعمل تحليل تربة هيكون ممتاز جدًا.» | "Advice in his own dialect: do this, because of that." |
| 23 to 28 | Water, heat and salt pages; NASA POWER and MODIS captions | (music) | "Every number comes from NASA weather and satellite data and FAO tables, not from the AI." |
| 28 to 30 | Title card: Field Shift, team, "NASA Space Apps 2026" | | "Field Shift: the right crop at the right time." |

Tips: record on a real phone in quiet surroundings; keep the "AI" mark on Eyad visible; do not use music you do not have permission to use (the rules forbid copyrighted material); the voice you hear is AI-generated and is listed in the AI disclosure.

## 7 slides
1. **Title.** "Field Shift: the right crop at the right time." Team, Mansoura Local Event, challenge name. One picture: the Delta from NASA MODIS.
2. **The problem.** Three pressures, each with one figure and its source: water (58% of tail-end farmers said rice had become very difficult, ghazouani2014), salt (57.2% report rising salinity, kassem2019), the wheat calendar (about 40% yield loss in late-sown trials, elbasyoni2018). And 31.7% of Delta farmers are illiterate.
3. **Our idea.** Eyad: a voice assistant in Egyptian Arabic that asks what the farmer wants and answers with a verdict, then water, heat and salt. Screenshots 02 and 04 from `docs/screenshots/`.
4. **How it works.** Ask, compute, advise. Engines (heat, water, salt, season, income) on NASA data; code chooses the advice; the AI only rewords it behind a guard.
5. **NASA data.** Six datasets and what each does (POWER drives every number; MODIS for pictures and phenology; MOD16 and SRTM as checks; IMERG for context). Say plainly which are used how. Then FAO and FAOSTAT as non-NASA tables.
6. **How we checked it.** ET0 within 1 to 8% of NASA's own MOD16; phenology consistent with the calendar; golden tests between Python and the app; independent reviews. Limits: no yield forecast, income is a national-average estimate before costs.
7. **Impact and next steps.** Who it helps; what is next (station validation, more crops with costs, tests with farmers). Link to the project page and repository.

## What to say about AI (all slides and the video)
Eyad's picture and voice are AI-generated and marked as such. The advice is written from templates by the team; an AI model may reword it only if every number and key fact survives. See `docs/ai-disclosure.md` (to be updated before the repository is made public).
