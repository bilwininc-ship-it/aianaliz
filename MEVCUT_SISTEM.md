# 📱 AI SPOR PRO - MEVCUT SİSTEM DOKÜMANTASYONU

**Uygulama Adı:** AI Spor Pro (ai_spor_pro)  
**Platform:** Flutter (Dart) - Android  
**Durum:** Google Play Store'da YAYINDA - 1000+ Aktif Kullanıcı  
**Versiyon:** 23.0.23+24  

---

## 🎯 UYGULAMA AMACI

AI Spor Pro, kullanıcıların hazırladıkları spor bültenlerini (futbol kuponları) yapay zeka destekli analiz ederek, bahis tahminlerinin doğruluğunu artırmayı amaçlayan bir mobil uygulamadır.

**Ana İşlev:**
- Kullanıcı bülten fotoğrafı yükler
- AI görüntüden maç bilgilerini çıkarır
- Her maç için detaylı istatistiksel analiz yapılır
- 7 farklı bahis türü için tahmin verilir
- Kullanıcıya risk analizi ve öneri sunulur

---

## 🏗️ TEKNİK ALTYAPI

### Backend Stack
```yaml
Veritabanı: Firebase Realtime Database
Auth: Firebase Authentication (Email/Password)
Cloud Functions: Firebase Functions v2
Storage: Yok (görsel kaydedilmiyor, sadece analiz için kullanılıyor)
Remote Config: Firebase Remote Config (API keys için)
```

### AI & API Entegrasyonları
```yaml
Gemini AI: v2.5-flash (Görüntü analizi)
Football API: v3.football.api-sports.io (Maç istatistikleri)
Google Play IAP: In-app purchase (Kredi ve premium paketleri)
```

### Frontend Stack
```yaml
Framework: Flutter 3.0+
State Management: Provider
Routing: go_router
UI Components: Material Design 3
```

---

## 📂 PROJE YAPISI

```
/app/
├── lib/
│   ├── core/
│   │   ├── routes/
│   │   │   └── app_router.dart          # Routing yapılandırması
│   │   └── theme/
│   │       └── app_theme.dart            # Tema ayarları
│   │
│   ├── models/
│   │   ├── user_model.dart               # Kullanıcı veri modeli
│   │   ├── bulletin_model.dart           # Bülten veri modeli
│   │   ├── match_pool_model.dart         # Maç havuzu modeli
│   │   └── credit_transaction_model.dart # Kredi işlem modeli
│   │
│   ├── providers/
│   │   ├── auth_provider.dart            # Kimlik doğrulama state
│   │   └── bulletin_provider.dart        # Bülten state
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart         # Giriş ekranı
│   │   │   └── register_screen.dart      # Kayıt ekranı
│   │   ├── home/
│   │   │   └── home_screen.dart          # Ana ekran
│   │   ├── upload/
│   │   │   └── upload_screen.dart        # Bülten yükleme
│   │   ├── analysis/
│   │   │   └── analysis_screen.dart      # Analiz sonuçları
│   │   ├── history/
│   │   │   └── history_screen.dart       # Geçmiş analizler
│   │   ├── subscription/
│   │   │   └── subscription_screen.dart  # Kredi/premium satın alma
│   │   └── profile/
│   │       ├── profile_screen.dart       # Profil
│   │       ├── account_settings_screen.dart
│   │       ├── credit_history_screen.dart
│   │       └── notification_settings_screen.dart
│   │
│   ├── services/
│   │   ├── analysis_service.dart         # ⭐ Ana analiz motoru
│   │   ├── gemini_service.dart           # Gemini AI entegrasyonu
│   │   ├── football_api_service.dart     # Football API entegrasyonu
│   │   ├── match_pool_service.dart       # Maç havuzu yönetimi
│   │   ├── user_service.dart             # Kullanıcı işlemleri
│   │   ├── iap_service.dart              # Google Play satın alma
│   │   ├── remote_config_service.dart    # Remote Config
│   │   └── app_startup_service.dart      # Uygulama başlatma
│   │
│   ├── widgets/
│   │   ├── common/
│   │   │   └── credits_widget.dart       # Kredi gösterimi
│   │   └── pool_status_widget.dart       # Havuz durumu
│   │
│   ├── firebase_options.dart             # Firebase config
│   └── main.dart                         # ⭐ Uygulama giriş noktası
│
├── functions/
│   ├── index.js                          # ⭐ Cloud Functions
│   └── package.json                      # Node.js bağımlılıkları
│
├── android/                              # Android native config
├── ios/                                  # iOS native config (kullanılmıyor)
└── pubspec.yaml                          # ⭐ Flutter bağımlılıkları
```

