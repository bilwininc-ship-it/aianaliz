# 🎯 AI SPOR PRO - TODO GÖREVLER LİSTESİ

**Bu dokümanda her görev, bir ajana verilebilecek şekilde detaylı olarak açıklanmıştır.**  
**Her bölüm bağımsız olarak çalıştırılabilir.**

---

# 📋 TODO-1: DİL SEÇİMİ SİSTEMİ (TR/EN)

**Öncelik:** YÜKSEK  
**Tahmini Süre:** 4-6 saat  
**Bağımlılıklar:** Yok

## Görev Özeti
Uygulamaya İngilizce ve Türkçe dil seçeneği eklenecek. Kullanıcı giriş ekranında dilini seçecek ve tüm uygulama seçilen dilde görüntülenecek.

## Gereksinimler

### 1. Paket Yüklemeleri
**pubspec.yaml'a ekle:**
```yaml
dependencies:
  intl: ^0.19.0
  flutter_localizations:
    sdk: flutter
```

Terminalde çalıştır:
```bash
flutter pub get
```

### 2. Yeni Dosyalar Oluştur

#### A. Language Provider (`/app/lib/providers/language_provider.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('tr', 'TR'); // Varsayılan Türkçe
  
  Locale get locale => _locale;
  
  // Uygulama başlarken dil yükle
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'tr';
    final countryCode = prefs.getString('country_code') ?? 'TR';
    _locale = Locale(languageCode, countryCode);
    notifyListeners();
  }
  
  // Dil değiştir
  Future<void> changeLanguage(String languageCode, String countryCode) async {
    _locale = Locale(languageCode, countryCode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    notifyListeners();
  }
  
  // Türkçe mi?
  bool get isTurkish => _locale.languageCode == 'tr';
  
  // İngilizce mi?
  bool get isEnglish => _locale.languageCode == 'en';
}
```

#### B. Çeviri Dosyaları

**`/app/lib/l10n/app_localizations.dart`**
```dart
import 'package:flutter/material.dart';
import 'tr.dart';
import 'en.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  static const List<Locale> supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
  ];
  
  late Map<String, String> _localizedStrings;
  
  Future<bool> load() async {
    if (locale.languageCode == 'tr') {
      _localizedStrings = tr;
    } else {
      _localizedStrings = en;
    }
    return true;
  }
  
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
  
  // Helper method
  String t(String key) => translate(key);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
