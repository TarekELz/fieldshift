# Roles and tasks

Roles confirmed by Tarek on 2026-11-14 (areas only). The detailed task list with hours is added after the method is chosen (gate G3). Until tasks become GitHub issues, they live here.

## Roles
| Member | Area | Backup for |
|---|---|---|
| **Tarek** | Lead and story: all gates; the farmer conversation in Egyptian Arabic (what the assistant asks and says); the 30-second demo or 7 slides; the submission page | - |
| **Hussain** | Data lead and **water engine**: owns `data/`, the catalog and the downloads; crop water demand from NASA POWER against the farmer's canal schedule | Calendar engine |
| **Al-Ashmawy** | **Wheat calendar engine** and tests: heat risk at grain filling for a given sowing date, from POWER temperature and the MODIS crop calendar. Built first | - |
| **Youssef** | **Voice assistant and app**: speech to text, the language model calling the engines, text to speech, the web page and picture card | - |
| **Eyad** | **Salt engine** and integration: crop salt-tolerance lookup with FAO soil maps; joining the three engines behind one interface; offline demo cache | Voice assistant |

## Priorities
- The calendar engine and a comparison card are the minimum product.
- Cut order if time runs short: salt engine first (Eyad moves to integration and voice), then live voice (fall back to a recording), then detail in the water engine.

## Open before tasks can be written
- G2: confirm the Delta points; Earthdata token in `.env` (each person adds their own, never in chat or git).
- G3: method for each engine (see `docs/methodology.md`, not yet written).
- Speech and language-model providers, and who holds the keys.

## Tasks
To be filled after G3.
