// Professional view (decision D21): the same engines and tables as the farmer view, laid open for people who read data (agronomists, extension agents,
// researchers). Place analysis with charts, a regional comparison of all NASA data points (a question a chatbot cannot answer), and the methods and data behind
// every number. Nothing here is new data: it reads the exported tables (heat, water, climate, season, salt, crops) and can copy them as CSV.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine.dart';
import 'goals.dart';
import 'i18n.dart';
import 'ui_kit.dart';

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class ProView extends StatefulWidget {
  const ProView({super.key, this.preloaded});
  final EngineData? preloaded; // tests hand in tables they loaded themselves
  @override
  State<ProView> createState() => _ProViewState();
}

class _ProViewState extends State<ProView> {
  EngineData? d;
  String site = 'gharbia', crop = 'rice', sd = '06-15', wd = '12-01';
  double ece = 4.0;
  int metric = 0;

  @override
  void initState() {
    super.initState();
    if (widget.preloaded != null) {
      d = widget.preloaded;
      registerSiteNames(d!);
      return;
    }
    EngineData.load().then((v) {
      registerSiteNames(v);
      if (mounted) setState(() => d = v);
    });
  }

  List<double> _col(Map<String, dynamic> m, List<String> ks, String f) => [for (final k in ks) (m[k][f] as num).toDouble()];

