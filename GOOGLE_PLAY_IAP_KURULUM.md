# 🛒 Google Play Uygulama İçi Satın Alma Kurulumu

## ✅ KOD HAZIR - GOOGLE PLAY CONSOLE KURULUMU GEREKİYOR

Uygulama içi satın alma (In-App Purchase) kodu tamamen hazır ve çalışır durumda. Ancak Google Play Console'da ürün tanımlamalarını yapmanız gerekiyor.

---

## 📦 ÜRÜN LİSTESİ

### 💰 Kredi Paketleri (Consumable - Tüketilebilir)

| Product ID | Kredi Miktarı | Önerilen Fiyat | Açıklama |
|------------|---------------|----------------|----------|
| `credits_10` | 10 Kredi | ₺19.99 | Küçük kredi paketi |
| `credits_25` | 25 Kredi | ₺44.99 | Orta kredi paketi |
| `credits_50` | 50 Kredi | ₺79.99 | Büyük kredi paketi |
| `credits_100` | 100 Kredi | ₺139.99 | Ekstra kredi paketi |

### 👑 Premium Abonelikler (Subscription - Abonelik)

| Product ID | Süre | Önerilen Fiyat | Açıklama |
|------------|------|----------------|----------|
| `premium_monthly` | 30 Gün | ₺49.99/ay | Aylık premium abonelik |
| `premium_yearly` | 365 Gün | ₺449.99/yıl | Yıllık premium abonelik (2 ay bedava) |

---

## 🚀 GOOGLE PLAY CONSOLE KURULUM ADIMLARI

### Adım 1: Google Play Console'a Giriş

1. https://play.google.com/console/ adresine gidin
2. Uygulamanızı seçin
3. Sol menüden **"Monetize" > "In-app products"** (Uygulama içi ürünler) seçin

### Adım 2: Kredi Paketlerini Oluşturun (Consumable Products)

Her kredi paketi için:

1. **"Create product"** (Ürün oluştur) butonuna tıklayın
2. **Product type:** "Consumable" (Tüketilebilir) seçin

#### 📦 10 Kredi Paketi
```
Product ID: credits_10
Name: 10 Kredi
Description: 10 analiz kredisi. Her analiz için 1 kredi harcanır.
Price: ₺19.99 (veya istediğiniz fiyat)
```

#### 📦 25 Kredi Paketi
```
Product ID: credits_25
Name: 25 Kredi
Description: 25 analiz kredisi. Orta boy kredi paketi.
Price: ₺44.99 (veya istediğiniz fiyat)
```

#### 📦 50 Kredi Paketi
```
Product ID: credits_50
Name: 50 Kredi
Description: 50 analiz kredisi. Popüler kredi paketi.
Price: ₺79.99 (veya istediğiniz fiyat)
```

#### 📦 100 Kredi Paketi
```
Product ID: credits_100
Name: 100 Kredi
Description: 100 analiz kredisi. En büyük kredi paketi.
Price: ₺139.99 (veya istediğiniz fiyat)
```

### Adım 3: Premium Abonelikleri Oluşturun (Subscriptions)

1. Sol menüden **"Monetize" > "Subscriptions"** seçin
2. **"Create subscription"** butonuna tıklayın

#### 👑 Aylık Premium
```
Subscription ID: premium_monthly
Name: Premium Aylık
Description: Sınırsız analiz - Aylık abonelik
Base plan: Monthly (Aylık)
Price: ₺49.99/ay
Billing period: 1 Month (1 Ay)
Free trial: İsteğe bağlı (örn: 7 gün)
Grace period: 3 days (Önerilen)
```

#### 👑 Yıllık Premium
```
Subscription ID: premium_yearly
Name: Premium Yıllık
Description: Sınırsız analiz - Yıllık abonelik (2 ay bedava)
Base plan: Yearly (Yıllık)
Price: ₺449.99/yıl
Billing period: 1 Year (1 Yıl)
Free trial: İsteğe bağlı (örn: 7 gün)
Grace period: 3 days (Önerilen)
```

### Adım 4: Ürünleri Aktif Edin

Her ürün için:
1. Ürün detay sayfasında **"Activate"** (Etkinleştir) butonuna tıklayın
2. Tüm gerekli bilgilerin doldurulduğundan emin olun
3. Status: **"Active"** (Aktif) olmalı

### Adım 5: Uygulamayı Test Edin

#### Test Modu (Internal/Closed Testing)

1. **Internal testing** veya **Closed testing** track'ine APK/AAB yükleyin
2. Test kullanıcıları ekleyin:
   - Play Console > **"Release" > "Testing" > "Testers"**
   - Gmail adreslerini ekleyin
