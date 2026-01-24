# 🔄 AI SPOR ANALİZ - UYGULAMA GÜNCELLEME REHBERİ

## 📌 GÜNCELLEME YAPMANIZ GEREKTİĞİNDE

Uygulamanızda değişiklik yaptığınızda (bug fix, yeni özellik, UI güncellemesi vb.) Google Play'de güncelleme yayınlamak için bu rehberi kullanın.

---

## ⚡ HIZLI GÜNCELLEME ADIMLARI

### 1. Versiyon Numarasını Artırın
### 2. Değişiklikleri Yapın
### 3. AAB/APK Oluşturun
### 4. Google Play Console'a Yükleyin

---

## 📊 VERSİYON NUMARASI YÖNETİMİ

### pubspec.yaml Dosyası:

Şu satırı bulun:
```yaml
version: 1.0.0+1
```

### Format:
```
version: MAJÖRVERSİYON.MİNÖRVERSİYON.YAMAVERSIYONU+VERSİYONKODU
```

### Örnekler:

| Değişiklik Türü | Eski Versiyon | Yeni Versiyon | Açıklama |
|------------------|---------------|---------------|----------|
| İlk yayın | 1.0.0+1 | 1.0.0+1 | İlk versiyon |
| Bug fix | 1.0.0+1 | 1.0.1+2 | Küçük düzeltme |
| Yeni özellik (küçük) | 1.0.1+2 | 1.1.0+3 | Minör güncelleme |
| Büyük özellik | 1.1.0+3 | 2.0.0+4 | Majör güncelleme |
| Acil hotfix | 2.0.0+4 | 2.0.1+5 | Kritik düzeltme |

### Kurallar:

1. **Versiyon Kodu** (+ sonrası): **HER ZAMAN** artmalı
   - Google Play bu sayıya bakar
   - Aynı veya düşük versiyon kodu yüklenemez
   - Her güncellemede +1 artırın

2. **Majör Versiyon** (ilk sayı):
   - Büyük değişiklikler
   - API değişiklikleri
   - UI tamamen değişti
   - Örnek: 1.0.0 → 2.0.0

3. **Minör Versiyon** (ikinci sayı):
   - Yeni özellikler
   - Önemli iyileştirmeler
   - Örnek: 1.0.0 → 1.1.0

4. **Yama Versiyonu** (üçüncü sayı):
   - Bug fix
   - Küçük düzeltmeler
   - Performans iyileştirmeleri
   - Örnek: 1.0.0 → 1.0.1

---

## 🛠️ GÜNCELLEME SENARYOLARI

### Senaryo 1: Bug Fix (Hata Düzeltme)

**Durum**: Kullanıcılar bir hata bildirdi, düzelttiniz.

**Adımlar**:
1. Hatayı düzeltin
2. `pubspec.yaml` içinde:
   ```yaml
   version: 1.0.1+2  # Yama versiyonu ve kod arttı
   ```
3. Build edin:
   ```bash
   flutter build appbundle --release
   ```
4. Google Play'e yükleyin
5. Release notes:
   ```
   - Uygulama çökme sorunu düzeltildi
   - Görsel yükleme hatası giderildi
   ```

---

### Senaryo 2: Yeni Özellik Ekleme

**Durum**: Kullanıcı profili özelliği eklediniz.

**Adımlar**:
1. Yeni özelliği geliştirin
2. `pubspec.yaml` içinde:
   ```yaml
   version: 1.1.0+3  # Minör versiyon ve kod arttı
   ```
3. Build edin:
   ```bash
   flutter build appbundle --release
   ```
4. Google Play'e yükleyin
5. Release notes:
   ```
   Yeni Özellikler:
   - Kullanıcı profili sayfası
   - Analiz geçmişi görüntüleme
   - Karanlık tema desteği
   ```

---

### Senaryo 3: Büyük Güncelleme

**Durum**: Uygulamayı tamamen yeniden tasarladınız.

**Adımlar**:
1. Büyük değişiklikleri yapın
2. `pubspec.yaml` içinde:
   ```yaml
   version: 2.0.0+4  # Majör versiyon değişti
   ```
3. Build edin:
   ```bash
   flutter build appbundle --release
   ```
4. Google Play'e yükleyin
5. Release notes:
   ```
   🎉 AI Spor Analiz 2.0!
   
   - Tamamen yeni arayüz
   - 3 kat daha hızlı analiz
   - Canlı maç takibi
   - Premium abonelik seçenekleri
   ```

---

### Senaryo 4: Acil Hotfix

**Durum**: Kritik bir hata, hemen düzeltmeniz gerek.

**Adımlar**:
1. Sadece hatayı düzeltin
2. `pubspec.yaml` içinde:
   ```yaml
   version: 1.0.1+2  # Hızlıca versiyon artır
   ```
