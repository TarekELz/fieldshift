// Probe (not part of the app): runs the same Hamsa calls as LiveVoice.generate with a key from ../.env, prints what happens, and saves the audio.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final keys = File('../.env').readAsLinesSync().where((l) => RegExp(r'^HAMSA_API_KEY(_\d+)?=').hasMatch(l)).map((l) => l.split('=')[1].trim()).toList();
  const base = 'https://api.tryhamsa.com', voice = '8f329168-6604-4f13-9572-994984f894c4';
  final text = 'تمام، الغربية. دي رسالة تجربة.';
  final sw = Stopwatch()..start();
  for (final k in keys) {
    final h = {'Authorization': 'Token $k', 'Content-Type': 'application/json'};
    final r = await http.post(Uri.parse('$base/v1/jobs/text-to-speech'), headers: h, body: jsonEncode({'voiceId': voice, 'text': text}));
    stdout.writeln('POST ${r.statusCode} after ${sw.elapsedMilliseconds} ms');
    if (r.statusCode != 200 && r.statusCode != 201) {
      stdout.writeln(r.body.substring(0, r.body.length > 150 ? 150 : r.body.length));
      continue;
    }
    var job = (jsonDecode(r.body) as Map)['data'] as Map;
    stdout.writeln('status ${job['status']} keys ${job.keys.take(8).toList()}');
    for (var i = 0; i < 12; i++) {
      final url = ((job['jobResponse'] as Map?)?['ttsMediaFile'] ?? job['mediaUrl']) as String?;
      if (job['status'] == 'COMPLETED' && url != null) {
        final a = await http.get(Uri.parse(url));
        stdout.writeln('audio ${a.statusCode} ${a.bodyBytes.length} bytes after ${sw.elapsedMilliseconds} ms, type ${a.headers['content-type']}');
        File('live_probe.wav').writeAsBytesSync(a.bodyBytes);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      final g = await http.get(Uri.parse('$base/v1/jobs?jobId=${job['id']}'), headers: h);
      job = (jsonDecode(g.body) as Map)['data'] as Map;
      stdout.writeln('poll $i status ${job['status']}');
    }
  }
  stdout.writeln('no audio');
}
