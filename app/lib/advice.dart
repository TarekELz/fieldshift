// Advice layer in the app (decisions D16, D18): the same logic as src/fieldshift/advice.py and season_engine.py, driven by assets/data/blueprints.json
// and assets/data/season.json. CODE selects the blueprint from the engines' facts; the language model (Gemini) may only rephrase the filled text, and
// its answer is shown only if the guard passes. Otherwise the filled blueprint text is shown: it needs no internet.
// Test: test/advice_test.dart reproduces the blueprint choices that Python makes (golden cases).
//
// Supports, and does not replace, the farmer's judgement and local agricultural advice.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'engine.dart';
import 'i18n.dart';

class AdviceData {
  AdviceData(this.blueprints, this.season);
  final Map<String, dynamic> blueprints, season;

  static AdviceData? _cache;

  static Future<AdviceData> load([AssetBundleLike? bundle]) async {
    if (_cache != null && bundle == null) return _cache!;
    Future<Map<String, dynamic>> read(String n) async =>
        jsonDecode(await (bundle?.loadString('assets/data/$n.json') ?? rootBundle.loadString('assets/data/$n.json'))) as Map<String, dynamic>;
    final d = AdviceData(await read('blueprints'), await read('season'));
    if (bundle == null) _cache = d;
    return d;
  }
}

class SeasonVerdict {
  SeasonVerdict(this.label, this.best);
  final String label; // right season | so-so | wrong season | cannot judge
  final String? best; // "MM-DD" of the best sowing date of the year
}

int _doy(int m, int d) => DateTime.utc(2001, m, d).difference(DateTime.utc(2001, 1, 1)).inDays;

/// Temperature-only season label (decision D17), the same rules as season_engine.verdict. The farmer's date is matched to the nearest half-month date.
SeasonVerdict seasonVerdict(AdviceData a, String site, String crop, String mmdd) {
  final sc = (a.season['sites'] as Map<String, dynamic>)[site]?[crop] as List?;
  if (sc == null) return SeasonVerdict('cannot judge', null);
  final scan = sc.map<List<num>>((e) => (e as List).cast<num>()).toList();
  final p = mmdd.split('-').map(int.parse).toList();
  final doy = _doy(p[0], p[1]);
  var nowI = 0, bestDist = 1 << 30;
  for (var i = 0; i < scan.length; i++) {
    final dd = (_doy(scan[i][0].toInt(), scan[i][1].toInt()) - doy).abs();
    final dist = dd > 182 ? 365 - dd : dd;
    if (dist < bestDist) {
      bestDist = dist;
      nowI = i;
    }
  }
  var best = scan[0];
  for (final r in scan) {
    if (r[2] > best[2] || (r[2] == best[2] && r[3] < best[3])) best = r;
  }
  final minIdeal = scan.map((r) => r[2]).reduce((x, y) => x < y ? x : y);
  final spread = best[2] - minIdeal;
  final bestDate = '${best[0].toInt().toString().padLeft(2, '0')}-${best[1].toInt().toString().padLeft(2, '0')}';
  if (spread < (a.season['min_spread'] as num)) return SeasonVerdict('cannot judge', null);
  final now = scan[nowI];
  final gap = best[2] - now[2];
  final String label;
  if (now[3] >= (a.season['bad_share_wrong'] as num) || gap > (a.season['so_so_within'] as num)) {
    label = 'wrong season';
  } else if (gap <= (a.season['right_within'] as num)) {
    label = 'right season';
  } else {
    label = 'so-so';
  }
  return SeasonVerdict(label, bestDate);
}

/// Flat facts from the comparison (first row = the farmer's own rotation), like advice.facts_from.
Map<String, dynamic> adviceFacts(AdviceData a, Comparison c) {
  final ex = c.rows.first, alts = c.rows.skip(1).where((r) => r.input.crop != ex.input.crop).toList();
  final sv = seasonVerdict(a, c.site, ex.input.crop, ex.input.summerSowing), wv = seasonVerdict(a, c.site, 'wheat', ex.input.wheatSowing);
  final f = <String, dynamic>{
    'sea': c.caveatKind == 'sea', 'summer_crop': ex.input.crop, 'summer_date': ex.input.summerSowing, 'wheat_date': ex.input.wheatSowing, 'gap': ex.gapDays,
    'heat_extra': ex.extra['32'], 'salt_known': ex.saltSummer != null, 'salt_summer': ex.saltSummer?.status, 'salt_wheat': ex.saltWheat?.status,
    'summer_label': sv.label, 'wheat_label': wv.label, 'summer_best': sv.best, 'wheat_best': wv.best,
    'alt_crop': null, 'alt_pct': null, 'alt_water_pct': null, 'alt_salt_ok': false,
  };
  if (alts.isNotEmpty) {
    final ok = alts.where((r) => r.saltSummer?.status == 'fine').toList();
    final pool = ok.isNotEmpty ? ok : alts;
    var pick = pool.first;
    for (final r in pool) {
      if (r.ratio < pick.ratio) pick = r;
    }
    f['alt_crop'] = pick.input.crop;
    f['alt_pct'] = f['alt_water_pct'] = roundHalfEven(100 * pick.ratio);
    f['alt_salt_ok'] = ok.isNotEmpty;
  }
  return f;
}

