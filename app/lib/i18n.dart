// Language switch: Arabic (default) or English, one at a time. Every screen reads the language here and rebuilds when
// it changes. Numbers always come from the engines; this file only wraps them in words (Arabic text is a DRAFT for
// native-speaker review, English text is the team's).
import 'package:flutter/foundation.dart';

import 'arabic.dart';
import 'dialogue.dart';
import 'engine.dart';

final ValueNotifier<String> lang = ValueNotifier<String>('ar');
bool get isAr => lang.value == 'ar';
void toggleLang() => lang.value = isAr ? 'en' : 'ar';

/// Dark (default) or light. Screens rebuild when either the language or the theme changes.
final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);
void toggleTheme() => darkMode.value = !darkMode.value;
final Listenable lookChanged = Listenable.merge([lang, darkMode]);

String tr(String ar, String en) => isAr ? ar : en;

const _egDays = {1: 'يوم', 2: 'يومين', 3: 'تلات أيام', 4: 'أربع أيام', 5: 'خمس أيام', 6: 'ست أيام', 7: 'سبع أيام', 8: 'تمان أيام', 9: 'تسع أيام', 10: 'عشر أيام',
  11: 'حداشر يوم', 12: 'اتناشر يوم', 13: 'تلتاشر يوم', 14: 'أربعتاشر يوم', 15: 'خمستاشر يوم', 16: 'ستاشر يوم', 17: 'سبعتاشر يوم', 18: 'تمنتاشر يوم', 19: 'تسعتاشر يوم', 20: 'عشرين يوم'};

/// The day phrases, longest first (so "عشرين يوم" is found before "يوم").
final List<String> egDayPhrases = (_egDays.values.toSet().toList()..sort((a, b) => b.length.compareTo(a.length)));

/// A count of days as Egyptians say it in a sentence ("ست أيام"), for 1 to 20; digits with the right noun beyond that. English: "6 days".
String daysN(int n) {
  if (!isAr) return n == 1 ? '1 day' : '$n days';
  return _egDays[n] ?? '${nd(n)} يوم';
}

/// The same as digits with the right Arabic noun, for big numbers on screen ("٦ أيام", "١٣ يوم").
String daysDigitsN(int n) {
  if (!isAr) return n == 1 ? '1 day' : '$n days';
  if (n == 1) return 'يوم';
  if (n == 2) return 'يومين';
  return n <= 10 ? '${nd(n)} أيام' : '${nd(n)} يوم';
}

/// Digits in the current language.
String nd(Object n) => isAr ? arDigits(n) : '$n';
String nn(num v, {int dec = 0}) => isAr ? arNum(v, dec: dec) : v.toStringAsFixed(dec);

final Map<String, String> enSite = {
  'kafr_el_sheikh': 'Kafr El-Sheikh',
  'damietta': 'Damietta',
  'beheira': 'Beheira',
  'gharbia': 'Gharbia (Tanta)',
  'menoufia': 'Menoufia',
  'sharqia': 'Sharqia',
  'dakahlia': 'Dakahlia (east)',
};
const enCrop = {'rice': 'Rice', 'maize': 'Maize', 'cotton': 'Cotton', 'wheat': 'Wheat'};
const enMonthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// The extra NASA cells (data points that are not a named place) get their names from the exported meta.json.
void registerSiteNames(EngineData d) {
  for (final k in d.siteKeys) {
    final m = d.meta['sites'][k] as Map<String, dynamic>;
    if (m['kind'] == 'cell') {
      arSite[k] = (m['name_ar'] as String?) ?? k;
      enSite[k] = m['name_en'] as String;
    }
  }
}

String siteN(String k) => isAr ? (arSite[k] ?? k) : (enSite[k] ?? k);
String cropN(String k) => isAr ? (arCrop[k] ?? k) : (enCrop[k] ?? k);
String monthN(int m) => isAr ? arMonth[m - 1] : enMonthNames[m - 1];

/// "11-15" -> "١٥ نوفمبر" / "15 November"
String dateN(String mmdd) {
  if (isAr) return arDate(mmdd);
  final p = mmdd.split('-');
  return '${int.parse(p[1])} ${enMonthNames[int.parse(p[0]) - 1]}';
}

/// Engine harvest text "13 Oct" in the current language.
String harvestN(String s) {
  if (isAr) return arHarvest(s);
  final p = s.split(' ');
  const short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final i = short.indexOf(p.length > 1 ? p[1] : '');
  return i < 0 ? s : '${int.parse(p[0])} ${enMonthNames[i]}';
}

String saltN(String status) => isAr ? (arSalt[status] ?? status) : const {'fine': 'Suitable', 'reduced': 'Lower yield', 'not advised': 'Not suitable'}[status]!;

