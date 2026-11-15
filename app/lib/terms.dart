// The Terms page: everything that used to appear as small print on the result screens. One place, behind the info button in the top bar.
import 'package:flutter/material.dart';

import 'i18n.dart';
import 'ui_kit.dart';

void showTerms(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Fs.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
        Text(tr('الشروط والأحكام', 'Terms and conditions'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _h(tr('الأرقام والنصايح', 'Numbers and advice')),
        _p(tr('كل الأرقام تقديرات من بيانات ناسا (الطقس من NASA POWER والصور من MODIS) وجداول الفاو، ومن كلامك أنت. مش وعد بمحصول ولا بربح، وبتساعدك ومش بتحل محل خبرتك ولا رأي المرشد الزراعي. اسأل المرشد قبل ما تغير الدورة.',
            'All numbers are estimates from NASA data (weather from NASA POWER, pictures from MODIS), FAO tables and what you tell the app. They are not a promise of a harvest or a profit, they help you and do not replace your experience or an agricultural engineer. Ask an engineer before you change your rotation.')),
        _p(tr('الطقس نموذج بدقة حوالي ٥٠ كم، ولسه ما اتقارنش بمحطات طقس في الدلتا. أرقام أيام الحر للمقارنة بين المواعيد مش أرقام مظبوطة.', 'The weather is a model at about 50 km and has not yet been checked against weather stations in the Delta. Hot-day numbers are for comparing dates, not exact.')),
        _h(tr('الدخل', 'Income')),
        _p(tr('الدخل التقريبي من متوسط مصر كلها (أرقام الفاو): الإنتاجية للفدان من ٢٠٢٠ إلى ٢٠٢٤ وسعر المزارع سنة ٢٠٢٢، وإجمالي قبل أي تكاليف. مش ربح. الخضار والفاكهة تكاليفها أعلى بكتير، والأسعار اتغيرت من وقتها.',
            'Income is from Egypt-wide averages (FAO figures): yield per feddan 2020 to 2024 and the farm-gate price in 2022, gross before any cost. It is not profit. Vegetables and fruit cost much more to grow, and prices have moved since.')),
        _h(tr('الملوحة', 'Salt')),
        _p(tr('مفيش قمر صناعي لناسا بيقيس ملوحة التربة. الملوحة من كلامك أو علامات الأرض، وتحليل التربة أدق. النسبة من جداول الفاو.', 'No NASA satellite measures soil salinity. Salt comes from what you tell the app or the signs on your land, and a soil test is more exact. The percentage comes from the FAO tables.')),
        _h(tr('الذكاء الاصطناعي', 'Artificial intelligence')),
        _p(tr('النصايح مكتوبة من قوالب كتبها الفريق، والأرقام بتطلع من حسابات مش من الذكاء الاصطناعي. ممكن نموذج ذكاء اصطناعي (Gemini) يعيد صياغة النصيحة، وبيتراجع إن الأرقام والمعلومات المهمة اتحفظت. وبيساعد في فهم كلام مش من الاختيارات (بيشوف الجملة القصيرة بس). صورة إياد وصوته مولّدين بالذكاء الاصطناعي.',
            'The advice is written from templates by the team, and the numbers come from calculations, not from the AI. An AI model (Gemini) may reword the advice, and the result is used only if every number and key fact is kept. It also helps understand a phrase that is not among the options (it sees only that short phrase). Eyad\'s picture and voice are AI-generated.')),
        _h(tr('إحنا مين', 'About')),
        _p(tr('مشروع لتحدي ناسا سبيس آبس ٢٠٢٦ من فريق في مصر. البيانات من ناسا والفاو. الكود مفتوح بترخيص MIT. التفاصيل في المستودع.', 'A NASA Space Apps Challenge 2026 project by a team in Egypt. Data: NASA and FAO. Code under the MIT licence. Details in the repository (docs).')),
        _p(noticeN(), dim: true),
        _p(notModelledN(), dim: true),
      ]),
    ),
  );
}

Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)));

Widget _p(String t, {bool dim = false}) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(fontSize: 14, height: 1.55, color: dim ? Fs.dim : null)));
