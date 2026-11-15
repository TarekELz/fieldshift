// Welcome screen: black canvas, huge headline, circular go button, Earth horizon drawn in code.
import 'package:flutter/material.dart';

import 'ui_kit.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: EarthHorizon()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Fs.teal, width: 2), boxShadow: [BoxShadow(color: Fs.teal.withValues(alpha: 0.4), blurRadius: 18)]),
                child: const Icon(Icons.eco_rounded, color: Fs.teal, size: 30),
              ),
              const SizedBox(height: 40),
              const Text('اعرف أرضك\nقبل ما تزرع', style: TextStyle(fontSize: 46, height: 1.15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Directionality(textDirection: TextDirection.ltr, child: Text('Know your field before you sow', style: TextStyle(fontSize: 16, color: Fs.dim))),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onStart,
                child: Row(children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6)),
                    child: const Icon(Icons.arrow_back_rounded, size: 30), // forward points left in right-to-left layouts
                  ),
                  const SizedBox(width: 16),
                  const Text('يلا بينا!', style: TextStyle(fontSize: 17, letterSpacing: 0.5, color: Fs.dim)),
                ]),
              ),
              const Spacer(),
              const Text('مساعد صوتي بالعربي لدورتك الزراعية\nببيانات ناسا في دلتا النيل', style: TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
              const Directionality(textDirection: TextDirection.ltr, child: Text('Arabic voice assistant for Nile Delta crop rotation, using NASA data', style: TextStyle(fontSize: 11, color: Fs.dim))),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ]),
    );
  }
}
