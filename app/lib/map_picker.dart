// Map of Egypt drawn in code from simplified Natural Earth data (public domain): outline, Nile and its
// two Delta branches, Lake Nasser. The farmer taps the Nile Delta to zoom in, then taps his place.
// The tapped point is matched to the nearest of our six NASA data points.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'engine.dart';
import 'ui_kit.dart';

const _lonMin = 24.5, _lonMax = 36.95, _latMin = 21.8, _latMax = 31.9;
final _cosLat = math.cos(26.5 * math.pi / 180);

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, required this.data, required this.onPick});
  final EngineData data;
  final void Function(double lat, double lon) onPick;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> with SingleTickerProviderStateMixin {
  final _ctrl = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  Animation<Matrix4>? _tween;
  ({double lat, double lon})? _pin;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_tween != null) _ctrl.value = _tween!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  double _scale(double w) => w / ((_lonMax - _lonMin) * _cosLat);
  Offset _project(double lon, double lat, double s) => Offset((lon - _lonMin) * _cosLat * s, (_latMax - lat) * s);
  ({double lat, double lon}) _unproject(Offset p, double s) => (lon: p.dx / s / _cosLat + _lonMin, lat: _latMax - p.dy / s);

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _ctrl.value, end: target).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  void _zoomDelta(double w, double h) {
    final s = _scale(w);
    final b = widget.data.deltaBox;
    final c = _project((b[0] + b[2]) / 2, (b[1] + b[3]) / 2, s);
    final deltaW = (b[2] - b[0]) * _cosLat * s;
    final z = (w / (deltaW * 1.1)).clamp(1.0, 10.0);
    _animateTo(Matrix4.translationValues(w / 2, h / 2, 0) * Matrix4.diagonal3Values(z, z, 1) * Matrix4.translationValues(-c.dx, -c.dy, 0));
  }

  void _tap(Offset p, double w, double h) {
    final ll = _unproject(p, _scale(w));
    final zoom = _ctrl.value.getMaxScaleOnAxis();
    if (zoom < 2.2 && insideDelta(widget.data, ll.lat, ll.lon)) {
      _zoomDelta(w, h); // first tap on the Delta zooms in; the next tap picks the place
      return;
    }
    setState(() => _pin = ll);
    widget.onPick(ll.lat, ll.lon);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final s = _scale(w);
      final h = (_latMax - _latMin) * s;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(color: const Color(0xFF070B10), border: Border.all(color: Fs.line), borderRadius: BorderRadius.circular(20)),
            child: InteractiveViewer(
              transformationController: _ctrl,
              minScale: 1,
              maxScale: 10,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tap(d.localPosition, w, h),
                  child: CustomPaint(size: Size(w, h), painter: _EgyptPainter(widget.data, s, _ctrl.value.getMaxScaleOnAxis(), _pin)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('اضغط على الدلتا عشان تكبّرها، وبعدين اضغط على مكان أرضك.', style: TextStyle(fontSize: 12, color: Fs.dim.withValues(alpha: 0.95)))),
          TextButton.icon(onPressed: () => _zoomDelta(w, h), icon: const Icon(Icons.zoom_in_map_rounded, size: 18), label: const Text('الدلتا')),
          TextButton.icon(onPressed: () => _animateTo(Matrix4.identity()), icon: const Icon(Icons.public_rounded, size: 18), label: const Text('مصر')),
        ]),
      ]);
    });
  }
}

class _EgyptPainter extends CustomPainter {
  _EgyptPainter(this.d, this.s, this.zoom, this.pin);
  final EngineData d;
  final double s, zoom;
  final ({double lat, double lon})? pin;

  Offset p(num lon, num lat) => Offset((lon - _lonMin) * _cosLat * s, (_latMax - lat) * s);

