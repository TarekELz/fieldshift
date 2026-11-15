// Voice: the phone's own speech recognition and text-to-speech (free, no key).
// Egyptian Arabic is requested first (ar-EG), then any Arabic. Whether the phone has an Arabic
// voice, and whether recognition needs internet, depends on the device and is unconfirmed:
// the app keeps working with typing and tap-to-answer chips if either is missing.
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'sentences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Pre-generated Egyptian-voice clips of Eyad's fixed lines (assets/audio, made by scripts/hamsa_tts.py with the Hamsa voice Ibrahim; AI-generated, disclosed in
/// docs/ai-disclosure.md). A line with a clip is played; every other line falls back to the phone's own voice.
class Clips {
  static Map<String, String>? _idx;
  static Future<String?> lookup(String text) async {
    if (_idx == null) {
      try {
        final j = jsonDecode(await rootBundle.loadString('assets/audio/index.json')) as Map<String, dynamic>;
        _idx = j.map((k, v) => MapEntry(k, v as String));
      } catch (_) {
        _idx = {};
      }
    }
    return _idx![text.trim()];
  }
}

/// Live generation with the same Egyptian voice (Hamsa, Ibrahim) for short lines that have no clip. Keys come from assets/secrets/secrets.json ('hamsa'),
/// tried in turn when one fails; any failure or a slow answer returns null and the caller uses the phone's voice. Generated audio is kept for the session.
class LiveVoice {
  static const _voiceId = '8f329168-6604-4f13-9572-994984f894c4';
  static const _base = 'https://api.tryhamsa.com';
  static final Map<String, Uint8List> _cache = {};
  static String lastError = 'not tried';

  static Future<List<String>> keys() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/secrets/secrets.json')) as Map<String, dynamic>;
      return ((j['hamsa'] as List?) ?? const []).cast<String>().where((k) => k.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Uint8List?> generate(String text, {Duration budget = const Duration(seconds: 6), List<String>? keyList}) async {
    if (kIsWeb) {
      lastError = 'web build';
      return null;
    }
    if (text.length > 300) {
      lastError = 'sentence too long';
      return null;
    }
    final hit = _cache[text];
    if (hit != null) return hit;
    final ks = keyList ?? await keys();
    if (ks.isEmpty) {
      lastError = 'no Hamsa key in this build';
      return null;
    }
    final sw = Stopwatch()..start();
    for (final k in ks) {
      try {
        final h = {'Authorization': 'Token $k', 'Content-Type': 'application/json'};
        final r = await http.post(Uri.parse('$_base/v1/jobs/text-to-speech'), headers: h, body: jsonEncode({'voiceId': _voiceId, 'text': text})).timeout(budget - sw.elapsed);
        if (r.statusCode != 200 && r.statusCode != 201) {
          lastError = 'Hamsa answered ${r.statusCode}';
          continue;
        }
        var job = (jsonDecode(r.body) as Map)['data'] as Map;
        while (sw.elapsed < budget) {
          final url = ((job['jobResponse'] as Map?)?['ttsMediaFile'] ?? job['mediaUrl']) as String?;
          if (job['status'] == 'COMPLETED' && url != null) {
            final a = await http.get(Uri.parse(url)).timeout(budget - sw.elapsed);
            if (a.statusCode == 200 && a.bodyBytes.isNotEmpty) return _cache[text] = a.bodyBytes;
            break;
          }
          if (job['status'] == 'FAILED') break;
          await Future<void>.delayed(const Duration(milliseconds: 1000));
          final g = await http.get(Uri.parse('$_base/v1/jobs?jobId=${job['id']}'), headers: h).timeout(budget - sw.elapsed);
          if (g.statusCode == 200) job = (jsonDecode(g.body) as Map)['data'] as Map;
        }
      } catch (e) {
        lastError = e.runtimeType.toString(); // offline, quota or too slow
        continue; // next key, then the phone's voice
      }
    }
    if (lastError == 'not tried') lastError = 'no audio returned in time';
    return null;
  }
}

class Voice {
  final AudioPlayer _player = AudioPlayer();
  /// True while an AI-generated voice (a bundled clip or a live line) is speaking: the screen then shows an AI label.
  final ValueNotifier<bool> aiVoice = ValueNotifier<bool>(false);
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool sttReady = false, ttsReady = false, listening = false;
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false); // true while a reply is being read aloud
  final ValueNotifier<bool> listeningNow = ValueNotifier<bool>(false); // false again on a result, a timeout or an error
  bool muted = false; // set by the setup choice "I'll type": replies are written, not spoken
  String? sttLocale, ttsLang, lastError;
  List<LocaleName> _sttLocales = [];
  bool arabic = true;

  Future<void> init() async {
    try {
      sttReady = await _stt.initialize(
        onError: (e) {
          lastError = e.errorMsg;
          listening = false;
          listeningNow.value = false;
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            listening = false;
            listeningNow.value = false;
          }
        },
      );
      if (sttReady) {
        final locales = await _stt.locales();
        _sttLocales = locales;
        String norm(String s) => s.toLowerCase().replaceAll('-', '_');
        final eg = locales.where((l) => norm(l.localeId) == 'ar_eg');
        final ar = locales.where((l) => norm(l.localeId).startsWith('ar'));
        sttLocale = eg.isNotEmpty ? eg.first.localeId : (ar.isNotEmpty ? ar.first.localeId : null);
        if (sttLocale == null) lastError = 'no Arabic speech recognition locale on this phone';
      }
    } catch (e) {
      sttReady = false;
      lastError = '$e';
    }
    try {
      for (final l in ['ar-EG', 'ar-SA', 'ar']) {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          ttsLang = l;
          break;
        }
      }
      if (ttsLang != null) {
        await _tts.setLanguage(ttsLang!);
        await _tts.setSpeechRate(0.45);
        await _tts.awaitSpeakCompletion(true);
        ttsReady = true;
      }
    } catch (e) {
      ttsReady = false;
      lastError = '$e';
    }
  }

  /// Switch recognition and speech to Arabic (ar-EG first) or English (en-US first), when the phone has them.
  Future<void> setLanguage(bool toArabic) async {
    arabic = toArabic;
    String norm(String s) => s.toLowerCase().replaceAll('-', '_');
    final exact = _sttLocales.where((l) => norm(l.localeId) == (toArabic ? 'ar_eg' : 'en_us'));
    final any = _sttLocales.where((l) => norm(l.localeId).startsWith(toArabic ? 'ar' : 'en'));
    sttLocale = exact.isNotEmpty ? exact.first.localeId : (any.isNotEmpty ? any.first.localeId : null);
    try {
      for (final l in (toArabic ? ['ar-EG', 'ar-SA', 'ar'] : ['en-US', 'en-GB', 'en'])) {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          ttsLang = l;
          await _tts.setLanguage(l);
          ttsReady = true;
          return;
        }
      }
      ttsReady = false; // no voice for this language on the phone: replies stay written
    } catch (e) {
      lastError = '$e';
    }
  }

  bool get canListen => sttReady && sttLocale != null;

  /// Start listening; [onResult] gets partial text and, once, the final text.
  Future<void> listen(void Function(String text, bool isFinal) onResult) async {
    if (!canListen) return;
    listening = true;
    listeningNow.value = true;
    await _stt.listen(
      onResult: (r) {
        onResult(r.recognizedWords, r.finalResult);
        if (r.finalResult) listening = false;
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: sttLocale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stopListening() async {
    listening = false;
    listeningNow.value = false;
    await _stt.stop();
  }

  int _gen = 0; // a newer speak() or stopSpeaking() cancels the one in progress
  /// What the last line used and why: "clip", "live", or "phone" with the reason. Shown by a long press on Eyad, so a phone problem is visible.
  String lastNote = 'nothing spoken yet';

  /// Speaks the text in Eyad's Egyptian voice: a whole-line clip if there is one, otherwise sentence by sentence (a clip, else a live line, else the phone's voice).
  Future<void> speak(String text) async {
    if (muted) return;
    final my = ++_gen;
    try {
      await _player.stop();
    } catch (_) {}
    if (ttsReady) await _tts.stop();
    final whole = await Clips.lookup(text);
    final parts = whole != null ? [text.trim()] : splitSentences(text);
    // start every part's audio at once (clips are instant, live lines take about a second each), then play them in order
    final ready = [for (final p in parts) _resolve(p)];
    speaking.value = true;
    final notes = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (my != _gen) return;
      final r = await ready[i];
      if (my != _gen) return;
      if (r.src != null && await _playSource(r.src!, my)) {
        notes.add(r.how);
        continue;
      }
      notes.add('phone (${r.src == null ? r.how : 'the audio could not be played'})');
      aiVoice.value = false;
      if (ttsReady) {
        try {
          await _tts.speak(parts[i]);
        } catch (_) {}
      }
    }
    if (my == _gen) {
      speaking.value = false;
      aiVoice.value = false;
      lastNote = notes.join(', ');
    }
  }

  Future<({Source? src, String how})> _resolve(String part) async {
    final clip = await Clips.lookup(part);
    if (clip != null) return (src: AssetSource('audio/$clip') as Source?, how: 'clip');
    final live = await LiveVoice.generate(part);
    if (live != null) return (src: BytesSource(live, mimeType: 'audio/wav') as Source?, how: 'live');
    return (src: null as Source?, how: 'no clip and live generation failed: ${LiveVoice.lastError}');
  }

  Future<bool> _playSource(Source src, int my) async {
    try {
      aiVoice.value = true;
      final done = _player.onPlayerComplete.first;
      await _player.play(src);
      await done.timeout(const Duration(seconds: 90));
      return true;
    } catch (e) {
      lastNote = 'play error: $e';
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    _gen++;
    speaking.value = false;
    aiVoice.value = false;
    try {
      await _player.stop();
    } catch (_) {}
    if (ttsReady) await _tts.stop();
  }
}
