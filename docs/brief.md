# Challenge brief: Field Shift: Adapting Farms with NASA Data

Source: https://www.spaceappschallenge.org/2026/challenges/adapting-farms-with-nasa-data/ (Details tab and Resources tab).
Read in a browser on 2026-11-14, about 13:00 local. Event: 2026 NASA Space Apps Challenge.
Difficulty: Advanced, Intermediate. Subjects: Arts & Multimedia, Earth Science, Software.
The site writes "SI" (Super Intelligence) where it means AI; the text below keeps the site's wording.

## Verbatim brief (Details tab)

> Farmers around the world navigate shifting temperatures, changing rainfall patterns, water shortages, extreme weather, and declining soil health. These pressures make it difficult to choose crop rotations that protect fields, conserve water, and support long‑term resilience. Your challenge is to create a decision‑support tool that uses NASA Earth observations along with local soil information, crop characteristics, and farmer priorities to help farmers explore rotation strategies that could strengthen soil health and adapt their farms to changing conditions.
>
> **BACKGROUND**
>
> Farmers face increasingly complex decisions as temperatures shift, rainfall becomes less predictable, and soil health declines across many regions. Water shortages, erosion, nutrient depletion, and extreme weather events add further uncertainty. Selecting new crops to add to a rotation can be difficult, because a crop that improves soil health in one place may consume too much water, introduce disease, conflict with local markets, or fall outside expected growing seasons somewhere else.
>
> This challenge is inspired in part by multigenerational farming experience — many families have lived through seasons where better tools for tracking changing conditions could have helped identify healthier, more resilient rotation choices. Today, NASA’s long‑term environmental datasets offer new ways to understand local growing conditions, and SI techniques open opportunities to translate that data into practical, farmer‑friendly insights.
>
> **OBJECTIVES**
>
> You may consider combining NASA Earth observations with local agricultural information to create an app, model, interactive map, or other decision‑support tool. The goal is to help farmers explore crop‑rotation options that may improve soil health and strengthen resilience to changing weather and water conditions.
>
> You may explore NASA datasets such as SMAP, ECOSTRESS, GPM, Landsat, MODIS, NASA POWER, GRACE and GRACE‑FO, and SRTM or other NASA elevation products. Using these datasets, you may analyze patterns in temperature, heat stress, rainfall, soil moisture, evaporation, frost risk, extreme precipitation, vegetation stress, and long‑term water trends. You may also consider local soil information, crop characteristics, and farmer priorities—such as water use, forage value, nitrogen‑fixing potential, erosion reduction, organic matter improvement, or market suitability.
>
> Your tool may highlight times when fields are typically bare, seasons when current crops appear more vulnerable, or opportunities for rotations that could interrupt pest cycles, reduce water demand, improve infiltration, or add supplemental income. You may compare at least three rotation strategies, including the existing rotation. For each strategy, you may explain why it was suggested, what evidence supports it, what benefits it may offer, where information gaps exist, and any risks that would need local review by farmers or agricultural experts.
>
> The intended outcome is a supportive tool — one that helps identify patterns and possibilities, but does not replace farmer judgment or local agricultural expertise.
>
> **POTENTIAL CONSIDERATIONS**
>
> You may (but are not required to) consider the following:
>
> *Understanding Conditions & Data*
>
> - Explore how changes in temperature, soil moisture, rainfall, evaporation, and vegetation stress relate to crop vulnerability and soil health.
> - Consider explaining scientific terms such as evapotranspiration, soil moisture anomalies, vegetation indices (e.g., NDVI), frost risk, and water‑balance indicators.
> - Clarify how satellite observations differ from ground‑based measurements, and how combining both may improve accuracy.
>
> *SI, Modeling, and Data Fusion*
>
> - You may compare different SI or statistical approaches for identifying patterns in historical climate and soil conditions.
> - Consider how SI could highlight seasonal transitions, bare‑field periods, or times when current crops show increased stress.
> - Explain how the model interprets uncertainty and where local expertise would be needed to validate results.
> - You may consider harmonizing datasets with different spatial and temporal resolutions by downsampling, aggregating, or resampling them to a common analysis grid. Harmonizing resolution can help the SI combine SMAP soil moisture, ECOSTRESS land‑surface temperature, GPM precipitation, Landsat/MODIS vegetation indices, GEDI biomass, and soil datasets into coherent features that support clear, explainable rotation‑strategy comparisons.
>
> *Rotation Strategy Exploration*
>
> - Compare rotation scenarios by examining nutrient cycling, erosion risk, organic matter contributions, pest‑cycle disruption, water use, forage potential, or market considerations.
> - You may consider mapping which rotation ideas best align with farmer priorities—such as conserving water, generating supplemental income, or improving soil structure.
> - Include brief explanations of how nitrogen‑fixing crops, cover crops, deep‑rooting crops, or drought‑tolerant crops contribute to long‑term soil health.
>
> *Geospatial Mapping & Visualization*
>
> - Consider whether interactive maps could help users explore trends over time such as long‑term soil moisture, heat waves, or water‑storage declines.
> - Explore ways to visualize field‑level vulnerabilities (e.g., zones of erosion risk, water stress hotspots, frost‑prone areas).
> - You may include optional add‑ons such as timelines, overlays comparing datasets, or scenario sliders that adjust rainfall or temperature patterns.
>
> *Farmer‑Centered Design*
>
> - Consider how to make the tool easily interpretable for farmers who may have limited technical or geospatial experience.
> - Think about ways to allow farmers to input their own priorities or constraints, such as water availability, equipment limitations, or market preferences.
> - Share reminders that the tool is intended to support—not replace—local expertise, and highlight where human judgment is particularly important.
>
> For data and resources related to this challenge, refer to the Resources tab at the top of the page. More resources may be added before the hackathon begins.

