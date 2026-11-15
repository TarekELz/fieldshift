// Scripted, deterministic dialogue: asks six short questions, understands typed or spoken answers,
// then calls the engine. It never invents numbers: every figure in a reply comes from engine.dart.
// (An optional AI mode can replace the understanding step later; the engine call stays the same.)
//
// Arabic text is a DRAFT for Tarek's review (docs/tasks.md, task 2).
import 'arabic.dart';
import 'advice.dart';
import 'engine.dart';
import 'goals.dart';
import 'i18n.dart';

String normalizeAr(String s) {
  var t = s.toLowerCase();
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(arabicIndic[i], '$i');
  }
  t = t.replaceAll(RegExp('[ً-ْـ]'), ''); // diacritics, tatweel
  t = t.replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class Choice {
  const Choice(this.label, this.value, {this.en});
  final String label, value;
  final String? en; // English label, when it cannot be made from the value
}

class BotMessage {
  BotMessage(this.ar, {this.en, this.choices = const [], this.result, this.goalResult, this.spoken, this.showMap = false, this.retry = false, this.note = false});
  final String ar;
  final String? en;
  final List<Choice> choices;
  final Comparison? result;
  final Object? goalResult; // a MoneyResult or a PlanResult (goals.dart)
  final String? spoken; // what to read aloud (defaults to ar)
  final bool showMap; // show the map picker under this message
  final bool retry; // the assistant did not understand
  final bool note; // an information line shown under the next question (for example which NASA point is used)
}

enum Step { site, goal, planCrop, planWhen, crop, summerWhen, wheatWhen, interval, salt, done }

const _monthKeys = ['يناير', 'فبراير', 'مارس', 'ابريل', 'مايو', 'يونيو', 'يوليو', 'اغسطس', 'سبتمبر', 'اكتوبر', 'نوفمبر', 'ديسمبر'];
const _defaultSummer = {'rice': '05-15', 'maize': '05-01', 'cotton': '04-01'};
const _altWheat = '11-15'; // recommended date; used for the alternatives and labelled as an assumption

String? parseSite(String n) {
  const m = {
    'kafr_el_sheikh': ['كفر', 'الشيخ', 'kafr'],
    'damietta': ['دمياط', 'damietta'],
    'beheira': ['بحير', 'beheira'],
    'gharbia': ['غربي', 'طنطا', 'gharbia', 'tanta'],
    'menoufia': ['منوفي', 'شبين', 'menoufia'],
    'sharqia': ['شرقي', 'زقازيق', 'sharqia'],
  };
  for (final e in m.entries) {
    if (e.value.any(n.contains)) return e.key;
  }
  return null;
}

String? parseCrop(String n) {
  if (n.contains('رز') || n.contains('ارز') || n.contains('rice')) return 'rice';
  if (n.contains('ذره') || n.contains('دره') || n.contains('شامي') || n.contains('maize') || n.contains('corn')) return 'maize';
  if (n.contains('قطن') || n.contains('cotton')) return 'cotton';
  return null;
}

/// "MM-DD" snapped to the nearest date the tables hold, or null when no month is understood or it is out of range.
String? parseWhen(String n, List<String> allowed) {
  int? month;
  for (var i = 0; i < 12; i++) {
    if (n.contains(_monthKeys[i])) month = i + 1;
  }
  const enM = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  for (var i = 0; i < 12; i++) {
    if (RegExp(enM[i] == 'may' ? r'\bmay\b' : r'\b' + enM[i]).hasMatch(n)) month = i + 1;
  }
  int? enDay;
  if (RegExp(r'\b(early|start|begin|first)').hasMatch(n)) {
    enDay = 1;
  } else if (RegExp(r'\b(mid|middle|half)').hasMatch(n)) {
    enDay = 15;
  } else if (RegExp(r'\b(late|end)').hasMatch(n)) {
    enDay = 25;
  }
  final num = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\b').allMatches(n).map((m) => int.parse(m.group(1)!)).toList();
  int? day = enDay;
  if (n.contains('اول') || n.contains('بدري') || n.contains('بدايه') || n.contains('بداية')) {
    day = 1;
  } else if (n.contains('نص') || n.contains('منتصف') || n.contains('وسط')) {
    day = 15;
  } else if (n.contains('اخر') || n.contains('نهايه')) {
    day = 25;
  }
  if (month == null && num.length >= 2 && num[1] >= 1 && num[1] <= 12 && num[0] >= 1 && num[0] <= 31) {
    day = num[0]; // "15 11" or "15/11"
    month = num[1];
  } else if (month != null && day == null && num.isNotEmpty && num.first >= 1 && num.first <= 31) {
    day = num.first;
  }
  if (month == null) return null;
  day ??= 15;
  final inMonth = allowed.where((a) => int.parse(a.split('-')[0]) == month).toList();
  if (inMonth.isEmpty) return null;
  inMonth.sort((a, b) => (int.parse(a.split('-')[1]) - day!).abs().compareTo((int.parse(b.split('-')[1]) - day).abs()));
  return inMonth.first;
}

