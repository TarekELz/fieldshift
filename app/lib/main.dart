// Field Shift: a voice assistant for Nile Delta farmers (NASA Space Apps 2026).
// The farmer answers six short questions (by voice, typing or tapping, or on the map) and gets a comparison of his
// rotation against two alternatives, using NASA POWER weather and FAO tables through the engines in engine.dart.
// It supports, and does not replace, local expertise. Arabic (default) and English, one at a time (i18n.dart).
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
        title: 'Field Shift',
        debugShowCheckedModeBanner: false,
        theme: Fs.theme(arabicLang: l == 'ar'),
        builder: (context, child) => Directionality(textDirection: l == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!),
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
