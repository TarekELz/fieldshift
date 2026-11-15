// Field Shift engine for the web explorer. A port of docs/try.js (which mirrors app/lib/advice.dart and src/fieldshift/advice.py),
// plus the income rule of app/lib/goals.dart, the verdict rule of app/lib/result_pages.dart and the place rules of app/lib/engine.dart.
// Nothing here is invented: every number is looked up in the exported tables (data/*.json, loaded as data/*.js).
(function () {
  var FS = window.FS;
  var E = FS.E = {};
  E.DEFAULT_SUMMER = { rice: '05-15', maize: '05-01', cotton: '04-01' };
  E.ALT_WHEAT = '11-15';
  E.BASE_WHEAT = FS.meta.baseline_wheat_sowing || '11-15';

  var doy = E.doy = function (m, d) { return Math.round((Date.UTC(2001, m - 1, d) - Date.UTC(2001, 0, 1)) / 864e5); };

  // FAO paper 29 (salt.json): linear interpolation on [ECe, yield %] points; null above the 50% point.
  function yieldPotential(pts, ece) {
    if (ece <= pts[0][0]) return 100;
    for (var i = 0; i < pts.length - 1; i++) { var a = pts[i], b = pts[i + 1]; if (ece <= b[0]) return a[1] + (b[1] - a[1]) * (ece - a[0]) / (b[0] - a[0]); }
    return null;
  }
  E.yieldPotential = yieldPotential;
  E.eceOf = function (sign) { return (sign == null || sign === 'unknown') ? null : FS.salt.sign_to_ece[sign]; };
  E.saltFit = function (saltKey, ece) {
    var c = FS.salt.crops[saltKey]; if (!c || ece == null) return null;
    var y = yieldPotential(c.points, ece);
    return { pct: y == null ? null : Math.round(y), status: y == null ? 'not advised' : (y >= 90 ? 'fine' : (y >= 75 ? 'reduced' : 'not advised')) };
  };
  E.gapDays = function (crop, sow, wheat) {
    var days = FS.meta.crops[crop].stage_days.reduce(function (a, b) { return a + b; }, 0), s = sow.split('-').map(Number), w = wheat.split('-').map(Number);
    var harvest = Date.UTC(2001, s[0] - 1, s[1]) + days * 864e5, wd = Date.UTC(w[0] >= 10 ? 2001 : 2002, w[0] - 1, w[1]);
    return Math.round((wd - harvest) / 864e5);
  };
  E.harvest = function (crop, sow) {
    var days = FS.meta.crops[crop].stage_days.reduce(function (a, b) { return a + b; }, 0), s = sow.split('-').map(Number);
    var d = new Date(Date.UTC(2001, s[0] - 1, s[1]) + days * 864e5);
    return pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate());
  };
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };

  // Season screen (season.json): same rules as try.js seasonVerdict.
  E.seasonVerdict = function (site, crop, mmdd) {
    var sc = FS.season.sites[site] && FS.season.sites[site][crop];
    if (!sc) return { label: 'cannot judge', best: null };
    var p = mmdd.split('-').map(Number), x = doy(p[0], p[1]), nowI = 0, bd = 1e9;
    sc.forEach(function (r, i) { var dd = Math.abs(doy(r[0], r[1]) - x); dd = dd > 182 ? 365 - dd : dd; if (dd < bd) { bd = dd; nowI = i; } });
    var best = sc[0]; sc.forEach(function (r) { if (r[2] > best[2] || (r[2] === best[2] && r[3] < best[3])) best = r; });
    var mn = Math.min.apply(null, sc.map(function (r) { return r[2]; })), spread = best[2] - mn;
    if (spread < FS.season.min_spread) return { label: 'cannot judge', best: null };
    var now = sc[nowI], gap = best[2] - now[2], label;
    if (now[3] >= FS.season.bad_share_wrong || gap > FS.season.so_so_within) label = 'wrong season'; else if (gap <= FS.season.right_within) label = 'right season'; else label = 'so-so';
    return { label: label, best: pad(best[0]) + '-' + pad(best[1]) };
  };
  // The best date of the year for a crop at a place, or null when the screen cannot judge it.
  E.seasonBest = function (site, crop) {
    var sc = FS.season.sites[site] && FS.season.sites[site][crop];
    if (!sc) return null;
    var best = sc[0]; sc.forEach(function (r) { if (r[2] > best[2] || (r[2] === best[2] && r[3] < best[3])) best = r; });
    var mn = Math.min.apply(null, sc.map(function (r) { return r[2]; }));
    return (best[2] - mn) < FS.season.min_spread ? null : pad(best[0]) + '-' + pad(best[1]);
  };
  E.notJudgedReason = function (crop) { return (FS.extra.not_judged || {})[crop] || null; };

  // Rotation comparison: the farmer's rotation plus the other two summer crops at their usual dates, wheat on 15 Nov.
  E.compare = function (site, crop, sow, wheat, sign) {
    var ece = E.eceOf(sign);
    var seqs = [{ crop: crop, sow: sow, wheat: wheat }].concat(['rice', 'maize', 'cotton'].filter(function (c) { return c !== crop; }).map(function (c) { return { crop: c, sow: E.DEFAULT_SUMMER[c], wheat: E.ALT_WHEAT }; }));
    var base = null;
    return seqs.map(function (s, i) {
      var w = FS.water[site][s.crop][s.sow], h = FS.heat[site][s.wheat];
      if (base == null) base = w.etc;
      return { existing: i === 0, crop: s.crop, sow: s.sow, wheat: s.wheat, etc: w.etc, ratio: Math.round(w.etc / base * 100) / 100, heat: h.median, p10: h.p10, p90: h.p90, extra32: h.extra['32'],
        gap: E.gapDays(s.crop, s.sow, s.wheat), harvest: E.harvest(s.crop, s.sow), saltS: E.saltFit(s.crop, ece), saltW: E.saltFit('wheat', ece) };
    });
  };
  E.facts = function (site, rows) {
    var ex = rows[0], alts = rows.slice(1), sv = E.seasonVerdict(site, ex.crop, ex.sow), wv = E.seasonVerdict(site, 'wheat', ex.wheat);
    var f = { sea: FS.meta.sites[site].caveat_kind === 'sea', summer_crop: ex.crop, summer_date: ex.sow, wheat_date: ex.wheat, gap: ex.gap, heat_extra: ex.extra32, salt_known: ex.saltS != null,
      salt_summer: ex.saltS ? ex.saltS.status : null, salt_wheat: ex.saltW ? ex.saltW.status : null, summer_label: sv.label, wheat_label: wv.label, summer_best: sv.best, wheat_best: wv.best,
      alt_crop: null, alt_pct: null, alt_water_pct: null, alt_salt_ok: false };
    if (alts.length) {
      var ok = alts.filter(function (r) { return r.saltS && r.saltS.status === 'fine'; }), pool = ok.length ? ok : alts, pick = pool[0];
      pool.forEach(function (r) { if (r.ratio < pick.ratio) pick = r; });
      f.alt_crop = pick.crop; f.alt_pct = f.alt_water_pct = Math.round(100 * pick.ratio); f.alt_salt_ok = ok.length > 0;
    }
    return f;
  };
  var truthy = function (v) { return v == null ? false : (typeof v === 'boolean' ? v : (typeof v === 'number' ? v !== 0 : (typeof v === 'string' ? v.length > 0 : true))); };
  function test(c, f) {
    var v = f[c.f];
    if ('in' in c) return c['in'].indexOf(v) >= 0;
    if ('truthy' in c) return truthy(v) === c.truthy;
    if (typeof v !== 'number') return false;
    if ('lt' in c && !(v < c.lt)) return false; if ('lte' in c && !(v <= c.lte)) return false;
    if ('gt' in c && !(v > c.gt)) return false; if ('gte' in c && !(v >= c.gte)) return false;
    return true;
  }
  E.holds = function (b, f) { return b.must.every(function (c) { return test(c, f); }); };
  E.blueprint = function (id) { return FS.blueprints.blueprints.filter(function (b) { return b.id === id; })[0]; };
  // Code chooses the advice: highest-priority blueprints whose conditions hold, at most two, no two from one family.
  E.select = function (f) {
    var all = [];
    FS.blueprints.blueprints.forEach(function (b) { if (E.holds(b, f)) all.push(b); });
    all.sort(function (x, y) { return y.priority - x.priority; });
    var keep = [], used = {};
    for (var i = 0; i < all.length; i++) {
      var b = all[i], fam = FS.blueprints.families[b.id] || [b.id], clash = fam.some(function (t) { return used[t]; });
      if (keep.length && (b.id === 'generic' || b.id === 'on_track' || clash)) continue;
      keep.push(b); fam.forEach(function (t) { used[t] = 1; });
      if (keep.length >= 2) break;
    }
    return keep;
  };
  // Verdict per rotation: the rule of app/lib/result_pages.dart verdictOf (level 0 fine, 1 small problem, 2 big problem).
  E.verdict = function (r) {
    var salt = r.saltS ? r.saltS.status : null, extra = r.extra32 || 0;
    if (r.gap < 0) return { level: 2, why: 'gap_neg' };
    if (salt === 'not advised') return { level: 2, why: 'salt_high' };
    if (r.gap < 14) return { level: 1, why: 'gap_tight' };
    if (extra >= 4) return { level: 1, why: 'wheat_late' };
    if (salt === 'reduced') return { level: 1, why: 'salt_reduced' };
    return { level: 0, why: 'none' };
  };

  // Income (app/lib/goals.dart): FAOSTAT Egypt national averages, gross before costs, lowered by FAO-29 relative yield (half when beyond the table).
  E.gross = function (key, ece) {
    var c = FS.crops.crops[key], base = c.yield_kg_ha / 1000 * FS.crops.feddan_ha * c.price_egp_per_t, f = 1, pct = null, known = false;
    var pts = c.salt_key && FS.salt.crops[c.salt_key] ? FS.salt.crops[c.salt_key].points : null;
    if (ece != null && pts) { known = true; var y = yieldPotential(pts, ece); if (y == null) f = 0.5; else { f = y / 100; pct = Math.round(y); } }
    return { key: key, gross: Math.round(base * f), base: Math.round(base), saltPct: pct, saltKnown: known, beyond: known && pct == null };
  };

  // Places (app/lib/engine.dart): POWER cell first, then the governorate's own point, then the nearest point.
  E.hav = function (a1, o1, a2, o2) {
    var r = Math.PI / 180, dl = (a2 - a1) * r, dn = (o2 - o1) * r;
    var x = Math.pow(Math.sin(dl / 2), 2) + Math.cos(a1 * r) * Math.cos(a2 * r) * Math.pow(Math.sin(dn / 2), 2);
    return 2 * 6371 * Math.asin(Math.sqrt(x));
  };
  var cellOf = function (lat, lon) { return Math.round((lat + 90) / 0.5) + ',' + Math.round((lon + 180) / 0.625); };
  E.resolveGov = function (g) {
    if (g.delta !== true) return null;
    var lat = g.label[1], lon = g.label[0], own = g.site || null, c = cellOf(lat, lon), keys = Object.keys(FS.meta.sites), same = null;
    if (own && cellOf(FS.meta.sites[own].lat, FS.meta.sites[own].lon) === c) same = own;
    if (!same) keys.forEach(function (k) { if (!same && cellOf(FS.meta.sites[k].lat, FS.meta.sites[k].lon) === c) same = k; });
    var key = same || own, km = null;
    if (!key) { var best = 1e9; keys.forEach(function (k) { var d = E.hav(lat, lon, FS.meta.sites[k].lat, FS.meta.sites[k].lon); if (d < best) { best = d; key = k; } }); km = Math.round(best); }
    return { site: key, own: own, nearestKm: km, sameCell: !!same && same !== own };
  };
})();
