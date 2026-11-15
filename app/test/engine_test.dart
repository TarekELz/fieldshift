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

  group('map picker logic', () {
    test('a tap near each data point picks that point', () {
      for (final k in data.siteKeys) {
        final p = data.siteLatLon(k);
        final n = nearestSite(data, p.lat + 0.01, p.lon - 0.01);
        expect(n.key, k);
        expect(n.km, lessThan(3));
      }
    });

    test('tapping Tanta picks the Gharbia data point and moves on to the crop question', () {
      final d = Dialogue(data);
      final msgs = d.handleLocation(30.79, 31.00);
      expect(d.site, 'gharbia');
      expect(d.step, Step.crop);
      expect(msgs.first.ar, contains('الغربية'));
    });

    test('each NASA data point lies inside the governorate it is labelled for', () {
      for (final k in data.siteKeys) {
        final p = data.siteLatLon(k);
        final g = governorateAt(data, p.lat, p.lon);
        expect(g, isNotNull, reason: '$k is outside every governorate');
        expect(g!['site'], k, reason: '$k lies in ${g['id']}, which owns ${g['site']}');
      }
    });

    test('a governorate without its own data point uses the nearest one and says so', () {
      final d = Dialogue(data);
      final msgs = d.handleLocation(31.04, 31.36); // Mansoura, Dakahlia
      expect(d.step, Step.crop);
      expect(d.site, isNotNull);
      expect(msgs.first.ar, contains('الدقهلية'));
      expect(msgs.first.ar, contains('مفيهاش'));
    });

    test('a governorate can also be named by voice or typing', () {
      final d = Dialogue(data);
      d.handle('الدقهلية');
      expect(d.step, Step.crop);
      final e = Dialogue(data);
      expect(e.handle('أنا في القليوبية').first.ar, contains('القليوبية'));
    });

    test('a tap in the sea or in another country is refused', () {
      final d = Dialogue(data);
      final msgs = d.handleLocation(32.6, 30.0); // Mediterranean, off the coast
      expect(d.step, Step.site);
      expect(msgs.first.retry, isTrue);
    });

    test('a governorate outside the Delta is named in the refusal', () {
      final d = Dialogue(data);
      expect(d.handleLocation(25.70, 32.65).first.ar, contains('الأقصر'));
    });

    test('Halayeb and Shalateen are drawn, named, and recognised outside the Delta', () {
      expect(data.areas.map((a) => a['id']).toSet(), {'Halayeb', 'Shalateen'});
      expect(data.areas.map((a) => a['ar']).toSet(), {'حلايب', 'شلاتين'});
      final h = Dialogue(data).handleLocation(22.3, 36.2); // Halayeb
      expect(h.first.ar, contains('حلايب'));
      expect(h.first.ar, contains('منطقة'));
      expect(h.first.retry, isTrue);
      final s = Dialogue(data).handleLocation(23.0, 34.6); // Shalateen
      expect(s.first.ar, contains('شلاتين'));
      final byName = Dialogue(data);
      expect(byName.handle('حلايب').first.ar, contains('حلايب'));
      expect(byName.step, Step.site);
      expect(Dialogue(data).handle('shalateen').first.en, contains('Shalateen'));
    });

    test('a tap outside the Delta is refused and the map stays', () {
      final d = Dialogue(data);
      final msgs = d.handleLocation(25.70, 32.65); // Luxor
      expect(d.site, isNull);
      expect(d.step, Step.site);
      expect(msgs.first.retry, isTrue);
      expect(msgs.first.showMap, isTrue);
      expect(msgs.first.ar, contains('برا دلتا النيل'));
    });

    test('a map tap after the place is chosen does not change it', () {
      final d = Dialogue(data);
      d.handleLocation(30.86, 31.05);
      final before = d.site;
      d.handleLocation(31.35, 31.75);
      expect(d.site, before);
    });

    test('the opening question asks where the field is and shows the map', () {
      final m = Dialogue(data).opening();
      expect(m.ar, contains('الخريطة'));
      expect(m.en, contains('map'));
      expect(m.showMap, isTrue);
    });

    test('the map file has the 27 governorates, ten of them in the Delta, and both Delta branches', () {
      final names = (data.egyptMap['water'] as List).map((w) => w['name']).toSet();
      expect(names, containsAll(['Nile', 'Rosetta Branch', 'Damietta Branch']));
      expect(data.governorates.length, 27);
      expect(data.governorates.where((g) => g['delta'] == true).length, 10);
      expect(data.governorates.every((g) => (g['ar'] as String).isNotEmpty && (g['rings'] as List).isNotEmpty), isTrue);
    });
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

    test('every answer button sends a date the dialogue keeps exactly (1 November and 1 December were read as January)', () {
      for (final w in data.wheatDates('gharbia')) {
        final d = Dialogue(data)
          ..site = 'gharbia'
          ..crop = 'rice'
          ..summerSowing = '06-15'
          ..step = Step.wheatWhen;
        d.handle(w);
        expect(d.wheatSowing, w, reason: 'wheat button $w');
      }
      for (final s in data.summerDates('gharbia', 'rice')) {
        final d = Dialogue(data)
          ..site = 'gharbia'
          ..crop = 'rice'
          ..step = Step.summerWhen;
        d.handle(s);
        expect(d.summerSowing, s, reason: 'summer button $s');
      }
    });

    test('unclear answers get a retry, not a crash', () {
      final d = Dialogue(data);
      expect(d.handle('هه').first.ar, contains('مفهمتش'));
      expect(d.step, Step.site);
    });
  });
}
