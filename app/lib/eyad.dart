// Eyad: the assistant's name and avatar.
// The avatar pictures were supplied by the team and appear to be AI-generated. The competition rules
// require a VISIBLE watermark on AI-generated images, so every avatar carries an "AI" mark. They are also
// acknowledged in the project's acknowledgements and in docs/ai-disclosure.md.
import 'package:flutter/material.dart';

import 'ui_kit.dart';

enum EyadMood { main, excited, thoughtful, success, worried, guiding, surprised }

const _files = {
  EyadMood.main: 'eyad_main',
  EyadMood.excited: 'eyad_excited',
  EyadMood.thoughtful: 'eyad_thoughtful',
  EyadMood.success: 'eyad_success',
  EyadMood.worried: 'eyad_worried',
  EyadMood.guiding: 'eyad_guiding',
  EyadMood.surprised: 'eyad_surprised',
};

/// Preload every expression so switching mood does not flicker.
Future<void> precacheEyad(BuildContext context) async {
  for (final f in _files.values) {
    await precacheImage(AssetImage('assets/eyad/$f.jpg'), context);
  }
}

class EyadAvatar extends StatelessWidget {
  const EyadAvatar({super.key, required this.mood, required this.size, this.progress, this.glow = true});
  final EyadMood mood;
  final double size;
  final double? progress; // when given, a progress ring is drawn around the avatar
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final ring = progress != null ? 7.0 : 3.0;
    final inner = size - ring * 2 - 4;
    final image = ClipOval(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Image.asset('assets/eyad/${_files[mood]}.jpg', key: ValueKey(mood), width: inner, height: inner, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
    final wide = size >= 110;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        if (progress != null)
          RingGauge(progress: progress!, size: size, stroke: 6)
        else
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Fs.teal, width: 2.4), boxShadow: glow ? [BoxShadow(color: Fs.teal.withValues(alpha: 0.4), blurRadius: 18)] : null),
          ),
        image,
        // The visible AI mark on the avatar (the pictures are AI-generated; the team acknowledges this in the
        // project's acknowledgements and AI-use disclosure). Larger on the big avatar so it stays clearly visible.
        Positioned(
          bottom: size * 0.05,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: wide ? 10 : 6, vertical: wide ? 2 : 1),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54, width: 0.6)),
            child: Text('AI', style: TextStyle(fontSize: wide ? 13 : 9, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
