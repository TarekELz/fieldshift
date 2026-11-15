// Which locale to ask the phone's speech recogniser for. Pure functions, so they can be tested without a phone (test/stt_locale_test.dart).
//
// A phone may list its recognition languages as 'ar_EG', 'ar-EG' or not at all (the list can be empty or late). Passing no locale makes Android use
// the phone's own language, which on an English phone turns «كفر الشيخ» into English words. So in Arabic mode we always pass an Arabic locale:
// the listed one if there is one, otherwise 'ar-EG' (the Google recogniser accepts it online even when it is not listed).

String _norm(String s) => s.toLowerCase().replaceAll('-', '_');

/// The locale id to pass to the recogniser. Never null: [arabic] mode never falls back to the phone's default language.
String pickSttLocale(List<String> listed, {required bool arabic}) {
  final prefs = arabic ? const ['ar_eg', 'ar_sa'] : const ['en_us', 'en_gb'];
  for (final p in prefs) {
    for (final id in listed) {
      if (_norm(id) == p) return id;
    }
  }
  final lang = arabic ? 'ar' : 'en';
  for (final id in listed) {
    final n = _norm(id);
    if (n == lang || n.startsWith('${lang}_')) return id;
  }
  return arabic ? 'ar-EG' : 'en-US';
}

/// True when text heard in Arabic mode came back mostly in Latin letters: the recogniser listened in another language, so the words are wrong.
bool heardInWrongScript(String text, {required bool arabic}) {
  if (!arabic) return false;
  final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
  final ar = RegExp(r'[ء-ي]').allMatches(text).length;
  return latin >= 3 && latin > ar;
}
