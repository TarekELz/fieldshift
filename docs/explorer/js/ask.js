// Ask Eyad: an offline, rule-based helper. No language model, no network. It reads the question with simple whole-word rules,
// answers only from the same tables (heat, water, salt, season, crops) and says "I cannot judge" or "I cannot forecast" otherwise.
(function () {
  var FS = window.FS, E = FS.E, I = FS.I, S = FS.S;
  var L = function (en, ar) { return I.lang === 'ar' ? ar : en; };
  var esc = function (s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var src = function (k, d) { return FS.src ? FS.src(k, d) : ''; };

  function norm(s) {
    var t = String(s).toLowerCase();
    '٠١٢٣٤٥٦٧٨٩'.split('').forEach(function (d, i) { t = t.split(d).join(String(i)); });
    t = t.replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي').replace(/ؤ/g, 'و').replace(/ئ/g, 'ي');
    return t.replace(/[؟?!.,،:;"'()]/g, ' ').replace(/\s+/g, ' ').trim();
  }
  var PREF = ['وال', 'بال', 'فال', 'كال', 'لل', 'ال', 'و', 'ب', 'ف', 'ل'];
  function tokens(n) { return n.split(' ').filter(Boolean); }
  function cands(tok) { var c = [tok]; PREF.forEach(function (p) { if (tok.indexOf(p) === 0 && tok.length - p.length >= 2) c.push(tok.slice(p.length)); }); return c; }
  function hasWord(n, words) {
    var toks = tokens(n);
    return words.some(function (w) {
      w = norm(w);
      if (w.indexOf(' ') >= 0) return (' ' + n + ' ').indexOf(' ' + w + ' ') >= 0 || toks.some(function (tk, i) { return cands(tk).indexOf(w.split(' ')[0]) >= 0 && (' ' + toks.slice(i + 1).join(' ') + ' ').indexOf(' ' + w.split(' ').slice(1).join(' ') + ' ') === 0; });
      return toks.some(function (tk) { return cands(tk).indexOf(w) >= 0; });
    });
  }
  // Crops named in the question (longest alias wins, so "ذرة رفيعة" is sorghum, not maize).
  var EXTRA_ALIASES = { berseem: ['برسيم', 'berseem', 'clover'] };
  function cropsIn(n) {
    var found = [], all = {};
    Object.keys(FS.crops.crops).forEach(function (k) { all[k] = FS.crops.crops[k].aliases.concat([FS.crops.crops[k].en.toLowerCase()]); });
    Object.keys(EXTRA_ALIASES).forEach(function (k) { all[k] = EXTRA_ALIASES[k]; });
    var hits = [];
    Object.keys(all).forEach(function (k) { all[k].forEach(function (a) { var na = norm(a); if (na.length >= 2 && hasWord(n, [na])) hits.push({ k: k, len: na.length, multi: na.indexOf(' ') >= 0, a: na }); }); });
    hits.sort(function (a, b) { return b.len - a.len; });
    hits.forEach(function (h) { if (found.indexOf(h.k) >= 0) return; if (found.some(function (f) { return hits.some(function (x) { return x.k === f && x.multi && x.a.indexOf(h.a) >= 0; }); })) return; found.push(h.k); });
    return found;
  }
  var MON_AR = ['يناير', 'فبراير', 'مارس', 'ابريل', 'مايو', 'يونيو', 'يوليو', 'اغسطس', 'سبتمبر', 'اكتوبر', 'نوفمبر', 'ديسمبر'];
  var MON_EN = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  function dateIn(n) {
    var month = null;
    MON_AR.forEach(function (m, i) { if (n.indexOf(m) >= 0) month = i + 1; });
    MON_EN.forEach(function (m, i) { if ((m === 'may' ? /\bmay\b/ : new RegExp('\\b' + m)).test(n)) month = i + 1; });
    var mm = n.match(/(?:شهر|month)\s*(\d{1,2})\b/); if (!month && mm && +mm[1] >= 1 && +mm[1] <= 12) month = +mm[1];
    if (!month) return null;
    var day = 15;
    if (/\b(early|start|beginning|first)\b/.test(n) || hasWord(n, ['اول', 'بدري', 'بدايه'])) day = 1;
    else if (/\b(mid|middle)\b/.test(n) || hasWord(n, ['نص', 'منتصف', 'وسط'])) day = 15;
    else if (/\b(late|end)\b/.test(n) || hasWord(n, ['اخر', 'نهايه'])) day = 25;
    var d = n.replace(/(?:شهر|month)\s*\d{1,2}/, '').match(/\b(\d{1,2})(?:st|nd|rd|th)?\b/); if (d && +d[1] >= 1 && +d[1] <= 31) day = +d[1];
    return { m: month, d: day };
  }
  function snap(keys, dt) {
    var inM = keys.filter(function (k) { return +k.split('-')[0] === dt.m; });
    if (!inM.length) return null;
    inM.sort(function (a, b) { return Math.abs(+a.split('-')[1] - dt.d) - Math.abs(+b.split('-')[1] - dt.d); });
    return inM[0];
  }
  var pad = function (x) { return (x < 10 ? '0' : '') + x; };
  function placeIn(n) {
    var SITE_WORDS = { gharbia: ['غربيه', 'طنطا', 'gharbia', 'tanta'], kafr_el_sheikh: ['كفر الشيخ', 'kafr el sheikh', 'kafr'], beheira: ['بحيره', 'دمنهور', 'beheira', 'behera'], menoufia: ['منوفيه', 'شبين الكوم', 'menoufia'], sharqia: ['شرقيه', 'زقازيق', 'sharqia', 'sharkia'], damietta: ['دمياط', 'damietta'], dakahlia: ['دقهليه', 'dakahlia'] };
    var found = null;
    Object.keys(SITE_WORDS).forEach(function (k) { if (!found && hasWord(n, SITE_WORDS[k])) found = { site: k }; });
    if (found) return found;
    if (hasWord(n, ['منصوره', 'mansoura'])) { var g0 = FS.map.governorates.filter(function (g) { return g.id === 'Dakahlia'; })[0]; var r0 = g0 && E.resolveGov(g0); if (r0) return { site: r0.site }; }
    var hit = null;
    FS.map.governorates.forEach(function (g) { var core = norm(g.ar).replace(/^ال/, ''); if (!hit && ((core.length >= 4 && hasWord(n, [core])) || hasWord(n, [g.id.toLowerCase()]))) hit = g; });
    if (hit) { var r = E.resolveGov(hit); return r ? { site: r.site, gov: hit } : { outside: hit }; }
    return null;
  }

  function answer(q) {
    var n = norm(q), out = [], site = S.site, place = I.site(site);
    if (!n) return L('Ask me about one field: wheat dates, water, salt, crops or income.', 'اسألني عن أرض واحدة: ميعاد القمح، المية، الملح، المحاصيل أو الدخل.');
    // 1. never forecast
    if (/\b(tons?|tonnes?|yield|forecast|predict|guarantee|promise)\b/.test(n) || /how much will i (get|harvest|earn|make)/.test(n) || hasWord(n, ['طن', 'اطنان', 'ضمان', 'اضمن', 'توقع', 'انتاجيه']) || /(هيطلع|هجيب|هكسب|هيجيب) كام/.test(n))
      return L('I cannot forecast yield, a harvest or profit. I can compare sowing dates, crop water need and salt tolerance for your place, and show average income across Egypt before costs.', 'مقدرش أتوقع المحصول ولا الحصاد ولا الربح. أقدر أقارن مواعيد الزراعة واحتياج المية وتحمّل الملح لمكانك، وأوريك متوسط دخل مصر قبل المصاريف.');
    // 2. a place in the question sets the place
    var pl = placeIn(n);
    if (pl && pl.outside) return L(pl.outside.id + ' is outside the Nile Delta. I only cover the Delta.', (pl.outside.ar) + ' برا دلتا النيل. أنا بغطي الدلتا بس.');
    if (pl && pl.site && pl.site !== site) { FS.setPlace(pl.site); site = S.site; place = I.site(site); out.push(L('Using ' + place + '.', 'هستخدم ' + place + '.')); }
    var crops = cropsIn(n), dt = dateIn(n);
    var isWheat = crops.indexOf('wheat') >= 0 || /\bwheat\b/.test(n);
    var wantsWater = /\b(water|irrigat\w*|thirst\w*)\b/.test(n) || hasWord(n, ['مي', 'ميه', 'مية', 'ري', 'يشرب', 'بيشرب', 'تشرب']);
    var wantsSalt = /\b(salt\w*|saline|salinity|crust|patch\w*)\b/.test(n) || hasWord(n, ['ملح', 'ملوحه', 'مالحه', 'مالح', 'بقع', 'قشره']);
    var wantsMoney = /\b(earn|money|income|price|profit\w*|pays?|best crop)\b/.test(n) || hasWord(n, ['دخل', 'فلوس', 'اكسب', 'مكسب', 'سعر', 'يكسب', 'ربح']);
    var wantsWhen = /\b(when|sow\w*|plant\w*|date|late|early)\b/.test(n) || hasWord(n, ['امتي', 'ميعاد', 'ازرع', 'يتزرع', 'زراعه', 'متاخر', 'بدري']);
    var cav = FS.meta.sites[site].caveat_kind === 'sea' ? L(' Caution: this NASA cell is mostly sea, so the heat numbers are not reliable here.', ' تنبيه: خلية ناسا دي أغلبها بحر، فأرقام الحر مش موثوقة هنا.') : '';

    if (wantsSalt) {
      var sign = /\bcrust|white\b/.test(n) || hasWord(n, ['قشره', 'بيضا', 'ابيض']) ? 'crust' : (/\bpatch/.test(n) || hasWord(n, ['بقع', 'بقعه']) ? 'patches' : (/\bno salt|no signs?\b/.test(n) || hasWord(n, ['مفيش', 'مافيش']) ? 'none' : null));
      var ece = sign ? E.eceOf(sign) : null, num = n.match(/\b(\d{1,2}(?:\.\d)?)\s*(?:ds|ec|ece)/);
      if (num) ece = +num[1];
      if (ece == null) { ece = E.eceOf(S.sign); sign = S.sign; }
      if (ece == null) return out.concat([L('Tell me what you see on the soil: no signs, white patches or a white crust, or a number from a soil test (ECe). No NASA product measures soil salt.', 'قولي إنت شايف إيه على الأرض: مفيش علامات، بقع بيضا، ولا قشرة بيضا، أو رقم تحليل التربة. مفيش منتج من ناسا بيقيس ملح التربة.')]).join(' ');
      var label = num ? 'ECe ' + I.n(ece) : '“' + I.t('sign_' + sign) + '”';
      var keysS = crops.filter(function (k) { return k !== 'wheat' || crops.length === 1; }).map(function (k) { return k === 'berseem' ? 'berseem' : (FS.crops.crops[k] && FS.crops.crops[k].salt_key); }).filter(function (k) { return k && FS.salt.crops[k]; });
      if (!keysS.length) keysS = Object.keys(FS.salt.crops);
      var parts = keysS.map(function (k) { var f = E.saltFit(k, ece); var nm = k === 'berseem' ? L('berseem', 'البرسيم') : I.cropLow(k); return nm + ': ' + I.status(f.status) + (f.pct != null ? ' (' + I.n(f.pct) + '%)' : L(' (below 50%)', ' (أقل من ٥٠٪)')); });
      if (crops.length && !keysS.length) parts = [L('That crop is not in the FAO-29 table, so I cannot judge its salt tolerance.', 'المحصول ده مش في جدول الفاو-٢٩، فمقدرش أحكم على تحمّله للملح.')];
      return out.concat([L('With ' + label + ', FAO paper 29 gives: ', 'مع ' + label + '، جدول الفاو-٢٩ بيقول: ') + parts.join(L('; ', '؛ ')) + '.' + src('salt', keysS.join(', ')) + L(' The sign-to-salinity link is our assumption: a soil test is better.', ' تحويل العلامة لملوحة افتراض مننا: التحليل أحسن.')]).join(' ');
    }
    if (isWheat && (wantsWhen || dt || /\b(heat|hot)\b/.test(n) || hasWord(n, ['حر', 'حراره']))) {
      var keys = Object.keys(FS.heat[site]), d = dt ? snap(keys, dt) : S.wheat;
      if (dt && !d) return out.concat([L('My wheat table covers 1 November to 25 January. Ask about a date in that window.', 'جدول القمح عندي من ١ نوفمبر لـ ٢٥ يناير. اسأل عن ميعاد في الفترة دي.')]).join(' ');
      if (dt && d !== S.wheat) { S.wheat = d; FS.changed(); }
      var h = FS.heat[site][d], sv = E.seasonVerdict(site, 'wheat', d), e1 = FS.heat[site]['11-01'];
      return out.concat([L('At ' + place + ', wheat sown ' + I.date(d) + ' meets about ' + h.median + ' hot days in grain filling (' + Math.round(h.p10) + ' to ' + Math.round(h.p90) + ' in 8 of 10 seasons), ' + (h.extra['32'] >= 0 ? '+' : '') + h.extra['32'] + ' against 15 November; sown 1 November it meets about ' + e1.median + '. Season (temperature): ' + I.label(sv.label) + '.',
        'في ' + place + '، القمح المزروع ' + I.date(d) + ' بيقابل حوالي ' + I.n(h.median) + ' يوم حر وقت امتلاء الحبة (' + I.n(Math.round(h.p10)) + ' لـ ' + I.n(Math.round(h.p90)) + ' في ٨ من ١٠ مواسم)، ' + I.n((h.extra['32'] >= 0 ? '+' : '') + h.extra['32']) + ' عن ١٥ نوفمبر؛ ولو اتزرع ١ نوفمبر حوالي ' + I.n(e1.median) + '. الموسم (الحرارة): ' + I.label(sv.label) + '.') + src('heat') + src('season', 'wheat') + cav]).join(' ');
    }
    if (wantsWater) {
      var w = FS.water[site], base = w.rice[E.DEFAULT_SUMMER.rice].etc;
      var parts2 = ['rice', 'maize', 'cotton'].map(function (c) { return I.cropLow(c) + ' ×' + I.n((w[c][E.DEFAULT_SUMMER[c]].etc / base).toFixed(2)); });
      var other = crops.filter(function (c) { return ['rice', 'maize', 'cotton'].indexOf(c) < 0; });
      return out.concat([L('Seasonal crop water need at ' + place + ', against rice, each on its usual date: ', 'احتياج المية في الموسم في ' + place + '، مقارنة بالرز، كل واحد في ميعاده: ') + parts2.join(L(', ', '، ')) + '.' + src('water', 'rice, maize, cotton') +
        L(' Rice is a floor (ponding and seepage are not counted).', ' الرز رقمه أقل من الحقيقة (الغمر والتسريب مش محسوبين).') + (other.length ? L(' I only have water tables for rice, maize and cotton.', ' عندي جداول مية للرز والذرة والقطن بس.') : '')]).join(' ');
    }
    var nonWheat = crops.filter(function (c) { return c !== 'wheat'; });
    if (nonWheat.length && (wantsWhen || dt)) {
      var c = nonWheat[0], why = E.notJudgedReason(c), cn = c === 'berseem' ? L('berseem', 'البرسيم') : I.cropLow(c);
      if (why || !(FS.season.sites[site] && FS.season.sites[site][c])) return out.concat([L('I cannot judge the season for ' + cn + ': ' + (why || 'it is not in the season table') + '.', 'مقدرش أحكم على موسم ' + cn + ': ' + (why ? L(why, why) : 'مش في جدول المواسم') + '.')]).join(' ');
      var best = E.seasonBest(site, c);
      if (dt) { var mmdd = pad(dt.m) + '-' + pad(dt.d), v = E.seasonVerdict(site, c, mmdd); return out.concat([L(cn.charAt(0).toUpperCase() + cn.slice(1) + ' sown around ' + I.date(mmdd) + ' at ' + place + ': ' + I.label(v.label) + (v.best ? '. The best temperature date was around ' + I.date(v.best) : '') + '.', cn + ' المزروع حوالي ' + I.date(mmdd) + ' في ' + place + ': ' + I.label(v.label) + (v.best ? '. أحسن ميعاد للحرارة كان حوالي ' + I.date(v.best) : '') + '.') + src('season', c) + L(' Temperature only, not a yield forecast.', ' الحرارة بس، مش توقع محصول.')]).join(' '); }
      return out.concat([best ? L('For ' + cn + ' at ' + place + ', the best sowing date for temperature was around ' + I.date(best) + '.', 'لـ ' + cn + ' في ' + place + '، أحسن ميعاد زراعة للحرارة كان حوالي ' + I.date(best) + '.') + src('season', c) : L('The temperature screen cannot separate the seasons for ' + cn + ' here.', 'شاشة الحرارة مش بتفرق بين المواسم لـ ' + cn + ' هنا.')]).join(' ');
    }
    if (wantsMoney || (crops.length && !wantsWhen)) {
      var ece2 = E.eceOf(S.sign), list = (crops.length ? crops.filter(function (k) { return FS.crops.crops[k]; }) : Object.keys(FS.crops.crops)).map(function (k) { return E.gross(k, ece2); }).sort(function (a, b) { return b.gross - a.gross; });
      if (!list.length) return out.concat([L('I have no income figure for that crop.', 'مفيش عندي رقم دخل للمحصول ده.')]).join(' ');
      var top = crops.length ? list : list.slice(0, 3);
      return out.concat([(crops.length ? '' : L('Highest approximate gross income per feddan, with your salt sign (“' + I.t('sign_' + S.sign) + '”): ', 'أعلى دخل إجمالي تقريبي للفدان، مع علامة الملح بتاعتك («' + I.t('sign_' + S.sign) + '»): ')) +
        top.map(function (g) { return I.crop(g.key) + ' ' + I.money(g.gross); }).join(L('; ', '؛ ')) + '.' + src('income', top.map(function (g) { return g.key; }).join(', ')) + L(' Averages across Egypt, before costs: an estimate, not a profit.', ' متوسطات مصر قبل المصاريف: تقدير، مش ربح.')]).join(' ');
    }
    if (/\b(nasa|data|satellite)\b/.test(n) || hasWord(n, ['ناسا', 'بيانات', 'قمر'])) return out.concat([L('Every number I give comes from NASA POWER daily weather (1990 to 2025) and FAO tables. NASA MODIS, MOD16A3GF, GPM IMERG and SRTM give pictures and checks.', 'كل رقم بقوله جاي من طقس ناسا باور اليومي (١٩٩٠ لـ ٢٠٢٥) وجداول الفاو. ومودس وMOD16A3GF وIMERG وSRTM بيدوا صور ومراجعات.') + src('heat')]).join(' ');
    if (out.length) return out.join(' ') + ' ' + L('What would you like to know about it?', 'عايز تعرف إيه عنها؟');
    return L('I cannot judge that from our tables. I can answer about wheat sowing dates and heat, crop water need, salt tolerance, sowing seasons and average income across Egypt.', 'مقدرش أحكم على ده من جداولنا. أقدر أجاوب عن ميعاد القمح والحر، واحتياج المية، وتحمّل الملح، ومواسم الزراعة، ومتوسط الدخل.');
  }

  var history = [], mounted = {};
  var SAMPLES = function () { return I.lang === 'ar' ? ['لو زرعت القمح في أول يناير؟', 'الذرة بتشرب مية قد إيه؟', 'أرضي فيها قشرة بيضا، القطن ينفع؟', 'هجيب كام طن قمح؟'] : ['What if I sow wheat in early January?', 'How much water does maize need?', 'My soil has a white crust. Is cotton OK?', 'Will I get 5 tons?']; };
  function greet() { return L('I am Eyad. I answer from our tables only, for ' + I.site(S.site) + ' (change it in the top bar).', 'أنا إياد. بجاوب من جداولنا بس، لـ ' + I.site(S.site) + ' (غيّرها من الشريط اللي فوق).'); }
  function draw(sfx) {
    var c = document.getElementById('chat' + sfx); if (!c) return;
    c.innerHTML = '<div class="msg bot">' + esc(greet()) + '</div>' + history.map(function (m) { return '<div class="msg ' + m.who + '"' + (m.dir ? ' dir="' + m.dir + '"' : '') + '>' + m.html + '</div>'; }).join('');
    c.scrollTop = c.scrollHeight;
    var q = document.getElementById('qchips' + sfx);
    if (q) { q.innerHTML = '<span class="dim small" style="align-self:center">' + I.t('ask_try') + '</span>' + SAMPLES().map(function (s) { return '<button type="button" class="chip" data-q="' + esc(s) + '">' + esc(s) + '</button>'; }).join(''); Array.prototype.forEach.call(q.querySelectorAll('[data-q]'), function (b) { b.onclick = function () { ask(b.getAttribute('data-q')); }; }); }
  }
  function drawAll() { Object.keys(mounted).forEach(draw); }
  function ask(q) {
    if (!q || !q.trim()) return;
    history.push({ who: 'me', html: esc(q), dir: /[؀-ۿ]/.test(q) ? 'rtl' : 'ltr' });
    var a = answer(q);
    var plain = a.replace(/<[^>]+>/g, '');
    history.push({ who: 'bot', html: a.replace(/(<button[^>]*>[^<]*<\/button>)|([^<]+)/g, function (m, b, txt) { return b ? b : esc(txt); }), dir: I.lang === 'ar' ? 'rtl' : 'ltr', plain: plain });
    drawAll();
  }
  function mount(sfx) {
    mounted[sfx] = true; draw(sfx);
    var f = document.getElementById('askForm' + sfx), inp = document.getElementById('askIn' + sfx);
    if (f) f.onsubmit = function (e) { e.preventDefault(); ask(inp.value); inp.value = ''; inp.focus(); };
  }
  FS.Ask = { answer: answer, ask: ask, mount: mount, refresh: drawAll, relabel: drawAll };
  mount('Panel');
  var fab = document.getElementById('askFab'), panel = document.getElementById('askPanel');
  fab.onclick = function () { var open = panel.hidden; panel.hidden = !open; fab.setAttribute('aria-expanded', open); if (open) { draw('Panel'); document.getElementById('askInPanel').focus(); } };
  document.getElementById('askClose').onclick = function () { panel.hidden = true; fab.setAttribute('aria-expanded', 'false'); fab.focus(); };
  if (location.hash.indexOf('#ask') === 0) FS.render();
})();
