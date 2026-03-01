import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../models/detection_result.dart';
import '../utils/sign_labels.dart';

/// Tespitin hangi tarama bölgesinden geldiği
enum ScanZone { left, center, right }

class DetectorService {
  static const int inputSize = 640;
  static const double defaultConfThreshold = 0.5;
  static const double nmsThreshold = 0.45;

  /// Karenin kaç üst fraksiyonu taransın (0.65 = üst %65)
  static const double roiTopFraction = 0.65;

  OrtSession? _session;
  late List<String> _classNames;
  bool _isInitialized = false;
  bool _isProcessing = false;

  double confidenceThreshold;

  DetectorService({
    this.confidenceThreshold = defaultConfThreshold,
  });

  Future<void> initialize() async {
    OrtEnv.instance.init();

    final labelsData = await rootBundle.loadString('assets/labels/classes.txt');
    _classNames = labelsData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawModel = await rootBundle.load('assets/models/best.onnx');
    final modelBytes = rawModel.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(2);

    _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _isInitialized = true;
    debugPrint('DetectorService: ONNX hazır — ${_classNames.length} sınıf');
  }

  /// Tek inference — ROI üst %65 → 640×640 → ScanZone bbox x pozisyonundan türetilir
  Future<List<DetectionResult>> detect(CameraImage cameraImage) async {
    if (!_isInitialized || _isProcessing || _session == null) return [];

    _isProcessing = true;
    try {
      final rgbImage = _convertCameraImage(cameraImage);
      if (rgbImage == null) return [];

      // Üst %65 ROI — sadece bu satırları dönüştürdük zaten
      final roiH = (rgbImage.height * roiTopFraction).toInt();
      final roi = img.copyCrop(
        rgbImage,
        x: 0,
        y: 0,
        width: rgbImage.width,
        height: roiH,
      );

      // Tek 640×640 resize
      final resized = img.copyResize(
        roi,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      final rawOut = await _runInference(resized);
      if (rawOut == null) return [];

      final dets = _postProcessV8(rawOut);

      // y koordinatını frame alanına geri dönüştür + zone'u x pozisyonundan türet
      return dets.map((d) {
        final y1 = d.boundingBox.top    * roiTopFraction;
        final y2 = d.boundingBox.bottom * roiTopFraction;
        final cx = (d.boundingBox.left + d.boundingBox.right) / 2;
        final zone = cx < 1 / 3
            ? ScanZone.left
            : cx < 2 / 3
                ? ScanZone.center
                : ScanZone.right;

        return DetectionResult(
          classId: d.classId,
          label: d.label,
          ttsText: d.ttsText,
          confidence: d.confidence,
          boundingBox: Rect.fromLTRB(
            d.boundingBox.left,
            y1.clamp(0.0, 1.0),
            d.boundingBox.right,
            y2.clamp(0.0, 1.0),
          ),
          priority: d.priority,
          scanZone: zone,
        );
      }).toList();
    } finally {
      _isProcessing = false;
    }
  }

  Future<List?> _runInference(img.Image image) async {
    try {
      final inputData = _imageToNchw(image); // ONNX: NCHW [1,3,640,640]
      final inputName = _session!.inputNames.first;
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        [1, 3, inputSize, inputSize],
      );

      final outputs = await _session!.runAsync(
        OrtRunOptions(),
        {inputName: inputTensor},
      );
      inputTensor.release();

      if (outputs == null || outputs.isEmpty) return null;
      final result = outputs.first!.value as List;
      for (final o in outputs) {
        o?.release();
      }
      return result;
    } catch (e) {
      debugPrint('ONNX inference hatası: $e');
      return null;
    }
  }

