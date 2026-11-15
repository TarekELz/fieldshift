// Field Shift voice and language proxy (Cloudflare Worker, no dependencies).
//
// Why it exists: the app and the website must not carry API keys. They call this proxy; the proxy holds the Hamsa (voice) and Gemini (language) keys as
// secrets, tries them in turn when one is out of funds or rate limited, and only accepts the few requests the project needs.
//
//   POST /tts     {"text": "..."}              -> audio/wav, Eyad's voice (Hamsa realtime, fixed voice, Egyptian dialect)
//   POST /gemini  {contents, systemInstruction?, generationConfig?} -> Gemini JSON (fixed model, small outputs)
//   GET  /health                               -> which services have keys and which are resting (no secrets)
//
// Secrets (wrangler secret put ...): HAMSA_KEYS and GEMINI_KEYS, each a comma separated list.
// Optional variables: ALLOWED_ORIGINS (comma list, for the website), APP_TOKEN (a shared header value; NOT a secret once it is inside an APK, it only keeps casual
// scrapers away), RATE_PER_MIN (default 30 per address), DAILY_TTS_CAP and DAILY_GEMINI_CAP (default 3000, needs the optional KV binding STATS), DISABLED=1 (kill switch).

export const VOICE_ID = '8f329168-6604-4f13-9572-994984f894c4'; // Ibrahim, the Egyptian voice Eyad uses
export const GEMINI_MODEL = 'gemini-3.1-flash-lite';
const HAMSA_URL = 'https://api.tryhamsa.com/v1/realtime/tts';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const MAX_TEXT = 300;
const MAX_GEMINI_BODY = 8000;
const MAX_TOKENS = 400;
const ALLOWED_GEMINI_FIELDS = new Set(['contents', 'systemInstruction', 'generationConfig']);

// keys that recently failed: "service:index" -> time (ms) until they are tried again. Lives as long as the worker instance.
const resting = new Map();
const hits = new Map(); // address -> request times (ms), best effort per worker instance
let rotate = 0;

export function __reset() {
  resting.clear();
  hits.clear();
  rotate = 0;
}

const pool = (s) => String(s || '').split(/[,\n]/).map((x) => x.trim()).filter(Boolean);
const json = (obj, status = 200, extra = {}) => new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json', ...extra } });

function corsHeaders(request, env) {
  const origin = request.headers.get('origin');
  const allowed = pool(env.ALLOWED_ORIGINS);
  if (!origin || !allowed.includes(origin)) return {};
  return { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'content-type, x-fs-app', 'access-control-allow-methods': 'GET, POST, OPTIONS', vary: 'origin' };
}

/** Tries each key in turn. A refused or empty key rests for an hour, a rate limited one for a minute. Returns the first good Response, or null. */
export async function withKeys(service, keys, makeRequest, now = Date.now()) {
  if (!keys.length) return null;
  const order = keys.map((_, i) => i);
  const start = rotate++ % order.length;
  const ready = order.filter((i) => (resting.get(`${service}:${i}`) || 0) <= now);
  const list = ready.length ? ready.slice(start % ready.length).concat(ready.slice(0, start % ready.length)) : order; // all resting: try them all anyway
  for (const i of list) {
    let res;
    try {
      res = await makeRequest(keys[i]);
    } catch (e) {
      resting.set(`${service}:${i}`, now + 10_000);
      continue;
    }
    if (res.ok) return res;
    if (res.status === 401 || res.status === 402 || res.status === 403) resting.set(`${service}:${i}`, now + 3_600_000);
    else if (res.status === 429) resting.set(`${service}:${i}`, now + 60_000);
    else resting.set(`${service}:${i}`, now + 10_000);
  }
  return null;
}

function tooMany(ip, limit, now = Date.now()) {
  const list = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  list.push(now);
  hits.set(ip, list);
  if (hits.size > 5000) for (const k of hits.keys()) { if (!hits.get(k).some((t) => now - t < 60_000)) hits.delete(k); }
  return list.length > limit;
}

async function dailyCap(env, name, cap) {
  if (!env.STATS) return false; // no KV binding: only the per address limit applies
  const key = `${new Date().toISOString().slice(0, 10)}:${name}`;
  try {
    const n = parseInt((await env.STATS.get(key)) || '0', 10) + 1;
    if (n > cap) return true; // over the cap: no further write (KV writes are limited per day)
    await env.STATS.put(key, String(n), { expirationTtl: 172800 });
    return false;
  } catch {
    return false; // KV unavailable or out of daily writes: do not turn every request into an error; the per address limit still applies
  }
}

