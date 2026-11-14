# Problem statement options (for gate G1)

Written 2026-11-14 after Step 3. This file describes problems only. It contains no solutions or product ideas.

## How to read this
- **Evidence** counts only papers whose full text was opened (17 of the 40 in `literature/papers.csv`). Three were read through (weisberger2021, nowatzke2024, and the results/discussion/conclusions of kassem2019). For the other 14 the full text was opened and the passages on farmer problems were read, not every page.
- Abstract-only papers are listed as "not evidence" so you can see what might strengthen or weaken a candidate later.
- Candidates are ordered by number of independent full-text sources. The counts are small and close together, so the order is weak. Data fit and feasibility are separate columns and did not affect the order.
- The search ran 2 loops (6 literature queries, 2 critique searches) and stopped at the 90-minute limit. Salinity only became a separate candidate in loop 2, so the list was not yet stable across two loops.
- Citation counts are in `literature/papers.csv` (OpenAlex and Consensus, 2026-11-14). They were not used for ordering.

## Summary table

| # | Problem | Full-text sources stating it | Site | Can NASA data address it? | Do we hold that data? | Rough demo feasibility |
|---|---|---|---|---|---|---|
| 1 | Farmers know diverse rotations help the soil but markets, land rents, crop insurance and equipment keep them in corn-soybean | 6 | US | Largely no. The barriers are economic and institutional | CDL crop history at Mead (yes). No market, rent or insurance data | Low for a NASA-data project |
| 2 | Farmers cannot tell whether a different rotation would pay off on their own land, especially as weather gets more variable; the science says the benefit varies by place and year | 3 farmer-reported + 4 agronomic | US mainly; one Egypt source | Partly. Weather, soil-moisture and vegetation history describe the conditions; they do not measure yield or profit | POWER both sites (yes), PRISM and CDL at Mead (yes). SMAP, IMERG, NDVI (no) | Medium to high at Mead; medium in Egypt |
| 3 | Delta farmers get little timely, trusted, local advice; extension reaches few; digital tools are rarely used | 5 | Egypt mainly; tool-uptake evidence from UK and US | Only as content. The gap is delivery, trust and literacy, not missing satellite data | POWER (yes) | Medium |
| 4 | Irrigation water in the Delta is short and unreliable, worst at canal tail ends, and it is forcing crop changes and yield losses | 4 | Egypt | Partly. Crop water demand and evapotranspiration, yes. Canal supply to a field, no | POWER (yes). ECOSTRESS, MODIS/Landsat ET (no) | Medium |
| 5 | Soil salinity and waterlogging limit what Delta farmers can grow, and rice, the crop that controls salt, is also the thirstiest | 4 | Egypt, strongest in the northern Delta | Weakly. No NASA product in the brief measures soil salinity directly | Nothing. SoilGrids for our Egypt point is empty | Low to medium |

## 1. Structural lock-in to corn-soybean (US)
**Statement.** Midwest farmers largely agree that longer rotations improve soil and cut pest pressure, but say they cannot adopt them because of things outside the farm gate: no market for a third crop, high land rents, crop insurance rules, missing equipment, and the loss of livestock that once used forage and small grains.

**Strongest full-text sources**
- weisberger2021 (Iowa, n=786): 83% agree extended rotations improve soil health. Barriers rated important or very important: lack of markets 82%, land rents 81%, lack of elite varieties 65%, technical support 59%, equipment 58%. The authors conclude the main barriers "cannot be addressed by individual farmers".
- asprooth2025jswc (four states, n=406): among farmers who stopped or never grew small grains, low prices (45%) and lack of markets (43%) lead; technical assistance was chosen by 2%.
- nowatzke2024 (11 interviews): crop insurance does not cover some alternative crops in some counties; rented land discourages long-term changes; structural barriers "could make DSS a null point unless also addressed".
- Also: asprooth2025rafs (n=725, economic barriers), socolar2021 (1.5 million fields: rotations are simplest on the best land and near biofuel plants), upadhaya2021 (n=1059: reliance on crop insurance linked to maladaptive responses).

