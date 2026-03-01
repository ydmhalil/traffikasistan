import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final double initialConfidence;
  final int initialCooldown;
  final bool initialVoiceEnabled;
  final double initialZoom;
  final void Function(double confidence, int cooldown, bool voice, double speechRate, double zoom)
      onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.initialConfidence,
    required this.initialCooldown,
    required this.initialVoiceEnabled,
    required this.initialZoom,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _confidence;
  late int _cooldown;
  late bool _voiceEnabled;
  late double _zoom;
  double _speechRate = 0.9;

  @override
  void initState() {
    super.initState();
    _confidence = widget.initialConfidence;
    _cooldown = widget.initialCooldown;
    _voiceEnabled = widget.initialVoiceEnabled;
    _zoom = widget.initialZoom;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRate = prefs.getDouble('speech_rate') ?? 0.9;
      _zoom = prefs.getDouble('zoom') ?? widget.initialZoom;
    });
  }

  Future<void> _saveAndApply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('confidence', _confidence);
    await prefs.setInt('cooldown', _cooldown);
    await prefs.setBool('voice_enabled', _voiceEnabled);
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setDouble('zoom', _zoom);
    widget.onSettingsChanged(_confidence, _cooldown, _voiceEnabled, _speechRate, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00B4FF)),
          onPressed: () async {
            await _saveAndApply();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Güven Eşiği
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Güven Eşiği',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Minimum tespit güvenirliği',
                            style: TextStyle(
                                color: Color(0xFF8A8A9A), fontSize: 13)),
                      ],
                    ),
                    Text(
                      '${(_confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFF00B4FF),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: _sliderTheme(context),
                  child: Slider(
                    value: _confidence,
                    min: 0.3,
                    max: 0.9,
                    divisions: 12,
                    onChanged: (v) => setState(() => _confidence = v),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('30%',
                        style:
                            TextStyle(color: Color(0xFF8A8A9A), fontSize: 12)),
                    Text('90%',
                        style:
                            TextStyle(color: Color(0xFF8A8A9A), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sesli Uyarı
          _SettingsCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sesli Uyarı',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Levhaları sesle bildir',
                        style:
                            TextStyle(color: Color(0xFF8A8A9A), fontSize: 13)),
                  ],
                ),
                Switch(
                  value: _voiceEnabled,
                  onChanged: (v) => setState(() => _voiceEnabled = v),
                  activeColor: const Color(0xFF00B4FF),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ses Hızı (sadece ses açıksa)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _voiceEnabled
                ? Column(
                    children: [
                      _SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ses Hızı',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text('Sesli bildirimlerin hızı',
                                        style: TextStyle(
                                            color: Color(0xFF8A8A9A),
                                            fontSize: 13)),
                                  ],
                                ),
                                Text(
                                  _speechRate <= 0.6
                                      ? 'Yavaş'
                                      : _speechRate <= 1.0
                                          ? 'Normal'
                                          : 'Hızlı',
                                  style: const TextStyle(
                                    color: Color(0xFF00B4FF),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: _sliderTheme(context),
                              child: Slider(
                                value: _speechRate,
                                min: 0.5,
                                max: 1.5,
                                divisions: 4,
                                onChanged: (v) =>
                                    setState(() => _speechRate = v),
                              ),
                            ),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Yavaş',
                                    style: TextStyle(
                                        color: Color(0xFF8A8A9A), fontSize: 12)),
                                Text('Normal',
                                    style: TextStyle(
                                        color: Color(0xFF8A8A9A), fontSize: 12)),
                                Text('Hızlı',
                                    style: TextStyle(
                                        color: Color(0xFF8A8A9A), fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Uyarı Bekleme Süresi
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Uyarı Bekleme Süresi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Aynı levha için uyarılar arası süre',
                    style:
                        TextStyle(color: Color(0xFF8A8A9A), fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [3, 5, 10].map((sec) {
                    final isSelected = _cooldown == sec;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _cooldown = sec),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00B4FF)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00B4FF)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${sec}s',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF0A0A0F)
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kamera Zoom
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kamera Zoom',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Uzak tabelalar için yakınlaştır',
                            style: TextStyle(
                                color: Color(0xFF8A8A9A), fontSize: 13)),
                      ],
                    ),
                    Text(
                      '${_zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Color(0xFF00B4FF),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: _sliderTheme(context),
                  child: Slider(
                    value: _zoom,
                    min: 1.0,
                    max: 3.0,
                    divisions: 8,
                    onChanged: (v) => setState(() => _zoom = v),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1.0x  (Geniş)',
                        style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12)),
                    Text('3.0x  (Yakın)',
                        style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Uygulama hakkında
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hakkında',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _InfoRow(label: 'Model', value: 'YOLOv11s'),
                _InfoRow(label: 'Sınıf sayısı', value: '33'),
                _InfoRow(label: 'Veri seti', value: '80K görüntü'),
                _InfoRow(label: 'Versiyon', value: '1.0.0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: const Color(0xFF00B4FF),
      inactiveTrackColor: const Color(0xFF1A1A2E),
      thumbColor: const Color(0xFF00B4FF),
      overlayColor: const Color(0xFF00B4FF).withOpacity(0.2),
      trackHeight: 4,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A8A9A), fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