  void _copy(String what, List<List<String>> rows) {
    Clipboard.setData(ClipboardData(text: rows.map((r) => r.map((c) => c.contains(',') ? '"$c"' : c).join(',')).join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('اتنسخ: $what (CSV)', 'Copied: $what (CSV)')), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final data = d;
    return ListenableBuilder(
      listenable: lookChanged,
      builder: (context, _) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr('عرض المحترفين', 'Professional view')),
            actions: [const LangPill(), const SizedBox(width: 6), const ThemeButton(), const SizedBox(width: 12)],
            bottom: TabBar(tabs: [Tab(text: tr('تحليل مكان', 'Place')), Tab(text: tr('مقارنة المناطق', 'Compare')), Tab(text: tr('الطريقة والبيانات', 'Method'))]),
          ),
          body: data == null ? Center(child: CircularProgressIndicator(color: Fs.accent)) : TabBarView(children: [_place(data), _compare(data), _method()]),
        ),
      ),
    );
  }

  // ---------- controls ----------
  Widget _controls(EngineData d) => SoftCard(
        child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
          _drop<String>(tr('المكان', 'Place'), site, d.siteKeys, (v) => siteN(v), (v) => setState(() {
                site = v;
                if (!d.summerDates(site, crop).contains(sd)) sd = d.summerDates(site, crop).first;
              }), width: 250),
          _drop<String>(tr('المحصول الصيفي', 'Summer crop'), crop, const ['rice', 'maize', 'cotton'], (v) => cropN(v), (v) => setState(() {
                crop = v;
                final ds = d.summerDates(site, crop);
                if (!ds.contains(sd)) sd = ds.contains('05-15') ? '05-15' : ds.first;
              })),
          _drop<String>(tr('زراعته', 'Sown'), sd, d.summerDates(site, crop), (v) => dateN(v), (v) => setState(() => sd = v)),
          _drop<String>(tr('القمح', 'Wheat sown'), wd, d.wheatDates(site), (v) => dateN(v), (v) => setState(() => wd = v)),
          SizedBox(
            width: 220,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('ملوحة التربة ECe', 'Soil salinity ECe')}: ${nn(ece, dec: 1)} dS/m', style: TextStyle(fontSize: 12, color: Fs.dim)),
              Slider(value: ece, min: 0, max: 16, divisions: 32, onChanged: (v) => setState(() => ece = v)),
            ]),
          ),
        ]),
      );

  Widget _drop<T>(String label, T value, List<T> items, String Function(T) name, void Function(T) on, {double width = 130}) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Fs.dim)),
          DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              items: [for (final i in items) DropdownMenuItem(value: i, child: Text(name(i), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))],
              onChanged: (v) => on(v as T)),
        ]),
      );

  Widget _card(String title, String how, Widget chart, {List<Widget> notes = const [], VoidCallback? copy}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              if (copy != null) IconButton(onPressed: copy, icon: Icon(Icons.copy_rounded, size: 20, color: Fs.accent), tooltip: 'CSV'),
            ]),
            Text(how, style: TextStyle(fontSize: 12.5, color: Fs.dim, height: 1.4)),
            const SizedBox(height: 10),
            Directionality(textDirection: TextDirection.ltr, child: SizedBox(height: 170, width: double.infinity, child: chart)),
            for (final n in notes) Padding(padding: const EdgeInsets.only(top: 6), child: n),
          ]),
        ),
      );

  Widget _note(String t) => Text(t, style: TextStyle(fontSize: 13, height: 1.45, color: Fs.dim));

  // ---------- tab 1: place ----------
  Widget _place(EngineData d) {
    final dim = Fs.dim, line = Fs.line;
    final wheatKeys = d.wheatDates(site);
    final hm = _col(d.heat[site], wheatKeys, 'median'), hlo = _col(d.heat[site], wheatKeys, 'p10'), hhi = _col(d.heat[site], wheatKeys, 'p90');
    final wi = math.max(0, wheatKeys.indexOf(wd));
    final hs = d.heat[site][wd];
    final series = (hs['series'] as List).map<double>((e) => (e as num).toDouble()).toList();
    final y0 = hs['first_season'] as int;
    final sumKeys = d.summerDates(site, crop);
    final wm = _col(d.water[site][crop], sumKeys, 'etc'), wlo = _col(d.water[site][crop], sumKeys, 'p10'), whi = _col(d.water[site][crop], sumKeys, 'p90');
    final si = math.max(0, sumKeys.indexOf(sd));
    final wv = d.water[site][crop][sd];
    final scan = ((d.season['sites'] as Map<String, dynamic>)[site]?[crop] as List?)?.map<List<num>>((e) => (e as List).cast<num>()).toList();
    int nearest(List<List<num>> sc, String mmdd) {
      final p = mmdd.split('-').map(int.parse).toList();
      int doy(int m, int dd) => DateTime.utc(2001, m, dd).difference(DateTime.utc(2001, 1, 1)).inDays;
      var bi = 0, bd = 1 << 30;
      for (var i = 0; i < sc.length; i++) {
        var x = (doy(sc[i][0].toInt(), sc[i][1].toInt()) - doy(p[0], p[1])).abs();
        if (x > 182) x = 365 - x;
        if (x < bd) {
          bd = x;
          bi = i;
        }
      }
      return bi;
    }

    final clim = d.climate[site] as Map<String, dynamic>;
    List<double> cv(String k) => (clim[k] as List).map<double>((e) => (e as num).toDouble()).toList();
    final book = CropBook(d);
    final saltCrops = ['rice', 'maize', 'cotton', 'wheat'];
    final saltCols = [Fs.water, Fs.warning, Fs.ok, Fs.accent];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
      _controls(d),
      if (d.siteCaveat(site) != null) Padding(padding: const EdgeInsets.only(top: 10), child: _note('${tr('تنبيه', 'Caution')}: ${d.siteCaveat(site)}')),
      _card(tr('مناخ ناسا شهرياً (متوسط ١٩٩٠ إلى ٢٠٢٥)', 'NASA POWER climate by month (mean 1990 to 2025)'), tr('أعلى وأقل حرارة يومية، °م', 'Daily maximum and minimum temperature, °C'),
          CustomPaint(painter: _LinePainter(ys: [cv('T2M_MAX'), cv('T2M_MIN')], colors: [Fs.heat, Fs.water], labels: _mon, grid: line, text: dim)),
          notes: [_note('${tr('المطر بالمم في الشهر', 'Rain, mm per month')}: ${cv('RAIN_MM_MONTH').map((e) => e.round()).join(' · ')}')],
          copy: () => _copy('climate $site', [['month', 'tmax_c', 'tmin_c', 'rain_mm'], for (var i = 0; i < 12; i++) [_mon[i], '${cv('T2M_MAX')[i]}', '${cv('T2M_MIN')[i]}', '${cv('RAIN_MM_MONTH')[i]}']])),
      _card(tr('حرارة القمح حسب ميعاد الزراعة', 'Wheat heat by sowing date'),
          tr('أيام ≥ ٣٢°م وقت امتلاء الحبوب: الوسيط، وبين النسبة ١٠ و٩٠ عبر المواسم', 'Days at or above 32 °C during grain filling: median with the 10th to 90th percentile across seasons'),
          CustomPaint(painter: _LinePainter(ys: [hm], lo: hlo, hi: hhi, colors: [Fs.heat], labels: [for (final k in wheatKeys) k.substring(3) == '01' ? _mon[int.parse(k.substring(0, 2)) - 1] : ''], mark: wi, grid: line, text: dim)),
          notes: [
            _note('${dateN(wd)}: ${tr('الوسيط', 'median')} ${nn(hm[wi], dec: 1)}, p10 ${nn(hlo[wi], dec: 1)}, p90 ${nn(hhi[wi], dec: 1)}; ${tr('أكتر من ١٥ نوفمبر بـ', 'extra vs 15 Nov')}: ${(hs['extra'] as Map)['32']} ${tr('يوم', 'days')}; ${tr('مواسم', 'seasons')}: ${series.length}'),
            Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(height: 90, width: double.infinity, child: CustomPaint(painter: _BarPainter(values: series, labels: [for (var i = 0; i < series.length; i++) i % 5 == 0 ? '${y0 + i}' : ''], mark: null, color: Fs.heat.withValues(alpha: 0.8), grid: line, text: dim, mean: series.reduce((a, b) => a + b) / series.length)))),
            _note(tr('أيام الحر في كل موسم لنفس الميعاد (الخط: المتوسط)', 'Hot days in each season for this date (line: mean)')),
          ],
          copy: () => _copy('wheat heat $site', [['sowing', 'median', 'p10', 'p90'], for (var i = 0; i < wheatKeys.length; i++) [wheatKeys[i], '${hm[i]}', '${hlo[i]}', '${hhi[i]}']])),
      _card('${tr('احتياج المية لـ', 'Water need of')} ${cropN(crop)}', tr('احتياج المحصول للمية (ETc) في الموسم بالمم، الوسيط وبين ١٠ و٩٠: FAO-56 على طقس ناسا', 'Crop evapotranspiration (ETc) over the season in mm, median with p10 to p90: FAO-56 on NASA weather'),
          CustomPaint(painter: _LinePainter(ys: [wm], lo: wlo, hi: whi, colors: [Fs.water], labels: [for (final k in sumKeys) k.substring(3) == '01' ? _mon[int.parse(k.substring(0, 2)) - 1] : ''], mark: si, grid: line, text: dim)),
          notes: [
            _note('${dateN(sd)}: ETc ${nd((wv['etc'] as num).round())} mm (p10 ${nd((wv['p10'] as num).round())}, p90 ${nd((wv['p90'] as num).round())}); ${tr('أعلى استهلاك يومي', 'peak daily')} ${nn((wv['peak_daily'] as num).toDouble(), dec: 1)} mm; ${tr('أيام الموسم', 'season')} ${wv['days']}'),
            if (crop == 'rice') _note(tr('الرز: الغمر والتسرب مش محسوبين، فالرقم حد أدنى.', 'Rice: ponding and percolation are not included, so this is a floor.')),
          ],
          copy: () => _copy('water $site $crop', [['sowing', 'etc_mm', 'p10', 'p90'], for (var i = 0; i < sumKeys.length; i++) [sumKeys[i], '${wm[i]}', '${wlo[i]}', '${whi[i]}']])),
      if (scan != null)
        _card('${tr('ملاءمة الميعاد (الحرارة فقط) لـ', 'Season fit (temperature only) for')} ${cropN(crop)}', tr('نسبة أيام الموسم في المدى الأمثل لـ EcoCrop إذا زُرع في الميعاد ده، مقابل ٣٦ سنة من طقس ناسا', 'Share of growing days inside the EcoCrop optimal range if sown on that date, against 36 years of NASA weather'),
            CustomPaint(painter: _BarPainter(values: [for (final r in scan) r[2].toDouble()], labels: [for (final r in scan) r[1].toInt() == 1 ? _mon[r[0].toInt() - 1] : ''], mark: nearest(scan, sd), color: Fs.ok.withValues(alpha: 0.85), grid: line, text: dim, maxV: 100)),
            notes: [_note('${tr('الميعاد', 'Sowing')} ${dateN(sd)}: ${tr('أمثل', 'ideal')} ${scan[nearest(scan, sd)][2]}%, ${tr('خارج المدى', 'outside range')} ${scan[nearest(scan, sd)][3]}%. ${tr('العتبات افتراضات الفريق (D17).', 'Thresholds are team assumptions (D17).')}')],
            copy: () => _copy('season fit $site $crop', [['month', 'day', 'ideal_pct', 'bad_pct'], for (final r in scan) ['${r[0]}', '${r[1]}', '${r[2]}', '${r[3]}']])),
      _card(tr('تحمل الملوحة (FAO-29)', 'Salt tolerance (FAO-29)'), tr('الإنتاج النسبي % مقابل ملوحة التربة ECe بـ dS/m، والخط الرأسي ملوحتك', 'Relative yield % against soil salinity ECe in dS/m; the vertical line is the chosen salinity'),
          CustomPaint(
              painter: _SaltPainter(curves: [
                for (final c in saltCrops) [for (final p in (d.salt['crops'][c]['points'] as List)) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())]
              ], colors: saltCols, ece: ece, grid: line, text: dim)),
          notes: [
            Wrap(spacing: 12, runSpacing: 4, children: [
              for (var i = 0; i < saltCrops.length; i++)
                () {
                  final g = book.gross(saltCrops[i], ece);
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: saltCols[i], shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('${cropN(saltCrops[i])}: ${g.saltPct ?? '<50'}%', style: const TextStyle(fontSize: 13)),
                  ]);
                }(),
            ]),
            _note(tr('مفيش منتج ناسا بيقيس ملوحة التربة: الرقم من مدخلك والجدول.', 'No NASA product measures soil salinity: this uses your input and the table.')),
          ]),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(tr('دخل تقريبي للفدان (متوسط مصر، قبل التكاليف)', 'Approximate income per feddan (Egypt averages, before costs)'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(
                  onPressed: () => _copy('income', [
                        ['crop', 'group', 'yield_kg_ha', 'price_egp_t_2022', 'salt_pct', 'gross_egp_feddan'],
                        for (final c in book.all) [c.key, c.group, '${c.yieldKgHa}', '${c.priceEgpPerT}', '${book.gross(c.key, ece).saltPct ?? ''}', '${book.gross(c.key, ece).grossEgp}']
                      ]),
                  icon: Icon(Icons.copy_rounded, size: 20, color: Fs.accent)),
            ]),
            Text(tr('FAOSTAT (مش ناسا): إنتاجية ٢٠٢٠ إلى ٢٠٢٤ × ٠٫٤٢ هكتار × سعر ٢٠٢٢ × عامل الملوحة', 'FAOSTAT (not NASA): yield 2020 to 2024 x 0.42 ha x 2022 price x salt factor'), style: TextStyle(fontSize: 12.5, color: Fs.dim)),
            const SizedBox(height: 8),
            for (final c in book.all)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(isAr ? c.ar : c.en, style: const TextStyle(fontSize: 13.5))),
                  Expanded(flex: 2, child: Text('${(c.yieldKgHa / 1000).toStringAsFixed(1)} t/ha', style: TextStyle(fontSize: 12.5, color: Fs.dim))),
                  Expanded(flex: 2, child: Text('${c.priceEgpPerT} /t', style: TextStyle(fontSize: 12.5, color: Fs.dim))),
                  Expanded(flex: 3, child: Text(moneyN(book.gross(c.key, ece).grossEgp), textAlign: TextAlign.end, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }

  // ---------- tab 2: compare ----------
  Widget _compare(EngineData d) {
    final keys = d.siteKeys;
    final labels = [tr('أيام حر القمح (≥٣٢°)', 'Wheat hot days (>=32 C)'), tr('احتياج المية ETc (مم)', 'Water need ETc (mm)'), tr('ملاءمة الميعاد (٪ أمثل)', 'Season fit (% ideal)')];
    final better = [tr('الأقل أحسن', 'lower is better'), tr('الأقل أحسن', 'lower is better'), tr('الأعلى أحسن', 'higher is better')];
    double? val(String k) {
      try {
        if (metric == 0) return (d.heat[k][wd]['median'] as num).toDouble();
        if (metric == 1) return (d.water[k][crop][sd]['etc'] as num).toDouble();
        final sc = ((d.season['sites'] as Map<String, dynamic>)[k]?[crop] as List?)?.map<List<num>>((e) => (e as List).cast<num>()).toList();
        if (sc == null) return null;
        final p = sd.split('-').map(int.parse).toList();
        int doy(int m, int dd) => DateTime.utc(2001, m, dd).difference(DateTime.utc(2001, 1, 1)).inDays;
        var best = sc.first, bd = 1 << 30;
        for (final r in sc) {
          var x = (doy(r[0].toInt(), r[1].toInt()) - doy(p[0], p[1])).abs();
          if (x > 182) x = 365 - x;
          if (x < bd) {
            bd = x;
            best = r;
          }
        }
        return best[2].toDouble();
      } catch (_) {
        return null;
      }
    }

    final rows = [for (final k in keys) if (val(k) != null) (k, val(k)!)];
    rows.sort((a, b) => metric == 2 ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2));
    final mx = rows.map((r) => r.$2).reduce(math.max), mn = rows.map((r) => r.$2).reduce(math.min);
    Color colorOf(double v) {
      final t = mx == mn ? 0.5 : (v - mn) / (mx - mn);
      final good = metric == 2 ? t : 1 - t;
      return Color.lerp(Fs.alert, Fs.ok, good)!;
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('قارن كل نقاط بيانات ناسا في الدلتا', 'Compare every NASA data point in the Delta'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _note(tr('سؤال شات بوت مبيقدرش يجاوبه: فين في الدلتا الأنسب لـ… ؟ نفس المحركات على ${nd(keys.length)} نقطة.', 'A question a chatbot cannot answer: where in the Delta is the best place for...? The same engines on ${keys.length} points.')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < 3; i++) ChoiceChip(label: Text(labels[i]), selected: metric == i, onSelected: (_) => setState(() => metric = i)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (metric == 0) _drop<String>(tr('ميعاد القمح', 'Wheat sown'), wd, d.wheatDates(site), (v) => dateN(v), (v) => setState(() => wd = v)),
            if (metric != 0) _drop<String>(tr('المحصول', 'Crop'), crop, const ['rice', 'maize', 'cotton'], (v) => cropN(v), (v) => setState(() {
                  crop = v;
                  final ds = d.summerDates(site, crop);
                  if (!ds.contains(sd)) sd = ds.contains('05-15') ? '05-15' : ds.first;
                })),
            if (metric != 0) _drop<String>(tr('ميعاد الزراعة', 'Sowing'), sd, d.summerDates(site, crop), (v) => dateN(v), (v) => setState(() => sd = v)),
          ]),
          const SizedBox(height: 6),
          _note('${labels[metric]}: ${better[metric]}'),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SoftCard(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(height: 230, width: double.infinity, child: CustomPaint(painter: _MapPainter(points: [for (final r in rows) (d.siteLatLon(r.$1), colorOf(r.$2), r.$1.startsWith('cell_'))], dim: Fs.dim, grid: Fs.line))),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(tr('الترتيب', 'Ranking'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => _copy('compare ${labels[metric]}', [['point', 'lat', 'lon', 'value'], for (final r in rows) [r.$1, '${d.siteLatLon(r.$1).lat}', '${d.siteLatLon(r.$1).lon}', '${r.$2}']]), icon: Icon(Icons.copy_rounded, size: 20, color: Fs.accent)),
            ]),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Fs.dim))),
                  Expanded(flex: 4, child: Text(siteN(rows[i].$1), style: const TextStyle(fontSize: 13.5))),
                  Expanded(flex: 4, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: mx == 0 ? 0 : rows[i].$2 / mx, minHeight: 8, color: colorOf(rows[i].$2), backgroundColor: Fs.card2))),
                  SizedBox(width: 56, child: Text(nn(rows[i].$2, dec: metric == 0 ? 1 : 0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            const SizedBox(height: 6),
            _note(tr('النقاط الرمادية الصغيرة على الخريطة خلايا ناسا الإضافية. خلايا الصحرا والبحر ليها تنبيه.', 'Small points on the map are the extra NASA cells. Desert and sea cells carry a caution.')),
          ]),
        ),
      ),
    ]);
  }

  // ---------- tab 3: method ----------
  Widget _method() {
    Widget h(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)));
    Widget p(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(fontSize: 13.5, height: 1.5, color: Fs.dim)));
    Widget row(String a, String b, String c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(flex: 3, child: Text(b, style: TextStyle(fontSize: 12.5, color: Fs.dim))),
            Expanded(flex: 4, child: Text(c, style: TextStyle(fontSize: 12.5, color: Fs.dim))),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      h(tr('البيانات', 'Data')),
      SoftCard(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            row('NASA POWER', '0.5 x 0.625 deg, daily, 1990-2025', 'T2M, T2M_MAX/MIN, RH2M, WS2M, solar: every number'),
            row('MODIS MOD13Q1', '250 m, 16-day, 2014-2025', 'pictures; vegetation context'),
            row('MODIS MCD12Q2', '500 m, yearly, 2015-2025', 'phenology cross-check (not in a result)'),
            row('MODIS MOD16A3GF', '500 m, yearly', 'input check: ET0 within 1-8%'),
            row('GPM IMERG', '0.1 deg, daily', 'context: summer rain ~ 0'),
            row('FAO-56, FAO-29', 'tables', 'Kc and stage lengths; salt tolerance'),
            row('FAO EcoCrop', 'tables', 'crop temperature ranges (generic)'),
            row('FAOSTAT', 'national, 2020-24 / 2022', 'yield and farm-gate price (not NASA)'),
          ]),
        ),
      ),
      h(tr('الحسابات', 'Calculations')),
      p('ET0: FAO-56 Penman-Monteith, daily step, G = 0, from POWER T2M_MAX/MIN, RH2M, WS2M, ALLSKY_SFC_SW_DWN. ETc = Kc(stage) x ET0 summed over the FAO-56 stage lengths from the sowing date, for every complete year 1990-2025; the app shows the median and p10 to p90.'),
      p('Wheat heat: days with Tmax >= 32 C in the grain-filling window (last 30% of thermal time before maturity), from the sowing date; shown against a 15 November sowing. The 32 C threshold, the window and the thermal-time constant are assumptions (models/wheat_calendar.yaml).'),
      p('Salt: piecewise-linear relative yield between the four FAO-29 Table 4 points at the soil ECe; above the 50% point the table gives no value (shown as under 50%, at most half in the income table).'),
      p('Season fit: share of the growing days whose daily mean temperature is inside the crop\'s EcoCrop optimal range; the label compares a date with the best date of the year (thresholds are team assumptions, D17). Crops whose score barely changes through the year are "cannot judge".'),
      p('Income: FAOSTAT Egypt yield (2020-2024 mean) x 0.42 ha x producer price (2022 annual mean) x the salt factor. Gross, before costs, national averages.'),
      h(tr('حدود', 'Limits')),
      p('POWER is a model product at about 50 km, not yet validated against Delta weather stations. Cells of mostly desert or sea carry a caution. No yield forecast; no NASA product measures soil salinity; EcoCrop ranges are generic; prices have moved since 2022.'),
      h(tr('التكرار', 'Reproducibility')),
      p('The Dart code reproduces the Python engines on golden cases (see app/test). Sources, decisions and checks: docs/methodology.md, docs/decisions.md, data/catalog.yaml.'),
    ]);
  }
}