```

**`/app/lib/l10n/tr.dart`**
```dart
final Map<String, String> tr = {
  // Auth
  'welcome': 'Hoş Geldiniz',
  'email': 'E-posta',
  'password': 'Şifre',
  'login': 'Giriş Yap',
  'register': 'Kayıt Ol',
  'forgot_password': 'Şifremi Unuttum',
  'dont_have_account': 'Hesabınız yok mu?',
  'already_have_account': 'Zaten hesabınız var mı?',
  
  // Home
  'home': 'Ana Sayfa',
  'new_analysis': 'Yeni Analiz',
  'history': 'Geçmiş',
  'profile': 'Profil',
  'settings': 'Ayarlar',
  'credits': 'Kredi',
  'buy_credits': 'Kredi Al',
  'premium': 'Premium',
  'quick_actions': 'Hızlı İşlemler',
  'statistics': 'İstatistikler',
  'total_analysis': 'Toplam Analiz',
  'remaining_credits': 'Kalan Kredi',
  'membership_status': 'Üyelik Durumu',
  
  // Upload
  'upload_bulletin': 'Bülten Yükle',
  'select_from_gallery': 'Galeriden Seç',
  'take_photo': 'Fotoğraf Çek',
  'upload_and_analyze': 'Yükle ve Analiz Et',
  'how_it_works': 'Nasıl Çalışır?',
  
  // Analysis
  'analysis_results': 'Analiz Sonuçları',
  'confidence': 'Güven',
  'prediction': 'Tahmin',
  'risk': 'Risk',
  'reasoning': 'Açıklama',
  'match_result': 'Maç Sonucu',
  'over_under': 'Alt/Üst',
  'btts': 'Karşılıklı Gol',
  'handicap': 'Handikap',
  'first_half': 'İlk Yarı',
  'total_goals': 'Toplam Gol',
  'double_chance': 'Çifte Şans',
  
  // Subscription
  'packages': 'Paketler',
  'credit_packages': 'Kredi Paketleri',
  'premium_packages': 'Premium Paketler',
  'buy': 'Satın Al',
  'monthly': 'Aylık',
  'yearly': 'Yıllık',
  'unlimited': 'Sınırsız',
  
  // Common
  'loading': 'Yükleniyor...',
  'error': 'Hata',
  'success': 'Başarılı',
  'cancel': 'İptal',
  'ok': 'Tamam',
  'save': 'Kaydet',
  'delete': 'Sil',
  'edit': 'Düzenle',
  'search': 'Ara',
  'filter': 'Filtrele',
  'sort': 'Sırala',
  'language': 'Dil',
  'select_language': 'Dil Seçin',
  'turkish': 'Türkçe',
  'english': 'English',
};
```

**`/app/lib/l10n/en.dart`**
```dart
final Map<String, String> en = {
  // Auth
  'welcome': 'Welcome',
  'email': 'Email',
  'password': 'Password',
  'login': 'Login',
  'register': 'Register',
  'forgot_password': 'Forgot Password',
  'dont_have_account': "Don't have an account?",
  'already_have_account': 'Already have an account?',
  
  // Home
  'home': 'Home',
  'new_analysis': 'New Analysis',
  'history': 'History',
  'profile': 'Profile',
  'settings': 'Settings',
  'credits': 'Credits',
  'buy_credits': 'Buy Credits',
  'premium': 'Premium',
  'quick_actions': 'Quick Actions',
  'statistics': 'Statistics',
  'total_analysis': 'Total Analysis',
  'remaining_credits': 'Remaining Credits',
  'membership_status': 'Membership Status',
  
  // Upload
  'upload_bulletin': 'Upload Bulletin',
  'select_from_gallery': 'Select from Gallery',
  'take_photo': 'Take Photo',
  'upload_and_analyze': 'Upload and Analyze',
  'how_it_works': 'How It Works?',
  
  // Analysis
  'analysis_results': 'Analysis Results',
  'confidence': 'Confidence',
  'prediction': 'Prediction',
  'risk': 'Risk',
  'reasoning': 'Reasoning',
  'match_result': 'Match Result',
  'over_under': 'Over/Under',
  'btts': 'BTTS',
  'handicap': 'Handicap',
  'first_half': 'First Half',
  'total_goals': 'Total Goals',
  'double_chance': 'Double Chance',
  
  // Subscription
  'packages': 'Packages',
  'credit_packages': 'Credit Packages',
  'premium_packages': 'Premium Packages',
  'buy': 'Buy',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
  'unlimited': 'Unlimited',
  
  // Common
  'loading': 'Loading...',
  'error': 'Error',
  'success': 'Success',
  'cancel': 'Cancel',
  'ok': 'OK',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'search': 'Search',
  'filter': 'Filter',
  'sort': 'Sort',
  'language': 'Language',
  'select_language': 'Select Language',
  'turkish': 'Türkçe',
  'english': 'English',
};
```

### 3. main.dart Güncelleme

**`/app/lib/main.dart`** dosyasını güncelle:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/remote_config_service.dart';
import 'services/app_startup_service.dart';
import 'core/routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/bulletin_provider.dart';
import 'providers/language_provider.dart'; // ✅ YENİ
import 'l10n/app_localizations.dart'; // ✅ YENİ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase initialize
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase başarıyla başlatıldı');
    }
  } catch (e) {
    print('❌ Firebase başlatma hatası: $e');
  }
  
  // Remote Config initialize
  try {
    final remoteConfig = RemoteConfigService();
    await remoteConfig.initialize();
  } catch (e) {
    print('❌ Remote Config hatası: $e');
  }
  
  // App Startup
  try {
    final appStartup = AppStartupService();
    await appStartup.initialize();
  } catch (e) {
    print('❌ App Startup hatası: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BulletinProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLanguage()), // ✅ YENİ
      ],
      child: Consumer<LanguageProvider>( // ✅ YENİ
        builder: (context, languageProvider, child) {
          return MaterialApp.router(
            title: 'AI Spor Pro',
            debugShowCheckedModeBanner: false,
            
            // ✅ YENİ: Localization
            locale: languageProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
```

### 4. Login Screen Güncelleme

**`/app/lib/screens/auth/login_screen.dart`** dosyasını güncelle:

AppBar'a dil seçici ekle:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart'; // ✅ YENİ
import '../../l10n/app_localizations.dart'; // ✅ YENİ
// ... diğer importlar

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ... mevcut kod

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // ✅ YENİ
    final languageProvider = context.watch<LanguageProvider>(); // ✅ YENİ
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.t('welcome')), // ✅ Çeviri kullan
        actions: [
          // ✅ YENİ: Dil seçici dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String languageCode) {
              if (languageCode == 'tr') {
                languageProvider.changeLanguage('tr', 'TR');
              } else {
                languageProvider.changeLanguage('en', 'US');
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'tr',
                child: Row(
                  children: [
                    const Text('🇹🇷'),
                    const SizedBox(width: 8),
                    Text(localizations.t('turkish')),
                    if (languageProvider.isTurkish)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, size: 16),
                      ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    const Text('🇬🇧'),
                    const SizedBox(width: 8),
                    Text(localizations.t('english')),
                    if (languageProvider.isEnglish)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, size: 16),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Email field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: localizations.t('email'), // ✅ Çeviri
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            
            // Password field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: localizations.t('password'), // ✅ Çeviri
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            
            // Login button
            ElevatedButton(
              onPressed: _login,
              child: Text(localizations.t('login')), // ✅ Çeviri
            ),
            
            // ... diğer butonlar da aynı şekilde
          ],
        ),
      ),
    );
  }
}
```

### 5. Diğer Ekranları Güncelle

**Tüm ekranlarda hardcoded metinleri çeviriye çevir:**

Örnek kullanım:
```dart
// ESKİ:
Text('Hoş Geldiniz')

