# Demo materials (draft for the team)

The rules allow either a 30-second video or a slide deck of up to 7 slides (title and intro included). The demo is in English; a video may be spoken in Arabic if it has English subtitles. Judges score Presentation from the demo and the full project.

## The story in one line
**The same field, two sowing dates: 4 versus 13 hot days, and Eyad says what to do, in the farmer's own words.**

The numbers are from `docs/methodology.md` (wheat heat by sowing date, Gharbia): wheat sown on 1 November meets a median of 4 hot days (maximum 32 °C or more) while filling its grain; sown on 1 December it meets 13 (median of 35 seasons of NASA POWER weather, 1990 to 2025). Say "hot days while the grain fills", never "yield loss": we do not convert hot days into yield.

## 30-second video (shot list with English subtitles)
Screen-record the Android app on a phone; use the Egyptian voice as it is. The farmer in the clip sows wheat at the start of December, which is the 13-day case.

| Seconds | Picture | Arabic voice (Eyad or the narrator) | English subtitle |
|---|---|---|---|
| 0 to 4 | The Nile Delta from NASA MODIS (the picture in the app) | (no speech) | "One Delta field. One question: when to sow the wheat." |
| 4 to 10 | The app opens; Eyad asks; the farmer speaks | «أنا في الغربية، بزرع رز في نص يونيو وقمح في أول ديسمبر» | "He says where his field is and what he grows." |
| 10 to 18 | The heat page: 1 November against 1 December | (no speech) | "Sown 1 November: 4 hot days while the grain fills. Sown 1 December: 13. NASA weather, 35 seasons." |
| 18 to 25 | The advice page; Eyad speaks it | «بلاش تزرع القمح متأخر كده... لو تعرف تعمل تحليل تربة هيكون ممتاز جدًا.» | "Eyad says what to do, in his own dialect." |
| 25 to 28 | Water and salt pages, NASA POWER caption | (no speech) | "The numbers come from NASA data and FAO tables. The AI only rewords." |
| 28 to 30 | Title card: Field Shift, team, "NASA Space Apps 2026" | | "Field Shift: the right crop at the right time." |

Check before recording: the heat page for Gharbia with wheat on 1 December shows 13 and the early date shows 4; if the screen shows a different early date, change subtitle 3 to what the screen shows. Keep the "AI" mark on Eyad visible. Use no music you lack permission for. Put the AI statement (Eyad's voice and picture are AI-generated; narration, if any, is Piper text-to-speech) in the video description.

## 7 slides
1. **Title.** "Field Shift: the right crop at the right time." Team name, member names, Mansoura Local Event, challenge name. Picture: the Delta from NASA MODIS.
2. **One field, two dates.** Gharbia wheat: 4 hot days in grain filling if sown 1 November, 13 if sown 1 December (NASA POWER, 35 seasons). Field trials: wheat sown 7 to 13 January lost about 40% of its yield against mid-November (elbasyoni2018).
3. **Why voice.** 31.7% of surveyed Delta farmers are illiterate and most get information from their sons or TV (kassem2019). Water (58% of tail-end farmers said rice had become very difficult, ghazouani2014) and salt (57.2% report rising salinity, kassem2019) pull against the calendar.
4. **Eyad.** He asks what the farmer wants, gives one verdict per crop, then water, heat and salt. Screenshots 02 and 04 from `docs/screenshots/`.
5. **How it works.** Five engines (heat, water, salt, season, income) on NASA POWER and FAO tables; code chooses the advice; an AI only rewords it behind a guard that keeps every number.
6. **NASA data and checks.** POWER drives every number; MODIS gives the pictures and a phenology check; MOD16 (ET within 1 to 8% at 7 points) and SRTM as input checks; IMERG for context. Limits: no yield forecast; income is a national average before costs.
7. **Next.** Station validation, more crops with costs, tests with farmers on real phones. Links to the project page and repository.

## What to say about AI
Eyad's picture and voice are AI-generated and marked as such. Code chooses the advice from the team's blueprints; an AI model may reword it only if every number and key fact survives. Full statement: [ai-disclosure.md](ai-disclosure.md).
