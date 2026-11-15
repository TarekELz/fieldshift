// The result as short pages the farmer swipes through himself: a verdict for each crop first, then Eyad's advice, then water, heat and salt, each with one
// plain line per crop and the small details underneath. Everything here comes from the engines (engine.dart) and the advice layer (advice.dart); the notes that
// used to crowd the screen live on the Terms page (terms.dart).
import 'package:flutter/material.dart';

import 'advice_card.dart';
import 'engine.dart';
import 'i18n.dart';
import 'ui_kit.dart';

String _label(RotationRow r) => r.isExisting ? '${tr('اللي بتزرعه دلوقتي', 'What you grow now')}: ${cropN(r.input.crop)} ${tr('ثم قمح', '+ wheat')}' : '${tr('بديل', 'Option')}: ${cropN(r.input.crop)} ${tr('ثم قمح', '+ wheat')}';

/// level 0 fine, 1 take care, 2 not suitable, with the reason in one line. The rules are code, not the AI.
({int level, String reason}) verdictOf(RotationRow r) {
  final salt = r.saltSummer?.status;
  final extra = r.extra['32'] ?? 0;
  final crop = cropN(r.input.crop);
  if (r.gapDays < 0) return (level: 2, reason: tr('القمح هيتزرع قبل ما $crop يخلص', 'Wheat would be sown before $crop finishes'));
  if (salt == 'not advised') return (level: 2, reason: tr('نسبة الملوحة عالية على $crop', 'The salt level is too high for $crop'));
  if (r.gapDays < 14) return (level: 1, reason: tr('فاضل ${daysN(r.gapDays)} بس قبل القمح', 'Only ${daysN(r.gapDays)} before wheat'));
  if (extra >= 4) return (level: 1, reason: tr('القمح متأخر، وهيقابل حر أكتر بحوالي ${daysN(extra)}', 'Wheat is late and meets about ${daysN(extra)} more heat'));
  if (salt == 'reduced') return (level: 1, reason: tr('الملوحة هتقلل شوية', 'The salt will reduce it a little'));
  return (level: 0, reason: tr('مفيش مشكلة ظاهرة', 'No problem found'));
}

Color _levelColor(int l) => l == 0 ? Fs.ok : (l == 1 ? Fs.warning : Fs.alert);
String _levelWord(int l) => l == 0 ? tr('تمام', 'Fine') : (l == 1 ? tr('مشكلة بسيطة', 'A small problem') : tr('مشكلة كبيرة', 'A big problem'));

class ResultPager extends StatefulWidget {
  const ResultPager({super.key, required this.c, required this.onRestart, required this.onReadAloud, this.onSpeak});
  final Comparison c;
  final VoidCallback onRestart, onReadAloud;
  final void Function(String text)? onSpeak;
  @override
  State<ResultPager> createState() => _ResultPagerState();
}

class _ResultPagerState extends State<ResultPager> {
  final _ctl = PageController();
  int page = 0;

  Comparison get c => widget.c;
  static const _count = 5;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _title => [tr('الحكم', 'Verdict'), tr('نصيحة إياد', "Eyad's advice"), tr('المية', 'Water'), tr('الحرارة', 'Heat'), tr('الملوحة', 'Salt')][page];

