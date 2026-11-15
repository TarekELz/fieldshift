# Output format (Step 4 Part A, gate G1b)

Decided by Tarek on 2026-11-14 (D2, D3 in `decisions.md`): **a voice assistant in Egyptian Arabic on top of three calculation engines, with a picture card.** This note records the alternatives that were on the table and what each gives up.

| Format | What the farmer gets | What the literature says users want | Build hours | Demo strength | Works offline | Main risk |
|---|---|---|---|---|---|---|
| **Voice assistant + picture card (chosen)** | Asks aloud, hears a short answer, sees a simple card | 31.7% of surveyed Delta farmers are illiterate; information comes from sons and TV; meetings and visits preferred over print (kassem2019). 23.1% unfamiliar with digital tools (swelam2026) | 10-14 | High: clear in 10 seconds | Card yes; live voice no (recorded fallback) | Egyptian-dialect speech recognition; live demo failure |
| Web dashboard or map | Charts and maps to explore | Tools are little used when they are hard to use or not relevant to the user (rose2016); farmers who do use data layer several years of it (nowatzke2024, US) | 8-10 | Medium | Yes | Needs literacy and a device; the other Field Shift teams built this |
| Extension-agent card (print or phone) | A one-page comparison an agent or son reads out | Extension is the preferred channel (kassem2019) but reaches few (3.6%, swelam2026) | 4-6 | Low to medium | Yes | Depends on an agent being present |
| Model + notebook only | Nothing farmer-facing | - | 3-4 | Low | Yes | Fails the "farmer-friendly" part of the brief |

**What we give up by choosing voice:** exploration (a farmer cannot browse 35 years of data by voice) and offline use of the live assistant. The picture card and the recorded fallback cover part of that.
**Unknown:** how many Delta farmers or their families have a smartphone. No paper read gives it, so the pitch must not claim it.
