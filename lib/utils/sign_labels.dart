import '../models/detection_result.dart';

class SignLabels {
  static const Map<String, Map<String, dynamic>> _labels = {
    '30HIZSINIRI': {
      'tts': '30 hız sınırı',
      'priority': SignPriority.high,
    },
    '50HIZSINIRI': {
      'tts': '50 hız sınırı',
      'priority': SignPriority.high,
    },
    '70HIZSINIRI': {
      'tts': '70 hız sınırı',
      'priority': SignPriority.high,
    },
    'ANAYOL': {
      'tts': 'Ana yol',
      'priority': SignPriority.medium,
    },
    'ANAYOLTALIYOL': {
      'tts': 'Ana yol, tali yol',
      'priority': SignPriority.medium,
    },
    'CIFTYON': {
      'tts': 'Çift yön',
      'priority': SignPriority.medium,
    },
    'DUR': {
      'tts': 'Dur',
      'priority': SignPriority.critical,
    },
    'DURAK': {
      'tts': 'Durak',
      'priority': SignPriority.low,
    },
    'ENGELLIPARK': {
      'tts': 'Engelli park yeri',
      'priority': SignPriority.low,
    },
    'GIRILMEZ': {
      'tts': 'Girilmez',
      'priority': SignPriority.critical,
    },
    'ILERISAG': {
      'tts': 'İleri ve sağ',
      'priority': SignPriority.medium,
    },
    'ILERISOL': {
      'tts': 'İleri ve sol',
      'priority': SignPriority.medium,
    },
    'ILERITEKYON': {
      'tts': 'İleri tek yön',
      'priority': SignPriority.medium,
    },
    'KASIS': {
      'tts': 'Dikkat, kasis',
      'priority': SignPriority.high,
    },
    'KAVSAK': {
      'tts': 'Kavşak',
      'priority': SignPriority.medium,
    },
    'KIRMIZIISIK': {
      'tts': 'Kırmızı ışık',
      'priority': SignPriority.critical,
    },
    'OKULGECIDI': {
      'tts': 'Okul geçidi',
      'priority': SignPriority.high,
    },
    'PARK': {
      'tts': 'Park',
      'priority': SignPriority.low,
    },
    'PARKYASAK': {
      'tts': 'Park yasak',
      'priority': SignPriority.low,
    },
    'SAG': {
      'tts': 'Sağa dön',
      'priority': SignPriority.medium,
    },
    'SAGADONULMEZ': {
      'tts': 'Sağa dönülmez',
      'priority': SignPriority.high,
    },
    'SAGATEHLIKELIVIRAJ': {
      'tts': 'Sağa tehlikeli viraj',
      'priority': SignPriority.high,
    },
    'SAGCAPRAZ': {
      'tts': 'Sağ çapraz yol',
      'priority': SignPriority.medium,
    },
    'SARIISIK': {
      'tts': 'Sarı ışık, dikkat',
      'priority': SignPriority.high,
    },
    'SOL': {
      'tts': 'Sola dön',
      'priority': SignPriority.medium,
    },
    'SOLADONULMEZ': {
      'tts': 'Sola dönülmez',
      'priority': SignPriority.high,
    },
    'SOLATEHLIKELIVIRAJ': {
      'tts': 'Sola tehlikeli viraj',
      'priority': SignPriority.high,
    },
    'TTKAPALIYOL': {
      'tts': 'T tipi kapalı yol',
      'priority': SignPriority.medium,
    },
    'UCGENTRAFIKISARETI': {
      'tts': 'Dikkat, trafik işareti',
      'priority': SignPriority.medium,
    },
    'UDONUSUYASAK': {
      'tts': 'U dönüşü yasak',
      'priority': SignPriority.medium,
    },
    'YAYAGECIDI': {
      'tts': 'Yaya geçidi',
      'priority': SignPriority.high,
    },
    'YESILISIK': {
      'tts': 'Yeşil ışık',
      'priority': SignPriority.low,
    },
    'YOLVER': {
      'tts': 'Yol ver',
      'priority': SignPriority.critical,
    },
  };

  static String getTtsText(String classId) {
    return _labels[classId]?['tts'] as String? ?? classId;
  }

  static SignPriority getPriority(String classId) {
    return _labels[classId]?['priority'] as SignPriority? ?? SignPriority.medium;
  }

  static List<String> get allClassIds => _labels.keys.toList();
}
