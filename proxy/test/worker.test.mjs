// Tests for the proxy with Hamsa and Gemini replaced by scripted fakes. Run:  node --test proxy/test
import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import worker, { __reset, GEMINI_MODEL, VOICE_ID } from '../worker.js';

const WAV = new Uint8Array([0x52, 0x49, 0x46, 0x46, ...new Array(60).fill(1)]); // "RIFF" + bytes
let calls;
let script; // service -> list of statuses used in order (the last repeats)

function fake(url, init) {
  const service = String(url).includes('tryhamsa') ? 'hamsa' : 'gemini';
  const key = service === 'hamsa' ? init.headers.authorization.replace('Token ', '') : init.headers['x-goog-api-key'];
  calls.push({ service, key, body: JSON.parse(init.body) });
  const rules = script[service] || {};
  const status = rules[key] ?? 200;
  if (status === 'throw') throw new Error('network');
  if (status !== 200) return Promise.resolve(new Response(JSON.stringify({ message: 'no' }), { status }));
  return Promise.resolve(service === 'hamsa' ? new Response(WAV, { status: 200 }) : new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }), { status: 200 }));
}

beforeEach(() => {
  __reset();
  calls = [];
  script = {};
  globalThis.fetch = fake;
});

const env = (extra = {}) => ({ HAMSA_KEYS: 'h1,h2,h3', GEMINI_KEYS: 'g1,g2', ...extra });
const post = (path, body, headers = {}) => new Request(`https://p.example${path}`, { method: 'POST', headers: { 'content-type': 'application/json', 'cf-connecting-ip': '1.1.1.1', ...headers }, body: typeof body === 'string' ? body : JSON.stringify(body) });

test('tts: returns audio and sends only the fixed voice, dialect and trimmed text', async () => {
  const r = await worker.fetch(post('/tts', { text: '  تمام.  ', speaker: 'evil', dialect: 'x' }), env());
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('content-type'), 'audio/wav');
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].body, { text: 'تمام.', speaker: VOICE_ID, dialect: 'egy' });
});

test('tts: a key out of funds is skipped and then rested', async () => {
  script.hamsa = { h1: 402, h2: 402 };
  const r = await worker.fetch(post('/tts', { text: 'a' }), env({ HAMSA_KEYS: 'h1,h2,h3' }));
  assert.equal(r.status, 200);
  assert.equal(calls.at(-1).key, 'h3');
  calls = [];
  const r2 = await worker.fetch(post('/tts', { text: 'b' }), env());
  assert.equal(r2.status, 200);
  assert.deepEqual(calls.map((c) => c.key), ['h3']); // h1 and h2 are resting: no wasted requests
});

test('tts: rate limited and failing keys fall through; all failing gives 503', async () => {
  script.hamsa = { h1: 429, h2: 'throw', h3: 500 };
  const r = await worker.fetch(post('/tts', { text: 'a' }), env());
  assert.equal(r.status, 503);
  assert.deepEqual(await r.json(), { error: 'unavailable' });
});

test('tts: when every key is resting they are still tried (a key may have been topped up)', async () => {
  script.hamsa = { h1: 402, h2: 402, h3: 402 };
  await worker.fetch(post('/tts', { text: 'a' }), env());
  script.hamsa = {};
  const r = await worker.fetch(post('/tts', { text: 'b' }), env());
  assert.equal(r.status, 200);
});

test('tts: bad input is refused before any key is used', async () => {
  for (const body of [{}, { text: '' }, { text: 5 }, { text: 'x'.repeat(301) }, 'not json']) {
    const r = await worker.fetch(post('/tts', body), env());
    assert.equal(r.status, 400);
  }
  assert.equal(calls.length, 0);
});

test('kill switch, unknown paths and methods', async () => {
  assert.equal((await worker.fetch(post('/tts', { text: 'a' }), env({ DISABLED: '1' }))).status, 503);
  assert.equal((await worker.fetch(post('/nope', {}), env())).status, 404);
  assert.equal((await worker.fetch(new Request('https://p.example/tts'), env())).status, 404);
  assert.equal(calls.length, 0);
});

test('per address rate limit', async () => {
  const e = env({ RATE_PER_MIN: '3' });
  const codes = [];
  for (let i = 0; i < 5; i++) codes.push((await worker.fetch(post('/tts', { text: `t${i}` }), e)).status);
  assert.deepEqual(codes, [200, 200, 200, 429, 429]);
  const other = await worker.fetch(post('/tts', { text: 'z' }, { 'cf-connecting-ip': '2.2.2.2' }), e);
  assert.equal(other.status, 200);
});

