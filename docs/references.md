# References (for the submission form's References field)

The NASA Space Apps rules require every external resource used in the project (code, text, images, data, even open-source or freely available) to be listed here. DRAFT for Tarek to check before pasting into the form; sources marked (to confirm) need a final look at the exact licence or citation.

## NASA data
- NASA POWER (Prediction Of Worldwide Energy Resources), daily agroclimatology, 1990 to 2025: https://power.larc.nasa.gov/
- NASA MODIS MOD13Q1 v061 vegetation indices (Terra, 250 m, 16-day), 2014 to 2025: https://doi.org/10.5067/MODIS/MOD13Q1.061
- NASA MODIS MCD12Q2 v061 land cover dynamics (phenology), 2015 to 2025: https://doi.org/10.5067/MODIS/MCD12Q2.061
- NASA MODIS MOD16A3GF v061 yearly evapotranspiration (input check): https://doi.org/10.5067/MODIS/MOD16A3GF.061
- NASA SRTMGL1 v003 terrain, 1 arc-second (terrain check of the data points): https://doi.org/10.5067/MEASURES/SRTM/SRTMGL1.003
- NASA GPM IMERG daily precipitation (context): https://gpm.nasa.gov/data/imerg
- Microsoft Planetary Computer open data service, used to read MOD16A3GF and ESA WorldCover: https://planetarycomputer.microsoft.com/

## Other data and tables (not NASA)
- FAOSTAT (FAO), Egypt crop yields and producer prices: https://www.fao.org/faostat/ (bulk files, downloaded 2026-11-15)
- FAO Irrigation and Drainage Paper 56, crop evapotranspiration (stage lengths and crop coefficients): https://www.fao.org/4/x0490e/x0490e00.htm
- FAO Irrigation and Drainage Paper 29 Rev.1, Ayers and Westcot 1985, Water quality for agriculture (salt tolerance, Table 4): https://www.fao.org/4/t0234e/t0234e00.htm
- FAO EcoCrop database (crop temperature ranges and cycle lengths), copy from the OpenCLIM/ecocrop repository: https://github.com/OpenCLIM/ecocrop (licence to confirm)
- ESA WorldCover 2021 v200 (10 m land cover, CC BY 4.0): https://esa-worldcover.org/
- Governorate boundaries of Egypt, CAPMAS via the Humanitarian Data Exchange (CC BY-IGO): https://data.humdata.org/
- Natural Earth (rivers, lakes, outlines; public domain): https://www.naturalearthdata.com/

## Literature (full text read)
- Ghazouani, W., Molle, F., Swelam, A., Rap, E. (2014). Understanding farmers' adaptation to water scarcity: a case study from the western Nile Delta. https://doi.org/10.5337/2015.200
- Kassem, H.S., Bello, A.R.S., Alotaibi, B.M., et al. (2019). Climate Change Adaptation in the Delta Nile Region of Egypt: Implications for Agricultural Extension. Sustainability 11(3), 685. https://doi.org/10.3390/su11030685
- Elbasyoni, I.S. (2018). Performance and Stability of Commercial Wheat Cultivars under Terminal Heat Stress. Agronomy 8(4), 37. https://doi.org/10.3390/agronomy8040037
- ElFetyany, M., Mostafa, E.F., Hatem, S.E.A. (2026). Enhanced water productivity and economic returns through cropping system management. Water Science. https://doi.org/10.1007/s44533-026-00061-5
- Medhi, I., Patnaik, S., Brunskill, E., et al. (2009). Designing mobile interfaces for novice and low-literacy users (CHI 2009), used for the design of the voice-first interface (to confirm exact citation).
- The full table of 58 papers read or checked, with what was read in full, is in `literature/papers.csv`.

## Software and fonts
- Flutter and Dart (BSD-3-Clause): https://flutter.dev/ ; packages speech_to_text, flutter_tts, audioplayers, http, shared_preferences (see app/pubspec.yaml for versions and licences)
- Python with numpy, rasterio, pyhdf, requests, PyYAML, Pillow, pytest (see requirements.txt)
- IBM Plex Sans and IBM Plex Sans Arabic fonts (SIL Open Font License 1.1): https://github.com/IBM/plex
- Design inspiration: the team's own Advanced Monitor app (design system), not copied from third parties.

## AI tools used (details in docs/ai-disclosure.md, to be updated)
- Claude (Anthropic) as a coding and research assistant.
- Gemini (Google) API: rewording advice text behind a number-and-fact guard, classifying a short phrase that is not among the options, adding diacritics to spoken text.
- Hamsa text-to-speech (voice "Ibrahim", Egyptian Arabic): AI-generated voice for Eyad.
- The avatar "Eyad": AI-generated images supplied by the team, shown with a visible "AI" mark.
- The phone's own speech recognition and text-to-speech (Android / Google), used as supplied by the device.
