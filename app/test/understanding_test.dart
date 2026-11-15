// Understanding what a farmer says: whole words, not pieces of words (a review by a teammate found wrong answers with no warning), the goal question
// after every way of choosing a place, months said as numbers or Coptic names, number words, and salt answers with a "no".
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:field_shift/goals.dart';
import 'package:field_shift/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

String _n(String s) => normalizeAr(s);

void main() {
  late EngineData data;
  setUpAll(() async {
    data = await EngineData.load(_FileBundle());
    lang.value = 'ar';
  });

  test('every way of choosing a place leads to the goal question', () {
    final a = Dialogue(data)..opening();
    a.handle('المنصورة');
    expect(a.step, Step.goal);
    final b = Dialogue(data)..opening();
    b.handleLocation(31.04, 31.38); // a map tap in Dakahlia
    expect(b.step, Step.goal);
    final c = Dialogue(data)..opening();
    c.handle('الدقهلية');
    expect(c.step, Step.goal);
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    d.handle('money'); // and "earn more" is reachable after any of them
    expect(d.goal, 'money');
  });

  test('"akeed" is not a request for a guarantee', () {
    final d = Dialogue(data)..opening();
    expect(d.parseGoal(_n('أكيد عايز أكسب أكتر')), 'money');
    expect(d.parseGoal(_n('ضمان ربح')), 'unmeasurable');
  });

  test('places are matched as whole names', () {
    expect(parseSite(_n('كفر الشيخ')), 'kafr_el_sheikh');
    expect(parseSite(_n('في كفر الشيخ')), 'kafr_el_sheikh');
    expect(parseSite(_n('كفر الزيات')), 'gharbia');
    expect(parseSite(_n('كفر شكر')), isNull);
    expect(parseSite(_n('الشيخ زايد')), isNull);
    expect(parseSite(_n('بالغربية')), 'gharbia');
    expect(parseSite(_n('دمنهور')), 'beheira');
    expect(parseSite(_n('المحلة')), 'gharbia');
    final d = Dialogue(data)..opening();
    final out = d.handle('الشيخ زايد'); // Giza, outside the Delta
    expect(out.last.retry, isTrue);
    expect(d.step, Step.site);
    final k = Dialogue(data)..opening();
    k.handle('كفر شكر'); // Qalyubia
    expect(k.step, Step.goal);
  });

  test('crops are matched as whole words', () {
    expect(parseCrop(_n('ربنا يرزق، بزرع قطن')), 'cotton');
    expect(parseCrop(_n('عندي ندرة مية، بزرع قطن')), 'cotton');
    expect(parseCrop(_n('الرز')), 'rice');
    expect(parseCrop(_n('ذرة شامي')), 'maize');
    expect(parseCrop(_n('ذرة رفيعة')), isNull); // sorghum is not maize
    final b = CropBook(data);
    expect(b.parse(_n('فول سوداني'))?.key, isNot('faba_bean'));
    expect(b.parse(_n('بطاطا'))?.key, isNot('potato'));
    expect(b.parse(_n('بطاطس'))?.key, 'potato');
    expect(notCoveredCrop(_n('فول سوداني')), 'peanut');
    final d = Dialogue(data)..opening();
    d.handle('الغربية');
    d.handle('improve');
    final out = d.handle('ذرة رفيعة');
    expect(out.last.retry, isTrue);
    expect(out.last.ar, contains('مش في مقارنة'));
  });

  test('months as numbers, number words and Coptic names', () {
    final allowed = data.wheatDates('gharbia');
    expect(parseWhen(_n('شهر 11'), allowed)!.startsWith('11-'), isTrue);
    expect(parseWhen(_n('شهر ١١'), allowed)!.startsWith('11-'), isTrue);
    expect(parseWhen(_n('شهر 12'), allowed)!.startsWith('12-'), isTrue);
    expect(parseWhen(_n('شهر اتناشر'), allowed)!.startsWith('12-'), isTrue);
    expect(parseWhen(_n('في هاتور'), allowed)!.startsWith('11-'), isTrue);
    expect(parseWhen(_n('في كيهك'), allowed)!.startsWith('12-'), isTrue);
    expect(parseWhen(_n('في طوبة'), allowed)!.startsWith('01-'), isTrue);
    final summer = data.summerDates('gharbia', 'rice');
    expect(parseWhen(_n('في بشنس'), summer)!.startsWith('05-'), isTrue);
    expect(parseWhen(_n('في بؤونة'), summer)!.startsWith('06-'), isTrue);
  });

  test('maize can be sown in June, as many Delta farmers do after the wheat harvest', () {
    final maize = data.summerDates('gharbia', 'maize');
    expect(maize, contains('06-15'));
    expect(data.water['gharbia']['maize']['06-15'], isNotNull);
  });

  test('days between waterings can be said in words', () {
    expect(parseDays(_n('كل خمس ايام')), 5);
    expect(parseDays(_n('كل عشرة ايام')), 10);
    expect(parseDays(_n('كل يومين')), 2);
    expect(parseDays(_n('مرتين في الشهر')), 15);
    expect(parseDays(_n('كل اسبوع')), 7);
    expect(parseDays(_n('كل 12 يوم')), 12);
  });

  test('salt answers keep their "no"', () {
    expect(parseSalt(_n('مش فيه بقع'))?.signs, 'none');
    expect(parseSalt(_n('مفيش بقع'))?.signs, 'none');
    expect(parseSalt(_n('من غير قشرة'))?.signs, 'none');
    expect(parseSalt(_n('لا'))?.signs, 'none');
    expect(parseSalt(_n('في بقع'))?.signs, 'patches');
    expect(parseSalt(_n('في ملح'))?.signs, 'patches');
    expect(parseSalt(_n('في ملح كتير'))?.signs, 'crust');
    expect(parseSalt(_n('الأرض مالحة'))?.signs, 'patches');
    expect(parseSalt(_n('قشرة بيضا'))?.signs, 'crust');
  });
}