test('daily cap with a KV binding', async () => {
  const store = new Map();
  const STATS = { get: async (k) => store.get(k), put: async (k, v) => store.set(k, v) };
  const e = env({ STATS, DAILY_TTS_CAP: '2', RATE_PER_MIN: '100' });
  const codes = [];
  for (let i = 0; i < 4; i++) codes.push((await worker.fetch(post('/tts', { text: `t${i}` }), e)).status);
  assert.deepEqual(codes, [200, 200, 429, 429]);
});

test('app token is required when configured', async () => {
  const e = env({ APP_TOKEN: 'abc' });
  assert.equal((await worker.fetch(post('/tts', { text: 'a' }), e)).status, 403);
  assert.equal((await worker.fetch(post('/tts', { text: 'a' }, { 'x-fs-app': 'abc' }), e)).status, 200);
});

test('cors: only listed origins are answered', async () => {
  const e = env({ ALLOWED_ORIGINS: 'https://site.example' });
  const ok = await worker.fetch(post('/tts', { text: 'a' }, { origin: 'https://site.example' }), e);
  assert.equal(ok.headers.get('access-control-allow-origin'), 'https://site.example');
  const no = await worker.fetch(post('/tts', { text: 'b' }, { origin: 'https://evil.example' }), e);
  assert.equal(no.headers.get('access-control-allow-origin'), null);
  const pre = await worker.fetch(new Request('https://p.example/tts', { method: 'OPTIONS', headers: { origin: 'https://site.example' } }), e);
  assert.equal(pre.status, 204);
});

test('gemini: fixed model, no extra fields, output clamped, keys rotate', async () => {
  script.gemini = { g1: 402 };
  const body = { contents: [{ role: 'user', parts: [{ text: 'hi' }] }], systemInstruction: { parts: [{ text: 's' }] }, tools: [{ codeExecution: {} }], safetySettings: [], generationConfig: { temperature: 5, maxOutputTokens: 100000 } };
  const r = await worker.fetch(post('/gemini', body), env());
  assert.equal(r.status, 200);
  assert.equal(calls.at(-1).key, 'g2');
  const sent = calls.at(-1).body;
  assert.equal(sent.tools, undefined);
  assert.equal(sent.safetySettings, undefined);
  assert.deepEqual(sent.generationConfig, { temperature: 1, maxOutputTokens: 400 });
  assert.ok(String(GEMINI_MODEL).length > 0);
});

test('gemini: bad or oversized bodies are refused', async () => {
  for (const body of ['nope', {}, { contents: [] }, { contents: [{ parts: [{ text: 'x'.repeat(9000) }] }] }]) {
    assert.equal((await worker.fetch(post('/gemini', body), env())).status, 400);
  }
  assert.equal(calls.length, 0);
});

test('health reports counts and resting keys but never a key', async () => {
  script.hamsa = { h1: 402 };
  await worker.fetch(post('/tts', { text: 'a' }), env({ HAMSA_KEYS: 'h1,h2' }));
  const r = await worker.fetch(new Request('https://p.example/health'), env({ HAMSA_KEYS: 'h1,h2' }));
  const text = await r.text();
  assert.deepEqual(JSON.parse(text).hamsa, { keys: 2, resting: [0] });
  for (const k of ['h1', 'h2', 'g1', 'g2']) assert.ok(!text.includes(`"${k}"`));
});

test('daily cap: no KV write once over the cap, and a failing KV does not break requests', async () => {
  const store = new Map();
  let writes = 0;
  const STATS = { get: async (k) => store.get(k), put: async (k, v) => { writes++; store.set(k, v); } };
  const e = env({ STATS, DAILY_TTS_CAP: '1', RATE_PER_MIN: '100' });
  for (let i = 0; i < 4; i++) await worker.fetch(post('/tts', { text: `w${i}` }), e);
  assert.equal(writes, 1);
  const broken = { get: async () => { throw new Error('kv'); }, put: async () => { throw new Error('kv write limit'); } };
  assert.equal((await worker.fetch(post('/tts', { text: 'k' }), env({ STATS: broken }))).status, 200);
});

test('tts: an oversized body is refused before parsing or any key is used', async () => {
  assert.equal((await worker.fetch(post('/tts', JSON.stringify({ text: 'a', pad: 'x'.repeat(5000) })), env())).status, 400);
  assert.equal(calls.length, 0);
});

test('gemini: temperature 0 is kept and negative values are clamped', async () => {
  const contents = [{ role: 'user', parts: [{ text: 'hi' }] }];
  await worker.fetch(post('/gemini', { contents, generationConfig: { temperature: 0, maxOutputTokens: -5 } }), env());
  assert.deepEqual(calls.at(-1).body.generationConfig, { temperature: 0, maxOutputTokens: 400 });
  await worker.fetch(post('/gemini', { contents, generationConfig: { temperature: -2, maxOutputTokens: 50 } }), env());
  assert.deepEqual(calls.at(-1).body.generationConfig, { temperature: 0, maxOutputTokens: 50 });
});
