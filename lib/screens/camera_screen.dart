import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/detection_result.dart';
import '../services/detector_service.dart';
import '../services/tts_service.dart';
import '../services/alert_manager.dart';
import '../widgets/bounding_box_overlay.dart';
import 'settings_screen.dart';

class CameraScreen extends StatefulWidget {
  final DetectorService detector;
  final TtsService tts;

  const CameraScreen({
    super.key,
    required this.detector,
    required this.tts,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<DetectionResult> _detections = [];
  DetectionResult? _lastCritical;
  bool _showCriticalFlash = false;
  bool _isInitialized = false;
  late AlertManager _alertManager;

  // Zoom
  double _currentZoom = 1.5;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;

  // Aktif tarama bölgeleri (son tespite göre vurgulanır)
  Set<ScanZone> _activeZones = {};

  // FPS sayacı
  double _fps = 0;
  int _fpsFrameCount = 0;
  DateTime _fpsLastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alertManager = AlertManager(tts: widget.tts);
    _initCamera();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high, // 1080p — uzak tabelalar için daha iyi çözünürlük
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    // Zoom sınırlarını al ve varsayılan zoom uygula
    _minZoom = await _cameraController!.getMinZoomLevel();
    _maxZoom = await _cameraController!.getMaxZoomLevel();
    _currentZoom = (_currentZoom).clamp(_minZoom, _maxZoom);
    await _cameraController!.setZoomLevel(_currentZoom);

    setState(() => _isInitialized = true);
    _cameraController!.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) async {
    if (!widget.detector.isInitialized) return;

    final detections = await widget.detector.detect(image);
    if (!mounted) return;

    // FPS hesapla (her 500ms'de güncelle)
    _fpsFrameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_fpsLastTime).inMilliseconds;
    if (elapsed >= 500) {
      final newFps = (_fpsFrameCount * 1000 / elapsed);
      _fpsFrameCount = 0;
      _fpsLastTime = now;
      setState(() {
        _fps = newFps;
        _detections = detections;
        _activeZones = detections.map((d) => d.scanZone).whereType<ScanZone>().toSet();
      });
    } else {
      setState(() {
        _detections = detections;
        _activeZones = detections.map((d) => d.scanZone).whereType<ScanZone>().toSet();
      });
    }

    if (detections.isNotEmpty) {
      final best = _alertManager.pickHighestPriority(detections);
      if (best != null) {
        await _alertManager.handle(best);
        if (best.isCritical) _triggerCriticalAlert(best);
      }
    }
  }