int? parseDays(String n) {
  if (n.contains('two weeks') || n.contains('fortnight')) return 14;
  if (n.contains('three weeks')) return 21;
  final wk = RegExp(r'\b(\d{1,2})\s*weeks?\b').firstMatch(n);
  if (wk != null) return int.parse(wk.group(1)!) * 7;
  if (n.contains('اسبوعين')) return 14;
  if (n.contains('ثلاث اسابيع') || n.contains('تلات اسابيع')) return 21;
  final m = RegExp(r'\b(\d{1,2})\b').firstMatch(n);
  if (m != null) {
    final v = int.parse(m.group(1)!);
    return v >= 1 && v <= 60 ? v : null;
  }
  if (n.contains('اسبوع') || n.contains('week')) return 7;
  if (n.contains('عشره') || n.contains('عشر ايام')) return 10;
  if (n.contains('خمستاشر') || n.contains('خمسه عشر')) return 15;
  return null;
}

bool _unknown(String n) => n.contains("don't know") || n.contains('dont know') || n.contains('not sure') || n.contains('مش عارف') || n.contains('معرفش') || n.contains('مش متاكد') || n.contains('مش عارفه');

class Salt {
  Salt({this.signs, this.ece, this.skipped = false});
  final String? signs;
  final double? ece;
  final bool skipped;
}

Salt? parseSalt(String n) {
  if (_unknown(n)) return Salt(skipped: true);
  if (RegExp(r'\b(no signs?|no salt|clean|nothing)\b').hasMatch(n) || RegExp(r'\bno\b.*\b(crust|white|patch\w*)').hasMatch(n)) return Salt(signs: 'none');
  if (n.contains('white')) return Salt(signs: 'crust');
  final m = RegExp(r'\b(\d{1,2}(?:[.,]\d)?)\b').firstMatch(n);
  if (m != null) {
    final v = double.parse(m.group(1)!.replaceAll(',', '.'));
    if (v >= 0 && v <= 30) return Salt(ece: v);
  }
  if (n.contains('مفيش') || n.contains('مافيش') || n.contains('نضيف') || n.contains('عادي') || n.contains('none')) return Salt(signs: 'none');
  if (n.contains('قشر') || n.contains('بيضا') || n.contains('crust')) return Salt(signs: 'crust');
  if (n.contains('بقع') || n.contains('patch')) return Salt(signs: 'patches');
  return null;
}

class Dialogue {
  Dialogue(this.data, {this.askGoal = true}) {
    goal = askGoal ? null : 'improve';
  }
  final EngineData data;
  /// When false the goal question is skipped and the farmer is taken to the comparison of his own rotation (the original flow).
  final bool askGoal;
  late final CropBook book = CropBook(data);
  Step step = Step.site;
  String? site, crop, summerSowing, wheatSowing;
  String? goal; // money | plan | improve
  String? planCrop, planWhen;
  BotMessage? lastGoal;
  int? interval;
  Salt? salt;
  Comparison? last;
  bool intervalAnswered = false; // the canal-water question was answered, or skipped

  void reset() {
    step = Step.site;
    goal = askGoal ? null : 'improve';
    planCrop = planWhen = null;
    lastGoal = null;
    site = crop = summerSowing = wheatSowing = null;
    interval = null;
    salt = null;
    last = null;
    intervalAnswered = false;
  }

  BotMessage opening() => prompt();

  List<Choice> _wheatChoices() => [
        for (final d in ['11-01', '11-15', '12-01', '12-15', '01-01', '01-10']) Choice(arDate(d), d),
      ];