---

## 🔄 KULLANICI AKIŞI (USER FLOW)

### 1. Kayıt ve Giriş
```
┌─────────────────┐
│  Uygulama Açılış│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Login Screen    │
│ - Email/Şifre   │
│ - Kayıt Ol Link │
└────────┬────────┘
         │
         ├──[Yeni Kullanıcı]──► Register Screen
         │                      │
         │                      ▼
         │              ┌──────────────────┐
         │              │ Email/Şifre/Tekrar│
         │              │ Firebase Auth     │
         │              │ İlk kredi: 3      │
         │              └──────────────────┘
         │                      │
         ▼                      ▼
┌────────────────────────────────┐
│      HOME SCREEN               │
│  - Kredi Durumu                │
│  - Yeni Analiz                 │
│  - Geçmiş                      │
│  - Kredi Satın Al              │
└────────────────────────────────┘
```

### 2. Bülten Analizi (ANA AKIŞ)
```
┌─────────────────────────────────────────────────────────┐
│ KULLANICI: "Yeni Analiz" butonuna tıklar              │
└────────────────────┬────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────┐
│ UPLOAD SCREEN                                           │
│ ┌─────────────┐  ┌─────────────┐                       │
│ │ Galeriden   │  │ Kamera      │                       │
│ │ Seç         │  │ Çek         │                       │
│ └─────────────┘  └─────────────┘                       │
│                                                          │
│ [Görsel Preview]                                        │
│                                                          │
│       [YÜKLE VE ANALİZ ET]  <─── Tıkla                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ BACKEND: analysis_service.analyzeBulletin()            │
│                                                          │
│ 1️⃣ Firebase'de yeni bulletin kaydı oluştur             │
│    Status: 'analyzing'                                  │
│                                                          │
│ 2️⃣ Kredi kontrolü ve düşüm                             │
│    - Premium ise ücretsiz                               │
│    - Değilse 1 kredi düş                                │
│                                                          │
│ 3️⃣ GEMİNİ AI: Görüntüden maçları çıkar                 │
│    Input: Base64 encoded image                          │
│    Output: JSON {matches: [{homeTeam, awayTeam}]}      │
│                                                          │
│ 4️⃣ Her maç için:                                        │
│    ┌──────────────────────────────┐                    │
│    │ A. Firebase Match Pool'da ara│                    │
│    │    - Fuzzy matching (%85)    │                    │
│    │    - Bulunan: Stats al       │                    │
│    └────────┬─────────────────────┘                    │
│             │ Bulunamadı?                               │
│             ▼                                            │
│    ┌──────────────────────────────┐                    │
│    │ B. Football API'den çek      │                    │
│    │    - searchAndGetTeamData()  │                    │
│    │    - getTeamStats()          │                    │
│    │    - getH2H()                │                    │
│    └──────────────────────────────┘                    │
│             │                                            │
│             ▼                                            │
│    ┌──────────────────────────────┐                    │
│    │ C. AI Analiz Motoru          │                    │
│    │    - 1X2 (Ev/Beraberlik/Dep) │                    │
│    │    - Alt/Üst 2.5 Gol         │                    │
│    │    - BTTS (Karşılıklı Gol)   │                    │
│    │    - Handikap                 │                    │
│    │    - İlk Yarı                 │                    │
│    │    - Toplam Gol Aralığı      │                    │
│    │    - Çifte Şans               │                    │
│    └──────────────────────────────┘                    │
│                                                          │
│ 5️⃣ Sonuçları Firebase'e kaydet                         │
│    Status: 'completed'                                  │
│    matches: [analyzed_matches_array]                   │
└────────────────────┬────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────┐
│ ANALYSIS SCREEN: Sonuçları göster                      │
│                                                          │
│ ┌─────────────────────────────────────────────────┐    │
│ │ Maç 1: Galatasaray vs Fenerbahçe               │    │
│ │ ─────────────────────────────────────────────── │    │
│ │ ✓ 1X2: 1 (Ev Kazanır) - %72 güven              │    │
│ │ ✓ Üst 2.5 Gol - %68 güven                       │    │
│ │ ✓ BTTS: Var - %65 güven                         │    │
│ │ Risk: Orta                                       │    │
│ │ Öneri: Ev sahibi avantajlı, dikkatli oynayın   │    │
│ └─────────────────────────────────────────────────┘    │
│                                                          │
│ [Maç 2, 3, 4...]                                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🧠 AI ANALİZ MOTORU DETAYLARı

### İstatistiksel Hesaplama

**analysis_service.dart → _performAiAnalysis()**

Her maç için hesaplanan metrikler:

```dart
stats = {
  // Ev Sahibi
  'homeGamesPlayed': 10,
  'homeWins': 4,
  'homeDraws': 3,
  'homeLosses': 3,
  'homeAvgFor': 1.3,        // Maç başı atılan gol
  'homeAvgAgainst': 1.2,    // Maç başı yenilen gol
  'homeWinRate': 40.0,      // Galibiyet oranı %
  
  // Deplasman
  'awayGamesPlayed': 10,
  'awayWins': 3,
  'awayDraws': 3,
  'awayLosses': 4,
  'awayAvgFor': 1.1,
  'awayAvgAgainst': 1.3,
  'awayWinRate': 30.0,
}
```

### 7 Bahis Türü Analiz Algoritmaları

#### 1. 1X2 (Ev/Beraberlik/Deplasman)
```dart
if (homeWinRate > 60 && goalDiff > 0.8) {
  prediction = '1' (Ev Kazanır)
  confidence = 70-90%
} else if (awayWinRate > 60 && goalDiff < -0.8) {
  prediction = '2' (Deplasman Kazanır)
  confidence = 70-90%
} else {
  prediction = '1' (Minimal avantaj)
  confidence = 52-60%
}
```

#### 2. Alt/Üst 2.5 Gol
```dart
totalExpected = (homeAvgFor + awayAvgAgainst + awayAvgFor + homeAvgAgainst) / 2

