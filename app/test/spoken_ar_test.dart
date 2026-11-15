// What Eyad says: Egyptian words for digits, dates and the EC abbreviation (rules approved by Tarek, 2026-11-15).
import 'package:field_shift/spoken_ar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers in Egyptian spelling', () {
    const want = {
      0: 'صفر', 1: 'واحد', 2: 'اتنين', 3: 'تلاتة', 7: 'سبعة', 8: 'تمانية', 10: 'عشرة', 11: 'حداشر', 12: 'اتناشر', 13: 'تلتاشر', 15: 'خمستاشر', 19: 'تسعتاشر',
      20: 'عشرين', 21: 'واحد وعشرين', 23: 'تلاتة وعشرين', 25: 'خمسة وعشرين', 30: 'تلاتين', 48: 'تمانية وأربعين', 99: 'تسعة وتسعين', 100: 'مية', 200: 'ميتين',
      235: 'ميتين وخمسة وتلاتين', 300: 'تلتمية', 1000: 'ألف', 1500: 'ألف وخمسمية', 2000: 'ألفين', 3000: 'تلات تلاف',
    };
    want.forEach((n, w) => expect(egNumber(n), w, reason: '$n'));
    for (var n = 0; n <= 999; n++) {
      final w = egNumber(n);
      expect(w.contains('ث'), isFalse, reason: 'no formal ث in $n: $w'); // تلاتة, not ثلاثة
      expect(RegExp(r'\d').hasMatch(w), isFalse, reason: '$n');
    }
  });

  test('counted nouns keep the plural the way day counts do', () {
    expect(egDays(1), 'يوم');
    expect(egDays(2), 'يومين');
    expect(egDays(6), 'ست أيام'); // not سته يوم
    expect(egDays(10), 'عشر أيام');
    expect(egDays(11), 'حداشر يوم');
    expect(egDays(23), 'تلاتة وعشرين يوم');
    expect(egMm(6), 'ست مليمترات');
    expect(egMm(15), 'خمستاشر مليمتر');
  });

  test('dates are said "نص" and "أول"', () {
    expect(speakable('تمام، ١٥ نوفمبر.'), 'تمام، نص نوفمبر.');
    expect(speakable('تمام، ١ يناير.'), 'تمام، أول يناير.');
    expect(speakable('تمام، ١٠ يناير.'), 'تمام، عشرة يناير.');
    expect(speakable('تمام، ٢٠ مارس.'), 'تمام، عشرين مارس.');
    expect(speakable('تمام، ٢٥ أكتوبر.'), 'تمام، خمسة وعشرين أكتوبر.');
  });

  test('the EC abbreviation is not spoken', () {
    expect(speakable('لو عملت تحليل قول الرقم (EC).'), 'لو عملت تحليل قول رقم الملوحة.');
    expect(speakable('قول عدد الأيام، مثلاً ١٠.'), 'قول عدد الأيام، مثلاً عشرة.');
  });

  test('numbers inside result lines', () {
    expect(speakable('محتاج مية أقل بـ٢٣ في المية.'), 'محتاج مية أقل بتلاتة وعشرين في المية.');
    expect(speakable('احتياج المية حوالي ٥٤٠ مم في الموسم.'), 'احتياج المية حوالي خمسمية وأربعين مليمتر في الموسم.');
    expect(speakable('فاضل ٦ أيام بس'), 'فاضل ست أيام بس');
    expect(speakable('فاضل ٢٣ يوم بس'), 'فاضل تلاتة وعشرين يوم بس');
    expect(speakable('النسبة ٧٥٪'), 'النسبة خمسة وسبعين في المية');
  });

  test('text without Arabic letters is left alone, and words with no digits are unchanged', () {
    expect(speakable('Wheat meets about 12 days of heat'), 'Wheat meets about 12 days of heat');
    expect(speakable('إيه أكتر حاجة بتدور عليها دلوقتي؟'), 'إيه أكتر حاجة بتدور عليها دلوقتي؟');
  });
}