**Not evidence yet (abstract only):** roeschmcnally2017 (paywalled, the most cited paper on this), wang2021, kasu2019, francis2024.

**Site fit.** US only. Our Mead centre point is corn in 14 of 17 years (CDL 2008-2024), so the pattern is visible there.
**NASA data.** Does not address markets, rents or insurance. USDA CDL shows the rotation pattern itself.
**Novelty risk.** Low risk of duplication, but high risk of a low Relevance score: NASA data would be peripheral.
**Counter-evidence.** kluger2025 finds farmers who rotate already tend to pick the most beneficial precrops, and that going beyond two crops gave small, sometimes negative yield effects. That suggests part of the "lock-in" is rational.

## 2. Uncertain, place-specific payoff of changing a rotation (US mainly)
**Statement.** Farmers are unsure whether a different rotation would be worth it on their own fields, and they want multi-year, local evidence before changing. Agronomic studies agree the benefit is real on average but varies with site, sequence and weather, and can take years to appear.

**Strongest full-text sources (farmer-reported)**
- weisberger2021: only 28% agree extended rotations can be as profitable as corn-soybean; 41% are uncertain. 75% rate "strong documentation of the economics/longer-term profitability" as important.
- nowatzke2024: farmers judge fields using 5 to 15 years of layered data (yield, soil maps, satellite imagery, elevation) plus their own observation; they report public soil maps as hit-or-miss and single data sources as inadequate.
- swelam2026 (Egypt, n=2953): 33.6% cite uncertainty about whether recommended practices work.

**Supporting full-text sources (agronomic)**
- kluger2025: states a knowledge gap on how rotation benefits vary with sequence and weather; legume precrop benefits were smaller under warmer conditions.
- sutton2025: benefits for yield stability took several years to appear on working farms.
- renwick2021: diversified rotation cut drought yield loss by 17.1% in one long-term trial, by a mechanism the authors could not fully explain.
- smith2023: yield benefit is real across 32 trials, but each farmer must weigh it against markets, skills and soils.

**Not evidence yet:** bowles2020 (the main paper on rotation and drought resilience; open access, not yet read), bybeefinley2024, costa2024, shekhar2022, and two that cut the other way: johnson2026 (3-crop rotation yielded less in drought years at two Minnesota sites) and shekhar2019 (paywalled; in north-east Nebraska continuous corn out-yielded corn-soybean under extreme drought).

**Site fit.** US evidence is strong. For Egypt only one source, and rotation is already near-universal there (96.6% in swelam2026), so the Egyptian form of this question is which crops, not whether to rotate.
**NASA data.** POWER, IMERG, SMAP and MODIS/Landsat can describe a location's weather, soil-moisture and vegetation history. None of them measures a field's yield or profit. Scale (product specifications, not from the papers): POWER is about 50 km, SMAP 9 km, MODIS 250 m. Delta holdings are about 1 ha (abstracts of abdalla2023b and dhehibi2015; kassem2019 reports 70.3% at 10 feddan, about 4 ha, or less). Field size at Mead has not been measured here.
**Data we hold.** POWER 1990-2025 at both sites, PRISM and CDL at Mead. No SMAP, IMERG or NDVI yet.
**Novelty risk.** High. At least three other public Field Shift repos are generic "what to plant next" rotation advisors (Saskatchewan, Bangladesh, one unspecified; README headers only were read).

## 3. The advice gap for Delta smallholders (Egypt mainly)
**Statement.** Farmers in the Delta see the climate changing but get little usable guidance. Extension reaches few of them, many cannot use written material, and existing digital tools are rarely used. Studies in the UK and US find the same low uptake of decision tools for different reasons (usability, cost, trust, poor fit to how farmers decide).