if (totalExpected > 3.0) {
  prediction = 'Üst 2.5'
  confidence = 65-85%
} else if (totalExpected < 2.0) {
  prediction = 'Alt 2.5'
  confidence = 65-85%
}
```

#### 3. BTTS (Karşılıklı Gol)
```dart
if (homeAvgFor > 0.8 && awayAvgFor > 0.8) {
  prediction = 'Var'
  confidence = 60-80%
} else {
  prediction = 'Yok'
  confidence = 60%
}
```

#### 4. Handikap
```dart
goalDiff = homeAvgFor - awayAvgFor

if (goalDiff > 1.5) {
  prediction = 'Ev -1.5'
} else if (goalDiff > 0.8) {
  prediction = 'Ev -0.5'
} else if (goalDiff < -1.5) {
  prediction = 'Dep -1.5'
}
```

#### 5. İlk Yarı
```dart
homeHalfGoals = homeAvgFor * 0.42
awayHalfGoals = awayAvgFor * 0.42

// En yüksek gol beklentisi
prediction = '1' veya 'X' veya '2'
```

#### 6. Toplam Gol Aralığı
```dart
if (total < 1.5) prediction = '0-1 Gol'
else if (total < 2.5) prediction = '2-3 Gol'
else if (total < 3.5) prediction = '3-4 Gol'
else prediction = '4+ Gol'
```

#### 7. Çifte Şans
```dart
homeNotLose = (homeWins + homeDraws) / homeGamesPlayed * 100

if (homeNotLose > 75) {
  prediction = '1X'
  confidence = 75%
}
```

---

## 💰 KREDİ VE ÖDEME SİSTEMİ

### Kredi Sistemi

**İlk Kayıt:**
- Her yeni kullanıcı 3 ücretsiz kredi alır

**Kredi Kullanımı:**
- Her analiz için 1 kredi düşülür
- Premium üyeler sınırsız analiz yapabilir

**Kredi Paketleri (Google Play IAP):**
```dart
Product IDs:
- 'credits_5'   → 5 Kredi
- 'credits_10'  → 10 Kredi
- 'credits_25'  → 25 Kredi
- 'credits_50'  → 50 Kredi
```

**Premium Abonelikler:**
```dart
Product IDs:
- 'premium_monthly'   → 30 Gün (Aylık)
- 'premium_3months'   → 90 Gün (3 Aylık)
- 'premium_yearly'    → 365 Gün (Yıllık)
```

### Satın Alma Akışı

```
Kullanıcı "Kredi Satın Al" butonuna tıklar
         ↓
Subscription Screen açılır
         ↓
Google Play IAP gösterilir
         ↓
Kullanıcı ödeme yapar
         ↓
Firebase Cloud Function tetiklenir:
- verifyPurchaseAndAddCredits()
- veya verifyPurchaseAndSetPremium()
         ↓
Google Play API ile satın alma doğrulanır
         ↓
Firebase Realtime Database güncellenir:
- users/{userId}/credits artırılır
- veya isPremium: true yapılır
         ↓
