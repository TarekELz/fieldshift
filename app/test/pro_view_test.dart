// The professional view builds on a phone-sized screen in both languages and both tabs, without layout errors, and the charts get real data.
import 'dart:io';

import 'package:field_shift/engine.dart';
import 'package:field_shift/i18n.dart';
import 'package:field_shift/pro_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

void main() {
  for (final l in ['ar', 'en']) {
    testWidgets('professional view renders (language $l)', (tester) async {
      tester.view.physicalSize = const Size(1080, 7000); // 360 x 2333 logical: a phone width, tall enough that every card is built
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      lang.value = l;
      final data = (await tester.runAsync(() => EngineData.load(_FileBundle())))!;
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: l == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: ProView(preloaded: data))));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining(l == 'ar' ? 'مناخ ناسا' : 'NASA POWER climate'), findsWidgets);
      void noErrors(String where) {
        final e = tester.takeException();
        expect(e, isNull, reason: where);
      }

      noErrors('place tab');
      await tester.tap(find.byType(Tab).at(1));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LinearProgressIndicator), findsWidgets); // the ranking bars
      noErrors('compare tab');
      expect(find.byType(Tab), findsNWidgets(2)); // Place and Compare only: the Method tab (English paragraphs, file paths) was removed
      lang.value = 'ar';
    });
  }
}