bool _truthy(Object? v) => v == null ? false : (v is bool ? v : (v is num ? v != 0 : (v is String ? v.isNotEmpty : true)));

bool _test(Map<String, dynamic> cond, Map<String, dynamic> facts) {
  final v = facts[cond['f']];
  if (cond.containsKey('in')) return (cond['in'] as List).contains(v);
  if (cond.containsKey('truthy')) return _truthy(v) == (cond['truthy'] as bool);
  if (v is! num) return false;
  if (cond.containsKey('lt') && !(v < (cond['lt'] as num))) return false;
  if (cond.containsKey('lte') && !(v <= (cond['lte'] as num))) return false;
  if (cond.containsKey('gt') && !(v > (cond['gt'] as num))) return false;
  if (cond.containsKey('gte') && !(v >= (cond['gte'] as num))) return false;
  return true;
}

class Picked {
  Picked(this.id, this.closeness, this.blueprint);
  final String id;
  final int? closeness; // share of the blueprint's conditions that hold, percent
  final Map<String, dynamic> blueprint;
}

/// Blueprints that apply, highest priority first. The first is the main advice; a second one must be on a different topic.
List<Picked> selectAdvice(AdviceData a, Map<String, dynamic> facts, {int howMany = 2}) {
  final all = <Picked>[];
  final prio = <String, int>{};
  for (final b in (a.blueprints['blueprints'] as List).cast<Map<String, dynamic>>()) {
    final must = (b['must'] as List).cast<Map<String, dynamic>>(), bonus = (b['bonus'] as List).cast<Map<String, dynamic>>();
    if (!must.every((c) => _test(c, facts))) continue;
    final total = must.length + bonus.length;
    final met = must.length + bonus.where((c) => _test(c, facts)).length;
    final id = b['id'] as String;
    prio[id] = b['priority'] as int;
    all.add(Picked(id, total == 0 ? null : roundHalfEven(100 * met / total), b));
  }
  all.sort((x, y) => prio[y.id]!.compareTo(prio[x.id]!));
  final fams = (a.blueprints['families'] as Map<String, dynamic>);
  final keep = <Picked>[];
  final used = <String>{};
  for (final r in all) {
    final fam = ((fams[r.id] as List?)?.cast<String>() ?? [r.id]).toSet();
    if (keep.isNotEmpty && (r.id == 'generic' || r.id == 'on_track' || fam.intersection(used).isNotEmpty)) continue;
    keep.add(r);
    used.addAll(fam);
    if (keep.length >= howMany) break;
  }
  return keep;
}

/// The blueprint text with the engines' numbers put in, in the current language.
String fillAdvice(Map<String, dynamic> blueprint, Map<String, dynamic> f) {
  final slots = <String, String>{
    'crop': cropN(f['summer_crop'] as String),
    'summer_date': dateN(f['summer_date'] as String),
    'wheat_date': dateN(f['wheat_date'] as String),
    'gap': nd(f['gap']),
    'heat_extra': nd(f['heat_extra'] ?? 0),
    'alt_crop': f['alt_crop'] == null ? '' : cropN(f['alt_crop'] as String),
    'alt_pct': f['alt_pct'] == null ? '' : nd(f['alt_pct']),
    'summer_best': f['summer_best'] == null ? '' : dateN(f['summer_best'] as String),
    'wheat_best': f['wheat_best'] == null ? '' : dateN(f['wheat_best'] as String),
  };
  var text = blueprint[isAr ? 'ar' : 'en'] as String;
  slots.forEach((k, v) => text = text.replaceAll('{$k}', v));
  if (!isAr) {
    // a slot such as a crop name can start a sentence
    text = text.replaceAllMapped(RegExp(r'(^|[.!?] )([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
  }
  return text;
}

String _normDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    sb.write(i >= 0 ? '$i' : ch);
  }
  return sb.toString();
}

