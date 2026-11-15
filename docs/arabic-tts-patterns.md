# How Arabic text-to-speech is used accurately: patterns from repos, vendor docs and papers

Question (Tarek, 2026-11-15): find repos, documents and other resources that show how Arabic voice tools such as Hamsa are used accurately, find the patterns, and make Eyad's voice accurate.

**Short answer.** The sources agree on one idea: the text you send decides most of the accuracy, so treat the text before the voice as a tested stage of its own. When we measured our own clips that way, we found and fixed a real bug in our text stage (27 clips damaged, mean round-trip similarity 0.886 to 0.990).

## What was read (and what was not)
| Source | Kind | What it gave us |
|---|---|---|
| [Hamsa TTS docs](https://docs.tryhamsa.com/text-to-speech/introduction.md), [quickstart](https://docs.tryhamsa.com/text-to-speech/quickstart.md), [voices](https://docs.tryhamsa.com/text-to-speech/voices.md), [media TTS](https://docs.tryhamsa.com/media/text-to-speech/overview.md), [voice dictionary API](https://docs.tryhamsa.com/api-reference/endpoint/create-voice-dictionary.md) | Vendor docs (read in full) | Two endpoints (async jobs, realtime), a `dialect` code (`egy` = Egyptian), `expressiveness` 0 to 2, speed, pronunciation dictionaries, tashkeel supported, mixed Arabic and English supported |
| [Navid-Gen-AI/arabic-tts-arena](https://github.com/Navid-Gen-AI/arabic-tts-arena) `models/hamsa_tts.py` | Repo | A real client for Hamsa's realtime endpoint inside a blind-comparison benchmark of Arabic TTS systems; it sends `dialect: "msa"` |
| [Oddadmix/arz-frontend](https://github.com/Oddadmix/arz-frontend) | Repo | An Egyptian Arabic TTS front end: normalize, then phonemize, then validate. No diacritizer for Egyptian, because the Egyptian voice predicts vowels itself (97.2% token accuracy on undiacritized text); every output symbol is checked against a known list or the run fails |
| [MMS-1017/Egyptian-Arabic-TTS-Fine-Tuning-Pipeline](https://github.com/MMS-1017/Egyptian-Arabic-TTS-Fine-Tuning-Pipeline) | Repo | A normalizer exposed as its own step that returns which rules it applied, run before every synthesis |
| [Sestek Arabic voices best practices](https://docs.sestek.com/docs/arabic-voices-best-practices) | Vendor guide (another TTS vendor) | Concrete text rules: numbers as words, dates and times in supported forms, expand abbreviations, one dialect per sentence, short sentences, Arabic script for brands, diacritics only where ambiguous |
| [Habibi, arXiv 2601.13802](https://arxiv.org/abs/2601.13802) and [arXiv 2603.01622](https://arxiv.org/abs/2603.01622) | Papers (abstracts) | Multi-dialect Arabic TTS works without diacritics; diacritized training data helps, but more data offsets the lack to a large degree |
| [Pipecat Hakim integration](https://docs.pipecat.ai/api-reference/server/services/tts/hakim) | Integration docs | One synthesis request per sentence on a persistent connection |

Not read: a LiveKit Arabic voice-agent article (blocked with HTTP 403), and the full text of the two papers (abstracts only). Marketing pages (tts.ai, Lemonfox) turned up in searches and were not relied on. No repo was found that documents Hamsa-specific text preprocessing; the Hamsa patterns below come from the vendor docs and the one benchmark client.

## The patterns, and where we stand
| # | Pattern | Seen in | Ours |
|---|---|---|---|
| 1 | **Say the dialect and keep the text in that dialect.** Hamsa has a `dialect` code; the benchmark used `msa` for MSA text; write "دلوقتي", not "الآن", and do not mix | Hamsa docs, arena, Sestek | Text is Egyptian; voice is the Egyptian voice "Ibrahim". The live path now also sends `dialect: "egy"` |
| 2 | **Make text preparation a separate, tested stage that fails loudly.** Log which rules ran; reject symbols the voice cannot take; never pass garbage on silently | arz-frontend, MMS pipeline | We had the stage (`scripts/add_tashkeel.py`) but **no test on its output**. This is how a bug sat unseen. Now tested (`tests/test_spoken_tashkeel.py`) |
| 3 | **Numbers, dates, symbols and Latin letters become spoken Arabic words.** | Sestek, arz-frontend | **Not done yet.** 20 of 67 spoken lines contain digits ("١٥ نوفمبر") or Latin letters ("EC"). The round trip misread them (see below) |
| 4 | **Diacritics sparingly and dialect-aware.** Only for ambiguous words; an Egyptian voice may do better without MSA-style marks; no case endings | Sestek, arz-frontend, papers | We vowel every line and strip case endings. In our own A/B (10 lines, round-trip scored) plain and voweled text scored the same (0.97 to 0.99), so we keep it; it was only harmful when corrupted |
| 5 | **Short sentences, one request each.** | Sestek, Pipecat, Hamsa media guide | Sentence-wise playback; one short line per result page (v12); live lines capped at 300 characters |
| 6 | **Realtime endpoint for interactive use, async jobs for batch.** | Hamsa docs, arena | Pre-recorded clips came from jobs (right). The live voice polled the jobs endpoint; it now calls the realtime endpoint first (about 1.1 s in our test) and falls back to jobs |
| 7 | **Pronunciation dictionaries for names and terms.** | Hamsa docs | A dashboard feature of Hamsa (not a field of the jobs or realtime TTS request). Not used; we spell the line so it reads right instead |
| 8 | **Expressiveness and speed controls.** | Hamsa docs | Defaults. Untested for slower, calmer delivery to low-literacy listeners; worth one listening test |
| 9 | **Measure, do not guess: synthesize, transcribe back, compare, then have a person listen to the worst ones.** | the arena repo is a benchmark with a leaderboard (only its Hamsa client was read); the round-trip idea itself is standard in TTS evaluation | **New:** `scripts/check_clips_roundtrip.py`, results in `docs/checks/tts_roundtrip.csv` |

## What the round-trip check found
The check sends each recorded clip to Gemini's audio input and compares the transcript with the intended line (character similarity, 0 to 1). It is a screen, not proof: the transcriber can be wrong and it says nothing about accent or naturalness.

1. **A real bug in our text stage.** `scripts/add_tashkeel.py` removed marks from the last letter of each word with a replacement that held a literal control character (U+0001) instead of the backreference `\1`. The last letter of many words was lost before the text reached the voice: 38 of 113 voweled lines, 27 of the 86 recorded clips. The transcripts showed stray syllables where the letters were missing. Fixed; the map was repaired from the plain text; the 27 clips were regenerated.

   | | Before | After |
   |---|---|---|
   | The 27 damaged clips, mean similarity | 0.886 | **0.990** |
   | All 86 clips, mean similarity | 0.951 | **0.981** |
   | The 59 untouched clips (same audio, shows the screen's noise) | 0.981 | 0.977 |

2. **Digits and Latin letters are read badly.** "تمام، ١ يناير." came back as "تمام واحد يا ماير"; "(EC)" came back as "20". These are the weakest clips left, and they match pattern 3.
3. **Hamsa's documentation is partly out of date.** The realtime quickstart shows `Authorization: Bearer`; the service answers that this header is deprecated, and only `Token <key>` works. The realtime endpoint accepts our voice's id in the `speaker` field.
4. **A/B on 10 clean lines** (plain or voweled text, with or without `dialect: "egy"`): all four variants scored 0.97 to 0.99. With a sample this small the screen cannot tell them apart, so we changed nothing on those two points.

## Recommended next steps (not done)
1. **Spell numbers and "EC" as words in the spoken text** (pattern 3). This changes the spoken form of about 20 lines and means regenerating those clips. It needs Tarek's approval of the Egyptian number spelling (for example how "١٥ نوفمبر" is said), because it is Arabic wording.
2. **A listening test** by two Egyptian speakers on the 10 lowest clips in `docs/checks/tts_roundtrip.csv` and on the A/B pairs, for accent and naturalness, which no script here can judge.
3. **Try `expressiveness` 0.5 to 0.8** for a calmer delivery and listen.
4. Keep the round-trip check as a gate whenever clips are regenerated.
