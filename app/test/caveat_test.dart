// A sea warning only for the sea cell; the shared-cell note only names the other governorate.
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

void main() {
  late EngineData data;
  setUpAll(() async => data = await EngineData.load(_FileBundle()));

  Comparison run(String site) => compare(data, site, [SequenceInput(name: 'x', crop: 'rice', summerSowing: '05-15', wheatSowing: '11-15')]);

  test('Damietta gets the sea warning', () {
    final c = run('damietta');
    expect(c.caveatKind, 'sea');
    expect(caveatAr(c), contains('البحر'));
  });

  test('Menoufia and Sharqia get a shared-cell note, not a sea warning', () {
    for (final s in ['menoufia', 'sharqia']) {
      final c = run(s);
      expect(c.caveatKind, 'shared_cell', reason: s);
      expect(caveatAr(c), isNot(contains('البحر')), reason: s);
      expect(caveatAr(c), contains(s == 'menoufia' ? 'الشرقية' : 'المنوفية'), reason: s);
    }
  });

  test('sites without a caveat show nothing', () {
    for (final s in ['gharbia', 'kafr_el_sheikh', 'beheira']) {
      expect(caveatAr(run(s)), isNull, reason: s);
    }
  });
}
