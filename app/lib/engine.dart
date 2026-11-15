// Field Shift engine (Dart). Reads the lookup tables exported from the Python engines
// (scripts/export_app_data.py) and joins them into a rotation comparison.
// It must give the same numbers as src/fieldshift/rotation.py: see test/engine_test.dart.
//
// Supports, and does not replace, the farmer's judgement and local agricultural advice.
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Round half to even, like Python's round(), so results match the Python engines exactly.
int roundHalfEven(double x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if (diff < 0.5) return f.toInt();
  if (diff > 0.5) return f.toInt() + 1;
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

class EngineData {
  EngineData(this.heat, this.water, this.salt, this.meta, this.climate, this.egyptMap);
  final Map<String, dynamic> heat, water, salt, meta, climate, egyptMap;

  static Future<EngineData> load([AssetBundleLike? bundle]) async {
    Future<Map<String, dynamic>> read(String n) async =>
        jsonDecode(await (bundle?.loadString('assets/data/$n.json') ?? rootBundle.loadString('assets/data/$n.json'))) as Map<String, dynamic>;
    return EngineData(await read('heat'), await read('water'), await read('salt'), await read('meta'), await read('climate'), await read('egypt_map'));
  }

  List<String> get siteKeys => (meta['sites'] as Map<String, dynamic>).keys.toList();
  String siteName(String k) => meta['sites'][k]['name_en'] as String;
  String? siteCaveat(String k) => meta['sites'][k]['caveat'] as String?;
  String? siteCaveatKind(String k) => meta['sites'][k]['caveat_kind'] as String?; // 'sea' or 'shared_cell'
  String? siteSharesCellWith(String k) => meta['sites'][k]['shares_cell_with'] as String?;
  List<String> get notModelled => (meta['not_modelled'] as List).cast<String>();
  List<String> wheatDates(String site) => (heat[site] as Map<String, dynamic>).keys.toList();
  List<String> summerDates(String site, String crop) => (water[site][crop] as Map<String, dynamic>).keys.toList();
  /// Monthly mean of a NASA POWER variable (T2M_MAX, T2M_MIN, RH2M, WS2M, RAIN_MM_MONTH, ALLSKY_SFC_SW_DWN), 12 values.
  List<double> climateVar(String site, String v) => (climate[site][v] as List).map<double>((e) => (e as num).toDouble()).toList();
  /// [lon_min, lat_min, lon_max, lat_max] of the Nile Delta, where the six data points apply.
  List<double> get deltaBox => (meta['delta_bbox'] as List).map<double>((e) => (e as num).toDouble()).toList();
  ({double lat, double lon}) siteLatLon(String k) => (lat: (meta['sites'][k]['lat'] as num).toDouble(), lon: (meta['sites'][k]['lon'] as num).toDouble());
  List get governorates => egyptMap['governorates'] as List;
  /// Named areas inside governorates that are drawn and named on the map (Halayeb and Shalateen, in the Red Sea governorate).
  List get areas => (egyptMap['areas'] as List?) ?? const [];
  List<String> get crops => (meta['crops'] as Map<String, dynamic>).keys.toList();
}

abstract class AssetBundleLike {
  Future<String> loadString(String key);
}

class SequenceInput {
  SequenceInput({required this.name, required this.crop, required this.summerSowing, required this.wheatSowing});
  final String name, crop, summerSowing, wheatSowing; // dates as "MM-DD"
}

class SaltFit {
  SaltFit(this.yieldPct, this.status);
  final int? yieldPct;
  final String status; // fine | reduced | not advised
}

class RotationRow {
  RotationRow({
    required this.input, required this.isExisting, required this.etc, required this.etcP10, required this.etcP90, required this.ratio,
    required this.peakDaily, required this.harvest, required this.gapDays, required this.heatMedian, required this.heatP10, required this.heatP90,
    required this.extra, required this.series, required this.turnMm, required this.saltSummer, required this.saltWheat, required this.warnings, required this.riceFloor,
  });
  final SequenceInput input;
  final bool isExisting;
  final int etc, etcP10, etcP90;
  final double ratio, peakDaily;
  final String harvest;
  final int gapDays;
  final num heatMedian, heatP10, heatP90;
  final Map<String, int> extra; // extra hot days vs a 15 Nov sowing at 30/32/34 C
  final List<int> series; // hot days in each season 1990 onwards (for the sparkline)
  final int? turnMm;
  final SaltFit? saltSummer, saltWheat;
  final List<String> warnings;
  final bool riceFloor; // rice figure excludes ponding and percolation
}

class Comparison {
  Comparison(this.site, this.siteName, this.caveat, this.rows, this.eceUsed, this.saltBasisAssumed, this.intervalDays, {this.caveatKind, this.sharesCellWith});
  final String site, siteName;
  final String? caveat, caveatKind, sharesCellWith;
  final List<RotationRow> rows;
  final double? eceUsed;
  final bool saltBasisAssumed; // true when ECe came from sign classes (a team assumption)
  final int? intervalDays;
}

int _md(String s, int i) => int.parse(s.split('-')[i]);

/// Estimated harvest date as "dd Mon", from the sowing date plus the FAO-56 stage lengths.
String harvestText(EngineData d, String crop, String sowing) {
  final stages = (d.meta['crops'][crop]['stage_days'] as List).cast<int>();
  final h = DateTime.utc(2001, _md(sowing, 0), _md(sowing, 1)).add(Duration(days: stages.fold(0, (a, b) => a + b)));
  return '${h.day.toString().padLeft(2, '0')} ${_months[h.month - 1]}';
}

int gapDays(EngineData d, String crop, String summerSowing, String wheatSowing) {
  final stages = (d.meta['crops'][crop]['stage_days'] as List).cast<int>();
  final harvest = DateTime.utc(2001, _md(summerSowing, 0), _md(summerSowing, 1)).add(Duration(days: stages.fold(0, (a, b) => a + b)));
  final wm = _md(wheatSowing, 0);
  final wheat = DateTime.utc(wm >= 10 ? 2001 : 2002, wm, _md(wheatSowing, 1));
  return wheat.difference(harvest).inDays;
}

/// Linear interpolation on the FAO paper 29 points [[ece, yield%], ...]; null above the 50% point.
double? yieldPotential(List<List<double>> pts, double ece) {
  if (ece < 0) throw ArgumentError('ECe cannot be negative');
  if (ece <= pts.first[0]) return 100;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    if (ece <= b[0]) return a[1] + (b[1] - a[1]) * (ece - a[0]) / (b[0] - a[0]);
  }
  return null;
}