// YENİ:
final localizations = AppLocalizations.of(context)!;
Text(localizations.t('welcome'))
```

**Güncellenecek dosyalar:**
- `/app/lib/screens/auth/register_screen.dart`
- `/app/lib/screens/home/home_screen.dart`
- `/app/lib/screens/upload/upload_screen.dart`
- `/app/lib/screens/analysis/analysis_screen.dart`
- `/app/lib/screens/history/history_screen.dart`
- `/app/lib/screens/subscription/subscription_screen.dart`
- `/app/lib/screens/profile/profile_screen.dart`

### 6. Test Et

```bash
flutter clean
flutter pub get
flutter run
```

**Test senaryosu:**
1. Uygulamayı aç
2. Login ekranında dil seçici butona tıkla
3. İngilizce seç → Tüm metinler İngilizce'ye dönmeli
4. Türkçe seç → Tüm metinler Türkçe'ye dönmeli
5. Uygulamayı kapat ve tekrar aç → Seçilen dil hatırlanmalı

## Tamamlanma Kriterleri
- ✅ Dil seçici login/register ekranlarında görünüyor
- ✅ Türkçe ve İngilizce arası geçiş yapılabiliyor
- ✅ Tüm ekranlarda çeviriler çalışıyor
- ✅ Seçilen dil SharedPreferences'a kaydediliyor
- ✅ Uygulama tekrar açıldığında dil hatırlanıyor

---

# 📱 TODO-2: GOOGLE ADS ENTEGRASYONU

**Öncelik:** ORTA  
**Tahmini Süre:** 3-4 saat  
**Bağımlılıklar:** TODO-1 (dil sistemi - opsiyonel)

## Görev Özeti
Google Ads conversion tracking entegre edilecek. Kullanıcı satın alma yaptığında Google Ads'e bildirim gidecek.

## Gereksinimler

### 1. Paket Yüklemeleri

**pubspec.yaml'a ekle:**
```yaml
dependencies:
  google_mobile_ads: ^4.0.0
```

Terminalde çalıştır:
```bash
flutter pub get
```

### 2. AndroidManifest.xml Güncelleme

**`/app/android/app/src/main/AndroidManifest.xml`** dosyasını güncelle:

```xml
<manifest>
  <application>
    <!-- Mevcut kodlar... -->
    
    <!-- ✅ YENİ: Google AdMob App ID -->
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-XXXXXXXXXXXXX~YYYYYYYYYY"/>
    <!-- NOT: Gerçek AdMob App ID'nizi kullanın -->
    
  </application>
</manifest>
```

### 3. Google Ads Service Oluştur

**`/app/lib/services/google_ads_service.dart`**
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class GoogleAdsService {
  static final GoogleAdsService _instance = GoogleAdsService._internal();
  factory GoogleAdsService() => _instance;
  GoogleAdsService._internal();

  bool _initialized = false;

  /// Initialize Google Mobile Ads
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('✅ Google Ads initialized');
    } catch (e) {
      debugPrint('❌ Google Ads initialization error: $e');
    }
  }

  /// Track purchase event (conversion)
  Future<void> trackPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Google Ads conversion tracking
      debugPrint('📊 Google Ads Conversion:');
      debugPrint('  Product: $productId');
      debugPrint('  Value: $value $currency');

      // NOT: Gerçek conversion tracking için Google Ads API kullanılmalı
      // Bu basit bir log örneğidir
      
      // Alternatif: Firebase Analytics ile entegre edilebilir
      // FirebaseAnalytics.instance.logPurchase(
      //   value: value,
      //   currency: currency,
      //   items: [AnalyticsEventItem(itemId: productId)],
      // );
      
    } catch (e) {
      debugPrint('❌ Google Ads tracking error: $e');
    }
  }

  /// Track app install (first launch)
  Future<void> trackAppInstall() async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('📊 Google Ads: App Install tracked');
  }

  /// Track first analysis
  Future<void> trackFirstAnalysis() async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('📊 Google Ads: First Analysis tracked');
  }
}
```

### 4. IAP Service'e Entegrasyon

**`/app/lib/services/iap_service.dart`** dosyasında _onPurchaseUpdate metodunu güncelle:

```dart
import './google_ads_service.dart'; // ✅ YENİ import

class InAppPurchaseService {
  // ... mevcut kod
  
  final GoogleAdsService _googleAds = GoogleAdsService(); // ✅ YENİ

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _purchasePending = false;
          onPurchaseError?.call(purchaseDetails.error?.message ?? 'Bilinmeyen hata');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Satın alma başarılı
          _purchasePending = false;
          onPurchaseSuccess?.call(purchaseDetails);
          
          // ✅ YENİ: Google Ads conversion tracking
          _trackPurchaseToGoogleAds(purchaseDetails);
        }
        
        // Satın almayı tamamla
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }
  
  // ✅ YENİ: Google Ads tracking helper
  Future<void> _trackPurchaseToGoogleAds(PurchaseDetails purchase) async {
    try {
      final productId = purchase.productID;
      
      // Fiyatı hesapla (örnek değerler)
      double value = 0.0;
      if (productId == 'credits_5') value = 4.99;
      else if (productId == 'credits_10') value = 9.99;
      else if (productId == 'credits_25') value = 19.99;
      else if (productId == 'credits_50') value = 39.99;
      else if (productId == 'premium_monthly') value = 29.99;
      else if (productId == 'premium_3months') value = 79.99;
      else if (productId == 'premium_yearly') value = 199.99;
      
      await _googleAds.trackPurchase(
        productId: productId,
        value: value,
        currency: 'TRY', // veya 'USD'
      );
      
      debugPrint('✅ Google Ads conversion tracked: $productId');
    } catch (e) {
      debugPrint('❌ Google Ads tracking error: $e');
    }
  }
}
```

### 5. App Startup'a Entegrasyon

**`/app/lib/services/app_startup_service.dart`** dosyasını güncelle:

```dart
import './google_ads_service.dart'; // ✅ YENİ

class AppStartupService {
  // ... mevcut kod
  
  Future<void> initialize() async {
    try {
      debugPrint('🚀 App Startup başlatılıyor...');
      
      // ✅ YENİ: Google Ads initialize
      final googleAds = GoogleAdsService();
      await googleAds.initialize();
      
      // Mevcut kodlar...
      
      debugPrint('✅ App Startup tamamlandı');
    } catch (e) {
      debugPrint('❌ App Startup hatası: $e');
    }
  }
}
```

### 6. Remote Config'e Ad Unit ID Ekleme

**Firebase Console → Remote Config:**

```json
{
  "ADMOB_APP_ID": "ca-app-pub-XXXXXXXXXXXXX~YYYYYYYYYY",
  "ADMOB_BANNER_AD_UNIT": "ca-app-pub-XXXXXXXXXXXXX/ZZZZZZZZZZ",
  "ADMOB_INTERSTITIAL_AD_UNIT": "ca-app-pub-XXXXXXXXXXXXX/AAAAAAAAAA",
  "ADMOB_REWARDED_AD_UNIT": "ca-app-pub-XXXXXXXXXXXXX/BBBBBBBBBB"
}
```

**`/app/lib/services/remote_config_service.dart`** güncelle:

```dart
class RemoteConfigService {
  // ... mevcut kod
  
  // ✅ YENİ getters
  String get admobAppId => _remoteConfig.getString('ADMOB_APP_ID');
  String get bannerAdUnit => _remoteConfig.getString('ADMOB_BANNER_AD_UNIT');
  String get interstitialAdUnit => _remoteConfig.getString('ADMOB_INTERSTITIAL_AD_UNIT');
  String get rewardedAdUnit => _remoteConfig.getString('ADMOB_REWARDED_AD_UNIT');
}
```

### 7. Test Et

**Test AdMob App ID (geliştirme için):**
```
ca-app-pub-3940256099942544~3347511713
```

**Test senaryosu:**
1. Uygulamayı çalıştır
2. Kredi satın al
3. Console'da "Google Ads Conversion" log'unu gör
4. Firebase Analytics'te purchase event'i kontrol et

## Tamamlanma Kriterleri
- ✅ Google Mobile Ads paketi yüklendi
- ✅ AndroidManifest.xml güncellendi
- ✅ GoogleAdsService oluşturuldu
- ✅ IAP Service'e conversion tracking eklendi
- ✅ Remote Config'e ad unit ID'leri eklendi
- ✅ Satın alma sonrası tracking çalışıyor

---

# 🔔 TODO-3: BİLDİRİM SİSTEMİ

**Öncelik:** ORTA  
**Tahmini Süre:** 4-5 saat  
**Bağımlılıklar:** Firebase Cloud Messaging (aktif olmalı)

## Görev Özeti
FCM (Firebase Cloud Messaging) ile push notification sistemi kurulacak. Kullanıcılara günlük hatırlatma, kredi bitimi uyarıları gönderilecek.

## Gereksinimler

### 1. Firebase Console Ayarları

1. Firebase Console → Project Settings → Cloud Messaging
2. "Cloud Messaging API" aktif et
3. Server Key'i kaydet

### 2. Paket Yüklemeleri

**pubspec.yaml'a ekle:**
```yaml
dependencies:
  firebase_messaging: ^14.7.9
  flutter_local_notifications: ^16.3.0
```

Terminalde çalıştır:
```bash
flutter pub get
```

