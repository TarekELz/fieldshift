# Field Shift: Egypt

NASA Space Apps Challenge 2026, challenge **"Field Shift: Adapting Farms with NASA Data"** (hackathon 14-15 November 2026). Team based in Egypt.

> **Status (15 Nov, morning):** problem and method chosen. Three engines built and tested (wheat calendar, water, salt) plus a rotation comparison that joins them. Voice assistant, picture card and web page are not built yet. Run the tests: `pip install -r requirements.txt` then `python -m pytest tests`; try the comparison: `python -m src.fieldshift.rotation --site gharbia --signs patches --interval-days 10` (needs the NASA POWER files, see `src/fieldshift/ingest/fetch_power_sites.py`).
> Live status: [`docs/status.md`](docs/status.md). Every decision: [`docs/decisions.md`](docs/decisions.md).

## What we agreed so far

### The problem (decision D1)
Farmers in the **Nile Delta** have to decide each season what to plant and when. Three pressures make that hard, and they interact:

1. **Water:** irrigation water is short and unreliable, worst at the tail ends of canals. In one western Delta study, 58% of tail-end farmers said growing rice had become very difficult, and rice yields fell 30-50% (ghazouani2014).
2. **Salty soil:** 57.2% of surveyed Delta farmers report rising soil salinity (kassem2019). Rice helps wash salt out but is the thirstiest crop, so salt and water pull in opposite directions.
3. **The wheat calendar:** when the summer crop is harvested late, wheat goes in late. Late wheat flowers in spring heat and in field trials lost about 40% of its yield (elbasyoni2018).

Underneath all three: **many farmers cannot read and get little advice.** 31.7% of surveyed Delta farmers are illiterate and most get information from their sons or TV (kassem2019). Only 3.6% of Egyptian farmers surveyed receive climate guidance from government extension (swelam2026).

Evidence for each claim is in [`literature/papers.csv`](literature/papers.csv) (58 papers; only full-text-read papers count as evidence). All candidate problems we considered are in [`docs/problem_statement_options.md`](docs/problem_statement_options.md).

### The idea (decisions D2 and D3)
A **voice assistant in Egyptian Arabic** that a farmer (or their son, or an extension agent) can talk to, built on three **calculation engines**:

| Engine | Question it answers | Main data |
|---|---|---|
| Wheat calendar | "If my summer crop comes off on date X, how risky is wheat sown then?" | NASA POWER daily temperature (1990-2025), MODIS crop phenology and NDVI |
| Water | "How much water does rice / maize / cotton need here this season, against how often I get canal water?" | NASA POWER weather (FAO-56 crop water demand), MODIS / ECOSTRESS evapotranspiration, farmer input |
| Salt | "Which crops can my soil take, and what happens if I drop rice?" | FAO soil and salinity maps, published crop salt tolerance, farmer input |

- **Grounded, not fine-tuned (D2):** the language model only asks the farmer questions, calls the engines, and says their results in simple Arabic. It does not invent numbers.
- **Voice stays (D3):** the engines and a simple picture card are built first so the demo still works if voice fails; a recorded fallback is kept for the video.
- **Open (D4):** how NASA data is presented in the final product is decided after the engines and the assistant exist.
- The tool **supports, and does not replace,** the farmer's judgement and local agricultural experts.

### Region and data (gate G2, not yet decided)
Egypt is the headline. The NASA products are global, so the engines can cover the whole Delta; we will use a few main areas for data pulls and demo examples (Kafr El-Sheikh, Damietta, El-Beheira, Gharbia, Menoufia, Sharqia). Already downloaded by the team for the whole Delta: NASA GPM IMERG daily rain (2015-2025), MODIS NDVI statistics (2015-2025; rasters coming), and SRTM 30 m elevation tiles. Details, resolutions and what each dataset can and cannot say about a 1 ha farm: [`docs/data_plan.md`](docs/data_plan.md) and [`data/catalog.yaml`](data/catalog.yaml).

## Repository map
| Path | What is in it |
|---|---|
| [`docs/brief.md`](docs/brief.md) | The challenge text, verbatim, and what it requires vs leaves open |
| [`docs/submission-rules.md`](docs/submission-rules.md) | Deadline, required fields, **30-second video or 7-slide demo**, AI-use rules, judging criteria |
| [`docs/problem_statement_options.md`](docs/problem_statement_options.md) | The 10 candidate problems, with evidence and other teams' repos checked |
| [`docs/decisions.md`](docs/decisions.md) | Decision log |
| [`docs/data_plan.md`](docs/data_plan.md), [`data/catalog.yaml`](data/catalog.yaml) | Data needed per engine, what we have, what is blocked |
| [`docs/status.md`](docs/status.md) | Current step, what is done, blockers |
| [`literature/`](literature/) | `papers.csv` (paper table) and `search_log.csv` (every search run) |
| [`src/fieldshift/ingest/`](src/fieldshift/ingest/) | Scripts that downloaded the first open datasets |

Raw data (`data/raw/`), paper PDFs (`literature/pdfs/`) and `.env` are not in the repo.

## Working rules
- Read [`AGENTS.md`](AGENTS.md). In short: no secrets in git (use `.env`, copy from [`.env.example`](.env.example)); never invent data or citations; `main` must always run; work on short branches and merge by pull request.
- Decisions that change the problem, scope, region, data, method or claims go through Tarek and are logged in `docs/decisions.md`.
- Before editing a file someone else is working on, check `git log` and ask.

## Team
NASA Space Apps 2026 team, Egypt.
| Member | Area |
|---|---|
| **Tarek** | Lead and story: gates, the farmer conversation in Egyptian Arabic, demo, submission |
| **Hussain** (hussainkzaid) | Data lead and water engine |
| **Al-Ashmawy** | Wheat calendar engine and tests (built first) |
| **Youssef** (Youssefnada-Engineer) | Voice assistant and app |
| **Eyad** (EyadM0hamed) | Salt engine and integration |

**What each person does, step by step:** [`docs/tasks.md`](docs/tasks.md).
