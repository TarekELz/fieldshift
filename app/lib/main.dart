// Field Shift: a voice assistant for Nile Delta farmers (NASA Space Apps 2026).
// The farmer talks (or types, or taps); the assistant asks six questions and answers with a
// comparison of the farmer's rotation against two alternatives, using NASA POWER weather and
// FAO tables through the engines in engine.dart. It supports, and does not replace, local expertise.
import 'package:flutter/material.dart';

import 'arabic.dart';
import 'dialogue.dart';
import 'engine.dart';
import 'eyad.dart';
import 'map_picker.dart';
import 'ui_kit.dart';
import 'voice.dart';
import 'welcome.dart';

void main() => runApp(const FieldShiftApp());

class FieldShiftApp extends StatelessWidget {
  const FieldShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Shift',
      debugShowCheckedModeBanner: false,
      theme: Fs.theme(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool setup = true;
  bool speak = true;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: setup
            ? Onboarding(key: const ValueKey('w'), onDone: (speakReplies) => setState(() {
                  speak = speakReplies;
                  setup = false;
                }))
            : ChatScreen(key: const ValueKey('c'), speakReplies: speak, onHome: () => setState(() => setup = true)),
      );
}

class ChatItem {
  ChatItem.bot(this.msg) : fromUser = false, text = msg!.ar;
  ChatItem.user(this.text) : fromUser = true, msg = null;
  final bool fromUser;
  final String text;
  final BotMessage? msg;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.onHome, this.speakReplies = true});
  final VoidCallback onHome;
  final bool speakReplies; // from the setup screens: should Eyad read his replies aloud?
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final voice = Voice();
  final input = TextEditingController();
  final inputFocus = FocusNode();
  final scroll = ScrollController();
  final items = <ChatItem>[];
  Dialogue? dialogue;
  String? loadError;
  bool listening = false;
  String partial = '';

  @override
  void initState() {
    super.initState();
    voice.muted = !widget.speakReplies;
    _start();
  }

  bool _precached = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheEyad(context);
    }
  }

  Future<void> _start() async {
    try {
      final data = await EngineData.load();
      dialogue = Dialogue(data);
      await voice.init();
      final first = dialogue!.opening();
      setState(() => items.add(ChatItem.bot(first)));
      voice.speak(first.ar);
    } catch (e) {
      setState(() => loadError = '$e');
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  void send(String text, {String? shown}) {
    final d = dialogue;
    if (d == null || text.trim().isEmpty) return;
    voice.stopSpeaking();
    final replies = d.handle(text);
    setState(() {
      items.add(ChatItem.user(shown ?? text));
      for (final r in replies) {
        items.add(ChatItem.bot(r));
      }
      partial = '';
    });
    input.clear();
    _scrollDown();
    // Read the full result if there is one, otherwise everything the assistant just said.
    final withSpoken = replies.where((r) => r.spoken != null);
    voice.speak(withSpoken.isNotEmpty ? withSpoken.first.spoken! : replies.map((r) => r.ar).join(' '));
  }

  EyadMood get _mood {
    if (listening) return EyadMood.main;
    final bots = items.where((i) => !i.fromUser).toList();
    if (bots.isEmpty) return EyadMood.excited;
    final m = bots.last.msg!;
    if (m.result != null) {
      if (m.result!.caveatKind == 'sea') return EyadMood.surprised;
      return m.result!.rows.any((r) => r.warnings.isNotEmpty) ? EyadMood.worried : EyadMood.success;
    }
    if (m.retry) return EyadMood.thoughtful;
    return items.length <= 1 ? EyadMood.excited : EyadMood.guiding;
  }

  /// The farmer tapped a place on the map.
  void _pickLocation(double lat, double lon) {
    final d = dialogue;
    if (d == null) return;
    voice.stopSpeaking();
    final before = d.site;
    final replies = d.handleLocation(lat, lon);
    setState(() {
      items.add(ChatItem.user(d.site != before && d.site != null ? '📍 ${arSite[d.site]}' : '📍 على الخريطة'));
      for (final r in replies) {
        items.add(ChatItem.bot(r));
      }
    });
    _scrollDown();
    voice.speak(replies.map((r) => r.ar).join(' '));
  }

  void _restart() {
    final d = dialogue;
    if (d == null) return;
    voice.stopSpeaking();
    d.reset();
    setState(() => items.clear());
    final first = d.opening();
    setState(() => items.add(ChatItem.bot(first)));
    voice.speak(first.ar);
  }

  Future<void> toggleMic() async {
    if (listening) {
      await voice.stopListening();
      setState(() => listening = false);
      return;
    }
    if (!voice.canListen) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('الميكروفون مش شغال على الموبايل ده${voice.lastError != null ? ' (${voice.lastError})' : ''}. اكتب أو اختار من الأزرار.')));
      return;
    }
    await voice.stopSpeaking();
    setState(() => listening = true);
    await voice.listen((text, isFinal) {
      if (!mounted) return;
      setState(() => partial = text);
      if (isFinal) {
        setState(() => listening = false);
        if (text.trim().isNotEmpty) send(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loadError != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل البيانات:\n$loadError')))
            : Column(children: [
                _topBar(),
                _header(),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _bubble(items[i], isLast: i == items.length - 1),
                  ),
                ),
                if (listening || partial.isNotEmpty)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(partial.isEmpty ? 'بسمعك... اتكلم دلوقتي' : partial, style: const TextStyle(color: Fs.teal, fontSize: 16)))),
                _inputBar(),
              ]),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          RoundButton(icon: Icons.arrow_back_rounded, onTap: widget.onHome, tooltip: 'رجوع'),
          const Expanded(child: Center(child: Text('إياد', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)))),
          RoundButton(icon: Icons.refresh_rounded, onTap: _restart, tooltip: 'ابدأ من جديد'),
        ]),
      );

  /// Eyad's avatar inside a ring that shows progress through the six questions, with a summary of the answers so far.
  Widget _header() {
    final d = dialogue;
    if (d == null) return const SizedBox(height: 8);
    final answered = [d.site, d.crop, d.summerSowing, d.wheatSowing, d.interval, d.salt].where((e) => e != null).length;
    final parts = <String>[
      if (d.site != null) arSite[d.site]!,
      if (d.crop != null) '${arCrop[d.crop]}${d.summerSowing != null ? ' ${arDate(d.summerSowing!)}' : ''}',
      if (d.wheatSowing != null) 'قمح ${arDate(d.wheatSowing!)}',
      if (d.interval != null) 'ري كل ${arDigits(d.interval!)} يوم',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: Fs.line)),
      child: Row(children: [
        EyadAvatar(mood: _mood, size: 84, progress: answered / 6),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('إياد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: Fs.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('مساعد ذكي AI', style: TextStyle(fontSize: 10, color: Fs.teal)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(parts.isEmpty ? 'جاوب على الأسئلة وأنا هقارن لك (${arDigits(answered)}/٦)' : '${parts.join(' · ')}  (${arDigits(answered)}/٦)', style: const TextStyle(fontSize: 13, color: Fs.dim, height: 1.3)),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(ChatItem it, {required bool isLast}) {
    if (it.fromUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Fs.teal.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Fs.teal.withValues(alpha: 0.5))),
          child: Text(it.text, style: const TextStyle(fontSize: 17)),
        ),
      );
    }
    final m = it.msg!;
    final children = <Widget>[
      Text(m.ar, style: const TextStyle(fontSize: 18, height: 1.45)),
      if (m.en != null) Padding(padding: const EdgeInsets.only(top: 3), child: Directionality(textDirection: TextDirection.ltr, child: Text(m.en!, style: const TextStyle(fontSize: 12, color: Fs.dim)))),

      if (m.showMap && isLast) Padding(padding: const EdgeInsets.only(top: 10), child: MapPicker(data: dialogue!.data, onPick: _pickLocation)),
    ];
    final chips = (isLast && m.choices.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in m.choices)
                ActionChip(
                  label: Text(c.label, style: const TextStyle(fontSize: 15)),
                  backgroundColor: Fs.card2,
                  side: BorderSide(color: Fs.teal.withValues(alpha: 0.55)),
                  shape: const StadiumBorder(),
                  onPressed: () => send(c.value, shown: c.label),
                ),
            ]),
          )
        : null;
    if (m.result != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ResultCard(m.result!, dialogue!.data),
        if (chips != null) chips,
      ]);
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: Fs.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...children, if (chips != null) chips]),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(30), border: Border.all(color: Fs.line)),
            padding: const EdgeInsetsDirectional.only(start: 18, end: 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  textInputAction: TextInputAction.send,
                  focusNode: inputFocus,
                  onSubmitted: (v) {
                    send(v);
                    inputFocus.requestFocus(); // keep the keyboard open for typed answers
                  },
                  decoration: const InputDecoration(hintText: 'اكتب ردك هنا', border: InputBorder.none),
                ),
              ),
              IconButton(onPressed: () => send(input.text), icon: const Icon(Icons.send_rounded, color: Fs.teal), tooltip: 'ابعت'),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: toggleMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Fs.card2,
              border: Border.all(color: listening ? Fs.orange : Fs.teal, width: 2.4),
              boxShadow: [BoxShadow(color: (listening ? Fs.orange : Fs.teal).withValues(alpha: listening ? 0.7 : 0.4), blurRadius: listening ? 26 : 14)],
            ),
            child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, size: 34, color: listening ? Fs.orange : Fs.teal),
          ),
        ),
      ]),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard(this.c, this.data, {super.key});
  final Comparison c;
  final EngineData data;

  @override
  Widget build(BuildContext context) {
    final maxRatio = c.rows.map((r) => r.ratio).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (caveatAr(c) != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: (c.caveatKind == 'sea' ? Fs.orange : Fs.teal).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: (c.caveatKind == 'sea' ? Fs.orange : Fs.teal).withValues(alpha: 0.6))),
          child: Text('${c.caveatKind == 'sea' ? '⚠️' : 'ℹ️'} ${caveatAr(c)}', style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
      _climateCard(),
      for (final r in c.rows) _rotationCard(r, maxRatio),
      if (c.intervalDays != null && c.rows.first.turnMm != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Fs.line)),
          child: Row(children: [
            const Icon(Icons.water_drop_rounded, color: Fs.teal),
            const SizedBox(width: 10),
            Expanded(child: Text('مع ري كل ${arDigits(c.intervalDays!)} يوم: كل مرة لازم توصل ${arDigits(c.rows.first.turnMm!)} مم على الأقل في أيام الذروة (استهلاك المحصول بس، من غير فاقد).', style: const TextStyle(fontSize: 14, height: 1.4))),
          ]),
        ),
      const SizedBox(height: 12),
      Text(arSources, style: const TextStyle(fontSize: 12, color: Fs.dim, height: 1.4)),
      const SizedBox(height: 2),
      Text(arNotModelled, style: const TextStyle(fontSize: 12, color: Fs.dim, height: 1.4)),
      const SizedBox(height: 8),
      Text(arNotice, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4)),
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(padding: EdgeInsets.only(top: 4), child: Text('Supports, does not replace, local expertise. Weather: NASA POWER 1990-2025 (about 50 km cell). Salt: farmer input + FAO paper 29.', style: TextStyle(fontSize: 11, color: Fs.dim))),
      ),
    ]);
  }

  Widget _tag(String t, Color color) => Container(
        margin: const EdgeInsetsDirectional.only(end: 6, top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(t, style: TextStyle(fontSize: 11, color: color)),
      );

  /// "Your area's weather" card: monthly maximum temperature from NASA POWER with the wheat sowing month marked.
  Widget _climateCard() {
    final month = int.parse(c.rows.first.input.wheatSowing.split('-')[0]);
    final tmax = data.climateVar(c.site, 'T2M_MAX'), tmin = data.climateVar(c.site, 'T2M_MIN');
    final rh = data.climateVar(c.site, 'RH2M'), wind = data.climateVar(c.site, 'WS2M'), rain = data.climateVar(c.site, 'RAIN_MM_MONTH'), sun = data.climateVar(c.site, 'ALLSKY_SFC_SW_DWN');
    Widget mini(IconData i, String v, String l) => Expanded(
          child: Column(children: [
            Icon(i, size: 20, color: Fs.green),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(l, style: const TextStyle(fontSize: 11, color: Fs.dim)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [const Color(0xFF0E2A22), Fs.card]),
        border: Border.all(color: Fs.green.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('طقس ${arSite[c.site]} في ${arMonth[month - 1]}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          _tag('NASA POWER', Fs.teal),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${arNum(tmax[month - 1])}°', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(width: 10),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('عظمى · صغرى ${arNum(tmin[month - 1])}°', style: const TextStyle(fontSize: 13, color: Fs.dim))),
        ]),
        const SizedBox(height: 8),
        MonthChart(values: tmax, markMonth: month),
        const Padding(padding: EdgeInsets.only(top: 2), child: Text('متوسط الحرارة العظمى كل شهر، من ١٩٩٠ لـ ٢٠٢٥ (الدايرة = شهر زراعة القمح)', style: TextStyle(fontSize: 11, color: Fs.dim))),
        const SizedBox(height: 10),
        Row(children: [
          mini(Icons.water_drop_outlined, '${arNum(rh[month - 1])}٪', 'رطوبة'),
          mini(Icons.grain_rounded, '${arNum(rain[month - 1], dec: 1)} مم', 'مطر'),
          mini(Icons.air_rounded, '${arNum(wind[month - 1], dec: 1)} م/ث', 'رياح'),
          mini(Icons.wb_sunny_outlined, '${arNum(sun[month - 1], dec: 1)}', 'شمس'),
        ]),
      ]),
    );
  }

  Widget _rotationCard(RotationRow r, double maxRatio) {
    final heatExtra = r.extra['32']!;
    final crop = arCrop[r.input.crop]!;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Fs.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: r.isExisting ? Fs.teal.withValues(alpha: 0.7) : Fs.line, width: r.isExisting ? 1.4 : 1),
        boxShadow: r.isExisting ? [BoxShadow(color: Fs.teal.withValues(alpha: 0.12), blurRadius: 20)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: r.isExisting ? Fs.teal : Colors.white12, borderRadius: BorderRadius.circular(12)),
            child: Text(r.isExisting ? 'دورتك الحالية' : 'بديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: r.isExisting ? Colors.black : Colors.white70)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('$crop ثم قمح', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text('$crop: زراعة ${arDate(r.input.summerSowing)}، حصاد تقريباً ${arHarvest(r.harvest)}.  القمح: ${arDate(r.input.wheatSowing)}${r.isExisting ? '' : ' (افتراض)'}', style: const TextStyle(fontSize: 13, color: Fs.dim, height: 1.4)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: StatTile(
              icon: Icons.water_drop_rounded,
              label: 'مية $crop مقارنة بدورتك',
              value: '${arNum(r.ratio, dec: 2)}×',
              note: 'حوالي ${arDigits(r.etc)} مم (غير مؤكد)',
              accent: Fs.teal,
              barFraction: r.ratio / maxRatio,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              icon: Icons.thermostat_rounded,
              label: 'أيام فوق ٣٢ درجة وقت امتلاء حبوب القمح',
              value: '${arDigits(r.heatMedian.round())} يوم',
              note: 'قارن بين المواعيد، الرقم نفسه تقريبي. في أغلب السنين من ${arDigits(r.heatP10.round())} لـ ${arDigits(r.heatP90.round())}',
              accent: Fs.orange,
              spark: r.series.isEmpty ? null : r.series,
            ),
          ),
        ]),
        Wrap(children: [
          _tag('NASA POWER + FAO-56', Fs.teal),
          _tag(r.input.wheatSowing == '11-15' ? 'ميعاد القمح المعتاد' : (heatExtra >= 0 ? '+${arDigits(heatExtra)} يوم حر عن ١٥ نوفمبر' : '-${arDigits(-heatExtra)} يوم حر عن ١٥ نوفمبر'), Fs.dim),
          _tag('افتراضات النموذج', Fs.orange),
          if (r.riceFloor) _tag('الرز: الرقم أقل من الحقيقي', Fs.orange),
        ]),
        if (r.saltSummer != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            RingGauge(
              progress: (r.saltSummer!.yieldPct ?? 0) / 100,
              size: 64,
              stroke: 6,
              color: Fs.status(r.saltSummer!.status),
              child: r.saltSummer!.yieldPct == null
                  ? const Text('أقل من\n٥٠٪', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w800))
                  : Text('${arDigits(r.saltSummer!.yieldPct!)}٪', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🧂 الملوحة (قدرة المحصول الصيفي على تحمّل أرضك)', style: TextStyle(fontSize: 13, color: Fs.dim)),
                const SizedBox(height: 4),
                Row(children: [
                  _dot(Fs.status(r.saltSummer!.status)),
                  Text(' $crop: ${arSalt[r.saltSummer!.status]}   ', style: const TextStyle(fontSize: 15)),
                  _dot(Fs.status(r.saltWheat!.status)),
                  Text(' القمح: ${arSalt[r.saltWheat!.status]}', style: const TextStyle(fontSize: 15)),
                ]),
                Wrap(children: [_tag('جداول FAO 29', Fs.green), _tag('من كلام المزارع', const Color(0xFFB388FF))]),
              ]),
            ),
          ]),
        ],
        for (final w in r.warnings)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text('⚠️ ${warningAr(r, w)}', style: const TextStyle(fontSize: 13, color: Fs.red, height: 1.4))),
      ]),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)]));
}