  BotMessage prompt() {
    switch (step) {
      case Step.site:
        return BotMessage(
          'احكيلي عن أرضك بصوتك: فين هي، وبتزرع إيه، وإمتى؟ أو اضغط على مكانها في الخريطة.',
          en: 'Tell me about your field in your own words: where it is, what you grow and when. Or tap it on the map.',
          choices: [for (final k in data.namedSiteKeys) Choice(arSite[k]!, k)],
          showMap: true,
        );
      case Step.goal:
        return BotMessage('إيه اللي عايزه دلوقتي؟', en: 'What do you want to do?', choices: const [
          Choice('أكسب أكتر', 'money', en: 'Earn more'),
          Choice('أزرع محصول معين في ميعاد معين', 'plan', en: 'Grow a certain crop at a certain time'),
          Choice('أحسّن اللي بزرعه دلوقتي', 'improve', en: 'Improve what I grow now'),
        ]);
      case Step.planCrop:
        return BotMessage('عايز تزرع إيه؟', en: 'What do you want to grow?', choices: [for (final c in book.all) Choice(c.ar, c.key, en: c.en)]);
      case Step.planWhen:
        return BotMessage('وإمتى تقريباً؟ قول الشهر، وأول ولا نص ولا آخر الشهر.', en: 'When, roughly? Say the month and early, middle or late.', choices: [
          for (var m = 1; m <= 12; m++) Choice(arMonth[m - 1], '${m.toString().padLeft(2, '0')}-15', en: enMonthNames[m - 1]),
        ]);
      case Step.crop:
        return BotMessage('إيه المحصول الصيفي اللي بتزرعه دلوقتي؟ رز ولا ذرة ولا قطن؟', en: 'Which summer crop do you grow now: rice, maize or cotton?',
            choices: [for (final c in ['rice', 'maize', 'cotton']) Choice(arCrop[c]!, c)]);
      case Step.summerWhen:
        final ds = data.summerDates(site!, crop!);
        return BotMessage('بتزرع ${arCrop[crop]} إمتى تقريباً؟ قول الشهر، وأول ولا نص ولا آخر الشهر.',
            en: 'When do you sow the summer crop? Say the month and early, middle or late.',
            choices: [for (final d in ds.where((d) => d.endsWith('-01') || d.endsWith('-15'))) Choice(arDate(d), d)]);
      case Step.wheatWhen:
        return BotMessage('والقمح بعد كده بتزرعه إمتى؟ (نوفمبر لحد يناير)', en: 'When do you sow the wheat that follows? (November to January)', choices: _wheatChoices());
      case Step.interval:
        return BotMessage('المية بتيجي أرضك كل كام يوم تقريباً؟', en: 'How many days between canal turns at your field?',
            choices: [for (final d in [7, 10, 14, 15, 21]) Choice('كل ${arDigits(d)} يوم', '$d'), const Choice('مش عارف', 'skip')]);
      case Step.salt:
        return BotMessage('في التربة قشرة بيضاء أو بقع ملح؟ لو عملت تحليل قول الرقم (EC).',
            en: 'Any white crust or salty patches on the soil? If you had a soil test, say the number (ECe).',
            choices: const [Choice('مفيش علامات', 'none'), Choice('في بقع', 'patches'), Choice('قشرة بيضاء', 'crust'), Choice('مش عارف', 'skip')]);
      case Step.done:
        return BotMessage('تحب نبدأ من جديد؟', en: 'Start again?', choices: const [Choice('ابدأ من جديد', 'restart'), Choice('اقرأ النتيجة تاني', 'repeat')]);
    }
  }

  BotMessage _retry(String ar, String en) => BotMessage(ar, en: en, choices: prompt().choices, retry: true, showMap: step == Step.site);

