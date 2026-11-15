// Result screen, laid out like the car-control reference: a real NASA picture on top (MODIS greenness of the Delta),
// a rotation switcher, one big ring for the main number, two small cards, and a row of round icon buttons that open the
// detail of water, heat, salt and weather. One rotation at a time; nothing here is computed in this file: every
// number comes from the engines (engine.dart).
import 'package:flutter/material.dart';

import 'engine.dart';
import 'eyad.dart';
import 'i18n.dart';
import 'ui_kit.dart';

class ResultView extends StatefulWidget {
  const ResultView({super.key, required this.c, required this.data, required this.mood, required this.onRestart, required this.onReadAloud});
  final Comparison c;
  final EngineData data;
  final EyadMood mood;
  final VoidCallback onRestart, onReadAloud;
  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  int sel = 0;

  Comparison get c => widget.c;

  String _pill(RotationRow r) => r.isExisting ? tr('دورتك', 'Yours') : '${cropN(r.input.crop)} ${tr('ثم قمح', '+ wheat')}';

  @override
  Widget build(BuildContext context) {
    final r = c.rows[sel];
    final maxRatio = c.rows.map((x) => x.ratio).reduce((a, b) => a > b ? a : b);
    final cav = caveatN(c);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      _hero(),
      if (cav != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: (c.caveatKind == 'sea' ? Fs.orange : Fs.card), borderRadius: BorderRadius.circular(16).copyWith(), border: Border.all(color: c.caveatKind == 'sea' ? Fs.orange : Fs.line)),
          child: Text(cav, style: TextStyle(fontSize: 13, height: 1.4, color: c.caveatKind == 'sea' ? Colors.black : Colors.white)),
        ),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < c.rows.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () => setState(() => sel = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: i == sel ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: i == sel ? Colors.white : Fs.line)),
                  child: Text(_pill(c.rows[i]), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: i == sel ? Colors.black : Fs.dim)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Text(
        '${cropN(r.input.crop)}: ${tr('زراعة', 'sown')} ${dateN(r.input.summerSowing)}, ${tr('حصاد تقريباً', 'harvest about')} ${harvestN(r.harvest)}.  ${cropN('wheat')}: ${dateN(r.input.wheatSowing)}${r.isExisting ? '' : tr(' (افتراض)', ' (assumed)')}',
        style: const TextStyle(fontSize: 13, color: Fs.dim, height: 1.4),
      ),
      const SizedBox(height: 18),
      Center(
        child: RingGauge(
          progress: r.ratio / maxRatio,
          size: 200,
          stroke: 9,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${nn(r.ratio, dec: 2)}×', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 4),
            Text(r.isExisting ? tr('مية دورتك', 'your water need') : tr('مية مقارنة بدورتك', 'water vs yours'), style: const TextStyle(fontSize: 12, color: Fs.dim)),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _heatCard(r)), const SizedBox(width: 12), Expanded(child: _saltCard(r))]),
      for (final w in r.warnings) _alert(r, w),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _round(Icons.water_drop_rounded, tr('مية', 'Water'), () => _sheet(_water(r))),
        _round(Icons.thermostat_rounded, tr('حرارة', 'Heat'), () => _sheet(_heat(r))),
        _round(Icons.grain_rounded, tr('ملوحة', 'Salt'), () => _sheet(_salt(r))),
        _round(Icons.wb_sunny_rounded, tr('طقس', 'Weather'), () => _sheet(_weather())),
      ]),
      const SizedBox(height: 22),
      Text(noticeN(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: widget.onReadAloud, icon: const Icon(Icons.volume_up_rounded), label: Text(tr('اسمع النتيجة', 'Read it aloud')), style: _btn())),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: widget.onRestart, icon: const Icon(Icons.refresh_rounded), label: Text(tr('ابدأ من جديد', 'Start again')), style: _btn())),
      ]),
    ]);
  }

  ButtonStyle _btn() => OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Fs.line), padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder());

  /// A real NASA picture: MODIS greenness of the Delta (our own rendering of the data), with the place name on it.
  Widget _hero() => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 170,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/img/delta_winter.jpg', fit: BoxFit.cover, alignment: const Alignment(0.1, -0.1)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33000000), Color(0xE6000000)]))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('المقارنة لـ', 'Comparison for'), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    Text(siteN(c.site), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 4),
                    Text(tr('صورة NASA MODIS لخضرة الدلتا (قمة الشتا)', 'NASA MODIS greenness of the Delta (winter peak)'), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ]),
                ),
                EyadAvatar(mood: widget.mood, size: 64, glow: false),
              ]),
            ),
          ]),
        ),
      );

  Widget _card({required Widget child}) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(22)), child: child);

  Widget _heatCard(RotationRow r) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.thermostat_rounded, size: 18, color: Fs.orange),
            const SizedBox(width: 6),
            Expanded(child: Text(tr('أيام فوق ٣٢°', 'Days above 32°'), style: const TextStyle(fontSize: 12, color: Fs.dim))),
          ]),
          if (r.series.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Sparkline(r.series, color: Fs.orange, mark: null)),
          const SizedBox(height: 6),
          Text('${nd(r.heatMedian.round())} ${tr('يوم', 'days')}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
          Text(tr('وقت امتلاء حبوب القمح، قارن بين المواعيد', 'in wheat grain filling; compare dates'), style: const TextStyle(fontSize: 11, color: Fs.dim, height: 1.3)),
        ]),
      );

  Widget _saltCard(RotationRow r) {
    final s = r.saltSummer;
    if (s == null) {
      return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.grain_rounded, size: 18, color: Fs.dim), const SizedBox(width: 6), Text(tr('الملوحة', 'Salt'), style: const TextStyle(fontSize: 12, color: Fs.dim))]),
          const SizedBox(height: 10),
          Text(tr('مفيش بيانات', 'Not provided'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      );
    }
    final col = Fs.status(s.status);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.grain_rounded, size: 18, color: Fs.dim),
          const SizedBox(width: 6),
          Expanded(child: Text('${tr('ملوحة', 'Salt')}: ${cropN(r.input.crop)}', style: const TextStyle(fontSize: 12, color: Fs.dim))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          RingGauge(
            progress: (s.yieldPct ?? 0) / 100,
            size: 52,
            stroke: 5,
            color: col,
            child: Text(s.yieldPct == null ? '<${nd(50)}%' : '${nd(s.yieldPct!)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(saltN(s.status), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col))),
        ]),
      ]),
    );
  }

  Widget _alert(RotationRow r, String w) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: const BoxDecoration(color: Fs.orange, shape: BoxShape.circle), child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(warningN(r), style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );

  Widget _round(IconData icon, String label, VoidCallback onTap) => Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onTap,
          child: Container(width: 62, height: 62, decoration: BoxDecoration(color: Fs.card2, shape: BoxShape.circle, border: Border.all(color: Fs.line)), child: Icon(icon, size: 26, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Fs.dim)),
      ]);

  void _sheet(Widget body) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Fs.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 24), child: body)),
        ),
      );

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)));
  Widget _p(String t, {bool dim = false}) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, style: TextStyle(fontSize: 14, height: 1.5, color: dim ? Fs.dim : Colors.white)));
  Widget _src(String t) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Fs.line), borderRadius: BorderRadius.circular(12)), child: Text(t, style: const TextStyle(fontSize: 11, color: Fs.dim))),
      );

  Widget _water(RotationRow r) {
    final c0 = c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h(tr('المية', 'Water')),
      Text('${nn(r.ratio, dec: 2)}×', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
      _p('${cropN(r.input.crop)}: ${ratioN(r.ratio)}'),
      _p('${tr('حوالي', 'About')} ${nd(r.etc)} ${tr('مم في الموسم (غير مؤكد). في أغلب السنين من', 'mm per season (unchecked). In most years')} ${nd(r.etcP10)} ${tr('لـ', 'to')} ${nd(r.etcP90)} ${tr('مم', 'mm')}.'),
      _p('${tr('أعلى استهلاك في اليوم', 'Peak use per day')}: ${nn(r.peakDaily, dec: 1)} ${tr('مم', 'mm')}.'),
      if (c0.intervalDays != null && r.turnMm != null)
        _p(tr('مع ري كل ${nd(c0.intervalDays!)} يوم: كل مرة لازم توصل ${nd(r.turnMm!)} مم على الأقل في أيام الذروة. ده استهلاك المحصول بس، من غير فاقد.',
            'With watering every ${c0.intervalDays} days, each turn must deliver at least ${r.turnMm} mm in peak days. That is crop use only, without losses.')),
      if (r.riceFloor) _p(tr('الرز بياخد مية أكتر من الرقم ده، لأن غمر الحقل والتسرب مش محسوبين.', 'Rice needs more than this figure, because flooding and seepage are not counted.'), dim: true),
      _src('NASA POWER + FAO-56 · ${tr('افتراضات النموذج', 'model assumptions')}'),
    ]);
  }

  Widget _heat(RotationRow r) {
    final e = r.extra;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h(tr('الحرارة وقت امتلاء الحبوب', 'Heat in grain filling')),
      Text('${nd(r.heatMedian.round())} ${tr('يوم فوق ٣٢°', 'days above 32°')}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      _p('${tr('في أغلب السنين من', 'In most years')} ${nd(r.heatP10.round())} ${tr('لـ', 'to')} ${nd(r.heatP90.round())}. ${tr('قارن بين المواعيد، الرقم نفسه تقريبي.', 'Compare dates; the number itself is approximate.')}'),
      if (r.input.wheatSowing == '11-15')
        _p(tr('ده الميعاد المعتاد (١٥ نوفمبر)، ونقيس عليه.', 'This is the usual date (15 November) that the others are measured against.'))
      else
        _p(tr('مقارنة بزراعة ١٥ نوفمبر: عند ٣٠° ${_signed(e['30'] ?? 0)}، عند ٣٢° ${_signed(e['32'] ?? 0)}، عند ٣٤° ${_signed(e['34'] ?? 0)} يوم.',
            'Compared with sowing on 15 November: at 30° ${_signed(e['30'] ?? 0)}, at 32° ${_signed(e['32'] ?? 0)}, at 34° ${_signed(e['34'] ?? 0)} days.')),
      if (r.series.isNotEmpty) ...[
        const SizedBox(height: 14),
        Sparkline(r.series, color: Fs.orange, height: 60),
        _p(tr('كل موسم من ١٩٩٠ لـ ٢٠٢٥', 'Each season, 1990 to 2025'), dim: true),
      ],
      _src(tr('NASA POWER · حد الحر ٣٢° فرضية', 'NASA POWER · the 32° limit is an assumption')),
    ]);
  }

  String _signed(int v) => v > 0 ? '+${nd(v)}' : (v < 0 ? '-${nd(-v)}' : nd(0));

  Widget _salt(RotationRow r) {
    final rows = <Widget>[];
    void line(String crop, SaltFit? f) {
      if (f == null) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: Fs.status(f.status), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text('${cropN(crop)}: ${saltN(f.status)}${f.yieldPct != null ? ' (${nd(f.yieldPct!)}%)' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
      ));
    }

    line(r.input.crop, r.saltSummer);
    line('wheat', r.saltWheat);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h(tr('الملوحة', 'Salt')),
      if (rows.isEmpty) _p(tr('مدخلتش معلومة عن الملوحة.', 'No salt information was given.')) else ...rows,
      if (c.saltBasisAssumed) _p(tr('ده تقدير من العلامات اللي وصفتها. اعمل تحليل تربة للتأكد.', 'This is an estimate from the signs you described. Please test the soil to be sure.'), dim: true),
      _p(tr('النسبة هي قدرة المحصول على تحمّل ملوحة أرضك حسب جداول الفاو، مش توقع لمحصولك أنت.', 'The percentage is how well the crop tolerates your soil salt according to the FAO tables, not a forecast for your crop.'), dim: true),
      _p(tr('مفيش قمر صناعي لناسا بيقيس ملوحة التربة، فالملوحة من كلامك أنت.', 'No NASA satellite measures soil salinity, so the salt result comes from what you told me.'), dim: true),
      _src(tr('جداول FAO 29 · من كلام المزارع', 'FAO paper 29 · farmer input')),
    ]);
  }

  Widget _weather() {
    final month = int.parse(c.rows.first.input.wheatSowing.split('-')[0]);
    final tmax = widget.data.climateVar(c.site, 'T2M_MAX'), tmin = widget.data.climateVar(c.site, 'T2M_MIN');
    final rh = widget.data.climateVar(c.site, 'RH2M'), wind = widget.data.climateVar(c.site, 'WS2M'), rain = widget.data.climateVar(c.site, 'RAIN_MM_MONTH');
    Widget stat(IconData i, String v, String l) => Expanded(
          child: Column(children: [
            Icon(i, size: 20, color: Fs.dim),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(l, style: const TextStyle(fontSize: 11, color: Fs.dim)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h('${tr('طقس', 'Weather in')} ${siteN(c.site)} ${tr('في', 'in')} ${monthN(month)}'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${nn(tmax[month - 1])}°', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(width: 10),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${tr('عظمى', 'high')} · ${tr('صغرى', 'low')} ${nn(tmin[month - 1])}°', style: const TextStyle(fontSize: 13, color: Fs.dim))),
      ]),
      const SizedBox(height: 12),
      MonthChart(values: tmax, markMonth: month),
      _p(tr('متوسط الحرارة العظمى كل شهر من ١٩٩٠ لـ ٢٠٢٥. الدايرة هي شهر زراعة القمح.', 'Average monthly high, 1990 to 2025. The dot is the month you sow wheat.'), dim: true),
      const SizedBox(height: 14),
      Row(children: [
        stat(Icons.water_drop_outlined, '${nn(rh[month - 1])}%', tr('رطوبة', 'humidity')),
        stat(Icons.grain_rounded, '${nn(rain[month - 1], dec: 1)} ${tr('مم', 'mm')}', tr('مطر', 'rain')),
        stat(Icons.air_rounded, '${nn(wind[month - 1], dec: 1)} ${tr('م/ث', 'm/s')}', tr('رياح', 'wind')),
      ]),
      _src(tr('NASA POWER · خلية حوالي ٥٠ كم', 'NASA POWER · cell of about 50 km')),
    ]);
  }
}