**Strongest full-text sources**
- swelam2026: 3.6% receive climate guidance from government extension; 47.1% rely on other farmers. Digital tools: 3.9% use them fully, 23.1% are unfamiliar with them. 84.6% want awareness programmes. The authors call it an "information-poverty trap".
- kassem2019 (n=792, two Delta governorates): 51.9% had no knowledge of climate change; 31.7% are illiterate; the main information source is their sons (59.6%), then TV (33.7%); extension 13.5%. Extension contact had no significant effect on adoption.
- rose2016 (UK): tool uptake is low despite many tools; use depends on usability, cost-effectiveness, performance, relevance, trust and compliance needs.
- Also: nowatzke2024 (tools clunky, costly, ignore soil health), attaher2009 (farmers want "a clear scientific message").

**Not evidence yet:** fahmy2021 (farmers rate available hydro-climatic information as poor), abdalla2023a, badawy2022, thar2021 (prescriptive tools are not what many smallholders want), adereti2023, rose2018.

**Site fit.** Egypt strongly. The US and UK sources are about tool design, not access.
**NASA data.** NASA data can supply content, but the problem as stated is about reach, trust and literacy.
**Novelty risk.** Medium. Every team will claim to be farmer-friendly; few will have evidence on who the farmer is.
**Counter-evidence.** kassem2019 found extension contact did not change adoption, and swelam2026 found adaptation follows tangible results and money, not awareness. More information alone may not change decisions.

## 4. Short and unreliable irrigation water in the Delta (Egypt)
**Statement.** Farmers, especially at the tail ends of canals, do not get enough water at the right time. They respond by dropping thirsty crops, buying pumps and reusing drainage water, and they report large yield losses.

**Strongest full-text sources**
- ghazouani2014 (one branch canal, western Delta): in a tail-end location 58% said growing rice had become very difficult and 50% had given up vegetables. Reported yield drops: about 25% for rice and maize mid-canal, 30-50% for rice at the tail. Rice share of area falls from 33% at the head to 6-8% at the tail.
- kassem2019: 25.7% report higher water requirements; in Kafr El-Sheikh 64.8% shortened irrigation intervals because of heat.
- swelam2026: 21.8% name water scarcity as a barrier.
- ayyad2024: rice, maize, wheat and berseem take about half of the harvested area and renewable freshwater.

**Not evidence yet:** ouda2015 (water needs projected +10-15% for maize by 2040), abdalla2023b (irrigation frequency explained 38% of wheat yield variation; not in papers.csv, metadata lookup failed), badawy2022, abdelaziz2025.

**Site fit.** Egypt. The detailed farmer evidence is one canal in the western Delta with fieldwork before 2014; our pilot point near Tanta is central Delta, and no source describes that location.
**NASA data.** POWER gives the weather needed to estimate crop water demand; ECOSTRESS and MODIS/Landsat give evapotranspiration (ECOSTRESS has about 5 times fewer scenes over Egypt). No satellite product shows how much canal water reaches a 1 ha field or when.
**Data we hold.** POWER only.
**Novelty risk.** Low to medium. None of the other repos found targets an irrigated delta.

## 5. Salinity and waterlogging, and the rice dilemma (Egypt)
**Statement.** Salt and a high water table limit which crops will grow in parts of the Delta. Rice is grown partly to flush salt, but rice is the heaviest water user, so the salt problem and the water problem pull the rotation in opposite directions.

**Strongest full-text sources**
- hagage2024 (north-eastern Delta, measured): 64% of soil samples strongly or very strongly saline; 87.5% of irrigation water samples under severe restriction; saline groundwater at 0.5-3 m.
- kassem2019: 57.2% of farmers report increased soil salinity; 38.1% plant salinity-tolerant varieties.
- ghazouani2014: upstream farmers are "bound to a regime that prioritizes salinity control based on frequent rice cultivation", which raises the water table and rules out other crops.
- attaher2009: salinity and waterlogging listed among the main vulnerabilities.

**Not evidence yet:** kotb2000 (paywalled; the main paper on rice and salinity policy), mohamed2016 (paywalled; 37% of cultivated Delta soils salt-affected, 46% in the north), amer2021.