  /// NCHW: [3, H*W] — channel-first, ONNX formatı
  Float32List _imageToNchw(img.Image image) {
    final data = Float32List(3 * inputSize * inputSize);
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        final idx = y * inputSize + x;
        data[idx]                          = pixel.r / 255.0;
        data[inputSize * inputSize + idx]  = pixel.g / 255.0;
        data[2 * inputSize * inputSize + idx] = pixel.b / 255.0;
      }
    }
    return data;
  }

  /// YOLOv8/11/12 post-process — output [1, nc+4, 8400]
  List<DetectionResult> _postProcessV8(List rawOutput) {
    final numClasses = _classNames.length;
    final tensor  = rawOutput[0] as List; // [nc+4][8400]
    final numBoxes = (tensor[0] as List).length; // 8400

    final boxes    = <Rect>[];
    final scores   = <double>[];
    final classIds = <int>[];

    for (int i = 0; i < numBoxes; i++) {
      double maxProb = 0.0;
      int maxClass = 0;

      for (int c = 0; c < numClasses; c++) {
        final prob = ((tensor[4 + c] as List)[i] as num).toDouble();
        if (prob > maxProb) {
          maxProb = prob;
          maxClass = c;
        }
      }

      if (maxProb < confidenceThreshold) continue;

      final cx = ((tensor[0] as List)[i] as num).toDouble() / inputSize;
      final cy = ((tensor[1] as List)[i] as num).toDouble() / inputSize;
      final w  = ((tensor[2] as List)[i] as num).toDouble() / inputSize;
      final h  = ((tensor[3] as List)[i] as num).toDouble() / inputSize;

      boxes.add(Rect.fromLTRB(
        (cx - w / 2).clamp(0.0, 1.0),
        (cy - h / 2).clamp(0.0, 1.0),
        (cx + w / 2).clamp(0.0, 1.0),
        (cy + h / 2).clamp(0.0, 1.0),
      ));
      scores.add(maxProb);
      classIds.add(maxClass);
    }

    final kept = _nmsIndices(boxes, scores, nmsThreshold);
    return kept.map((i) {
      final classId = _classNames[classIds[i]];
      return DetectionResult(
        classId: classId,
        label: classId,
        ttsText: SignLabels.getTtsText(classId),
        confidence: scores[i],
        boundingBox: boxes[i],
        priority: SignLabels.getPriority(classId),
      );
    }).toList();
  }

  List<int> _nmsIndices(List<Rect> boxes, List<double> scores, double iouThr) {
    final indices = List.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    final kept       = <int>[];
    final suppressed = List.filled(scores.length, false);

    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (suppressed[idx]) continue;
      kept.add(idx);
      for (int j = i + 1; j < indices.length; j++) {
        final jdx = indices[j];
        if (suppressed[jdx]) continue;
        if (_iou(boxes[idx], boxes[jdx]) >= iouThr) suppressed[jdx] = true;
      }
    }
    return kept;
  }

  double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.isEmpty) return 0.0;
    final ia = inter.width * inter.height;
    final ua = a.width * a.height + b.width * b.height - ia;
    return ia / ua;
  }

  img.Image? _convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _yuv420ToRgb(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _bgra8888ToRgb(image);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  img.Image _yuv420ToRgb(CameraImage image) {
    final width  = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final result = img.Image(width: width, height: height);

    // Sadece üst %65'i dönüştür
    final maxRow = (height * roiTopFraction).toInt();

    for (int y = 0; y < maxRow; y++) {
      for (int x = 0; x < width; x++) {
        final uvIdx = uPlane.bytesPerRow * (y >> 1) + (x >> 1) * uPlane.bytesPerPixel!;
        final yVal  = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final uVal  = uPlane.bytes[uvIdx];
        final vVal  = vPlane.bytes[uvIdx];
        final r = (yVal + 1.402    * (vVal - 128)).round().clamp(0, 255);
        final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round().clamp(0, 255);
        final b = (yVal + 1.772    * (uVal - 128)).round().clamp(0, 255);
        result.setPixelRgb(x, y, r, g, b);
      }
    }
    return result;
  }

  img.Image _bgra8888ToRgb(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  bool get isInitialized => _isInitialized;
  bool get isProcessing  => _isProcessing;

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}
