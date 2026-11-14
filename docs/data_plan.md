# Data plan (Step 4 Part B, draft for gate G2)

Written 2026-11-14 evening. Follows decisions D1-D3: Egypt, three grounded engines (wheat calendar, water, salt) behind a voice assistant. Region and accounts are still Tarek's call at G2.

## First finding: our Egypt pilot point is in a city
The Egypt point 30.79N, 31.00E is in or next to Tanta city. SoilGrids returns no values there or within about 1 km. It does return values about 2.5 km away (30.81N 31.02E: clay 36%, pH 7.3; 30.77N 30.98E: clay 32%, pH 7.8). This suggests the point is masked as urban. **The Egypt point needs moving onto farmland before we pull more data.** One candidate set already exists: the three Damietta farm points a teammate pulled from AppEEARS (31.25-31.35N, 31.65-31.75E). These are in the northern Delta, where the salinity literature is concentrated (hagage2024, kotb2000 abstract).

## Scale: what each dataset can and cannot say about a farm
Typical Delta holding: about 1 ha or less (hautbout2025: most farms under 0.5 ha). One hectare is a square about 100 m across.

| Dataset | Resolution | What it can say at farm level | What it cannot |
|---|---|---|---|
| NASA POWER (temp, rain, sun, humidity, wind) | ~0.5 x 0.625 deg (~50 km) | Weather for the district; air temperature varies little across flat Delta land | Anything field-specific |
| MODIS MOD13Q1 NDVI | 250 m (6 ha pixel) | Crop calendar of the area: when fields green up and when they are bare | One farmer's own plot (a pixel mixes several plots) |
| HLS (Landsat + Sentinel-2) NDVI | 30 m | Close to plot level | Needs Earthdata token; cloud gaps |
| SMAP L4 soil moisture | 9 km | Regional wetness trend | Irrigated plots (irrigation is not resolved) |
| IMERG rainfall | ~10 km | Rain, which is near zero in most of the Delta | Little use for irrigated crops |
| ECOSTRESS ET / LST | 70 m | Field-scale water use and heat, on the days it passes | Regular time series (about 5x fewer scenes over Egypt than Mead) |
| FAO WaPOR v3 actual ET | 300 m (L1), 100 m (L2) | Area water use by 10-day period | Plot level; Level 3 Delta coverage not confirmed |
| HWSD v2.0 soil (incl. salinity attributes) | 1 km | Soil unit and its typical salinity class | A field's actual salinity |
| FAO Global Map of Salt-Affected Soils | ~1 km (national submissions) | Whether an area is salt-affected | A field's actual salinity |
| SoilGrids | 250 m | Texture, pH, carbon near (not in) the city point | Salinity (not a SoilGrids property) |

## Per engine: needed, have, missing

### Engine 1: wheat calendar (heat at grain filling for a given sowing date)
| Need | Have? | Source / status |
|---|---|---|
| Daily Tmax/Tmin 1990-2025 | YES (city point; move point) | NASA POWER, on disk; re-pull at the new point takes minutes, no account |
| When the summer crop is usually harvested and wheat sown in this area | YES, 3 Damietta points | MODIS NDVI 2000-2026 from teammate's AppEEARS extract (98% good-quality values). Median NDVI shows winter peak Dec-Feb, dip in May, summer peak Jul-Aug, dip Sep-Oct |
| Recommended sowing windows, crop durations | Partly | WUR yield gap atlas (Delta: wheat sown first half of November, harvested mid-April to early May; rice sown May to mid-June); FAO GIEWS; Egyptian Ministry of Agriculture bulletins not yet found |
| Heat limits at flowering/grain fill | Literature | elbasyoni2018 (full text); others abstract only. FieldShift0 uses 32 C for wheat grain filling (not a source we can cite) |
| Future warming | Optional | NASA NEX-GDDP-CMIP6 (open on AWS, no account) |

### Engine 2: water (summer crop water need vs what the canal delivers)
| Need | Have? | Source / status |
|---|---|---|
| Reference evapotranspiration (ET0) | YES (computable) | FAO-56 Penman-Monteith from POWER temp, humidity, wind, solar |
| Crop coefficients for rice, maize, cotton, wheat, berseem | Literature | FAO-56 tables (published) |
| Measured water use to check the estimate | NO | ECOSTRESS (token), MODIS MOD16 (via AppEEARS, token), WaPOR v3 (open; my API test returned no items, needs a second look) |
| Canal supply to the farmer (days on / days off) | NO satellite can see it | Farmer input in the conversation; ghazouani2014 describes rotation turns |

### Engine 3: salt (which crops tolerate the farmer's salt level; the rice trade-off)
| Need | Have? | Source / status |
|---|---|---|
| Area salinity class | NO | HWSD v2.0 (1 km, CC BY-NC-SA, raster + attribute database), FAO salt-affected soils map (download location not yet confirmed) |
| Crop salt tolerance thresholds | Literature | FAO irrigation and drainage paper tables (Maas-Hoffman thresholds); to be cited from the source |
| The farmer's own field | NO | Farmer input: soil test EC if they have one, or signs (white crust, patchy growth) |
| Satellite salinity | NOT from NASA in the brief | Landsat/Sentinel-2 salinity indices exist in the literature (hagage2024, amer2021) but need local ground truth to mean anything |

## What is blocked and by whom
| Item | Blocked by | Who |
|---|---|---|
| Moving the Egypt point and re-pulling POWER | Choice of point(s) | Tarek (G2) |
| ECOSTRESS, MODIS MOD16, HLS, SMAP, SRTM | Earthdata token in `.env` | Tarek, or Youssef (already has an AppEEARS account) |
| MODIS NDVI at our own Egypt point | ORNL API returned 503; AppEEARS works | Teammate with AppEEARS |
| Local data server 192.168.4.110:8000 | Host answers ping, but ports 8000, 8080, 80, 8888, 5000, 3000 are closed from this machine | Whoever runs it: start it bound to 0.0.0.0, or share the files |
| Speech-to-text, LLM, text-to-speech | Provider choice and API keys | Tarek |

## Recommendation for G2
- **Region:** Egypt as the headline. Drop Mead from the demo; keep its data only as a test case if time allows.
- **Points:** use the three Damietta farm points (north Delta, saline, data already pulled), plus one central-Delta farm point near Tanta, moved off the city. Cost: about 1 hour to re-pull POWER and check the points on a map.