Kredi geçmişi kaydedilir (credit_transactions)
         ↓
Kullanıcıya başarı mesajı gösterilir
```

### Güvenlik Önlemleri

**Cloud Functions (functions/index.js):**
1. ✅ Purchase token doğrulama (Google Play API)
2. ✅ Duplicate purchase kontrolü
3. ✅ Suspicious activity logging
4. ✅ Server-side kredi güncelleme (client'tan gönderilmez)
5. ✅ Transaction logging (audit trail)

---

## 🔥 FİREBASE MATCH POOL SİSTEMİ

### Amaç
Football API çağrılarını azaltarak maliyeti düşürmek.

### İşleyiş

**1. Havuz Güncelleme (Otomatik - Cloud Functions):**
```javascript
// functions/index.js → updateMatchPoolLogic()

1. Bugün + Yarın oynanan TÜM maçları Football API'den çek
2. Her maç için:
   - Takım istatistikleri
   - H2H geçmişi
   - Lig bilgileri
3. Firebase Realtime Database'e kaydet:
   matchPool/
     2025-01-15/
       12345/  (fixture ID)
         homeTeam: "Galatasaray"
         awayTeam: "Fenerbahce"
         homeStats: {...}
         awayStats: {...}
         h2h: [...]
4. Eski maçları temizle (3 saat öncesi)
5. Metadata güncelle (toplam maç, lig sayısı)
```

**2. Havuzda Arama (Fuzzy Matching):**
```dart
// match_pool_service.dart → findMatchInPool()

1. Gemini'den gelen takım isimleri normalize edilir
   "Galatasaray" → "galatasaray"
   "Fenerbahçe" → "fenerbahce" (Türkçe karakterler temizlenir)

2. Son 2 günlük maçlarda ara

3. Levenshtein Distance ile %85 benzerlik kontrolü
   "Galatasaray" vs "Galatasaray SK" → %90 benzer → ✅ Eşleşme
   
4. Bulunursa:
   - Pool'daki stats kullanılır (ÜCRETSİZ)
   
5. Bulunmazsa:
   - Football API'den çekilir (ÜCRETLI)
