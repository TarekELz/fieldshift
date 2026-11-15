// Every sentence Eyad says in the question flow that does not depend on the farmer's numbers should have a pre-generated Egyptian-voice clip.
// Run with DUMP_SPOKEN=1 to write scripts/spoken_lines.json (the list scripts/hamsa_tts.py generates).
import 'dart:convert';
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:field_shift/sentences.dart';
import 'package:field_shift/spoken_ar.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

const _routes = [
  ['gharbia', 'improve', 'rice', '06-15', '12-01', '10', 'patches'],
  ['gharbia', 'plan', 'onion', '11-15', 'patches'],
  ['gharbia', 'money', 'patches'],
];

Set<String> _spokenSentences(EngineData data) {
  final out = <String>{};
  void add(Iterable<BotMessage> ms) {
    for (final m in ms) {
      if (m.result != null) continue; // the result summary depends on the numbers: generated live
      out.addAll(splitSentences(speakable(m.ar))); // the sentences as the voice gets them
    }
  }

  add([Dialogue(data).opening()]);
  for (final route in _routes) {
    for (var i = 0; i < route.length; i++) {
      final probe = Dialogue(data)..opening();
      for (var j = 0; j < i; j++) {
        probe.handle(route[j]);
      }
      for (final v in probe.prompt().choices.map((c) => c.value)) {
        final d = Dialogue(data)..opening();
        for (var j = 0; j < i; j++) {
          d.handle(route[j]);
        }
        add(d.handle(v));
      }
      final e = Dialogue(data)..opening();
      for (var j = 0; j < i; j++) {
        e.handle(route[j]);
      }
      add(e.handle('xyz'));
    }
  }
  return out;
}

void main() {
  test('deterministic spoken sentences have clips (or the list is dumped for generation)', () async {
    final data = await EngineData.load(_FileBundle());
    final sentences = _spokenSentences(data).where((s) => s.length >= 4).toList()..sort();
    final idx = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as Map).keys.map((k) => k.toString().trim()).toSet();
    if (Platform.environment['DUMP_SPOKEN'] == '1') {
      File('../scripts/spoken_dialogue.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(sentences));
      stdout.writeln('dumped ${sentences.length} sentences from the dialogue');
      return;
    }
    final missing = sentences.where((s) => !idx.contains(s)).toList();
    stdout.writeln('${sentences.length - missing.length} of ${sentences.length} sentences have a clip');
    expect(missing.length, lessThanOrEqualTo(sentences.length * 0.1), reason: 'missing clips: ${missing.take(8)}');
  });
}