List<String> _numbers(String s) => RegExp(r'\d+(?:\.\d+)?').allMatches(_normDigits(s)).map((m) => m.group(0)!).toList();

/// null when the model's text may be shown, otherwise the reason it is refused (same rules as advice.guard).
String? guardAdvice(AdviceData a, String tailored, String filled, Map<String, dynamic> blueprint) {
  final t = tailored.trim();
  if (t.isEmpty) return 'empty';
  if (t.contains('\n\n') || t.length > 1.7 * filled.length + 40) return 'too long';
  final have = _numbers(t).toSet(), want = _numbers(filled).toSet();
  if (have.difference(want).isNotEmpty) return 'new number';
  if (want.difference(have).isNotEmpty) return 'missing number';
  final lang = isAr ? 'ar' : 'en';
  for (final w in (a.blueprints['forbidden_$lang'] as List).cast<String>()) {
    if (t.toLowerCase().contains(w)) return 'forbidden word';
  }
  if (isAr) {
    for (final stem in (blueprint['keep'] as List).cast<String>()) {
      if (!t.contains(stem)) return 'missing key word';
    }
  }
  return null;
}

class AdviceResult {
  AdviceResult({required this.id, required this.closeness, required this.text, required this.ai, required this.also});
  final String id;
  final int? closeness;
  final String text; // shown text: the model's rewrite only when ai is true
  final bool ai;
  final List<String> also;
}

const _model = 'gemini-3.1-flash-lite';
const _system = {
  'ar': 'You rewrite a short advice text for an Egyptian farmer who may not read well. Write in simple Egyptian colloquial Arabic, short sentences. '
      'STRICT: keep every number and every fact exactly as given; add NO new fact, number, crop, date, price, yield or promise; keep the same meaning and the same advice. '
      'At most 60 words. Output only the rewritten text, no quotes, no markdown.',
  'en': 'You rewrite a short advice text for a farmer in simple, friendly English. STRICT: keep every number and fact exactly as given; add NO new fact, number, crop, date, '
      'price, yield or promise; keep the same advice. At most 60 words. Output only the rewritten text.',
};

/// Optional API keys, bundled from assets/secrets/secrets.json when the build was made with keys (never committed). Empty list = no model.
Future<List<String>> geminiKeys() async {
  try {
    final j = jsonDecode(await rootBundle.loadString('assets/secrets/secrets.json')) as Map<String, dynamic>;
    return (j['gemini'] as List).cast<String>().where((k) => k.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

typedef ModelCaller = Future<String> Function(String key, String text, String lang, Duration timeout);

Future<String> _callGemini(String key, String text, String lang, Duration timeout) async {
  final r = await http
      .post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
          headers: {'x-goog-api-key': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {'parts': [{'text': _system[lang]}]},
            'contents': [{'role': 'user', 'parts': [{'text': text}]}],
            'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 400},
          }))
      .timeout(timeout);
  if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
  final parts = (jsonDecode(r.body)['candidates'][0]['content']['parts'] as List);
  return parts.map((p) => (p['text'] ?? '') as String).join().trim();
}

/// Advice for the comparison. Never throws. The text is the filled blueprint unless a model rewrite passes the guard within the time budget.
Future<AdviceResult> adviceFor(AdviceData a, Comparison c, {Duration budget = const Duration(seconds: 6), List<String>? keys, ModelCaller? caller}) async {
  final facts = adviceFacts(a, c);
  final sel = selectAdvice(a, facts);
  final main = sel.first;
  final filled = fillAdvice(main.blueprint, facts);
  final also = [for (final s in sel.skip(1)) fillAdvice(s.blueprint, facts)];
  var text = filled, ai = false;
  final ks = keys ?? await geminiKeys();
  final call = caller ?? _callGemini;
  final sw = Stopwatch()..start();
  for (final k in ks) {
    final left = budget - sw.elapsed;
    if (left.inMilliseconds < 500) break;
    try {
      final out = await call(k, filled, isAr ? 'ar' : 'en', left);
      if (guardAdvice(a, out, filled, main.blueprint) == null) {
        text = out.trim();
        ai = true;
      }
      break;
    } catch (_) {
      continue; // quota, network or a slow answer: try the next key
    }
  }
  return AdviceResult(id: main.id, closeness: main.closeness, text: text, ai: ai, also: also);
}