  /// Handle one answer (typed, spoken or a tapped choice). Returns the bot messages to show, in order.
  List<BotMessage> handle(String raw) {
    final n = normalizeAr(raw);
    if (n == 'restart' || n.contains('ابدا من جديد') || n.contains('من الاول')) {
      reset();
      return [prompt()];
    }
    if (n == 'repeat' && lastGoal != null) return [lastGoal!];
    if (n == 'repeat' && last != null) return [resultMessage(last!)];
    if (step != Step.done && (goal == null || goal == 'improve')) {
      final free = _absorb(n); // a sentence that gives several answers at once
      if (free != null) return free;
    }
    switch (step) {
      case Step.site:
        if (n.contains('منصور') || n.contains('mansoura')) {
          // Mansoura city: it sits in the same NASA cell as Gharbia, so it gets Gharbia's data (stated to the farmer)
          final dk = data.governorates.cast<Map<String, dynamic>>().firstWhere((g) => g['id'] == 'Dakahlia');
          return _useGovernorate(dk, 31.04, 31.38);
        }
        final s = parseSite(n);
        if (s == null) {
          final g = _governorateByName(n);
          if (g != null) {
            final lbl = g['label'] as List;
            return _useGovernorate(g, (lbl[1] as num).toDouble(), (lbl[0] as num).toDouble());
          }
          final a = _areaByName(n);
          if (a != null) return _outside(a['ar'] as String, areaEn: a['id'] as String, area: true);
          return [_retry('مفهمتش. قول اسم المحافظة تاني من فضلك.', 'I did not understand. Please say the governorate again.')];
        }
        site = s;
        step = _afterSite();
        return [BotMessage('تمام، ${arSite[s]}.', en: data.siteName(s)), prompt()];
      case Step.goal:
        final g = parseGoal(n);
        if (g == 'unmeasurable') {
          return [_retry('أنا بحسب الدخل من متوسط مصر بس، مش بوعد بربح ولا بمحصول. اختار: أكسب أكتر، ولا محصول معين في ميعاد معين، ولا أحسّن اللي بزرعه؟', 'I estimate income from Egypt-wide averages only and never promise profit or yield. Choose: earn more, a certain crop at a certain time, or improve what I grow now.')];
        }
        if (g == null) return [_retry('مفهمتش. عايز تكسب أكتر، ولا تزرع محصول معين في ميعاد معين، ولا تحسّن اللي بتزرعه؟', 'I did not understand. Do you want to earn more, grow a certain crop at a certain time, or improve what you grow now?')];
        goal = g;
        step = g == 'money' ? Step.salt : (g == 'plan' ? Step.planCrop : Step.crop);
        return [prompt()];
      case Step.planCrop:
        final pc = book.parse(n);
        if (pc == null) return [_retry('مفهمتش. قول اسم المحصول، زي القمح أو البصل أو العنب.', 'I did not understand. Say the crop, for example wheat, onion or grapes.')];
        planCrop = pc.key;
        step = Step.planWhen;
        return [BotMessage('تمام، ${pc.ar}.', en: pc.en), prompt()];
      case Step.planWhen:
        final grid = [for (var m = 1; m <= 12; m++) for (final d in ['01', '15']) '${m.toString().padLeft(2, '0')}-$d'];
        final pw = RegExp(r'^\d\d-\d\d$').hasMatch(n) ? n : parseWhen(n, grid);
        if (pw == null) return [_retry('مفهمتش الميعاد. قول الشهر، وأول ولا نص ولا آخر الشهر.', 'I did not understand the date. Say the month and early, middle or late.')];
        planWhen = pw;
        step = Step.salt;
        return [BotMessage('تمام، ${arDate(pw)}.'), prompt()];
      case Step.crop:
        final c = parseCrop(n);
        if (c == null) return [_retry('مفهمتش. رز ولا ذرة ولا قطن؟', 'Rice, maize or cotton?')];
        crop = c;
        step = Step.summerWhen;
        return [prompt()];
      case Step.summerWhen:
        final summerAllowed = data.summerDates(site!, crop!);
        final d = summerAllowed.contains(n) ? n : (parseWhen(n, summerAllowed) ?? (RegExp(r'^\d\d-\d\d$').hasMatch(n) ? n : null));
        if (d == null || data.water[site][crop][d] == null) {
          return [_retry('مفهمتش الميعاد، أو برا الجدول بتاعي. قول الشهر وأول ولا نص ولا آخر الشهر.', 'I did not understand the date, or it is outside my table.')];
        }
        summerSowing = d;
        step = Step.wheatWhen;
        return [BotMessage('تمام، ${arDate(d)}.'), prompt()];
      case Step.wheatWhen:
        final wheatAllowed = data.wheatDates(site!);
        final d = wheatAllowed.contains(n) ? n : (parseWhen(n, wheatAllowed) ?? (RegExp(r'^\d\d-\d\d$').hasMatch(n) && data.heat[site][n] != null ? n : null));
        if (d == null) return [_retry('مفهمتش. قول شهر من نوفمبر لحد يناير، وأول ولا نص ولا آخر الشهر.', 'I did not understand. Say a month from November to January.')];
        wheatSowing = d;
        step = Step.interval;
        return [BotMessage('تمام، ${arDate(d)}.'), prompt()];
      case Step.interval:
        if (n == 'skip' || _unknown(n)) {
          interval = null;
        } else {
          final v = parseDays(n);
          if (v == null) return [_retry('مفهمتش. قول عدد الأيام، مثلاً ١٠.', 'I did not understand. Say a number of days, for example 10.')];
          interval = v;
        }
        intervalAnswered = true;
        step = Step.salt;
        return [prompt()];
      case Step.salt:
        final s = n == 'skip' ? Salt(skipped: true) : parseSalt(n);
        if (s == null) return [_retry('مفهمتش. مفيش علامات، ولا بقع، ولا قشرة بيضاء؟', 'None, patches or white crust?')];
        salt = s;
        step = Step.done;
        if (goal == 'money' || goal == 'plan') return [goalResultMessage()];
        last = run();
        return [resultMessage(last!)];
      case Step.done:
        return [prompt()];
    }
  }

  List<BotMessage> _outside(String? govAr, {String? areaEn, bool area = false}) => [
        BotMessage(
          '${govAr != null ? (area ? 'منطقة $govAr' : 'محافظة $govAr') : 'المكان ده'} برا دلتا النيل. أنا دلوقتي بشتغل على الدلتا بس: الإسكندرية، البحيرة، كفر الشيخ، الغربية، الدقهلية، دمياط، المنوفية، القليوبية، الشرقية، وبورسعيد. اضغط على واحدة منهم.',
          en: '${areaEn != null ? '$areaEn is' : 'That place is'} outside the Nile Delta, which is all I cover for now.',
          choices: prompt().choices,
          retry: true,
          showMap: true,
        ),
      ];

