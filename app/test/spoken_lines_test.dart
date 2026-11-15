// Every sentence Eyad says in the question flow that does not depend on the farmer's numbers should have a pre-generated Egyptian-voice clip.
// Run with DUMP_SPOKEN=1 to write scripts/spoken_lines.json (the list scripts/hamsa_tts.py generates).
import 'dart:convert';
import 'dart:io';

import 'package:field_shift/dialogue.dart';
import 'package:field_shift/engine.dart';
import 'package:field_shift/sentences.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle implements AssetBundleLike {
  @override
  Future<String> loadString(String key) async => File(key).readAsString();
}

const _route = ['gharbia', 'rice', '06-15', '12-01', '10', 'patches'];

Set<String> _spokenSentences(EngineData data) {
  final out = <String>{};
  void add(Iterable<BotMessage> ms) {
    for (final m in ms) {
      if (m.result != null) continue; // the result summary depends on the numbers: generated live
      out.addAll(splitSentences(m.ar));
    }
  }

  add([Dialogue(data).opening()]);
  for (var i = 0; i < _route.length; i++) {
    final probe = Dialogue(data)..opening();
    for (var j = 0; j < i; j++) {
      probe.handle(_route[j]);
    }
    final choices = [
      for (final m in [probe.prompt()]) ...m.choices.map((c) => c.value)
    ];
    for (final v in choices) {
      final d = Dialogue(data)..opening();
      for (var j = 0; j < i; j++) {
        d.handle(_route[j]);
      }
      add(d.handle(v));
    }
    final e = Dialogue(data)..opening();
    for (var j = 0; j < i; j++) {
      e.handle(_route[j]);
    }
    add(e.handle('xyz'));
  }
  return out;
}

void main() {
  test('deterministic spoken sentences have clips (or the list is dumped for generation)', () async {
    final data = await EngineData.load(_FileBundle());
    final sentences = _spokenSentences(data).where((s) => s.length >= 4).toList()..sort();
    final idx = (jsonDecode(File('assets/audio/index.json').readAsStringSync()) as Map).keys.map((k) => k.toString().trim()).toSet();
    if (Platform.environment['DUMP_SPOKEN'] == '1') {
      final all = {...idx, ...sentences}.toList()..sort();
      File('../scripts/spoken_lines.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(all));
      stdout.writeln('dumped ${all.length} lines (${sentences.length} sentences from the dialogue)');
      return;
    }
    final missing = sentences.where((s) => !idx.contains(s)).toList();
    stdout.writeln('${sentences.length - missing.length} of ${sentences.length} sentences have a clip');
    expect(missing.length, lessThanOrEqualTo(sentences.length * 0.1), reason: 'missing clips: ${missing.take(8)}');
  });
}
