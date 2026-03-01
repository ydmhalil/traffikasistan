import 'package:flutter/material.dart';
import '../services/detector_service.dart';
import '../services/tts_service.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _statusText = 'Başlatılıyor...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _loadApp();
  }

  Future<void> _loadApp() async {
    _progressController.forward();

    try {
      // TTS başlat
      setState(() => _statusText = 'Ses sistemi hazırlanıyor...');
      final tts = TtsService();
      await tts.initialize();

      // Model yükle
      setState(() => _statusText = 'YOLO modeli yükleniyor...');
      final detector = DetectorService();
      await detector.initialize();

      setState(() => _statusText = 'Hazır!');
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              CameraScreen(detector: detector, tts: tts),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusText = 'Hata: Model yüklenemedi.\n${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // İkon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00B4FF),
                    width: 2,
                  ),
                  color: const Color(0xFF1A1A2E),
                ),
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 56,
                  color: Color(0xFF00B4FF),
                ),
              ),
              const SizedBox(height: 32),

              // Uygulama adı
              const Text(
                'TrafikAsistan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Levhaları kaçırma',
                style: TextStyle(
                  color: Color(0xFF8A8A9A),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 48),

              // Progress bar
              if (!_hasError)
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (_, __) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          backgroundColor: const Color(0xFF1A1A2E),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00B4FF),
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: Color(0xFF8A8A9A),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // Hata mesajı
              if (_hasError)
                Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF3B3B), size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Color(0xFFFF3B3B),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4FF),
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
