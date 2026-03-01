# TrafikAsistan 🚗

Gerçek zamanlı Türk trafik levhası tanıma ve sesli uyarı sistemi. Telefonu araç içinde tripoda bağlayarak sürücülere ADAS benzeri özellikler sağlar.

---

## Proje Özeti

Mobil kamera aracılığıyla trafik levhalarını anlık olarak tespit eden, Türkçe sesli bildirim ve görsel uyarı veren bir Flutter uygulaması. YOLOv11s modeli, 80.000 görüntülük veri setiyle 33 Türk trafik levhası sınıfı üzerine eğitilmiştir.

---

## Özellikler

- **Gerçek zamanlı tespit** — ONNX Runtime ile async inference
- **33 trafik levhası sınıfı** — DUR, GIRILMEZ, hız sınırları, kasis, okul geçidi vb.
- **Türkçe sesli uyarı** — Flutter TTS ile önceliğe göre bildirim
- **Öncelik sistemi** — Kritik / Yüksek / Orta / Düşük (kırmızı/sarı/mavi renkler)
- **Kritik levha alarmı** — Titreşim + kırmızı flash + banner (DUR, GİRİLMEZ, vb.)
- **Kamera zoom kontrolü** — Uzak tabelalar için 1×–4× zoom
- **ROI tarama** — Üst %65 alanda levha taraması (yol/kaput görmezden gelme)
- **Zone göstergesi** — SOL / ORTA / SAĞ tespit konumu
- **FPS göstergesi** — Yeşil ≥8 / Sarı 4-8 / Kırmızı <4
- **Ayarlar kalıcılığı** — Güven eşiği, ses hızı, cooldown, zoom

---

## Mimari

```
trafik_asistan/
├── lib/
│   ├── main.dart                    # Uygulama giriş noktası
│   ├── models/
│   │   └── detection_result.dart    # DetectionResult, SignPriority
│   ├── screens/
│   │   ├── splash_screen.dart       # Model yükleme ekranı
│   │   ├── camera_screen.dart       # Ana kamera + overlay UI
│   │   └── settings_screen.dart     # Ayarlar ekranı
│   ├── services/
│   │   ├── detector_service.dart    # ONNX inference + YUV→RGB + NMS
│   │   ├── tts_service.dart         # FlutterTTS wrapper
│   │   └── alert_manager.dart       # Cooldown + öncelik yönetimi
│   ├── utils/
│   │   └── sign_labels.dart         # 33 sınıf → TTS metni + öncelik
│   └── widgets/
│       └── bounding_box_overlay.dart # CustomPainter bounding box
├── assets/
│   ├── models/
│   │   └── best.onnx                # YOLOv11s — 33 sınıf (37MB)
│   └── labels/
│       └── classes.txt              # Sınıf isimleri (33 satır)
└── android/
    └── app/src/main/AndroidManifest.xml
```

---

## Model Bilgisi

| Parametre | Değer |
|-----------|-------|
| Mimari | YOLOv11s |
| Format | ONNX (opset 12) |
| Giriş | 640×640 NCHW float32 |
| Çıkış | [1, 37, 8400] (4 bbox + 33 sınıf) |
| Sınıf sayısı | 33 |
| Eğitim seti | ~80.000 görüntü |
| Dosya boyutu | ~37 MB |

### Sınıf Listesi (33 adet)

`30HIZSINIRI` `50HIZSINIRI` `70HIZSINIRI` `ANAYOL` `ANAYOLTALIYOL` `CIFTYON` `DUR` `DURAK` `ENGELLIPARK` `GIRILMEZ` `ILERISAG` `ILERISOL` `ILERITEKYON` `KASIS` `KAVSAK` `KIRMIZIISIK` `OKULGECIDI` `PARK` `PARKYASAK` `SAG` `SAGADONULMEZ` `SAGATEHLIKELIVIRAJ` `SAGCAPRAZ` `SARIISIK` `SOL` `SOLADONULMEZ` `SOLATEHLIKELIVIRAJ` `TTKAPALIYOL` `UCGENTRAFIKISARETI` `UDONUSUYASAK` `YAYAGECIDI` `YESILISIK` `YOLVER`

---

## Gereksinimler

| Araç | Versiyon |
|------|---------|
| Flutter SDK | ≥ 3.3.0 |
| Dart SDK | ≥ 3.3.0 |
| Android SDK | API 21+ (Android 5.0) |
| Java | 17+ |
| Android Studio | Flamingo veya üstü |

### Flutter kurulumu yoksa

```bash
# Windows için
winget install Google.Flutter
# veya https://docs.flutter.dev/get-started/install adresinden indir
```

---

## Kurulum & Çalıştırma

### 1. Repoyu klonla