// ---------- painters ----------
void _txt(Canvas c, String s, Offset o, Color col, {double size = 10, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: col)), textDirection: TextDirection.ltr)..layout();
  final dx = align == TextAlign.right ? -tp.width : (align == TextAlign.center ? -tp.width / 2 : 0);
  tp.paint(c, o + Offset(dx.toDouble(), -tp.height / 2));
}

class _Frame {
  _Frame(Size s) : w = s.width - l - r, h = s.height - t - b;
  static const l = 40.0, r = 8.0, t = 8.0, b = 22.0;
  final double w, h;
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.ys, this.lo, this.hi, required this.colors, required this.labels, this.mark, required this.grid, required this.text});
  final List<List<double>> ys;
  final List<double>? lo, hi;
  final List<Color> colors;
  final List<String> labels;
  final int? mark;
  final Color grid, text;

  @override
  void paint(Canvas c, Size size) {
    final f = _Frame(size);
    final all = [for (final y in ys) ...y, ...?lo, ...?hi];
    var mn = all.reduce(math.min), mx = all.reduce(math.max);
    if (mn > 0 && mn < mx * 0.6) mn = 0;
    final pad = (mx - mn) * 0.08;
    mx += pad;
    if (mn != 0) mn -= pad;
    final n = ys.first.length;
    double x(int i) => _Frame.l + f.w * i / math.max(1, n - 1);
    double y(double v) => _Frame.t + f.h * (1 - (v - mn) / (mx - mn == 0 ? 1 : mx - mn));
    for (var g = 0; g <= 4; g++) {
      final v = mn + (mx - mn) * g / 4, yy = y(v);
      c.drawLine(Offset(_Frame.l, yy), Offset(size.width - _Frame.r, yy), Paint()..color = grid..strokeWidth = 0.7);
      _txt(c, v.abs() >= 100 ? v.round().toString() : v.toStringAsFixed(1), Offset(_Frame.l - 4, yy), text, align: TextAlign.right);
    }
    if (lo != null && hi != null) {
      final path = Path()..moveTo(x(0), y(hi![0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(hi![i]));
      }
      for (var i = n - 1; i >= 0; i--) {
        path.lineTo(x(i), y(lo![i]));
      }
      c.drawPath(path..close(), Paint()..color = colors.first.withValues(alpha: 0.18));
    }
    for (var s = 0; s < ys.length; s++) {
      final p = Path()..moveTo(x(0), y(ys[s][0]));
      for (var i = 1; i < n; i++) {
        p.lineTo(x(i), y(ys[s][i]));
      }
      c.drawPath(p, Paint()..color = colors[s]..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    if (mark != null) {
      c.drawLine(Offset(x(mark!), _Frame.t), Offset(x(mark!), _Frame.t + f.h), Paint()..color = text..strokeWidth = 1);
      c.drawCircle(Offset(x(mark!), y(ys.first[mark!])), 4.5, Paint()..color = colors.first);
    }
    for (var i = 0; i < n && i < labels.length; i++) {
      if (labels[i].isNotEmpty) _txt(c, labels[i], Offset(x(i), size.height - 8), text, align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => true;
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.values, required this.labels, this.mark, required this.color, required this.grid, required this.text, this.maxV, this.mean});
  final List<double> values;
  final List<String> labels;
  final int? mark;
  final Color color, grid, text;
  final double? maxV, mean;

  @override
  void paint(Canvas c, Size size) {
    final f = _Frame(size);
    final mx = maxV ?? values.reduce(math.max) * 1.1;
    final n = values.length, bw = f.w / n;
    for (var g = 0; g <= 2; g++) {
      final v = mx * g / 2, yy = _Frame.t + f.h * (1 - g / 2);
      c.drawLine(Offset(_Frame.l, yy), Offset(size.width - _Frame.r, yy), Paint()..color = grid..strokeWidth = 0.7);
      _txt(c, v.round().toString(), Offset(_Frame.l - 4, yy), text, align: TextAlign.right);
    }
    for (var i = 0; i < n; i++) {
      final h = f.h * (values[i] / (mx == 0 ? 1 : mx));
      final r = Rect.fromLTWH(_Frame.l + i * bw + 1, _Frame.t + f.h - h, math.max(1, bw - 2), h);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = i == mark ? Colors.white : color);
      if (i < labels.length && labels[i].isNotEmpty) _txt(c, labels[i], Offset(_Frame.l + i * bw + bw / 2, size.height - 8), text, align: TextAlign.center);
    }
    if (mean != null) {
      final yy = _Frame.t + f.h * (1 - mean! / (mx == 0 ? 1 : mx));
      c.drawLine(Offset(_Frame.l, yy), Offset(size.width - _Frame.r, yy), Paint()..color = text..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter o) => true;
}

class _SaltPainter extends CustomPainter {
  _SaltPainter({required this.curves, required this.colors, required this.ece, required this.grid, required this.text});
  final List<List<Offset>> curves;
  final List<Color> colors;
  final double ece;
  final Color grid, text;

  @override
  void paint(Canvas c, Size size) {
    final f = _Frame(size);
    const xmax = 20.0;
    double x(double v) => _Frame.l + f.w * v / xmax;
    double y(double v) => _Frame.t + f.h * (1 - (v - 40) / 65);
    for (var g = 0; g <= 4; g++) {
      final v = 40 + 65 * g / 4, yy = y(v);
      c.drawLine(Offset(_Frame.l, yy), Offset(size.width - _Frame.r, yy), Paint()..color = grid..strokeWidth = 0.7);
      _txt(c, v.round().toString(), Offset(_Frame.l - 4, yy), text, align: TextAlign.right);
    }
    for (var v = 0; v <= 20; v += 5) {
      _txt(c, '$v', Offset(x(v.toDouble()), size.height - 8), text, align: TextAlign.center);
    }
    for (var s = 0; s < curves.length; s++) {
      final pts = [Offset(0, 100), ...curves[s]];
      final p = Path()..moveTo(x(pts.first.dx), y(pts.first.dy));
      for (final q in pts.skip(1)) {
        p.lineTo(x(q.dx), y(q.dy));
      }
      c.drawPath(p, Paint()..color = colors[s]..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    c.drawLine(Offset(x(ece), _Frame.t), Offset(x(ece), _Frame.t + f.h), Paint()..color = text..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _SaltPainter o) => true;
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.points, required this.dim, required this.grid});
  final List<(({double lat, double lon}), Color, bool)> points;
  final Color dim, grid;

  @override
  void paint(Canvas c, Size size) {
    const lonMin = 29.0, lonMax = 33.0, latMin = 29.9, latMax = 31.7;
    final w = size.width - 16, h = size.height - 16;
    Offset o(double lat, double lon) => Offset(8 + w * (lon - lonMin) / (lonMax - lonMin), 8 + h * (1 - (lat - latMin) / (latMax - latMin)));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8, 8, w, h), const Radius.circular(10)), Paint()..color = grid.withValues(alpha: 0.4));
    for (final p in points) {
      final pos = o(p.$1.lat, p.$1.lon);
      c.drawCircle(pos, p.$3 ? 7 : 11, Paint()..color = p.$2.withValues(alpha: p.$3 ? 0.75 : 0.95));
      if (!p.$3) c.drawCircle(pos, 11, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
    _txt(c, 'N', Offset(size.width - 14, 18), dim, size: 11);
    _txt(c, '${lonMin.toInt()}E', Offset(24, size.height - 8), dim);
    _txt(c, '${lonMax.toInt()}E', Offset(size.width - 20, size.height - 8), dim);
  }

  @override
  bool shouldRepaint(covariant _MapPainter o) => true;
}