3. Test cihazınızda:
   - Test track'ındaki uygulamayı yükleyin
   - Satın alma işlemlerini test edin
   - **Test kartları gerçek ödeme yapmaz!**

#### Test Kartları

Google Play test kartları ile ödeme yapmadan test edebilirsiniz:
- Test kullanıcısı olarak eklenen Gmail hesapları otomatik test modunda
- Gerçek para çekilmez
- Tüm satın almalar başarılı görünür

---

## 🔍 DOĞRULAMA

Uygulamanızı çalıştırın ve şunları kontrol edin:

### ✅ Kontrol Listesi:

- [ ] Uygulamada "Abonelik" sayfası açılıyor
- [ ] 4 kredi paketi görünüyor (10, 25, 50, 100)
- [ ] 2 premium abonelik seçeneği görünüyor (Aylık, Yıllık)
- [ ] Fiyatlar doğru gösteriliyor
- [ ] Satın alma butonu çalışıyor
- [ ] Test satın alma başarılı oluyor
- [ ] Krediler hesaba ekleniyor
- [ ] Premium aktif oluyor

---

## 🛠️ TEKNİK DETAYLAR

### Android Manifest
✅ `com.android.vending.BILLING` izni eklendi

### Kullanılan Paketler
```yaml
in_app_purchase: ^3.2.0
in_app_purchase_android: ^0.3.0+1
```

### Product ID'ler (iap_service.dart)
```dart
// Kredi paketleri
credits_10      // 10 kredi
credits_25      // 25 kredi
credits_50      // 50 kredi
credits_100     // 100 kredi

// Premium abonelikler
premium_monthly  // Aylık
premium_yearly   // Yıllık
```

### Kod Konumu
- **IAP Servisi:** `/app/lib/services/iap_service.dart`
- **Abonelik Ekranı:** `/app/lib/screens/subscription/subscription_screen.dart`
- **Auth Provider:** `/app/lib/providers/auth_provider.dart`

---

## ⚠️ ÖNEMLİ NOTLAR

### 1. Production'a Çıkmadan Önce
- [ ] Tüm product ID'ler Google Play Console'da tanımlı olmalı
- [ ] Status: "Active" (Aktif) olmalı
- [ ] Fiyatlar onaylanmış olmalı
- [ ] Test edilmiş olmalı

### 2. İlk Kez Yayınlama
- İlk APK/AAB yüklendikten sonra Google Play'in ürünleri onaylaması 24-48 saat sürebilir
- Bu süre zarfında ürünler "Not found" hatası verebilir
- Sabırlı olun, Google onayladıktan sonra çalışacaktır

### 3. Gizlilik Politikası
Uygulama içi satın alma kullanan uygulamalar için:
- Gizlilik politikası zorunlu
- İptal ve iade politikası eklenmeli
- Kullanıcı sözleşmesinde satın alma koşulları belirtilmeli

### 4. Vergi ve Gelir
- Google Play %15-30 komisyon alır
- Fiyatlandırmada bunu göz önünde bulundurun
- Vergi kesintileri ülkeye göre değişir

---

## 🧪 TEST SENARYOLARI

### Kredi Paketi Testi
1. Kullanıcı giriş yapsın
2. "Abonelik" sayfasına gitsin
3. "10 Kredi" paketine tıklasın
4. Satın alma tamamlansın
5. Kredi sayısı 10 artsın ✅

### Premium Abonelik Testi
1. Kullanıcı giriş yapsın
2. "Premium Aylık" seçsin
3. Satın alma tamamlansın
4. Premium aktif olsun
5. Sınırsız analiz yapabilsin ✅

### Geri Yükleme Testi
1. Premium satın alınsın
2. Uygulama silinsin
3. Tekrar yüklensin
4. Giriş yapılsın
5. "Satın Almaları Geri Yükle" butonuna tıklansın
6. Premium tekrar aktif olsun ✅

---

## 📞 DESTEK

Sorun yaşarsanız:
- **E-posta:** bilwininc@gmail.com
- **Google Play Console Dokümanları:** https://support.google.com/googleplay/android-developer

---

## 📋 ÖZET

✅ **Kod tarafı HAZIR** - Hiçbir kod değişikliği gerekmez
⏳ **Google Play Console'da ürün tanımlamaları yapılmalı**
🧪 **Internal testing ile test edilmeli**
🚀 **Production'a yüklenebilir**

Tüm adımları takip ettikten sonra uygulama içi satın alma sisteminiz Google Play'de çalışacaktır!
