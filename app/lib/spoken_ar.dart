// What Eyad SAYS is not always what the screen shows. The screen keeps digits ("١٥ نوفمبر", "٢٣٪"); the voice gets Egyptian words, because digits, Latin letters
// and symbols are misread by text-to-speech (round-trip check, docs/arabic-tts-patterns.md: "١ يناير" came back as "واحد يا ماير", "(EC)" as "20").
// Rules approved by Tarek (2026-11-15): "نص" for the 15th and "أول" for the 1st of a month; the soil question says "رقم الملوحة" instead of "EC"; numbers in
// Egyptian spelling (تلاتة, never ثلاثة) with the counted noun the way day counts already are ("ست أيام", "حداشر يوم"), never "سته يوم".
// Used by voice.dart before a line is looked up or sent, and by test/spoken_lines_test.dart so the list of recorded lines is the list of spoken forms.

const _units = ['صفر', 'واحد', 'اتنين', 'تلاتة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'تمانية', 'تسعة', 'عشرة'];
const _teens = ['حداشر', 'اتناشر', 'تلاتاشر', 'أربعتاشر', 'خمستاشر', 'ستاشر', 'سبعتاشر', 'تمنتاشر', 'تسعتاشر']; // 11 to 19
const _tens = {2: 'عشرين', 3: 'تلاتين', 4: 'أربعين', 5: 'خمسين', 6: 'ستين', 7: 'سبعين', 8: 'تمانين', 9: 'تسعين'};
const _hundreds = {1: 'مية', 2: 'ميتين', 3: 'تلتمية', 4: 'ربعمية', 5: 'خمسمية', 6: 'ستمية', 7: 'سبعمية', 8: 'تمنمية', 9: 'تسعمية'};
const _construct = {3: 'تلات', 4: 'أربع', 5: 'خمس', 6: 'ست', 7: 'سبع', 8: 'تمان', 9: 'تسع', 10: 'عشر'}; // the form before a plural noun: تلات أيام

/// A whole number 0 to 99999 in Egyptian spoken Arabic, standing alone ("تلاتة وعشرين", "ميتين وخمسة وتلاتين", "ألف وخمسمية").
String egNumber(int n) {
  if (n < 0) return 'ناقص ${egNumber(-n)}';
  if (n <= 10) return _units[n];
  if (n < 20) return _teens[n - 11];
  if (n < 100) {
    final u = n % 10, t = n ~/ 10;
    return u == 0 ? _tens[t]! : '${_units[u]} و${_tens[t]}';
  }
  if (n < 1000) {
    final r = n % 100, h = _hundreds[n ~/ 100]!;
    return r == 0 ? h : '$h و${egNumber(r)}';
  }
  final r = n % 1000, k = n ~/ 1000;
  final String th;
  if (k == 1) {
    th = 'ألف';
  } else if (k == 2) {
    th = 'ألفين';
  } else if (k <= 10) {
    th = '${_construct[k]} تلاف';
  } else {
    th = '${egNumber(k)} ألف';
  }
  return r == 0 ? th : '$th و${egNumber(r)}';
}

/// A count of days: "يوم", "يومين", "تلات أيام" ... "عشر أيام", then "حداشر يوم", "تلاتة وعشرين يوم" (the noun stays singular from 11).
String egDays(int n) {
  if (n == 1) return 'يوم';
  if (n == 2) return 'يومين';
  if (n <= 10) return '${_construct[n]} أيام';
  return '${egNumber(n)} يوم';
}

/// A count of millimetres the same way: "مليمتر", "مليمترين", "ست مليمترات", "حداشر مليمتر".
String egMm(int n) {
  if (n == 1) return 'مليمتر';
  if (n == 2) return 'مليمترين';
  if (n <= 10) return '${_construct[n]} مليمترات';
  return '${egNumber(n)} مليمتر';
}

/// The text as it is SENT to the voice for a line that has no recording: the same words, with the marks Tarek chose after listening to samples (2026-11-15):
/// "ست أيام" gets a shadda and a linking kasra so the ت does not stop dead ("sitt ayyaam", not "st ayam"), and "تلاتاشر" its marks ("talatashar"). The screen and the phone's
/// own voice keep the plain words. Recorded clips are looked up by the plain text, so this is applied only where audio is requested from Hamsa.
String forVoice(String text) => text.replaceAll('ست أيام', 'سِتِّ أَيَّام').replaceAll('تلاتاشر يوم', 'تَلَاتَاشَر يُوم').replaceAll('تلاتاشر', 'تَلَاتَاشَر');

const _months = 'يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر';
const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

/// The text as it should be spoken: no digits, no Latin letters, no symbols that are misread. Text without Arabic letters (English) is returned unchanged.
String speakable(String text) {
  if (!RegExp(r'[؀-ۿ]').hasMatch(text)) return text;
  var t = text;
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(_arabicIndic[i], '$i');
  }
  t = t.replaceAll('٪', ' في المية').replaceAll('%', ' في المية');
  // the soil question: the lab abbreviation is dropped in speech
  t = t.replaceAll(RegExp(r'الرقم\s*\(EC\)'), 'رقم الملوحة').replaceAll(RegExp(r'\s*\(EC\)'), '');
  // a day of a month: "15 نوفمبر" is said "نص نوفمبر", "1 يناير" "أول يناير"
  t = t.replaceAllMapped(RegExp('(\\d{1,2})\\s+($_months)'), (m) {
    final d = int.parse(m.group(1)!);
    final w = d == 1 ? 'أول' : (d == 15 ? 'نص' : egNumber(d));
    return '$w ${m.group(2)}';
  });
  t = t.replaceAllMapped(RegExp(r'(\d+)[.,](\d+)'), (m) => '${egNumber(int.parse(m.group(1)!))} فاصلة ${egNumber(int.parse(m.group(2)!))}');
  t = t.replaceAllMapped(RegExp(r'ـ?(\d+)\s*(?:مم|ملم)(?![ء-ي])'), (m) => egMm(int.parse(m.group(1)!)));
  t = t.replaceAllMapped(RegExp(r'ـ?(\d+)\s+(?:أيام|ايام|يوم)(?![ء-ي])'), (m) => egDays(int.parse(m.group(1)!)));
  t = t.replaceAllMapped(RegExp(r'(بـ|ـ)?(\d+)'), (m) => '${m.group(1) == 'بـ' ? 'ب' : ''}${egNumber(int.parse(m.group(2)!))}');
  return t;
}