String saltStatus(double? y) => y == null ? 'not advised' : (y >= 90 ? 'fine' : (y >= 75 ? 'reduced' : 'not advised'));

SaltFit saltFit(EngineData d, String crop, double ece) {
  final pts = ((d.salt['crops'][crop]['points']) as List).map<List<double>>((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]).toList();
  final y = yieldPotential(pts, ece);
  return SaltFit(y?.round(), saltStatus(y));
}

Comparison compare(EngineData d, String site, List<SequenceInput> seqs, {double? ece, String? signs, int? intervalDays}) {
  if (seqs.isEmpty) throw ArgumentError('give at least one sequence');
  if (!d.siteKeys.contains(site)) throw ArgumentError('unknown site: $site');
  if ((ece != null) && (signs != null)) throw ArgumentError('give only one of ece or signs');
  double? e = ece;
  var assumed = false;
  if (e == null && signs != null) {
    final m = d.salt['sign_to_ece'] as Map<String, dynamic>;
    if (!m.containsKey(signs)) throw ArgumentError('signs must be one of ${m.keys.join(', ')}');
    e = (m[signs] as num).toDouble();
    assumed = true;
  }
  final rows = <RotationRow>[];
  int? baseEtc;
  for (var i = 0; i < seqs.length; i++) {
    final s = seqs[i];
    final w = d.water[site][s.crop]?[s.summerSowing];
    if (w == null) throw ArgumentError('no water data for ${s.crop} sown ${s.summerSowing}');
    final h = d.heat[site][s.wheatSowing];
    if (h == null) throw ArgumentError('no wheat data for sowing ${s.wheatSowing}');
    final etc = (w['etc'] as num).toInt();
    baseEtc ??= etc;
    final gap = gapDays(d, s.crop, s.summerSowing, s.wheatSowing);
    final warns = <String>[];
    if (gap < 0) warns.add('wheat is sown ${-gap} days before the summer crop would finish; check the dates');
    if (gap >= 0 && gap < 14) warns.add('only $gap days between the summer harvest and wheat sowing');
    final peak = (w['peak_daily'] as num).toDouble();
    rows.add(RotationRow(
      input: s, isExisting: i == 0, etc: etc, etcP10: (w['p10'] as num).toInt(), etcP90: (w['p90'] as num).toInt(),
      ratio: (etc / baseEtc * 100).roundToDouble() / 100, peakDaily: peak, harvest: harvestText(d, s.crop, s.summerSowing), gapDays: gap,
      heatMedian: h['median'] as num, heatP10: h['p10'] as num, heatP90: h['p90'] as num,
      extra: {for (final k in ['30', '32', '34']) k: (h['extra'][k] as num).toInt()},
      series: ((h['series'] as List?) ?? const []).map<int>((e) => (e as num).toInt()).toList(),
      turnMm: intervalDays == null ? null : roundHalfEven(peak * intervalDays),
      saltSummer: e == null ? null : saltFit(d, s.crop, e), saltWheat: e == null ? null : saltFit(d, 'wheat', e),
      warnings: warns, riceFloor: s.crop == 'rice',
    ));
  }
  return Comparison(site, d.siteName(site), d.siteCaveat(site), rows, e, assumed, intervalDays, caveatKind: d.siteCaveatKind(site), sharesCellWith: d.siteSharesCellWith(site));
}

