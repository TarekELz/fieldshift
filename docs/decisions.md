# Decision log

A decision is anything that changes problem, scope, region, data, method, stack or claims.
Tarek decides; this file records it.

| id | time (local) | question | options | choice | decided by | evidence |
|---|---|---|---|---|---|---|
| D1 | 2026-11-14 ~17:30 | G1: which problem(s)? | 10 candidates in docs/problem_statement_options.md | Egypt (Nile Delta) farmers: water shortage (4), soil salinity (5), the wheat/summer-crop calendar (6), with illiteracy and "not knowing what and when to plant" (3) as the reason for a voice interface | Tarek (team idea) | kassem2019, swelam2026, ghazouani2014, hagage2024, elbasyoni2018, elfetyany2026 |
| D2 | 2026-11-14 ~18:00 | How the AI part works | fine-tune a chatbot vs grounded: calculation engines + a language model that only asks questions, calls the engines and phrases their results | Grounded engines, not fine-tuning | Tarek ("ok I agree") | Validity criterion; no Egyptian farmer dialogue data to fine-tune on |
| D3 | 2026-11-14 ~18:00 | Keep live voice despite build risk? | voice / text + card only / recorded voice | Keep voice; engines and a picture card still built first, recorded fallback for the video | Tarek ("I still want voice") | kassem2019 (31.7% illiterate), swelam2026 |
| D4 | open | How NASA data is framed in the product (engines as the product vs assistant as the product) | see Tarek's reply | Deferred until engines and chatbot exist | Tarek | Relevance criterion |
| D5 | 2026-11-14 ~17:30 | G2: region and points | US only / Egypt only / both; point sets | Egypt, whole Delta, with six example areas in models/sites.yaml (Kafr El-Sheikh, Damietta, Beheira, Gharbia, Menoufia, Sharqia). Points are provisional until checked as farmland | Tarek (whole Delta, main areas; told the agent to proceed; the six specific points were proposed by the agent and not individually confirmed) | docs/data_plan.md |
| D6 | 2026-11-14 ~17:25 | Who does the work | split by member / central build | Central build with the AI assistant; members do small independent tasks (docs/tasks.md) and the assistant reviews | Tarek | - |
| D7 | 2026-11-15 ~09:30 | G3: method for each engine | wheat A/B/C, water A/B/C, salt A/B/C (docs/methodology.md) | Wheat B (thermal time, shown as a sowing-date comparison); water A (FAO-56, ratios); salt A (tolerance lookup, first to cut) | Tarek, by delegation: he asked for two independent reviews and for the choice to follow them ("run 2 agents to revise this work and choose what to do", then "complete"). Both reviewers recommended these options. Tarek can overrule | review reports of 2026-11-15; elbasyoni2018 |
