// What the farmer wants (decision D20): earn more, grow a certain crop at a certain time, or improve what he grows now.
// The crop book and the income numbers come from models/crops.yaml and FAOSTAT (national averages, gross before costs), exported by scripts/export_app_data.py;
// the season label comes from the temperature screen (advice.dart), the salt figure from FAO paper 29. Nothing here is a forecast for a field.
import 'package:flutter/material.dart';

import 'dialogue.dart';
import 'engine.dart';
import 'i18n.dart';
import 'ui_kit.dart';

class CropInfo {
  CropInfo(this.key, this.en, this.ar, this.group, this.saltKey, this.season, this.water, this.aliases, this.yieldKgHa, this.priceEgpPerT);
  final String key, en, ar, group;
  final String? saltKey;
  final bool season, water;
  final List<String> aliases;
  final int yieldKgHa, priceEgpPerT;
}

class Gross {
  Gross(this.crop, this.grossEgp, this.baseEgp, this.saltPct, this.saltKnown);
  final String crop;
  final int grossEgp, baseEgp;
  final int? saltPct; // FAO-29 relative yield potential at the farmer's salt, null when unknown or beyond the table
  final bool saltKnown;
}

class MoneyResult {
  MoneyResult(this.site, this.siteName, this.groups, this.ece, this.eceAssumed);
  final String site, siteName;
  final Map<String, List<Gross>> groups; // winter, summer, any, orchard: ranked, highest first
  final double? ece;
  final bool eceAssumed;
}

class PlanResult {
  PlanResult(this.site, this.siteName, this.crop, this.date, this.seasonLabel, this.bestDate, this.saltStatus, this.saltPct, this.gross, this.peers, this.ece, this.eceAssumed);
  final String site, siteName, date; // date as "MM-DD"
  final CropInfo crop;
  final String seasonLabel; // right season | so-so | wrong season | cannot judge
  final String? bestDate, saltStatus;
  final int? saltPct;
  final Gross gross;
  final List<Gross> peers; // the same group, ranked, with this crop among them
  final double? ece;
  final bool eceAssumed;
}

class CropBook {
  CropBook(this.d);
  final EngineData d;

  double get feddanHa => (d.cropBook['feddan_ha'] as num?)?.toDouble() ?? 0.42;
  Map<String, dynamic> get _c => (d.cropBook['crops'] as Map<String, dynamic>?) ?? const {};

  List<CropInfo> get all => [
        for (final e in _c.entries)
          CropInfo(e.key, e.value['en'] as String, e.value['ar'] as String, e.value['group'] as String, e.value['salt_key'] as String?, e.value['season'] as bool, e.value['water'] as bool,
              (e.value['aliases'] as List).cast<String>(), (e.value['yield_kg_ha'] as num).toInt(), (e.value['price_egp_per_t'] as num).toInt())
      ];

  CropInfo? info(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// The crop named in a (normalised) phrase: the longest matching alias wins, so "ذرة رفيعة" is sorghum and "ذرة" alone is maize.
  CropInfo? parse(String n) {
    if (notCoveredCrop(n) != null) return null; // peanut, sweet potato: not on the list, never guessed as faba bean or potato
    CropInfo? best;
    var bestLen = 0;
    for (final c in all) {
      for (final a in c.aliases) {
        final na = normalizeAr(a);
        if (na.length >= 2 && na.length > bestLen && hasWord(n, na)) {
          best = c;
          bestLen = na.length;
        }
      }
    }
    return best;
  }

  double? eceOf(Salt? s) {
    if (s == null || s.skipped) return null;
    if (s.ece != null) return s.ece;
    final m = d.salt['sign_to_ece'] as Map<String, dynamic>;
    return s.signs == null ? null : (m[s.signs] as num).toDouble();
  }

  /// National average gross income per feddan, lowered by FAO-29's relative yield at the farmer's salt (at most half when the table gives no value).
  Gross gross(String crop, double? ece) {
    final c = info(crop)!;
    final base = c.yieldKgHa / 1000.0 * feddanHa * c.priceEgpPerT;
    var f = 1.0;
    int? pct;
    var known = false;
    final pts = c.saltKey == null ? null : (d.salt['crops'] as Map<String, dynamic>)[c.saltKey]?['points'];
    if (ece != null && pts != null) {
      known = true;
      final y = yieldPotential((pts as List).map<List<double>>((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]).toList(), ece);
      if (y == null) {
        f = 0.5;
      } else {
        f = y / 100.0;
        pct = y.round();
      }
    }
    return Gross(crop, (base * f).round(), base.round(), pct, known);
  }

  List<Gross> rank(String group, double? ece) {
    final r = [for (final c in all.where((c) => c.group == group)) gross(c.key, ece)];
    r.sort((a, b) => b.grossEgp.compareTo(a.grossEgp));
    return r;
  }
}

String moneyN(int v) {
  final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => isAr ? '٬' : ',');
  return isAr ? '${nd(s).replaceAll(',', '٬')} جنيه' : '$s EGP';
}