  void _triggerCriticalAlert(DetectionResult det) async {
    setState(() {
      _lastCritical = det;
      _showCriticalFlash = true;
    });

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) Vibration.vibrate(pattern: [0, 200, 100, 200]);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _showCriticalFlash = false);
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clamped);
    await _cameraController!.setZoomLevel(clamped);
  }

  Future<void> _openSettings() async {
    _cameraController?.stopImageStream();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initialConfidence: widget.detector.confidenceThreshold,
          initialCooldown: _alertManager.cooldownSeconds,
          initialVoiceEnabled: _alertManager.voiceEnabled,
          initialZoom: _currentZoom,
          onSettingsChanged: (conf, cooldown, voice, speechRate, zoom) {
            widget.detector.confidenceThreshold = conf;
            _alertManager.cooldownSeconds = cooldown;
            _alertManager.voiceEnabled = voice;
            widget.tts.setSpeechRate(speechRate);
            _setZoom(zoom);
          },
        ),
      ),
    );
    if (mounted && _cameraController != null) {
      _cameraController!.startImageStream(_onFrame);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    widget.detector.dispose();
    widget.tts.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Kamera önizlemesi
          if (_isInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF00B4FF))),

          // 2. Tarama bölgesi kılavuzu (üst %65)
          if (_isInitialized)
            _ScanZoneGuide(activeZones: _activeZones),

          // 3. Bounding box overlay
          if (_isInitialized)
            BoundingBoxOverlay(
              detections: _detections,
              previewSize: _cameraController != null
                  ? Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    )
                  : Size.zero,
            ),

          // 4. Kritik flash border
          if (_showCriticalFlash)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF3B3B), width: 6),
                ),
              ),
            ),

          // 5. Kritik uyarı banner
          if (_showCriticalFlash && _lastCritical != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _AlertBanner(detection: _lastCritical!),
            ),

          // 6. Zoom kontrolü (sağ kenar)
          Positioned(
            right: 12,
            top: 0,
            bottom: 80,
            child: _ZoomControl(
              current: _currentZoom,
              min: _minZoom,
              max: _maxZoom,
              onChanged: _setZoom,
            ),
          ),

          // 7. Alt durum çubuğu
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(
              detections: _detections,
              activeZones: _activeZones,
              zoomLevel: _currentZoom,
              fps: _fps,
              onSettingsTap: _openSettings,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarama bölgesi kılavuzu ────────────────────────────────────────────────

class _ScanZoneGuide extends StatelessWidget {
  final Set<ScanZone> activeZones;
  const _ScanZoneGuide({required this.activeZones});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final w = constraints.maxWidth;
      final roiH = h * DetectorService.roiTopFraction;
      final zoneW = w / 3;

      return Stack(
        children: [
          // Alt bölge (taranmayan alan) — hafif karartma
          Positioned(
            top: roiH,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          // ROI sınır çizgisi
          Positioned(
            top: roiH - 1,
            left: 0,
            right: 0,
            child: Container(
              height: 1.5,
              color: const Color(0xFF00B4FF).withOpacity(0.5),
            ),
          ),

          // Sol zone
          Positioned(
            top: 0,
            left: 0,
            width: zoneW,
            height: roiH,
            child: _ZoneBox(zone: ScanZone.left, isActive: activeZones.contains(ScanZone.left)),
          ),

          // Orta zone
          Positioned(
            top: 0,
            left: zoneW,
            width: zoneW,
            height: roiH,
            child: _ZoneBox(zone: ScanZone.center, isActive: activeZones.contains(ScanZone.center)),
          ),

          // Sağ zone
          Positioned(
            top: 0,
            left: zoneW * 2,
            width: zoneW,
            height: roiH,
            child: _ZoneBox(zone: ScanZone.right, isActive: activeZones.contains(ScanZone.right)),
          ),

          // "TARAMA BÖLGESİ" etiketi
          Positioned(
            top: roiH + 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TARAMA ALANI ↑',
                  style: TextStyle(
                    color: Color(0xFF00B4FF),
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _ZoneBox extends StatelessWidget {
  final ScanZone zone;
  final bool isActive;
  const _ZoneBox({required this.zone, required this.isActive});

  String get label => zone == ScanZone.left ? 'SOL' : zone == ScanZone.center ? 'ORTA' : 'SAĞ';

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF00B4FF) : Colors.white;
    final opacity = isActive ? 0.25 : 0.05;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        border: Border(
          left: zone != ScanZone.left
              ? BorderSide(color: color.withOpacity(0.3), width: 0.5)
              : BorderSide.none,
          right: zone != ScanZone.right
              ? BorderSide(color: color.withOpacity(0.3), width: 0.5)
              : BorderSide.none,
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Zoom kontrolü ──────────────────────────────────────────────────────────

class _ZoomControl extends StatelessWidget {
  final double current;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _ZoomControl({
    required this.current,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Zoom artır
        _ZoomButton(
          icon: Icons.add,
          onTap: () => onChanged((current + 0.25).clamp(min, max)),
        ),
        const SizedBox(height: 8),

        // Zoom seviyesi göstergesi
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${current.toStringAsFixed(1)}x',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF00B4FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Zoom azalt
        _ZoomButton(
          icon: Icons.remove,
          onTap: () => onChanged((current - 0.25).clamp(min, max)),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00B4FF).withOpacity(0.4)),
        ),
        child: Icon(icon, color: const Color(0xFF00B4FF), size: 20),
      ),
    );
  }
}

// ─── Kritik banner ──────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final DetectionResult detection;
  const _AlertBanner({required this.detection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: detection.borderColor.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: detection.borderColor, width: 2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detection.ttsText.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '⚠ Tespit Edildi  •  ${detection.zoneLabel}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alt durum çubuğu ───────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final List<DetectionResult> detections;
  final Set<ScanZone> activeZones;
  final double zoomLevel;
  final double fps;
  final VoidCallback onSettingsTap;

  const _BottomBar({
    required this.detections,
    required this.activeZones,
    required this.zoomLevel,
    required this.fps,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = detections.isNotEmpty;
    final best = isActive ? detections.first : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.95),
        border: const Border(top: BorderSide(color: Color(0x3300B4FF))),
      ),
      child: Row(
        children: [
          // Durum noktası
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF00B4FF) : const Color(0xFFFFD600),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? const Color(0xFF00B4FF) : const Color(0xFFFFD600))
                      .withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isActive ? 'AKTİF' : 'TARANIYOR...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),

          // Son tespit + zone
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (best != null) ...[
                  Text(
                    best.ttsText.toUpperCase(),
                    style: TextStyle(
                      color: best.borderColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    best.zoneLabel,
                    style: const TextStyle(
                      color: Color(0xFF8A8A9A),
                      fontSize: 11,
                    ),
                  ),
                ] else
                  const Text('—', style: TextStyle(color: Colors.white54, fontSize: 18)),
              ],
            ),
          ),

          // FPS + Zoom göstergesi
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${fps.toStringAsFixed(1)} ',
                    style: TextStyle(
                      color: fps >= 8
                          ? const Color(0xFF00FF88)
                          : fps >= 4
                              ? const Color(0xFFFFD600)
                              : const Color(0xFFFF3B3B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'FPS',
                    style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 10),
                  ),
                ],
              ),
              Text(
                '${zoomLevel.toStringAsFixed(1)}x',
                style: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Ayarlar
          GestureDetector(
            onTap: onSettingsTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B4FF).withOpacity(0.15),
                border: Border.all(color: const Color(0xFF00B4FF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.settings_outlined, color: Color(0xFF00B4FF), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