async function sha256(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function handleTts(request, env, cors) {
  const raw = await request.text();
  if (raw.length > 4 * MAX_TEXT) return json({ error: 'bad_request' }, 400, cors);
  let body;
  try { body = JSON.parse(raw); } catch { return json({ error: 'bad_request' }, 400, cors); }
  const text = body && typeof body.text === 'string' ? body.text.trim() : '';
  if (!text || text.length > MAX_TEXT) return json({ error: 'bad_request' }, 400, cors);
  const cache = globalThis.caches && globalThis.caches.default;
  const cacheKey = cache ? new Request(`https://cache.fieldshift.local/tts/${await sha256(text)}`) : null;
  if (cache) {
    const hit = await cache.match(cacheKey);
    if (hit) return new Response(hit.body, { status: 200, headers: { 'content-type': 'audio/wav', 'x-fs-cache': 'hit', ...cors } });
  }
  if (await dailyCap(env, 'tts', parseInt(env.DAILY_TTS_CAP || '3000', 10))) return json({ error: 'limit' }, 429, cors);
  const res = await withKeys('hamsa', pool(env.HAMSA_KEYS), (key) => fetch(HAMSA_URL, {
    method: 'POST',
    headers: { authorization: `Token ${key}`, 'content-type': 'application/json' },
    body: JSON.stringify({ text, speaker: VOICE_ID, dialect: 'egy' }),
  }));
  if (!res) return json({ error: 'unavailable' }, 503, cors);
  const audio = await res.arrayBuffer();
  if (audio.byteLength < 44 || new TextDecoder().decode(audio.slice(0, 4)) !== 'RIFF') return json({ error: 'unavailable' }, 503, cors);
  const out = new Response(audio, { status: 200, headers: { 'content-type': 'audio/wav', 'cache-control': 'public, max-age=2592000', ...cors } });
  if (cache) { try { await cache.put(cacheKey, out.clone()); } catch { /* caching is an optimisation only */ } }
  return out;
}

async function handleGemini(request, env, cors) {
  const raw = await request.text();
  if (raw.length > MAX_GEMINI_BODY) return json({ error: 'bad_request' }, 400, cors);
  let body;
  try { body = JSON.parse(raw); } catch { return json({ error: 'bad_request' }, 400, cors); }
  if (!body || typeof body !== 'object' || !Array.isArray(body.contents) || body.contents.length === 0) return json({ error: 'bad_request' }, 400, cors);
  const clean = {};
  for (const k of Object.keys(body)) if (ALLOWED_GEMINI_FIELDS.has(k)) clean[k] = body[k]; // no tools, no safety overrides, nothing else
  const gc = clean.generationConfig && typeof clean.generationConfig === 'object' ? clean.generationConfig : {};
  const t = Number(gc.temperature ?? 0.3), m = Math.floor(Number(gc.maxOutputTokens ?? MAX_TOKENS));
  clean.generationConfig = { temperature: Number.isFinite(t) ? Math.min(Math.max(t, 0), 1) : 0.3, maxOutputTokens: Number.isFinite(m) && m >= 1 ? Math.min(m, MAX_TOKENS) : MAX_TOKENS };
  if (await dailyCap(env, 'gemini', parseInt(env.DAILY_GEMINI_CAP || '3000', 10))) return json({ error: 'limit' }, 429, cors);
  const res = await withKeys('gemini', pool(env.GEMINI_KEYS), (key) => fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'x-goog-api-key': key, 'content-type': 'application/json' },
    body: JSON.stringify(clean),
  }));
  if (!res) return json({ error: 'unavailable' }, 503, cors);
  return new Response(await res.text(), { status: 200, headers: { 'content-type': 'application/json', ...cors } });
}

export default {
  async fetch(request, env = {}) {
    const url = new URL(request.url);
    const cors = corsHeaders(request, env);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (String(env.DISABLED || '') === '1') return json({ error: 'off' }, 503, cors);
    if (url.pathname === '/health' && request.method === 'GET') {
      const now = Date.now();
      const rest = (svc, n) => [...Array(n).keys()].filter((i) => (resting.get(`${svc}:${i}`) || 0) > now);
      const h = pool(env.HAMSA_KEYS), g = pool(env.GEMINI_KEYS);
      return json({ ok: true, hamsa: { keys: h.length, resting: rest('hamsa', h.length) }, gemini: { keys: g.length, resting: rest('gemini', g.length) } }, 200, cors);
    }
    if (request.method !== 'POST' || (url.pathname !== '/tts' && url.pathname !== '/gemini')) return json({ error: 'not_found' }, 404, cors);
    if (env.APP_TOKEN && request.headers.get('x-fs-app') !== env.APP_TOKEN) return json({ error: 'forbidden' }, 403, cors);
    const ip = request.headers.get('cf-connecting-ip') || request.headers.get('x-forwarded-for') || 'unknown';
    if (tooMany(ip, parseInt(env.RATE_PER_MIN || '30', 10))) return json({ error: 'rate' }, 429, { 'retry-after': '60', ...cors });
    return url.pathname === '/tts' ? handleTts(request, env, cors) : handleGemini(request, env, cors);
  },
};