String groupN(String g) => switch (g) {
      'winter' => tr('محاصيل الشتا', 'Winter crops'),
      'summer' => tr('محاصيل الصيف', 'Summer crops'),
      'any' => tr('خضار (أكتر من موسم)', 'Vegetables (several seasons)'),
      _ => tr('أشجار وكروم (في السنة)', 'Trees and vines (per year)'),
    };

String _cropName(CropInfo c) => isAr ? c.ar : c.en;

class GoalView extends StatelessWidget {
  const GoalView({super.key, required this.result, required this.book, required this.onRestart, this.onSpeak});
  final Object result;
  final CropBook book;
  final VoidCallback onRestart;
  final void Function(String text)? onSpeak;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      Text(r is MoneyResult ? tr('أكتر اختيارات بتجيب فلوس', 'Crops that bring in more') : tr('خطتك', 'Your plan'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.2)),
      const SizedBox(height: 4),
      Text(r is MoneyResult ? r.siteName : (r as PlanResult).siteName, style: TextStyle(fontSize: 15, color: Fs.dim)),
      const SizedBox(height: 12),
      if (r is MoneyResult) ..._money(r) else ..._plan(r as PlanResult),
      const SizedBox(height: 14),
      const SizedBox(height: 4),
      SizedBox(height: 52, child: FilledButton.icon(onPressed: onRestart, icon: const Icon(Icons.refresh_rounded), label: Text(tr('ابدأ من جديد', 'Start again')))),
    ]);
  }

  List<Widget> _money(MoneyResult r) {
    final out = <Widget>[];
    for (final g in ['winter', 'summer', 'any', 'orchard']) {
      final rows = r.groups[g] ?? const [];
      if (rows.isEmpty) continue;
      final top = rows.first.grossEgp;
      out.add(SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(groupN(g), style: TextStyle(fontSize: 13, color: Fs.dim)),
          const SizedBox(height: 8),
          for (final x in rows) _row(x, top),
        ]),
      ));
      out.add(const SizedBox(height: 12));
    }
    if (r.ece == null) out.add(Text(tr('مقلتش على الملوحة، فالأرقام من غير تعديل للملوحة.', 'No salt information was given, so these are not adjusted for salt.'), style: TextStyle(fontSize: 13, color: Fs.dim)));
    return out;
  }

  Widget _row(Gross x, int top) {
    final c = book.info(x.crop)!;
    final frac = top == 0 ? 0.0 : x.grossEgp / top;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_cropName(c), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          Text(moneyN(x.grossEgp), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: frac, minHeight: 6, color: Fs.accent, backgroundColor: Fs.card2)),
        if (x.saltKnown)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(x.saltPct == null ? tr('الملوحة: أقل من ٥٠٪ من الطبيعي', 'Salt: below 50% of normal') : tr('الملوحة: ${nd(x.saltPct!)}٪ من الطبيعي', 'Salt: ${x.saltPct}% of normal'),
                style: TextStyle(fontSize: 12, color: Fs.dim)),
          ),
      ]),
    );
  }

  List<Widget> _plan(PlanResult r) {
    final c = r.crop;
    final label = r.seasonLabel;
    final col = label == 'right season' ? Fs.ok : (label == 'so-so' ? Fs.warning : (label == 'wrong season' ? Fs.alert : Fs.dim));
    final name = _cropName(c);
    final String verdict = switch (label) {
      'right season' => tr('الميعاد ${dateN(r.date)} مناسب للحرارة.', 'The date ${dateN(r.date)} suits the temperature.'),
      'so-so' => tr('الميعاد ${dateN(r.date)} مقبول، بس فيه ميعاد أنسب للحرارة حوالي ${r.bestDate == null ? '' : dateN(r.bestDate!)}.', 'The date ${dateN(r.date)} is acceptable, but a better one for temperature is around ${r.bestDate == null ? '' : dateN(r.bestDate!)}.'),
      'wrong season' => tr('الحرارة مش مناسبة في ${dateN(r.date)}. الأنسب حوالي ${r.bestDate == null ? '' : dateN(r.bestDate!)}.', 'The temperature is not suitable on ${dateN(r.date)}. The best date is around ${r.bestDate == null ? '' : dateN(r.bestDate!)}.'),
      _ => c.group == 'orchard'
          ? tr('ده شجر أو كرم: مفيش ميعاد زراعة موسمي أحكم عليه بالحرارة.', 'This is a tree or vine: there is no seasonal sowing date I can judge by temperature.')
          : tr('الحرارة لوحدها مش بتحدد الميعاد المناسب للمحصول ده. اسأل مهندس زراعي.', 'Temperature alone cannot tell the right date for this crop. Ask an agricultural engineer.'),
    };
    final String salt = r.saltStatus == null
        ? tr('مقلتش على الملوحة، أو مفيش جدول ملوحة للمحصول ده.', 'No salt information was given, or there is no salt table for this crop.')
        : tr('الملوحة: ${saltN(r.saltStatus!)}${r.saltPct != null ? ' (${nd(r.saltPct!)}٪)' : ''}', 'Salt: ${saltN(r.saltStatus!)}${r.saltPct != null ? ' (${r.saltPct}%)' : ''}');
    final peers = r.peers.take(4).toList();
    final top = peers.isEmpty ? 1 : peers.first.grossEgp;
    return [
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('$name في ${dateN(r.date)}', '$name on ${dateN(r.date)}'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [Icon(Icons.thermostat_rounded, color: col, size: 20), const SizedBox(width: 8), Expanded(child: Text(verdict, style: const TextStyle(fontSize: 15, height: 1.4)))]),
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.grain_rounded, color: Fs.dim, size: 20), const SizedBox(width: 8), Expanded(child: Text(salt, style: const TextStyle(fontSize: 15, height: 1.4)))]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.payments_rounded, color: Fs.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('الدخل التقريبي للفدان: ${moneyN(r.gross.grossEgp)}', 'Approximate income per feddan: ${moneyN(r.gross.grossEgp)}'), style: const TextStyle(fontSize: 15, height: 1.4))),
          ]),
          if (!c.water)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('مفيش عندي أرقام احتياج مية للمحصول ده.', 'I have no water-need numbers for this crop.'), style: TextStyle(fontSize: 13, color: Fs.dim)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('للمقارنة: ${groupN(c.group)}', 'For comparison: ${groupN(c.group)}'), style: TextStyle(fontSize: 13, color: Fs.dim)),
          const SizedBox(height: 8),
          for (final x in peers) _row(x, top),
        ]),
      ),
    ];
  }
}

/// The spoken Egyptian-Arabic line for a goal result.
String goalSpoken(Object r, CropBook book) {
  if (r is MoneyResult) {
    final w = r.groups['winter']!.first, s = r.groups['summer']!.first;
    return 'أكتر اختيار دخل في الشتا ${book.info(w.crop)!.ar}، وفي الصيف ${book.info(s.crop)!.ar}. الأرقام قدامك على الشاشة.';
  }
  final p = r as PlanResult;
  return 'خطة ${p.crop.ar}. الدخل التقريبي حوالي ${nd(p.gross.grossEgp)} جنيه للفدان، قبل التكاليف.';
}
