// Voice-first: one sentence can give several answers; Eyad then asks only for what is missing.
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

  test('an Arabic sentence with place, crop and both dates fills four answers and asks the next question', () {
    final d = Dialogue(data);
    final out = d.handle('أنا في الغربية وبزرع رز في نص يونيو وقمح أول ديسمبر');
    expect(d.site, 'gharbia');
    expect(d.crop, 'rice');
    expect(d.summerSowing, '06-15');
    expect(d.wheatSowing, '12-01');
    expect(d.step, Step.interval); // the next missing answer
    expect(out.first.note, isTrue);
    expect(out.first.ar, contains('فهمت'));
    expect(out.last.ar, contains('المية'));
  });

  test('an English sentence with everything gives the comparison straight away', () {
    final d = Dialogue(data);
    final out = d.handle('I am in Gharbia, I grow rice in mid June and wheat in early December, water every 10 days, and there are salty patches');
    expect(d.step, Step.done);
    expect(out.last.result, isNotNull);
    expect(out.last.result!.rows.length, 3);
    expect(d.interval, 10);
    expect(d.salt?.signs, 'patches');
  });

  test('two answers in the middle of the conversation are both kept', () {
    final d = Dialogue(data);
    d.handle('الغربية');
    expect(d.step, Step.crop);
    d.handle('بزرع رز في مايو');
    expect(d.crop, 'rice');
    expect(d.summerSowing, '05-15');
    expect(d.step, Step.wheatWhen);
  });

  test('a single answer still goes through the normal step', () {
    final d = Dialogue(data);
    final out = d.handle('رز');
    expect(d.step, Step.site); // one answer, not enough place: asked again
    expect(out.first.retry, isTrue);
  });

  test('Mansoura plus a crop uses the Gharbia data and says why', () {
    final d = Dialogue(data);
    final out = d.handle('أنا في المنصورة وبزرع رز');
    expect(d.site, 'gharbia');
    expect(d.crop, 'rice');
    expect(out.first.ar, contains('نفس خلية'));
  });

  test('wheat month with no crop word is understood from the season, and numbers in dates are not read as days', () {
    final d = Dialogue(data);
    d.handle('الغربية رز');
    expect(d.step, Step.summerWhen);
    d.handle('نص مايو');
    d.handle('نص نوفمبر');
    expect(d.wheatSowing, '11-15');
    expect(d.interval, isNull);
  });
}