  /// A Delta governorate was chosen (by tapping the map or by name). It uses its own NASA data point if it has
  /// one, otherwise the nearest one, and says which.
  List<BotMessage> _useGovernorate(Map<String, dynamic> g, double lat, double lon) {
    final ar = g['ar'] as String;
    if (g['delta'] != true) return _outside(ar);
    final r = _resolveGov(g, lat, lon)!;
    site = r.key;
    step = Step.crop;
    return [r.note, prompt()];
  }

  /// Which NASA data point a Delta governorate place uses, and the sentence that says so. Changes nothing.
  ({String key, BotMessage note})? _resolveGov(Map<String, dynamic> g, double lat, double lon) {
    final ar = g['ar'] as String;
    if (g['delta'] != true) return null;
    final own = g['site'] as String?;
    final cellSite = siteInSameCell(data, lat, lon, prefer: own); // same NASA cell: identical weather, whatever the distance
    final key = cellSite ?? own ?? nearestSite(data, lat, lon).key;
    final p = data.siteLatLon(key);
    final km = haversineKm(lat, lon, p.lat, p.lon);
    final far = km > 60;
    final approx = far ? ' المسافة بعيدة شوية، فالأرقام تقريبية.' : '';
    final text = (cellSite != null && cellSite != own)
        ? 'تمام. محافظة $ar. مكانك في نفس خلية بيانات ناسا (حوالي ٥٠ كم) بتاعة ${arSite[key]}، فهستخدم بياناتها.'
        : own != null
        ? 'تمام. محافظة $ar، وهستخدم بيانات ناسا لنقطة ${arSite[key]}.$approx'
        : 'تمام. محافظة $ar مفيهاش نقطة بيانات خاصة بيها، فهستخدم أقرب نقطة من ناسا: ${arSite[key]} (حوالي ${arDigits(km.round())} كم).$approx';
    final en = (cellSite != null && cellSite != own)
        ? 'Governorate ${g['id']}: your spot is in the same NASA data cell (about 50 km) as ${data.siteName(key)}, so I use its data.'
        : own != null
        ? 'Governorate ${g['id']}: using the NASA data point ${data.siteName(key)}${far ? '; far from where you tapped, so numbers are approximate' : ''}.'
        : 'Governorate ${g['id']} has no data point of its own: using the nearest, ${data.siteName(key)}, about ${km.round()} km away.';
    return (key: key, note: BotMessage(text, en: en, note: true));
  }

  /// The farmer tapped the map.
  List<BotMessage> handleLocation(double lat, double lon) {
    if (step != Step.site) {
      return [BotMessage('عشان تغير المكان، اضغط على "ابدأ من جديد".', en: 'To change the place, tap Start again.')];
    }
    final a = areaAt(data, lat, lon);
    if (a != null) return _outside(a['ar'] as String, areaEn: a['id'] as String, area: true);
    final g = governorateAt(data, lat, lon);
    if (g == null) return _outside(null);
    return _useGovernorate(g, lat, lon);
  }

  static const _cropWords = {
    'rice': ['رز', 'ارز', 'rice'],
    'maize': ['ذره', 'دره', 'شامي', 'maize', 'corn'],
    'cotton': ['قطن', 'cotton'],
    'wheat': ['قمح', 'wheat'],
  };
  static const _enCropNames = {'rice': 'Rice', 'maize': 'Maize', 'cotton': 'Cotton', 'wheat': 'Wheat'};
  static const _enMonthsFull = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static String _enDate(String mmdd) => '${int.parse(mmdd.split('-')[1])} ${_enMonthsFull[int.parse(mmdd.split('-')[0]) - 1]}';

  int? _intervalIn(String n) {
    final m = RegExp(r'(?:كل|every|each)\s*(\d{1,2})\s*(?:يوم|ايام|days?)').firstMatch(n);
    if (m != null) {
      final v = int.parse(m.group(1)!);
      return v >= 1 && v <= 60 ? v : null;
    }
    if (RegExp(r'(?:كل|every|each)\s*(?:اسبوعين|two weeks|2 weeks)').hasMatch(n)) return 14;
    if (RegExp(r'(?:كل|every|each)\s*(?:ثلاث|تلات|three|3)\s*(?:اسابيع|weeks)').hasMatch(n)) return 21;
    if (RegExp(r'(?:كل|every|each)\s*(?:اسبوع|week)').hasMatch(n)) return 7;
    return null;
  }

  Salt? _saltIn(String n) {
    if (!RegExp(r'ملح|قشر|بقع|بيضا|salt|crust|patch|no signs').hasMatch(n)) return null;
    final s = parseSalt(n.replaceAll(RegExp(r'\d+'), ' ')); // signs only: numbers in a sentence are dates and days
    return (s == null || s.skipped || s.ece != null) ? null : s;
  }

  Step _afterSite() => goal == null ? Step.goal : (goal == 'money' ? Step.salt : (goal == 'plan' ? Step.planCrop : Step.crop));

