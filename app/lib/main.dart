// Field Shift: a voice assistant for Nile Delta farmers (NASA Space Apps 2026).
// The farmer answers six short questions (by voice, typing or tapping, or on the map) and gets a comparison of his
// rotation against two alternatives, using NASA POWER weather and FAO tables through the engines in engine.dart.
// It supports, and does not replace, local expertise. Arabic (default) and English, one at a time (i18n.dart).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'flow.dart';
import 'i18n.dart';
import 'ui_kit.dart';
import 'welcome.dart';

/// Preview switches for the web build (ignored on a phone): ?theme=light, ?lang=en, ?skip=1 (go straight to the questions),
/// ?demo=1 (also answer them with a sample farmer, to see the result screen).
void main() {
  final q = Uri.base.queryParameters;
  if (q['theme'] == 'light') darkMode.value = false;
  if (q['lang'] == 'en') lang.value = 'en';
  runApp(FieldShiftApp(skipSetup: q['skip'] == '1' || q['demo'] == '1', demo: q['demo'] == '1'));
}

class FieldShiftApp extends StatelessWidget {
  const FieldShiftApp({super.key, this.skipSetup = false, this.demo = false});
  final bool skipSetup, demo;

  @override
  Widget build(BuildContext context) {
    // The theme follows the language: IBM Plex Sans Arabic in Arabic, IBM Plex Sans in English; the layout direction too.
    return ListenableBuilder(
      listenable: lookChanged,
      builder: (context, _) {
        final l = lang.value;
        return MaterialApp(
        title: 'Eyad AI',
        debugShowCheckedModeBanner: false,
        theme: Fs.theme(arabicLang: l == 'ar'),
        builder: (context, child) => _PhoneFrame(child: Directionality(textDirection: l == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!)),
        home: _Root(skipSetup: skipSetup, demo: demo),
        );
      },
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({this.skipSetup = false, this.demo = false});
  final bool skipSetup, demo;
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool setup = !widget.skipSetup;
  bool speak = true;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: setup
            ? Onboarding(
                key: const ValueKey('setup'),
                onDone: (speakReplies) => setState(() {
                  speak = speakReplies;
                  setup = false;
                }),
              )
            : FlowScreen(key: const ValueKey('flow'), speakReplies: widget.demo ? false : speak, demo: widget.demo, onHome: () => setState(() => setup = true)),
      );
}

/// Web preview only: when the browser window is wide (a desktop), show the app inside a phone-sized frame, so the preview
/// looks like what a phone shows. On a phone, and in a narrow window, the app fills the screen as usual.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth <= 600) return child;
      const w = 400.0;
      final h = math.min(c.maxHeight - 32, 860.0);
      return ColoredBox(
        color: Fs.dark ? const Color(0xFF050607) : const Color(0xFFE2E0DA),
        child: Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), border: Border.all(color: Fs.dark ? const Color(0xFF2A2E33) : const Color(0xFFB9B6AE), width: 6)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(w - 12, h - 12)), child: child),
            ),
          ),
        ),
      );
    });
  }
}
