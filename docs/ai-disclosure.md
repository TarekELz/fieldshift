# Use of AI tools in Field Shift

NASA Space Apps 2026 allows AI ("SI") tools if their use is stated where it happens: images and video carry a visible watermark, audio is acknowledged in descriptive text and metadata, and code and data acknowledge AI generation in descriptive text (see [submission-rules.md](submission-rules.md)). This file is that statement for the whole repository. It lists every AI tool the repository shows, where it is used, what it does, and what people wrote or decided.

## What is not AI
- **The idea and the decisions.** The problem (Nile Delta rotation under water, salt and heat pressure), the solution (a voice assistant that explains engine results) and every scope, data and method decision were taken by the team and are logged in [decisions.md](decisions.md).
- **Every number.** Heat, water, salt, season and income figures come from deterministic engines (`src/fieldshift/`, ported to `app/lib/engine.dart` and `docs/explorer/js/engine.js`) running on NASA POWER weather and FAO/FAOSTAT tables. No language model calculates, estimates or chooses a number.
- **The advice.** Code chooses one of the team's advice blueprints (`models/blueprints.json`) from the engine facts (`src/fieldshift/advice.py`, `app/lib/advice.dart`). The blueprint text is the fallback that is shown whenever the AI rewording is missing or rejected.
- **Data and evidence.** Datasets are listed in `data/catalog.yaml`; problem figures come from papers whose full text was read (`literature/papers.csv`).

## Tools, where they are used and what for

| Tool | Where | What for | Human role |
|---|---|---|---|
| **Claude (Anthropic), through Claude Code** | Whole repository: Python engines and scripts, the Flutter app, tests, the proxy, the project page `docs/index.html`, documentation | Coding and research assistant: wrote and edited code and documents under the team's instructions, searched and summarised literature, ran checks and code reviews (the "independent AI reviews" in the README) | The team set the problem, the method and every decision, reviewed and tested the output, and approved what was merged |
| **Claude and an AI assistant** | Explorer website `docs/explorer/` | Built the static pages, the English and draft Arabic interface text, and the inline field-scene illustration and crop pictures (SVG, `docs/explorer/img/`) | Uses the same exported tables and engine rules as the app; checked by `tests/test_explorer_data.py` |
| **Claude (drafts of Arabic text)** | App and explorer Arabic interface text; alternative wordings B and C in `docs/text_vote/` | First drafts of Egyptian Arabic wording | Team members and friends reviewed and voted on wording (`docs/text_review/`, `docs/text_vote/`); a full native-speaker review is still pending |
| **Gemini API (Google), model `gemini-3.1-flash-lite`** | At run time in the app (`app/lib/advice.dart`, `app/lib/interpret.dart`) through the proxy (`proxy/worker.js`) | (1) Rewords the code-chosen advice in plain Egyptian Arabic; a guard rejects any rewrite that changes or adds a number, drops a key fact or adds yield or money words, and the blueprint text is used instead. (2) Classifies a short phrase from the farmer that matches none of the listed options (it sees only that phrase) | Blueprints, the guard and the fallback are written by the team |
| **Gemini API** | `scripts/add_tashkeel.py` (offline) | Adds diacritics (tashkeel) to Eyad's spoken lines so the voice pronounces them in Egyptian Arabic; a guard requires the text without diacritics to equal the input exactly | Hand edits in `scripts/spoken_tashkeel_manual.json` override Gemini's output |
| **Gemini API** | `scripts/check_clips_roundtrip.py` (offline) | Transcribes each recorded clip so it can be compared with the intended text; a screen to decide which clips a person listens to first, not proof of quality | A person listens to flagged clips |
| **Hamsa text-to-speech, voice "Ibrahim" (Egyptian Arabic)** | Recorded clips in `app/assets/audio/` (made by `scripts/hamsa_tts.py`), and live speech through the proxy for lines with no clip (`app/lib/voice.dart`, `proxy/worker.js`) | Eyad's voice. AI-generated audio | The team chose the voice and wrote every spoken line |
| **Google Gemini image generation** | Eyad avatar pictures `app/assets/eyad/eyad_*.jpg`, copies in `docs/site/assets/` and `docs/explorer/img/` | The cartoon character Eyad, from a prompt by the team. See `app/assets/eyad/ABOUT.txt` (the person whose likeness it is is a team member, over 18, and consents) | Team prompt and selection |
| **The phone's own speech recognition and text-to-speech** (packages `speech_to_text`, `flutter_tts`; Android/Google services) | App, when the farmer speaks, and as the fallback voice when there is no internet; the explorer's Listen button uses the browser's own text-to-speech | Speech to text and text to speech, as supplied by the device | None; used as supplied |
| **Piper text-to-speech** (offline neural TTS, voice `en-US lessac`) and **Claude** | The 30-second demo video (not stored in this repository) | Piper made the English narration; Claude drew the cartoon scenes (as code) and assembled and timed the video; Eyad's lines in it are the recorded Hamsa clips | The team wrote the script and approved the cut |

Not AI: the explorer's "Ask Eyad" answers only from the tables, with rule-based matching and no AI model. The README graphics (`assets/readme/*.svg`) and the MODIS pictures are drawn by code (`scripts/build_readme_assets.py`, `scripts/make_delta_images.py`) from our data.

## Visible marks
- **Eyad's avatar** carries a visible "AI" mark wherever it is shown: in the app (`app/lib/eyad.dart`), on the project page and in the explorer. Keep it visible in screenshots, slides and the video.
- **The explorer field scene** is captioned "Illustration: drawn by AI", and the crop pictures under it "Illustrations: drawn by AI".
- **Eyad's voice** is AI-generated. This is stated in the app's Terms screen (`app/lib/terms.dart`), here, and in `app/lib/voice.dart`. The demo video narration is AI-generated (Piper) and is stated in the video description.
- **Advice rewording**: the app's Terms state that an AI model (Gemini) may reword the advice and that the numbers come from calculations, not from the AI.
- No AI-generated content uses or modifies NASA logos, flags or mission identifiers.
