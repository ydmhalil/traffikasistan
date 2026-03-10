import '../models/detection_result.dart';
import '../services/detector_service.dart';
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

    // Yeni akıllı seslendirme API'si kullan
    await _tts.speakDetection(detection);
  }

  /// Aynı anda birden fazla tespit varsa akıllı önceliklendirme:
  /// 1. Merkez bölgede olanlar öncelikli (sürücünün gittiği yön)
  /// 2. Priority seviyesi (critical > high > medium > low)
  /// 3. Bbox alanı (yakın/büyük tabelalar öncelikli)
  /// 4. Confidence (güven skoru)
  DetectionResult? pickHighestPriority(List<DetectionResult> detections) {
    if (detections.isEmpty) return null;
    if (detections.length == 1) return detections.first;

    // Önce merkez bölgede olanları filtrele
    final centerDetections = detections
        .where((d) => d.scanZone == ScanZone.center)
        .toList();

    // Merkez bölgede tespit varsa onları kullan, yoksa tümüne bak
    final candidates = centerDetections.isNotEmpty ? centerDetections : detections;

    // Akıllı sıralama: priority + bbox area (yakınlık) + confidence
    candidates.sort((a, b) {
      // 1. Priority (en önemli)
      final priorityDiff = a.priority.index.compareTo(b.priority.index);
      if (priorityDiff != 0) return priorityDiff;

      // 2. Bbox alanı (büyük = yakın/önemli)
      final aArea = a.boundingBox.width * a.boundingBox.height;
      final bArea = b.boundingBox.width * b.boundingBox.height;
      final areaDiff = bArea.compareTo(aArea);
      if (areaDiff != 0) return areaDiff;

      // 3. Confidence
      return b.confidence.compareTo(a.confidence);
    });

    return candidates.first;
  }

  /// Merkez bölgeye odaklanan filtreleme - yan tabelaları bastır
  List<DetectionResult> filterRelevantSigns(List<DetectionResult> detections) {
    if (detections.isEmpty) return detections;

    // Kritik levha varsa hepsini göster
    final hasCritical = detections.any((d) => d.isCritical);
    if (hasCritical) return detections;

    // Merkez bölgede tespit varsa yan bölgeleri filtrele
    final centerSigns = detections.where((d) => d.scanZone == ScanZone.center).toList();
    if (centerSigns.isNotEmpty) {
      // Merkezdeki büyük tabelaları + yan bölgelerden sadece büyük/öncelikli olanları
      final sideSigns = detections
          .where((d) => d.scanZone != ScanZone.center)
          .where((d) => 
              (d.boundingBox.width * d.boundingBox.height) > 0.02 || // büyük tabela
              d.priority.index <= SignPriority.high.index // veya yüksek öncelikli
          )
          .toList();
      
      return [...centerSigns, ...sideSigns];
    }

    return detections;
  }

  void reset() {
    _lastAlertTime.clear();
  }
}
