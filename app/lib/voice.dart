// Voice: the phone's own speech recognition and text-to-speech (free, no key).
// Egyptian Arabic is requested first (ar-EG), then any Arabic. Whether the phone has an Arabic
// voice, and whether recognition needs internet, depends on the device and is unconfirmed:
// the app keeps working with typing and tap-to-answer chips if either is missing.
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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

class Voice {
  final AudioPlayer _player = AudioPlayer();
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

  Future<void> speak(String text) async {
    if (muted) return;
    final clip = await Clips.lookup(text);
    if (clip != null) {
      try {
        await _player.stop();
        if (ttsReady) await _tts.stop();
        speaking.value = true;
        _player.onPlayerComplete.first.then((_) => speaking.value = false);
        await _player.play(AssetSource('audio/$clip'));
        return;
      } catch (_) {
        speaking.value = false; // the clip could not be played: use the phone's voice below
      }
    }
    if (!ttsReady) return;
    await _tts.stop();
    speaking.value = true;
    try {
      await _tts.speak(text);
    } finally {
      speaking.value = false;
    }
  }

  Future<void> stopSpeaking() async {
    speaking.value = false;
    try {
      await _player.stop();
    } catch (_) {}
    if (ttsReady) await _tts.stop();
  }
}