```bash
git clone https://github.com/ydmhalil/traffikasistan.git
cd traffikasistan
```

### 2. Bağımlılıkları kur

```bash
flutter pub get
```

### 3. Android cihaza bağla ve çalıştır

```bash
# Bağlı cihazları listele
flutter devices

# Release modda çalıştır (gerçek performans)
flutter run --release -d <DEVICE_ID>

# veya debug modda (geliştirme için)
flutter run -d <DEVICE_ID>
```

### 4. APK derle

```bash
# Tüm mimari için tek APK (~165 MB)
flutter build apk --release

# Sadece arm64 (Samsung/modern cihazlar için ~85 MB)
flutter build apk --release --target-platform android-arm64

# APK çıktısı:
# build/app/outputs/flutter-apk/app-release.apk
```

### 5. APK'yı yükle

```bash
flutter install --release
# veya
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Android İzinleri

`AndroidManifest.xml`'de aşağıdaki izinler tanımlıdır:
- `CAMERA` — Kamera erişimi
- `WAKE_LOCK` — Ekranı açık tut
- `VIBRATE` — Kritik uyarı titreşimi

---

## Inference Pipeline

```
CameraImage (YUV420)
    ↓ YUV → RGB dönüşümü (sadece üst %65)
    ↓ copyCrop (ROI: üst %65)
    ↓ copyResize (640×640, linear interpolation)
    ↓ NCHW Float32List [1, 3, 640, 640]
    ↓ ONNX Runtime runAsync()
    ↓ output [1, 37, 8400]
    ↓ postProcessV8 + NMS
    ↓ coordinate mapping → frame space
    ↓ zone derive (x pozisyonuna göre SOL/ORTA/SAĞ)
    ↓ DetectionResult listesi
```

---

## Bilinen Sınırlamalar & Geliştirilecek Alanlar

- [ ] **Uzak levha tespiti** — 20×20 px altındaki levhalar kaçırılıyor; SAHI veya küçük nesne odaklı model ile iyileştirilebilir
- [ ] **Gece/kötü hava koşulları** — Eğitim setinde bu koşullar az temsil edilmiş
- [ ] **YUV→RGB performansı** — Dart'ta pixel-by-pixel dönüşüm darboğaz; native kod ile 5-10x hızlanabilir
- [ ] **ARM64 APK split** — `--target-platform android-arm64` ile ~85 MB'a inebilir
- [ ] **Model iyileştirme** — Daha fazla veri veya YOLOv11n (nano) ile hız/doğruluk dengesi

---

## Geliştirme Notları

### Yeni model eklemek için
1. `assets/models/` klasörüne `.onnx` dosyasını koy
2. `pubspec.yaml`'da `assets/models/` zaten tanımlı
3. `detector_service.dart`'ta `'assets/models/best.onnx'` yolunu güncelle
4. Sınıf sayısı değiştiyse `assets/labels/classes.txt` ve `utils/sign_labels.dart`'ı güncelle

### Yeni trafik levhası sınıfı eklemek için
1. `assets/labels/classes.txt`'e sınıf adını ekle
2. `lib/utils/sign_labels.dart`'ta TTS metni ve önceliği tanımla

---

## Bağımlılıklar

```yaml
camera: ^0.12.0            # Kamera stream
onnxruntime: ^1.4.1        # ONNX inference (async)
image: ^4.8.0              # Görüntü işleme (YUV→RGB)
flutter_tts: ^4.2.5        # Türkçe sesli uyarı
shared_preferences: ^2.5.4 # Ayar kalıcılığı
wakelock_plus: ^1.4.0      # Ekranı açık tut
vibration: ^3.1.8          # Titreşim uyarısı
permission_handler: ^12.0.1 # İzin yönetimi
```

---

## Proje Geliştirme Süreci

1. YOLOv10s/v11s/v12s modelleri `.pt` formatından `.onnx`'e export edildi
2. Flutter projesi oluşturuldu; kamera, TTS, ONNX Runtime entegre edildi
3. Android v2 embedding ve izin yapısı kuruldu
4. 33 sınıf için TTS metni ve öncelik tablosu oluşturuldu
5. Bounding box overlay, kritik banner, titreşim, wakelock eklendi
6. Kamera zoom kontrolü ve ROI tarama (üst %65) eklendi
7. 3 bölgeli (SOL/ORTA/SAĞ) tarama → tek inference'a optimize edildi
8. FPS sayacı eklendi (yeşil/sarı/kırmızı renkli)
9. Ayarlar ekranı: güven eşiği, ses hızı, cooldown, zoom kalıcılığı

---

## Lisans

Bu proje akademik/bitirme projesi kapsamında geliştirilmiştir.
