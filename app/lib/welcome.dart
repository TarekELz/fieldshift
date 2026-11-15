// Setup flow (three screens), laid out like the team's references: a welcome screen with a real NASA picture, huge type
// and a round "go" button (space-agency app); a grid of what Eyad does; then Eyad with option cards and one button
// (onboarding reference). The only real setting is the last one: should Eyad read his replies aloud, or only write them.
// Arabic and English are switched with the pill at the top; one language at a time.
import 'package:flutter/material.dart';

import 'eyad.dart';
import 'i18n.dart';
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
  bool _precached = false;

  void _go(int s) => setState(() => step = s);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage('assets/img/delta_winter.jpg'), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lookChanged,
      builder: (context, _) {
        final pages = [_welcome(), _what(), _how()];
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
              child: Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _topBar()),
                Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: KeyedSubtree(key: ValueKey('$step${lang.value}'), child: step == 0 ? pages[0] : Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: pages[step])))),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar() => SizedBox(
        height: 48,
        child: Row(children: [
          SizedBox(width: 44, child: step > 0 ? IconButton(onPressed: () => _go(step - 1), icon: const Icon(Icons.arrow_back_rounded), tooltip: tr('رجوع', 'Back')) : null),
          const SizedBox(width: 8),
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 250), height: 4, decoration: BoxDecoration(color: i <= step ? Fs.accent : Fs.card2, borderRadius: BorderRadius.circular(4)))),
            if (i < 2) const SizedBox(width: 6),
          ],
          const SizedBox(width: 12),
          const LangPill(),
          const SizedBox(width: 6),
          const ThemeButton(),
        ]),
      );

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Fs.accent, foregroundColor: Fs.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fs.radiusTile)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          onPressed: onTap,
          child: Text(label),
        ),
      );

  // 1. welcome: a real NASA picture of the Delta, Eyad over its edge, huge headline, round go button
  Widget _welcome() => LayoutBuilder(
      builder: (context, cons) => SingleChildScrollView(
            child: ConstrainedBox(constraints: BoxConstraints(minHeight: cons.maxHeight), child: IntrinsicHeight(child: _welcomeBody())),
          ));

  Widget _welcomeBody() => Stack(fit: StackFit.expand, children: [
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          height: 300,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/img/delta_winter.jpg', fit: BoxFit.cover, alignment: const Alignment(0.1, -0.2)),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000), Fs.bg], stops: [0.0, 0.35, 1.0]))),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 210),
          const EyadAvatar(mood: EyadMood.excited, size: 118, glow: false),
          const SizedBox(height: 10),
          Text(tr('أنا إياد، مساعدك الذكي', 'I am Eyad, your AI assistant'), style: TextStyle(fontSize: 14, color: Fs.dim, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TwoWeightHeadline(tr('اعرف أرضك\nقبل ما تزرع', 'Know your field\nbefore you sow'), size: 40),
          const SizedBox(height: 12),
          Text(tr('الطقس من بيانات ناسا،\nوالملوحة من جداول الفاو وكلامك', 'Weather from NASA data,\nsalt from FAO tables and what you tell me'), style: TextStyle(fontSize: 15, height: 1.5, color: Fs.dim)),
          const Spacer(),
          Row(children: [
            GestureDetector(
              onTap: () => _go(1),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Fs.accent),
                child: Icon(Icons.arrow_forward_rounded, size: 30, color: Fs.onAccent), // flips itself in right-to-left layouts
              ),
            ),
            const SizedBox(width: 14),
            Text(tr('يلا بينا!', "LET'S GO!"), style: TextStyle(fontSize: 16, letterSpacing: 0.5, color: Fs.dim)),
            const Spacer(),
            TextButton(onPressed: () => widget.onDone(true), child: Text(tr('تخطّي', 'Skip'), style: TextStyle(fontSize: 16, color: Fs.dim))),
          ]),
          const SizedBox(height: 14),
        ])),
      ]);

  // 2. what he does
  Widget _what() {
    final cards = [
      (Icons.grass_rounded, tr('ميعاد زراعة القمح', 'Wheat sowing date'), tr('حرارة ناسا وقت امتلاء الحبوب لكل ميعاد', 'NASA heat during grain filling, for each date')),
      (Icons.water_drop_rounded, tr('احتياج المية', 'Water need'), tr('محاصيل الصيف قصاد دورتك', 'Summer crops against your rotation')),
      (Icons.grain_rounded, tr('ملوحة الأرض', 'Soil salt'), tr('من جداول الفاو وكلامك عن أرضك', 'From FAO tables and what you tell me')),
      (Icons.compare_arrows_rounded, tr('مقارنة دورات', 'Rotation comparison'), tr('دورتك الحالية قصاد بديلين', 'Your rotation against two alternatives')),
    ];
    return Column(children: [
      const SizedBox(height: 6),
      const EyadAvatar(mood: EyadMood.guiding, size: 96, glow: false),
      const SizedBox(height: 10),
      Text(tr('إياد هيساعدك في إيه؟', 'What can Eyad help with?'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(tr('طقس ناسا وجداول الفاو', 'NASA weather and FAO tables'), style: TextStyle(fontSize: 14, color: Fs.dim)),
      const SizedBox(height: 18),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in cards)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(Fs.radiusCard), boxShadow: Fs.lift),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBubble(c.$1),
                  const Spacer(),
                  Text(c.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(c.$3, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.35, color: Fs.dim)),
                ]),
              ),
          ],
        ),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tr('إياد بيدعم خبرتك، ومبيحلش مكانها.', 'Eyad supports your experience; he does not replace it.'), style: TextStyle(fontSize: 12, color: Fs.dim))),
      _primary(tr('التالي', 'Next'), () => _go(2)),
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
          decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(Fs.radiusCard), border: on ? Border.all(color: Fs.accent, width: 1.6) : null, boxShadow: Fs.lift),
          child: Row(children: [
            Icon(icon, color: on ? Fs.accent : Fs.dim, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(sub, style: TextStyle(fontSize: 12.5, height: 1.35, color: Fs.dim)),
              ]),
            ),
            Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? Fs.accent : Fs.dim),
          ]),
        ),
      );
    }

    return Column(children: [
      const Spacer(),
      const EyadAvatar(mood: EyadMood.main, size: 170, glow: false),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(Fs.radiusTile)),
        child: Text(tr('تحب نتكلم إزاي؟', 'How would you like to talk?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      const Spacer(),
      option(true, Icons.record_voice_over_rounded, tr('كلّمني بصوتك', 'Talk to me'), tr('إياد بيرد بالصوت، وتقدر تجاوبه بالمايك', 'Eyad answers aloud and you can reply with the microphone')),
      const SizedBox(height: 12),
      option(false, Icons.keyboard_alt_rounded, tr('هكتب', "I'll type"), tr('الردود مكتوبة بس، من غير صوت', 'Answers are written only, without sound')),
      const SizedBox(height: 22),
      _primary(tr('يلا نبدأ', "Let's start"), () => widget.onDone(speak)),
    ]);
  }
}