**Site fit.** Evidence concentrates on the northern Delta. Whether it applies near Tanta is unverified.
**NASA data.** Weak. hagage2024 used Sentinel-2 (ESA) and SRTM (NASA elevation) alongside field samples. SMAP, POWER and IMERG do not measure salinity.
**Data we hold.** None. Our SoilGrids file for the Egypt point is empty.
**Novelty risk.** Low duplication risk; high risk of not being able to show anything measured.

## Things that apply to every candidate
- **The brief is about rotation choice.** Relevance is judged on that and on NASA data being central. Candidates 1 and 3 are real problems where NASA data is peripheral.
- **Scale.** No NASA product in the brief resolves a 1 ha Delta holding except Landsat (30 m) and ECOSTRESS (70 m). POWER and SMAP describe a district, not a field.
- **Ground truth.** Mead has AmeriFlux, PRISM, CDL and SSURGO. For the Delta we hold no soil, crop-history or ground weather data.
- **Papers I could not open** are listed in the G1 message. Four are paywalled; several open-access ones blocked automated access and were not read for lack of time.


---

# Loop 3: more problems from the Egyptian literature (added 2026-11-14 at Tarek's request)

Search: 6 more queries, Egypt only (ids 9-14 in `literature/search_log.csv`). 18 papers added to `literature/papers.csv`; 4 opened in full text. Several Egyptian journal PDFs and ScienceDirect pages showed a browser check, which I did not bypass, so those stay abstract-only. Same rules as above: problems only, ordered by full-text evidence, data fit in separate columns.

| # | Problem | Full-text sources | Abstract-only signals | Site | Can NASA data address it? | Do we hold that data? | Rough demo feasibility |
|---|---|---|---|---|---|---|---|
| 6 | Rotation calendar squeeze: the previous crop finishes late, wheat goes in late, and late wheat meets spring heat and rust | 2 (elbasyoni2018, elfetyany2026), plus kassem2019 on changed planting dates | mohiy2021, ali2020, gamal2024, dadrasi2024, sorour2018, abokhadra2019, eid2007 | Egypt, whole Delta | Yes, centrally: daily max/min temperature, heat days at flowering, growing degree days | POWER daily Tmax/Tmin 1990-2025 at the Delta point (yes) | Medium to high |
| 7 | Forage squeeze: smallholders rely on berseem and fodder maize for animals; feed costs and rents are rising and families are selling animals | 1 (hautbout2025), plus ayyad2024 on berseem area | abuzaid2021, abdalla2023a | Egypt | Partly: berseem water demand and season length; not prices | POWER (yes) | Medium |
| 8 | Pests and diseases rising with heat | 2 (kassem2019: 81.4% report more; elbasyoni2018: heat raised rust) | none added | Egypt | Partly: weather that favours disease; not pest counts | POWER (yes) | Low to medium |
| 9 | Rice straw burning (the "black cloud") | 1 (kassem2019: 45.4% compost partly to reduce it) | elsafty2020, zaghloul2018 (about 3 million t straw a year) | Egypt rice areas | Detection yes (NASA FIRMS active fire), but FIRMS is not in the brief's list | No | Medium |
| 10 | Farmland lost to buildings and split by inheritance | 2 (radwan2019: 74,600 ha lost 1992-2015; hautbout2025: most farms under 0.5 ha) | sattar2024, abay2022 | Egypt | Mapping yes (Landsat), but it is land policy, not rotation choice | No | Low for this brief |

## 6. The rotation calendar squeeze (Egypt)
**Statement.** In the Delta the winter and summer crops follow each other with little slack. When the previous crop is harvested late, or farmers fit in a short cash crop first, wheat is sown late. Late wheat flowers and fills grain in hotter weather and loses yield.

**Full-text evidence**
- elbasyoni2018 (Delta clay and reclaimed sand, 3 seasons): late sowing caused about 40% yield loss, partly because heat raised leaf and stem rust. The authors state that, because of limited land and water, several growers sow wheat after sugar beet, carrot or pea, around mid-January.
- elfetyany2026 (Fayoum, 2 years): wheat sowing date "determines the planting window for subsequent summer crops". Early wheat then cotton gave 10.7% less wheat but 212% higher net return than wheat then maize. The authors call it site-specific, and the design mixes sowing date with the following crop.
- kassem2019: 82% of Kafr El-Sheikh farmers name changing planting dates as an adaptation they know.

