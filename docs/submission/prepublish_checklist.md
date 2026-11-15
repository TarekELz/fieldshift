# Pre-publish checklist (run once, tick each)

## Rules
- [ ] One official 2026 challenge named: Field Shift: Adapting Farms with NASA Data.
- [ ] Demo is a 30-second video or at most 7 slides, in English (or Arabic speech with English subtitles); slides show team name, member names, challenge.
- [ ] No image, video, audio or likeness of anyone under 18 (avatar: team member, 22, consents; `app/assets/eyad/ABOUT.txt`).
- [ ] No NASA logos, flags or mission identifiers in AI-generated content.
- [ ] `docs/ai-disclosure.md` present and linked from README and `docs/references.md`.
- [ ] Every AI image shown carries a visible AI mark (avatar: yes; explorer field scene: captioned; explorer crop pictures: check, see findings).
- [ ] Audio from AI is acknowledged in text and in the video description.

## Repository
- [ ] No keys in history or in `app/assets/secrets/`; `.env` gitignored.
- [ ] README links work on GitHub (project page, status, decisions, methodology, references, AI use).
- [ ] README test counts match a fresh run (`python -m pytest tests`, `flutter test`) or are corrected.
- [ ] README and `docs/index.html` agree: 6 NASA datasets used, 5 engines, same test counts.
- [ ] CI green on `main`; Pages workflow green.

## Links (logged out)
- [ ] Repository public.
- [ ] Pages project page and `/explorer/` load; no request to another host from the explorer.
- [ ] Release APK downloads and installs.
- [ ] Video plays without login.
