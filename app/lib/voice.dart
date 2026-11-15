// Voice: the phone's own speech recognition and text-to-speech (free, no key).
// Egyptian Arabic is requested first (ar-EG), then any Arabic. Whether the phone has an Arabic
// voice, and whether recognition needs internet, depends on the device and is unconfirmed:
// the app keeps working with typing and tap-to-answer chips if either is missing.
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Voice {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool sttReady = false, ttsReady = false, listening = false;
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
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening = false;
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
    await _stt.stop();
  }

  Future<void> speak(String text) async {
    if (!ttsReady || muted) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    if (ttsReady) await _tts.stop();
  }
}
