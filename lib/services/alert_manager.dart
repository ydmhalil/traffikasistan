import '../models/detection_result.dart';
import 'tts_service.dart';

class AlertManager {
  final TtsService _tts;

  // Son uyarı zamanları: classId → DateTime
  final Map<String, DateTime> _lastAlertTime = {};

  // Cooldown süreleri (saniye) — ayarlardan değiştirilebilir
  int cooldownSeconds;
  bool voiceEnabled;

  AlertManager({
    required TtsService tts,
    this.cooldownSeconds = 5,
    this.voiceEnabled = true,
  }) : _tts = tts;

  /// Tespit sonucunu işle, cooldown geçmişse sesli uyarı ver.
  Future<void> handle(DetectionResult detection) async {
    if (!voiceEnabled) return;

    final now = DateTime.now();
    final last = _lastAlertTime[detection.classId];

    // Cooldown geçmediyse ses çıkarma
    if (last != null) {
      final elapsed = now.difference(last).inSeconds;
      if (elapsed < cooldownSeconds) return;
    }

    _lastAlertTime[detection.classId] = now;

    // Kritik levhalar konuşmayı keser ve önce söylenir
    final interrupt = detection.isCritical;
    await _tts.speak(detection.ttsText, interrupt: interrupt);
  }

  /// Aynı anda birden fazla tespit varsa en yüksek öncelikliyi seç
  DetectionResult? pickHighestPriority(List<DetectionResult> detections) {
    if (detections.isEmpty) return null;

    detections.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return detections.first;
  }

  void reset() {
    _lastAlertTime.clear();
  }
}