```

**Veri Yapısı:**
```json
{
  "matchPool": {
    "2025-01-15": {
      "12345": {
        "fixtureId": 12345,
        "homeTeam": "Galatasaray",
        "awayTeam": "Fenerbahce",
        "homeTeamId": 645,
        "awayTeamId": 646,
        "league": "Super Lig",
        "leagueId": 203,
        "date": "2025-01-15",
        "time": "20:00",
        "timestamp": 1736960400000,
        "homeStats": { /* ... */ },
        "awayStats": { /* ... */ },
        "h2h": [ /* ... */ ],
        "lastUpdated": 1736950000000
      }
    }
  },
  "poolMetadata": {
    "lastUpdate": 1736950000000,
    "totalMatches": 245,
    "leagues": [39, 61, 78, 203],
    "nextUpdate": 1736971600000
  }
}
```

---

## 📊 VERİ MODELLERİ (Firebase Realtime Database)

### users/{userId}
```json
{
  "email": "user@example.com",
  "displayName": "Kullanıcı Adı",
  "credits": 15,
  "isPremium": false,
  "premiumExpiresAt": null,
  "totalAnalysisCount": 7,
  "createdAt": 1736000000000,
  "lastLoginAt": 1736950000000,
  "ipAddress": "192.168.1.1",
  "deviceId": "abc123",
  "isBanned": false
}
```

### bulletins/{userId}/{bulletinId}
```json
{
  "userId": "user123",
  "status": "completed",  // pending, analyzing, completed, failed
  "createdAt": 1736950000000,
  "analyzedAt": 1736950300000,
  "matches": [
    {
      "homeTeam": "Galatasaray",
      "awayTeam": "Fenerbahce",
      "league": "Super Lig",
      "source": "firebase_pool",  // veya football_api
      "predictions": {
        "matchResult": {
          "prediction": "1",
          "confidence": 72,
          "reasoning": "Ev sahibi dominant..."
        },
        "over25": { /* ... */ },
        "btts": { /* ... */ }
      },
      "homeStats": { /* ... */ },
      "awayStats": { /* ... */ }
    }
  ]
}
```

### credit_transactions/
```json
{
  "transactionId": {
    "userId": "user123",
    "type": "purchase",  // purchase, usage, reward
    "amount": 10,
    "balanceAfter": 25,
    "createdAt": 1736950000000,
    "description": "Kredi satın alma - credits_10",
    "productId": "credits_10",
    "verified": true
  }
}
```

### purchase_logs/
```json
{
  "logId": {
    "userId": "user123",
    "productId": "credits_10",
    "purchaseToken": "abcd1234...",
    "creditAmount": 10,
    "createdAt": 1736950000000,
    "verified": true,
    "platform": "google_play"
  }
}
```

---

## 🔑 API KEYS & REMOTE CONFIG

**Firebase Remote Config:**
```json
{
  "API_FOOTBALL_KEY": "your-football-api-key",
  "GEMINI_API_KEY": "your-gemini-api-key"
}
```

**Kullanım:**
```dart
// remote_config_service.dart
final remoteConfig = RemoteConfigService();
final footballKey = remoteConfig.footballApiKey;
final geminiKey = remoteConfig.geminiApiKey;
```

---

## 🛡️ GÜVENLİK ÖNLEMLERİ

### 1. Satın Alma Güvenliği
✅ Cloud Functions ile server-side doğrulama  
✅ Google Play API ile purchase token kontrolü  
✅ Duplicate purchase önleme  
✅ Suspicious activity logging  

### 2. Kredi Manipülasyonu Önleme
✅ Kredi güncellemeleri sadece server-side  
✅ Client'tan gelen kredi değerleri kullanılmaz  
✅ Her işlem transaction log'una kaydedilir  

### 3. IP Ban Sistemi
✅ Kullanıcı IP adresi kaydedilir  
✅ Cihaz ID tutulur  
✅ Şüpheli aktivite tespit edilebilir  

### 4. Rate Limiting
✅ API çağrıları arasında delay  
✅ Football API: 200-800ms delay  
✅ Gemini API: Tek seferde max 4 maç  

---

## ⚠️ BİLİNEN SORUNLAR

### 1. 4.5+ Maç Yüklendiğinde Hata
**Durum:** Aktif sorun  
**Sebep:** Gemini tüm maçları döndürüyor ancak sistem işleyemiyor  
**Etki:** Kullanıcıya hata mesajı gösteriliyor  
**Çözüm:** İlk 4 maçı seç ve analiz et (TODO-8.1)  

### 2. "Yetersiz Veri" Mesajları
**Durum:** Aktif sorun  
**Sebep:** Varsayılan değerler kullanıldığında belirsiz sonuç  
**Etki:** Kullanıcı kafası karışıyor, güven azalıyor  
**Çözüm:** Daha kesin ifadeler kullan (TODO-8.2)  

### 3. Yüksek Başarısızlık Oranı
**Durum:** Aktif sorun  
**Sebep:** Pool'da bulunamayan maçlar + API timeout/hataları  
**Etki:** Kullanıcı kaybı  
**Çözüm:** Retry mekanizması, timeout artırma (TODO-8.3)  

### 4. Dil Desteği Yok
**Durum:** Feature eksikliği  
**Etki:** Sadece Türkçe kullanıcılar  
**Çözüm:** İngilizce/Türkçe dil seçimi (TODO-1)  

### 5. Kullanıcı Bağlılığı Düşük
**Durum:** İyileştirme gerekli  
**Etki:** Kullanıcılar uygulamayı bırakıyor  
**Çözüm:** Bildirimler, ödüllü reklamlar, rating sistemi (TODO-3,4,6)  

---

## 📈 PERFORMANS METRİKLERİ

**Ortalama Analiz Süresi:**
- Pool'dan: 5-10 saniye (4 maç)
- API'den: 20-40 saniye (4 maç)

**API Maliyeti:**
- Gemini: ~$0.001 per image
- Football API: ~$0.003 per endpoint (stats, h2h)

**Kullanıcı Davranışı:**
- Ortalama günlük analiz: 2-3
- Kredi satın alma oranı: ~15%
- Premium abonelik oranı: ~5%

---

## 🚀 DEPLOYMENT

**Google Play Store:**
- Package: com.aisporanaliz.app
- Min SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Signing: Release keystore ile

**Firebase:**
- Project: ai-spor-pro-xxxxx
- Region: us-central1
- Database: Realtime Database (Frankfurt)

**Cloud Functions:**
- Runtime: Node.js 18
- Memory: 256MB
- Timeout: 60s

---

## 📞 DESTEK VE İLETİŞİM

**Powered by:** Bilwin.inc  
**Email:** (belirtilmemiş)  
**Privacy Policy:** (url gerekli)  
**Terms of Service:** (url gerekli)  

---

**Son Güncelleme:** Ocak 2025  
**Versiyon:** 23.0.23+24  
**Durum:** Aktif - Google Play'de 1000+ kullanıcı