  Step _nextMissing() {
    if (site == null) return Step.site;
    if (goal == null) return Step.goal;
    if (goal == 'money') return salt == null ? Step.salt : Step.done;
    if (goal == 'plan') {
      if (planCrop == null) return Step.planCrop;
      if (planWhen == null) return Step.planWhen;
      return salt == null ? Step.salt : Step.done;
    }
    if (crop == null) return Step.crop;
    if (summerSowing == null) return Step.summerWhen;
    if (wheatSowing == null) return Step.wheatWhen;
    if (!intervalAnswered) return Step.interval;
    if (salt == null) return Step.salt;
    return Step.done;
  }

  /// Free speech: one sentence that gives several answers ("I am in Gharbia, I grow rice in mid June and wheat in early
  /// December"). Finds every answer it can with the same parsers as the step-by-step questions, keeps them, and asks only for
  /// what is missing. Returns null when fewer than two answers are found, so a single answer goes through the normal step logic.
  /// Nothing here calculates anything: the numbers still come only from the engines.
  List<BotMessage>? _absorb(String n) {
    if (_areaByName(n) != null) return null;
    String? fSite;
    BotMessage? placeNote;
    if (n.contains('منصور') || n.contains('mansoura')) {
      final dk = data.governorates.cast<Map<String, dynamic>>().firstWhere((g) => g['id'] == 'Dakahlia');
      final r = _resolveGov(dk, 31.04, 31.38);
      if (r != null) {
        fSite = r.key;
        placeNote = r.note;
      }
    } else {
      fSite = parseSite(n);
      if (fSite == null) {
        final g = _governorateByName(n);
        if (g != null) {
          final lbl = g['label'] as List;
          final r = _resolveGov(g, (lbl[1] as num).toDouble(), (lbl[0] as num).toDouble());
          if (r == null) return null; // outside the Delta: the step logic says so
          fSite = r.key;
          placeNote = r.note;
        }
      }
    }
    final fCrop = parseCrop(n);

    // months, each tied to the nearest crop word (summer crop or wheat); with no crop word the season decides
    final hits = <List<int>>[]; // [position, length, month]
    for (var i = 0; i < 12; i++) {
      var from = 0;
      while (true) {
        final k = n.indexOf(_monthKeys[i], from);
        if (k < 0) break;
        hits.add([k, _monthKeys[i].length, i + 1]);
        from = k + 1;
      }
    }
    const enM = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    for (final m in RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b').allMatches(n)) {
      if (m.group(0) == 'maybe') continue;
      hits.add([m.start, m.group(0)!.length, enM.indexOf(m.group(1)!) + 1]);
    }
    final crops = <List<Object>>[]; // [position, key]
    _cropWords.forEach((key, words) {
      for (final w in words) {
        var from = 0;
        while (true) {
          final k = n.indexOf(w, from);
          if (k < 0) break;
          crops.add([k, key]);
          from = k + 1;
        }
      }
    });
    List<int>? sHit, wHit;
    for (final h in hits) {
      String? kind;
      var best = 1 << 30;
      for (final c in crops) {
        final d = ((c[0] as int) - h[0]).abs();
        if (d < best) {
          best = d;
          kind = c[1] == 'wheat' ? 'wheat' : 'summer';
        }
      }
      final m = h[2];
      if (kind == null) {
        kind = (m >= 11 || m <= 2) ? 'wheat' : 'summer';
      } else if (kind == 'summer' && (m >= 11 || m <= 1)) {
        kind = 'wheat';
      } else if (kind == 'wheat' && m >= 3 && m <= 7) {
        kind = 'summer';
      }
      if (kind == 'summer') sHit ??= h;
      if (kind == 'wheat') wHit ??= h;
    }
    final tableSite = fSite ?? site ?? 'gharbia', tableCrop = fCrop ?? crop ?? 'rice';
    // only the words right next to the month ("mid June", "15 June"): a wider window would take the next month's "early"
    String window(List<int> h) => n.substring(h[0] - 9 < 0 ? 0 : h[0] - 9, h[0] + h[1] + 3 > n.length ? n.length : h[0] + h[1] + 3);
    final fSummer = sHit == null ? null : parseWhen(window(sHit), data.summerDates(tableSite, tableCrop));
    final fWheat = wHit == null ? null : parseWhen(window(wHit), data.wheatDates(tableSite));
    final fInt = _intervalIn(n);
    final fSalt = _saltIn(n);
    final found = [fSite, fCrop, fSummer, fWheat, fInt, fSalt].where((e) => e != null).length;
    if (found < 2) return null;

    if (fCrop != null || fSummer != null || fWheat != null) goal ??= 'improve'; // talking about his rotation means he wants it improved
    if (fSite != null) site = fSite;
    if (fCrop != null) crop = fCrop;
    if (fSummer != null) summerSowing = fSummer;
    if (fWheat != null) wheatSowing = fWheat;
    if (fInt != null) {
      interval = fInt;
      intervalAnswered = true;
    }
    if (fSalt != null) salt = fSalt;
    if (site != null && crop != null && summerSowing != null && data.water[site][crop][summerSowing] == null) summerSowing = null; // asked again

    const arSaltWords = {'none': 'مفيش علامات', 'patches': 'بقع', 'crust': 'قشرة بيضاء'};
    const enSaltWords = {'none': 'no signs', 'patches': 'salty patches', 'crust': 'white crust'};
    final ar = <String>[], en = <String>[];
    if (site != null) {
      ar.add(arSite[site]!);
      en.add(data.siteName(site!));
    }
    if (crop != null) {
      ar.add('${arCrop[crop]}${summerSowing != null ? ' ${arDate(summerSowing!)}' : ''}');
      en.add('${_enCropNames[crop]}${summerSowing != null ? ' ${_enDate(summerSowing!)}' : ''}');
    }
    if (wheatSowing != null) {
      ar.add('قمح ${arDate(wheatSowing!)}');
      en.add('Wheat ${_enDate(wheatSowing!)}');
    }
    if (interval != null) {
      ar.add('ري كل ${arDigits(interval!)} يوم');
      en.add('water every $interval days');
    }
    if (salt?.signs != null) {
      ar.add('ملح: ${arSaltWords[salt!.signs]}');
      en.add('salt: ${enSaltWords[salt!.signs]}');
    }
    final head = BotMessage('فهمت: ${ar.join(' · ')}.${placeNote != null ? ' ${placeNote.ar}' : ''}', en: 'Got it: ${en.join(' · ')}.${placeNote?.en != null ? ' ${placeNote!.en}' : ''}', note: true);
    step = _nextMissing();
    if (step == Step.done) {
      last = run();
      return [head, resultMessage(last!)];
    }
    return [head, prompt()];
  }

