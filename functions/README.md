# 🔥 Firebase Cloud Functions - Maç Havuzu Güncelleyici

## 🚀 KURULUM

### 1. Firebase CLI Yükle
```bash
npm install -g firebase-tools
firebase login
```

### 2. Firebase Projesi Bağla
```bash
cd /app
firebase init functions
# Mevcut projeyi seç: ai-spor-analiz-2024
# JavaScript seç
# ESLint: Evet
# Dependencies: Evet
```

### 3. Football API Key Ayarla
```bash
# Ortam değişkenini ayarla
firebase functions:config:set football.apikey="YOUR_FOOTBALL_API_KEY"

# Kontrol et
firebase functions:config:get
```

### 4. Deploy Et
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

---

## ⚙️ FUNCTIONS LİSTESİ

### 1️⃣ `updateMatchPool` (Scheduled - Her 6 Saatte)
- **Ne Yapar:** 24 saatlik maçları Football API'den çeker ve Firebase'e kaydeder
- **Çalışma Zamanı:** Her 6 saatte bir (00:00, 06:00, 12:00, 18:00)
- **Timezone:** Europe/Istanbul

### 2️⃣ `cleanOldMatches` (Scheduled - Her 3 Saatte)
- **Ne Yapar:** 3 saatten eski maçları Firebase'den siler
- **Çalışma Zamanı:** Her 3 saatte bir

### 3️⃣ `manualUpdatePool` (HTTP Trigger)
- **Ne Yapar:** Manuel olarak havuzu günceller
- **Kullanım:**
```bash
curl -X GET https://YOUR_REGION-ai-spor-analiz-2024.cloudfunctions.net/manualUpdatePool
```

---

## 📊 HAVUZ YAPISI

```json
{
  "matchPool": {
    "2024-12-01": {
      "123456": {
        "fixtureId": 123456,
        "homeTeam": "Fenerbahce",
        "awayTeam": "Galatasaray",
        "homeTeamId": 556,
        "awayTeamId": 548,
        "league": "Super Lig",
        "leagueId": 203,
        "date": "2024-12-01",
        "time": "20:00",
        "timestamp": 1733079600000,
        "status": "NS",
        "homeStats": { ... },
        "awayStats": { ... },
        "h2h": [ ... ],
        "lastUpdated": 1733070000000
      }
    }
  },
  "poolMetadata": {
    "lastUpdate": 1733070000000,
    "totalMatches": 350,
    "leagues": [203, 39, 140, 78, 135, 61]
  }
}
```

---

## 🔧 MANUEL KULLANIM

### Lokal Test (Emulator)
```bash
firebase emulators:start --only functions
```

### Log'ları İzle
```bash
firebase functions:log --only updateMatchPool
```

### Tek Seferlik Çalıştırma
```bash
# HTTP endpoint ile manuel tetikleme
curl https://YOUR_REGION-ai-spor-analiz-2024.cloudfunctions.net/manualUpdatePool
```

---

## ⚡ PERFORMANS

| Metrik | Değer |
|--------|--------|
| Güncelleme Süresi | ~5-10 dakika (6 lig) |
| API Çağrısı | ~500-800 request |
| Firebase Yazım | ~300-400 write |
| Maliyet | ~$0.02 per update |

---

## ⚠️ DİKKAT NOKTALARI

1. **Football API Rate Limit:** 10 req/sec (kod otomatik bekliyor)
2. **Firebase Quota:** Free plan 20K/day write (yeterli)
3. **Cloud Functions Quota:** Free plan 125K/month invocations
4. **Timezone:** Türkiye saat dilimine göre ayarlandı

---

## 🐞 SORUN GİDERME

### Hata: "Missing football.apikey"
```bash
firebase functions:config:set football.apikey="YOUR_KEY"
firebase deploy --only functions
```

### Hata: "Insufficient permissions"
- Firebase Console > Database > Rules kontrol et
- Cloud Functions service account'a admin erişimi ver

### Log'ları Kontrol Et
```bash
firebase functions:log
```