  void _go(int p) => _ctl.animateToPage(p.clamp(0, _count - 1), duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final last = page == _count - 1;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
        child: Row(children: [
          Expanded(child: Text('${tr('المقارنة لـ', 'For')} ${siteN(c.site)}', style: TextStyle(fontSize: 14, color: Fs.dim))),
          IconButton(onPressed: widget.onReadAloud, icon: Icon(Icons.volume_up_rounded, color: Fs.accent), tooltip: tr('اسمع', 'Listen')),
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(_title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)))),
      const SizedBox(height: 8),
      Expanded(
        child: PageView(controller: _ctl, onPageChanged: (i) => setState(() => page = i), children: [_verdict(), _advice(), _water(), _heat(), _salt()]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(children: [
          RoundButton(icon: Icons.arrow_back_rounded, onTap: page == 0 ? null : () => _go(page - 1), tooltip: tr('السابق', 'Back')),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == page ? Fs.accent : Fs.card2, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
          ),
          last
              ? SizedBox(height: 48, child: FilledButton(onPressed: widget.onRestart, child: Text(tr('ابدأ من جديد', 'Start again'))))
              : SizedBox(height: 48, child: FilledButton(onPressed: () => _go(page + 1), child: Text(tr('التالي', 'Next')))),
        ]),
      ),
    ]);
  }

  Widget _shell(List<Widget> rows, {List<Widget> details = const []}) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
        ...rows,
        if (details.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(tr('تفاصيل', 'Details'), style: TextStyle(fontSize: 14, color: Fs.dim)),
              children: [Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: details))],
            ),
          ),
      ]);

  Widget _row(RotationRow r, String big, String line, Color color, {double? bar}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_label(r), style: TextStyle(fontSize: 14, color: Fs.dim)),
            const SizedBox(height: 6),
            Text(big, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: color)),
            if (bar != null) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: bar.clamp(0.02, 1.0), minHeight: 7, color: color, backgroundColor: Fs.card2)),
            ],
            const SizedBox(height: 6),
            Text(line, style: const TextStyle(fontSize: 16, height: 1.4)),
          ]),
        ),
      );

  Widget _small(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(fontSize: 13.5, height: 1.45, color: Fs.dim)));

  Widget _verdict() => _shell([
        for (final r in c.rows) () {
          final v = verdictOf(r);
          return _row(r, _levelWord(v.level), v.reason, _levelColor(v.level));
        }(),
      ], details: [
        for (final r in c.rows) _small('${_label(r)}: ${tr('زراعة', 'sown')} ${dateN(r.input.summerSowing)}, ${tr('حصاد تقريباً', 'harvest about')} ${harvestN(r.harvest)}. ${cropN('wheat')}: ${dateN(r.input.wheatSowing)}${r.isExisting ? '' : tr(' (افتراض)', ' (assumed)')}'),
      ]);

  Widget _advice() => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [AdviceCard(c: c, onSpeak: widget.onSpeak)]);

  Widget _water() {
    final base = c.rows.first;
    return _shell([
      for (final r in c.rows)
        _row(
            r,
            r.isExisting ? tr('مقياس المقارنة', 'The baseline') : (r.ratio == 1 ? tr('زي اللي بتزرعه دلوقتي', 'Same as what you grow now') : (r.ratio < 1 ? tr('أقل بـ ${nd(((1 - r.ratio) * 100).round())}٪', '${((1 - r.ratio) * 100).round()}% less') : tr('أكتر بـ ${nd(((r.ratio - 1) * 100).round())}٪', '${((r.ratio - 1) * 100).round()}% more'))),
            r.isExisting ? tr('احتياج المية للمحصول الصيفي في موسمه', "The summer crop's water need in its season") : tr('احتياج المية للمحصول الصيفي مقارنة باللي بتزرعه دلوقتي', "The summer crop's water need compared with yours"),
            r.ratio <= 1.0 ? Fs.ok : (r.ratio <= 1.15 ? Fs.warning : Fs.alert),
            bar: r.ratio / 1.5),
    ], details: [
      for (final r in c.rows) _small('${cropN(r.input.crop)}: ${tr('حوالي', 'about')} ${nd(r.etc)} ${tr('مم في الموسم، أعلى استهلاك في اليوم', 'mm per season, peak use per day')} ${nn(r.peakDaily, dec: 1)} ${tr('مم', 'mm')}.${r.riceFloor ? tr(' الرز بياخد أكتر، لأن غمر الحقل والتسرب مش محسوبين.', ' Rice needs more: flooding and seepage are not counted.') : ''}'),
      if (c.intervalDays != null && base.turnMm != null)
        _small(tr('مع ري كل ${nd(c.intervalDays!)} يوم: كل مرة لازم توصل ${nd(base.turnMm!)} مم على الأقل في أيام الذروة لـ${cropN(base.input.crop)}.', 'With watering every ${c.intervalDays} days each turn must deliver at least ${base.turnMm} mm at peak for ${cropN(base.input.crop)}.')),
    ]);
  }

  Widget _heat() => _shell([
        for (final r in c.rows)
          () {
            final e = r.extra['32'] ?? 0;
            final color = e >= 8 ? Fs.alert : (e >= 4 ? Fs.warning : Fs.ok);
            final line = e == 0 ? tr('زي زراعة القمح في ١٥ نوفمبر', 'Same as sowing wheat on 15 November') : (e > 0 ? tr('أكتر بـ${daysN(e)} من زراعته في ١٥ نوفمبر', '${daysN(e)} more than sowing on 15 November') : tr('أقل بـ${daysN(-e)} من زراعته في ١٥ نوفمبر', '${daysN(-e)} fewer than sowing on 15 November'));
            return _row(r, '${daysDigitsN(r.heatMedian.round())} ${tr('حر', 'of heat')}', '${tr('وقت امتلاء حبوب القمح', 'During wheat grain filling')} (${dateN(r.input.wheatSowing)}): $line', color, bar: r.heatMedian / 25);
          }(),
      ], details: [
        _small(tr('أيام الحر هنا فوق ٣٢°. الأرقام للمقارنة بين المواعيد.', 'Hot days here are above 32 degrees. The numbers are for comparing dates.')),
      ]);

  Widget _salt() {
    if (c.rows.first.saltSummer == null) {
      return _shell([SoftCard(child: Text(tr('مقلتليش على الملوحة. لو في بقع أو قشرة بيضا في الأرض أو عملت تحليل، ابدأ من جديد وقولي.', 'I was not told about salt. If there are patches or a white crust, or you had a soil test, start again and tell me.'), style: const TextStyle(fontSize: 16, height: 1.5)))]);
    }
    return _shell([
      for (final r in c.rows)
        () {
          final s = r.saltSummer!;
          final w = r.saltWheat;
          final color = Fs.status(s.status);
          return _row(r, '${saltN(s.status)}${s.yieldPct != null ? ' · ${nd(s.yieldPct!)}٪' : ''}', '${cropN(r.input.crop)}${w != null ? '، ${tr('والقمح', 'and wheat')}: ${saltN(w.status)}' : ''}', color, bar: (s.yieldPct ?? 0) / 100);
        }(),
    ], details: [
      if (c.saltBasisAssumed) _small(tr('ده تقدير من العلامات اللي وصفتها. تحليل التربة أدق.', 'This is estimated from the signs you described. A soil test is more exact.')),
      _small(tr('النسبة هي قدرة المحصول على تحمّل ملوحة أرضك حسب جداول الفاو.', "The percentage is how well the crop tolerates your soil's salt, from the FAO tables.")),
    ]);
  }
}
