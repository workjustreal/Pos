// ignore_for_file: avoid_print
import 'package:flutter_tts/flutter_tts.dart';

/// Thai text-to-speech helper. Singleton so the underlying TTS engine is
/// initialised once and reused across screens (saves ~200ms on subsequent
/// calls and avoids the engine cold-start hitch).
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  Future<void>? _initFuture;

  Future<void> _ensureInit() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      await _tts.setLanguage("th-TH");
      await _tts.setSpeechRate(0.5); // slower → easier to catch the amount
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (e) {
      print('TtsService init error: $e');
    }
  }

  /// Speak an arbitrary Thai/English string. Stops any pending speech first
  /// so consecutive calls don't queue up.
  Future<void> speak(String text) async {
    try {
      await _ensureInit();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      print('TtsService.speak error: $e');
    }
  }

  /// Read a monetary amount aloud, e.g. 1250.50 → "ยอดรวม 1250 บาท 50 สตางค์".
  /// Whole-baht amounts skip the satang part for naturalness.
  Future<void> speakAmount(double amount) async {
    final whole = amount.floor();
    final cents = ((amount - whole) * 100).round();
    final text = cents > 0
        ? "ยอดรวม $whole บาท $cents สตางค์"
        : "ยอดรวม $whole บาท";
    await speak(text);
  }
}
