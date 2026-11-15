// The recogniser locale choice (stt_locale.dart): Arabic mode never falls back to the phone's default language.
import 'package:field_shift/stt_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic: Egyptian first, then Saudi, then any Arabic, then an explicit ar-EG', () {
    expect(pickSttLocale(['en_US', 'ar_SA', 'ar_EG'], arabic: true), 'ar_EG');
    expect(pickSttLocale(['en-US', 'ar-EG'], arabic: true), 'ar-EG'); // dash form kept as listed
    expect(pickSttLocale(['en_US', 'ar_SA'], arabic: true), 'ar_SA');
    expect(pickSttLocale(['en_US', 'ar'], arabic: true), 'ar');
    expect(pickSttLocale(['en_US', 'ar_JO'], arabic: true), 'ar_JO');
    expect(pickSttLocale(['en_US', 'fr_FR'], arabic: true), 'ar-EG'); // none listed: still Arabic, never the default
    expect(pickSttLocale([], arabic: true), 'ar-EG'); // empty list
  });

  test('English mode', () {
    expect(pickSttLocale(['ar_EG', 'en_GB', 'en_US'], arabic: false), 'en_US');
    expect(pickSttLocale(['ar_EG'], arabic: false), 'en-US');
  });

  test('a result in Latin letters in Arabic mode is treated as a failure', () {
    expect(heardInWrongScript('kab bread', arabic: true), isTrue);
    expect(heardInWrongScript('كفر الشيخ', arabic: true), isFalse);
    expect(heardInWrongScript('كفر الشيخ 10', arabic: true), isFalse);
    expect(heardInWrongScript('kab bread', arabic: false), isFalse);
    expect(heardInWrongScript('ok', arabic: true), isFalse); // too short to judge
  });
}