/// Great-circle distance in km.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * 3.141592653589793 / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class NearestSite {
  NearestSite(this.key, this.km);
  final String key;
  final double km;
}

/// The data point closest to a tapped place. Menoufia and Sharqia are different places but two data points.
NearestSite nearestSite(EngineData d, double lat, double lon) {
  String? best;
  var bestKm = double.infinity;
  for (final k in d.siteKeys) {
    final p = d.siteLatLon(k);
    final km = haversineKm(lat, lon, p.lat, p.lon);
    if (km < bestKm) {
      bestKm = km;
      best = k;
    }
  }
  return NearestSite(best!, bestKm);
}

bool _inRing(List ring, double x, double y) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = (ring[i][0] as num).toDouble(), yi = (ring[i][1] as num).toDouble();
    final xj = (ring[j][0] as num).toDouble(), yj = (ring[j][1] as num).toDouble();
    if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
  }
  return inside;
}

/// The governorate containing a place, or null (sea, or outside Egypt). Borders are Natural Earth, generalized.
Map<String, dynamic>? governorateAt(EngineData d, double lat, double lon) {
  for (final g in d.governorates) {
    for (final ring in g['rings'] as List) {
      if (_inRing(ring as List, lon, lat)) return g as Map<String, dynamic>;
    }
  }
  return null;
}

/// True when the place lies in one of the Nile Delta governorates the app covers.
/// The NASA POWER grid cell (0.5 degrees of latitude by 0.625 of longitude, MERRA-2) that a place falls in. Two places in
/// the same cell get identical weather from POWER, whatever the distance between them (Mansoura and Gharbia, for example).
(int, int) powerCell(double lat, double lon) => (((lat + 90) / 0.5).round(), ((lon + 180) / 0.625).round());

/// A data point that lies in the same POWER cell as the place, or null.
String? siteInSameCell(EngineData d, double lat, double lon) {
  final c = powerCell(lat, lon);
  for (final k in d.siteKeys) {
    final p = d.siteLatLon(k);
    if (powerCell(p.lat, p.lon) == c) return k;
  }
  return null;
}

Map<String, dynamic>? areaAt(EngineData d, double lat, double lon) {
  for (final a in d.areas.where((a) => a['kind'] != 'plain')) {
    for (final ring in a['rings'] as List) {
      if (_inRing(ring as List, lon, lat)) return a as Map<String, dynamic>;
    }
  }
  return null;
}

bool insideDelta(EngineData d, double lat, double lon) => governorateAt(d, lat, lon)?['delta'] == true;
