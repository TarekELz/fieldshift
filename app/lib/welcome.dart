// Setup flow (three screens), laid out like the team's onboarding reference: welcome with Skip / Get started,
// a grid of what the assistant does, then the assistant with option cards and one button.
// The only real setting is the last one: should Eyad read his replies aloud, or only write them.
import 'package:flutter/material.dart';

import 'eyad.dart';
import 'ui_kit.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final void Function(bool speakReplies) onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  bool speak = true;

  void _go(int s) => setState(() => step = s);

  @override
  Widget build(BuildContext context) {
    final pages = [_welcome(), _what(), _how()];
    return Scaffold(
      body: Stack(children: [
        if (step == 0) const Positioned.fill(child: EarthHorizon()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(children: [
              _topBar(),
              Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: KeyedSubtree(key: ValueKey(step), child: pages[step]))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _topBar() => SizedBox(
        height: 48,
        child: Row(children: [
          SizedBox(width: 44, child: step > 0 ? IconButton(onPressed: () => _go(step - 1), icon: const Icon(Icons.arrow_back_rounded), tooltip: 'رجوع') : null),
          const SizedBox(width: 8),
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 250), height: 4, decoration: BoxDecoration(color: i <= step ? Fs.teal : Fs.line, borderRadius: BorderRadius.circular(4)))),
            if (i < 2) const SizedBox(width: 6),
          ],
          const SizedBox(width: 52),
        ]),
      );

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Fs.teal, foregroundColor: Colors.black, shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          onPressed: onTap,
          child: Text(label),
        ),
      );

  // 1. welcome
  Widget _welcome() => Column(children: [
        const Spacer(flex: 2),
        const EyadAvatar(mood: EyadMood.excited, size: 190),
        const SizedBox(height: 14),
        const Text('أنا إياد، مساعدك الذكي', style: TextStyle(fontSize: 15, color: Fs.teal, fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        const Text('إياد بيحسبلك،\nوإنت اللي بتقرر', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, height: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('ميعاد القمح والمية والملوحة\nمن بيانات ناسا في دلتا النيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white70)),
        const Directionality(textDirection: TextDirection.ltr, child: Padding(padding: EdgeInsets.only(top: 6), child: Text('Know your field before you sow', style: TextStyle(fontSize: 12, color: Fs.dim)))),
        const Spacer(flex: 3),
        Row(children: [
          Expanded(flex: 2, child: TextButton(onPressed: () => widget.onDone(true), child: const Text('تخطّي', style: TextStyle(fontSize: 16, color: Fs.dim)))),
          Expanded(flex: 3, child: _primary('يلا نبدأ', () => _go(1))),
        ]),
      ]);

  // 2. what he does
  Widget _what() {
    const cards = [
      (Icons.grass_rounded, 'ميعاد زراعة القمح', 'الحرارة وقت امتلاء الحبوب لكل ميعاد'),
      (Icons.water_drop_rounded, 'احتياج المية', 'محاصيل الصيف قصاد دورتك'),
      (Icons.grain_rounded, 'ملوحة الأرض', 'المحصول هيستحمل أرضك ولا لأ'),
      (Icons.compare_arrows_rounded, 'مقارنة دورات', 'دورتك الحالية قصاد بديلين'),
    ];
    return Column(children: [
      const SizedBox(height: 6),
      const EyadAvatar(mood: EyadMood.guiding, size: 96),
      const SizedBox(height: 10),
      const Text('إياد هيساعدك في إيه؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('من بيانات ناسا وجداول الفاو', style: TextStyle(fontSize: 14, color: Fs.dim)),
      const SizedBox(height: 18),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in cards)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: Fs.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Fs.teal.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(c.$1, color: Fs.teal, size: 22)),
                  const Spacer(),
                  Text(c.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(c.$3, style: const TextStyle(fontSize: 12, height: 1.35, color: Fs.dim)),
                ]),
              ),
          ],
        ),
      ),
      const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('إياد بيدعم خبرتك، ومبيحلش مكانها.', style: TextStyle(fontSize: 12, color: Fs.dim))),
      _primary('التالي', () => _go(2)),
    ]);
  }

  // 3. how to talk
  Widget _how() {
    Widget option(bool value, IconData icon, String title, String sub) {
      final on = speak == value;
      return GestureDetector(
        onTap: () => setState(() => speak = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: on ? Fs.teal.withValues(alpha: 0.10) : Fs.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? Fs.teal : Fs.line, width: on ? 1.6 : 1)),
          child: Row(children: [
            Icon(icon, color: on ? Fs.teal : Fs.dim, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(fontSize: 12.5, height: 1.35, color: Fs.dim)),
            ])),
            Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? Fs.teal : Fs.line),
          ]),
        ),
      );
    }

    return Column(children: [
      const Spacer(),
      const EyadAvatar(mood: EyadMood.main, size: 170),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(18), border: Border.all(color: Fs.line)),
        child: const Text('تحب نتكلم إزاي؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      const Spacer(),
      option(true, Icons.record_voice_over_rounded, 'كلّمني بصوتك', 'إياد بيرد بالصوت، وتقدر تجاوبه بالمايك'),
      const SizedBox(height: 12),
      option(false, Icons.keyboard_alt_rounded, 'هكتب', 'الردود مكتوبة بس، من غير صوت'),
      const SizedBox(height: 22),
      _primary('يلا نبدأ', () => widget.onDone(speak)),
    ]);
  }
}