### 3. AndroidManifest.xml Güncelleme

**`/app/android/app/src/main/AndroidManifest.xml`**

```xml
<manifest>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/> <!-- ✅ Android 13+ -->
  
  <application>
    <!-- Mevcut kodlar... -->
    
    <!-- ✅ YENİ: FCM default notification channel -->
    <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="ai_spor_pro_channel" />
  </application>
</manifest>
```

### 4. Notification Service Oluştur

**`/app/lib/services/notification_service.dart`**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Background message handler (MUST be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;

  /// Initialize notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Request permission (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else {
        debugPrint('⚠️ Notification permission denied');
        return;
      }

      // 2. Get FCM token
      _fcmToken = await _fcm.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      // 3. Initialize local notifications
      await _initializeLocalNotifications();

      // 4. Setup message handlers
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 5. Handle notification when app opened from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Notification initialization error: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📩 Local notification tapped: ${response.payload}');
      },
    );

    // Create notification channel (Android)
    const androidChannel = AndroidNotificationChannel(
      'ai_spor_pro_channel',
      'AI Spor Pro Notifications',
      description: 'AI Spor Pro bildirim kanalı',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'AI Spor Pro',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📩 Notification tapped: ${message.data}');
    
    // TODO: Navigate to specific screen based on message.data
    // Example: if (message.data['type'] == 'credit_low') { navigate to subscription }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_spor_pro_channel',
      'AI Spor Pro Notifications',
      channelDescription: 'AI Spor Pro bildirim kanalı',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Save FCM token to Firebase (kullanıcı başına)
  Future<void> saveFcmToken(String userId) async {
    if (_fcmToken == null) return;

    try {
      // Firebase Realtime Database'e kaydet
      // final db = FirebaseDatabase.instance.ref();
      // await db.child('users/$userId/fcmToken').set(_fcmToken);
      debugPrint('✅ FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('❌ FCM token save error: $e');
    }
  }

  /// Check if daily reminder is enabled
  Future<bool> isDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('daily_reminder_enabled') ?? true;
  }

  /// Toggle daily reminder
  Future<void> setDailyReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder_enabled', enabled);
    debugPrint('📅 Daily reminder: ${enabled ? "enabled" : "disabled"}');
  }

  /// Test notification (for development)
  Future<void> showTestNotification() async {
    await _showLocalNotification(
      title: 'Test Bildirimi',
      body: 'Bu bir test bildirimidir.',
    );
  }
}
```

### 5. App Startup'a Entegrasyon

**`/app/lib/services/app_startup_service.dart`** güncelle:

```dart
import './notification_service.dart'; // ✅ YENİ

