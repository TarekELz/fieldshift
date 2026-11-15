// Map of Egypt drawn in code: the 27 governorates from the official CAPMAS boundaries (HDX COD-AB, CC BY-IGO, simplified
// to about 0.6 km) with their Arabic names; the Nile, its two Delta branches and Lake Nasser from Natural Earth
// (generalized). The farmer taps a governorate of the Nile Delta (green) to zoom in, then taps his governorate.
// Each Delta governorate is matched to a NASA data point.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'engine.dart';
import 'i18n.dart';
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
  String? _selected;

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
    final g = governorateAt(widget.data, ll.lat, ll.lon);
    final zoom = _ctrl.value.getMaxScaleOnAxis();
    if (zoom < 2.2 && g != null && g['delta'] == true) {
      _zoomDelta(w, h); // the first tap on a Delta governorate zooms in; the next tap picks
      return;
    }
    setState(() {
      _pin = ll;
      _selected = g?['id'] as String?;
    });
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
            decoration: BoxDecoration(color: Fs.card, borderRadius: BorderRadius.circular(Fs.radiusCard)),
            child: InteractiveViewer(
              transformationController: _ctrl,
              minScale: 1,
              maxScale: 10,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tap(d.localPosition, w, h),
                  child: CustomPaint(size: Size(w, h), painter: _EgyptPainter(widget.data, s, _ctrl.value.getMaxScaleOnAxis(), _pin, _selected)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(tr('اضغط على محافظتك (الخضرا) عشان تكبّرها، وبعدين اضغط عليها تاني.', 'Tap your governorate (green) to zoom in, then tap it again.'), style: TextStyle(fontSize: 12, color: Fs.dim.withValues(alpha: 0.95), height: 1.35))),
          TextButton.icon(onPressed: () => _zoomDelta(w, h), icon: const Icon(Icons.zoom_in_map_rounded, size: 18), label: Text(tr('الدلتا', 'Delta'))),
          TextButton.icon(onPressed: () => _animateTo(Matrix4.identity()), icon: const Icon(Icons.public_rounded, size: 18), label: Text(tr('مصر', 'Egypt'))),
        ]),
        Text(tr('حدود المحافظات من بيانات CAPMAS الرسمية عبر HDX (مبسّطة)، والأنهار تقريبية.', 'Borders: official CAPMAS data via HDX, simplified. Rivers are approximate.'), style: TextStyle(fontSize: 10, color: Fs.dim)),
      ]);
    });
  }
}

class _EgyptPainter extends CustomPainter {
  _EgyptPainter(this.d, this.s, this.zoom, this.pin, this.selectedId);
  final EngineData d;
  final double s, zoom;
  final ({double lat, double lon})? pin;
  final String? selectedId;

  Offset p(num lon, num lat) => Offset((lon - _lonMin) * _cosLat * s, (_latMax - lat) * s);

  Path _ring(List pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = p(pts[i][0] as num, pts[i][1] as num);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  void _label(Canvas c, String text, Offset at, {double size = 10, Color color = Colors.white70}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size / zoom, color: color, fontWeight: FontWeight.w600)), textDirection: TextDirection.rtl)..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    final govs = d.governorates;
    final all = Path();
    for (final g in govs) {
      for (final r in g['rings'] as List) {
        all.addPath(_ring(r as List), Offset.zero);
      }
    }
    // soft silhouette glow, then each governorate: Delta ones greener
    for (final g in govs) {
      final path = Path();
      for (final r in g['rings'] as List) {
        path.addPath(_ring(r as List), Offset.zero);
      }
      final delta = g['delta'] == true;
      c.drawPath(path, Paint()..color = delta ? Color.alphaBlend(Fs.accent.withValues(alpha: 0.22), Fs.card2) : Fs.card2);
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9 / zoom..color = delta ? Fs.accent.withValues(alpha: 0.8) : Fs.line..strokeJoin = StrokeJoin.round);
      if (g['id'] == selectedId) {
        c.drawPath(path, Paint()..color = Fs.warning.withValues(alpha: 0.18));
        c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8 / zoom..color = Fs.warning);
      }
    }
    // lakes
    for (final l in d.egyptMap['lakes'] as List) {
      c.drawPath(_ring(l['pts'] as List), Paint()..color = Fs.accent.withValues(alpha: 0.4));
    }
    // Nile, its two Delta branches, the canals
    for (final w in d.egyptMap['water'] as List) {
      final pts = w['pts'] as List;
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = p(pts[i][0] as num, pts[i][1] as num);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final canal = (w['name'] as String).contains('Canal');
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = (canal ? 1.0 : 1.7) / zoom..strokeCap = StrokeCap.round..color = canal ? Fs.accent.withValues(alpha: 0.55) : Fs.accent);
    }
    // governorate names: large governorates at once, small ones once zoomed in
    for (final g in govs) {
      final delta = g['delta'] == true;
      if (delta ? zoom < 2.2 : (g['size'] as num) * zoom < 1.5) continue; // Delta governorates are always named once zoomed in
      final lbl = g['label'] as List;
      _label(c, (isAr ? g['ar'] : g['id']) as String, p(lbl[0] as num, lbl[1] as num), size: 11, color: delta ? Colors.white : Colors.white54);
    }
    if (zoom < 2.0) {
      final b = d.deltaBox;
      _label(c, tr('دلتا النيل', 'Nile Delta'), p((b[0] + b[2]) / 2, b[3] + 0.28), size: 11, color: Fs.ok);
    }
    // the six NASA data points
    for (final k in d.siteKeys) {
      final ll = d.siteLatLon(k);
      final o = p(ll.lon, ll.lat);
      c.drawCircle(o, 7 / zoom, Paint()..color = Fs.accent.withValues(alpha: 0.35));
      c.drawCircle(o, 3.2 / zoom, Paint()..color = Fs.accent);
      c.drawCircle(o, 1.2 / zoom, Paint()..color = Colors.black);
    }
    // the tapped place
    if (pin != null) {
      final o = p(pin!.lon, pin!.lat);
      c.drawCircle(o, 10 / zoom, Paint()..color = Fs.warning.withValues(alpha: 0.4));
      c.drawCircle(o, 4.5 / zoom, Paint()..color = Fs.warning);
      c.drawCircle(o, 4.5 / zoom, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2 / zoom..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_EgyptPainter o) => true; // cheap, and the labels follow the language
}
