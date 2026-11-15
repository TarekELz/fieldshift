// The Dart advice layer must choose the same blueprints as the Python one (golden cases from scripts/export_app_data.py) and its guard must refuse unfaithful model text.
import 'dart:convert';
import 'dart:io';

import 'package:field_shift/advice.dart';
import 'package:field_shift/engine.dart';
import 'package:field_shift/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

String _md(List s) => '${(s[0] as int).toString().padLeft(2, '0')}-${(s[1] as int).toString().padLeft(2, '0')}';

void main() {
  late EngineData data;
  late AdviceData adv;
  setUpAll(() async {
    data = await EngineData.load(_FileBundle());
    adv = await AdviceData.load(_FileBundle());
  });

  Comparison cmp(Map c) => compare(data, c['site'], [for (final s in c['sequences']) SequenceInput(name: 'x', crop: s['summer_crop'], summerSowing: _md(s['summer_sowing']), wheatSowing: _md(s['wheat_sowing']))],
      signs: c['signs'], intervalDays: c['interval_days']);

  test('Dart picks the same blueprints as Python (golden cases)', () {
    final cases = jsonDecode(File('test/fixtures/rotation_cases.json').readAsStringSync()) as List;
    for (final c in cases) {
      final sel = selectAdvice(adv, adviceFacts(adv, cmp(c)));
      final e = c['advice'];
      final tag = '${c['site']} ${c['signs']}';
      expect(sel.first.id, e['primary'], reason: tag);
      expect(sel.first.closeness, e['closeness'], reason: tag);
      expect([for (final s in sel.skip(1)) s.id], e['also'], reason: tag);
    }
  });

  test('a salt problem is never advised as fine', () {
    final cases = jsonDecode(File('test/fixtures/rotation_cases.json').readAsStringSync()) as List;
    for (final c in cases.where((c) => c['signs'] != null)) {
      final f = adviceFacts(adv, cmp(c));
      if (f['salt_summer'] == 'not advised') expect(selectAdvice(adv, f).first.id, isNot('on_track'));
    }
  });

  test('season labels follow the temperature screen', () {
    expect(seasonVerdict(adv, 'gharbia', 'rice', '11-01').label, 'wrong season');
    expect(seasonVerdict(adv, 'gharbia', 'rice', '05-15').label, 'right season');
    expect(seasonVerdict(adv, 'gharbia', 'wheat', '11-15').label, 'right season');
    expect(seasonVerdict(adv, 'gharbia', 'wheat', '03-01').label, 'wrong season');
    expect(seasonVerdict(adv, 'gharbia', 'tomato', '02-01').label, 'cannot judge');
  });

  test('the guard accepts a faithful rewrite and refuses changes', () {
    lang.value = 'ar';
    final c = cmp((jsonDecode(File('test/fixtures/rotation_cases.json').readAsStringSync()) as List).firstWhere((c) => c['site'] == 'gharbia' && c['signs'] == null));
    final f = adviceFacts(adv, c);
    final main = selectAdvice(adv, f).first;
    final filled = fillAdvice(main.blueprint, f);
    expect(filled.contains('{'), isFalse);
    expect(guardAdvice(adv, filled, filled, main.blueprint), isNull);
    expect(guardAdvice(adv, '', filled, main.blueprint), 'empty');
    expect(guardAdvice(adv, '$filled ٩٩', filled, main.blueprint), 'new number');
    expect(guardAdvice(adv, '$filled وهتكسب إنتاج أكتر', filled, main.blueprint), 'forbidden word');
  });

  test('adviceFor uses a faithful model rewrite, and falls back on a bad one, an error, or no key', () async {
    lang.value = 'ar';
    final c = cmp((jsonDecode(File('test/fixtures/rotation_cases.json').readAsStringSync()) as List).firstWhere((c) => c['site'] == 'gharbia' && c['signs'] == 'patches'));
    final filled = (await adviceFor(adv, c, keys: const [])).text;
    expect((await adviceFor(adv, c, keys: const [])).ai, isFalse);
    final ok = await adviceFor(adv, c, keys: ['a'], caller: (k, t, l, d) async => '$filled ');
    expect(ok.ai, isTrue);
    final bad = await adviceFor(adv, c, keys: ['a'], caller: (k, t, l, d) async => 'الرز تمام ومفيش مشكلة');
    expect(bad.ai, isFalse);
    expect(bad.text, filled);
    var calls = 0;
    final second = await adviceFor(adv, c, keys: ['a', 'b'], caller: (k, t, l, d) async {
      calls++;
      if (k == 'a') throw Exception('quota');
      return filled;
    });
    expect(calls, 2);
    expect(second.ai, isTrue);
  });
}
