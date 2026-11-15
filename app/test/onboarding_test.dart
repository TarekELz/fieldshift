// The setup flow has three screens and one real setting: whether Eyad reads replies aloud.
import 'package:field_shift/welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(void Function(bool) onDone) => MaterialApp(
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Onboarding(onDone: onDone),
    );

void main() {
  testWidgets('walking through and choosing typing turns spoken replies off', (t) async {
    bool? result;
    await t.pumpWidget(_app((v) => result = v));
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
    }
    expect(find.byIcon(Icons.keyboard_alt_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.keyboard_alt_rounded));
    await t.pumpAndSettle();
    await t.tap(find.byType(FilledButton));
    expect(result, isFalse);
  });

  testWidgets('the default keeps voice on, and the first screen can be skipped', (t) async {
    bool? result;
    await t.pumpWidget(_app((v) => result = v));
    await t.tap(find.byType(TextButton));
    expect(result, isTrue);
    result = null;
    await t.pumpWidget(_app((v) => result = v));
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
    }
    await t.tap(find.byType(FilledButton));
    expect(result, isTrue);
  });
}