  /// Halayeb or Shalateen named by voice or typing.
  Map<String, dynamic>? _areaByName(String n) {
    for (final a in data.areas) {
      for (final k in (a['aliases'] as List).cast<String>()) {
        if (n.contains(normalizeAr(k))) return a as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _governorateByName(String n) {
    for (final g in data.governorates) {
      final core = normalizeAr(g['ar'] as String).replaceFirst(RegExp('^ال'), '');
      if (core.length >= 4 && n.contains(core)) return g as Map<String, dynamic>;
      final id = (g['id'] as String).toLowerCase();
      if (id.length >= 4 && n.contains(id)) return g as Map<String, dynamic>;
    }
    return null;
  }

  /// The goal the farmer named, 'unmeasurable' when he asks for profit or yield promises, or null.
  String? parseGoal(String n) {
    if (RegExp(r'ضمان|اضمن|اكيد|guarantee|promise').hasMatch(n)) return 'unmeasurable';
    if (RegExp(r'فلوس|ربح|مكسب|اكسب|اكتر دخل|دخل|ايراد|money|profit|income|earn|revenue').hasMatch(n)) return 'money';
    if (RegExp(r'احسن|حسن|دورتي|دورتك|الحالي|اللي بزرع|improve|current|my rotation|better').hasMatch(n)) return 'improve';
    if (RegExp(r'معين|ميعاد|عايز ازرع|اريد ان ازرع|ازرع|خطه|plan|specific|certain|grow').hasMatch(n)) return 'plan';
    return null;
  }

  BotMessage goalResultMessage() {
    final e = book.eceOf(salt);
    final assumed = salt?.signs != null;
    final name = arSite[site] ?? site!;
    final enName = data.siteName(site!);
    final Object res;
    if (goal == 'money') {
      res = MoneyResult(site!, siteName(name, enName), {for (final g in ['winter', 'summer', 'any', 'orchard']) g: book.rank(g, e)}, e, assumed);
    } else {
      final c = book.info(planCrop!)!;
      final sv = c.season ? seasonVerdict(AdviceData(const {}, data.season), site!, c.key, planWhen!) : SeasonVerdict('cannot judge', null);
      final gr = book.gross(c.key, e);
      final saltStatus = gr.saltKnown ? (gr.saltPct == null ? 'not advised' : saltStatus_(gr.saltPct!)) : null;
      res = PlanResult(site!, siteName(name, enName), c, planWhen!, sv.label, sv.best, saltStatus, gr.saltPct, gr, book.rank(c.group, e), e, assumed);
    }
    lastGoal = BotMessage('دي النتيجة لـ $name:', en: 'The result for $enName', goalResult: res, spoken: goalSpoken(res, book),
        choices: const [Choice('ابدأ من جديد', 'restart'), Choice('اقرأ النتيجة تاني', 'repeat')]);
    return lastGoal!;
  }

  static String saltStatus_(int pct) => pct >= 90 ? 'fine' : (pct >= 75 ? 'reduced' : 'not advised');
  String siteName(String ar, String en) => isAr ? ar : en;

  Comparison run() {
    final seqs = <SequenceInput>[
      SequenceInput(name: 'دورتك الحالية', crop: crop!, summerSowing: summerSowing!, wheatSowing: wheatSowing!),
      for (final c in ['rice', 'maize', 'cotton'].where((c) => c != crop))
        SequenceInput(name: 'بديل: ${arCrop[c]} ثم قمح', crop: c, summerSowing: _defaultSummer[c]!, wheatSowing: _altWheat),
    ];
    final s = salt;
    return compare(data, site!, seqs, ece: s?.ece, signs: s?.signs, intervalDays: interval);
  }

  BotMessage resultMessage(Comparison c) => BotMessage(
        'دي المقارنة لـ ${arSite[c.site]}:',
        en: 'Comparison for ${c.siteName}',
        result: c,
        spoken: spokenSummary(c),
        choices: const [Choice('ابدأ من جديد', 'restart'), Choice('اقرأ النتيجة تاني', 'repeat')],
      );
}

String _heatPhrase(RotationRow r) {
  final e = r.extra['32']!;
  final base = 'أيام الحر وقت امتلاء الحبوب حوالي ${arDigits(r.heatMedian.round())} يوم، للمقارنة بين المواعيد مش رقم مظبوط';
  if (r.input.wheatSowing == '11-15') return '$base، وده الميعاد المعتاد';
  if (e == 0) return base;
  return e > 0 ? '$base، يعني أكتر بـ ${arDigits(e)} يوم من زراعة منتصف نوفمبر' : '$base، يعني أقل بـ ${arDigits(-e)} يوم من زراعة منتصف نوفمبر';
}

String warningAr(RotationRow r, String w) {
  if (r.gapDays < 0) return 'تنبيه: القمح هيتزرع قبل ما ${arCrop[r.input.crop]} يخلص بحوالي ${arDigits(-r.gapDays)} يوم. راجع المواعيد.';
  return 'تنبيه: فاضل ${arDigits(r.gapDays)} يوم بس بين حصاد ${arCrop[r.input.crop]} وزراعة القمح.';
}

/// Arabic note about the weather data of the chosen place, or null. 'sea': the NASA cell is mostly sea, so heat
/// numbers are not trustworthy. 'shared_cell': two governorates fall in one 50 km NASA cell, so they get identical results.
String? caveatAr(Comparison c) {
  if (c.caveat == null) return null;
  if (c.caveatKind == 'sea') return 'تنبيه: بيانات الطقس للمنطقة دي مش دقيقة لأنها قريبة من البحر. ما تعتمدش على أرقام الحر هنا.';
  if (c.caveatKind == 'desert_edge') return 'ملحوظة: خلية بيانات ناسا هنا أغلبها صحرا مرتفعة. الأرض الزراعية على النيل بتبقى أخضر وأبرد بالليل من اللي الخلية بتقول، فاعتبر الأرقام تقريبية.';
  final other = arSite[c.sharesCellWith] ?? '';
  return 'ملحوظة: درجات الحرارة من ناسا للمنطقة دي هي نفسها بتاعة $other، فنتايج الحر هتطلع زي بعض.';
}

String spokenSummary(Comparison c) {
  final b = StringBuffer('المقارنة لمنطقة ${arSite[c.site]}. ');
  final cv = caveatAr(c);
  if (cv != null) b.write('$cv ');
  for (final r in c.rows) {
    b.write('${r.isExisting ? 'دورتك الحالية' : 'البديل'}: ${arCrop[r.input.crop]} وبعده قمح يتزرع ${arDate(r.input.wheatSowing)}. ');
    b.write('${_heatPhrase(r)}. ');
    b.write('${arCrop[r.input.crop]} ${arRatio(r.ratio)} في المية. ');
    if (r.saltSummer != null) {
      b.write('الملوحة: ${arCrop[r.input.crop]} ${arSalt[r.saltSummer!.status]}، والقمح ${arSalt[r.saltWheat!.status]}. ');
    }
    for (final w in r.warnings) {
      b.write('${warningAr(r, w)} ');
    }
  }
  if (c.intervalDays != null && c.rows.first.turnMm != null) {
    b.write('ومع ري كل ${arDigits(c.intervalDays!)} يوم، كل مرة لازم توصل على الأقل ${arDigits(c.rows.first.turnMm!)} مليمتر في أيام الذروة، ده استهلاك المحصول بس من غير فاقد. ');
  }
  if (c.rows.any((r) => r.riceFloor)) b.write('الرز بياخد مية أكتر من الرقم المحسوب، لأن غمر الحقل والتسرب مش محسوبين. ');
  if (c.saltBasisAssumed) b.write('الملوحة تقدير من العلامات اللي شايفها، اعمل تحليل تربة. ');
  b.write(arNotice);
  return b.toString();
}
