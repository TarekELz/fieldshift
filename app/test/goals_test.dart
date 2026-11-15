// The goal page (decision D20): earn more, grow a certain crop at a certain time, improve what I grow now. Numbers must match the Python economics engine.
import 'dart:convert';
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:field_shift/goals.dart';
import 'package:field_shift/i18n.dart';
import 'package:field_shift/interpret.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

void main() {
  late EngineData data;
  setUpAll(() async {
    data = await EngineData.load(_FileBundle());
    lang.value = 'ar';
  });

  test('the crop book parses crops, longest alias first', () {
    final b = CropBook(data);
    expect(b.parse(normalizeAr('عايز ازرع بصل'))?.key, 'onion');
    expect(b.parse(normalizeAr('ذرة رفيعة'))?.key, 'sorghum');
    expect(b.parse(normalizeAr('ذرة شامي'))?.key, 'maize');
    expect(b.parse(normalizeAr('بنجر السكر'))?.key, 'sugar_beet');
    expect(b.parse(normalizeAr('عنب'))?.key, 'grape');
    expect(b.parse(normalizeAr('xyz')), isNull);
    expect(b.all.length, 14);
  });

  test('income ranking matches the Python economics engine (golden cases)', () {
    final cases = jsonDecode(File('test/fixtures/economics_cases.json').readAsStringSync()) as List;
    final b = CropBook(data);
    for (final c in cases) {
      final ece = (c['ece'] as num?)?.toDouble();
      for (final g in ['winter', 'summer', 'any', 'orchard']) {
        final expected = (c['rank'][g] as List);
        final got = b.rank(g, ece);
        expect([for (final r in got) r.crop], [for (final e in expected) e[0]], reason: 'order $g ece $ece');
        for (var i = 0; i < got.length; i++) {
          expect((got[i].grossEgp - (expected[i][1] as num)).abs(), lessThanOrEqualTo(1), reason: '${got[i].crop} ece $ece');
          expect(got[i].saltPct, expected[i][2], reason: '${got[i].crop} ece $ece');
        }
      }
    }
  });

  test('goal question: money, plan and improve are understood; promises are refused', () {
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    expect(d.step, Step.goal);
    final promise = d.handle('ضمنلي محصول اكتر');
    expect(promise.last.retry, isTrue);
    expect(d.step, Step.goal);
    d.handle('عايز اكسب فلوس اكتر');
    expect(d.goal, 'money');
    expect(d.step, Step.salt);
    final p = Dialogue(data)..opening();
    p.handle('الغربية');
    p.handle('عايز ازرع محصول معين في ميعاد معين');
    expect(p.goal, 'plan');
    expect(p.step, Step.planCrop);
    final i = Dialogue(data)..opening();
    i.handle('الغربية');
    i.handle('احسن اللي بزرعه دلوقتي');
    expect(i.step, Step.crop);
  });

  test('earn-more flow ends with a ranked income result', () {
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    d.handle('money');
    final out = d.handle('patches');
    final r = out.last.goalResult as MoneyResult;
    expect(r.ece, 6.0);
    expect(r.groups['winter']!.first.grossEgp, greaterThan(0));
    expect(out.last.spoken, contains('الشتا')); // short on purpose: the figures are on the screen
  });

  test('plan flow: any crop, any month, with season, salt and income', () {
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    d.handle('plan');
    d.handle('بصل');
    expect(d.planCrop, 'onion');
    d.handle('نوفمبر');
    expect(d.planWhen, '11-15');
    final r = d.handle('none').last.goalResult as PlanResult;
    expect(r.crop.key, 'onion');
    expect(r.seasonLabel, isNot('wrong season'));
    expect(r.gross.grossEgp, greaterThan(0));
    // a crop the temperature screen cannot judge says so, and a tree has no sowing season
    final g = Dialogue(data)..opening();
    g.handle('الغربية');
    g.handle('plan');
    g.handle('عنب');
    g.handle('فبراير');
    expect((g.handle('none').last.goalResult as PlanResult).seasonLabel, 'cannot judge');
  });

  test('the professional view is offered at the goal question and opens from a spoken word', () {
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    expect(d.prompt().choices.map((c) => c.value), contains('pro'));
    expect(d.handle('pro').last.openPro, isTrue);
    expect(d.step, Step.goal);
    expect(d.handle('عايز اشوف البيانات').last.openPro, isTrue);
  });

  test('original flow still works when the goal question is skipped', () {
    final d = Dialogue(data, askGoal: false)..opening();
    d.handle('الغربية');
    expect(d.step, Step.crop);
  });

  test('the AI interpreter accepts only an allowed key', () async {
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    final opts = interpretOptions(d)!;
    expect(opts.keys.toSet(), {'money', 'plan', 'improve'});
    expect(await interpretPhrase('عايز اربح اكتر', opts, keys: ['k'], caller: (k, s, p, t) async => 'money'), 'money');
    expect(await interpretPhrase('عايز اربح اكتر', opts, keys: ['k'], caller: (k, s, p, t) async => 'Money.\n'), 'money');
    expect(await interpretPhrase('xx', opts, keys: ['k'], caller: (k, s, p, t) async => 'maybe profit'), isNull);
    expect(await interpretPhrase('xx', opts, keys: ['k'], caller: (k, s, p, t) async => 'none'), isNull);
    expect(await interpretPhrase('xx', opts, keys: const [], caller: (k, s, p, t) async => 'money'), isNull);
    expect(await interpretPhrase('x' * 120, opts, keys: ['k'], caller: (k, s, p, t) async => 'money'), isNull);
    expect(await interpretPhrase('xx', opts, keys: ['a', 'b'], caller: (k, s, p, t) async => k == 'a' ? throw Exception('quota') : 'plan'), 'plan');
  });
}
