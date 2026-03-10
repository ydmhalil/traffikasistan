import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/detection_result.dart';
import './detector_service.dart';

/// Android TTS API entegreli akıllı seslendirme servisi
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  double _baseSpeechRate = 0.85;
  double _baseVolume = 1.0;
  double _basePitch = 1.0;

  Future<void> initialize() async {
    // Android özel ayarlar
    if (Platform.isAndroid) {
      await _tts.setEngine('com.google.android.tts'); // Google TTS Engine
      await _tts.setLanguage('tr-TR');
      
      // Android TTS parametreleri
      await _tts.setQueueMode(0); // Flush mode - yeni konuşma eskiyi keser
      await _tts.awaitSpeakCompletion(false); // Async konuşma
    } else if (Platform.isIOS) {
      await _tts.setLanguage('tr-TR');
      await _tts.setSharedInstance(true);
    }

    await _tts.setSpeechRate(_baseSpeechRate);
    await _tts.setVolume(_baseVolume);
    await _tts.setPitch(_basePitch);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setErrorHandler((msg) {
      debugPrint('TTS Hatası: $msg');
      _isSpeaking = false;
    });

    _isInitialized = true;
    debugPrint('TTS servisi hazır (Android Google TTS)');
  }

  /// Tabela tespitine özel akıllı seslendirme
  Future<void> speakDetection(DetectionResult detection) async {
    if (!_isInitialized) return;

    // Önceliğe göre dinamik parametreler
    final params = _getVoiceParameters(detection.priority);
    
    await _tts.setSpeechRate(params.speechRate);
    await _tts.setPitch(params.pitch);
    await _tts.setVolume(params.volume);

    // Gelişmiş seslendirme metni
    final text = _buildEnhancedText(detection);
    
    if (params.interrupt && _isSpeaking) {
      await _tts.stop();
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Basit metin seslendirme (eski API uyumluluğu)
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_isInitialized) return;
    if (_isSpeaking && !interrupt) return;

    if (interrupt && _isSpeaking) {
      await _tts.stop();
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Her tabela için bağlamsal seslendirme metni - TÜM 33 SINIF
  String _buildEnhancedText(DetectionResult detection) {
    final classId = detection.classId;
    final zone = detection.scanZone;
    final isCenter = zone == ScanZone.center;
    final zonePrefix = !isCenter ? '${detection.zoneLabel.toLowerCase()} tarafta, ' : '';

    // Her tabela için özelleştirilmiş metinler
    switch (classId) {
      // ═══════════════════════════════════════════════════════════════
      // KRİTİK ÖNCELIK
      // ═══════════════════════════════════════════════════════════════
      case 'DUR':
        return 'DİKKAT! Dur levhası!';
      
      case 'GIRILMEZ':
        return 'DİKKAT! Girilmez!';
      
      case 'YOLVER':
        return 'DİKKAT! Yol ver!';
      
      case 'KIRMIZIISIK':
        return 'DİKKAT! Kırmızı ışık! Dur!';

      // ═══════════════════════════════════════════════════════════════
      // YÜKSEK ÖNCELIK
      // ═══════════════════════════════════════════════════════════════
      case '30HIZSINIRI':
        return 'Hız limiti 30';
      
      case '50HIZSINIRI':
        return 'Hız limiti 50';
      
      case '70HIZSINIRI':
        return 'Hız limiti 70';
      
      case 'KASIS':
        return 'Dikkat! Kasis var, yavaşlayın';
      
      case 'OKULGECIDI':
        return 'Dikkat! Okul geçidi, yavaşlayın';
      
      case 'YAYAGECIDI':
        return 'Dikkat! Yaya geçidi';
      
      case 'SAGADONULMEZ':
        return 'Dikkat! Sağa dönüş yasak';
      
      case 'SOLADONULMEZ':
        return 'Dikkat! Sola dönüş yasak';
      
      case 'SAGATEHLIKELIVIRAJ':
        return 'Dikkat! Sağa tehlikeli viraj';
      
      case 'SOLATEHLIKELIVIRAJ':
        return 'Dikkat! Sola tehlikeli viraj';
      
      case 'SARIISIK':
        return 'Sarı ışık! Hazırlanın';

      // ═══════════════════════════════════════════════════════════════
      // ORTA ÖNCELIK - Yön levhaları
      // ═══════════════════════════════════════════════════════════════
      case 'ILERITEKYON':
        return '${zonePrefix}İleri tek yön';
      
      case 'ILERISAG':
        return '${zonePrefix}İleri veya sağa dönülebilir';
      
      case 'ILERISOL':
        return '${zonePrefix}İleri veya sola dönülebilir';
      
      case 'SAG':
        return '${zonePrefix}Sağa dönün';
      
      case 'SOL':
        return '${zonePrefix}Sola dönün';
      
      case 'ANAYOL':
        return '${zonePrefix}Ana yol';
      
      case 'ANAYOLTALIYOL':
        return '${zonePrefix}Ana yol, tali yol';
      
      case 'CIFTYON':
        return '${zonePrefix}Çift yön yol';
      
      case 'KAVSAK':
        return '${zonePrefix}Kavşak yaklaşıyor';
      
      case 'SAGCAPRAZ':
        return '${zonePrefix}Sağ çapraz yol';
      
      case 'TTKAPALIYOL':
        return '${zonePrefix}T kavşağı';
      
      case 'UCGENTRAFIKISARETI':
        return '${zonePrefix}Dikkat! Trafik işareti';
      
      case 'UDONUSUYASAK':
        return '${zonePrefix}U dönüşü yasak';

      // ═══════════════════════════════════════════════════════════════
      // DÜŞÜK ÖNCELIK - Park ve bilgilendirme
      // ═══════════════════════════════════════════════════════════════
      case 'PARK':
        return 'Park yeri';
      
      case 'PARKYASAK':
        return 'Park yasak';
      
      case 'ENGELLIPARK':
        return 'Engelli park yeri';
      
      case 'DURAK':
        return 'Durak';
      
      case 'YESILISIK':
        return 'Yeşil ışık';

      // ═══════════════════════════════════════════════════════════════
      // Fallback - Bilinmeyen tabela
      // ═══════════════════════════════════════════════════════════════
      default:
        // Önceliğe göre genel format
        if (detection.isCritical) {
          return 'DİKKAT! ${detection.ttsText}';
        } else if (detection.isHigh) {
          return 'Dikkat! ${detection.ttsText}';
        } else {
          return '$zonePrefix${detection.ttsText}';
        }
    }
  }

  /// Önceliğe göre ses parametreleri
  _VoiceParams _getVoiceParameters(SignPriority priority) {
    switch (priority) {
      case SignPriority.critical:
        return _VoiceParams(
          speechRate: 0.75,  // Daha yavaş (anlaşılırlık)
          pitch: 1.3,        // Daha tiz (dikkat çekici)
          volume: 1.0,       // Maksimum
          interrupt: true,   // Her zaman keser
        );

      case SignPriority.high:
        return _VoiceParams(
          speechRate: 0.8,
          pitch: 1.15,
          volume: 0.95,
          interrupt: true,
        );

      case SignPriority.medium:
        return _VoiceParams(
          speechRate: 0.9,
          pitch: 1.0,
          volume: 0.85,
          interrupt: false,
        );

      case SignPriority.low:
        return _VoiceParams(
          speechRate: 1.0,
          pitch: 0.95,
          volume: 0.75,
          interrupt: false,
        );
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Kullanıcı ayarlarından hız değiştirme
  Future<void> setSpeechRate(double rate) async {
    _baseSpeechRate = rate.clamp(0.5, 1.5);
    if (!_isSpeaking) {
      await _tts.setSpeechRate(_baseSpeechRate);
    }
  }

  /// Ses seviyesi ayarı
  Future<void> setVolume(double volume) async {
    _baseVolume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_baseVolume);
  }

  /// Android TTS engine durumunu kontrol et
  Future<bool> isGoogleTtsAvailable() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final engines = await _tts.getEngines;
      if (engines == null) return false;
      
      return (engines as List).any((e) => 
        e.toString().contains('com.google.android.tts')
      );
    } catch (_) {
      return false;
    }
  }

  /// Mevcut TTS dillerini listele
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      return (languages as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _tts.stop();
  }
}

/// Ses parametreleri modeli
class _VoiceParams {
  final double speechRate;
  final double pitch;
  final double volume;
  final bool interrupt;

  _VoiceParams({
    required this.speechRate,
    required this.pitch,
    required this.volume,
    required this.interrupt,
  });
}
