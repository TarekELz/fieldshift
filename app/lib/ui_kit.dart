// Visual kit for Field Shift. Style inspired by three reference apps shared by the team:
// a space-agency app (black canvas, huge bold headlines, circular go button, Earth horizon),
// a car-control app (glowing teal rings, stat tiles with sparklines, orange area chart) and a farm app
// (weather card, green accents). Only the style is borrowed: no logos or images from them.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'i18n.dart';

class Fs {
  static const bg = Color(0xFF05070A);
  static const card = Color(0xFF0F1318);
  static const card2 = Color(0xFF171C22);
  static const line = Color(0xFF242B33);
  static const teal = Color(0xFF19E3D0);
  static const green = Color(0xFF3DDC84);
  static const orange = Color(0xFFFF7A1A);
  static const red = Color(0xFFFF5252);
  static const dim = Color(0xFF8A94A0);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: teal, secondary: green, surface: card, error: red),
        splashFactory: NoSplash.splashFactory,
      );

  static Color status(String s) => s == 'fine' ? green : (s == 'reduced' ? orange : red);
}

/// Glowing progress ring (like the battery gauge in the car app).
class RingGauge extends StatelessWidget {
  const RingGauge({super.key, required this.progress, required this.size, this.color = Fs.teal, this.stroke = 7, this.child});
  final double progress, size, stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(progress.clamp(0.0, 1.0), color, stroke), child: Center(child: child)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.color, this.stroke);
  final double p, stroke;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final r = (math.min(s.width, s.height) - stroke * 2) / 2;
    final center = s.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = Colors.white.withValues(alpha: 0.08));
    if (p <= 0) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.6
      ..color = color.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.1);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = StrokeCap.round;
    c.drawArc(rect, -math.pi / 2, 2 * math.pi * p, false, glow);
    c.drawArc(rect, -math.pi / 2, 2 * math.pi * p, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.p != p || o.color != color;
}

/// Tiny line chart of a series; [mark] draws a horizontal reference (for example the median).
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.color = Fs.teal, this.height = 30, this.mark});
  final List<num> values;
  final Color color;
  final double height;
  final num? mark;

  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(values, color, mark)));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.mark);
  final List<num> v;
  final Color color;
  final num? mark;

  @override
  void paint(Canvas c, Size s) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min).toDouble(), hi = v.reduce(math.max).toDouble();
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    Offset pt(int i, num y) => Offset(s.width * i / (v.length - 1), s.height - 3 - (s.height - 6) * ((y - lo) / span));
    if (mark != null) {
      final y = pt(0, mark!).dy;
      c.drawLine(Offset(0, y), Offset(s.width, y), Paint()..color = Colors.white24..strokeWidth = 1);
    }
    final path = Path()..moveTo(pt(0, v[0]).dx, pt(0, v[0]).dy);
    for (var i = 1; i < v.length; i++) {
      final a = pt(i - 1, v[i - 1]), b = pt(i, v[i]);
      path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    path.lineTo(pt(v.length - 1, v.last).dx, pt(v.length - 1, v.last).dy);
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v;
}

/// Monthly area chart with a marker on one month (like the temperature chart in the car app).
class MonthChart extends StatelessWidget {
  const MonthChart({super.key, required this.values, this.markMonth, this.color = Fs.orange, this.height = 110});
  final List<double> values;
  final int? markMonth; // 1..12
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _AreaPainter(values, markMonth, color)));
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.v, this.mark, this.color);
  final List<double> v;
  final int? mark;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final lo = v.reduce(math.min) - 2, hi = v.reduce(math.max) + 2;
    const topPad = 6.0, bottomPad = 16.0;
    Offset pt(int i) => Offset(s.width * (i + 0.5) / v.length, s.height - bottomPad - (s.height - bottomPad - topPad) * ((v[i] - lo) / (hi - lo)));
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      final a = pt(i - 1), b = pt(i);
      line.cubicTo((a.dx + b.dx) / 2, a.dy, (a.dx + b.dx) / 2, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)..lineTo(pt(v.length - 1).dx, s.height - bottomPad)..lineTo(pt(0).dx, s.height - bottomPad)..close();
    c.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.02)]).createShader(Offset.zero & s));
    c.drawPath(line, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = color);
    const labels = ['ي', 'ف', 'م', 'أ', 'م', 'ي', 'ي', 'أ', 'س', 'أ', 'ن', 'د'];
    for (var i = 0; i < 12; i++) {
      final tp = TextPainter(text: TextSpan(text: labels[i], style: TextStyle(fontSize: 10, color: (mark == i + 1) ? Colors.white : Fs.dim)), textDirection: TextDirection.rtl)..layout();
      tp.paint(c, Offset(pt(i).dx - tp.width / 2, s.height - 13));
    }
    if (mark != null) {
      final p = pt(mark! - 1);
      c.drawLine(Offset(p.dx, p.dy), Offset(p.dx, s.height - bottomPad), Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 1.2);
      c.drawCircle(p, 7, Paint()..color = color.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      c.drawCircle(p, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter o) => o.v != v || o.mark != mark;
}

/// Dark rounded stat tile: icon in a circle, optional sparkline, label and a big value.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.spark, this.accent = Fs.teal, this.note, this.barFraction});
  final IconData icon;
  final String label, value;
  final List<num>? spark;
  final double? barFraction; // 0..1: a thin comparison bar under the value
  final Color accent;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Fs.card2, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: Icon(icon, size: 18, color: accent)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Fs.dim, height: 1.2))),
          ]),
          if (spark != null) Padding(padding: const EdgeInsets.only(top: 8), child: Sparkline(spark!, color: accent, mark: null)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
          if (barFraction != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: barFraction!.clamp(0.0, 1.0), minHeight: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(accent))),
            ),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 11, color: Fs.dim)),
        ]),
      );
}

/// Round dark icon button (like the round buttons in the car app).
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: InkResponse(
          onTap: onTap,
          child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Fs.card2, shape: BoxShape.circle, border: Border.all(color: Fs.line)), child: Icon(icon, size: 22)),
        ),
      );
}

/// Earth-limb horizon with stars, drawn in code (no image needed), for the welcome screen.
class EarthHorizon extends StatelessWidget {
  const EarthHorizon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.expand(child: CustomPaint(painter: _EarthPainter()));
}

class _EarthPainter extends CustomPainter {
  const _EarthPainter();
  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(7);
    for (var i = 0; i < 70; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.8), rnd.nextDouble() * 1.2 + 0.2, Paint()..color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.5));
    }
    final center = Offset(s.width / 2, s.height + s.width * 1.05);
    final r = s.width * 1.55;
    c.drawCircle(center, r + 18, Paint()..color = Fs.teal.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
    c.drawCircle(
      center,
      r,
      Paint()..shader = RadialGradient(center: Alignment.topCenter, radius: 0.5, colors: const [Color(0xFF7FD6FF), Color(0xFF1B5E8C), Color(0xFF04131F)], stops: const [0.0, 0.25, 1.0]).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_EarthPainter o) => false;
}

/// Arabic / English switch: two segments, the active one filled.
class LangPill extends StatelessWidget {
  const LangPill({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: lang,
        builder: (context, l, _) {
          Widget seg(String label, String code) => GestureDetector(
                onTap: () => lang.value = code,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: l == code ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: l == code ? Colors.black : Fs.dim)),
                ),
              );
          return Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: Fs.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [seg('عربي', 'ar'), seg('EN', 'en')]),
          );
        },
      );
}