## Resources tab (names as listed; descriptions not copied here)

Notice on the tab: NASA does not endorse non-U.S. Government entities; for non-government sites, participants must comply with that site's data-use terms.

**NASA Data & Resources:** SMAP; GPM & IMERG; Landsat; MODIS/VIIRS; NASA POWER; SRTM; ECOSTRESS; USDA Ag Data Commons; Web Soil Survey; Cropland Data Layer (CropScape); PRISM; USDA NRCS SSURGO/STATSGO2; NAIP; USGS NLCD; NLDAS/GLDAS; FAO GAEZ; CoCoRaHS; USGS NWIS; USDA AMS Market News; USDA NASS QuickStats; OpenET (described as western U.S. states); USFS LANDFIRE; GEDI (described as most effective with taller vegetation).

**Space Agency Partner Resources (ESA):** Copernicus Sentinel-2; ERA5 (ECMWF reanalysis).

GRACE/GRACE-FO are named in the brief text but have no entry on the Resources tab.

## What the brief requires
Almost everything in the brief is phrased "you may". The firm parts are:
1. The stated challenge: "create a decision‑support tool that uses NASA Earth observations along with local soil information, crop characteristics, and farmer priorities to help farmers explore rotation strategies that could strengthen soil health and adapt their farms to changing conditions."
2. The intended outcome: a supportive tool that "does not replace farmer judgment or local agricultural expertise."
3. From the judging rules (see submission-rules.md): at least one NASA dataset or resource must be used, and Relevance is scored on how fully the project addresses the challenge and how central NASA data is.

**Consequence for Step 3:** the challenge sentence is about crop-rotation decisions. A problem with no link to rotation or crop choice would score low on Relevance. The brief does allow many angles on the rotation decision (water, soil health, heat, frost, erosion, pests, markets, bare-field periods).

## What the brief leaves to us
- Which farmer, region, crops and farm scale.
- Which pressure matters most (water, heat, salinity, soil decline, markets, pests, and so on).
- Output form: "an app, model, interactive map, or other decision‑support tool".
- Which NASA datasets, and whether to add non-NASA data.
- Method: "SI or statistical approaches"; no method is required.
- Comparing "at least three rotation strategies, including the existing rotation" is suggested, not required.
- How uncertainty, evidence, gaps and risks are shown (suggested, not required).
- No region is required. Most listed context datasets are US-only; the brief opens with "Farmers around the world".
