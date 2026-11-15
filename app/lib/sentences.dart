// Splits spoken text into sentences, so each one can be played from a pre-generated clip or generated live. The same splitter is used by the app (voice.dart)
// and by test/spoken_lines_test.dart, which lists the sentences that need a clip.
List<String> splitSentences(String text) {
  final out = <String>[];
  for (final line in text.split('\n')) {
    for (final m in RegExp(r'[^.!؟?]+[.!؟?]*').allMatches(line)) {
      final s = m.group(0)!.trim();
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}
