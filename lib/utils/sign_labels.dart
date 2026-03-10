import '../models/detection_result.dart';

class SignLabels {
  static const Map<String, Map<String, dynamic>> _labels = {
    '30HIZSINIRI': {
      'tts': '30 hız sınırı',
      'priority': SignPriority.high,
      'icon': '30',
    },
    '50HIZSINIRI': {
      'tts': '50 hız sınırı',
      'priority': SignPriority.high,
      'icon': '50',
    },
    '70HIZSINIRI': {
      'tts': '70 hız sınırı',
      'priority': SignPriority.high,
      'icon': '70',
    },
    'ANAYOL': {
      'tts': 'Ana yol',
      'priority': SignPriority.medium,
      'icon': '⬆️',
    },
    'ANAYOLTALIYOL': {
      'tts': 'Ana yol, tali yol',
      'priority': SignPriority.medium,
      'icon': '↕',
    },
    'CIFTYON': {
      'tts': 'Çift yön',
      'priority': SignPriority.medium,
      'icon': '⇅',
    },
    'DUR': {
      'tts': 'Dur',
      'priority': SignPriority.critical,
      'icon': '⛔',
    },
    'DURAK': {
      'tts': 'Durak',
      'priority': SignPriority.low,
      'icon': '🚏',
    },
    'ENGELLIPARK': {
      'tts': 'Engelli park yeri',
      'priority': SignPriority.low,
      'icon': '♿',
    },
    'GIRILMEZ': {
      'tts': 'Girilmez',
      'priority': SignPriority.critical,
      'icon': '🚫',
    },
    'ILERISAG': {
      'tts': 'İleri ve sağ',
      'priority': SignPriority.medium,
      'icon': '↱',
    },
    'ILERISOL': {
      'tts': 'İleri ve sol',
      'priority': SignPriority.medium,
      'icon': '↰',
    },
    'ILERITEKYON': {
      'tts': 'İleri tek yön',
      'priority': SignPriority.medium,
      'icon': '⬆',
    },
    'KASIS': {
      'tts': 'Dikkat, kasis',
      'priority': SignPriority.high,
      'icon': '🚧',
    },
    'KAVSAK': {
      'tts': 'Kavşak',
      'priority': SignPriority.medium,
      'icon': '✖',
    },
    'KIRMIZIISIK': {
      'tts': 'Kırmızı ışık',
      'priority': SignPriority.critical,
      'icon': '🔴',
    },
    'OKULGECIDI': {
      'tts': 'Okul geçidi',
      'priority': SignPriority.high,
      'icon': '🎓',
    },
    'PARK': {
      'tts': 'Park',
      'priority': SignPriority.low,
      'icon': '🅿️',
    },
    'PARKYASAK': {
      'tts': 'Park yasak',
      'priority': SignPriority.low,
      'icon': '🚳',
    },
    'SAG': {
      'tts': 'Sağa dön',
      'priority': SignPriority.medium,
      'icon': '➡',
    },
    'SAGADONULMEZ': {
      'tts': 'Sağa dönülmez',
      'priority': SignPriority.high,
      'icon': '🚷',
    },
    'SAGATEHLIKELIVIRAJ': {
      'tts': 'Sağa tehlikeli viraj',
      'priority': SignPriority.high,
      'icon': '↗',
    },
    'SAGCAPRAZ': {
      'tts': 'Sağ çapraz yol',
      'priority': SignPriority.medium,
      'icon': '↗',
    },
    'SARIISIK': {
      'tts': 'Sarı ışık, dikkat',
      'priority': SignPriority.high,
      'icon': '🟡',
    },
    'SOL': {
      'tts': 'Sola dön',
      'priority': SignPriority.medium,
      'icon': '⬅',
    },
    'SOLADONULMEZ': {
      'tts': 'Sola dönülmez',
      'priority': SignPriority.high,
      'icon': '🚷',
    },
    'SOLATEHLIKELIVIRAJ': {
      'tts': 'Sola tehlikeli viraj',
      'priority': SignPriority.high,
      'icon': '↖',
    },
    'TTKAPALIYOL': {
      'tts': 'T tipi kapalı yol',
      'priority': SignPriority.medium,
      'icon': '⊤',
    },
    'UCGENTRAFIKISARETI': {
      'tts': 'Dikkat, trafik işareti',
      'priority': SignPriority.medium,
      'icon': '⚠',
    },
    'UDONUSUYASAK': {
      'tts': 'U dönüşü yasak',
      'priority': SignPriority.medium,
      'icon': '⤴',
    },
    'YAYAGECIDI': {
      'tts': 'Yaya geçidi',
      'priority': SignPriority.high,
      'icon': '🚶',
    },
    'YESILISIK': {
      'tts': 'Yeşil ışık',
      'priority': SignPriority.low,
      'icon': '🟢',
    },
    'YOLVER': {
      'tts': 'Yol ver',
      'priority': SignPriority.critical,
      'icon': '🔺',
    },
  };

  static String getTtsText(String classId) {
    return _labels[classId]?['tts'] as String? ?? classId;
  }

  static SignPriority getPriority(String classId) {
    return _labels[classId]?['priority'] as SignPriority? ?? SignPriority.medium;
  }

  static String getIcon(String classId) {
    return _labels[classId]?['icon'] as String? ?? '📍';
  }

  static List<String> get allClassIds => _labels.keys.toList();
}
