import 'package:flutter/material.dart';
import '../services/detector_service.dart';
import '../utils/sign_labels.dart';

enum SignPriority { critical, high, medium, low }

class DetectionResult {
  final String classId;
  final String label;
  final String ttsText;
  final double confidence;
  final Rect boundingBox; // normalize (0.0-1.0), frame koordinatlarında
  final SignPriority priority;
  final ScanZone? scanZone; // hangi tarama bölgesinden geldi

  const DetectionResult({
    required this.classId,
    required this.label,
    required this.ttsText,
    required this.confidence,
    required this.boundingBox,
    required this.priority,
    this.scanZone,
  });

  Color get borderColor {
    switch (priority) {
      case SignPriority.critical:
        return const Color(0xFFFF3B3B);
      case SignPriority.high:
        return const Color(0xFFFFD600);
      case SignPriority.medium:
      case SignPriority.low:
        return const Color(0xFF00B4FF);
    }
  }

  bool get isCritical => priority == SignPriority.critical;
  bool get isHigh => priority == SignPriority.high;

  String get zoneLabel {
    switch (scanZone) {
      case ScanZone.left:   return 'SOL';
      case ScanZone.center: return 'ORTA';
      case ScanZone.right:  return 'SAĞ';
      case null:            return '';
    }
  }

  String get icon => SignLabels.getIcon(classId);
}
