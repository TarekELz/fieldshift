# Field Shift proxy: the keys stay on a server, never in the app

The Android app and the explorer website call this small Cloudflare Worker for Eyad's voice (Hamsa) and for the language model (Gemini). The Worker holds the keys as secrets, tries them in turn when one is out of funds or rate limited, and only accepts the requests the project needs. The APK and the repository then carry no keys at all.

| Call | What it does |
|---|---|
| `POST /tts` with `{"text": "..."}` | Returns Eyad's voice as a WAV (fixed voice, Egyptian dialect, at most 300 characters). Repeated lines are cached |
| `POST /gemini` with the usual `contents` body | Fixed model, no tools, output capped at 400 tokens, body capped at 8 KB |
| `GET /health` | How many keys each service has and which are resting. Never a key |

**Fallback.** A key answering "out of funds" (402) or refused (401, 403) rests for an hour; one rate limited (429) rests for a minute; any other failure rests for 10 seconds. If every key is resting they are tried anyway (one may have been topped up). If all fail, the Worker answers 503 and the app uses the phone's voice and fixed text.

**Protection against misuse.** The Worker address is public, so it limits what a stranger could spend: one fixed voice and model, a text length cap, 30 requests a minute per address, an optional daily total cap (needs the KV binding), an optional shared header value, an allowed list of website origins, and a kill switch. The shared header value is not a secret once it is inside an APK. For stronger limits add a Cloudflare rate limiting rule (step 8).

**Deployed:** `https://fieldshift-proxy.fieldshift-proxy.workers.dev` (Cloudflare account of the team lead; `/health` shows key counts). Two notes from the real deployment: the Cache API does nothing on `workers.dev` addresses (only on a custom domain), so repeated lines are not cached; and Cloudflare rate limiting rules need a custom domain, so on `workers.dev` the limits in `worker.js` and the daily caps are the protection.

## Deploy (about 15 minutes, once)
You need a free Cloudflare account (cloudflare.com) and Node.js. Everything below runs from this `proxy/` folder.

1. **Sign in.** `npx wrangler login` opens a browser; approve it.
2. **Add the keys as secrets** (comma separated, no spaces needed; never paste them into chat or a file in git):
   ```
   npx wrangler secret put HAMSA_KEYS
   npx wrangler secret put GEMINI_KEYS
   ```
3. **Optional daily caps.** `npx wrangler kv namespace create STATS`, then paste the printed `id` into `wrangler.toml` (the commented block).
4. **Deploy.** `npx wrangler deploy`. It prints the address, like `https://fieldshift-proxy.<your-name>.workers.dev`.
5. **Check it.** Open `https://<address>/health`. It should show your key counts. Then:
   ```
   curl -X POST https://<address>/tts -H "content-type: application/json" -d "{\"text\":\"تمام.\"}" --output test.wav
   ```
   and play `test.wav`.
6. **Build the apps against it.** No `secrets.json` is needed:
   ```
   flutter build apk --release --dart-define=PROXY_URL=https://<address>
   ```
   Team test builds may also add `--dart-define=VOICE_DIAG=true` for the grey diagnostics line.
7. **Website (later).** Set `ALLOWED_ORIGINS` in `wrangler.toml` to the Pages origin and redeploy.
8. **Extra limit with no code.** Cloudflare dashboard, Security, WAF, Rate limiting rules: for example 60 requests per minute per IP on the paths `/tts` and `/gemini`.

## Everyday use
- **Rotate or replace a key:** run `npx wrangler secret put HAMSA_KEYS` again with the new list. No rebuild, no new APK.
- **Top up a key:** nothing to do; a resting key is retried after an hour, or at once if all are resting.
- **Kill switch:** uncomment `DISABLED = "1"` in `wrangler.toml` and `npx wrangler deploy`, or turn the Worker off in the dashboard. The apps fall back to fixed text and the phone voice.
- **Watch it:** `/health`, and the Worker's Logs page in the dashboard.
- **Cost:** the free Workers plan allows 100,000 requests a day, far more than the project needs. The real cost is Hamsa and Gemini credit, which the caps limit.

## Develop and test
`npm test` (or `node --test test/worker.test.mjs`) runs the tests with Hamsa and Gemini replaced by fakes. For a local run: copy `.dev.vars.example` to `.dev.vars` (git ignored), fill in the keys, then `npx wrangler dev`.
