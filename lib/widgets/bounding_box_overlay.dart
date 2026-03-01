import 'package:flutter/material.dart';
import '../models/detection_result.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size previewSize;

  const BoundingBoxOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoxPainter(detections: detections, previewSize: previewSize),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size previewSize;

  _BoxPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final rect = Rect.fromLTRB(
        det.boundingBox.left * size.width,
        det.boundingBox.top * size.height,
        det.boundingBox.right * size.width,
        det.boundingBox.bottom * size.height,
      );

      // Bounding box çizgisi
      final boxPaint = Paint()
        ..color = det.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = det.isCritical ? 4.0 : 3.0;

      if (det.confidence < 0.65) {
        // Düşük güven → kesik çizgi
        _drawDashedRect(canvas, rect, boxPaint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          boxPaint,
        );
      }

      // Glow efekti (kritik levhalar için)
      if (det.isCritical) {
        final glowPaint = Paint()
          ..color = det.borderColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          glowPaint,
        );
      }

      // Etiket arka planı
      final labelText = '${det.label}  ${(det.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - labelPadding.vertical - 2,
        textPainter.width + labelPadding.horizontal,
        textPainter.height + labelPadding.vertical,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        Paint()..color = det.borderColor.withOpacity(0.85),
      );

      textPainter.paint(
        canvas,
        Offset(
          labelRect.left + labelPadding.left,
          labelRect.top + labelPadding.top,
        ),
      );
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 5.0;

    void drawDashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = (end - start).distance;
      double progress = 0;
      while (progress < length) {
        final from = progress / length;
        final to = ((progress + dashLength) / length).clamp(0.0, 1.0);
        canvas.drawLine(
          Offset(start.dx + dx * from, start.dy + dy * from),
          Offset(start.dx + dx * to, start.dy + dy * to),
          paint,
        );
        progress += dashLength + gapLength;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.detections != detections;
}
