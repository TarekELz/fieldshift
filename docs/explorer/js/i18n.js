// UI text in English and Egyptian Arabic. The Arabic UI strings here are a DRAFT that needs a native speaker's review.
// Crop names come from data/crops.json and advice from data/blueprints.json (both written by the team's pipeline).
(function () {
  var FS = window.FS;
  var I = FS.I = { lang: 'en' };
  var AR_DIG = '٠١٢٣٤٥٦٧٨٩';
  I.toAr = function (s) { return String(s).replace(/[0-9]/g, function (d) { return AR_DIG[d]; }).replace(/\./g, '٫'); };
  I.n = function (v) { return I.lang === 'ar' ? I.toAr(v) : String(v); };
  I.money = function (v) { var s = String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ','); return I.lang === 'ar' ? I.toAr(s).replace(/,/g, '٬') + ' جنيه' : s + ' EGP'; };
  var MON_EN = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var MON_AR = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  I.MON_AR = MON_AR; I.MON_EN = MON_EN;
  I.date = function (mmdd) { var p = mmdd.split('-'); return I.lang === 'ar' ? I.toAr(+p[1]) + ' ' + MON_AR[p[0] - 1] : (+p[1]) + ' ' + MON_EN[p[0] - 1]; };
  I.doyDate = function (d) { var t = new Date(Date.UTC(2001, 0, 1) + (((d % 365) + 365) % 365) * 864e5); var mm = t.getUTCMonth() + 1, dd = t.getUTCDate(); return I.date((mm < 10 ? '0' : '') + mm + '-' + (dd < 10 ? '0' : '') + dd); };
  var EG_DAYS = { 1: 'يوم', 2: 'يومين', 3: 'تلات أيام', 4: 'أربع أيام', 5: 'خمس أيام', 6: 'ست أيام', 7: 'سبع أيام', 8: 'تمان أيام', 9: 'تسع أيام', 10: 'عشر أيام', 11: 'حداشر يوم', 12: 'اتناشر يوم', 13: 'تلاتاشر يوم', 14: 'أربعتاشر يوم', 15: 'خمستاشر يوم', 16: 'ستاشر يوم', 17: 'سبعتاشر يوم', 18: 'تمنتاشر يوم', 19: 'تسعتاشر يوم', 20: 'عشرين يوم' };
  I.days = function (n) { return I.lang === 'ar' ? (EG_DAYS[n] || I.toAr(n) + ' يوم') : (n === 1 ? '1 day' : n + ' days'); };
  var SITE_AR = { kafr_el_sheikh: 'كفر الشيخ', damietta: 'دمياط', beheira: 'البحيرة', gharbia: 'الغربية (طنطا)', menoufia: 'المنوفية', sharqia: 'الشرقية', dakahlia: 'الدقهلية (شرق)' };
  var SITE_EN = { kafr_el_sheikh: 'Kafr El-Sheikh', damietta: 'Damietta', beheira: 'Beheira', gharbia: 'Gharbia (Tanta)', menoufia: 'Menoufia', sharqia: 'Sharqia', dakahlia: 'Dakahlia (east)' };
  I.site = function (k) {
    var s = FS.meta.sites[k]; if (!s) return k;
    if (I.lang === 'ar') return SITE_AR[k] || s.name_ar || s.name_en;
    return SITE_EN[k] || s.name_en;
  };
  I.crop = function (k) { var c = FS.crops.crops[k]; return c ? (I.lang === 'ar' ? c.ar : c.en) : k; };
  I.cropLow = function (k) { var s = I.crop(k); return I.lang === 'ar' ? s : s.toLowerCase(); };

  // [English, Arabic draft]
  var T = {
    honesty: ['Planning estimates from NASA data, built to support farmers and local experts.', 'تقديرات للتخطيط من بيانات ناسا، معمولة لدعم الفلاح والخبراء المحليين.'],
    brand: ['Field Shift', 'فيلد شيفت'], badge: ['NASA SPACE APPS 2026', 'ناسا سبيس آبس ٢٠٢٦'],
    nav_learn: ['The story', 'الحكاية'], nav_lab: ['Field lab', 'معمل الأرض'], nav_crops: ['Crops', 'المحاصيل'], nav_compare: ['Compare', 'قارن'], nav_data: ['NASA data', 'بيانات ناسا'],
    nav_ask: ['Ask Eyad', 'اسأل إياد'], nav_methods: ['Methods', 'الطريقة'], nav_judges: ['Evidence', 'الأدلة'], nav_views: ['Who are you?', 'إنت مين؟'],
    menu: ['Menu', 'القائمة'], view: ['VIEW', 'العرض'], lang_btn: ['عربي', 'English'], theme_btn: ['Theme', 'الألوان'],
    pill_place: ['Place', 'المكان'], pill_wheat: ['Wheat sown on', 'ميعاد زراعة القمح'], pill_title: ['Your place and wheat date: every page uses them', 'مكانك وميعاد القمح: كل الصفحات بتستخدمهم'], done: ['Done', 'تمام'],
    wheat_short: ['wheat', 'قمح'],
    v_everyone: ['Everyone (all pages)', 'الكل (كل الصفحات)'], v_farmer: ['Farmer', 'فلاح'], v_officer: ['Extension officer', 'مرشد زراعي'], v_researcher: ['Researcher', 'باحث'], v_judge: ['Judge', 'حَكَم'],
    views_eyebrow: ['CHOOSE A VIEW', 'اختار طريقتك'], views_h: ['Who are you?', 'إنت مين؟'],
    views_sub: ['Each view is a short path through the site. Every page stays open to everyone.', 'كل اختيار بيمشيك في طريق قصير. كل الصفحات مفتوحة للكل.'],
    vd_farmer: ['Abu Ahmed grows rice and wheat in Gharbia. Big text, one decision at a time.', 'أبو أحمد بيزرع رز وقمح في الغربية. كلام كبير، وقرار واحد كل مرة.'],
    vd_officer: ['Advise many farmers: test a field, compare places and crops.', 'بتنصح فلاحين كتير: جرب أرض، وقارن الأماكن والمحاصيل.'],
    vd_researcher: ['Check the method, the NASA data and the limits first.', 'شوف الطريقة وبيانات ناسا والحدود الأول.'],
    vd_judge: ['The five criteria, the evidence and the limits, in three stops.', 'المعايير الخمسة والدليل والحدود، في تلات محطات.'],
    vd_everyone: ['No path: show everything.', 'من غير طريق: اعرض كل حاجة.'],
    start: ['Start', 'ابدأ'], then: ['then', 'وبعدين'], persona_pick: ['Use this view', 'استخدم ده'],
    learn_eyebrow: ['NILE DELTA · ONE SEASON, THREE PRESSURES', 'دلتا النيل · موسم واحد وتلات ضغوط'],
    learn_h: ['What decides a Delta farmer’s season?', 'إيه اللي بيحدد موسم فلاح الدلتا؟'],
    learn_sub: ['Tap a glowing point in the field. Each one plays out in four steps: cause, effect, what NASA data shows, and what Eyad advises.', 'دوس على نقطة منورة في الأرض. كل واحدة بتتحكي في أربع خطوات: السبب، والنتيجة، وبيانات ناسا بتقول إيه، وإياد بينصح بإيه.'],
    illus: ['Illustration: drawn by AI', 'رسم: مرسوم بالذكاء الاصطناعي'], illus_crops: ['Illustrations: drawn by AI', 'رسوم: مرسومة بالذكاء الاصطناعي'],
    hs_canal: ['Canal turn', 'دور المية'], hs_rice: ['Rice stubble', 'بقايا الرز'], hs_wheat: ['Wheat field', 'غيط القمح'], hs_salt: ['White salt patch', 'بقعة ملح بيضا'], hs_sat: ['NASA satellite', 'قمر ناسا'],
    step_cause: ['Cause', 'السبب'], step_effect: ['Effect', 'النتيجة'], step_nasa: ['What NASA data shows', 'بيانات ناسا بتقول إيه'], step_eyad: ['What Eyad advises', 'إياد بينصح بإيه'],
    replay: ['Replay', 'من الأول'], next: ['Next', 'اللي بعده'],
    hud_place: ['Place', 'المكان'], hud_wheat: ['Wheat sown', 'القمح اتزرع'], hud_hot: ['Hot days in grain filling', 'أيام حر وقت امتلاء الحبة'], hud_salt: ['Salt sign', 'علامة الملح'], hud_summer: ['Summer crop', 'المحصول الصيفي'],
    stepper_1: ['Why the wheat date matters', 'ليه ميعاد القمح مهم'], stepper_2: ['Water', 'المية'], stepper_3: ['Salt', 'الملح'], stepper_4: ['What Eyad advises', 'إياد بينصح بإيه'], stepper_try: ['Try it yourself', 'جرب بنفسك'], skip_lab: ['Skip to the lab', 'روح للمعمل على طول'],
    s1_h: ['Early wheat vs late wheat', 'قمح بدري وقمح متأخر'],
    s1_p: ['Wheat sown late fills its grain in spring heat. Published field trials in the Delta found that wheat sown 7 to 13 January lost about 40% of its yield against mid November. Here is that effect in our own numbers for your place.', 'القمح المتأخر بيملي حبته في حر الربيع. تجارب حقلية منشورة في الدلتا لقت إن القمح المزروع من ٧ لـ ١٣ يناير خسر حوالي ٤٠٪ من المحصول مقارنة بنص نوفمبر. ده نفس التأثير بأرقامنا لمكانك.'],
    early: ['Early: sown 1 Nov', 'بدري: ١ نوفمبر'], late: ['Your date', 'ميعادك'], hot_days: ['hot days (median)', 'يوم حر (الوسيط)'], range_lbl: ['in 8 of 10 seasons', 'في ٨ من ١٠ مواسم'],
    vs15: ['vs sowing on 15 Nov', 'عن زراعة ١٥ نوفمبر'], seasons35: ['Each bar is one season, 1990 to 2025', 'كل عمود موسم، من ١٩٩٠ لـ ٢٠٢٥'], hot_def: ['A hot day: maximum 32 °C or more while the grain fills.', 'يوم الحر: العظمى ٣٢ درجة أو أكتر وقت امتلاء الحبة.'],
    s2_h: ['Water: the summer crop decides most of it', 'المية: المحصول الصيفي بيحدد أغلبها'],
    s2_p: ['Irrigation water is short and unreliable, worst at the tail ends of canals: published research from the western Delta found that 58% of farmers at the tail end said growing rice had become very difficult. Each bar is a summer crop’s seasonal water need at your place, against rice.', 'مية الري قليلة ومش مضمونة، وأسوأ في آخر الترعة: في دراسة في غرب الدلتا، ٥٨٪ من فلاحين آخر الترعة قالوا إن زراعة الرز بقت صعبة جداً. كل عمود هو احتياج المية لمحصول صيفي في مكانك، مقارنة بالرز.'],
    rice_floor: ['Rice is a floor: ponding and seepage are not counted, so rice really needs more.', 'الرز رقمه أقل من الحقيقة: الغمر والتسريب مش محسوبين.'],
    s3_h: ['Salt: which crops your soil can take', 'الملح: أرضك تستحمل أنهي محاصيل'],
    s3_p: ['Published surveys of Delta farmers found that 57.2% report rising soil salinity. No NASA product measures soil salt, so the farmer says what he sees. Choose a sign:', 'استطلاعات منشورة لفلاحين الدلتا لقت إن ٥٧٫٢٪ منهم بيقولوا إن ملوحة الأرض بتزيد. مفيش منتج من ناسا بيقيس ملح التربة، فالفلاح بيقول اللي شايفه. اختار علامة:'],
    tol_pct: ['relative yield the soil allows (FAO-29)', 'نسبة المحصول اللي الأرض تسمح بيها (فاو-٢٩)'], beyond: ['beyond the table: not advised', 'برا الجدول: مش مناسب'],
    sign_unknown: ['I don’t know', 'مش عارف'], sign_none: ['No signs', 'مفيش علامات'], sign_patches: ['White patches', 'بقع ملح'], sign_crust: ['White crust', 'قشرة بيضا'],
    sign_note: ['Signs map to an assumed soil salinity (none 2, patches 6, crust 12 dS/m). That is the team’s assumption, not a measurement: get a soil test.', 'العلامات بتتحول لملوحة مفترضة (مفيش ٢، بقع ٦، قشرة ١٢). ده افتراض من الفريق مش قياس: اعمل تحليل تربة.'],
    s4_h: ['What Eyad advises for this field', 'إياد بينصح بإيه للأرض دي'],
    s4_p: ['Code picks the advice from blueprints the team wrote, using the facts below. In the app an AI may only reword it, behind a guard that keeps every number.', 'الكود بيختار النصيحة من قوالب كتبها الفريق، من الحقائق اللي تحت. في التطبيق الذكاء الاصطناعي ممكن بس يعيد صياغتها، وكل رقم بيفضل زي ما هو.'],
    facts: ['Facts from the engines', 'حقائق من المحركات'], chosen: ['Blueprint chosen by code', 'القالب اللي الكود اختاره'], speak: ['Listen', 'اسمع'],
    try_h: ['Now try your own field', 'جرب أرضك إنت'], go_lab: ['Open the Field lab', 'افتح معمل الأرض'],
    see_app: ['See the app', 'شوف التطبيق'], see_app_sub: ['Screens from the Flutter Android app (web preview of the same code).', 'شاشات من تطبيق أندرويد (نفس الكود على الويب).'],
    lab_eyebrow: ['FIELD LAB · YOUR ROTATION AGAINST TWO OTHERS', 'معمل الأرض · دورتك قصاد اتنين تانيين'],
    lab_h: ['Change one thing, see what moves.', 'غيّر حاجة واحدة وشوف إيه اللي بيتغير.'],
    lab_sub: ['Your summer crop then wheat, against the other two summer crops at their usual dates with wheat on 15 November.', 'محصولك الصيفي وبعده قمح، قصاد المحصولين التانيين في مواعيدهم المعتادة والقمح ١٥ نوفمبر.'],
    estimate_badge: ['Estimate from NASA POWER + FAO tables', 'تقدير من ناسا باور وجداول الفاو'],
    c_place: ['Place', 'المكان'], c_crop: ['Summer crop', 'المحصول الصيفي'], c_sow: ['Summer crop sown on', 'ميعاد زراعته'], c_wheat: ['Wheat sown on', 'ميعاد القمح'], c_salt: ['Salt sign', 'علامة الملح'],
    yours: ['Yours', 'دورتك'], option: ['Option', 'بديل'], then_wheat: ['then wheat', 'وبعده قمح'],
    lvl0: ['Fine', 'تمام'], lvl1: ['A small problem', 'مشكلة بسيطة'], lvl2: ['A big problem', 'مشكلة كبيرة'],
    why_gap_neg: ['Wheat would be sown before {crop} finishes', 'القمح هيتزرع قبل ما {crop} يخلص'], why_salt_high: ['The salt level is too high for {crop}', 'نسبة الملوحة عالية على {crop}'],
    why_gap_tight: ['Only {days} before wheat', 'فاضل {days} بس قبل القمح'], why_wheat_late: ['Wheat is late and meets about {days} more heat', 'القمح متأخر، وهيقابل حر أكتر بحوالي {days}'],
    why_salt_reduced: ['The salt will reduce it a little', 'الملوحة هتقلل شوية'], why_none: ['No problem found', 'مفيش مشكلة ظاهرة'],
    water_vs: ['Water vs yours', 'المية مقارنة بدورتك'], hot_wheat: ['Hot days, wheat', 'أيام حر للقمح'], salt_lbl: ['Salt', 'الملح'], harvest_lbl: ['Harvest about', 'الحصاد حوالي'], gap_lbl: ['Days to wheat', 'أيام لحد القمح'],
    season_lbl: ['Season (temperature)', 'الموسم (الحرارة)'], salt_unknown: ['Not given', 'مش معروف'],
    l_right: ['Right season', 'ميعاد مناسب'], l_so: ['So-so', 'مقبول'], l_wrong: ['Wrong season', 'ميعاد مش مناسب'], l_na: ['Cannot judge', 'مقدرش أحكم'],
    st_fine: ['Suitable', 'مناسب'], st_reduced: ['Reduced', 'أقل'], st_not: ['Not suitable', 'مش مناسب'],
    wys_h: ['What you are seeing', 'إنت شايف إيه'],
    wys_p: ['Water: FAO-56 crop water need from NASA POWER weather, shown as a ratio to your crop (not millimetres). Heat: hot days during wheat grain filling over 35 seasons, compared between sowing dates. Salt: FAO paper 29 tolerance at the soil salinity your sign stands for. Verdict: the app’s own rule. None of this is a yield forecast.', 'المية: احتياج المحصول بطريقة الفاو-٥٦ من طقس ناسا باور، كنسبة لمحصولك (مش ملليمتر). الحر: أيام الحر وقت امتلاء حبة القمح في ٣٥ موسم، للمقارنة بين المواعيد. الملح: تحمّل المحصول من جدول الفاو-٢٩ عند الملوحة اللي العلامة بتمثلها. الحكم: قاعدة التطبيق نفسها. مفيش هنا أي توقع للمحصول.'],
    caveat_sea: ['Caution: this NASA cell is mostly sea; do not rely on the heat numbers here.', 'تنبيه: خلية ناسا دي أغلبها بحر؛ متعتمدش على أرقام الحر هنا.'],
    caveat_desert: ['Note: this NASA cell is mostly desert plateau; treat the numbers as rough.', 'ملحوظة: خلية ناسا دي أغلبها هضبة صحرا؛ اعتبر الأرقام تقريبية.'],
    caveat_shared: ['Note: Menoufia and Sharqia share one NASA weather cell, so their heat results are the same.', 'ملحوظة: المنوفية والشرقية في نفس خلية طقس ناسا، فنتايج الحر هتطلع زي بعض.'],
    crops_eyebrow: ['14 CROPS · FAOSTAT EGYPT AVERAGES · FAO-29 SALT', '١٤ محصول · متوسطات مصر من فاوستات · ملح فاو-٢٩'],
    crops_h: ['14 crops, ordered by what a feddan might earn here.', '١٤ محصول، مترتبين باللي الفدان ممكن يجيبه.'],
    crops_sub: ['Gross income per feddan from averages across Egypt, before costs, lowered by your salt sign. An estimate, not a profit and not a forecast for your field.', 'الدخل الإجمالي للفدان من متوسطات مصر، قبل المصاريف، وبيقل حسب علامة الملح. تقدير، مش ربح ومش توقع لأرضك.'],
    search: ['Search crops', 'دوّر على محصول'], f_all: ['All', 'الكل'], f_summer: ['Summer', 'صيفي'], f_winter: ['Winter', 'شتوي'], f_any: ['Vegetables', 'خضار'], f_orchard: ['Trees', 'أشجار'],
    gallery: ['Gallery', 'كروت'], table: ['Table', 'جدول'], shown: ['shown', 'معروض'], dimmed_note: ['DIMMED = THE SEASON SCREEN CANNOT JUDGE IT', 'الباهت = شاشة الموسم مقدرتش تحكم عليه'],
    per_feddan: ['per feddan, gross', 'للفدان، إجمالي'], best_sow: ['Best sowing (temperature)', 'أحسن ميعاد (الحرارة)'], add_cmp: ['Add to compare', 'ضيف للمقارنة'], remove_cmp: ['Remove', 'شيل'],
    cmp_tray: ['Compare crops', 'قارن المحاصيل'], cmp_empty: ['Add up to three crops to compare them side by side.', 'ضيف لحد تلات محاصيل وقارنهم جنب بعض.'], salt_effect: ['Salt effect', 'تأثير الملح'], group: ['Group', 'النوع'],
    g_summer: ['Summer', 'صيفي'], g_winter: ['Winter', 'شتوي'], g_any: ['Several seasons', 'أكتر من موسم'], g_orchard: ['Tree or vine (per year)', 'شجر أو كرم (في السنة)'],
    compare_eyebrow: ['19 NASA POWER POINTS · ONE MEASURE AT A TIME', '١٩ نقطة من ناسا باور · مقياس واحد كل مرة'],
    compare_h: ['Rank the Delta’s data points on one measure.', 'رتّب نقط الدلتا على مقياس واحد.'],
    compare_sub: ['Tap a governorate on the map to set your place. Governorates without their own NASA point use the nearest one.', 'دوس على محافظة في الخريطة عشان تختار مكانك. المحافظات اللي ملهاش نقطة من ناسا بتاخد أقرب نقطة.'],
    m_hot: ['Hot days in wheat grain filling (your wheat date)', 'أيام الحر وقت امتلاء حبة القمح (ميعادك)'], m_water: ['Summer crop water need, ratio to your place', 'احتياج المية للمحصول الصيفي، نسبة لمكانك'],
    m_season: ['Wheat season fit at your date', 'مناسبة ميعاد القمح'], m_tmax: ['Mean daily maximum in July (°C)', 'متوسط العظمى في يوليو'],
    copy_csv: ['Copy as CSV', 'انسخ CSV'], copied: ['Copied', 'اتنسخ'], copy_fail: ['Select the text below and copy it', 'حدد النص اللي تحت وانسخه'],
    rank: ['Rank', 'الترتيب'], point: ['Data point', 'النقطة'], value: ['Value', 'القيمة'], note: ['Note', 'ملحوظة'],
    outside: ['{g} is outside the Nile Delta. The tool covers the Delta only.', '{g} برا دلتا النيل. الأداة بتغطي الدلتا بس.'],
    uses_nearest: ['{g} has no NASA point of its own: uses the nearest data point, {s} (about {km} km).', '{g} ملهاش نقطة من ناسا: بنستخدم أقرب نقطة، {s} (حوالي {km} كم).'],
    uses_cell: ['{g}: in the same NASA weather cell as {s}, so it uses that point.', '{g}: في نفس خلية طقس ناسا بتاعة {s}، فبنستخدمها.'],
    uses_own: ['{g}: uses its own NASA data point, {s}.', '{g}: بنستخدم نقطة ناسا بتاعتها، {s}.'],
    map_caption: ['Governorate borders: CAPMAS via HDX (CC BY-IGO). Nile branches and lakes: Natural Earth. Dots: NASA POWER data points (big: named, small: extra cells).', 'حدود المحافظات: CAPMAS عن طريق HDX. فروع النيل والبحيرات: Natural Earth. النقط: نقط ناسا باور (الكبيرة: بأسامي، الصغيرة: خلايا زيادة).'],
    data_eyebrow: ['SIX NASA DATASETS · WHAT EACH ONE DOES', 'ست مجموعات بيانات من ناسا · كل واحدة بتعمل إيه'],
    data_h: ['NASA POWER drives every number a farmer sees.', 'ناسا باور ورا كل رقم الفلاح بيشوفه.'],
    data_sub: ['The other five NASA datasets give the pictures and check our inputs. We say which is which.', 'الخمسة التانيين بيدونا الصور وبيراجعوا مدخلاتنا. وبنقول مين بيعمل إيه.'],
    role_farmer: ['Used by the farmer', 'للفلاح'], role_picture: ['Pictures + check', 'صور ومراجعة'], role_check: ['Check only', 'مراجعة بس'], role_context: ['Context only', 'سياق بس'],
    phen_h: ['NASA MCD12Q2: when the land is green (a second check)', 'ناسا MCD12Q2: الأرض بتخضر إمتى (مراجعة)'],
    phen_p: ['Median greenup, peak and dormancy over 11 years at each named point. It agrees with the calendar the engines assume; it feeds no number the farmer sees.', 'وسيط بداية الاخضرار والذروة والسكون في ١١ سنة عند كل نقطة. بيتفق مع التقويم اللي المحركات بتفترضه، ومش بيطلع منه رقم للفلاح.'],
    cycle1: ['Cycle 1 (winter)', 'الدورة ١ (شتوي)'], cycle2: ['Cycle 2 (summer)', 'الدورة ٢ (صيفي)'], greenup: ['Greenup', 'بداية الاخضرار'], peak: ['Peak', 'الذروة'], dormancy: ['Dormancy', 'السكون'],
    modis_cap: ['NASA MODIS MOD13Q1 greenness of the Delta, winter and summer (data art, not a map). Drag to compare.', 'اخضرار الدلتا من ناسا مودس، شتا وصيف (صورة بيانات، مش خريطة). اسحب للمقارنة.'],
    other_tables: ['Other tables (not NASA)', 'جداول تانية (مش من ناسا)'],
    ask_h: ['Ask Eyad', 'اسأل إياد'], ask_sub: ['Answers only from our tables, offline in your browser. No AI model, no network. If the tables cannot answer, Eyad says so.', 'بيجاوب من جداولنا بس، من غير نت. من غير ذكاء اصطناعي. لو الجداول مش بتجاوب، إياد بيقول كده.'],
    ask_ph: ['Ask about wheat dates, water, salt, crops or income', 'اسأل عن ميعاد القمح، المية، الملح، المحاصيل أو الدخل'], send: ['Send', 'ابعت'],
    ask_try: ['Try:', 'جرب:'], ask_open: ['Ask Eyad', 'اسأل إياد'], close: ['Close', 'اقفل'],
    methods_eyebrow: ['METHOD AND LIMITS', 'الطريقة والحدود'], methods_h: ['How the numbers are made, and what they are not.', 'الأرقام بتتعمل إزاي، وإيه اللي هي مش هو.'],
    not_claim_h: ['What we do not claim', 'إحنا مش بنقول إيه'], not_model_h: ['Not modelled', 'مش محسوب'], engines_h: ['The engines', 'المحركات'], limits_h: ['Known limits', 'حدود معروفة'],
    judges_eyebrow: ['EVIDENCE · FIVE CRITERIA', 'الأدلة · خمس معايير'], judges_h: ['Five criteria, answered with evidence.', 'خمس معايير، وكل واحد بالدليل.'],
    judges_sub: ['Everything below can be checked in this site and the repository.', 'كل اللي تحت ممكن تتأكد منه في الموقع والمستودع.'],
    valid_h: ['What we checked', 'إحنا راجعنا إيه'], datasets_h: ['The six NASA datasets', 'مجموعات بيانات ناسا الست'],
    src: ['source', 'المصدر'], src_file: ['From', 'من'], src_not: ['It does not mean', 'مش معناه'],
    footer: ['Field Shift: Egypt · NASA Space Apps Challenge 2026 · challenge: Field Shift: Adapting Farms with NASA Data · MIT licence (data and fonts keep their own licences).', 'فيلد شيفت: مصر · تحدي ناسا سبيس آبس ٢٠٢٦ · ترخيص MIT.'],
    ar_draft: ['Arabic interface text is a draft awaiting native review.', 'النص العربي مسودة لسه محتاجة مراجعة.'],
    not_available: ['not available', 'مش متاح']
  };
  I.t = function (k, vars) {
    var e = T[k]; var s = e ? (I.lang === 'ar' ? e[1] : e[0]) : k;
    if (vars) Object.keys(vars).forEach(function (v) { s = s.split('{' + v + '}').join(vars[v]); });
    return s;
  };
  I.label = function (l) { return I.t({ 'right season': 'l_right', 'so-so': 'l_so', 'wrong season': 'l_wrong', 'cannot judge': 'l_na' }[l] || 'l_na'); };
  I.labelCls = function (l) { return { 'right season': 'ok', 'so-so': 'warn', 'wrong season': 'bad', 'cannot judge': 'na' }[l] || 'na'; };
  I.status = function (s) { return I.t({ fine: 'st_fine', reduced: 'st_reduced', 'not advised': 'st_not' }[s]); };
  // Fill a blueprint (blueprints.json) with slots from the engine facts, exactly like docs/try.js.
  I.fill = function (b, f) {
    var slots = { crop: I.cropLow(f.summer_crop), summer_date: I.date(f.summer_date), wheat_date: I.date(f.wheat_date), gap: I.n(f.gap), heat_extra: I.n(f.heat_extra), gap_days: I.days(f.gap), heat_extra_days: I.days(f.heat_extra),
      alt_crop: f.alt_crop ? I.cropLow(f.alt_crop) : '', alt_pct: f.alt_pct != null ? I.n(f.alt_pct) : '', summer_best: f.summer_best ? I.date(f.summer_best) : '', wheat_best: f.wheat_best ? I.date(f.wheat_best) : '' };
    var t = b[I.lang];
    Object.keys(slots).forEach(function (k) { t = t.split('{' + k + '}').join(slots[k]); });
    if (I.lang === 'en') t = t.replace(/(^|[.!?] )([a-z])/g, function (m, a, c) { return a + c.toUpperCase(); });
    return t;
  };
})();
