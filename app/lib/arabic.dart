// Arabic text for the app. DRAFT: written by the project's AI assistant and not yet reviewed by a
// native Egyptian speaker. Tarek (task 2 in docs/tasks.md) reviews and corrects every string here.
// Numbers and dates come only from the engines; this file only wraps them in words.

const _digits = '٠١٢٣٤٥٦٧٨٩';

/// Arabic-Indic digits for display and speech ("15" -> "١٥").
String arDigits(Object n) => n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : _digits[i];
    }).join();

/// Filled with the extra NASA cells' names when the data loads (registerSiteNames in i18n.dart).
final Map<String, String> arSite = {
  'kafr_el_sheikh': 'كفر الشيخ',
  'damietta': 'دمياط',
  'beheira': 'البحيرة',
  'gharbia': 'الغربية (طنطا)',
  'menoufia': 'المنوفية',
  'sharqia': 'الشرقية',
  'dakahlia': 'الدقهلية (شرق)',
};

const arCrop = {'rice': 'الرز', 'maize': 'الذرة', 'cotton': 'القطن', 'wheat': 'القمح'};
const arMonth = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

/// "11-15" -> "١٥ نوفمبر"
String arDate(String mmdd) {
  final p = mmdd.split('-');
  return '${arDigits(int.parse(p[1]))} ${arMonth[int.parse(p[0]) - 1]}';
}

const arSalt = {'fine': 'مناسب', 'reduced': 'إنتاج أقل', 'not advised': 'مش مناسب'};

const arNotice = 'الأرقام دي بتساعدك بس، ومش بتحل محل خبرتك ولا رأي المرشد الزراعي. اسأل المرشد قبل ما تغير الدورة.';
const arSources = 'الأرقام من بيانات ناسا (NASA POWER) وجداول الفاو (FAO)، والملوحة من كلامك أنت.';
const arNotModelled = 'مش محسوب: النيتروجين وخصوبة التربة، الآفات والأمراض، الأسعار والدخل، العمالة والمعدات، وغمر الرز وتسرب المية.';

/// "Water compared with your current rotation" in words.
String arRatio(double ratio) {
  if (ratio == 1.0) return 'نفس احتياج اللي بتزرعه دلوقتي';
  final pct = ((ratio - 1).abs() * 100).round();
  if (pct == 0) return 'تقريباً نفس احتياج اللي بتزرعه دلوقتي';
  return ratio < 1 ? 'أقل ${arDigits(pct)}٪ من اللي بتزرعه دلوقتي' : 'أكتر ${arDigits(pct)}٪ من اللي بتزرعه دلوقتي';
}

/// Number in Arabic digits with an Arabic decimal mark: 1.12 -> "١٫١٢".
String arNum(num v, {int dec = 0}) => arDigits(v.toStringAsFixed(dec)).replaceAll('.', '٫');

const _enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Engine harvest text "13 Oct" -> "١٣ أكتوبر".
String arHarvest(String s) {
  final p = s.split(' ');
  final i = _enMonths.indexOf(p.length > 1 ? p[1] : '');
  return i < 0 ? s : '${arDigits(int.parse(p[0]))} ${arMonth[i]}';
}
