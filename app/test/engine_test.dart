// The Dart engine must reproduce the Python engines (golden cases exported by scripts/export_app_data.py)
// and the dialogue must understand typical Arabic answers.
import 'dart:convert';
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key.replaceFirst('assets/', 'assets/')).readAsString();
}

void main() {
  late EngineData data;
  setUpAll(() async => data = await EngineData.load(_FileBundle()));

  test('Dart comparison matches the Python golden cases', () {
    final cases = jsonDecode(File('test/fixtures/rotation_cases.json').readAsStringSync()) as List;
    expect(cases.length, greaterThanOrEqualTo(9));
    for (final c in cases) {
      final seqs = [
        for (final s in c['sequences'])
          SequenceInput(
            name: 'x',
            crop: s['summer_crop'],
            summerSowing: '${(s['summer_sowing'][0] as int).toString().padLeft(2, '0')}-${(s['summer_sowing'][1] as int).toString().padLeft(2, '0')}',
            wheatSowing: '${(s['wheat_sowing'][0] as int).toString().padLeft(2, '0')}-${(s['wheat_sowing'][1] as int).toString().padLeft(2, '0')}',
          )
      ];
      final out = compare(data, c['site'], seqs, signs: c['signs'], intervalDays: c['interval_days']);
      for (var i = 0; i < seqs.length; i++) {
        final e = c['expected'][i], r = out.rows[i];
        final tag = '${c['site']} ${c['signs']} row $i';
        expect(r.etc, e['etc'], reason: tag);
        expect(r.ratio, closeTo((e['ratio'] as num).toDouble(), 0.011), reason: tag);
        expect(r.heatMedian, e['heat_median'], reason: tag);
        expect(r.extra['32'], e['extra32'], reason: tag);
        expect(r.gapDays, e['gap'], reason: tag);
        expect(r.harvest, e['harvest'], reason: tag);
        expect(r.turnMm, e['turn_mm'], reason: tag);
        expect(r.saltSummer?.status, e['salt_summer'], reason: tag);
        expect(r.saltWheat?.status, e['salt_wheat'], reason: tag);
      }
    }
  });

  test('half-even rounding matches Python', () {
    expect(roundHalfEven(34.5), 34);
    expect(roundHalfEven(31.5), 32);
    expect(roundHalfEven(2.4), 2);
    expect(roundHalfEven(2.6), 3);
  });

  test('salt interpolation follows the FAO table', () {
    final pts = [[6.0, 100.0], [7.4, 90.0], [9.5, 75.0], [13.0, 50.0]];
    expect(yieldPotential(pts, 3), 100);
    expect(yieldPotential(pts, 13), closeTo(50, 1e-9));
    expect(yieldPotential(pts, 14), isNull);
    expect(() => yieldPotential(pts, -1), throwsArgumentError);
  });

  test('bad input is rejected', () {
    expect(() => compare(data, 'atlantis', [SequenceInput(name: 'x', crop: 'rice', summerSowing: '05-15', wheatSowing: '11-15')]), throwsArgumentError);
    expect(() => compare(data, 'gharbia', []), throwsArgumentError);
    expect(() => compare(data, 'gharbia', [SequenceInput(name: 'x', crop: 'rice', summerSowing: '05-15', wheatSowing: '11-15')], ece: 3, signs: 'none'), throwsArgumentError);
  });

  group('understanding Arabic answers', () {
    test('governorates, crops, dates, days, salt', () {
      expect(parseSite(normalizeAr('أنا في كفر الشيخ')), 'kafr_el_sheikh');
      expect(parseSite(normalizeAr('الغربية')), 'gharbia');
      expect(parseCrop(normalizeAr('بزرع رز')), 'rice');
      expect(parseCrop(normalizeAr('ذرة شامية')), 'maize');
      expect(parseCrop(normalizeAr('قطن')), 'cotton');
      expect(parseWhen(normalizeAr('نص نوفمبر'), ['11-01', '11-15', '12-01']), '11-15');
      expect(parseWhen(normalizeAr('أول ديسمبر'), ['11-01', '11-15', '12-01']), '12-01');
      expect(parseWhen(normalizeAr('آخر نوفمبر'), ['11-01', '11-10', '11-15', '11-20', '11-25']), '11-25');
      expect(parseWhen(normalizeAr('مارس'), ['11-01', '11-15']), isNull);
      expect(parseDays(normalizeAr('كل ١٠ ايام')), 10);
      expect(parseDays(normalizeAr('اسبوعين')), 14);
      expect(parseSalt(normalizeAr('في قشرة بيضاء'))?.signs, 'crust');
      expect(parseSalt(normalizeAr('مفيش قشرة'))?.signs, 'none');
      expect(parseSalt(normalizeAr('بقع'))?.signs, 'patches');
      expect(parseSalt(normalizeAr('التحليل طلع ٥'))?.ece, 5);
      expect(parseSalt(normalizeAr('مش عارف'))?.skipped, isTrue);
    });

    test('a full conversation reaches a comparison and speaks only engine numbers', () {
      final d = Dialogue(data);
      var out = d.handle('الغربية');
      expect(d.step, Step.crop);
      d.handle('رز');
      d.handle('منتصف يونيو');
      expect(d.summerSowing, '06-15');
      d.handle('أول ديسمبر');
      expect(d.wheatSowing, '12-01');
      d.handle('١٠');
      out = d.handle('بقع');
      expect(d.step, Step.done);
      final res = out.first.result!;
      expect(res.rows.length, 3);
      expect(res.rows.first.isExisting, isTrue);
      expect(out.first.spoken, contains('الرز بياخد مية أكتر'));
      expect(out.first.spoken, contains('مش بتحل محل'));
    });

    test('unclear answers get a retry, not a crash', () {
      final d = Dialogue(data);
      expect(d.handle('هه').first.ar, contains('مفهمتش'));
      expect(d.step, Step.site);
    });
  });
}