  Path _poly(List pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = p(pts[i][0] as num, pts[i][1] as num);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  void _label(Canvas c, String text, Offset at, {double size = 10, Color color = Colors.white70, bool centered = true}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size / zoom, color: color, fontWeight: FontWeight.w600)), textDirection: TextDirection.rtl)..layout();
    tp.paint(c, centered ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  void paint(Canvas c, Size size) {
    final map = d.egyptMap;
    // land
    for (final ring in map['outline'] as List) {
      final path = _poly(ring as List);
      c.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF12301F), Color(0xFF0C1A14)]).createShader(Offset.zero & size));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6 / zoom..color = Fs.teal.withValues(alpha: 0.75));
    }
    // Delta area highlight
    final b = d.deltaBox;
    final r = Rect.fromPoints(p(b[0], b[3]), p(b[2], b[1]));
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(10 / zoom)), Paint()..color = Fs.green.withValues(alpha: 0.10));
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(10 / zoom)), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2 / zoom..color = Fs.green.withValues(alpha: 0.55));
    // lakes
    for (final l in map['lakes'] as List) {
      c.drawPath(_poly(l['pts'] as List), Paint()..color = const Color(0xFF2D8CFF).withValues(alpha: 0.55));
    }
    // Nile, branches, canals
    for (final w in map['water'] as List) {
      final pts = w['pts'] as List;
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = p(pts[i][0] as num, pts[i][1] as num);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final canal = (w['name'] as String).contains('Canal');
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = (canal ? 3.0 : 5.0) / zoom..color = Fs.teal.withValues(alpha: 0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 / zoom));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = (canal ? 1.0 : 1.8) / zoom..strokeCap = StrokeCap.round..color = canal ? Fs.teal.withValues(alpha: 0.6) : Fs.teal);
    }
    // orientation: a few cities
    const cities = {'القاهرة': [31.24, 30.04], 'الإسكندرية': [29.92, 31.2], 'بورسعيد': [32.3, 31.26], 'أسوان': [32.9, 24.09], 'الأقصر': [32.65, 25.7]};
    cities.forEach((n, ll) {
      final o = p(ll[0], ll[1]);
      c.drawCircle(o, 2.2 / zoom, Paint()..color = Colors.white54);
      _label(c, n, o + Offset(0, 8 / zoom), size: 9, color: Colors.white54);
    });
    _label(c, 'دلتا النيل', p((b[0] + b[2]) / 2, b[3] + 0.18), size: 11, color: Fs.green);
    _label(c, 'البحر المتوسط', p(28.5, 31.75), size: 9, color: Fs.dim);
    _label(c, 'البحر الأحمر', p(35.6, 26.4), size: 9, color: Fs.dim);
    // the six data points
    for (final k in d.siteKeys) {
      final ll = d.siteLatLon(k);
      final o = p(ll.lon, ll.lat);
      c.drawCircle(o, 8 / zoom, Paint()..color = Fs.teal.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 / zoom));
      c.drawCircle(o, 3.6 / zoom, Paint()..color = Fs.teal);
      c.drawCircle(o, 1.4 / zoom, Paint()..color = Colors.black);
      if (zoom >= 2.4) _label(c, siteAr[k] ?? k, o + Offset(0, -11 / zoom), size: 11, color: Colors.white);
    }
    // the tapped place
    if (pin != null) {
      final o = p(pin!.lon, pin!.lat);
      c.drawCircle(o, 10 / zoom, Paint()..color = Fs.orange.withValues(alpha: 0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 / zoom));
      c.drawCircle(o, 4.5 / zoom, Paint()..color = Fs.orange);
      c.drawCircle(o, 4.5 / zoom, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2 / zoom..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_EgyptPainter o) => o.zoom != zoom || o.pin != pin;
}

/// Short Arabic names for map labels (the full names with governorate notes live in arabic.dart).
const siteAr = {
  'kafr_el_sheikh': 'كفر الشيخ',
  'damietta': 'دمياط',
  'beheira': 'البحيرة',
  'gharbia': 'الغربية',
  'menoufia': 'المنوفية',
  'sharqia': 'الشرقية',
};
