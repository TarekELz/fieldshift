// "Try Eyad": the same lookup tables, blueprint rules and season rules as the app (assets/data/*.json), running in the browser.
// Nothing here is invented: heat, water and salt numbers come from the exported engine tables; the advice is the blueprint selected by the same rules as
// app/lib/advice.dart and src/fieldshift/advice.py. (The app may rephrase the text with a language model behind a guard; this page shows the blueprint text.)
(function () {
  var $ = function (i) { return document.getElementById(i); };
  var D = {}, lang = 'en';
  var MONTH_EN = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var MONTH_AR = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  var CROP = { en: { rice: 'rice', maize: 'maize', cotton: 'cotton', wheat: 'wheat' }, ar: { rice: 'الرز', maize: 'الذرة', cotton: 'القطن', wheat: 'القمح' } };
  var SALT_EN = { fine: 'Suitable', reduced: 'Reduced', 'not advised': 'Not suitable' };
  var SALT_AR = { fine: 'مناسب', reduced: 'أقل', 'not advised': 'مش مناسب' };
  var DEFAULT_SUMMER = { rice: '05-15', maize: '05-01', cotton: '04-01' }, ALT_WHEAT = '11-15';
  var toAr = function (s) { return String(s).replace(/[0-9]/g, function (d) { return '٠١٢٣٤٥٦٧٨٩'[d]; }); };
  var num = function (n) { return lang === 'ar' ? toAr(n) : String(n); };
  var dlab = function (k) { var p = k.split('-'); return lang === 'ar' ? toAr(+p[1]) + ' ' + MONTH_AR[p[0] - 1] : (+p[1]) + ' ' + MONTH_EN[p[0] - 1]; };
  var doy = function (m, d) { return Math.round((Date.UTC(2001, m - 1, d) - Date.UTC(2001, 0, 1)) / 864e5); };

  function yieldPotential(pts, ece) {
    if (ece <= pts[0][0]) return 100;
    for (var i = 0; i < pts.length - 1; i++) { var a = pts[i], b = pts[i + 1]; if (ece <= b[0]) return a[1] + (b[1] - a[1]) * (ece - a[0]) / (b[0] - a[0]); }
    return null;
  }
  function saltFit(crop, ece) {
    var y = yieldPotential(D.salt.crops[crop].points, ece);
    return { pct: y == null ? null : Math.round(y), status: y == null ? 'not advised' : (y >= 90 ? 'fine' : (y >= 75 ? 'reduced' : 'not advised')) };
  }
  function gapDays(crop, sow, wheat) {
    var days = D.meta.crops[crop].stage_days.reduce(function (a, b) { return a + b; }, 0), s = sow.split('-').map(Number), w = wheat.split('-').map(Number);
    var harvest = Date.UTC(2001, s[0] - 1, s[1]) + days * 864e5, wd = Date.UTC(w[0] >= 10 ? 2001 : 2002, w[0] - 1, w[1]);
    return Math.round((wd - harvest) / 864e5);
  }
  function seasonVerdict(site, crop, mmdd) {
    var sc = D.season.sites[site] && D.season.sites[site][crop];
    if (!sc) return { label: 'cannot judge', best: null };
    var p = mmdd.split('-').map(Number), x = doy(p[0], p[1]), nowI = 0, bd = 1e9;
    sc.forEach(function (r, i) { var dd = Math.abs(doy(r[0], r[1]) - x); dd = dd > 182 ? 365 - dd : dd; if (dd < bd) { bd = dd; nowI = i; } });
    var best = sc[0]; sc.forEach(function (r) { if (r[2] > best[2] || (r[2] === best[2] && r[3] < best[3])) best = r; });
    var mn = Math.min.apply(null, sc.map(function (r) { return r[2]; })), spread = best[2] - mn;
    if (spread < D.season.min_spread) return { label: 'cannot judge', best: null };
    var now = sc[nowI], gap = best[2] - now[2], label;
    if (now[3] >= D.season.bad_share_wrong || gap > D.season.so_so_within) label = 'wrong season'; else if (gap <= D.season.right_within) label = 'right season'; else label = 'so-so';
    var pad = function (n) { return (n < 10 ? '0' : '') + n; };
    return { label: label, best: pad(best[0]) + '-' + pad(best[1]) };
  }
  function compare(site, crop, sow, wheat, signs) {
    var ece = signs === 'unknown' ? null : D.salt.sign_to_ece[signs];
    var seqs = [{ crop: crop, sow: sow, wheat: wheat }].concat(['rice', 'maize', 'cotton'].filter(function (c) { return c !== crop; }).map(function (c) { return { crop: c, sow: DEFAULT_SUMMER[c], wheat: ALT_WHEAT }; }));
    var base = null;
    return seqs.map(function (s) {
      var w = D.water[site][s.crop][s.sow], h = D.heat[site][s.wheat];
      if (base == null) base = w.etc;
      return { crop: s.crop, sow: s.sow, wheat: s.wheat, etc: w.etc, ratio: Math.round(w.etc / base * 100) / 100, heat: h.median, extra32: h.extra['32'], gap: gapDays(s.crop, s.sow, s.wheat),
        saltS: ece == null ? null : saltFit(s.crop, ece), saltW: ece == null ? null : saltFit('wheat', ece) };
    });
  }
  function facts(site, rows) {
    var ex = rows[0], alts = rows.slice(1), sv = seasonVerdict(site, ex.crop, ex.sow), wv = seasonVerdict(site, 'wheat', ex.wheat);
    var f = { sea: D.meta.sites[site].caveat_kind === 'sea', summer_crop: ex.crop, summer_date: ex.sow, wheat_date: ex.wheat, gap: ex.gap, heat_extra: ex.extra32, salt_known: ex.saltS != null,
      salt_summer: ex.saltS ? ex.saltS.status : null, salt_wheat: ex.saltW ? ex.saltW.status : null, summer_label: sv.label, wheat_label: wv.label, summer_best: sv.best, wheat_best: wv.best,
      alt_crop: null, alt_pct: null, alt_water_pct: null, alt_salt_ok: false };
    if (alts.length) {
      var ok = alts.filter(function (r) { return r.saltS && r.saltS.status === 'fine'; }), pool = ok.length ? ok : alts, pick = pool[0];
      pool.forEach(function (r) { if (r.ratio < pick.ratio) pick = r; });
      f.alt_crop = pick.crop; f.alt_pct = f.alt_water_pct = Math.round(100 * pick.ratio); f.alt_salt_ok = ok.length > 0;
    }
    return f;
  }
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
  function select(f) {
    var all = [];
    D.blueprints.blueprints.forEach(function (b) {
      if (!b.must.every(function (c) { return test(c, f); })) return;
      var total = b.must.length + b.bonus.length, met = b.must.length + b.bonus.filter(function (c) { return test(c, f); }).length;
      all.push({ id: b.id, priority: b.priority, closeness: total ? Math.round(100 * met / total) : null, b: b });
    });
    all.sort(function (x, y) { return y.priority - x.priority; });
    var keep = [], used = {};
    for (var i = 0; i < all.length; i++) {
      var r = all[i], fam = D.blueprints.families[r.id] || [r.id], clash = fam.some(function (t) { return used[t]; });
      if (keep.length && (r.id === 'generic' || r.id === 'on_track' || clash)) continue;
      keep.push(r); fam.forEach(function (t) { used[t] = 1; });
      if (keep.length >= 2) break;
    }
    return keep;
  }
  function fill(b, f) {
    var slots = { crop: CROP[lang][f.summer_crop], summer_date: dlab(f.summer_date), wheat_date: dlab(f.wheat_date), gap: num(f.gap), heat_extra: num(f.heat_extra),
      alt_crop: f.alt_crop ? CROP[lang][f.alt_crop] : '', alt_pct: f.alt_pct != null ? num(f.alt_pct) : '', summer_best: f.summer_best ? dlab(f.summer_best) : '', wheat_best: f.wheat_best ? dlab(f.wheat_best) : '' };
    var t = b[lang];
    Object.keys(slots).forEach(function (k) { t = t.split('{' + k + '}').join(slots[k]); });
    if (lang === 'en') t = t.replace(/(^|[.!?] )([a-z])/g, function (m, a, b) { return a + b.toUpperCase(); });
    return t;
  }
  var pill = function (label) { var c = { 'right season': 'right', 'so-so': 'so', 'wrong season': 'wrong', 'cannot judge': 'na' }[label]; var tx = { 'right season': lang === 'ar' ? 'ميعاد مناسب' : 'Right season', 'so-so': lang === 'ar' ? 'مقبول' : 'So-so', 'wrong season': lang === 'ar' ? 'ميعاد مش مناسب' : 'Wrong season', 'cannot judge': lang === 'ar' ? 'مقدرش أحكم' : 'Cannot judge' }[label]; return '<span class="pill ' + c + '" style="font-size:12px;padding:3px 10px">' + tx + '</span>'; };

  function render() {
    var site = $('t_site').value, crop = $('t_crop').value, sow = $('t_sow').value, wheat = $('t_wheat').value, signs = $('t_salt').value;
    var rows = compare(site, crop, sow, wheat, signs), f = facts(site, rows), sel = select(f), ex = rows[0];
    var box = $('t_advice'); box.setAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
    box.innerHTML = '<div style="font-size:18px;line-height:1.6">' + fill(sel[0].b, f) + '</div>' + sel.slice(1).map(function (s) { return '<div style="margin-top:10px;color:var(--dim)">' + fill(s.b, f) + '</div>'; }).join('') +
      '<div class="note" style="margin-top:12px">' + (lang === 'ar' ? 'مبنية على أرقام ناسا · تشابه مع حالة نموذجية ' + num(sel[0].closeness) + '٪' : 'Built from the NASA numbers · match with a typical case ' + sel[0].closeness + '%') + ' · ' + sel[0].id + '</div>';
    var alts = rows.slice(1).map(function (r) { return CROP[lang][r.crop] + ' ×' + (lang === 'ar' ? toAr(r.ratio.toFixed(2)) : r.ratio.toFixed(2)); }).join(' · ');
    var saltTxt = ex.saltS ? ((lang === 'ar' ? SALT_AR : SALT_EN)[ex.saltS.status] + (ex.saltS.pct != null ? ' (' + num(ex.saltS.pct) + '%)' : '')) : (lang === 'ar' ? 'مفيش معلومة' : 'Not given');
    $('t_tiles').innerHTML =
      '<div class="stat"><span>' + (lang === 'ar' ? 'احتياج المية (مقارنة بدورتك)' : 'Crop water need vs your rotation') + '</span><b style="font-size:20px;margin-top:6px">' + (lang === 'ar' ? 'بدائل: ' : 'Alternatives: ') + alts + '</b></div>' +
      '<div class="stat"><span>' + (lang === 'ar' ? 'أيام حر وقت امتلاء حبوب القمح' : 'Hot days in wheat grain filling') + '</span><b>' + num(ex.heat) + '</b><span>' + (lang === 'ar' ? '+' + num(ex.extra32) + ' عن زراعته ١٥ نوفمبر' : '+' + ex.extra32 + ' vs sowing on 15 Nov') + '</span></div>' +
      '<div class="stat"><span>' + (lang === 'ar' ? 'الملوحة (' + CROP.ar[crop] + ')' : 'Salt (' + crop + ')') + '</span><b style="font-size:22px;margin-top:6px">' + saltTxt + '</b></div>' +
      '<div class="stat"><span>' + (lang === 'ar' ? 'مواعيد الزراعة' : 'Sowing dates') + '</span><div style="margin-top:8px">' + pill(f.summer_label) + ' ' + pill(f.wheat_label) + '</div><span style="display:block;margin-top:6px">' + (lang === 'ar' ? CROP.ar[crop] + ' · القمح' : crop + ' · wheat') + '</span></div>';
    $('t_note').textContent = (f.sea ? (lang === 'ar' ? 'تنبيه: الخلية دي قريبة من البحر. ' : 'Caution: this cell is mostly sea. ') : '') + (D.meta.sites[site].caveat_kind === 'desert_edge' ? (lang === 'ar' ? 'ملحوظة: الخلية دي أغلبها صحرا، فاعتبر الأرقام تقريبية. ' : 'Note: this cell is mostly desert plateau, so treat the numbers as rough. ') : '') +
      (lang === 'ar' ? 'تقدير من بيانات ناسا بتاعة 1990 إلى 2025، مش وعد بمحصول.' : 'An estimate from NASA data 1990 to 2025, not a promise of a harvest.');
  }
  function fillSelects() {
    var site = $('t_site').value, crop = $('t_crop').value;
    var set = function (id, keys, keep, fallback) { var s = $(id), prev = keep || s.value; s.innerHTML = ''; keys.forEach(function (k) { var o = document.createElement('option'); o.value = k; o.textContent = dlab(k); s.appendChild(o); }); s.value = keys.indexOf(prev) >= 0 ? prev : fallback; };
    set('t_sow', Object.keys(D.water[site][crop]), null, DEFAULT_SUMMER[crop]);
    set('t_wheat', Object.keys(D.heat[site]), null, '12-01');
  }
  function labels() {
    var ar = lang === 'ar';
    $('t_ll_site').textContent = ar ? 'المكان' : 'Place'; $('t_ll_crop').textContent = ar ? 'المحصول الصيفي' : 'Summer crop'; $('t_ll_sow').textContent = ar ? 'ميعاد زراعته' : 'Sown on';
    $('t_ll_wheat').textContent = ar ? 'ميعاد القمح' : 'Wheat sown on'; $('t_ll_salt').textContent = ar ? 'الملوحة' : 'Salt in the soil';
    var opts = { unknown: ar ? 'مش عارف' : "I don't know", none: ar ? 'مفيش علامات' : 'No signs', patches: ar ? 'بقع ملح' : 'Salty patches', crust: ar ? 'قشرة بيضاء' : 'White crust' };
    Array.prototype.forEach.call($('t_salt').options, function (o) { o.textContent = opts[o.value]; });
    Array.prototype.forEach.call($('t_crop').options, function (o) { o.textContent = CROP[lang][o.value]; });
    $('t_lang').textContent = ar ? 'English' : 'عربي';
    fillSelects(); render();
  }
  function start(d) {
    D = d; var s = $('t_site');
    Object.keys(D.meta.sites).forEach(function (k) { var o = document.createElement('option'); o.value = k; o.textContent = D.meta.sites[k].name_en; s.appendChild(o); });
    s.value = 'gharbia'; $('t_crop').value = 'rice'; $('t_salt').value = 'patches';
    labels(); $('t_sow').value = '06-15'; $('t_wheat').value = '12-01'; render();
    ['t_site', 't_crop'].forEach(function (id) { $(id).addEventListener('change', function () { fillSelects(); render(); }); });
    ['t_sow', 't_wheat', 't_salt'].forEach(function (id) { $(id).addEventListener('change', render); });
    $('t_lang').addEventListener('click', function () { lang = lang === 'ar' ? 'en' : 'ar'; labels(); });
  }
  var names = ['heat', 'water', 'salt', 'meta', 'blueprints', 'season'];
  Promise.all(names.map(function (n) { return fetch('site/data/' + n + '.json').then(function (r) { return r.json(); }); })).then(function (arr) {
    var d = {}; names.forEach(function (n, i) { d[n] = arr[i]; }); start(d);
  }).catch(function () { var n = $('t_note'); if (n) n.textContent = 'The playground needs site/data/*.json next to this page (run scripts/build_pages_data.py).'; });
})();
