// The extra NASA cells (decision D15): named in both languages, kept out of the place list, flagged when desert or sea, and chosen for places with no named point.
import 'dart:io';

import 'package:field_shift/engine.dart';
import 'package:field_shift/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

void main() {
  late EngineData d;
  setUpAll(() async {
    d = await EngineData.load(_FileBundle());
    registerSiteNames(d);
  });

  test('cells are data points, not places in the list', () {
    expect(d.namedSiteKeys.length, 7);
    expect(d.siteKeys.length, 19);
    expect(d.siteKeys.where((k) => k.startsWith('cell_')).length, 12);
  });

  test('cells have names in Arabic and English and a caveat when desert or sea', () {
    lang.value = 'ar';
    expect(siteN('cell_30.500_30.625'), contains('خلية بيانات ناسا'));
    lang.value = 'en';
    expect(siteN('cell_30.500_30.625'), startsWith('NASA data cell 30.5'));
    expect(d.siteCaveatKind('cell_30.500_30.625'), isNull);
    expect(d.siteCaveatKind('cell_30.500_32.500'), 'desert_edge');
    expect(d.siteCaveatKind('cell_31.000_29.375'), 'sea');
  });

  test('a place in a cell with no named point uses that cell, and numbers can be computed for it', () {
    // 30.4 N 30.4 E is in the south-west Delta: no named point shares its cell
    expect(siteInSameCell(d, 30.4, 30.4), 'cell_30.500_30.625');
    // a place in Gharbia's cell still uses Gharbia
    expect(siteInSameCell(d, 30.9, 31.1), 'gharbia');
    final c = compare(d, 'cell_30.500_30.625', [SequenceInput(name: 'x', crop: 'rice', summerSowing: '05-15', wheatSowing: '11-15')], signs: 'none');
    expect(c.rows.first.etc, greaterThan(500));
    final e = compare(d, 'cell_30.500_32.500', [SequenceInput(name: 'x', crop: 'maize', summerSowing: '05-01', wheatSowing: '11-15')]);
    expect(e.caveatKind, 'desert_edge');
    lang.value = 'en';
    expect(caveatN(e), contains('desert'));
  });
}
