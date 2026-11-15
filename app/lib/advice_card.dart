// Eyad's advice card at the top of the result: what looks right, what could improve, what to try. The text is a blueprint chosen by CODE from the
// engines' numbers (advice.dart); a Gemini rewrite replaces it only when the guard accepts it. It is an estimate from NASA data, not a promise.
import 'package:flutter/material.dart';

import 'advice.dart';
import 'engine.dart';
import 'i18n.dart';
import 'ui_kit.dart';

class AdviceCard extends StatefulWidget {
  const AdviceCard({super.key, required this.c, this.onSpeak, this.autoSpeak = false, this.onText});
  final Comparison c;
  final void Function(String text)? onSpeak;
  /// Speak the main advice once its final text is ready (after the AI rewording, or at once when there is none).
  final bool autoSpeak;
  final void Function(String text)? onText;
  @override
  State<AdviceCard> createState() => _AdviceCardState();
}

class _AdviceCardState extends State<AdviceCard> {
  AdviceResult? res;
  bool thinking = false;
  int _run = 0;
  bool _spoke = false;

  void _ready() {
    final r = res;
    if (r == null) return;
    widget.onText?.call(r.text);
    if (widget.autoSpeak && !_spoke) {
      _spoke = true;
      widget.onSpeak?.call(r.text);
    }
  }

  @override
  void initState() {
    super.initState();
    lang.addListener(_compute);
    _compute();
  }

  @override
  void dispose() {
    lang.removeListener(_compute);
    super.dispose();
  }

  @override
  void didUpdateWidget(AdviceCard old) {
    super.didUpdateWidget(old);
    if (old.c != widget.c) _compute();
  }

  Future<void> _compute() async {
    final run = ++_run;
    final a = await AdviceData.load();
    final quick = await adviceFor(a, widget.c, keys: const []); // the blueprint text: instant, offline
    if (!mounted || run != _run) return;
    setState(() {
      res = quick;
      thinking = false;
    });
    widget.onText?.call(quick.text);
    final keys = await geminiKeys();
    if (keys.isEmpty) {
      _ready();
      return;
    }
    setState(() => thinking = true);
    final smart = await adviceFor(a, widget.c, keys: keys);
    if (!mounted || run != _run) return;
    setState(() {
      if (smart.ai) res = smart;
      thinking = false;
    });
    _ready();
  }

  @override
  Widget build(BuildContext context) {
    final r = res;
    if (r == null) return const SizedBox.shrink();
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBubble(Icons.tips_and_updates_rounded, size: 34, color: Fs.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('نصيحة إياد', "Eyad's advice"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (thinking) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Fs.accent)),
          if (widget.onSpeak != null) IconButton(onPressed: () => widget.onSpeak!(r.text), icon: Icon(Icons.volume_up_rounded, color: Fs.accent), tooltip: tr('اسمع', 'Listen')),
        ]),
        const SizedBox(height: 8),
        AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(r.text, key: ValueKey(r.text), style: const TextStyle(fontSize: 17, height: 1.5))),
        for (final t in r.also) ...[const SizedBox(height: 8), Text(t, style: TextStyle(fontSize: 15, height: 1.5, color: Fs.dim))],
      ]),
    );
  }
}
