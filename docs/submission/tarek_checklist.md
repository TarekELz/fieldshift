# Tarek: manual steps before 23:59 (Egypt time)

Only you can do these. In this order.

1. **Commit and push the review changes** (this folder, `docs/ai-disclosure.md`, README, `docs/index.html`, `docs/demo.md`, `docs/references.md`) on a short branch and merge to `main`.
2. **Fix the Pages build.** Every Pages run today failed with "This project is not configured for the web". In `app/`: `flutter create . --platforms web`, check that only `app/web/` (and `.metadata` if changed) is new, run `flutter build web` once locally, commit `app/web/`, push.
3. **Make the repository public:** GitHub, Settings, General, Danger Zone, Change visibility. Before that, confirm no secrets: `git log -p | grep -i -E "api[_-]?key|AIza|hamsa.*key"` should find nothing; `app/assets/secrets/` must stay gitignored.
4. **LICENSE:** present (MIT). Nothing to add.
5. **Enable Pages:** Settings, Pages, Source "GitHub Actions". Re-run the Pages workflow (Actions, pages, Re-run all jobs). Open the published `/`, `/explorer/` and `/ai-disclosure.md` links.
6. **Release the keyless APK:** Releases, Draft a new release, tag `v17`, attach `dist/field_shift_public_v17_2026-11-15.apk` from your machine (it is not in git). Say in the notes that this build has no API keys and falls back to fixed text and the phone's voice. Install it once on a phone first.
7. **Upload the 30-second video** (YouTube unlisted or public, no login). Description must say: narration is AI-generated (Piper text-to-speech, voice en-US lessac), Eyad's voice is AI-generated (Hamsa), the avatar is AI-generated, and link `docs/ai-disclosure.md`. Check the "AI" mark on Eyad is visible in the video. No copyrighted music.
8. **Fill the form** from `docs/submission/fields.md`. Project link: the public repository (or the Pages URL).
9. **Test every link logged out** (private window): repository, Pages page, explorer, release APK, video. Fix any 404 before submitting.
10. **Submit before 23:59.** Do not wait for optional fixes.
