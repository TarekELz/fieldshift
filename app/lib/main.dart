// Field Shift: a voice assistant for Nile Delta farmers (NASA Space Apps 2026).
// The farmer answers six short questions (by voice, typing or tapping, or on the map) and gets a comparison of his
// rotation against two alternatives, using NASA POWER weather and FAO tables through the engines in engine.dart.
// It supports, and does not replace, local expertise. Arabic (default) and English, one at a time (i18n.dart).
import 'package:flutter/material.dart';

import 'flow.dart';
import 'i18n.dart';
import 'ui_kit.dart';
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
      builder: (context, child) => ValueListenableBuilder<String>(
        valueListenable: lang,
        builder: (context, l, _) => Directionality(textDirection: l == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!),
      ),
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
            ? Onboarding(
                key: const ValueKey('setup'),
                onDone: (speakReplies) => setState(() {
                  speak = speakReplies;
                  setup = false;
                }),
              )
            : FlowScreen(key: const ValueKey('flow'), speakReplies: speak, onHome: () => setState(() => setup = true)),
      );
}
