// Result screen. Layout follows the team's Advanced Monitor app (a two-weight headline, a hero picture with readings
// pinned to it on dotted leaders, a dial card, soft cards, round icon buttons) and the car-control reference. The hero
// is the real NASA MODIS greenness picture of the Delta with the chosen place pinned at its true position. One rotation
// at a time; nothing here is computed in this file: every number comes from the engines (engine.dart).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'advice_card.dart';
import 'engine.dart';
import 'eyad.dart';
import 'i18n.dart';
import 'ui_kit.dart';

/// Where each NASA data point falls on delta_winter.jpg / delta_summer.jpg (fraction of width, height), computed from the
/// MODIS raster's own projection (see docs/status.md).
const _sitePixel = <String, Offset>{
  'kafr_el_sheikh': Offset(0.435, 0.389),
  'damietta': Offset(0.662, 0.217),
  'beheira': Offset(0.222, 0.499),
  'gharbia': Offset(0.5, 0.554),
  'menoufia': Offset(0.501, 0.773),
  'sharqia': Offset(0.651, 0.807),
  'dakahlia': Offset(0.676, 0.423),
};


class ResultView extends StatefulWidget {
  const ResultView({super.key, required this.c, required this.data, required this.mood, required this.onRestart, required this.onReadAloud, this.onSpeak});
  final Comparison c;
  final EngineData data;
  final EyadMood mood;
  final VoidCallback onRestart, onReadAloud;
  final void Function(String text)? onSpeak;
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
    final cav = caveatN(c);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      _headline(),
      const SizedBox(height: 14),
      AdviceCard(c: c, onSpeak: widget.onSpeak),
      const SizedBox(height: 14),
      _heroArt(r),
      if (cav != null) _notice(cav, c.caveatKind == 'sea' ? Fs.warning : Fs.accent),
      const SizedBox(height: 16),
      _tabs(),
      const SizedBox(height: 8),
      Text(
        '${cropN(r.input.crop)}: ${tr('زراعة', 'sown')} ${dateN(r.input.summerSowing)}, ${tr('حصاد تقريباً', 'harvest about')} ${harvestN(r.harvest)}.  ${cropN('wheat')}: ${dateN(r.input.wheatSowing)}${r.isExisting ? '' : tr(' (افتراض)', ' (assumed)')}',
        style: TextStyle(fontSize: 13, color: Fs.dim, height: 1.4),
      ),
      const SizedBox(height: 14),
      _dialCard(r),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _heatCard(r)), const SizedBox(width: 12), Expanded(child: _saltCard(r))]),
      for (final w in r.warnings) _alert(r, w),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _round(Icons.water_drop_rounded, tr('مية', 'Water'), () => _sheet(_water(r))),
        _round(Icons.thermostat_rounded, tr('حرارة', 'Heat'), () => _sheet(_heat(r))),
        _round(Icons.grain_rounded, tr('ملوحة', 'Salt'), () => _sheet(_salt(r))),
        _round(Icons.wb_sunny_rounded, tr('طقس', 'Weather'), () => _sheet(_weather())),
      ]),
      const SizedBox(height: 22),
      Text(noticeN(), style: TextStyle(fontSize: 13, color: Fs.dim, height: 1.5)),
      const SizedBox(height: 16),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: widget.onReadAloud,
          icon: const Icon(Icons.volume_up_rounded),
          label: Text(tr('اسمع النتيجة', 'Read it aloud')),
          style: FilledButton.styleFrom(backgroundColor: Fs.accent, foregroundColor: Fs.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fs.radiusTile)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: widget.onRestart,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('ابدأ من جديد', 'Start again')),
          style: FilledButton.styleFrom(backgroundColor: Fs.card2, foregroundColor: Fs.text, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fs.radiusTile)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // Two-weight headline (light line, then semibold), with Eyad beside it.
  Widget _headline() => Row(children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${tr('المقارنة لـ', 'Comparison for')}\n', style: const TextStyle(fontWeight: FontWeight.w400)),
              TextSpan(text: siteN(c.site), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontSize: 30, height: 1.2),
          ),
        ),
        EyadAvatar(mood: widget.mood, size: 64, glow: false),
      ]);

  /// The real NASA picture with the place pinned at its true position and three readings on dotted leaders.
  Widget _heroArt(RotationRow r) => ClipRRect(
        borderRadius: BorderRadius.circular(Fs.radiusCard),
        child: Container(
          color: Fs.card,
          child: AspectRatio(
            aspectRatio: 1.32,
            child: LayoutBuilder(builder: (context, cons) {
              final w = cons.maxWidth, h = cons.maxHeight;
              // the picture covers the card (centre-cropped); the pin follows the same mapping
              final scale = math.max(w / 1372, h / 700);
              final iw = 1372 * scale, ih = 700 * scale;
              final ox = (w - iw) / 2, oy = (h - ih) / 2;
              final f = _sitePixel[c.site] ?? const Offset(0.5, 0.55);
              final pin = Offset(ox + f.dx * iw, oy + f.dy * ih);
              final s = r.saltSummer;
              final bubbles = <_BubbleSpec>[
                _BubbleSpec(Icons.thermostat_rounded, Fs.heat, '${nd(r.heatMedian.round())} ${tr('يوم', 'days')}', const Offset(0.15, 0.27)),
                _BubbleSpec(Icons.water_drop_rounded, Fs.water, '${nn(r.ratio, dec: 2)}×', const Offset(0.85, 0.27)),
                _BubbleSpec(Icons.grain_rounded, s == null ? Fs.dim : Fs.status(s.status), s == null ? '—' : saltN(s.status), const Offset(0.5, 0.80)),
              ];
              // a bubble that would sit on top of the pin (Menoufia's pin is under the salt bubble) moves sideways
              // the salt verdict stays on the bottom row: it takes the first of centre, left, right that is clear of the pin
              Offset saltAt(Offset want) {
                for (final dx in const [0.5, 0.2, 0.8]) {
                  final o = Offset(dx, want.dy);
                  if ((pin - Offset(o.dx * w, o.dy * h)).distance >= 62) return o;
                }
                return want;
              }

              final placed = [
                for (final b in bubbles)
                  if (b.icon == Icons.grain_rounded)
                    _BubbleSpec(b.icon, b.color, b.text, saltAt(b.at))
                  else if ((pin - Offset(b.at.dx * w, b.at.dy * h)).distance < 70)
                    _BubbleSpec(b.icon, b.color, b.text, Offset(b.at.dx + (pin.dx < w / 2 ? 0.3 : -0.3), b.at.dy))
                  else
                    b
              ];
              return Stack(children: [
                Positioned.fill(child: Image.asset('assets/img/delta_winter.jpg', fit: BoxFit.cover)),
                PositionedDirectional(top: 10, start: 14, child: Text(tr('خضرة الدلتا من أقمار ناسا (MODIS)', 'Delta greenness, NASA MODIS'), style: const TextStyle(fontSize: 10, color: Colors.white70, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))),
                Positioned.fill(child: CustomPaint(painter: _LeaderPainter(pin, [for (final b in placed) Offset(b.at.dx * w, b.at.dy * h)]))),
                for (final b in placed) Positioned(left: b.at.dx * w - 54, top: b.at.dy * h - 27, width: 108, child: _bubble(b)),
              ]);
            }),
          ),
        ),
      );

  Widget _bubble(_BubbleSpec b) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Fs.card, shape: BoxShape.circle, border: Border.all(color: b.color.withValues(alpha: 0.5), width: 1.5)),
          child: Icon(b.icon, size: 22, color: b.color),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(12)),
          child: Text(b.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _notice(String text, Color color) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Color.alphaBlend(color.withValues(alpha: 0.18), Fs.card), borderRadius: BorderRadius.circular(Fs.radiusTile)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45))),
        ]),
      );

  Widget _tabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < c.rows.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () => setState(() => sel = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: i == sel ? Fs.accent : Fs.card2, borderRadius: BorderRadius.circular(24)),
                  child: Text(_pill(c.rows[i]), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: i == sel ? Fs.onAccent : Fs.text)),
                ),
              ),
            ),
        ]),
      );

  /// The main number: water need compared with the farmer's own rotation, as a position on a 0.5x to 1.5x scale.
  Widget _dialCard(RotationRow r) {
    final pct = ((r.ratio - 1).abs() * 100).round();
    final label = r.isExisting || pct == 0 ? tr('نفس دورتك', 'Same as yours') : '${nd(pct)}% ${r.ratio > 1 ? tr('أكتر', 'more') : tr('أقل', 'less')}';
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(children: [
        Row(children: [
          IconBubble(Icons.water_drop_rounded, color: Fs.water),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('احتياج المية', 'Water need'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text(tr('مية المحصول الصيفي بس، قصاد دورتك الحالية', 'summer crop only, compared with your current rotation'), style: TextStyle(fontSize: 13, color: Fs.dim)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        ArcDial(
          value: r.ratio,
          min: 0.5,
          max: 1.5,
          bandLow: 0.95,
          bandHigh: 1.05,
          size: 230,
          minLabel: '${nn(0.5, dec: 1)}×',
          maxLabel: '${nn(1.5, dec: 1)}×',
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${nn(r.ratio, dec: 2)}×', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w500, height: 1.1)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(14)), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }

  Widget _heatCard(RotationRow r) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBubble(Icons.thermostat_rounded, size: 34, color: Fs.heat),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('أيام فوق ٣٢°', 'Days above 32°'), style: TextStyle(fontSize: 13, color: Fs.dim))),
          ]),
          const SizedBox(height: 10),
          Text('${nd(r.heatMedian.round())} ${tr('يوم', 'days')}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.1)),
          if (r.series.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Sparkline(r.series, color: Fs.heat, mark: null)),
          const SizedBox(height: 6),
          Text(tr('وقت امتلاء حبوب القمح، قارن بين المواعيد', 'in wheat grain filling; compare dates'), style: TextStyle(fontSize: 12, color: Fs.dim, height: 1.3)),
        ]),
      );

  Widget _saltCard(RotationRow r) {
    final s = r.saltSummer;
    if (s == null) {
      return SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [IconBubble(Icons.grain_rounded, size: 34, color: Fs.dim), const SizedBox(width: 8), Text(tr('الملوحة', 'Salt'), style: TextStyle(fontSize: 13, color: Fs.dim))]),
          const SizedBox(height: 14),
          Text(tr('مفيش بيانات', 'Not provided'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final col = Fs.status(s.status);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBubble(Icons.grain_rounded, size: 34, color: col),
          const SizedBox(width: 8),
          Expanded(child: Text('${tr('ملوحة', 'Salt')}: ${cropN(r.input.crop)}', style: TextStyle(fontSize: 13, color: Fs.dim))),
        ]),
        const SizedBox(height: 14),
        Center(
          child: RingGauge(
            progress: (s.yieldPct ?? 0) / 100,
            size: 84,
            stroke: 8,
            color: col,
            child: Text(s.yieldPct == null ? '<${nd(50)}%' : '${nd(s.yieldPct!)}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Color.alphaBlend(col.withValues(alpha: 0.18), Fs.card), borderRadius: BorderRadius.circular(12)), child: Text(saltN(s.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: col)))),
      ]),
    );
  }

  Widget _alert(RotationRow r, String w) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(Fs.radiusCard), boxShadow: Fs.lift),
        child: Row(children: [
          IconBubble(Icons.priority_high_rounded, color: Fs.warning),
          const SizedBox(width: 12),
          Expanded(child: Text(warningN(r), style: const TextStyle(fontSize: 13, height: 1.45))),
        ]),
      );

  Widget _round(IconData icon, String label, VoidCallback onTap) => Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onTap,
          child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Fs.card2, shape: BoxShape.circle), child: Icon(icon, size: 26, color: Fs.text)),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Fs.dim)),
      ]);

  void _sheet(Widget body) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Fs.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Fs.radiusCard))),
        builder: (_) => Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 24), child: body)),
        ),
      );

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)));
  Widget _p(String t, {bool dim = false}) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, style: TextStyle(fontSize: 15, height: 1.5, color: dim ? Fs.dim : Fs.text)));
  Widget _src(String t) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(12)), child: Text(t, style: TextStyle(fontSize: 12, color: Fs.dim))),
      );

  Widget _water(RotationRow r) {
    final c0 = c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h(tr('المية', 'Water')),
      Text('${nn(r.ratio, dec: 2)}×', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w500)),
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
      Text('${nd(r.heatMedian.round())} ${tr('يوم فوق ٣٢°', 'days above 32°')}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
      _p('${tr('في أغلب السنين من', 'In most years')} ${nd(r.heatP10.round())} ${tr('لـ', 'to')} ${nd(r.heatP90.round())}. ${tr('قارن بين المواعيد، الرقم نفسه تقريبي.', 'Compare dates; the number itself is approximate.')}'),
      if (r.input.wheatSowing == '11-15')
        _p(tr('ده الميعاد المعتاد (١٥ نوفمبر)، ونقيس عليه.', 'This is the usual date (15 November) that the others are measured against.'))
      else
        _p(tr('مقارنة بزراعة ١٥ نوفمبر: عند ٣٠° ${_signed(e['30'] ?? 0)}، عند ٣٢° ${_signed(e['32'] ?? 0)}، عند ٣٤° ${_signed(e['34'] ?? 0)} يوم.',
            'Compared with sowing on 15 November: at 30° ${_signed(e['30'] ?? 0)}, at 32° ${_signed(e['32'] ?? 0)}, at 34° ${_signed(e['34'] ?? 0)} days.')),
      if (r.series.isNotEmpty) ...[
        const SizedBox(height: 14),
        Sparkline(r.series, color: Fs.heat, height: 60),
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
          Expanded(child: Text('${cropN(crop)}: ${saltN(f.status)}${f.yieldPct != null ? ' (${nd(f.yieldPct!)}%)' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
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
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(l, style: TextStyle(fontSize: 12, color: Fs.dim)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _h('${tr('طقس', 'Weather in')} ${siteN(c.site)} ${tr('في', 'in')} ${monthN(month)}'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${nn(tmax[month - 1])}°', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w500, height: 1)),
        const SizedBox(width: 10),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${tr('عظمى', 'high')} · ${tr('صغرى', 'low')} ${nn(tmin[month - 1])}°', style: TextStyle(fontSize: 13, color: Fs.dim))),
      ]),
      const SizedBox(height: 12),
      MonthChart(values: tmax, markMonth: month, color: Fs.heat),
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

class _BubbleSpec {
  const _BubbleSpec(this.icon, this.color, this.text, this.at);
  final IconData icon;
  final Color color;
  final String text;
  final Offset at; // fraction of the card where the bubble is centred
}

/// Dotted leaders from the pinned place to each reading, and the pin itself.
class _LeaderPainter extends CustomPainter {
  _LeaderPainter(this.pin, this.to);
  final Offset pin;
  final List<Offset> to;

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final t in to) {
      final d = t - pin;
      final len = d.distance;
      if (len < 1) continue;
      final dir = d / len;
      for (double x = 14; x < len - 24; x += 8) {
        c.drawLine(pin + dir * x, pin + dir * math.min(x + 4, len - 24), paint);
      }
    }
    c.drawCircle(pin, 9, Paint()..color = Fs.accent.withValues(alpha: 0.35));
    c.drawCircle(pin, 5, Paint()..color = Fs.accent);
    c.drawCircle(pin, 5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LeaderPainter o) => o.pin != pin || o.to != to;
}