**Abstract-only signals (not evidence):** mohiy2021 (wheat after sugarcane lost 37.7%), ali2020 (models: wheat down 8.7% to 13.2% by the 2030s-2080s; shifting sowing helps), gamal2024 (night temperatures rising and hurting wheat), dadrasi2024 (global meta-analysis: late sowing down 24%), sorour2018 and abokhadra2019 (a short berseem "fahl" crop in the gap between rice or maize and wheat raised wheat yield and saved nitrogen).

**Fit to the brief.** It is a rotation-sequence problem: what goes in during summer decides when wheat can go in. The brief names "seasons when current crops appear more vulnerable", crops that "fall outside expected growing seasons", and "times when fields are typically bare".
**NASA data.** POWER daily Tmax and Tmin since 1990 cover heat-at-flowering and growing-degree-day measures; we already hold them. MODIS/VIIRS NDVI could show green-up and harvest timing, but 250 m is coarse for 1 ha plots.
**Scale.** Air temperature changes little across flat Delta land, so a 50 km POWER cell matters less here than for soil or water.
**Novelty risk.** Low. None of the other Field Shift repos found frames rotation as a calendar.
**Gaps.** No full-text farmer survey yet says how often wheat is sown late in the central Delta, or why. Most evidence is from field trials.

## 7. The forage squeeze (Egypt)
hautbout2025 (Behera, interviews 2023): the main fodder system is berseem in winter and fodder maize in summer; rising land rents and feed prices forced landless families to sell large animals; Nile water reduced and soil fertility declining; most farms under half a hectare. ayyad2024 projects berseem at 18% of harvested area by 2050. NASA data helps only partly (season length, water demand). My own inference, not stated in the texts read: less berseem would also mean less legume nitrogen in the rotation.

## 8. Pests and diseases rising with heat (Egypt)
kassem2019: 81.4% of 792 farmers report more pests and diseases. elbasyoni2018: heat raised rust. Weather data can describe risk conditions; satellites cannot see pests. Thin, and overlaps with 6.

## 9. Rice straw burning (Egypt)
Only kassem2019 in full text. A study from India (not Egypt) ties burning to the short gap before wheat; I found no Egyptian full text saying so. NASA FIRMS fire detections could show it. It is more an air-quality problem than a rotation choice.

## 10. Land loss and fragmentation (Egypt)
radwan2019: 74,600 ha of Delta farmland went to urban use in 1992-2015 (about 3,108 ha a year), with 87,000 ha more projected by 2030. hautbout2025: inheritance leaves most farms under half a hectare. Serious, but a land-policy problem rather than a rotation choice.

## How loop 3 changes the picture
- Candidate 6 is new, and among the Egypt problems it matches the brief's wording on growing seasons and rotation sequence best.
- Candidates 4 (water) and 6 (calendar) connect: the summer crop (rice, maize or cotton) sets both water use and when wheat can be sown.
- The list is not stable yet: loop 3 produced a new leading Egypt candidate. Another loop focused on 6 (farmer surveys of wheat sowing dates in the central Delta) would be needed to call it settled.

## Other Field Shift repos checked (novelty risk)
- ALBOU517/Field-Shift (team NASA-LARPERS, Quebec; checked 2026-11-14, last push 2026-11-10): web app where a farmer draws a field, then all 1-4 year rotations of five crops (maize, soy, spring and winter wheat, barley) are scored on yield, resilience, soil, water and income, with normal/dry/hot scenarios and horizons up to 30 years. Data, prices and climate trend are fictitious in v1.1; rotation effects come from US studies; NASA data not yet connected. No licence file. Overlaps strongly with candidate 2; no overlap with candidates 4-10.
- Also seen earlier (README headers only): huiliijiang/spaceapp26 (Saskatchewan rotation advisor), Zul-Qarnain/field-shift (Bangladesh), chhra/field-shift (generic).