class AppStartupService {
  Future<void> initialize() async {
    try {
      debugPrint('🚀 App Startup başlatılıyor...');
      
      // ✅ YENİ: Notification service initialize
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Mevcut kodlar...
      
      debugPrint('✅ App Startup tamamlandı');
    } catch (e) {
      debugPrint('❌ App Startup hatası: $e');
    }
  }
}
```

### 6. Notification Settings Screen Güncelleme

**`/app/lib/screens/profile/notification_settings_screen.dart`** güncelle:

```dart
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _dailyReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.isDailyReminderEnabled();
    setState(() {
      _dailyReminderEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Günlük Hatırlatma'),
            subtitle: const Text('Her gün analiz hatırlatması al'),
            value: _dailyReminderEnabled,
            onChanged: (value) async {
              await _notificationService.setDailyReminder(value);
              setState(() {
                _dailyReminderEnabled = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Test Bildirimi Gönder'),
            subtitle: const Text('Bildirimlerin çalıştığını test et'),
            trailing: const Icon(Icons.send),
            onTap: () async {
              await _notificationService.showTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test bildirimi gönderildi')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
```

### 7. Cloud Functions - Scheduled Notifications

**`/app/functions/index.js`** dosyasına ekle:

```javascript
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getMessaging} = require("firebase-admin/messaging");

/**
 * 🔔 SCHEDULED: Send daily reminders to free users
 * Runs every day at 10:00 AM (UTC)
 */
exports.sendDailyReminders = onSchedule(
    {
      schedule: "0 10 * * *", // Cron format: 10:00 AM daily
      timeZone: "Europe/Istanbul",
      memory: "256MiB",
    },
    async (event) => {
      logger.info("🔔 Sending daily reminders...");

      try {
        const db = admin.database();
        const usersRef = db.ref("users");
        const snapshot = await usersRef.get();

        if (!snapshot.exists()) {
          logger.warn("No users found");
          return;
        }

        const users = snapshot.val();
        const messages = [];

        for (const [userId, userData] of Object.entries(users)) {
          // Sadece ücretsiz kullanıcılar (premium olmayanlar)
          if (userData.isPremium) continue;

          // FCM token var mı?
          if (!userData.fcmToken) continue;

          // Kredisi düşük mü?
          const credits = userData.credits || 0;
          
          let title = "AI Spor Pro";
          let body = "";

          if (credits === 0) {
            title = "Kredin bitti! 😢";
            body = "Analiz yapmak için kredi satın al.";
          } else if (credits <= 2) {
            title = "Kredin azalıyor! ⚠️";
            body = `Sadece ${credits} kredi kaldı. Hemen satın al!`;
          } else {
            title = "Bugünkü analizini yaptın mı? 🤔";
            body = `${credits} kredin var. Hemen analiz yap!`;
          }

          messages.push({
            token: userData.fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: "daily_reminder",
              credits: credits.toString(),
            },
          });
        }

        if (messages.length > 0) {
          const response = await getMessaging().sendEach(messages);
          logger.info(
              `✅ ${response.successCount} bildirim gönderildi, ` +
              `${response.failureCount} hata`,
          );
        } else {
          logger.info("Gönderilecek bildirim yok");
        }
      } catch (error) {
        logger.error("❌ Daily reminder error:", error);
      }
    },
);
```

### 8. Test Et

```bash
flutter clean
flutter pub get
flutter run
```

**Test senaryosu:**
1. Uygulamayı aç → Bildirim izni iste
2. Ayarlar → Bildirim Ayarları → Test Bildirimi Gönder
3. Bildirimin geldiğini kontrol et
4. Cloud Functions'ı manuel tetikle (Firebase Console)
5. Günlük hatırlatma bildiriminin geldiğini kontrol et

## Tamamlanma Kriterleri
- ✅ FCM entegrasyonu tamamlandı
- ✅ Local notifications çalışıyor
- ✅ Test bildirimi gönderilebiliyor
- ✅ Bildirim ayarları ekranı çalışıyor
- ✅ Cloud Functions scheduled notification hazır
- ✅ Foreground ve background notifications çalışıyor

---

# 🎁 TODO-4: ÖDÜLLÜ REKLAM SİSTEMİ

**Öncelik:** YÜKSEK  
**Tahmini Süre:** 5-6 saat  
**Bağımlılıklar:** TODO-2 (Google Ads entegrasyonu)

## Görev Özeti
Kullanıcılar 24 saatte bir ödüllü reklam izleyerek 1 kredi kazanabilecek. Cooldown sistemi ve hata yönetimi ile tam entegrasyon.

## Gereksinimler

### 1. Paket Kontrolü

**pubspec.yaml** (TODO-2'de eklenmişti):
```yaml
dependencies:
  google_mobile_ads: ^4.0.0
```

### 2. Rewarded Ad Service Oluştur

**`/app/lib/services/rewarded_ad_service.dart`**

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './remote_config_service.dart';

class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Callbacks
  Function()? onAdLoaded;
  Function()? onAdFailedToLoad;
  Function()? onAdShown;
  Function()? onRewardEarned;
  Function(String)? onError;

  /// Check if user can watch ad (24 hour cooldown)
  Future<bool> canWatchAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt('last_rewarded_ad_watch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // 24 hours = 86400000 milliseconds
      const cooldownPeriod = 86400000;
      
      return (currentTime - lastWatchTime) >= cooldownPeriod;
    } catch (e) {
      debugPrint('❌ Cooldown check error: $e');
      return false;
    }
  }

  /// Get remaining time until next ad
  Future<Duration> getRemainingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt('last_rewarded_ad_watch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      const cooldownPeriod = 86400000; // 24 hours
      final elapsed = currentTime - lastWatchTime;
      final remaining = cooldownPeriod - elapsed;
      
      if (remaining <= 0) {
        return Duration.zero;
      }
      
      return Duration(milliseconds: remaining);
    } catch (e) {
      debugPrint('❌ Remaining cooldown error: $e');
      return Duration.zero;
    }
  }

  /// Load rewarded ad
  Future<void> loadAd() async {
    if (_isLoading || _isAdLoaded) return;

    _isLoading = true;

    try {
      // Test ad unit (geliştirme için)
      // Production'da Remote Config'den al
      String adUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID
      
      // Remote Config'den al (production'da)
      if (_remoteConfig.rewardedAdUnit.isNotEmpty) {
        adUnitId = _remoteConfig.rewardedAdUnit;
      }

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            debugPrint('✅ Rewarded ad loaded');
            onAdLoaded?.call();
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _isAdLoaded = false;
            debugPrint('❌ Rewarded ad failed to load: $error');
            onAdFailedToLoad?.call();
            onError?.call('Reklam yüklenemedi. Lütfen tekrar deneyin.');
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      _isAdLoaded = false;
      debugPrint('❌ Load ad error: $e');
      onError?.call('Reklam yükleme hatası: $e');
    }
  }

  /// Setup ad callbacks
  void _setupAdCallbacks() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Rewarded ad showed');
        onAdShown?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('❌ Rewarded ad dismissed');
        _isAdLoaded = false;
        ad.dispose();
        _rewardedAd = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded ad failed to show: $error');
        _isAdLoaded = false;
        ad.dispose();
        _rewardedAd = null;
        onError?.call('Reklam gösterilemedi');
      },
    );
  }

  /// Show rewarded ad
  Future<bool> showAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      onError?.call('Reklam henüz yüklenmedi');
      return false;
    }

    // Check cooldown
    final canWatch = await canWatchAd();
    if (!canWatch) {
      final remaining = await getRemainingCooldown();
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      onError?.call('$hours saat $minutes dakika sonra tekrar izleyebilirsiniz');
      return false;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          debugPrint('✅ User earned reward: ${reward.amount} ${reward.type}');
          
          // Add credit to user
          await _addCreditToUser();
          
          // Save last watch time
          await _saveLastWatchTime();
          
          onRewardEarned?.call();
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Show ad error: $e');
      onError?.call('Reklam gösterme hatası');
      return false;
    }
  }

  /// Add 1 credit to user (Firebase)
  Future<void> _addCreditToUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ User not logged in');
        return;
      }

      final db = FirebaseDatabase.instance.ref();
      final userRef = db.child('users/$userId');
      
      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        debugPrint('❌ User not found');
        return;
      }

      final userData = snapshot.value as Map;
      final currentCredits = userData['credits'] ?? 0;
      final newCredits = currentCredits + 1;

      await userRef.update({'credits': newCredits});

      // Create transaction record
      final transactionRef = db.child('credit_transactions').push();
      await transactionRef.set({
        'userId': userId,
        'type': 'rewarded_ad',
        'amount': 1,
        'balanceAfter': newCredits,
        'createdAt': ServerValue.timestamp,
        'description': 'Ödüllü reklam izlendi',
      });

      debugPrint('✅ 1 credit added via rewarded ad');
    } catch (e) {
      debugPrint('❌ Add credit error: $e');
    }
  }

  /// Save last watch time
  Future<void> _saveLastWatchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_rewarded_ad_watch',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('✅ Last watch time saved');
    } catch (e) {
      debugPrint('❌ Save watch time error: $e');
    }
  }

  /// Dispose ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
}
```

### 3. Home Screen'e Buton Ekleme

**`/app/lib/screens/home/home_screen.dart`** güncelle:

```dart
import '../../services/rewarded_ad_service.dart'; // ✅ YENİ

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RewardedAdService _rewardedAdService = RewardedAdService(); // ✅ YENİ
  bool _adLoading = false;
  bool _canWatchAd = false;
  Duration _remainingCooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkAdAvailability();
    _setupAdCallbacks();
  }

  Future<void> _checkAdAvailability() async {
    final canWatch = await _rewardedAdService.canWatchAd();
    final remaining = await _rewardedAdService.getRemainingCooldown();
    
    setState(() {
      _canWatchAd = canWatch;
      _remainingCooldown = remaining;
    });
    
    // Eğer izlenebilirse reklamı yükle
    if (canWatch && !_rewardedAdService.isAdLoaded) {
      _rewardedAdService.loadAd();
    }
  }

  void _setupAdCallbacks() {
    _rewardedAdService.onAdLoaded = () {
      if (mounted) {
        setState(() {
          _adLoading = false;
        });
      }
    };

    _rewardedAdService.onAdFailedToLoad = () {
      if (mounted) {
        setState(() {
          _adLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam yüklenemedi')),
        );
      }
    };

    _rewardedAdService.onRewardEarned = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tebrikler! 1 kredi kazandınız'),
            backgroundColor: Colors.green,
          ),
        );
        _checkAdAvailability();
        // Refresh user data
        context.read<AuthProvider>().refreshUser();
      }
    };

    _rewardedAdService.onError = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    };
  }

  Future<void> _watchRewardedAd() async {
    if (!_rewardedAdService.isAdLoaded) {
      setState(() {
        _adLoading = true;
      });
      await _rewardedAdService.loadAd();
    } else {
      await _rewardedAdService.showAd();
    }
  }

  @override
  void dispose() {
    _rewardedAdService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      // ... mevcut kodlar
      
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Mevcut kodlar...
            
            // ✅ YENİ: Ödüllü Reklam Kartı
            if (!authProvider.isPremium)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF64DD17)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ücretsiz Kredi Kazan!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kısa bir reklam izleyerek 1 kredi kazan\n24 saatte bir izleyebilirsin',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _canWatchAd && !_adLoading ? _watchRewardedAd : null,
                        icon: _adLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _canWatchAd
                              ? (_adLoading ? 'Yükleniyor...' : 'Reklam İzle')
                              : '${_remainingCooldown.inHours}s ${_remainingCooldown.inMinutes.remainder(60)}dk sonra',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Mevcut kodlar devam eder...
          ],
        ),
      ),
    );
  }
}
```

### 4. AuthProvider'a refreshUser Metodu Ekle

**`/app/lib/providers/auth_provider.dart`** güncelle:

```dart
class AuthProvider extends ChangeNotifier {
  // ... mevcut kodlar
  
  // ✅ YENİ: Kullanıcı verilerini yenile
  Future<void> refreshUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final db = FirebaseDatabase.instance.ref();
      final snapshot = await db.child('users/${user.uid}').get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        _userModel = UserModel.fromJson(user.uid, Map<String, dynamic>.from(data));
        notifyListeners();
        debugPrint('✅ User data refreshed');
      }
    } catch (e) {
      debugPrint('❌ Refresh user error: $e');
    }
  }
}
```

### 5. Test Et

```bash
flutter clean
flutter pub get
flutter run
```

**Test senaryosu:**
1. Uygulamayı aç (ücretsiz kullanıcı olarak)
2. Ana ekranda "Ücretsiz Kredi Kazan" kartını gör
3. "Reklam İzle" butonuna tıkla
4. Test reklamını izle
5. Reklam bitince 1 kredi eklendiğini kontrol et
6. Butonun "24s 0dk sonra" yazısına döndüğünü kontrol et
7. 24 saat sonra tekrar izlenebilir olmalı

## Tamamlanma Kriterleri
- ✅ Rewarded Ad Service oluşturuldu
- ✅ 24 saat cooldown mekanizması çalışıyor
- ✅ Reklam izlendiğinde 1 kredi ekleniyor
- ✅ Ana ekranda kart görünüyor
- ✅ Hata yönetimi yapılmış
- ✅ Premium kullanıcılara kart gösterilmiyor

---

# 📖 TODO-5: İLK KULLANICI ONBOARDİNG

**Öncelik:** ORTA  
**Tahmini Süre:** 3-4 saat  
**Bağımlılıklar:** TODO-1 (dil sistemi - opsiyonel)

## Görev Özeti
İlk kez kayıt olan kullanıcılara uygulama kullanımını anlatan 3-4 sayfalık onboarding ekranı gösterilecek.

## Gereksinimler

### 1. Paket Yüklemeleri

**pubspec.yaml'a ekle:**
```yaml
dependencies:
  smooth_page_indicator: ^1.1.0
```

Terminalde çalıştır:
```bash
flutter pub get
```

### 2. Onboarding Screen Oluştur

**`/app/lib/screens/onboarding/onboarding_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Hoş Geldiniz! 👋',
      description:
          'AI Spor Pro ile maç tahminlerinizi yapay zeka destekli analiz edin.',
      image: Icons.rocket_launch,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Bülten Yükleyin 📸',
      description:
          'Hazırladığınız spor bülteninin fotoğrafını çekin veya galeriden seçin.',
      image: Icons.add_a_photo,
      color: Colors.purple,
    ),
    OnboardingPage(
      title: 'AI Analiz ⚡',
      description:
          'Yapay zekamız her maç için 7 farklı bahis türünde detaylı analiz yapar.',
      image: Icons.analytics,
      color: Colors.orange,
    ),
    OnboardingPage(
      title: 'Başarıya Ulaşın 🎯',
      description:
          'Risk analizi ve önerilerle daha bilinçli kararlar verin!',
      image: Icons.celebration,
      color: Colors.green,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      context.go('/login');
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text(
                    'Atla',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: Theme.of(context).primaryColor,
                ),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Başlayalım!'
                        : 'İleri',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            page.image,
            size: 120,
            color: page.color,
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData image;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
}
```

### 3. Router Güncelleme

**`/app/lib/core/routes/app_router.dart`** güncelle:

```dart
import '../../screens/onboarding/onboarding_screen.dart'; // ✅ YENİ
import 'package:shared_preferences/shared_preferences.dart'; // ✅ YENİ

// ✅ YENİ: Initial route kontrolü
Future<String> _getInitialRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  
  if (!onboardingCompleted) {
    return '/onboarding';
  }
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return '/login';
  }
  
  return '/home';
}

final router = GoRouter(
  initialLocation: '/onboarding', // ✅ Başlangıçta onboarding'e git
  routes: [
    // ✅ YENİ: Onboarding route
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    
    // Login
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    // ... diğer route'lar
  ],
  
  // ✅ YENİ: Redirect logic
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    
    // Eğer onboarding tamamlanmadıysa ve onboarding sayfasında değilse
    if (!onboardingCompleted && state.matchedLocation != '/onboarding') {
      return '/onboarding';
    }
    
    // Eğer onboarding tamamlandıysa ve login gerekiyorsa
    if (onboardingCompleted && user == null && state.matchedLocation == '/onboarding') {
      return '/login';
    }
    
    return null; // No redirect
  },
);
```

### 4. Test Et

```bash
flutter clean
flutter pub get
flutter run
```

**Test senaryosu:**
1. Uygulamayı tamamen sil ve tekrar yükle (fresh install)
2. Uygulama açıldığında onboarding ekranı görünmeli
3. Sayfalarda ileri-geri gez
4. "Atla" butonuna tıkla → Login ekranına gitm