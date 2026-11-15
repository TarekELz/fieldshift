// Field Shift explorer: state, routing and pages. All figures come from window.FS (data/*.js) through engine.js.
(function () {
  var FS = window.FS, E = FS.E, I = FS.I, t = I.t;
  var $ = function (id) { return document.getElementById(id); };
  var L = function (en, ar) { return I.lang === 'ar' ? ar : en; };
  var esc = function (s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var SITES = Object.keys(FS.meta.sites);
  var WHEAT_DATES = Object.keys(FS.heat[SITES[0]]);
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---------- state (only conveniences are remembered, in this browser) ----------
  var S = { site: 'gharbia', wheat: '12-01', crop: 'rice', sow: '06-15', sign: 'patches', view: 'farmer', lang: 'en', theme: null,
    hs: 'wheat', hsStep: 0, cropFilter: 'all', cropQuery: '', cropMode: 'gallery', cmp: [], measure: 'hot', firstVisit: true };
  var store = { get: function (k) { try { return localStorage.getItem('fs_' + k); } catch (e) { return null; } }, set: function (k, v) { try { localStorage.setItem('fs_' + k, v); } catch (e) { } } };
  ['site', 'wheat', 'crop', 'sow', 'sign', 'view', 'lang', 'theme'].forEach(function (k) { var v = store.get(k); if (v) { S[k] = v; if (k === 'view') S.firstVisit = false; } });
  if (!FS.meta.sites[S.site]) S.site = 'gharbia';
  if (!FS.heat[S.site][S.wheat]) S.wheat = '12-01';
  if (['rice', 'maize', 'cotton'].indexOf(S.crop) < 0) S.crop = 'rice';
  if (!FS.water[S.site][S.crop][S.sow]) S.sow = E.DEFAULT_SUMMER[S.crop];
  var save = function () { ['site', 'wheat', 'crop', 'sow', 'sign', 'view', 'lang'].forEach(function (k) { store.set(k, S[k]); }); if (S.theme) store.set('theme', S.theme); };
  FS.S = S;

  // ---------- sources: every number carries a chip that names its file and key ----------
  var SRC = {
    heat: { l: ['NASA POWER 1990 to 2025', 'ناسا باور ١٩٩٠-٢٠٢٥'], f: function () { return 'data/heat.json → ' + S.site + ' → ' + S.wheat + ' → median, p10, p90, extra["32"], series'; },
      n: ['Not a forecast. Reanalysis weather at about 50 km, not checked against Delta stations; compare sowing dates, not absolute counts.', 'مش توقع. طقس محسوب لمربعات حوالي ٥٠ كم ومش متراجع على محطات؛ قارن المواعيد مش الأرقام المطلقة.'] },
    water: { l: ['NASA POWER + FAO-56', 'ناسا باور + فاو-٥٦'], f: function () { return 'data/water.json → ' + S.site + ' → {crop} → {sowing date} → etc (ratio between crops)'; },
      n: ['Not millimetres to apply: crop water need only, no canal supply, rain or losses; rice is a floor (no ponding or seepage).', 'مش كمية مية تحطها: احتياج المحصول بس من غير فاقد ولا ترعة؛ الرز رقمه أقل من الحقيقة.'] },
    salt: { l: ['FAO-29', 'فاو-٢٩'], f: function () { return 'data/salt.json → crops → {crop} → points (ECe, yield %); sign_to_ece'; },
      n: ['A crop tolerance figure from the FAO table, not a forecast of your crop. The salinity assumed for each sign is the team’s assumption.', 'رقم تحمّل من جدول الفاو، مش توقع لمحصولك. تحويل العلامة لملوحة افتراض من الفريق.'] },
    season: { l: ['NASA POWER + FAO EcoCrop', 'ناسا باور + إيكوكروب'], f: function () { return 'data/season.json → sites → ' + S.site + ' → {crop} → [month, day, temperature score, bad share]'; },
      n: ['Temperature only, from a generic coarse table; never a yield model.', 'الحرارة بس من جدول عام؛ مش نموذج للمحصول.'] },
    income: { l: ['FAOSTAT 2020 to 2024', 'فاوستات ٢٠٢٠-٢٠٢٤'], f: function () { return 'data/crops.json → crops → {crop} → yield_kg_ha × feddan_ha (' + FS.crops.feddan_ha + ') × price_egp_per_t (' + FS.crops.price_year + '), × FAO-29 salt factor'; },
      n: ['Averages across Egypt, gross before costs. Not a profit and not a forecast for any field.', 'متوسطات مصر، إجمالي قبل المصاريف. مش ربح ومش توقع لأرض بعينها.'] },
    advice: { l: ['Team blueprints', 'قوالب الفريق'], f: function () { return 'data/blueprints.json → blueprints → {id}; chosen by code from the engine facts (same rules as the app)'; },
      n: ['Not written by an AI on the fly. The Arabic is a draft awaiting native review.', 'مش مكتوب بالذكاء الاصطناعي وقتها. العربي مسودة.'] },
    phen: { l: ['NASA MCD12Q2', 'ناسا MCD12Q2'], f: function () { return 'data/site_data_extra.json → sites → {site} → phenology → 1|2 → greenup, peak, dormancy (day of year)'; },
      n: ['A second check of the calendar the engines assume; it feeds no number the farmer sees.', 'مراجعة للتقويم بس؛ مش بيطلع منه رقم للفلاح.'] },
    climate: { l: ['NASA POWER monthly means', 'متوسطات ناسا باور'], f: function () { return 'data/climate.json → {site} → T2M_MAX[6] (July), 1990 to 2025'; },
      n: ['A ~50 km cell average, not a field measurement.', 'متوسط مربع ~٥٠ كم، مش قياس في الغيط.'] },
    paper: { l: ['Published research', 'رقم من الـ README'], f: function () { return 'README.md → The problem (papers read in full, literature/papers.csv in the repository)'; },
      n: ['A result from published research in the Nile Delta, not a number computed by this site.', 'نتيجة من الورقة البحثية، مش رقم محسوب هنا.'] },
    readme: { l: ['Project checks', 'فحوصات المشروع'], f: function () { return 'README.md → What we checked; result files in docs/checks/ in the repository'; },
      n: ['Checks run on the project data against NASA and FAO sources.', 'فحوصات اتعملت على بيانات المشروع قصاد مصادر ناسا وفاو.'] }
  };
  var src = function (k, detail) { return ' <button type="button" class="src" data-src="' + k + '"' + (detail ? ' data-d="' + esc(detail) + '"' : '') + '>' + esc(SRC[k].l[I.lang === 'ar' ? 1 : 0]) + '</button>'; };
  FS.src = src;
  function showSrc(btn) {
    var k = btn.getAttribute('data-src'), s = SRC[k], d = btn.getAttribute('data-d'), pop = $('srcPop');
    var f = s.f(); if (d) f = f.replace(/\{crop\}|\{id\}|\{site\}|\{sowing date\}/, d);
    pop.innerHTML = '<b>' + esc(s.l[I.lang === 'ar' ? 1 : 0]) + '</b><div><span class="dim">' + t('src_file') + ':</span> <code dir="ltr">' + esc(f) + '</code></div><div style="margin-top:6px"><span class="dim">' + t('src_not') + ':</span> ' + esc(s.n[I.lang === 'ar' ? 1 : 0]) + '</div>';
    pop.hidden = false;
    var r = btn.getBoundingClientRect(), w = Math.min(380, window.innerWidth * 0.9);
    var left = Math.max(8, Math.min(window.innerWidth - w - 8, r.left + window.scrollX - 20));
    pop.style.left = left + 'px'; pop.style.top = (r.bottom + window.scrollY + 6) + 'px';
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.src');
    if (b) { e.preventDefault(); showSrc(b); return; }
    if (!e.target.closest('#srcPop')) $('srcPop').hidden = true;
    if (!e.target.closest('#pillPop') && !e.target.closest('#pillBtn')) closePill();
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { $('srcPop').hidden = true; closePill(); } });

  // ---------- small helpers ----------
  var NAMES_EXTRA = { berseem: ['Berseem (Egyptian clover)', 'البرسيم'] };
  var CROPPIC = { rice: 1, maize: 1, cotton: 1, wheat: 1 };
  var cropPic = function (k, w) { return CROPPIC[k] ? '<img class="cpic" src="img/crops/' + k + '.svg" alt="" width="' + w + '" height="' + Math.round(w * 0.75) + '">' : ''; };
  var icon = function (n) { return '<img class="cico" src="img/crops/' + n + '.svg" alt="" width="40" height="40"> '; };
  var cropName = function (k) { return FS.crops.crops[k] ? I.crop(k) : (NAMES_EXTRA[k] ? L(NAMES_EXTRA[k][0], NAMES_EXTRA[k][1]) : k); };
  var signName = function (s) { return t('sign_' + s); };
  var pillLabel = function (l) { return '<span class="pill ' + I.labelCls(l) + '">' + esc(I.label(l)) + '</span>'; };
  var caveatOf = function (site) {
    var k = FS.meta.sites[site].caveat_kind;
    if (k === 'sea') return t('caveat_sea'); if (k === 'desert_edge') return t('caveat_desert'); if (k === 'shared_cell') return t('caveat_shared'); return null;
  };
  var ratioTxt = function (r) { return '×' + I.n(r.toFixed(2)); };
  // Listen: in Arabic, Eyad's own recorded voice (data/voice.js maps each advice line to an audio file; a public page cannot hold an API key, so every line is recorded
  // in advance, see scripts/build_explorer_voice.py). A line with no recording, and English, use the browser's own voice.
  var hasRecorded = function () { return !!(FS.voice && I.lang === 'ar'); };
  var canSpeak = function () { return 'speechSynthesis' in window || !!FS.voice; };
  var player = null;
  function stopVoice() {
    if (player) { player.onended = null; player.onerror = null; try { player.pause(); } catch (e) { } player = null; }
    if ('speechSynthesis' in window) { try { speechSynthesis.cancel(); } catch (e) { } }
    var on = document.querySelectorAll('.speakbtn.playing'); for (var i = 0; i < on.length; i++) on[i].classList.remove('playing');
  }
  function speak(text) { if (!('speechSynthesis' in window)) return; try { var u = new SpeechSynthesisUtterance(text); u.lang = I.lang === 'ar' ? 'ar-EG' : 'en-US'; speechSynthesis.cancel(); speechSynthesis.speak(u); } catch (e) { } }
  FS.speak = speak;
  // Plays the advice bubbles of a block one after another from their recordings; if any bubble has no recording the whole block uses the browser voice.
  function eyadSpeak(el, btn) {
    var bubbles = [].slice.call(el.querySelectorAll('.bubble')).map(function (x) { return x.textContent; });
    var items = bubbles.length ? bubbles : [el.textContent];
    var clips = hasRecorded() ? items.map(function (x) { return FS.voice[x]; }) : [];
    stopVoice();
    if (!clips.length || clips.some(function (c) { return !c; })) { speak(items.join(' ')); return; }
    btn.classList.add('playing');
    var i = 0;
    (function next() {
      if (i >= clips.length) { stopVoice(); return; }
      player = new Audio(clips[i++]);
      player.onended = next;
      player.onerror = function () { stopVoice(); speak(items.join(' ')); };
      var started = player.play(); if (started && started.catch) started.catch(function () { stopVoice(); speak(items.join(' ')); });
    })();
  }
  var speakBtn = function (id) { return canSpeak() ? ' <button type="button" class="tbtn speakbtn" data-speak="' + id + '" title="' + esc(L("Eyad's recorded voice (Arabic)", 'صوت إياد المسجّل')) + '">🔊 ' + t('speak') + '</button>' : ''; };
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('[data-speak]'); if (!b) return;
    if (b.classList.contains('playing')) { stopVoice(); return; }
    var el = $(b.getAttribute('data-speak')); if (el) eyadSpeak(el, b);
  });
  window.addEventListener('hashchange', stopVoice);
  var eyadAv = function () { return '<span class="av"><img src="img/eyad_main.jpg" alt="' + esc(L('Eyad, the assistant (AI-generated picture)', 'إياد، المساعد (صورة بالذكاء الاصطناعي)')) + '"><span class="ai">AI</span></span>'; };
  function state() { var rows = E.compare(S.site, S.crop, S.sow, S.wheat, S.sign); return { rows: rows, f: E.facts(S.site, rows) }; }

  // ---------- pages, views, nav ----------
  var PAGES = [['learn', 'nav_learn'], ['lab', 'nav_lab'], ['judges', 'nav_judges']];
  var VIEWS = { everyone: [], farmer: ['learn', 'lab', 'ask'], officer: ['lab', 'compare', 'crops'], researcher: ['methods', 'data', 'compare'], judge: ['judges', 'learn', 'data'] };
  var current = 'learn';
  function renderNav() {
    var path = VIEWS[S.view] || [];
    $('mainNav').innerHTML = PAGES.map(function (p) {
      var i = path.indexOf(p[0]), cls = (p[0] === current ? 'on ' : '') + (i >= 0 ? 'path' : (path.length ? 'off' : ''));
      return '<a href="#' + p[0] + '" class="' + cls + '"' + (p[0] === current ? ' aria-current="page"' : '') + '>' + (i >= 0 ? '<span class="stepno">' + I.n(i + 1) + '</span>' : '') + esc(t(p[1])) + '</a>';
    }).join('');
    var vs = $('viewSel');
    vs.innerHTML = ['everyone', 'farmer', 'officer', 'researcher', 'judge'].map(function (v) { return '<option value="' + v + '"' + (v === S.view ? ' selected' : '') + '>' + esc(t('v_' + v)) + '</option>'; }).join('');
    $('viewLink').textContent = L('Choose a view for farmers, extension officers, researchers or judges →', 'اختار طريقة للفلاح أو المرشد أو الباحث أو الحَكَم ←');
  }
  function setView(v) { S.view = v; document.body.classList.toggle('farmer', v === 'farmer'); save(); renderNav(); }

  function applyStatic() {
    var ar = I.lang === 'ar';
    document.documentElement.lang = ar ? 'ar' : 'en'; document.documentElement.dir = ar ? 'rtl' : 'ltr';
    $('honesty').textContent = t('honesty'); $('brandName').textContent = t('brand');
    $('badge').innerHTML = ar ? 'ناسا سبيس آبس<br>تحدي ٢٠٢٦' : 'NASA SPACE APPS<br>CHALLENGE 2026';
    $('menuBtn').textContent = t('menu'); $('langBtn').textContent = t('lang_btn'); $('langBtn').lang = ar ? 'en' : 'ar';
    $('viewLbl').textContent = t('view'); $('footText').textContent = t('footer'); $('footDraft').textContent = t('ar_draft');
    $('askFabTxt').textContent = t('ask_open'); $('askPanelTitle').textContent = t('ask_h'); $('askClose').textContent = t('close');
    $('askInPanel').placeholder = t('ask_ph'); $('askSendPanel').textContent = t('send');
    $('pillTitle').textContent = t('pill_title'); $('pillPlaceLbl').textContent = t('pill_place'); $('pillWheatLbl').textContent = t('pill_wheat'); $('pillDone').textContent = t('done');
    $('illus1').textContent = t('illus');
    if ($('illus2')) $('illus2').textContent = t('illus_crops');
    updatePill();
  }
  function updatePill() { $('pillText').textContent = I.site(S.site) + ' · ' + t('wheat_short') + ' ' + I.date(S.wheat); }
  function siteOptions(sel) {
    var named = SITES.filter(function (k) { return FS.meta.sites[k].kind !== 'cell'; }), cells = SITES.filter(function (k) { return FS.meta.sites[k].kind === 'cell'; });
    var o = function (k) { return '<option value="' + k + '"' + (k === sel ? ' selected' : '') + '>' + esc(I.site(k)) + '</option>'; };
    return '<optgroup label="' + esc(L('Named points', 'نقط بأسامي')) + '">' + named.map(o).join('') + '</optgroup><optgroup label="' + esc(L('Extra NASA cells', 'خلايا ناسا زيادة')) + '">' + cells.map(o).join('') + '</optgroup>';
  }
  function openPill() {
    $('pillPlace').innerHTML = siteOptions(S.site);
    $('pillWheat').innerHTML = WHEAT_DATES.map(function (d) { return '<option value="' + d + '"' + (d === S.wheat ? ' selected' : '') + '>' + I.date(d) + '</option>'; }).join('');
    var r = $('pillBtn').getBoundingClientRect(), pop = $('pillPop'); pop.hidden = false;
    pop.style.top = (r.bottom + window.scrollY + 8) + 'px'; pop.style.left = Math.max(8, Math.min(window.innerWidth - pop.offsetWidth - 8, r.left + window.scrollX)) + 'px';
    $('pillBtn').setAttribute('aria-expanded', 'true'); $('pillPlace').focus();
  }
  function closePill() { if (!$('pillPop').hidden) { $('pillPop').hidden = true; $('pillBtn').setAttribute('aria-expanded', 'false'); } }
  $('pillBtn').onclick = function () { if ($('pillPop').hidden) openPill(); else closePill(); };
  $('pillDone').onclick = function () { closePill(); $('pillBtn').focus(); };
  $('pillPlace').onchange = function () { setPlace(this.value); };
  $('pillWheat').onchange = function () { S.wheat = this.value; changed(); };
  function setPlace(k) {
    S.site = k;
    if (!FS.water[k][S.crop][S.sow]) S.sow = E.DEFAULT_SUMMER[S.crop];
    if (!FS.heat[k][S.wheat]) S.wheat = '11-15';
    changed();
  }
  FS.setPlace = setPlace;
  function changed() { save(); updatePill(); render(); if (FS.Ask) FS.Ask.refresh(); }
  FS.changed = changed;

  // ---------- routing ----------
  function render() {
    var h = (location.hash || '').replace('#', ''), m = h.match(/^([a-z]+)(?:-(\d))?$/), page = m ? m[1] : '', step = m && m[2] ? +m[2] : null;
    var all = PAGES.map(function (p) { return p[0]; }).concat(['views']);
    if (all.indexOf(page) < 0) page = 'learn';
    var changedPage = page !== current; current = page;
    all.forEach(function (p) { $('p-' + p).hidden = p !== page; });
    renderNav(); applyStatic();
    ({ learn: renderLearn, lab: renderLab, crops: renderCrops, compare: renderCompare, data: renderData, ask: renderAsk, methods: renderMethods, judges: renderJudges, views: renderViews })[page](step);
    document.title = (page === 'views' ? t('nav_views') : t(PAGES.filter(function (p) { return p[0] === page; })[0][1])) + ' · Field Shift: Egypt';
    $('mainNav').classList.remove('open'); $('menuBtn').setAttribute('aria-expanded', 'false');
    return changedPage;
  }
  window.addEventListener('hashchange', function () { var ch = render(); if (ch) { window.scrollTo(0, 0); $('main').focus({ preventScroll: true }); } else if (current === 'learn') { var st = $('stepper'); if (st) st.scrollIntoView({ block: 'start' }); } });

  // ---------- Views ----------
  function renderViews() {
    var P = { farmer: ['learn', 'lab', 'ask'], officer: ['lab', 'compare', 'crops'], researcher: ['methods', 'data', 'compare'], judge: ['judges', 'learn', 'data'] };
    var nm = function (p) { return t(PAGES.filter(function (x) { return x[0] === p; })[0][1]); };
    var card = function (v) {
      var path = P[v] || [];
      return '<button type="button" class="persona' + (S.view === v ? ' sel' : '') + '" data-view="' + v + '"><b>' + esc(t('v_' + v)) + '</b><span class="dim">' + esc(t('vd_' + v)) + '</span>' +
        (path.length ? '<span class="path">' + t('start') + ': ' + path.map(nm).join(' → ') + '</span>' : '<span class="path">' + esc(t('v_everyone')) + '</span>') + '</button>';
    };
    $('p-views').innerHTML = '<p class="eyebrow">' + t('views_eyebrow') + '</p><h1>' + t('views_h') + '</h1><p class="lead">' + t('views_sub') + '</p>' +
      '<div class="grid3">' + ['farmer', 'officer', 'researcher', 'judge', 'everyone'].map(card).join('') + '</div>' +
      '<p class="dim small" style="margin-top:18px">' + esc(L('Abu Ahmed is a fictional farmer from the README. The farmer view uses bigger text.', 'أبو أحمد فلاح خيالي من الـ README. طريقة الفلاح بتكبّر الكلام.')) + '</p>';
    Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
      b.onclick = function () { var v = b.getAttribute('data-view'); S.firstVisit = false; setView(v); location.hash = (VIEWS[v][0] || 'learn'); };
    });
  }

  // ---------- Learn: scene, hotspots, stepper ----------
  var HS = [{ id: 'canal', x: 11.5, y: 76 }, { id: 'rice', x: 40, y: 55 }, { id: 'wheat', x: 74, y: 60 }, { id: 'salt', x: 33.5, y: 84 }, { id: 'sat', x: 82, y: 16 }];
  var timer = null;
  function pick(ids, f) { for (var i = 0; i < ids.length; i++) { var b = E.blueprint(ids[i]); if (b && E.holds(b, f)) return { id: ids[i], txt: I.fill(b, f) }; } return null; }
  function story(id) {
    var st = state(), f = st.f, site = S.site, place = I.site(site);
    var riceSow = S.crop === 'rice' ? S.sow : E.DEFAULT_SUMMER.rice, rr = E.compare(site, 'rice', riceSow, S.wheat, S.sign), rf = E.facts(site, rr);
    var w = FS.water[site], base = w.rice[E.DEFAULT_SUMMER.rice].etc, rm = w.maize[E.DEFAULT_SUMMER.maize].etc / base, rc = w.cotton[E.DEFAULT_SUMMER.cotton].etc / base;
    var h = FS.heat[site][S.wheat], none = L('At these settings Eyad sees nothing to flag here.', 'بالإعدادات دي إياد مش شايف حاجة هنا تستاهل تنبيه.');
    var adv = function (p) { return p ? { txt: '«' + p.txt + '»', s: src('advice', p.id) } : { txt: none, s: '' }; };
    if (id === 'canal') return [
      { txt: L('Canal water comes in turns. Fields at the tail end of a canal get the least, and the least reliably.', 'مية الترعة بتيجي بالدور. الأرض اللي في آخر الترعة بتاخد أقل، ومش بانتظام.') },
      { txt: L('Published research from the western Delta found that 58% of farmers at the tail end said growing rice had become very difficult, and rice yields fell 30 to 50%.', 'أبحاث منشورة من غرب الدلتا لقت إن ٥٨٪ من فلاحين آخر الترعة قالوا إن الرز بقى صعب جداً، ومحصوله قل من ٣٠ لـ ٥٠٪.'), s: src('paper') },
      { txt: L('At ' + place + ', maize needs about ' + ratioTxt(rm) + ' and cotton ' + ratioTxt(rc) + ' of rice’s seasonal water, each sown on its usual date.', 'في ' + place + '، الذرة محتاجة حوالي ' + ratioTxt(rm) + ' والقطن ' + ratioTxt(rc) + ' من مية الرز في الموسم، كل واحد في ميعاده المعتاد.'), s: src('water', 'maize, cotton vs rice') },
      adv(pick(['water_heavy'], rf))];
    if (id === 'rice') return [
      { txt: L('Rice is the last summer crop to leave the field. When it is sown late, it is harvested late.', 'الرز آخر محصول صيفي بيسيب الأرض. لو اتزرع متأخر، بيتحصد متأخر.') },
      { txt: L('Rice sown ' + I.date(riceSow) + ' is ready around ' + I.date(rr[0].harvest) + ': ' + I.days(Math.abs(rr[0].gap)) + (rr[0].gap < 0 ? ' after' : ' before') + ' wheat on ' + I.date(S.wheat) + '.', 'الرز المزروع ' + I.date(riceSow) + ' بيخلص حوالي ' + I.date(rr[0].harvest) + ': ' + I.days(Math.abs(rr[0].gap)) + (rr[0].gap < 0 ? ' بعد' : ' قبل') + ' القمح في ' + I.date(S.wheat) + '.'), s: src('water', 'rice stage_days (meta.json → crops → rice)') },
      { txt: L('Crop stage lengths are FAO-56 (rice ' + FS.meta.crops.rice.stage_days.reduce(function (a, b) { return a + b; }, 0) + ' days); the heat each wheat date meets comes from 35 seasons of NASA POWER weather.', 'أطوال المراحل من الفاو-٥٦ (الرز ' + I.n(FS.meta.crops.rice.stage_days.reduce(function (a, b) { return a + b; }, 0)) + ' يوم)؛ والحر اللي كل ميعاد قمح بيقابله من ٣٥ موسم من طقس ناسا باور.'), s: src('heat') },
      adv(pick(['tight_gap'], rf))];
    if (id === 'wheat') return [
      { txt: L('Wheat sown late fills its grain in the spring heat.', 'القمح المتأخر بيملي حبته في حر الربيع.') },
      { txt: L('Published field trials found that wheat sown 7 to 13 January lost about 40% of its yield against mid November.', 'تجارب حقلية منشورة لقت إن القمح المزروع من ٧ لـ ١٣ يناير خسر حوالي ٤٠٪ من محصوله مقارنة بنص نوفمبر.'), s: src('paper') },
      { txt: L('At ' + place + ', wheat sown ' + I.date(S.wheat) + ' meets about ' + h.median + ' hot days in grain filling (median of 35 seasons), ' + (h.extra['32'] >= 0 ? '+' : '') + h.extra['32'] + ' against 15 November.', 'في ' + place + '، القمح المزروع ' + I.date(S.wheat) + ' بيقابل حوالي ' + I.n(h.median) + ' يوم حر وقت امتلاء الحبة (وسيط ٣٥ موسم)، ' + I.n((h.extra['32'] >= 0 ? '+' : '') + h.extra['32']) + ' عن ١٥ نوفمبر.'), s: src('heat') },
      adv(pick(['combo_late_salt', 'wheat_off_season', 'wheat_late'], f))];
    if (id === 'salt') {
      var sf = st.rows[0].saltS, wf = st.rows[0].saltW;
      return [
        { txt: L('Salty groundwater and poor drainage leave salt in the topsoil. It shows as white patches or a crust.', 'المية الجوفية المالحة وضعف الصرف بيسيبوا ملح في وش الأرض. بيبان كبقع بيضا أو قشرة.') },
        { txt: L('Published surveys of Delta farmers found that 57.2% report rising soil salinity. Rice helps wash salt out but is the thirstiest crop.', 'استطلاعات منشورة لفلاحين الدلتا لقت إن ٥٧٫٢٪ منهم بيقولوا إن ملوحة الأرض بتزيد. الرز بيغسل الملح بس هو أكتر محصول بيشرب مية.'), s: src('paper') },
        { txt: sf ? L('No NASA product measures soil salt, so the farmer says what he sees. With “' + signName(S.sign) + '”, FAO paper 29 gives ' + I.cropLow(S.crop) + ' ' + (sf.pct == null ? 'less than 50% (not advised)' : sf.pct + '%') + ' and wheat ' + (wf.pct == null ? 'less than 50%' : wf.pct + '%') + ' relative yield.', 'مفيش منتج من ناسا بيقيس ملح التربة، فالفلاح بيقول اللي شايفه. مع «' + signName(S.sign) + '»، جدول الفاو-٢٩ بيدي ' + I.crop(S.crop) + ' ' + (sf.pct == null ? 'أقل من ٥٠٪ (مش مناسب)' : I.n(sf.pct) + '٪') + ' والقمح ' + (wf.pct == null ? 'أقل من ٥٠٪' : I.n(wf.pct) + '٪') + ' من المحصول النسبي.')
                 : L('No NASA product measures soil salt, so the farmer says what he sees. No sign is given yet: choose one in the Field lab or in step 3 below.', 'مفيش منتج من ناسا بيقيس ملح التربة. لسه مفيش علامة: اختار واحدة في المعمل أو في الخطوة ٣ تحت.'), s: src('salt', S.crop) },
        adv(pick(['salt_not_advised_alt', 'salt_not_advised', 'salt_reduced', 'no_salt_info'], f))];
    }
    return [
      { txt: L('Heat and water need come from the weather, but most Delta villages have no weather station nearby.', 'الحر واحتياج المية جايين من الطقس، وأغلب قرى الدلتا مفيش جنبها محطة أرصاد.') },
      { txt: L('So the tool uses NASA POWER: daily weather from 1990 to 2025 for ' + SITES.length + ' points across the Delta (cells of about 50 km).', 'فالأداة بتستخدم ناسا باور: طقس يومي من ١٩٩٠ لـ ٢٠٢٥ لـ ' + I.n(SITES.length) + ' نقطة في الدلتا (مربعات حوالي ٥٠ كم).'), s: src('heat') },
      { txt: L('NASA POWER feeds every number a farmer sees. MODIS (MOD13Q1, MCD12Q2), MOD16A3GF, GPM IMERG and SRTM give the pictures and check the inputs.', 'ناسا باور ورا كل رقم الفلاح بيشوفه. ومودس وMOD16A3GF وIMERG وSRTM بيدوا الصور وبيراجعوا المدخلات.') },
      { txt: L('Eyad never invents a number: each one comes from these tables, and he says so when he cannot judge.', 'إياد عمره ما بيخترع رقم: كل رقم من الجداول دي، ولما مايقدرش يحكم بيقول كده.'), s: src('advice', 'generic') }];
  }
  var STEPNAMES = ['step_cause', 'step_effect', 'step_nasa', 'step_eyad'];
  function renderStory() {
    var s = story(S.hs), i = S.hsStep, card = $('story');
    card.innerHTML = '<div class="eb"><span>' + esc(t('hs_' + S.hs)).toUpperCase() + '</span><span class="bars">' + s.map(function (_, k) { return '<i class="' + (k <= i ? 'on' : '') + '"></i>'; }).join('') + '</span></div>' +
      '<div class="body"><h3><small>' + I.n(i + 1) + '/' + I.n(4) + '</small>' + t(STEPNAMES[i]) + '</h3><p>' + esc(s[i].txt) + (s[i].s || '') + '</p></div>' +
      '<div class="row">' + (i < 3 ? '<button type="button" class="tbtn" id="hsNext">' + t('next') + ' →</button>' : '') + '<button type="button" class="tbtn" id="hsReplay">↻ ' + t('replay') + '</button></div>';
    if ($('hsNext')) $('hsNext').onclick = function () { stopAuto(); S.hsStep = Math.min(3, S.hsStep + 1); renderStory(); };
    $('hsReplay').onclick = function () { S.hsStep = 0; renderStory(); startAuto(); };
    Array.prototype.forEach.call(document.querySelectorAll('.hs,[data-hs]'), function (b) { var on = (b.getAttribute('data-hs') === S.hs); b.classList.toggle('sel', on); if (b.classList.contains('chip')) b.setAttribute('aria-pressed', on ? 'true' : 'false'); });
  }
  function stopAuto() { if (timer) { clearInterval(timer); timer = null; } }
  function startAuto() { stopAuto(); if (reduced) return; timer = setInterval(function () { if (current !== 'learn' || S.hsStep >= 3) { stopAuto(); return; } S.hsStep++; renderStory(); }, 4200); }
  function renderHud() {
    var h = FS.heat[S.site][S.wheat];
    $('hud').innerHTML = [[t('hud_place'), I.site(S.site)], [t('hud_wheat'), I.date(S.wheat)], [t('hud_hot'), I.n(h.median) + ' (' + I.n((h.extra['32'] >= 0 ? '+' : '') + h.extra['32']) + ')'], [t('hud_summer'), I.crop(S.crop) + ' · ' + I.date(S.sow)], [t('hud_salt'), signName(S.sign)]]
      .map(function (r) { return '<div><span>' + esc(r[0]) + '</span><b>' + esc(r[1]) + '</b></div>'; }).join('');
  }
  function renderLearn(step) {
    step = step || 1;
    $('learnEb').textContent = t('learn_eyebrow'); $('learnH').textContent = t('learn_h'); $('learnSub').textContent = t('learn_sub');
    $('hotspots').innerHTML = HS.map(function (h) { return '<button type="button" class="hs" data-hs="' + h.id + '" style="left:' + h.x + '%;top:' + h.y + '%" aria-label="' + esc(t('hs_' + h.id)) + '"><span class="ring" aria-hidden="true"></span><span class="tag">' + esc(t('hs_' + h.id)) + '</span></button>'; }).join('');
    $('cropStrip').innerHTML = ['rice', 'maize', 'cotton', 'wheat'].map(function (k) { return '<figure>' + cropPic(k, 160) + '<figcaption><b>' + esc(I.crop(k)) + '</b><span class="dim small">' + L(k === 'wheat' ? 'Winter crop' : 'Summer crop', k === 'wheat' ? 'محصول شتوي' : 'محصول صيفي') + '</span></figcaption></figure>'; }).join('');
    $('hsChips').innerHTML = HS.map(function (h) { return '<button type="button" class="chip" data-hs="' + h.id + '" aria-pressed="false"><span class="cd" aria-hidden="true"></span>' + esc(t('hs_' + h.id)) + '</button>'; }).join('');
    Array.prototype.forEach.call(document.querySelectorAll('[data-hs]'), function (b) { b.onclick = function () { S.hs = b.getAttribute('data-hs'); S.hsStep = 0; renderStory(); startAuto(); }; });
    renderHud(); renderStory();
    var names = ['stepper_1', 'stepper_2', 'stepper_3', 'stepper_4', 'stepper_try'];
    $('stepper').innerHTML = names.map(function (n, i) { return '<a href="#learn-' + (i + 1) + '" class="' + (step === i + 1 ? 'on' : '') + '"' + (step === i + 1 ? ' aria-current="step"' : '') + '><span class="no">' + I.n(i + 1) + '</span>' + esc(t(n)) + '</a>'; }).join('') + '<a class="skip" href="#lab">' + esc(t('skip_lab')) + ' →</a>';
    var box = $('learnStep');
    if (step === 1) box.innerHTML = learn1(); else if (step === 2) box.innerHTML = learn2(); else if (step === 3) box.innerHTML = learn3(); else if (step === 4) box.innerHTML = learn4(); else box.innerHTML = learnTry();
    bindLearn(step);
    $('seeAppH').textContent = t('see_app'); $('seeAppSub').textContent = t('see_app_sub');
    var SHOTS = [['01_ask', 'Ask: where is the field?', 'السؤال: الأرض فين؟'], ['02_goal', 'Goal question', 'سؤال الهدف'], ['03_earn_more', 'Earn more', 'أكسب أكتر'], ['04_verdict', 'Verdict per crop', 'الحكم لكل محصول'], ['05_advice', 'Advice', 'النصيحة'], ['06_water', 'Water', 'المية'], ['07_salt', 'Salt', 'الملح'], ['08_pro_climate_heat', 'Professional: climate and heat', 'للمحترفين: المناخ والحر'], ['09_pro_heat_water', 'Professional: heat and water', 'للمحترفين: الحر والمية'], ['10_pro_compare', 'Professional: compare', 'للمحترفين: مقارنة']];
    $('appList').innerHTML = SHOTS.map(function (s) { return '<figure><img loading="lazy" src="img/app/' + s[0] + '.jpg" alt="' + esc(L('App screen: ', 'شاشة التطبيق: ') + L(s[1], s[2])) + '"><figcaption>' + esc(L(s[1], s[2])) + '</figcaption></figure>'; }).join('');
  }
  function sideCard(date, label, max) {
    var h = FS.heat[S.site][date], ex = h.extra['32'];
    return '<div class="card side"><span class="tag2">' + esc(label) + ' · ' + I.date(date) + '</span><div class="row" style="align-items:baseline;margin-top:8px"><span class="big">' + I.n(h.median) + '</span><span class="dim">' + t('hot_days') + src('heat') + '</span></div>' +
      '<div class="dim small">' + I.n(Math.round(h.p10)) + '–' + I.n(Math.round(h.p90)) + ' ' + t('range_lbl') + ' · ' + I.n((ex >= 0 ? '+' : '') + ex) + ' ' + t('vs15') + '</div>' +
      '<div class="spark" role="img" aria-label="' + esc(t('seasons35')) + '">' + h.series.map(function (v) { return '<i style="height:' + Math.max(2, Math.round(v / max * 100)) + '%" title="' + v + '"></i>'; }).join('') + '</div><div class="dim small">' + t('seasons35') + '</div></div>';
  }
  function learn1() {
    var max = 1; [ '11-01', S.wheat ].forEach(function (d) { FS.heat[S.site][d].series.forEach(function (v) { if (v > max) max = v; }); });
    var cav = caveatOf(S.site);
    return '<h2>' + icon('heat') + t('s1_h') + '</h2><p class="lead">' + esc(t('s1_p')) + src('paper') + '</p>' + (cav ? '<div class="caveat">' + esc(cav) + '</div>' : '') +
      '<div class="sbs">' + sideCard('11-01', t('early'), max) + sideCard(S.wheat, t('late'), max) + '</div>' +
      '<p class="dim small" style="margin-top:10px">' + t('hot_def') + '</p><div class="chips" id="wheatChips" aria-label="' + esc(t('pill_wheat')) + '">' + WHEAT_DATES.map(function (d) { return '<button type="button" class="chip" data-wheat="' + d + '" aria-pressed="' + (d === S.wheat) + '">' + I.date(d) + '</button>'; }).join('') + '</div>';
  }
  function learn2() {
    var w = FS.water[S.site], base = w.rice[E.DEFAULT_SUMMER.rice].etc, crops = ['rice', 'maize', 'cotton'];
    return '<h2>' + icon('water') + t('s2_h') + '</h2><p class="lead">' + esc(t('s2_p')) + src('paper') + '</p><div class="card"><div class="bars">' + crops.map(function (c) {
      var r = w[c][E.DEFAULT_SUMMER[c]].etc / base;
      return '<div class="bar"><span>' + esc(I.crop(c)) + ' <span class="dim small">' + I.date(E.DEFAULT_SUMMER[c]) + '</span></span><span class="track"><span class="fillb" style="width:' + Math.min(100, r / 1.2 * 100) + '%;display:block"></span></span><b>' + ratioTxt(r) + '</b></div>';
    }).join('') + '</div><p class="dim small" style="margin:12px 0 0">' + esc(I.site(S.site)) + ' · ' + t('rice_floor') + src('water', 'rice, maize, cotton') + '</p></div>';
  }
  function saltBars() {
    var ece = E.eceOf(S.sign), keys = Object.keys(FS.salt.crops);
    if (ece == null) return '<p class="dim">' + esc(L('No sign chosen: the salt effect cannot be judged.', 'مفيش علامة: مقدرش أحكم على الملح.')) + '</p>';
    return '<div class="bars">' + keys.map(function (k) {
      var y = E.yieldPotential(FS.salt.crops[k].points, ece), cls = y == null ? 'bad' : (y >= 90 ? 'ok' : (y >= 75 ? 'warn' : 'bad'));
      return '<div class="bar"><span>' + cropPic(k, 28) + esc(cropName(k)) + '</span><span class="track"><span class="fillb ' + cls + '" style="display:block;width:' + (y == null ? 4 : Math.round(y)) + '%"></span></span><b>' + (y == null ? '<50%' : I.n(Math.round(y)) + '%') + '</b></div>';
    }).join('') + '</div>';
  }
  var signSeg = function (id) { return '<div class="seg" id="' + id + '" role="group">' + ['unknown', 'none', 'patches', 'crust'].map(function (s) { return '<button type="button" class="chip" data-sign="' + s + '" aria-pressed="' + (s === S.sign) + '">' + esc(signName(s)) + '</button>'; }).join('') + '</div>'; };
  function learn3() {
    return '<h2>' + icon('salt') + t('s3_h') + '</h2><p class="lead">' + esc(t('s3_p')) + src('paper') + '</p>' + signSeg('signSeg3') +
      '<div class="card" style="margin-top:14px"><p class="dim small" style="margin-top:0">' + t('tol_pct') + src('salt', 'all crops in salt.json') + '</p>' + saltBars() + '<p class="dim small" style="margin-bottom:0">' + esc(t('sign_note')) + '</p></div>';
  }
  function adviceBlock(prefix) {
    var st = state(), sel = E.select(st.f);
    return '<div class="eyad">' + eyadAv() + '<div style="flex:1;min-width:0"><div id="' + prefix + 'Adv">' + sel.map(function (b, i) { return '<div class="bubble">' + esc(I.fill(b, st.f)) + '</div>'; }).join('') + '</div>' +
      '<div class="row" style="margin-top:8px">' + src('advice', sel.map(function (b) { return b.id; }).join(', ')) + speakBtn(prefix + 'Adv') + '</div></div></div>';
  }
  function learn4() {
    var st = state(), f = st.f, sel = E.select(f);
    var fl = [['summer_crop', I.crop(f.summer_crop)], ['summer_date', I.date(f.summer_date)], ['wheat_date', I.date(f.wheat_date)], ['gap', I.n(f.gap)], ['heat_extra', I.n(f.heat_extra)], ['salt_summer', f.salt_summer ? I.status(f.salt_summer) : '—'], ['summer_label', I.label(f.summer_label)], ['wheat_label', I.label(f.wheat_label)], ['alt_crop', f.alt_crop ? I.crop(f.alt_crop) : '—'], ['alt_water_pct', f.alt_water_pct == null ? '—' : I.n(f.alt_water_pct) + '%'], ['sea', f.sea ? 'true' : 'false']];
    return '<h2>' + t('s4_h') + '</h2><p class="lead">' + esc(t('s4_p')) + '</p>' +
      '<div class="card reveal" id="rv1"><h3 class="small dim mono">01 · ' + t('facts') + src('heat') + src('water', S.crop) + src('salt', S.crop) + '</h3><div class="factlist">' + fl.map(function (x) { return '<div>' + x[0] + ' <b>' + esc(x[1]) + '</b></div>'; }).join('') + '</div></div>' +
      '<div class="card reveal" id="rv2" style="margin-top:10px"><h3 class="small dim mono">02 · ' + t('chosen') + '</h3><div class="chips">' + sel.map(function (b) { return '<span class="chip on" style="cursor:default">' + b.id + ' · ' + b.priority + '</span>'; }).join('') + '</div></div>' +
      '<div class="card reveal" id="rv3" style="margin-top:10px">' + adviceBlock('l4') + '</div>' +
      '<div class="row" style="margin-top:12px"><button type="button" class="tbtn" id="rvReplay">↻ ' + t('replay') + '</button><a class="btn p" href="#learn-5">' + t('stepper_try') + ' →</a></div>';
  }
  function learnTry() {
    return '<h2>' + t('try_h') + '</h2><p class="lead">' + esc(t('lab_sub')) + '</p><div class="row"><a class="btn p" href="#lab">' + t('go_lab') + ' →</a></div>';
  }
  function reveal() { var ids = ['rv1', 'rv2', 'rv3']; ids.forEach(function (i) { var e = $(i); if (e) e.classList.toggle('shown', reduced); }); if (reduced) return; ids.forEach(function (i, k) { setTimeout(function () { var e = $(i); if (e) e.classList.add('shown'); }, 350 + k * 900); }); }
  function bindLearn(step) {
    Array.prototype.forEach.call(document.querySelectorAll('[data-wheat]'), function (b) { b.onclick = function () { S.wheat = b.getAttribute('data-wheat'); changed(); }; });
    Array.prototype.forEach.call(document.querySelectorAll('#signSeg3 [data-sign]'), function (b) { b.onclick = function () { S.sign = b.getAttribute('data-sign'); changed(); }; });
    if (step === 4) { reveal(); $('rvReplay').onclick = reveal; }
  }

  // ---------- Field lab ----------
  function renderLab() {
    var sows = Object.keys(FS.water[S.site][S.crop]), si = Math.max(0, sows.indexOf(S.sow)), wi = Math.max(0, WHEAT_DATES.indexOf(S.wheat));
    $('p-lab').innerHTML = '<p class="eyebrow">' + t('lab_eyebrow') + '</p><div class="headrow"><h1>' + t('lab_h') + '</h1><p class="lead">' + esc(t('lab_sub')) + '</p></div>' +
      '<div class="lab"><div class="card ctrls">' +
      '<label>' + t('c_place') + '<select id="labSite">' + siteOptions(S.site) + '</select></label>' +
      '<div><span class="dim small">' + t('c_crop') + '</span><div class="seg" id="labCrop" style="margin-top:6px">' + ['rice', 'maize', 'cotton'].map(function (c) { return '<button type="button" class="chip" data-crop="' + c + '" aria-pressed="' + (c === S.crop) + '">' + cropPic(c, 28) + esc(I.crop(c)) + '</button>'; }).join('') + '</div></div>' +
      '<label>' + t('c_sow') + ' <output id="sowOut">' + I.date(S.sow) + '</output><input type="range" id="labSow" min="0" max="' + (sows.length - 1) + '" step="1" value="' + si + '" aria-valuetext="' + I.date(S.sow) + '"></label>' +
      '<label>' + t('c_wheat') + ' <output id="wheatOut">' + I.date(S.wheat) + '</output><input type="range" id="labWheat" min="0" max="' + (WHEAT_DATES.length - 1) + '" step="1" value="' + wi + '" aria-valuetext="' + I.date(S.wheat) + '"></label>' +
      '<div><span class="dim small">' + t('c_salt') + '</span><div style="margin-top:6px">' + signSeg('labSign') + '</div></div>' +
      '<span class="est">' + t('estimate_badge') + '</span></div><div id="labOut"></div></div>';
    $('labSite').onchange = function () { setPlace(this.value); };
    Array.prototype.forEach.call(document.querySelectorAll('#labCrop [data-crop]'), function (b) { b.onclick = function () { S.crop = b.getAttribute('data-crop'); if (!FS.water[S.site][S.crop][S.sow]) S.sow = E.DEFAULT_SUMMER[S.crop]; changed(); }; });
    Array.prototype.forEach.call(document.querySelectorAll('#labSign [data-sign]'), function (b) { b.onclick = function () { S.sign = b.getAttribute('data-sign'); save(); Array.prototype.forEach.call(document.querySelectorAll('#labSign [data-sign]'), function (x) { x.setAttribute('aria-pressed', x === b); }); labOut(); updatePill(); }; });
    $('labSow').oninput = function () { S.sow = sows[+this.value]; $('sowOut').textContent = I.date(S.sow); this.setAttribute('aria-valuetext', I.date(S.sow)); save(); labOut(); };
    $('labWheat').oninput = function () { S.wheat = WHEAT_DATES[+this.value]; $('wheatOut').textContent = I.date(S.wheat); this.setAttribute('aria-valuetext', I.date(S.wheat)); save(); updatePill(); labOut(); };
    labOut();
  }
  function whyTxt(v, r) {
    var vars = { crop: I.cropLow(r.crop), days: I.days(v.why === 'gap_tight' ? r.gap : r.extra32) };
    return t('why_' + v.why, vars);
  }
  function labOut() {
    var st = state(), rows = st.rows, f = st.f, cav = caveatOf(S.site);
    var html = (cav ? '<div class="caveat">' + esc(cav) + '</div>' : '') + '<div class="card" style="margin-bottom:14px">' + adviceBlock('lab') + '</div><div class="grid3">';
    rows.forEach(function (r) {
      var v = E.verdict(r), sv = E.seasonVerdict(S.site, r.crop, r.sow);
      html += '<div class="rot' + (r.existing ? ' yours' : '') + '"><div class="dim small mono">' + (r.existing ? t('yours') : t('option')) + '</div>' + cropPic(r.crop, 160) + '<h3>' + esc(I.crop(r.crop)) + ' <span class="dim small">' + t('then_wheat') + '</span></h3>' +
        '<div class="lvl l' + v.level + '">' + t('lvl' + v.level) + '</div><div class="small">' + esc(whyTxt(v, r)) + '</div><div class="kv">' +
        '<span>' + t('c_sow') + '</span><b>' + I.date(r.sow) + '</b><span>' + t('harvest_lbl') + '</span><b>' + I.date(r.harvest) + '</b><span>' + t('c_wheat') + '</span><b>' + I.date(r.wheat) + '</b>' +
        '<span>' + t('gap_lbl') + '</span><b>' + I.n(r.gap) + '</b>' +
        '<span>' + t('water_vs') + '<br>' + src('water', r.crop) + '</span><b>' + ratioTxt(r.ratio) + '</b>' +
        '<span>' + t('hot_wheat') + '<br>' + src('heat') + '</span><b>' + I.n(r.heat) + ' (' + I.n((r.extra32 >= 0 ? '+' : '') + r.extra32) + ')</b>' +
        '<span>' + t('salt_lbl') + '<br>' + src('salt', r.crop) + '</span><b>' + (r.saltS ? I.status(r.saltS.status) + (r.saltS.pct != null ? ' ' + I.n(r.saltS.pct) + '%' : '') : t('salt_unknown')) + '</b>' +
        '<span>' + t('season_lbl') + '<br>' + src('season', r.crop) + '</span><b>' + pillLabel(sv.label) + '</b></div></div>';
    });
    html += '</div><div class="wys" style="margin-top:14px"><b style="color:var(--text)">' + t('wys_h') + '</b><br>' + esc(t('wys_p')) + '</div>';
    $('labOut').innerHTML = html;
  }

  // ---------- Crops ----------
  function cropInfo(k) {
    var c = FS.crops.crops[k], ece = E.eceOf(S.sign), g = E.gross(k, ece), why = E.notJudgedReason(k), best = why ? null : E.seasonBest(S.site, k);
    return { k: k, c: c, g: g, notJudged: !!why || !best, why: why, best: best, wheatNow: k === 'wheat' ? E.seasonVerdict(S.site, 'wheat', S.wheat) : null };
  }
  var GLOW = { summer: '#e6a94a', winter: '#62b2ec', any: '#5dc48a', orchard: '#b48cf0' };
  function renderCrops() {
    var all = Object.keys(FS.crops.crops).map(cropInfo).sort(function (a, b) { return b.g.gross - a.g.gross; });
    all.forEach(function (x, i) { x.rank = i + 1; });
    var max = all[0].g.gross, q = S.cropQuery.trim().toLowerCase();
    var list = all.filter(function (x) { return (S.cropFilter === 'all' || x.c.group === S.cropFilter) && (!q || (x.c.en + ' ' + x.c.ar + ' ' + x.c.aliases.join(' ')).toLowerCase().indexOf(q) >= 0); });
    var saltLine = function (x) { return !x.g.saltKnown ? (E.eceOf(S.sign) == null ? t('salt_unknown') : L('No FAO-29 entry', 'مش في جدول الفاو-٢٩')) : (x.g.beyond ? t('beyond') : I.n(x.g.saltPct) + '%'); };
    var seasonLine = function (x) { return x.notJudged ? '<span class="pill na">' + t('l_na') + '</span> <span class="dim small">' + esc(x.why || L('the temperature score does not separate the seasons here', 'درجة الحرارة مش بتفرق بين المواسم هنا')) + '</span>' : esc(t('best_sow')) + ': <b>' + I.date(x.best) + '</b>' + (x.wheatNow ? ' · ' + pillLabel(x.wheatNow.label) : '') + src('season', x.k); };
    var body;
    if (S.cropMode === 'gallery') {
      body = '<div class="cards">' + list.map(function (x) {
        var inCmp = S.cmp.indexOf(x.k) >= 0;
        return '<article class="ccard' + (x.notJudged ? ' dimmed' : '') + '"><div class="ctop"><span class="glow" style="background:radial-gradient(circle at 70% 60%,' + GLOW[x.c.group] + ',transparent 60%)"></span><span>' + esc(t('g_' + x.c.group)) + '</span><span>#' + I.n(x.rank) + '</span></div>' +
          '<div class="cbody"><h3>' + esc(I.crop(x.k)) + '</h3><div class="money">' + I.money(x.g.gross) + '</div><div class="dim small">' + t('per_feddan') + src('income', x.k) + '</div>' +
          '<div class="meter" aria-hidden="true"><i style="width:' + Math.round(x.g.gross / max * 100) + '%"></i></div>' +
          '<div class="small">' + t('salt_effect') + ': <b>' + saltLine(x) + '</b>' + (x.g.saltKnown ? src('salt', x.c.salt_key) : '') + '</div><div class="small">' + seasonLine(x) + '</div>' +
          '<button type="button" class="tbtn add" data-cmp="' + x.k + '" aria-pressed="' + inCmp + '">' + (inCmp ? '✓ ' + t('remove_cmp') : '+ ' + t('add_cmp')) + '</button></div></article>';
      }).join('') + '</div>';
    } else {
      body = '<div class="tablewrap"><table><thead><tr><th>' + t('rank') + '</th><th>' + L('Crop', 'المحصول') + '</th><th>' + t('group') + '</th><th>' + t('per_feddan') + '</th><th>' + t('salt_effect') + '</th><th>' + t('season_lbl') + '</th><th></th></tr></thead><tbody>' +
        list.map(function (x) { var inCmp = S.cmp.indexOf(x.k) >= 0; return '<tr class="' + (x.notJudged ? 'dimmed' : '') + '"><td class="num">' + I.n(x.rank) + '</td><td>' + esc(I.crop(x.k)) + '</td><td>' + esc(t('g_' + x.c.group)) + '</td><td class="num">' + I.money(x.g.gross) + src('income', x.k) + '</td><td>' + saltLine(x) + '</td><td>' + seasonLine(x) + '</td><td><button type="button" class="tbtn" data-cmp="' + x.k + '" aria-pressed="' + inCmp + '">' + (inCmp ? t('remove_cmp') : '+') + '</button></td></tr>'; }).join('') + '</tbody></table></div>';
    }
    var cmpRows = S.cmp.map(function (k) { return all.filter(function (x) { return x.k === k; })[0]; }).filter(Boolean);
    var tray = '<div class="card tray"><h3>' + t('cmp_tray') + '</h3>' + (cmpRows.length ? '<div class="tablewrap"><table><thead><tr><th></th>' + cmpRows.map(function (x) { return '<th>' + esc(I.crop(x.k)) + '</th>'; }).join('') + '</tr></thead><tbody>' +
      '<tr><td>' + t('per_feddan') + '</td>' + cmpRows.map(function (x) { return '<td class="num">' + I.money(x.g.gross) + '</td>'; }).join('') + '</tr>' +
      '<tr><td>' + L('Before salt', 'قبل الملح') + '</td>' + cmpRows.map(function (x) { return '<td class="num">' + I.money(x.g.base) + '</td>'; }).join('') + '</tr>' +
      '<tr><td>' + t('salt_effect') + '</td>' + cmpRows.map(function (x) { return '<td>' + saltLine(x) + '</td>'; }).join('') + '</tr>' +
      '<tr><td>' + t('group') + '</td>' + cmpRows.map(function (x) { return '<td>' + esc(t('g_' + x.c.group)) + '</td>'; }).join('') + '</tr>' +
      '<tr><td>' + t('season_lbl') + '</td>' + cmpRows.map(function (x) { return '<td>' + seasonLine(x) + '</td>'; }).join('') + '</tr></tbody></table></div>' : '<p class="dim">' + t('cmp_empty') + '</p>') + '</div>';
    $('p-crops').innerHTML = '<p class="eyebrow">' + t('crops_eyebrow') + '</p><div class="headrow"><h1>' + t('crops_h') + '</h1><p class="lead">' + esc(t('crops_sub')) + ' ' + L('Salt sign now: ', 'علامة الملح دلوقتي: ') + '<b>' + esc(signName(S.sign)) + '</b> · ' + esc(I.site(S.site)) + '.</p></div>' +
      '<div class="toolbar"><label class="sr" for="cropQ">' + t('search') + '</label><input type="search" id="cropQ" placeholder="' + esc(t('search')) + '" value="' + esc(S.cropQuery) + '">' +
      '<div class="chips">' + ['all', 'summer', 'winter', 'any', 'orchard'].map(function (g) { return '<button type="button" class="chip" data-filter="' + g + '" aria-pressed="' + (S.cropFilter === g) + '">' + t('f_' + g) + '</button>'; }).join('') + '</div><span class="sp"></span>' +
      signSeg('cropSign') + '<div class="chips"><button type="button" class="chip" data-mode="gallery" aria-pressed="' + (S.cropMode === 'gallery') + '">' + t('gallery') + '</button><button type="button" class="chip" data-mode="table" aria-pressed="' + (S.cropMode === 'table') + '">' + t('table') + '</button></div></div>' +
      '<p class="count">' + I.n(list.length) + ' ' + t('shown').toUpperCase() + ' · ' + t('dimmed_note') + '</p>' + body + tray;
    $('cropQ').oninput = function () { S.cropQuery = this.value; var pos = this.selectionStart; renderCrops(); var q2 = $('cropQ'); q2.focus(); try { q2.setSelectionRange(pos, pos); } catch (e) { } };
    Array.prototype.forEach.call(document.querySelectorAll('[data-filter]'), function (b) { b.onclick = function () { S.cropFilter = b.getAttribute('data-filter'); renderCrops(); }; });
    Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) { b.onclick = function () { S.cropMode = b.getAttribute('data-mode'); renderCrops(); }; });
    Array.prototype.forEach.call(document.querySelectorAll('#cropSign [data-sign]'), function (b) { b.onclick = function () { S.sign = b.getAttribute('data-sign'); changed(); }; });
    Array.prototype.forEach.call(document.querySelectorAll('[data-cmp]'), function (b) { b.onclick = function () { var k = b.getAttribute('data-cmp'), i = S.cmp.indexOf(k); if (i >= 0) S.cmp.splice(i, 1); else { if (S.cmp.length >= 3) S.cmp.shift(); S.cmp.push(k); } renderCrops(); }; });
  }

  // ---------- Compare + map ----------
  var MEASURES = ['hot', 'water', 'season', 'tmax'];
  function measureRows() {
    var crop = S.crop, d = E.DEFAULT_SUMMER[crop], base = FS.water[S.site][crop][d].etc, ORD = { 'right season': 0, 'so-so': 1, 'wrong season': 2, 'cannot judge': 3 };
    var rows = SITES.map(function (k) {
      var m = FS.meta.sites[k], r = { k: k, lat: m.lat, lon: m.lon, cav: caveatOf(k) };
      if (S.measure === 'hot') { var h = FS.heat[k][S.wheat]; r.v = h.median; r.txt = I.n(h.median) + ' (' + I.n(Math.round(h.p10)) + '–' + I.n(Math.round(h.p90)) + ')'; r.csv = h.median; }
      else if (S.measure === 'water') { var x = FS.water[k][crop][d].etc / base; r.v = x; r.txt = ratioTxt(x); r.csv = x.toFixed(2); }
      else if (S.measure === 'season') { var sv = E.seasonVerdict(k, 'wheat', S.wheat); r.v = ORD[sv.label]; r.txt = pillLabel(sv.label); r.csv = sv.label; }
      else { var tm = FS.climate[k].T2M_MAX[6]; r.v = -tm; r.txt = I.n(tm.toFixed(1)) + ' °C'; r.csv = tm; }
      return r;
    });
    // A mostly-sea cell has no trustworthy temperature: it is listed last and not ranked on temperature measures.
    rows.forEach(function (r) { r.sea = S.measure !== 'water' && FS.meta.sites[r.k].caveat_kind === 'sea'; });
    rows.sort(function (a, b) { return (a.sea - b.sea) || (a.v - b.v); });
    return rows;
  }
  var SORTNOTE = { hot: ['Fewest hot days first; cells that are mostly sea are listed last, not ranked.', 'الأقل في أيام الحر الأول؛ والخلايا اللي أغلبها بحر في الآخر من غير ترتيب.'], water: ['Lowest water need first (ratio to your place, crop {c} on its usual date).', 'الأقل في احتياج المية الأول (نسبة لمكانك، {c} في ميعاده المعتاد).'], season: ['Right season first.', 'الميعاد المناسب الأول.'], tmax: ['Hottest first.', 'الأحر الأول.'] };
  function renderCompare() {
    var rows = measureRows(), srcK = { hot: 'heat', water: 'water', season: 'season', tmax: 'climate' }[S.measure];
    var note = L(SORTNOTE[S.measure][0], SORTNOTE[S.measure][1]).replace('{c}', I.cropLow(S.crop));
    $('p-compare').innerHTML = '<p class="eyebrow">' + t('compare_eyebrow').replace('19', SITES.length).replace('١٩', I.n(SITES.length)) + '</p><div class="headrow"><h1>' + t('compare_h') + '</h1><p class="lead">' + esc(t('compare_sub')) + '</p></div>' +
      '<div class="toolbar"><label for="measure" class="dim small">' + L('Measure', 'المقياس') + '</label><select id="measure">' + MEASURES.map(function (m) { return '<option value="' + m + '"' + (m === S.measure ? ' selected' : '') + '>' + esc(t('m_' + m)) + '</option>'; }).join('') + '</select>' + src(srcK) +
      '<span class="sp"></span><button type="button" class="tbtn" id="copyCsv">' + t('copy_csv') + '</button></div>' +
      '<div class="grid2"><div class="mapbox"><div id="map"></div><p class="mapmsg" id="mapMsg" aria-live="polite"></p><p class="dim small" style="margin:4px">' + esc(t('map_caption')) + '</p></div>' +
      '<div><p class="dim small" style="margin-top:0">' + esc(note) + ' ' + esc(L('Wheat date: ', 'ميعاد القمح: ') + I.date(S.wheat)) + '.</p><div class="tablewrap"><table><thead><tr><th>' + t('rank') + '</th><th>' + t('point') + '</th><th>' + t('value') + '</th></tr></thead><tbody>' +
      rows.map(function (r, i) { return '<tr class="' + (r.k === S.site ? 'me' : '') + (r.sea ? ' dimmed' : '') + '"><td class="num">' + (r.sea ? '–' : I.n(i + 1)) + '</td><td><button type="button" class="tbtn" data-site="' + r.k + '" style="border:0;background:none;padding:0;text-align:start">' + esc(I.site(r.k)) + '</button>' + (r.cav ? '<div class="dim small">' + esc(r.cav) + '</div>' : '') + '</td><td class="num">' + r.txt + '</td></tr>'; }).join('') +
      '</tbody></table></div><textarea id="csvBox" hidden readonly style="width:100%;height:120px;margin-top:8px" aria-label="CSV"></textarea></div></div>';
    $('measure').onchange = function () { S.measure = this.value; renderCompare(); };
    Array.prototype.forEach.call(document.querySelectorAll('[data-site]'), function (b) { b.onclick = function () { setPlace(b.getAttribute('data-site')); }; });
    $('copyCsv').onclick = function () {
      var csv = 'rank,point,lat,lon,measure,value,caveat\n' + rows.map(function (r, i) { return [r.sea ? '' : i + 1, '"' + FS.meta.sites[r.k].name_en + '"', r.lat, r.lon, S.measure, r.csv, '"' + (FS.meta.sites[r.k].caveat_kind || '') + '"'].join(','); }).join('\n');
      var btn = this, fallback = function () { var bx = $('csvBox'); bx.hidden = false; bx.value = csv; bx.select(); btn.textContent = t('copy_fail'); };
      try { navigator.clipboard.writeText(csv).then(function () { btn.textContent = t('copied'); }, fallback); } catch (e) { fallback(); }
    };
    drawMap($('map'), 'mapMsg');
  }
  function drawMap(el, msgId) {
    var lon0 = 29.35, lon1 = 32.75, lat0 = 29.9, lat1 = 31.75, kx = Math.cos(31 * Math.PI / 180), W = 640, sc = W / ((lon1 - lon0) * kx), H = Math.round((lat1 - lat0) * sc);
    var P = function (p) { return ((p[0] - lon0) * kx * sc).toFixed(1) + ',' + ((lat1 - p[1]) * sc).toFixed(1); };
    var mySite = S.site, svg = '<svg viewBox="0 0 ' + W + ' ' + H + '" role="group" aria-label="' + esc(L('Map of the Nile Delta governorates', 'خريطة محافظات دلتا النيل')) + '"><rect class="sea" width="' + W + '" height="' + H + '"/>';
    FS.map.governorates.forEach(function (g, i) {
      svg += '<path class="gov' + (g.delta ? ' delta' : '') + (g.site === mySite ? ' sel' : '') + '" data-gov="' + i + '" tabindex="0" role="button" aria-label="' + esc(I.lang === 'ar' ? g.ar : g.id) + '" d="' + g.rings.map(function (r) { return 'M' + r.map(P).join('L') + 'Z'; }).join('') + '"/>';
    });
    FS.map.lakes.forEach(function (l) { svg += '<path class="lake" d="M' + l.pts.map(P).join('L') + 'Z"/>'; });
    FS.map.water.forEach(function (w) { svg += '<path class="riv" d="M' + w.pts.map(P).join('L') + '"/>'; });
    FS.map.governorates.forEach(function (g) { if (!g.delta) return; var xy = P(g.label).split(','); svg += '<text class="maplbl" x="' + xy[0] + '" y="' + xy[1] + '" text-anchor="middle">' + esc(I.lang === 'ar' ? g.ar : g.id) + '</text>'; });
    SITES.forEach(function (k) { var m = FS.meta.sites[k], xy = P([m.lon, m.lat]).split(','), named = m.kind !== 'cell'; svg += '<circle class="pt ' + (named ? 'ptn' : 'ptc') + (k === mySite ? ' me' : '') + '" cx="' + xy[0] + '" cy="' + xy[1] + '" r="' + (k === mySite ? 8 : (named ? 6 : 3.5)) + '"><title>' + esc(I.site(k)) + '</title></circle>'; });
    el.innerHTML = svg + '</svg>';
    var act = function (g) {
      var name = I.lang === 'ar' ? g.ar : g.id, r = E.resolveGov(g), msg;
      if (!r) { $(msgId).textContent = t('outside', { g: name }); return; }
      if (r.own && !r.sameCell) msg = t('uses_own', { g: name, s: I.site(r.site) });
      else if (r.sameCell) msg = t('uses_cell', { g: name, s: I.site(r.site) });
      else msg = t('uses_nearest', { g: name, s: I.site(r.site), km: I.n(r.nearestKm) });
      setPlace(r.site); var m2 = $(msgId); if (m2) m2.textContent = msg;
    };
    Array.prototype.forEach.call(el.querySelectorAll('[data-gov]'), function (p) {
      var g = FS.map.governorates[+p.getAttribute('data-gov')];
      p.addEventListener('click', function () { act(g); });
      p.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); act(g); } });
    });
  }

  // ---------- NASA data ----------
  function renderData() {
    var DS = [
      ['NASA POWER', L('Daily weather, 1990 to 2025, at ' + SITES.length + ' points (7 named, ' + (SITES.length - 7) + ' extra cells).', 'طقس يومي ١٩٩٠-٢٠٢٥ لـ ' + I.n(SITES.length) + ' نقطة (٧ بأسامي و' + I.n(SITES.length - 7) + ' خلايا زيادة).'), 'farmer', L('Every number a farmer sees: hot days for each wheat date, crop water need, the season screen.', 'كل رقم الفلاح بيشوفه: أيام الحر لكل ميعاد قمح، احتياج المية، وشاشة الموسم.'), src('heat') + src('water') + src('season')],
      ['MODIS MOD13Q1', L('Vegetation index, Delta, 2014 to 2025 (242 of 254 dates).', 'مؤشر الغطاء النباتي للدلتا ٢٠١٤-٢٠٢٥ (٢٤٢ من ٢٥٤ تاريخ).'), 'picture', L('The satellite pictures (below) and a plausibility check of the wheat calendar. No number the farmer sees.', 'صور القمر الصناعي (تحت) ومراجعة لتقويم القمح. مش بيطلع منه رقم للفلاح.'), src('readme')],
      ['MODIS MCD12Q2', L('Yearly phenology, 2015 to 2025.', 'مراحل نمو سنوية ٢٠١٥-٢٠٢٥.'), 'check', L('A second check of the wheat and summer crop calendar (table below). No number the farmer sees.', 'مراجعة لتقويم القمح والمحاصيل الصيفي (الجدول تحت). مش بيطلع منه رقم للفلاح.'), src('phen')],
      ['MODIS MOD16A3GF', L('Yearly evapotranspiration, 7 points, 2015 to 2024.', 'البخر-نتح السنوي، ٧ نقط، ٢٠١٥-٢٠٢٤.'), 'check', L('An input check: the engine’s yearly ET0 is within 1 to 8% of NASA’s own potential ET (README). No number the farmer sees.', 'مراجعة للمدخلات: البخر-نتح السنوي للمحرك في حدود ١ لـ ٨٪ من رقم ناسا (الـ README). مش بيطلع منه رقم للفلاح.'), src('readme')],
      ['GPM IMERG', L('Daily rainfall over the Delta.', 'المطر اليومي على الدلتا.'), 'context', L('Context only: 14 to 181 mm of rain a year over the whole Delta box, almost none May to September, so summer crops depend on irrigation (methodology).', 'سياق بس: من ١٤ لـ ١٨١ مم مطر في السنة على الدلتا كلها، وتقريباً مفيش من مايو لسبتمبر، فالمحاصيل الصيفي على الري (الطريقة).'), src('readme')],
      ['SRTM', L('30 m terrain.', 'تضاريس ٣٠ متر.'), 'check', L('A terrain check of the data points: the 7 named points sit on the flat floodplain (about 0 to 12 m); every cell flagged "desert edge" is 29 to 67% plateau above 100 m, the others 18% or less (README). No number the farmer sees.', 'مراجعة لتضاريس النقط: النقط السبعة على السهل (حوالي ٠ لـ ١٢ متر)؛ وكل خلية متعلم عليها "طرف صحرا" فيها ٢٩ لـ ٦٧٪ هضبة فوق ١٠٠ متر (الـ README). مش بيطلع منه رقم للفلاح.'), src('readme')]
    ];
    var ROLE = { farmer: 'role_farmer', picture: 'role_picture', check: 'role_check', context: 'role_context' };
    var named = SITES.filter(function (k) { return FS.extra.sites[k]; });
    $('p-data').innerHTML = '<p class="eyebrow">' + t('data_eyebrow') + '</p><div class="headrow"><h1>' + t('data_h') + '</h1><p class="lead">' + esc(t('data_sub')) + '</p></div>' +
      DS.map(function (d) { return '<div class="ds"><div><h3>' + d[0] + '</h3><span class="role ' + d[2] + '">' + t(ROLE[d[2]]) + '</span></div><div><div>' + esc(d[1]) + '</div><div class="dim">' + esc(d[3]) + d[4] + '</div></div></div>'; }).join('') +
      '<div class="grid2" style="margin-top:28px"><div><div class="cmpimg" id="cmpImg"><img src="img/delta_summer.jpg" alt="' + esc(L('NASA MODIS greenness of the Nile Delta in summer', 'اخضرار الدلتا في الصيف من ناسا مودس')) + '"><img class="topimg" src="img/delta_winter.jpg" alt="' + esc(L('NASA MODIS greenness of the Nile Delta in winter', 'اخضرار الدلتا في الشتا من ناسا مودس')) + '"><span class="barv"></span><span class="lbl" style="left:10px">' + L('Summer', 'صيف') + '</span><span class="lbl" style="right:10px">' + L('Winter', 'شتا') + '</span></div>' +
      '<label class="dim small" style="display:block;margin-top:8px">' + esc(t('modis_cap')) + '<input type="range" id="cmpRange" min="0" max="100" value="50"></label></div>' +
      '<div class="card"><h3>' + t('phen_h') + src('phen', 'gharbia') + '</h3><p class="dim small">' + esc(t('phen_p')) + '</p><div class="tablewrap"><table><thead><tr><th>' + t('point') + '</th><th>' + t('cycle1') + '</th><th>' + t('cycle2') + '</th></tr></thead><tbody>' +
      named.map(function (k) { var p = FS.extra.sites[k].phenology || {}, c = function (n) { var x = p[n]; return x ? t('greenup') + ' ' + I.doyDate(x.greenup) + '<br>' + t('peak') + ' ' + I.doyDate(x.peak) + '<br>' + t('dormancy') + ' ' + I.doyDate(x.dormancy) : t('not_available'); }; return '<tr><td>' + esc(I.site(k)) + (FS.extra.sites[k].sea_edge ? '<div class="dim small">' + esc(t('caveat_sea')) + '</div>' : '') + '</td><td class="small">' + c('1') + '</td><td class="small">' + c('2') + '</td></tr>'; }).join('') +
      '</tbody></table></div></div></div>' +
      '<h2 style="margin-top:34px">' + t('other_tables') + '</h2><ul class="tight dim">' +
      [L('FAO Irrigation and Drainage Paper 56: crop coefficients and stage lengths (water engine).', 'ورقة الفاو ٥٦: معاملات المحاصيل وأطوال المراحل (محرك المية).'), L('FAO Irrigation and Drainage Paper 29: salt tolerance (salt engine).', 'ورقة الفاو ٢٩: تحمّل الملوحة (محرك الملح).'), L('FAOSTAT: Egypt yields 2020 to 2024 and producer prices 2022 (income).', 'فاوستات: إنتاجية مصر ٢٠٢٠-٢٠٢٤ وأسعار ٢٠٢٢ (الدخل).'), L('FAO EcoCrop: crop temperature ranges (season screen; generic and coarse).', 'إيكوكروب: نطاقات حرارة المحاصيل (شاشة الموسم؛ عامة وتقريبية).'), L('ESA WorldCover 2021 (not NASA): confirms the points are farmland.', 'ESA WorldCover (مش ناسا): بيأكد إن النقط أرض زراعية.'), L('CAPMAS via HDX (governorates) and Natural Earth (rivers, lakes).', 'CAPMAS عن طريق HDX (المحافظات) وNatural Earth (الأنهار والبحيرات).')].map(function (s) { return '<li>' + esc(s) + '</li>'; }).join('') + '</ul>';
    var box = $('cmpImg'), set = function (p) { p = Math.max(0, Math.min(100, p)); box.querySelector('.topimg').style.clipPath = 'inset(0 0 0 ' + p + '%)'; box.querySelector('.barv').style.left = p + '%'; $('cmpRange').value = p; };
    var drag = false, mv = function (e) { if (!drag) return; var r = box.getBoundingClientRect(); set((e.clientX - r.left) / r.width * 100); };
    box.addEventListener('pointerdown', function (e) { drag = true; try { box.setPointerCapture(e.pointerId); } catch (x) { } mv(e); });
    box.addEventListener('pointermove', mv); box.addEventListener('pointerup', function () { drag = false; });
    $('cmpRange').oninput = function () { set(+this.value); };
  }

  // ---------- Ask (page) ----------
  function renderAsk() {
    $('p-ask').innerHTML = '<p class="eyebrow">' + L('OFFLINE · ANSWERS FROM OUR TABLES', 'من غير نت · بالقواعد · من جداولنا') + '</p><div class="headrow"><h1>' + t('ask_h') + '</h1><p class="lead">' + esc(t('ask_sub')) + '</p></div>' +
      '<div class="eyad" style="margin-bottom:14px">' + eyadAv() + '<p class="dim">' + esc(L('Ask about one field at a time. Eyad uses your place and wheat date from the top bar.', 'اسأل عن أرض واحدة كل مرة. إياد بيستخدم مكانك وميعاد القمح من الشريط اللي فوق.')) + '</p></div>' +
      '<div class="chat" id="chatPage" aria-live="polite"></div><div class="qchips" id="qchipsPage" style="padding:10px 0"></div>' +
      '<form class="askform" id="askFormPage" style="padding:0"><label class="sr" for="askInPage">' + esc(L('Question', 'السؤال')) + '</label><input id="askInPage" type="text" autocomplete="off" placeholder="' + esc(t('ask_ph')) + '"><button class="btn p" type="submit">' + t('send') + '</button></form>';
    if (FS.Ask) FS.Ask.mount('Page');
  }

  // ---------- Methods ----------
  function renderMethods() {
    var ENG = [
      [L('Wheat calendar', 'تقويم القمح'), L('How much heat does wheat meet during grain filling if sown on date X, compared with other dates?', 'القمح المزروع في ميعاد معين بيقابل حر قد إيه وقت امتلاء الحبة، مقارنة بالمواعيد التانية؟'), L('Thermal time, shown only as a comparison of sowing dates against 15 November', 'الوقت الحراري، ومعروض بس كمقارنة بـ ١٥ نوفمبر'), L('NASA POWER daily temperature, 1990 to 2025', 'حرارة ناسا باور اليومية ١٩٩٠-٢٠٢٥')],
      [L('Water', 'المية'), L('How much water does the summer crop need, compared with my rotation?', 'المحصول الصيفي محتاج مية قد إيه مقارنة بدورتي؟'), L('FAO-56 reference evapotranspiration times crop coefficients; shown as ratios, not millimetres', 'البخر-نتح المرجعي (فاو-٥٦) في معاملات المحصول؛ كنسب مش ملليمتر'), L('NASA POWER weather; crop tables from FAO-56', 'طقس ناسا باور؛ جداول المحاصيل من فاو-٥٦')],
      [L('Salt', 'الملح'), L('Can my soil take this crop?', 'أرضي تستحمل المحصول ده؟'), L('FAO paper 29 salt tolerance table', 'جدول تحمّل الملوحة من ورقة الفاو ٢٩'), L('Farmer input (soil test or signs). No NASA product measures soil salinity', 'كلام الفلاح (تحليل أو علامات). مفيش منتج من ناسا بيقيس ملوحة التربة')],
      [L('Season screen', 'شاشة الموسم'), L('Is this the right season for this crop here?', 'ده الميعاد المناسب للمحصول ده هنا؟'), L('Temperature screen from FAO EcoCrop against NASA POWER; crops it cannot judge are labelled so', 'شاشة حرارة من إيكوكروب على طقس ناسا باور؛ والمحاصيل اللي مايقدرش يحكم عليها متعلّمة'), 'NASA POWER, FAO EcoCrop'],
      [L('Income', 'الدخل'), L('What might this crop earn per feddan?', 'المحصول ده ممكن يجيب كام للفدان؟'), L('FAOSTAT Egypt yield and price, lowered by the FAO-29 salt factor', 'إنتاجية وسعر مصر من فاوستات، وبيقل بمعامل الملح'), 'FAOSTAT']];
    var LIM = [
      L('The 32 °C hot-day threshold, the 30% grain-filling share, the base temperature and the maturity target in late April have no full text source (confidence: low).', 'حد الـ ٣٢ درجة ونسبة ٣٠٪ لامتلاء الحبة ودرجة الأساس وميعاد النضج في آخر أبريل ملهمش مصدر مقري بالكامل (ثقة قليلة).'),
      L('Thermal time only: no vernalisation or photoperiod; the stage most sensitive to heat, anthesis, is not counted separately.', 'الوقت الحراري بس: من غير الارتباع ولا طول النهار؛ ومرحلة التزهير مش محسوبة لوحدها.'),
      L('Reanalysis temperature at about 50 km, not yet checked against Delta weather stations.', 'حرارة محسوبة لمربعات حوالي ٥٠ كم، ولسه متراجعتش على محطات الدلتا.'),
      L('Damietta’s cell is mostly sea (zero hot days at every date), so its heat numbers are unreliable. Menoufia and Sharqia share one cell.', 'خلية دمياط أغلبها بحر (صفر أيام حر في كل المواعيد): مش أمان، بس مش موثوق. المنوفية والشرقية في خلية واحدة.'),
      L('Rice water need is a floor: ponding, puddling, percolation and seepage are excluded. No canal supply, rain, capillary rise or irrigation losses.', 'احتياج الرز أقل من الحقيقة: الغمر والتسريب مش محسوبين. ومفيش حساب للترعة ولا المطر ولا الفاقد.'),
      L('Salt signs map to an assumed ECe of 2, 6 and 12 dS/m: the team’s assumption, not a measurement.', 'العلامات بتتحول لملوحة مفترضة ٢ و٦ و١٢: افتراض من الفريق، مش قياس.'),
      L('The season screen uses FAO EcoCrop ranges, which are generic and coarse: a temperature screen, never a yield model.', 'شاشة الموسم بتستخدم نطاقات إيكوكروب العامة: شاشة حرارة، مش نموذج محصول.'),
      L('Income uses FAOSTAT averages across Egypt (yield 2020 to 2024, price at the farm gate 2022), gross before costs.', 'الدخل من متوسطات مصر في فاوستات (إنتاجية ٢٠٢٠-٢٠٢٤ وسعر ٢٠٢٢)، إجمالي قبل المصاريف.')];
    var NM = { 'nitrogen fixation and soil organic matter': ['Nitrogen fixation and soil organic matter', 'تثبيت النيتروجين والمادة العضوية'], 'pests and disease': ['Pests and disease', 'الآفات والأمراض'], 'market prices and income': ['Market prices (income uses national averages only)', 'أسعار السوق (الدخل من متوسطات مصر بس)'], 'labour and machinery': ['Labour and machinery', 'العمالة والمعدات'], 'rice ponding and percolation': ['Rice ponding and percolation', 'غمر الرز والتسريب'], "the farmer's canal supply (ask the farmer)": ['The farmer’s canal supply (ask the farmer)', 'مية الترعة عند الفلاح (اسأله)'] };
    $('p-methods').innerHTML = '<p class="eyebrow">' + t('methods_eyebrow') + '</p><h1>' + t('methods_h') + '</h1><p class="lead">' + esc(L('Five engines, each a published method on NASA POWER weather and FAO tables. Code chooses the advice; an AI may only reword it in the app.', 'خمس محركات، كل واحد طريقة منشورة على طقس ناسا باور وجداول الفاو. الكود بيختار النصيحة؛ والذكاء الاصطناعي ممكن بس يعيد صياغتها في التطبيق.')) + '</p>' +
      '<h2>' + t('engines_h') + '</h2><div class="tablewrap"><table><thead><tr><th>' + L('Engine', 'المحرك') + '</th><th>' + L('Question it answers', 'بيجاوب على') + '</th><th>' + L('Method', 'الطريقة') + '</th><th>' + L('Data', 'البيانات') + '</th></tr></thead><tbody>' + ENG.map(function (r) { return '<tr>' + r.map(function (c) { return '<td>' + esc(c) + '</td>'; }).join('') + '</tr>'; }).join('') + '</tbody></table></div>' +
      '<div class="grid2" style="margin-top:28px"><div class="card"><h2>' + t('not_claim_h') + '</h2><p>' + esc(L('No yield forecast, no yield loss in percent, no accuracy at field level and no validation against weather stations. Weather is a model product at about 50 km; absolute hot-day counts are approximate, so the app compares dates. The salt percentage is a crop-tolerance figure from the FAO table, not a forecast of the farmer’s crop. Several wheat parameters have no full text source.', 'مفيش توقع للمحصول، ولا نسبة خسارة، ولا دقة متراجعة على الغيط أو المحطات. الطقس محسوب لمربعات حوالي ٥٠ كم؛ فبنقارن المواعيد. نسبة الملح رقم تحمّل من جدول الفاو، مش توقع لمحصولك. وفي قيم للقمح ملهاش مصدر مقري بالكامل.')) + src('readme') + '</p></div>' +
      '<div class="card"><h2>' + t('not_model_h') + '</h2><ul class="tight">' + FS.meta.not_modelled.map(function (x) { return '<li>' + esc(NM[x] ? L(NM[x][0], NM[x][1]) : x) + '</li>'; }).join('') + '</ul><p class="dim small">' + esc(L('The brief mentions soil health: the tool models one part of it, salinity (FAO-29), and says plainly that nitrogen fixation and cover crops are not modelled.', 'التحدي بيذكر صحة التربة: الأداة بتحسب جزء منها بس، الملوحة، وبتقول بوضوح إن تثبيت النيتروجين والمحاصيل الغطائية مش محسوبة.')) + '</p></div></div>' +
      '<h2 style="margin-top:28px">' + t('limits_h') + '</h2><ul class="tight">' + LIM.map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('') + '</ul>' +
      '<figure class="card" style="margin:24px 0 0"><img src="img/workflow.svg" alt="' + esc(L('Three steps: ask the farmer; compute with five engines on NASA POWER weather and FAO tables; advise in Egyptian Arabic, where code picks the advice and an AI may only reword it.', 'تلات خطوات: نسأل الفلاح، نحسب بخمس محركات، وننصح بالمصري.')) + '" style="width:100%;height:auto"><figcaption class="dim small">' + esc(L('Diagram from the team’s README (assets/readme/workflow.svg).', 'رسم من الـ README بتاع الفريق.')) + '</figcaption></figure>';
  }

  // ---------- Judges ----------
  function renderJudges() {
    var C = [
      [L('Impact', 'التأثير'), L('Built on published research from the Nile Delta on water scarcity, rising salinity and the wheat calendar. It covers the whole Delta: 10 governorates and ' + SITES.length + ' NASA data points, with a voice assistant for farmers who cannot read.', 'مبني على أبحاث منشورة من الدلتا عن شح المية وزيادة الملوحة وميعاد القمح. بيغطي الدلتا كلها: ١٠ محافظات و' + I.n(SITES.length) + ' نقطة بيانات من ناسا، ومساعد صوتي للفلاح اللي مبيقراش.'), [['#learn', t('nav_learn')]]],
      [L('Creativity', 'الإبداع'), L('A farmer’s own goal question, advice chosen by code with an AI only rewording it, an Egyptian voice, and a field scene you can change and watch.', 'سؤال هدف الفلاح نفسه، ونصيحة الكود بيختارها والذكاء الاصطناعي بس بيعيد صياغتها، وصوت مصري، ومشهد حقل تغيّر فيه وتشوف النتيجة.'), [['#learn', t('nav_learn')], ['#lab', t('nav_lab')]]],
      [L('Validity', 'الصحة'), L('Published methods (FAO-56, FAO-29, thermal time) on NASA POWER weather. Every number shows its source, and the checks below ran against NASA and FAO data.', 'طرق منشورة (FAO-56 وFAO-29 والزمن الحراري) على طقس ناسا باور. كل رقم عليه مصدره، والفحوصات تحت اتعملت قصاد بيانات ناسا وفاو.'), []],
      [L('Relevance', 'الارتباط'), L('Answers the rotation question: your rotation against two alternatives, with evidence. NASA POWER drives every number the farmer sees.', 'بيجاوب سؤال الدورة: دورتك قصاد بديلين، بالدليل. ناسا باور ورا كل رقم الفلاح بيشوفه.'), [['#lab', t('nav_lab')]]],
      [L('Presentation', 'العرض'), L('The story, the Field lab and the app screens in one place. Works offline, on a phone, in English and Arabic.', 'الحكاية ومعمل الأرض وشاشات التطبيق في مكان واحد. شغال من غير نت، على الموبايل، بالعربي والإنجليزي.'), [['#learn', t('nav_learn')], ['#lab', t('nav_lab')]]]];
    var VAL = [
      ['Engine yearly reference evapotranspiration against NASA MOD16A3GF potential ET, 7 points', 'within 1 to 8%; result files in docs/checks/'],
      ['Are the data points farmland (ESA WorldCover 2021)?', 'cropland 73 to 91% within 2.5 km of six points'],
      ['Do the weather cells match the ground? (NASA SRTM terrain)', 'named points on the floodplain at 0 to 12 m; the "desert edge" cells are confirmed by measured plateau share (29 to 67%, against 18% or less for the others)'],
      ['Python and Dart give the same answers', '18 golden cases and 18 advice cases match'],
      ['Automated tests', 'hundreds of Python and Flutter tests, run on every push']];
    var DS6 = [['NASA POWER', 'role_farmer', 'farmer'], ['MODIS MOD13Q1', 'role_picture', 'picture'], ['MODIS MCD12Q2', 'role_check', 'check'], ['MODIS MOD16A3GF', 'role_check', 'check'], ['GPM IMERG', 'role_context', 'context'], ['SRTM', 'role_check', 'check']];
    $('p-judges').innerHTML = '<p class="eyebrow">' + t('judges_eyebrow') + '</p><h1>' + t('judges_h') + '</h1><p class="lead">' + esc(t('judges_sub')) + '</p>' +
      '<div class="grid3">' + C.map(function (c) { return '<div class="card"><h3>' + esc(c[0]) + '</h3><p class="dim small">' + esc(c[1]) + '</p><div class="chips">' + c[2].map(function (l) { return '<a class="chip" href="' + l[0] + '" style="text-decoration:none">' + esc(l[1]) + ' →</a>'; }).join('') + '</div></div>'; }).join('') + '</div>' +
      '<h2 style="margin-top:32px">' + t('datasets_h') + '</h2><div class="chips">' + DS6.map(function (d) { return '<span class="role ' + d[2] + '" style="font-size:12px;padding:5px 12px">' + d[0] + ' · ' + t(d[1]) + '</span>'; }).join('') + '</div>' +
      '<h2 id="valid" style="margin-top:32px">' + t('valid_h') + src('readme') + '</h2><div class="tablewrap"><table dir="ltr" lang="en"><thead><tr><th>Check</th><th>Result</th></tr></thead><tbody>' + VAL.map(function (v) { return '<tr><td>' + esc(v[0]) + '</td><td>' + esc(v[1]) + '</td></tr>'; }).join('') + '</tbody></table></div>';
  }

  // ---------- header controls ----------
  $('viewSel').onchange = function () { S.firstVisit = false; setView(this.value); var p = VIEWS[this.value][0]; if (p && current !== p) location.hash = p; else render(); };
  $('langBtn').onclick = function () { I.lang = S.lang = I.lang === 'ar' ? 'en' : 'ar'; save(); render(); if (FS.Ask) FS.Ask.relabel(); };
  $('themeBtn').onclick = function () { var cur = document.documentElement.getAttribute('data-theme') || (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'); S.theme = cur === 'light' ? 'dark' : 'light'; document.documentElement.setAttribute('data-theme', S.theme); save(); };
  $('menuBtn').onclick = function () { var n = $('mainNav'), o = !n.classList.contains('open'); n.classList.toggle('open', o); this.setAttribute('aria-expanded', o); };

  I.lang = S.lang === 'ar' ? 'ar' : 'en';
  if (S.theme) document.documentElement.setAttribute('data-theme', S.theme);
  setView(S.view);
  render();
  FS.render = render;
})();