/// Label of an answer button in the current language (the Arabic label comes from the dialogue; English is made from the value).
String choiceLabel(Choice c, Step step) {
  if (isAr) return c.label;
  if (c.en != null) return c.en!;
  switch (step) {
    case Step.site:
      return enSite[c.value] ?? c.label;
    case Step.crop:
      return enCrop[c.value] ?? c.label;
    case Step.summerWhen:
    case Step.wheatWhen:
      return RegExp(r'^\d\d-\d\d$').hasMatch(c.value) ? dateN(c.value) : c.label;
    case Step.interval:
      return c.value == 'skip' ? "I don't know" : 'Every ${c.value} days';
    case Step.salt:
      return const {'none': 'No signs', 'patches': 'Salty patches', 'crust': 'White crust', 'skip': "I don't know"}[c.value] ?? c.label;
    case Step.goal:
    case Step.planCrop:
    case Step.planWhen:
      return c.label;
    case Step.done:
      return c.value == 'restart' ? 'Start again' : 'Read it again';
  }
}

String msgText(BotMessage m) => isAr ? m.ar : (m.en ?? m.ar);

// ---- result texts ----
const _noticeEn = 'These numbers support your experience and do not replace it or your agricultural adviser. Ask the adviser before changing your rotation.';
const _sourcesEn = 'Numbers: NASA POWER weather and FAO tables. Salt: what you told me.';
const _notModelledEn = 'Not counted: nitrogen and soil fertility, pests and disease, prices and income, labour and machinery, rice ponding and percolation.';

String noticeN() => isAr ? arNotice : _noticeEn;
String sourcesN() => isAr ? arSources : _sourcesEn;
String notModelledN() => isAr ? arNotModelled : _notModelledEn;

String? caveatN(Comparison c) {
  if (isAr) return caveatAr(c);
  if (c.caveat == null) return null;
  if (c.caveatKind == 'sea') return 'Warning: weather data here is unreliable because the area is mostly sea. Do not rely on the heat numbers.';
  if (c.caveatKind == 'desert_edge') return 'Note: this NASA cell is mostly desert plateau. Farmland along the Nile is usually greener and cooler at night than the cell suggests, so treat the numbers as rough.';
  return 'Note: the NASA temperatures for this area are the same as for ${enSite[c.sharesCellWith] ?? ''}, so the heat results will be the same.';
}

String warningN(RotationRow r) {
  final crop = cropN(r.input.crop);
  if (isAr) return warningAr(r, '');
  if (r.gapDays < 0) return 'Warning: wheat would be sown about ${-r.gapDays} days before the $crop finishes. Check the dates.';
  return 'Warning: only ${r.gapDays} days between the $crop harvest and sowing the wheat.';
}

String ratioN(double ratio) {
  if (isAr) return arRatio(ratio);
  if (ratio == 1.0) return 'the same as your current rotation';
  final pct = ((ratio - 1).abs() * 100).round();
  if (pct == 0) return 'about the same as your current rotation';
  return ratio < 1 ? '$pct% less than your current rotation' : '$pct% more than your current rotation';
}

String heatPhraseEn(RotationRow r) {
  final e = r.extra['32']!;
  final base = 'Hot days during grain filling: about ${r.heatMedian.round()}, for comparing sowing dates, not an exact figure';
  if (r.input.wheatSowing == '11-15') return '$base, and this is the usual date';
  if (e == 0) return base;
  return e > 0 ? '$base, which is $e more than sowing in mid-November' : '$base, which is ${-e} fewer than sowing in mid-November';
}

/// What Eyad reads aloud for a result, in the current language.
String spokenN(Comparison c) {
  if (isAr) return spokenSummary(c);
  final b = StringBuffer('Comparison for ${enSite[c.site]}. ');
  final cv = caveatN(c);
  if (cv != null) b.write('$cv ');
  for (final r in c.rows) {
    b.write('${r.isExisting ? 'Your current rotation' : 'Alternative'}: ${enCrop[r.input.crop]} then wheat sown ${dateN(r.input.wheatSowing)}. ');
    b.write('${heatPhraseEn(r)}. ');
    b.write('${enCrop[r.input.crop]} water need is ${ratioN(r.ratio)}. ');
    if (r.saltSummer != null) b.write('Salt: ${enCrop[r.input.crop]} is ${saltN(r.saltSummer!.status).toLowerCase()}, and wheat is ${saltN(r.saltWheat!.status).toLowerCase()}. ');
    if (r.warnings.isNotEmpty) b.write('${warningN(r)} ');
  }
  if (c.intervalDays != null && c.rows.first.turnMm != null) {
    b.write('With watering every ${c.intervalDays} days, each turn must deliver at least ${c.rows.first.turnMm} millimetres in peak days. That is crop use only, without losses. ');
  }
  if (c.rows.any((r) => r.riceFloor)) b.write('Rice needs more water than the figure, because flooding the field and seepage are not counted. ');
  if (c.saltBasisAssumed) b.write('The salt result is an estimate from the signs you described. Please test the soil. ');
  b.write(_noticeEn);
  return b.toString();
}

/// What Eyad reads aloud for any message.
String spokenForMessage(BotMessage m) => m.result != null ? spokenN(m.result!) : msgText(m);
