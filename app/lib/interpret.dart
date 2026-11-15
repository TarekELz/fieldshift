// The AI reads an answer that is not among the options (decision D20): when the dialogue did not understand a phrase at the goal or crop question, Gemini is asked
// which of the allowed options it means. It sees ONLY the short phrase the farmer said or typed (no place, no name, nothing else). Its answer is accepted only if
// it is exactly one of the allowed keys; anything else (or no key, or no internet, or a slow answer) leaves the normal "I did not understand" retry in place.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'proxy.dart';

import 'advice.dart';
import 'dialogue.dart';

const _model = 'gemini-3.1-flash-lite';

/// The options the AI may choose from at the current question, as {key: meaning}, or null when the question is not one the AI interprets.
Map<String, String>? interpretOptions(Dialogue d) {
  switch (d.step) {
    case Step.goal:
      return {
        'money': 'the farmer wants to earn more money / more income',
        'plan': 'the farmer wants to grow a specific crop at a specific time (planning a crop)',
        'improve': 'the farmer wants to improve what he grows now, his current crops or rotation',
      };
    case Step.planCrop:
      return {for (final c in d.book.all) c.key: '${c.en} (${c.ar})'};
    case Step.crop:
      return {'rice': 'rice (الرز)', 'maize': 'maize / corn (الذرة)', 'cotton': 'cotton (القطن)'};
    default:
      return null;
  }
}

typedef InterpretCaller = Future<String> Function(String key, String system, String phrase, Duration timeout);

Future<String> _callGemini(String key, String system, String phrase, Duration timeout) async {
  final r = await http
      .post(key == kProxyKey ? Uri.parse('$kProxyUrl/gemini') : Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
          headers: key == kProxyKey ? proxyHeaders : {'x-goog-api-key': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {'parts': [{'text': system}]},
            'contents': [{'role': 'user', 'parts': [{'text': phrase}]}],
            'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 20},
          }))
      .timeout(timeout);
  if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
  final parts = (jsonDecode(r.body)['candidates'][0]['content']['parts'] as List);
  return parts.map((p) => (p['text'] ?? '') as String).join().trim();
}

/// Which allowed key the phrase means, or null. Keys are tried in turn; the whole attempt is bounded by [budget].
Future<String?> interpretPhrase(String phrase, Map<String, String> options,
    {Duration budget = const Duration(seconds: 5), List<String>? keys, InterpretCaller? caller}) async {
  final p = phrase.trim();
  if (p.isEmpty || p.length > 80) return null; // a short answer, not a story
  final ks = keys ?? await geminiKeys();
  if (ks.isEmpty) return null;
  final system = 'You classify a short phrase said by an Egyptian farmer (Arabic, often colloquial, or English; spelling may be wrong) into exactly one of the allowed keys.\n'
      'Allowed keys and their meaning:\n${options.entries.map((e) => '${e.key}: ${e.value}').join('\n')}\n'
      'Answer with ONLY the key. If the phrase does not clearly mean one of them, answer none. No explanation.';
  final call = caller ?? _callGemini;
  final sw = Stopwatch()..start();
  for (final k in ks) {
    final left = budget - sw.elapsed;
    if (left.inMilliseconds < 400) break;
    try {
      final out = (await call(k, system, p, left)).trim().toLowerCase().replaceAll(RegExp(r'[^a-z_]'), '');
      return options.containsKey(out) ? out : null; // anything but an allowed key is ignored
    } catch (_) {
      continue; // quota, network or too slow: next key
    }
  }
  return null;
}
