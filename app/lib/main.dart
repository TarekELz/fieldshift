// Field Shift: a voice assistant for Nile Delta farmers (NASA Space Apps 2026).
// The farmer talks (or types, or taps); the assistant asks six questions and answers with a
// comparison of the farmer's rotation against two alternatives, using NASA POWER weather and
// FAO tables through the engines in engine.dart. It supports, and does not replace, local expertise.
import 'package:flutter/material.dart';

import 'arabic.dart';
import 'dialogue.dart';
import 'engine.dart';
import 'voice.dart';

void main() => runApp(const FieldShiftApp());

class FieldShiftApp extends StatelessWidget {
  const FieldShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Shift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ChatScreen(),
    );
  }
}

class ChatItem {
  ChatItem.bot(this.msg) : fromUser = false, text = msg!.ar;
  ChatItem.user(this.text) : fromUser = true, msg = null;
  final bool fromUser;
  final String text;
  final BotMessage? msg;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final voice = Voice();
  final input = TextEditingController();
  final scroll = ScrollController();
  final items = <ChatItem>[];
  Dialogue? dialogue;
  String? loadError;
  bool listening = false;
  String partial = '';

  @override
  void initState() {
    super.initState();
    _start();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primaryContainer,
        title: const Text('فيلد شيفت  Field Shift'),
        actions: [
          IconButton(
            tooltip: 'ابدأ من جديد',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final d = dialogue;
              if (d == null) return;
              d.reset();
              setState(() => items.clear());
              final first = d.opening();
              setState(() => items.add(ChatItem.bot(first)));
              voice.speak(first.ar);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: loadError != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل البيانات:\n$loadError')))
            : Column(children: [
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _bubble(items[i], isLast: i == items.length - 1),
                  ),
                ),
                if (listening || partial.isNotEmpty)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(partial.isEmpty ? 'بسمعك... اتكلم دلوقتي' : partial, style: TextStyle(color: scheme.primary))),
                _inputBar(scheme),
              ]),
      ),
    );
  }

  Widget _bubble(ChatItem it, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    if (it.fromUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
          child: Text(it.text, style: const TextStyle(fontSize: 17)),
        ),
      );
    }
    final m = it.msg!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.ar, style: const TextStyle(fontSize: 18, height: 1.4)),
            if (m.en != null) Padding(padding: const EdgeInsets.only(top: 2), child: Directionality(textDirection: TextDirection.ltr, child: Text(m.en!, style: TextStyle(fontSize: 12, color: scheme.outline)))),
            if (m.result != null) ResultCard(m.result!),
            if (isLast && m.choices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final c in m.choices) ActionChip(label: Text(c.label), onPressed: () => send(c.value, shown: c.label)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _inputBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: input,
            textInputAction: TextInputAction.send,
            onSubmitted: send,
            decoration: InputDecoration(hintText: 'اكتب ردك هنا', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(onPressed: () => send(input.text), icon: const Icon(Icons.send), tooltip: 'ابعت'),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            heroTag: 'mic',
            backgroundColor: listening ? Colors.red : scheme.primary,
            foregroundColor: Colors.white,
            onPressed: toggleMic,
            child: Icon(listening ? Icons.stop : Icons.mic, size: 32),
          ),
        ),
      ]),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard(this.c, {super.key});
  final Comparison c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.caveat != null)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
          child: const Text('تنبيه: بيانات الطقس للمنطقة دي مش دقيقة (قريبة من البحر). ما تعتمدش على أرقام الحر هنا.', style: TextStyle(fontSize: 13)),
        ),
      for (final r in c.rows) _rowCard(r, scheme),
      if (c.intervalDays != null && c.rows.first.turnMm != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('مع ري كل ${arDigits(c.intervalDays!)} يوم: كل مرة لازم توصل ${arDigits(c.rows.first.turnMm!)} مم على الأقل في أيام الذروة (استهلاك المحصول بس).', style: const TextStyle(fontSize: 14)),
        ),
      const SizedBox(height: 8),
      Text(arSources, style: TextStyle(fontSize: 12, color: scheme.outline)),
      Text(arNotModelled, style: TextStyle(fontSize: 12, color: scheme.outline)),
      const SizedBox(height: 4),
      Text(arNotice, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text('Supports, does not replace, local expertise. Weather: NASA POWER 1990-2025 (about 50 km cell). Salt: farmer input + FAO paper 29.', style: TextStyle(fontSize: 11, color: scheme.outline)),
      ),
    ]);
  }

  Widget _tag(String t, Color color) => Container(
        margin: const EdgeInsetsDirectional.only(end: 4, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(t, style: TextStyle(fontSize: 10, color: color)),
      );

  Widget _rowCard(RotationRow r, ColorScheme scheme) {
    final heatExtra = r.extra['32']!;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: r.isExisting ? scheme.secondaryContainer : scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.isExisting ? 'دورتك الحالية' : 'بديل'}: ${arCrop[r.input.crop]} ثم قمح', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text('${arCrop[r.input.crop]} بتتزرع ${arDate(r.input.summerSowing)} وتتحصد تقريباً ${r.harvest}. القمح ${arDate(r.input.wheatSowing)}${r.isExisting ? '' : ' (افتراض)'}.', style: const TextStyle(fontSize: 13)),
          const Divider(),
          Row(children: [const Text('💧 '), Expanded(child: Text('مية ${arCrop[r.input.crop]}: ${arRatio(r.ratio)}', style: const TextStyle(fontSize: 15)))]),
          Wrap(children: [_tag('NASA POWER + FAO-56', Colors.blue), _tag('~${arDigits(r.etc)} مم (غير مؤكد)', Colors.grey), if (r.riceFloor) _tag('الرز: الرقم أقل من الحقيقي', Colors.orange)]),
          const SizedBox(height: 6),
          Row(children: [const Text('🌡️ '), Expanded(child: Text('حر وقت امتلاء حبوب القمح: ${arDigits(r.heatMedian.round())} يوم فوق ٣٢° (من ${arDigits(r.heatP10.round())} لـ ${arDigits(r.heatP90.round())})', style: const TextStyle(fontSize: 15)))]),
          Wrap(children: [
            _tag('NASA POWER', Colors.blue),
            _tag(r.input.wheatSowing == '11-15' ? 'الميعاد المعتاد' : (heatExtra >= 0 ? '+${arDigits(heatExtra)} يوم عن ١٥ نوفمبر' : '-${arDigits(-heatExtra)} يوم عن ١٥ نوفمبر'), Colors.grey),
            _tag('افتراضات النموذج', Colors.orange),
          ]),
          if (r.saltSummer != null) ...[
            const SizedBox(height: 6),
            Row(children: [const Text('🧂 '), Expanded(child: Text('الملوحة: ${arCrop[r.input.crop]} ${arSalt[r.saltSummer!.status]}، القمح ${arSalt[r.saltWheat!.status]}', style: const TextStyle(fontSize: 15)))]),
            Wrap(children: [_tag('جداول FAO 29', Colors.green), _tag('من كلام المزارع', Colors.purple)]),
          ],
          for (final w in r.warnings) Padding(padding: const EdgeInsets.only(top: 6), child: Text('⚠️ ${warningAr(r, w)}', style: const TextStyle(fontSize: 13, color: Colors.red))),
        ]),
      ),
    );
  }
}
