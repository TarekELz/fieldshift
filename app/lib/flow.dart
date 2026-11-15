// The guided screen: one question at a time (Eyad on top, the question in big type, big answer buttons or the map, a big
// mic button). It replaces the old scrolling chat. The dialogue logic is unchanged (dialogue.dart); only the way it
// is shown changed. Language comes from i18n.dart, so the whole screen switches between Arabic and English.
import 'package:flutter/material.dart' hide Step;

import 'dialogue.dart';
import 'engine.dart';
import 'eyad.dart';
import 'i18n.dart';
import 'map_picker.dart';
import 'result_view.dart';
import 'ui_kit.dart';
import 'voice.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key, required this.onHome, this.speakReplies = true, this.demo = false});
  final VoidCallback onHome;
  final bool speakReplies;
  final bool demo; // preview only: answer the questions with a sample farmer
  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  final voice = Voice();
  final input = TextEditingController();
  final focus = FocusNode();
  Dialogue? dialogue;
  String? loadError;
  BotMessage? current, note;
  bool listening = false, typing = false;
  String partial = '';
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    voice.muted = !widget.speakReplies;
    lang.addListener(_onLang);
    voice.listeningNow.addListener(_onListenEnd);
    _start();
  }

  @override
  void dispose() {
    lang.removeListener(_onLang);
    voice.listeningNow.removeListener(_onListenEnd);
    voice.stopSpeaking(); // pressing Back must not leave Eyad talking
    voice.stopListening();
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheEyad(context);
      precacheImage(const AssetImage('assets/img/delta_winter.jpg'), context);
    }
  }

  void _onListenEnd() {
    if (!voice.listeningNow.value && listening && mounted) setState(() => listening = false); // a timeout or an error ends the listening screen too
  }

  void _onLang() {
    voice.stopSpeaking();
    voice.setLanguage(isAr);
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    try {
      final data = await EngineData.load();
      registerSiteNames(data);
      dialogue = Dialogue(data);
      await voice.init();
      await voice.setLanguage(isAr);
      current = dialogue!.opening();
      if (widget.demo) {
        for (final a in ['gharbia', 'rice', '06-15', '12-01', '10', 'patches']) {
          current = dialogue!.handle(a).last;
        }
      }
      if (mounted) setState(() {});
      if (!widget.demo) voice.speak(msgText(current!));
    } catch (e) {
      if (mounted) setState(() => loadError = '$e');
    }
  }

  void _apply(List<BotMessage> replies) {
    final main = replies.last;
    final n = (replies.length > 1 && replies.first.note) ? replies.first : null;
    setState(() {
      current = main;
      note = n;
      partial = '';
    });
    input.clear();
    if (typing) focus.requestFocus(); // keep the keyboard open between typed answers
    voice.speak(main.result != null ? spokenN(main.result!) : '${n != null ? '${msgText(n)} ' : ''}${msgText(main)}');
  }

  void send(String text) {
    final d = dialogue;
    if (d == null || text.trim().isEmpty) return;
    voice.stopSpeaking();
    _apply(d.handle(text));
  }

  void _pickLocation(double lat, double lon) {
    final d = dialogue;
    if (d == null) return;
    voice.stopSpeaking();
    _apply(d.handleLocation(lat, lon));
  }

  void _restart() {
    final d = dialogue;
    if (d == null) return;
    voice.stopSpeaking();
    d.reset();
    setState(() {
      current = d.opening();
      note = null;
    });
    voice.speak(msgText(current!));
  }

  void _readAgain() {
    final m = current;
    if (m == null) return;
    voice.speak(m.result != null ? spokenN(m.result!) : msgText(m));
  }

  Future<void> _holdStart() async {
    if (!listening) await _toggleMic();
  }

  Future<void> _holdEnd() async {
    if (listening) await _toggleMic();
  }

  Future<void> _toggleMic() async {
    if (listening) {
      await voice.stopListening();
      setState(() => listening = false);
      return;
    }
    if (!voice.canListen) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('الميكروفون مش شغال على الموبايل ده. اكتب أو اختار من الأزرار.', 'The microphone is not available on this phone. Type or tap an answer.'))));
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

  EyadMood get _mood {
    if (listening) return EyadMood.main;
    final m = current;
    if (m == null) return EyadMood.main;
    if (m.result != null) {
      if (m.result!.caveatKind == 'sea') return EyadMood.surprised;
      return m.result!.rows.any((r) => r.warnings.isNotEmpty) ? EyadMood.worried : EyadMood.success;
    }
    if (m.retry) return EyadMood.thoughtful;
    return dialogue?.step == Step.site ? EyadMood.main : EyadMood.guiding;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lookChanged,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${tr('تعذر تحميل البيانات', 'Could not load the data')}:\n$loadError')))
              : Column(children: [
                  _topBar(),
                  Expanded(child: dialogue == null || current == null ? Center(child: CircularProgressIndicator(color: Fs.accent)) : (current!.result != null ? _result() : _question())),
                ]),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          RoundButton(icon: Icons.arrow_back_rounded, onTap: widget.onHome, tooltip: tr('رجوع', 'Back')),
          const Spacer(),
          const LangPill(),
          const SizedBox(width: 8),
          const ThemeButton(),
          const Spacer(),
          RoundButton(icon: Icons.refresh_rounded, onTap: _restart, tooltip: tr('ابدأ من جديد', 'Start again')),
        ]),
      );

  Widget _result() => ResultView(
        c: current!.result!,
        data: dialogue!.data,
        mood: _mood,
        onRestart: _restart,
        onReadAloud: _readAgain,
        onSpeak: (s) => voice.speak(s),
      );

  List<String> _answered() {
    final d = dialogue!;
    return [
      if (d.site != null) siteN(d.site!),
      if (d.crop != null) '${cropN(d.crop!)}${d.summerSowing != null ? ' · ${dateN(d.summerSowing!)}' : ''}',
      if (d.wheatSowing != null) '${cropN('wheat')} · ${dateN(d.wheatSowing!)}',
      if (d.interval != null) tr('ري كل ${nd(d.interval!)} يوم', 'every ${d.interval} days'),
    ];
  }

  Widget _question() {
    final d = dialogue!, m = current!;
    final done = [d.site, d.crop, d.summerSowing, d.wheatSowing, d.interval, d.salt].where((e) => e != null).length;
    final chips = _answered();
    final compact = m.showMap; // the map needs the room
    return Column(children: [
      SizedBox(height: compact ? 2 : 10),
      ValueListenableBuilder<bool>(
        valueListenable: voice.speaking,
        builder: (context, speaking, _) => GestureDetector(
          onTap: _readAgain, // tap Eyad to hear the question again
          onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('آخر صوت', 'Last voice')}: ${voice.lastNote}'), duration: const Duration(seconds: 6))),
          child: EyadAvatar(mood: _mood, size: compact ? 84 : 148, progress: done / 6, active: speaking || listening),
        ),
      ),
      const SizedBox(height: 2),
      Text(tr('إياد', 'Eyad'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Fs.dim)),
      ValueListenableBuilder<bool>(
        valueListenable: voice.aiVoice,
        builder: (context, ai, _) => AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: ai
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(12)),
                    child: Text(tr('صوت مولَّد بالذكاء الاصطناعي', 'AI-generated voice'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Fs.dim)),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
      const SizedBox(height: 8),
      _bubble(msgText(m), compact),
      if (note != null) Padding(padding: const EdgeInsets.fromLTRB(28, 6, 28, 0), child: Text(msgText(note!), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: Fs.dim))),
      if (chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: Fs.ok),
              for (final c in chips)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(20)),
                  child: Text(c, style: TextStyle(fontSize: 12, color: Fs.text, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _answers(m, d))),
      if (listening || partial.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), child: Text(partial.isEmpty ? tr('بسمعك... اتكلم دلوقتي', 'Listening... speak now') : partial, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Fs.accent))),
      _bottom(),
    ]);
  }

  /// Eyad's words in a speech bubble with a small tail pointing up at him.
  Widget _bubble(String text, bool compact) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 10 : 16),
            decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(Fs.radiusCard), boxShadow: Fs.lift),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: compact ? 18 : 22, height: 1.35, fontWeight: FontWeight.w700)),
          ),
          Positioned(
            top: -6,
            child: Transform.rotate(angle: 0.785398, child: Container(width: 14, height: 14, color: Fs.card)),
          ),
        ]),
      );

  IconData? _iconFor(Choice c, Step s) {
    if (s != Step.crop) return null;
    return const {'rice': Icons.rice_bowl_rounded, 'maize': Icons.eco_rounded, 'cotton': Icons.cloud_rounded}[c.value];
  }

  Widget _answers(BotMessage m, Dialogue d) {
    final tiles = <Widget>[];
    final w = (MediaQuery.of(context).size.width - 32 - 12) / 2;
    for (final c in m.choices) {
      final dim = c.value == 'skip';
      final icon = _iconFor(c, d.step);
      tiles.add(SizedBox(
        width: m.showMap ? null : w,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Fs.radiusTile),
            onTap: () => send(c.value),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: m.showMap ? 14 : 12, vertical: m.showMap ? 8 : 16),
              decoration: BoxDecoration(color: dim ? Colors.transparent : Fs.card, borderRadius: BorderRadius.circular(Fs.radiusTile), border: dim ? Border.all(color: Fs.line) : null, boxShadow: dim ? null : Fs.lift),
              child: Row(mainAxisSize: m.showMap ? MainAxisSize.min : MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 22, color: Fs.accent), const SizedBox(width: 8)],
                Flexible(child: Text(choiceLabel(c, d.step), textAlign: TextAlign.center, style: TextStyle(fontSize: m.showMap ? 14 : 17, fontWeight: FontWeight.w600, color: dim ? Fs.dim : Fs.text))),
              ]),
            ),
          ),
        ),
      ));
    }
    if (m.showMap) {
      return Column(children: [
        MapPicker(data: d.data, onPick: _pickLocation),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: tiles),
      ]);
    }
    return Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: tiles);
  }

  Widget _bottom() {
    if (typing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: input,
              focusNode: focus,
              autofocus: true,
              textInputAction: TextInputAction.send,
              onSubmitted: (v) {
                send(v);
                focus.requestFocus();
              },
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: tr('اكتب ردك هنا', 'Type your answer'),
                filled: true,
                fillColor: Fs.card2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Fs.radiusTile), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Fs.radiusTile), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoundButton(icon: Icons.send_rounded, onTap: () => send(input.text), tooltip: tr('ابعت', 'Send')),
          const SizedBox(width: 6),
          RoundButton(icon: Icons.close_rounded, onTap: () => setState(() => typing = false), tooltip: tr('إغلاق', 'Close')),
        ]),
      );
    }
    return Stack(alignment: Alignment.bottomCenter, children: [
      Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
      Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          RoundButton(icon: Icons.keyboard_alt_rounded, onTap: () => setState(() => typing = true), tooltip: tr('اكتب', 'Type')),
          const SizedBox(height: 4),
          Text(tr('اكتب', 'Type'), style: TextStyle(fontSize: 11, color: Fs.dim)),
        ]),
        GestureDetector(
          onTap: _toggleMic,
          onLongPressStart: (_) => _holdStart(),
          onLongPressEnd: (_) => _holdEnd(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening ? Fs.accent : Fs.card,
              border: Border.all(color: Fs.accent, width: 2),
            ),
            child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, size: 36, color: listening ? Fs.onAccent : Fs.accent),
          ),
          const SizedBox(height: 4),
          Text(listening ? tr('سيب لما تخلص', 'Release when done') : tr('اضغط وكلّم', 'Press and talk'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Fs.text)),
          ]),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          RoundButton(icon: Icons.volume_up_rounded, onTap: _readAgain, tooltip: tr('اسمع تاني', 'Hear again')),
          const SizedBox(height: 4),
          Text(tr('اسمع', 'Listen'), style: TextStyle(fontSize: 11, color: Fs.dim)),
        ]),
      ]),
    ),
    ]);
  }
}

/// Two soft green hills along the bottom: a calm field behind the mic (decoration only).
class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final dark = Fs.dark;
    final a = Paint()..color = dark ? const Color(0xFF14402B) : const Color(0xFFCFE8D5);
    final b = Paint()..color = dark ? const Color(0xFF1B5337) : const Color(0xFFB5DBBF);
    canvas.drawOval(Rect.fromLTWH(-s.width * 0.25, s.height * 0.55, s.width * 0.9, s.height * 1.2), a);
    canvas.drawOval(Rect.fromLTWH(s.width * 0.3, s.height * 0.7, s.width * 1.0, s.height * 1.2), b);
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => false;
}