3. Hızlı test edin
4. Build edin:
   ```bash
   flutter build appbundle --release
   ```
5. Google Play Console'da **Priority update** olarak işaretleyin
6. Release notes:
   ```
   Acil Düzeltme:
   - Uygulama açılma sorunu çözüldü
   ```

---

## 📦 BUILD KOMUTLARI

### Release AAB (Google Play için):
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

**Çıktı**: `build/app/outputs/bundle/release/app-release.aab`

### Release APK (Test için):
```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Çıktı**: `build/app/outputs/flutter-apk/app-release.apk`

### Split APK (Daha küçük boyut):
```bash
flutter build apk --release --split-per-abi
```

**Çıktılar**:
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

---

## 🏪 GOOGLE PLAY CONSOLE'A YÜKLEME

### Adım 1: Console'a Giriş
https://play.google.com/console/

### Adım 2: Uygulamanızı Seçin
"AI Spor Analiz" uygulamanıza tıklayın

### Adım 3: Release Oluşturun

#### Production Release (Herkese Açık):
1. Sol menüden **Release** > **Production**
2. **Create new release** butonuna tıklayın
3. **Upload** ile `app-release.aab` dosyasını yükleyin
4. **Release name**: Otomatik dolar (1.1.0 vb.)
5. **Release notes** yazın:

**Türkçe Örnek**:
```
Bu güncellemede neler var?

Yeni Özellikler:
• Takım istatistikleri artık daha detaylı
• Karanlık tema desteği eklendi
• Analiz sonuçlarını PDF olarak kaydetme

İyileştirmeler:
• Uygulama %30 daha hızlı açılıyor
• Görsel yükleme süresi kısaltıldı
• Kullanıcı arayüzü iyileştirildi

Hata Düzeltmeleri:
• Uygulama çökme sorunu giderildi
• Kredi sayısı yanlış gösterilme hatası düzeltildi
```

6. **Review release** butonuna tıklayın
7. Tüm bilgileri kontrol edin
8. **Start rollout to Production** butonuna tıklayın

### Adım 4: İnceleme Süreci
- Google uygulamanızı inceler: **1-7 gün**
- Onaylanınca otomatik yayınlanır
- Email bildirimi alırsınız

---

## 🧪 TEST ETME (Production Öncesi)

### Internal Testing (Önerilir):

1. **Release** > **Testing** > **Internal testing**
2. **Create new release**
3. AAB yükleyin
4. **Start rollout to Internal testing**
5. Test kullanıcıları uygulamayı test eder
6. Sorun yoksa Production'a promote edin

**Avantajlar**:
- Hızlı onay (birkaç dakika)
- Güvenli test ortamı
- Gerçek kullanıcılarla test

---

## ⚠️ YAYGIN HATALAR VE ÇÖZÜMLERI

### Hata 1: "Upload failed: Version code already exists"

**Sebep**: Versiyon kodunu artırmadınız.

**Çözüm**:
```yaml
# pubspec.yaml
version: 1.0.1+3  # + sonrasını artırın
```

---

### Hata 2: "You need to use a different package name"

**Sebep**: Application ID değişti.

**Çözüm**: 
Application ID'yi **HİÇBİR ZAMAN** değiştirmeyin! İlk yayınladığınız ID'yi kullanmaya devam edin.

---

### Hata 3: "APK signature verification failed"

**Sebep**: Keystore değişti veya şifre yanlış.

**Çözüm**:
- İlk yayınlarda kullandığınız keystore'u kullanın
- `key.properties` dosyasını kontrol edin
- Şifrelerin doğru olduğundan emin olun

---

### Hata 4: "This release will not be available to any users"

**Sebep**: Rollout yüzdesi 0% veya targeting ayarı yanlış.

**Çözüm**:
- **Rollout percentage**: 100% yapın
- **Countries**: "All countries" seçin
- Veya belirli ülkeleri seçin

---

## 🔄 STAGED ROLLOUT (Aşamalı Yayın)

Büyük güncellemelerde önce küçük bir kullanıcı grubuna yayınlayın.

### Nasıl Yapılır:

1. Release oluştururken **Rollout percentage** ayarını kullanın
2. Örnek rollout planı:

| Gün | Rollout | Kullanıcılar | Amaç |
|-----|---------|--------------|------|
| 1 | 10% | 100 kişi | İlk feedback |
| 3 | 25% | 250 kişi | Kararlılık testi |
| 5 | 50% | 500 kişi | Geniş test |
| 7 | 100% | Herkes | Tam yayın |

3. Her aşamada:
   - Crash raporlarını izleyin
   - Kullanıcı yorumlarını okuyun
   - Sorun yoksa sonraki aşamaya geçin

---

## 📈 GÜNCELLEME SONRASI TAKİP

### 1. İlk 24 Saat:
- [ ] Crash Free Users oranı > %99
- [ ] ANR (App Not Responding) oranı < %1
- [ ] Yıldız puanı düşmedi mi?
- [ ] Yeni yorumları yanıtlayın

### 2. İlk 7 Gün:
- [ ] İndirme sayısını kontrol edin
- [ ] Retention rate (elde tutma) stabil mi?
- [ ] Güncelleme oranı > %70 mı?

### 3. İlk 30 Gün:
- [ ] Yeni özelliklerin kullanım oranı
- [ ] Gelir değişimi (IAP varsa)
- [ ] Kullanıcı geri bildirimleri

---

## 🚨 ACİL DURUMLAR

### Güncelleme Kritik Hata İçeriyorsa:

1. **Derhal Durdur**:
   - Google Play Console > Production
   - **Halt rollout** butonuna tıklayın

2. **Hızlı Fix**:
   - Hatayı düzeltin
   - Versiyon kodunu artırın
   - Acil AAB oluşturun

3. **Hotfix Yayınlayın**:
   - Yeni release oluşturun
   - **Priority update** olarak işaretleyin
   - Release notes: "Kritik hata düzeltmesi"

4. **Kullanıcıları Bilgilendirin**:
   - In-app mesaj gösterin
   - Sosyal medyada duyurun
   - Email gönderin (varsa)

---

## 📝 RELEASE NOTES ŞABLONLARİ

### Bug Fix Güncellemesi:
```
Hata Düzeltmeleri:
• Uygulama açılma sorunu giderildi
• Analiz sonuçları doğru gösterilmiyor hatası düzeltildi
• Kredi satın alma sorunu çözüldü
• Performans iyileştirmeleri
```

### Yeni Özellik:
```
🎉 Yeni Özellikler:
• Karanlık tema desteği
• Favori analizleri kaydetme
• Analiz geçmişi görüntüleme
• Bildirim ayarları

