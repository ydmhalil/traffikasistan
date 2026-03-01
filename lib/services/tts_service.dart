import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_isInitialized) return;
    if (_isSpeaking && !interrupt) return;

    if (interrupt && _isSpeaking) {
      await _tts.stop();
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.5, 1.5));
  }

  bool get isSpeaking => _isSpeaking;

  void dispose() {
    _tts.stop();
  }
}