İyileştirmeler:
• Daha hızlı analiz sonuçları
• İyileştirilmiş kullanıcı arayüzü
• Daha az pil tüketimi
```

### Majör Güncelleme:
```
🚀 AI Spor Analiz 2.0 Burada!

Tamamen Yenilendi:
✨ Yepyeni modern tasarım
⚡ 3 kat daha hızlı analiz
📊 Detaylı istatistikler
🔔 Canlı maç bildirimleri
👑 Premium abonelik seçenekleri

Bu versiyonda 50'den fazla iyileştirme ve yenilik var!
```

---

## 💾 BACKUP STRATEJİSİ

### Keystore Yedeği:
- ✅ Google Drive'a yükleyin
- ✅ Şifreli USB'ye kopyalayın
- ✅ Güvenli bir bulut servisine yükleyin
- ✅ Birden fazla yedek tutun

### Versiyon Kontrolü:
- ✅ Git kullanın
- ✅ Her release için tag oluşturun:
  ```bash
  git tag -a v1.0.0 -m "Release 1.0.0"
  git push origin v1.0.0
  ```

### AAB/APK Arşivi:
- Eski versiyonların AAB/APK dosyalarını saklayın
- Sorun olursa geri dönebilirsiniz

---

## 🔐 GÜVENLİK KONTROL LİSTESİ

Güncelleme yapmadan önce:

- [ ] API anahtarları güvenli mi?
- [ ] Hassas bilgiler kodda yok mu?
- [ ] ProGuard/R8 aktif mi? (kod karıştırma)
- [ ] HTTPS kullanılıyor mu?
- [ ] Kullanıcı verileri şifreli mi?

---

## 📞 YARDIM VE DESTEK

### Resmi Kaynaklar:
- Flutter Docs: https://docs.flutter.dev
- Google Play Console Help: https://support.google.com/googleplay/android-developer
- Flutter Community: https://flutter.dev/community

### Topluluk:
- Stack Overflow: [flutter] etiketi
- Reddit: r/FlutterDev
- Discord: Flutter Dev Community

---

## 📊 GÜNCELLEME BAŞARI METRİKLERİ

### İyi Bir Güncelleme:
- ✅ Crash-free users: > %99
- ✅ ANR rate: < %1
- ✅ Güncelleme oranı: > %70 (7 gün içinde)
- ✅ Yıldız puanı: Sabit veya arttı
- ✅ Retention rate: Sabit veya arttı

### Sorunlu Güncelleme:
- ❌ Crash-free users: < %97
- ❌ ANR rate: > %2
- ❌ Olumsuz yorumlar arttı
- ❌ Kaldırma (uninstall) oranı arttı

---

## 🎯 ÖZET: GÜNCELLEME KONTROL LİSTESİ

### Yayınlamadan Önce:
- [ ] Versiyon numarası artırıldı
- [ ] Değişiklikler test edildi
- [ ] Keystore aynı ve şifre doğru
- [ ] Release notes hazırlandı
- [ ] AAB başarıyla oluşturuldu
- [ ] Internal testing yapıldı (önerilir)

### Yayınladıktan Sonra:
- [ ] İlk 24 saatte crash raporları izlendi
- [ ] Kullanıcı yorumları okundu ve yanıtlandı
- [ ] Güncelleme oranı takip edildi
- [ ] Yeni versiyon AAB/APK arşivlendi

---

## 🏆 PRO İPUÇLARI

1. **Düzenli Güncelleme**: Ayda 1-2 kez güncelleme yapın (kullanıcılar aktif gelişim gördüğünde memnun olur)

2. **Geri Bildirime Kulak Verin**: Play Store yorumlarını okuyun, kullanıcı isteklerini değerlendirin

3. **A/B Testing**: Firebase Remote Config ile yeni özellikleri test edin

4. **Changelog Tutun**: Her güncellemeyi kaydedin (CHANGELOG.md dosyası)

5. **Beta Tester Grubu**: Sadık kullanıcılardan beta test grubu oluşturun

---

**Başarılı güncellemeler dileriz! 🚀**

*Son güncelleme: Ocak 2025*
Java versiyon sorunu! Android Gradle plugin Java 17 gerektiriyor ama sizde Java 11 var. Hızlıca çözelim! 💪

## 🔧 ÇÖZÜM: JAVA 17 YÜKLEME

### ✅ ADIM 1: JAVA 17 İNDİRİN

İki seçenek var:

#### Seçenek A: Oracle JDK 17 (Kolay)
1. Şu linke gidin: https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html
2. **Windows x64 Installer** indirin (örn: `jdk-17_windows-x64_bin.exe`)
3. İndirdiğiniz dosyayı çalıştırın
4. Kurulum sırasında varsayılan ayarlarla devam edin
5. Kurulum konumunu not alın (genellikle: `C:\Program Files\Java\jdk-17`)

#### Seçenek B: OpenJDK 17 (Ücretsiz)
1. Şu linke gidin: https://adoptium.net/temurin/releases/
2. **Version: 17** seçin
3. **Operating System: Windows**
4. **Architecture: x64**
5. **Package Type: JDK**
6. `.msi` installer'ı indirin ve kurun

---

### ✅ ADIM 2: FLUTTER'A JAVA 17'Yİ GÖSTERİN

Kurulum bittikten sonra PowerShell'de:

```powershell
flutter config --jdk-dir="C:\Program Files\Java\jdk-17"
```

⚠️ **Not**: Kurulum konumu farklıysa o konumu yazın!

---

### ✅ ADIM 3: KONTROL EDİN

```powershell
flutter doctor --verbose
```

Java versiyonunu göreceksiniz. Java 17 olarak görünmeli.

---

### ✅ ADIM 4: YENİDEN DENEYİN

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

---

## ⚡ HIZLI ÇÖZÜM: ENVIRONMENT VARIABLE AYARLAMA

Java 17'yi yükledikten sonra hala sorun olursa:

### 1. System Environment Variables Açın:
- **Windows Arama** → "Environment Variables" yazın
- **"Edit the system environment variables"** açın
- **Environment Variables** butonuna tıklayın

### 2. JAVA_HOME Ekleyin/Düzenleyin:
- **System variables** altında **JAVA_HOME** var mı kontrol edin
- Varsa **Edit** → Değeri: `C:\Program Files\Java\jdk-17`
- Yoksa **New** → Variable name: `JAVA_HOME`, Value: `C:\Program Files\Java\jdk-17`

### 3. Path Güncelleyin:
- **System variables** altında **Path** seçin → **Edit**
- Yeni satır ekleyin: `%JAVA_HOME%\bin`
- **OK** ile kaydedin

### 4. PowerShell'i Kapatıp Yeniden Açın

### 5. Kontrol Edin:
```powershell
java -version
```

**Beklenen çıktı**:
```
java version "17.0.x"
```

---

## 🎯 ÖZET

**Sorun**: Android Gradle plugin Java 17 gerektiriyor, sizde Java 11 var  
**Çözüm**: Java 17 yükleyin ve Flutter'a gösterin

**Komutlar (sırasıyla)**:
```powershell
# 1. Java 17 yükledikten sonra:
flutter config --jdk-dir="C:\Program Files\Java\jdk-17"

# 2. Kontrol edin:
flutter doctor --verbose

# 3. Build edin:
flutter clean
flutter pub get
flutter build apk --release
```

Java 17 yükledikten sonra tekrar deneyin! 🚀

Sorun devam ederse çıktıyı paylaşın, beraber bakalım! 👍